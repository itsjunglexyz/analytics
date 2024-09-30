defmodule PlausibleWeb.Api.Internal.SegmentsController do
  use Plausible
  use PlausibleWeb, :controller
  use Plausible.Repo
  use PlausibleWeb.Plugs.ErrorHandler
  alias PlausibleWeb.Api.Helpers, as: H

  defp normalize_segment_id_param(input) do
    case Integer.parse(input) do
      {int_value, ""} -> int_value
      _ -> nil
    end
  end

  defp get_one_segment(_user_id, _site_id, nil) do
    nil
  end

  defp get_one_segment(user_id, site_id, segment_id) do
    Repo.one(
      from(i in Plausible.SegmentCollaborator,
        join: segment in assoc(i, :segment),
        select: %{role: i.role, segment: segment},
        where: i.user_id == ^user_id,
        where: segment.site_id == ^site_id,
        where: segment.id == ^segment_id
      )
    )
  end

  def get_all_segments(conn, _params) do
    user_id = conn.assigns.current_user.id
    site_id = conn.assigns.site.id

    segment_collaborators_query =
      from(i in Plausible.SegmentCollaborator,
        join: segment in assoc(i, :segment),
        select: %{role: i.role, segment: segment},
        where: i.user_id == ^user_id,
        where: segment.site_id == ^site_id
      )

    result = Repo.all(segment_collaborators_query)

    json(conn, result)
  end

  def get_segment(conn, params) do
    user_id = conn.assigns.current_user.id
    site_id = conn.assigns.site.id
    segment_id = normalize_segment_id_param(params["segment_id"])

    result = get_one_segment(user_id, site_id, segment_id)

    case result do
      nil -> H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")
      %{role: :owner} -> json(conn, result)
    end
  end

  def create_segment(conn, params) do
    user_id = conn.assigns.current_user.id
    site_id = conn.assigns.site.id
    segment_definition = Map.merge(params, %{"site_id" => site_id})

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :segment,
        Plausible.Segment.changeset(%Plausible.Segment{}, segment_definition)
      )
      |> Ecto.Multi.insert(:segment_collaboration, fn %{segment: segment} ->
        Plausible.SegmentCollaborator.changeset(%Plausible.SegmentCollaborator{}, %{
          role: :owner,
          segment_id: segment.id,
          user_id: user_id
        })
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{segment: segment, segment_collaboration: segment_collaboration}} ->
        json(conn, %{segment: segment, role: segment_collaboration.role})

      {:error, _} ->
        H.bad_request(conn, "Failed to create segment")
    end
  end

  def update_segment(conn, params) do
    user_id = conn.assigns.current_user.id
    site_id = conn.assigns.site.id
    segment_id = normalize_segment_id_param(params["segment_id"])

    existing = get_one_segment(user_id, site_id, segment_id)

    case existing do
      nil ->
        H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")

      %{role: :owner} ->
        updated_segment =
          Repo.update!(Plausible.Segment.changeset(existing.segment, params),
            returning: true
          )

        json(conn, %{role: existing.role, segment: updated_segment})
    end
  end

  def delete_segment(conn, params) do
    user_id = conn.assigns.current_user.id
    site_id = conn.assigns.site.id
    segment_id = normalize_segment_id_param(params["segment_id"])

    existing = get_one_segment(user_id, site_id, segment_id)

    case existing do
      nil ->
        H.not_found(conn, "Segment not found with ID #{inspect(params["segment_id"])}")

      %{role: :owner} ->
        Repo.delete!(existing.segment)
        json(conn, existing)
    end
  end
end
