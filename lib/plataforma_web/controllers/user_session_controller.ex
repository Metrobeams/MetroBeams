defmodule PlataformaWeb.UserSessionController do
  use PlataformaWeb, :controller

  alias Plataforma.Accounts
  alias PlataformaWeb.UserAuth

  def new(conn, _params) do
    reauth = conn.query_params["reauth"] == "true"
    email = get_in(conn.assigns, [:current_scope, Access.key(:user), Access.key(:email)])
    form = Phoenix.Component.to_form(%{"email" => email}, as: "user")

    conn
    |> assign(:reauth, reauth)
    |> render(:new, form: form)
  end

  # magic link login
  def create(conn, %{"user" => %{"token" => token} = user_params} = params) do
    info =
      case params do
        %{"_action" => "confirmed"} -> "Identidade confirmada com sucesso."
        _ -> "Bem-vindo de volta!"
      end

    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, _expired_tokens}} ->
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      {:error, :not_found} ->
        conn
        |> assign(:reauth, false)
        |> put_flash(:error, "O link é inválido ou expirou.")
        |> render(:new, form: Phoenix.Component.to_form(%{}, as: "user"))
    end
  end

  # email + password login
  def create(conn, %{"user" => %{"email" => email, "password" => password} = user_params}) do
    reauth = conn.query_params["reauth"] == "true"

    if user = Accounts.get_user_by_email_and_password(email, password) do
      if reauth && conn.assigns.current_scope do
        token = Accounts.generate_user_session_token_with_fresh_timestamp(user)

        conn
        |> put_flash(:info, "Identidade confirmada.")
        |> put_session(:user_token, token)
        |> redirect(to: get_session(conn, :user_return_to) || ~p"/users/settings")
      else
        conn
        |> put_flash(:info, "Bem-vindo de volta!")
        |> UserAuth.log_in_user(user, user_params)
      end
    else
      form = Phoenix.Component.to_form(user_params, as: "user")

      conn
      |> assign(:reauth, reauth)
      |> put_flash(:error, "E-mail ou senha inválidos")
      |> render(:new, form: form)
    end
  end

  # magic link request
  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    conn
    |> redirect(to: ~p"/users/log-in?sent=true&email=#{email}")
  end

  def confirm(conn, %{"token" => token}) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = Phoenix.Component.to_form(%{"token" => token}, as: "user")

      conn
      |> assign(:user, user)
      |> assign(:form, form)
      |> render(:confirm)
    else
      conn
      |> put_flash(:error, "O link é inválido ou expirou.")
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Sessão encerrada com sucesso.")
    |> UserAuth.log_out_user()
  end
end
