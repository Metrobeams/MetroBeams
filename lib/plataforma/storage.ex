defmodule Plataforma.Storage do
  @moduledoc """
  Behaviour for storage backends (e.g., S3, local filesystem).
  """

  @callback put(String.t(), Path.t(), String.t()) :: :ok | {:error, term()}
  @callback delete(String.t()) :: :ok | {:error, term()}
  @callback url(String.t()) :: {:ok, String.t()} | {:error, term()}
end
