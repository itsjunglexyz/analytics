defmodule PlausibleWeb.Api.Internal.SegmentsControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

  describe "GET /internal-api/:domain/segments" do
    setup [:create_user, :create_new_site, :log_in]

    test "returns empty list when no segment collaborations", %{conn: conn, site: site} do
      conn =
        get(conn, "/internal-api/#{site.domain}/segments")

      assert json_response(conn, 200) == []
    end
  end

  describe "GET /internal-api/:domain/segments/:segment_id" do
    setup [:create_user, :create_new_site, :log_in]

    test "serves 404 when invalid segment key used", %{conn: conn, site: site} do
      conn =
        get(conn, "/internal-api/#{site.domain}/segments/any-id")

      assert json_response(conn, 404) == %{"error" => "Segment not found with ID \"any-id\""}
    end

    test "serves 404 when no segment found", %{conn: conn, site: site} do
      conn =
        get(conn, "/internal-api/#{site.domain}/segments/100100")

      assert json_response(conn, 404) == %{"error" => "Segment not found with ID \"100100\""}
    end

    test "serves 404 when user is not collaborating on the segment", %{conn: conn, site: site} do
      %{id: segment_id} =
        insert(:segment, site: site, name: "any", segment_data: %{"filters" => []})

      conn =
        get(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

      assert json_response(conn, 404) == %{
               "error" => "Segment not found with ID \"#{segment_id}\""
             }
    end

    test "serves 404 when segment is for another site", %{conn: conn, site: site, user: user} do
      other_site = insert(:site, owner: user)

      %{id: segment_id} =
        insert(:segment, site: other_site, name: "any", segment_data: %{"filters" => []})

      insert(:segment_collaborator, role: :owner, user: user, segment_id: segment_id)

      conn =
        get(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

      assert json_response(conn, 404) == %{
               "error" => "Segment not found with ID \"#{segment_id}\""
             }
    end

    test "serves 200 with segment when user is collaborating on the segment", %{
      conn: conn,
      site: site,
      user: user
    } do
      name = "foo"
      description = "bar"
      segment_data = %{"filters" => []}
      inserted_at = "2024-09-01T10:00:00"
      updated_at = inserted_at
      role = "owner"

      %{id: segment_id} =
        insert(:segment,
          site: site,
          name: name,
          description: description,
          segment_data: segment_data,
          inserted_at: inserted_at,
          updated_at: updated_at
        )

      insert(:segment_collaborator, role: role, user: user, segment_id: segment_id)

      conn =
        get(conn, "/internal-api/#{site.domain}/segments/#{segment_id}")

      assert json_response(conn, 200) == %{
               "role" => role,
               "segment" => %{
                 "id" => segment_id,
                 "name" => name,
                 "description" => description,
                 "segment_data" => segment_data,
                 "inserted_at" => inserted_at,
                 "updated_at" => updated_at
               }
             }
    end
  end

  describe "POST /internal-api/:domain/segments" do
    setup [:create_user, :create_new_site, :log_in]

    test "creates segment successfully", %{conn: conn, site: site} do
      segment_data = %{"filters" => [["is", "visit:entry_page", ["/blog"]]]}
      name = "any name"

      conn =
        post(conn, "/internal-api/#{site.domain}/segments", %{
          "segment_data" => segment_data,
          "name" => name
        })

      response = json_response(conn, 200)

      assert %{
               "role" => "owner",
               "segment" => %{
                 "description" => nil,
                 "name" => ^name,
                 "segment_data" => ^segment_data
               }
             } = response

      %{"segment" => %{"id" => id, "updated_at" => updated_at, "inserted_at" => inserted_at}} =
        response

      assert is_integer(id)
      assert is_binary(inserted_at)
      assert is_binary(updated_at)
      assert ^inserted_at = updated_at
    end
  end

  describe "PATCH /internal-api/:domain/segments/:segment_id" do
    setup [:create_user, :create_new_site, :log_in]

    test "updates segment successfully", %{conn: conn, site: site, user: user} do
      name = "foo"
      description = "bar"
      segment_data = %{"filters" => []}
      inserted_at = "2024-09-01T10:00:00"
      updated_at = inserted_at
      role = "owner"

      %{id: segment_id} =
        insert(:segment,
          site: site,
          name: name,
          description: description,
          segment_data: segment_data,
          inserted_at: inserted_at,
          updated_at: updated_at
        )

      insert(:segment_collaborator, role: role, user: user, segment_id: segment_id)

      conn =
        patch(conn, "/internal-api/#{site.domain}/segments/#{segment_id}", %{
          "name" => "updated name"
        })

      response = json_response(conn, 200)

      assert %{
               "role" => ^role,
               "segment" => %{
                 "inserted_at" => ^inserted_at,
                 "id" => ^segment_id,
                 "description" => ^description,
                 "segment_data" => ^segment_data
               }
             } = response

      assert response["segment"]["name"] == "updated name"
      assert response["segment"]["updated_at"] != inserted_at
    end
  end
end
