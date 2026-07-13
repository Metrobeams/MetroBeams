defmodule PlataformaWeb.UserSettingsController do
  use PlataformaWeb, :controller

  alias Plataforma.Accounts
  alias Plataforma.Media.Avatar
  alias PlataformaWeb.UserAuth

  import PlataformaWeb.UserAuth, only: [require_sudo_mode: 2]

  plug :require_sudo_mode
  plug :assign_email_and_password_changesets

  def edit(conn, _params) do
    render(conn, :edit)
  end

  def update_avatar(conn, %{"avatar" => %Plug.Upload{} = upload}) do
    case Avatar.upload(conn.assigns.current_scope.user, upload) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Avatar atualizado com sucesso.")
        |> redirect(to: ~p"/users/settings")

      {:error, :file_too_large} ->
        avatar_error(conn, "A imagem deve ter no máximo 5 MB.")

      {:error, reason} when reason in [:unsupported_image, :invalid_upload, :processing_failed] ->
        avatar_error(conn, "Selecione uma imagem JPEG, PNG ou WebP válida.")

      {:error, _reason} ->
        avatar_error(conn, "Não foi possível atualizar o avatar. Tente novamente.")
    end
  end

  def update_avatar(conn, _params) do
    avatar_error(conn, "Selecione uma imagem para enviar.")
  end

  def delete_avatar(conn, _params) do
    case Avatar.remove(conn.assigns.current_scope.user) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Avatar removido com sucesso.")
        |> redirect(to: ~p"/users/settings")

      {:error, _reason} ->
        avatar_error(conn, "Não foi possível remover o avatar. Tente novamente.")
    end
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: ~p"/users/settings")

      changeset ->
        render(conn, :edit, email_changeset: %{changeset | action: :insert})
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.update_user_password(user, user_params) do
      {:ok, {user, _}} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/users/settings")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        render(conn, :edit, password_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_scope.user, token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"/users/settings")

      {:error, _} ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    user = conn.assigns.current_scope.user

    conn
    |> assign(:email_changeset, Accounts.change_user_email(user))
    |> assign(:password_changeset, Accounts.change_user_password(user))
    |> assign(:avatar_url, Avatar.url(user))
  end

  defp avatar_error(conn, message) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/users/settings")
  end
end
