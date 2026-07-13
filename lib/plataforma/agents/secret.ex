defmodule Plataforma.Agents.Secret do
  @moduledoc """
  Cryptographic secret generation and verification for agent authentication.
  """

  @secret_bytes 32
  @digest_bytes 32

  @spec generate() :: String.t()
  def generate do
    @secret_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  @spec digest(String.t()) :: binary()
  def digest(value) when is_binary(value), do: :crypto.hash(:sha256, value)

  @spec verify?(term(), term()) :: boolean()
  def verify?(value, digest) when is_binary(value) and byte_size(digest) == @digest_bytes do
    Plug.Crypto.secure_compare(digest(value), digest)
  end

  def verify?(_value, _digest), do: false

  @spec credential(Ecto.UUID.t(), String.t()) :: String.t()
  def credential(agent_id, secret) when is_binary(agent_id) and is_binary(secret) do
    agent_id <> "." <> secret
  end
end
