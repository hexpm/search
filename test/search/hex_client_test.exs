defmodule Search.HexClientTest do
  use ExUnit.Case, async: true

  alias Search.{HexClient, TestHelpers}

  setup ctx do
    tmp_dir = ctx[:tmp_dir]

    if is_nil(tmp_dir) do
      {:ok, []}
    else
      content = "# I am a README!"
      archive_name = "README.md"
      test_tar = TestHelpers.make_targz(tmp_dir, content, archive_name)
      test_tar_contents = [{to_charlist(archive_name), content}]

      {:ok, %{test_tar: test_tar, test_tar_contents: test_tar_contents}}
    end
  end

  describe "get_releases/1" do
    test "when given a well-formed package JSON, successfuly parses the releases" do
      Req.Test.stub(Search.HexClient, fn conn ->
        Req.Test.json(conn, %{
          "releases" => [
            %{"version" => "1.2.3", "has_docs" => true},
            %{"version" => "1.1.25", "has_docs" => false}
          ]
        })
      end)

      package_name = "test_package"

      assert HexClient.get_releases(package_name) ==
               {:ok,
                [
                  %HexClient.Release{
                    package_name: package_name,
                    version: Version.parse!("1.2.3"),
                    has_docs: true
                  },
                  %HexClient.Release{
                    package_name: package_name,
                    version: Version.parse!("1.1.25"),
                    has_docs: false
                  }
                ]}
    end

    test "when getting a response other than 200 OK, should fail gracefully" do
      Req.Test.stub(Search.HexClient, fn conn ->
        Plug.Conn.send_resp(conn, 403, "Internal server error")
      end)

      assert HexClient.get_releases("test_package") == {:error, "HTTP 403"}
    end
  end

  describe "get_docs_tarball" do
    @tag :tmp_dir
    test "when given a release with documentation, should return contents of the archive", %{
      test_tar: test_tar,
      test_tar_contents: test_tar_contents
    } do
      Req.Test.stub(Search.HexClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/octet-stream", nil)
        |> Plug.Conn.send_file(200, test_tar)
      end)

      rel = %HexClient.Release{
        package_name: "test_package",
        version: Version.parse!("1.2.3"),
        has_docs: true
      }

      assert HexClient.get_docs_tarball(rel) == {:ok, test_tar_contents}
    end

    test "when given a release with no documentation, should return error" do
      rel = %HexClient.Release{
        package_name: "test_package",
        version: Version.parse!("1.2.3"),
        has_docs: false
      }

      assert HexClient.get_docs_tarball(rel) == {:error, "Package release has no documentation."}
    end

    test "when getting a response other than 200 OK, should fail gracefully" do
      Req.Test.stub(Search.HexClient, fn conn ->
        Plug.Conn.send_resp(conn, 403, "Internal server error")
      end)

      rel = %HexClient.Release{
        package_name: "test_package",
        version: Version.parse!("1.2.3"),
        has_docs: true
      }

      assert HexClient.get_docs_tarball(rel) == {:error, "HTTP 403"}
    end
  end
end