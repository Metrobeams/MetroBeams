defmodule PlataformaWeb.Plugs.RequireJSONContentType do
  @moduledoc """
  Plug that requires requests to have application/json content type.
  """

  import Plug.Conn

  @content_type "application/json"

  def init(opts), do: opts

  def call(conn, _opts) do
    if json_content_type?(conn) do
      conn
    else
      body =
        Jason.encode!(%{
          error: %{
            code: "unsupported_media_type",
            message: "Content-Type must be application/json"
          }
        })

      conn
      |> put_resp_content_type(@content_type)
      |> send_resp(:unsupported_media_type, body)
      |> halt()
    end
  end

  defp json_content_type?(conn) do
    conn
    |> get_req_header("content-type")
    |> Enum.any?(fn value ->
      value
      |> String.downcase()
      |> String.split(";", parts: 2)
      |> hd()
      |> String.trim()
      |> Kernel.==(@content_type)
    end)
  end
end
