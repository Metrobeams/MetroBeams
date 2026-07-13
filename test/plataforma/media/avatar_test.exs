defmodule Plataforma.Media.AvatarTest do
  use Plataforma.DataCase, async: true

  import Mox
  import Plataforma.AccountsFixtures

  alias Plataforma.Accounts
  alias Plataforma.Media.Avatar
  alias Plataforma.{ImageProcessorMock, Repo, StorageMock}

  setup :verify_on_exit!

  setup do
    processed_path =
      Path.join(System.tmp_dir!(), "processed-avatar-#{System.unique_integer([:positive])}.webp")

    File.write!(processed_path, :crypto.strong_rand_bytes(64))
    on_exit(fn -> File.rm(processed_path) end)

    %{processed_path: processed_path}
  end

  test "uploads a processed avatar and persists only its key and metadata", context do
    user = user_fixture()
    processed = processed(context.processed_path)
    browser_upload = upload()
    source_path = browser_upload.path

    expect(ImageProcessorMock, :process, fn ^source_path -> {:ok, processed} end)

    expect(StorageMock, :put, fn key, path, content_type ->
      assert String.starts_with?(key, "avatars/#{user.id}/")
      assert Path.extname(key) == ".webp"
      assert path == processed.path
      assert content_type == processed.content_type
      :ok
    end)

    assert {:ok, updated_user} = Avatar.upload(user, browser_upload, adapters())
    assert updated_user.avatar_key
    assert updated_user.avatar_content_type == processed.content_type
    assert updated_user.avatar_size == processed.size
    assert %DateTime{} = updated_user.avatar_updated_at
    refute String.contains?(updated_user.avatar_key, "://")
    refute File.exists?(processed.path)
  end

  test "does not update the database when storage upload fails", context do
    user = user_fixture()
    processed = processed(context.processed_path)

    expect(ImageProcessorMock, :process, fn _path -> {:ok, processed} end)
    expect(StorageMock, :put, fn _key, _path, _content_type -> {:error, :storage_unavailable} end)

    assert {:error, :storage_unavailable} = Avatar.upload(user, upload(), adapters())
    refute Repo.reload!(user).avatar_key
  end

  test "removes the new object if persisting its metadata fails", context do
    user = user_fixture()
    processed = %{processed(context.processed_path) | size: 0}

    expect(ImageProcessorMock, :process, fn _path -> {:ok, processed} end)
    expect(StorageMock, :put, fn _key, _path, _content_type -> :ok end)

    expect(StorageMock, :delete, fn key ->
      assert String.starts_with?(key, "avatars/#{user.id}/")
      :ok
    end)

    assert {:error, %Ecto.Changeset{}} = Avatar.upload(user, upload(), adapters())
    refute Repo.reload!(user).avatar_key
  end

  test "deletes the previous object only after replacing its database reference", context do
    user = user_fixture()
    previous_key = "avatars/#{user.id}/#{Ecto.UUID.generate()}.webp"
    user = persist_avatar!(user, previous_key)
    processed = processed(context.processed_path)

    expect(ImageProcessorMock, :process, fn _path -> {:ok, processed} end)
    expect(StorageMock, :put, fn _key, _path, _content_type -> :ok end)
    expect(StorageMock, :delete, fn ^previous_key -> :ok end)

    assert {:ok, updated_user} = Avatar.upload(user, upload(), adapters())
    assert updated_user.avatar_key != previous_key
    assert Repo.reload!(user).avatar_key == updated_user.avatar_key
  end

  test "removes avatar metadata and tolerates an object already missing" do
    user = user_fixture()
    key = "avatars/#{user.id}/#{Ecto.UUID.generate()}.webp"
    user = persist_avatar!(user, key)

    expect(StorageMock, :delete, fn ^key -> :ok end)

    assert {:ok, updated_user} = Avatar.remove(user, adapters())
    refute updated_user.avatar_key
    refute updated_user.avatar_content_type
    refute updated_user.avatar_size
    refute updated_user.avatar_updated_at
  end

  test "returns the default avatar without consulting storage" do
    user = user_fixture()
    assert Avatar.url(user, adapters()) == "/images/default-avatar.svg"
  end

  test "resolves a stored key at runtime" do
    user = user_fixture()
    key = "avatars/#{user.id}/#{Ecto.UUID.generate()}.webp"
    user = persist_avatar!(user, key)
    resolved = "https://media.example/#{key}"

    expect(StorageMock, :url, fn ^key -> {:ok, resolved} end)

    assert Avatar.url(user, adapters()) == resolved
  end

  defp processed(path) do
    %{path: path, content_type: "image/webp", size: File.stat!(path).size}
  end

  defp upload do
    %Plug.Upload{
      path: Path.join(System.tmp_dir!(), "browser-upload"),
      filename: "avatar",
      content_type: "application/octet-stream"
    }
  end

  defp adapters do
    [storage: StorageMock, image_processor: ImageProcessorMock]
  end

  defp persist_avatar!(user, key) do
    {:ok, user} =
      Accounts.update_user_avatar(user, %{
        avatar_key: key,
        avatar_content_type: "image/webp",
        avatar_size: byte_size(key),
        avatar_updated_at: DateTime.utc_now(:second)
      })

    user
  end
end
