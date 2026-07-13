defmodule Plataforma.Media.Avatar do
  alias Plataforma.Accounts

  require Logger

  @default_url "/images/default-avatar.svg"

  def upload(user, upload, opts \\ [])

  def upload(user, %Plug.Upload{path: source_path}, opts) do
    image_processor = adapter(opts, :image_processor, Plataforma.Media.ImageProcessor.ImageMagick)

    case image_processor.process(source_path) do
      {:ok, processed} ->
        try do
          persist_upload(user, processed, opts)
        after
          File.rm(processed.path)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def upload(_user, _upload, _opts), do: {:error, :invalid_upload}

  def remove(user, opts \\ [])

  def remove(%{avatar_key: nil} = user, _opts), do: {:ok, user}

  def remove(user, opts) do
    storage = adapter(opts, :storage, Plataforma.Storage.MinIO)
    previous_key = user.avatar_key

    with {:ok, updated_user} <- Accounts.clear_user_avatar(user),
         :ok <- storage.delete(previous_key) do
      {:ok, updated_user}
    end
  end

  def url(user, opts \\ [])

  def url(%{avatar_key: nil}, _opts), do: @default_url

  def url(%{avatar_key: key}, opts) do
    storage = adapter(opts, :storage, Plataforma.Storage.MinIO)

    case storage.url(key) do
      {:ok, resolved_url} ->
        resolved_url

      {:error, reason} ->
        Logger.error("Avatar URL resolution failed", reason: inspect_safe(reason))
        @default_url
    end
  end

  defp persist_upload(user, processed, opts) do
    storage = adapter(opts, :storage, Plataforma.Storage.MinIO)
    new_key = "avatars/#{user.id}/#{Ecto.UUID.generate()}.webp"

    with :ok <- storage.put(new_key, processed.path, processed.content_type) do
      persist_metadata(user, new_key, processed, storage)
    end
  end

  defp persist_metadata(user, new_key, processed, storage) do
    attrs = %{
      avatar_key: new_key,
      avatar_content_type: processed.content_type,
      avatar_size: processed.size,
      avatar_updated_at: DateTime.utc_now(:second)
    }

    case Accounts.update_user_avatar(user, attrs) do
      {:ok, updated_user} ->
        delete_previous(storage, user.avatar_key)
        {:ok, updated_user}

      {:error, changeset} ->
        storage.delete(new_key)
        {:error, changeset}
    end
  end

  defp delete_previous(_storage, nil), do: :ok

  defp delete_previous(storage, key) do
    case storage.delete(key) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Previous avatar cleanup failed", reason: inspect_safe(reason))
        :ok
    end
  end

  defp adapter(opts, name, default) do
    Keyword.get(opts, name, Application.get_env(:plataforma, name, default))
  end

  defp inspect_safe(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp inspect_safe(_reason), do: "avatar_operation_error"
end
