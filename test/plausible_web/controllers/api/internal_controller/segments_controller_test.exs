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
          "segment_data" => %{},
          "name" => "should work"
        })

      response = json_response(conn, 200)

      assert %{
               "role" => "owner",
               "segment" => %{
                 "description" => nil,
                 "name" => "should work",
                 "segment_data" => %{}
               }
             } = response

      assert is_binary(response["segment"]["inserted_at"])
      assert is_binary(response["segment"]["updated_at"])
      assert is_integer(response["segment"]["id"])
    end
  end

  describe "PATCH /internal-api/:domain/segments/:segment_id" do
    setup [:create_user, :create_new_site, :log_in]

    test "updates segment successfully", %{conn: conn, site: site} do
      conn1 =
        post(conn, "/internal-api/#{site.domain}/segments", %{
          "segment_data" => %{},
          "name" => "should work"
        })

      segment_id = json_response(conn1, 200)["segment"]["id"]

      conn2 =
        patch(conn, "/internal-api/#{site.domain}/segments/#{segment_id}", %{
          "name" => "should overwrite"
        })

      response = json_response(conn2, 200)

      assert %{
               "role" => "owner",
               "segment" => %{
                 "description" => nil,
                 "name" => "should overwrite",
                 "segment_data" => %{}
               }
             } = response
    end
  end
end
