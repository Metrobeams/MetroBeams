defmodule PlataformaWeb.AccountControllerTest do
  use PlataformaWeb.ConnCase, async: true

  import Mox
  import Plataforma.AccountsFixtures

  alias Plataforma.{ImageProcessorMock, Repo, StorageMock}

  setup :verify_on_exit!
  setup :register_and_log_in_user

  setup do
    source_path =
      Path.join(System.tmp_dir!(), "account-source-#{System.unique_integer([:positive])}")

    output_path =
      Path.join(System.tmp_dir!(), "account-output-#{System.unique_integer([:positive])}.webp")

    File.write!(source_path, :crypto.strong_rand_bytes(32))
    File.write!(output_path, :crypto.strong_rand_bytes(64))

    on_exit(fn ->
      File.rm(source_path)
      File.rm(output_path)
    end)

    %{source_path: source_path, output_path: output_path}
  end

  test "GET /api/account requires authentication" do
    conn = build_conn() |> put_req_header("accept", "application/json") |> get(~p"/api/account")
    assert json_response(conn, 401)["error"]
  end

  test "GET /api/account returns the current user and default avatar", %{conn: conn, user: user} do
    conn = get(conn, ~p"/api/account")
    body = json_response(conn, 200)

    assert body["id"] == user.id
    assert body["email"] == user.email
    assert body["avatar_url"] == "/images/default-avatar.svg"
  end

  test "PUT /api/account/avatar uploads for the current user", context do
    processed = %{
      path: context.output_path,
      content_type: "image/webp",
      size: File.stat!(context.output_path).size
    }

    source_path = context.source_path
    output_path = context.output_path

    expect(ImageProcessorMock, :process, fn ^source_path -> {:ok, processed} end)

    expect(StorageMock, :put, fn key, ^output_path, "image/webp" ->
      assert String.starts_with?(key, "avatars/#{context.user.id}/")
      :ok
    end)

    expect(StorageMock, :url, fn key -> {:ok, "https://media.example/#{key}"} end)

    upload = %Plug.Upload{path: source_path, filename: "avatar.jpg", content_type: "image/jpeg"}
    conn = put(context.conn, ~p"/api/account/avatar", %{avatar: upload})
    body = json_response(conn, 200)

    assert body["avatar_url"]
    assert Repo.reload!(context.user).avatar_key
  end

  test "PUT /api/account/avatar rejects unsupported content", context do
    expect(ImageProcessorMock, :process, fn _path -> {:error, :unsupported_image} end)

    upload = %Plug.Upload{
      path: context.source_path,
      filename: "avatar.gif",
      content_type: "image/gif"
    }

    conn = put(context.conn, ~p"/api/account/avatar", %{avatar: upload})
    assert json_response(conn, 422)["error"]
  end

  test "PUT /api/account/avatar rejects oversized content", context do
    expect(ImageProcessorMock, :process, fn _path -> {:error, :file_too_large} end)

    upload = %Plug.Upload{
      path: context.source_path,
      filename: "avatar.png",
      content_type: "image/png"
    }

    conn = put(context.conn, ~p"/api/account/avatar", %{avatar: upload})
    assert json_response(conn, 413)["error"]
  end

  test "DELETE /api/account/avatar clears the current user's avatar even when another id is sent",
       context do
    other_user = user_fixture()
    key = "avatars/#{context.user.id}/#{Ecto.UUID.generate()}.webp"

    {:ok, current_user} =
      Plataforma.Accounts.update_user_avatar(context.user, %{
        avatar_key: key,
        avatar_content_type: "image/webp",
        avatar_size: byte_size(key),
        avatar_updated_at: DateTime.utc_now(:second)
      })

    expect(StorageMock, :delete, fn ^key -> :ok end)

    conn = delete(context.conn, ~p"/api/account/avatar", %{user_id: other_user.id})
    body = json_response(conn, 200)

    assert body["avatar_url"] == "/images/default-avatar.svg"
    refute Repo.reload!(current_user).avatar_key
    refute Repo.reload!(other_user).avatar_key
  end
end
