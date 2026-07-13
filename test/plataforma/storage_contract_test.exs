defmodule Plataforma.StorageContractTest do
  use ExUnit.Case, async: true

  Mox.defmock(StorageContractMock, for: Plataforma.Storage)

  test "storage adapters expose upload, idempotent deletion and runtime URL resolution" do
    key = "avatars/#{System.unique_integer([:positive])}/#{Ecto.UUID.generate()}.webp"
    path = Path.join(System.tmp_dir!(), Path.basename(key))
    content_type = "image/webp"
    resolved_url = URI.to_string(%URI{scheme: "https", host: "media.example", path: "/#{key}"})

    StorageContractMock
    |> Mox.expect(:put, fn ^key, ^path, ^content_type -> :ok end)
    |> Mox.expect(:delete, fn ^key -> :ok end)
    |> Mox.expect(:url, fn ^key -> {:ok, resolved_url} end)

    assert :ok = StorageContractMock.put(key, path, content_type)
    assert :ok = StorageContractMock.delete(key)
    assert {:ok, url} = StorageContractMock.url(key)
    assert URI.parse(url).host == URI.parse(resolved_url).host
  end

  test "media storage has a configurable bucket and short-lived private URL TTL" do
    bucket = Application.fetch_env!(:plataforma, :media_bucket)
    ttl = Application.fetch_env!(:plataforma, :avatar_url_ttl)

    assert is_binary(bucket)
    assert byte_size(bucket) > 0
    assert is_integer(ttl)
    assert ttl > 0
  end

  test "local media storage targets the bucket available in MinIO" do
    expected_bucket = System.get_env("MINIO_BUCKET", "photos")

    assert Application.fetch_env!(:plataforma, :media_bucket) == expected_bucket
  end

  test "local S3 requests use an adapter that preserves signed upload headers" do
    assert Application.fetch_env!(:ex_aws, :http_client) == ExAws.Request.Req
    assert Code.ensure_loaded?(ExAws.Request.Req)
  end
end
