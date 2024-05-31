defmodule Plausible.Stats.Aggregate do
  use Plausible.ClickhouseRepo
  use Plausible
  import Plausible.Stats.{Base, Imported}
  import Ecto.Query
  alias Plausible.Stats.{Query, Util}

  def aggregate(site, query, metrics) do
    {currency, metrics} =
      on_ee do
        Plausible.Stats.Goal.Revenue.get_revenue_tracking_currency(site, query, metrics)
      else
        {nil, metrics}
      end

    Query.trace(query, metrics)

    {event_metrics, session_metrics, other_metrics} =
      metrics
      |> Util.maybe_add_visitors_metric()
      |> Plausible.Stats.TableDecider.partition_metrics(query)

    event_task = fn -> aggregate_events(site, query, event_metrics) end

    session_task = fn -> aggregate_sessions(site, query, session_metrics) end

    time_on_page_task =
      if :time_on_page in other_metrics do
        fn -> aggregate_time_on_page(site, query) end
      else
        fn -> %{} end
      end

    Plausible.ClickhouseRepo.parallel_tasks([session_task, event_task, time_on_page_task])
    |> Enum.reduce(%{}, fn aggregate, task_result -> Map.merge(aggregate, task_result) end)
    |> Util.keep_requested_metrics(metrics)
    |> cast_revenue_metrics_to_money(currency)
    |> Enum.map(&maybe_round_value/1)
    |> Enum.map(fn {metric, value} -> {metric, %{value: value}} end)
    |> Enum.into(%{})
  end

  defp aggregate_events(_, _, []), do: %{}

  defp aggregate_events(site, query, metrics) do
    from(e in base_event_query(site, query), select: ^select_event_metrics(metrics))
    |> merge_imported(site, query, metrics)
    |> maybe_add_conversion_rate(site, query, metrics)
    |> ClickhouseRepo.one()
  end

  defp aggregate_sessions(_, _, []), do: %{}

  defp aggregate_sessions(site, query, metrics) do
    from(e in query_sessions(site, query), select: ^select_session_metrics(metrics, query))
    |> filter_converted_sessions(site, query)
    |> merge_imported(site, query, metrics)
    |> ClickhouseRepo.one()
    |> Util.keep_requested_metrics(metrics)
  end

  defp aggregate_time_on_page(site, query) do
    if FunWithFlags.enabled?(:window_time_on_page) do
      window_aggregate_time_on_page(site, query)
    else
      neighbor_aggregate_time_on_page(site, query)
    end
  end

  defp neighbor_aggregate_time_on_page(site, query) do
    q =
      from(
        e in base_event_query(site, Query.remove_filters(query, ["event:page"])),
        select: {
          fragment("? as p", e.pathname),
          fragment("? as t", e.timestamp),
          fragment("? as s", e.session_id)
        },
        order_by: [e.session_id, e.timestamp]
      )

    {base_query_raw, base_query_raw_params} = ClickhouseRepo.to_sql(:all, q)
    where_param_idx = length(base_query_raw_params)

    {where_clause, where_arg} =
      case Query.get_filter(query, "event:page") do
        [:is, _, page] ->
          {"p IN {$#{where_param_idx}:Array(String)}", page}

        [:is_not, _, page] ->
          {"p NOT IN {$#{where_param_idx}:Array(String)}", page}

        [:matches, _, exprs] ->
          page_regexes = Enum.map(exprs, &page_regex/1)
          {"multiMatchAny(p, {$#{where_param_idx}:Array(String)})", page_regexes}

        [:does_not_match, _, exprs] ->
          page_regexes = Enum.map(exprs, &page_regex/1)
          {"not(multiMatchAny(p, {$#{where_param_idx}:Array(String)}))", page_regexes}
      end

    params = base_query_raw_params ++ [where_arg]

    time_query = "
      SELECT
        avg(ifNotFinite(avgTime, null))
      FROM
        (SELECT
          p,
          sum(td)/count(case when p2 != p then 1 end) as avgTime
        FROM
          (SELECT
            p,
            p2,
            sum(t2-t) as td
          FROM
            (SELECT
            *,
              neighbor(t, 1) as t2,
              neighbor(p, 1) as p2,
              neighbor(s, 1) as s2
            FROM (#{base_query_raw}))
          WHERE s=s2 AND #{where_clause}
          GROUP BY p,p2,s)
        GROUP BY p)"

    {:ok, res} = ClickhouseRepo.query(time_query, params)
    [[time_on_page]] = res.rows
    %{time_on_page: time_on_page}
  end

  defp window_aggregate_time_on_page(site, query) do
    windowed_pages_q =
      from e in base_event_query(site, Query.remove_filters(query, ["event:page"])),
        select: %{
          next_timestamp: over(fragment("leadInFrame(?)", e.timestamp), :event_horizon),
          next_pathname: over(fragment("leadInFrame(?)", e.pathname), :event_horizon),
          timestamp: e.timestamp,
          pathname: e.pathname,
          session_id: e.session_id
        },
        windows: [
          event_horizon: [
            partition_by: e.session_id,
            order_by: e.timestamp,
            frame: fragment("ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING")
          ]
        ]

    event_page_filter = Query.get_filter(query, "event:page")

    timed_page_transitions_q =
      from e in Ecto.Query.subquery(windowed_pages_q),
        group_by: [e.pathname, e.next_pathname, e.session_id],
        where:
          ^Plausible.Stats.Filters.WhereBuilder.build_condition(:pathname, event_page_filter),
        where: e.next_timestamp != 0,
        select: %{
          pathname: e.pathname,
          transition: e.next_pathname != e.pathname,
          duration: sum(e.next_timestamp - e.timestamp)
        }

    avg_time_per_page_transition_q =
      from e in Ecto.Query.subquery(timed_page_transitions_q),
        select: %{avg: fragment("sum(?)/countIf(?)", e.duration, e.transition)},
        group_by: e.pathname

    time_on_page_q =
      from e in Ecto.Query.subquery(avg_time_per_page_transition_q),
        select: fragment("avg(ifNotFinite(?,NULL))", e.avg)

    %{time_on_page: ClickhouseRepo.one(time_on_page_q)}
  end

  @metrics_to_round [:bounce_rate, :time_on_page, :visit_duration, :sample_percent]

  defp maybe_round_value({metric, nil}), do: {metric, nil}

  defp maybe_round_value({metric, value}) when metric in @metrics_to_round do
    {metric, round(value)}
  end

  defp maybe_round_value(entry), do: entry

  on_ee do
    defp cast_revenue_metrics_to_money(results, revenue_goals) do
      Plausible.Stats.Goal.Revenue.cast_revenue_metrics_to_money(results, revenue_goals)
    end
  else
    defp cast_revenue_metrics_to_money(results, _revenue_goals), do: results
  end
end
