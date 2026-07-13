defmodule Plataforma.Agents.SecretTest do
  use ExUnit.Case, async: true

  alias Plataforma.Agents.Secret

  test "generate/0 returns distinct URL-safe 256-bit secrets" do
    first = Secret.generate()
    second = Secret.generate()

    assert first != second
    assert {:ok, decoded} = Base.url_decode64(first, padding: false)
    assert byte_size(decoded) == 32
  end

  test "digest/1 is deterministic and verify?/2 compares the plaintext" do
    digest = Secret.digest("secret")

    assert byte_size(digest) == 32
    assert digest == Secret.digest("secret")
    assert Secret.verify?("secret", digest)
    refute Secret.verify?("wrong", digest)
    refute Secret.verify?(nil, digest)
  end

  test "credential/2 combines the public agent id and secret" do
    id = Ecto.UUID.generate()

    assert Secret.credential(id, "opaque") == "#{id}.opaque"
  end
end
