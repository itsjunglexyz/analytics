defmodule PlausibleWeb.DebugController do
  use PlausibleWeb, :controller
  use Plausible.IngestRepo
  use Plausible

  import Ecto.Query

  plug(PlausibleWeb.RequireAccountPlug)
  plug(PlausibleWeb.SuperAdminOnlyPlug)

  def clickhouse(conn, params) do
    user_id = Map.get(params, "user_id", conn.assigns.current_user.id)

    cluster? = Plausible.MigrationUtils.clustered_table?("events_v2")
    on_cluster = if(cluster?, do: "ON CLUSTER '{cluster}'", else: "")

    # Ensure last logs are flushed
    IngestRepo.query("SYSTEM FLUSH LOGS #{on_cluster}")

    prefix =
      if(cluster?,
        do: "sysall",
        else: "system"
      )

    q =
      from t in "query_log",
        prefix: ^prefix,
        select: %{
          log_comment: t.log_comment,
          data: %{
            query: fragment("formatQuery(?)", t.query),
            type: t.type,
            event_time: t.event_time,
            query_duration_ms: t.query_duration_ms,
            query_id: t.query_id,
            result_rows: t.result_rows,
            memory_usage: fragment("formatReadableSize(?)", t.memory_usage),
            read_bytes: fragment("formatReadableSize(?)", t.read_bytes),
            result_bytes: fragment("formatReadableSize(?)", t.result_bytes)
          }
        },
        where:
          t.type > 1 and
            fragment("JSONExtractUInt(log_comment, 'user_id') = ?", ^user_id) and
            t.event_time > fragment("now() - toIntervalMinute(15)"),
        order_by: [desc: t.event_time]

    queries = IngestRepo.all(q)

    conn
    |> render("clickhouse.html",
      queries: queries,
      user_id: user_id,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end
end
