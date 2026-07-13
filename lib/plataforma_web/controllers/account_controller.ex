defmodule PlataformaWeb.AccountController do
  use PlataformaWeb, :controller

  alias Plataforma.Media.Avatar

  def show(conn, _params) do
    json(conn, account_json(conn.assigns.current_scope.user))
  end

  def update_avatar(conn, %{"avatar" => %Plug.Upload{} = upload}) do
    user = conn.assigns.current_scope.user

    case Avatar.upload(user, upload) do
      {:ok, updated_user} ->
        json(conn, account_json(updated_user))

      {:error, :file_too_large} ->
        conn |> put_status(413) |> json(%{error: "file_too_large"})

      {:error, reason} when reason in [:unsupported_image, :invalid_upload, :processing_failed] ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: Atom.to_string(reason)})

      {:error, %Ecto.Changeset{}} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid_avatar"})

      {:error, _reason} ->
        conn |> put_status(:service_unavailable) |> json(%{error: "avatar_service_unavailable"})
    end
  end

  def update_avatar(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "avatar_required"})
  end

  def delete_avatar(conn, _params) do
    user = conn.assigns.current_scope.user

    case Avatar.remove(user) do
      {:ok, updated_user} ->
        json(conn, account_json(updated_user))

      {:error, _reason} ->
        conn |> put_status(:service_unavailable) |> json(%{error: "avatar_service_unavailable"})
    end
  end

  defp account_json(user) do
    %{
      id: user.id,
      email: user.email,
      avatar_url: Avatar.url(user),
      avatar_content_type: user.avatar_content_type,
      avatar_size: user.avatar_size,
      avatar_updated_at: user.avatar_updated_at
    }
  end
end
