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
  end

  describe "POST /internal-api/:domain/segments" do
    setup [:create_user, :create_new_site, :log_in]

    test "creates segment successfully", %{conn: conn, site: site} do
      conn =
        post(conn, "/internal-api/#{site.domain}/segments", %{
          "segment_data" => %{"filters" => []},
          "name" => "any name"
        })

      response = json_response(conn, 200)

      assert %{
               "role" => "owner",
               "segment" => %{
                 "description" => nil,
                 "name" => "any name",
                 "segment_data" => %{"filters" => []}
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

    test "updates segment successfully", %{conn: conn, site: site} do
      conn1 =
        post(conn, "/internal-api/#{site.domain}/segments", %{
          "segment_data" => %{"filters" => []},
          "name" => "any name"
        })

      insert_response = json_response(conn1, 200)
      %{"role" => role, "segment" => segment} = insert_response
      %{"id" => id} = segment

      conn2 =
        patch(conn, "/internal-api/#{site.domain}/segments/#{id}", %{
          "name" => "updated name"
        })

      patch_response = json_response(conn2, 200)

      assert ^patch_response = %{
               "role" => role,
               "segment" => %{segment | "name" => "updated name"}
             }
    end
  end
end
