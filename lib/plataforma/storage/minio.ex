defmodule Plataforma.Storage.MinIO do
  @moduledoc """
  S3-compatible storage implementation using MinIO.
  """

  @behaviour Plataforma.Storage

  require Logger

  @impl true
  def put(key, path, content_type) do
    with {:ok, contents} <- File.read(path),
         {:ok, _response} <-
           ExAws.S3.put_object(bucket(), key, contents, content_type: content_type)
           |> ExAws.request() do
      :ok
    else
      {:error, reason} ->
        Logger.error("Avatar object upload failed", reason: inspect_safe(reason))
        {:error, :storage_unavailable}
    end
  end

  @impl true
  def delete(key) do
    case ExAws.S3.delete_object(bucket(), key) |> ExAws.request() do
      {:ok, _response} ->
        :ok

      {:error, {:http_error, 404, _response}} ->
        :ok

      {:error, reason} ->
        Logger.error("Avatar object deletion failed", reason: inspect_safe(reason))
        {:error, :storage_unavailable}
    end
  end

  @impl true
  def url(key) do
    case Application.get_env(:plataforma, :media_base_url) do
      base_url when is_binary(base_url) and base_url != "" ->
        {:ok, String.trim_trailing(base_url, "/") <> "/" <> key}

      _ ->
        config = presign_config()

        ExAws.S3.presigned_url(config, :get, bucket(), key,
          expires_in: Application.get_env(:plataforma, :avatar_url_ttl, 300)
        )
    end
  end

  defp bucket, do: Application.fetch_env!(:plataforma, :media_bucket)

  defp presign_config do
    case Application.get_env(:plataforma, :minio_public_endpoint) do
      endpoint when is_binary(endpoint) and endpoint != "" ->
        uri = URI.parse(endpoint)

        ExAws.Config.new(:s3,
          scheme: uri.scheme <> "://",
          host: uri.host,
          port: uri.port
        )

      _ ->
        ExAws.Config.new(:s3)
    end
  end

  defp inspect_safe(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp inspect_safe(_reason), do: "external_service_error"
end
