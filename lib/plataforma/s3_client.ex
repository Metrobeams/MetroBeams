defmodule Plataforma.S3Client do
  @moduledoc """
  HTTP client adapter for ExAws using Req with path-style URLs for MinIO.
  """

  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(method, url, body, headers, _opts) do
    method_atom = method_to_atom(method)

    # Convert tuple headers to string list
    headers_list =
      headers
      |> Enum.map(fn
        {k, v} when is_tuple(k) -> {elem(k, 0) |> to_string(), to_string(v)}
        {k, v} -> {to_string(k), to_string(v)}
      end)

    case Req.request(
           method: method_atom,
           url: url,
           body: body,
           headers: headers_list,
           decode_body: false
         ) do
      {:ok, %Req.Response{status: status, body: body}} ->
        status_code =
          if is_binary(status) do
            String.to_integer(status)
          else
            status
          end

        {:ok, %{status_code: status_code, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp method_to_atom("GET"), do: :get
  defp method_to_atom("POST"), do: :post
  defp method_to_atom("PUT"), do: :put
  defp method_to_atom("DELETE"), do: :delete
  defp method_to_atom("HEAD"), do: :head
  defp method_to_atom(_), do: :get
end
