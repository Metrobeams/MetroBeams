defmodule PlataformaWeb.UserSessionControllerTest do
  use PlataformaWeb.ConnCase, async: true

  import Plataforma.AccountsFixtures
  alias Plataforma.Accounts

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), user: user_fixture()}
  end

  describe "GET /users/log-in" do
    test "renders login page", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in")
      document = conn |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("#app-content.max-w-7xl") |> Enum.count() == 1

      assert LazyHTML.attribute(
               LazyHTML.query(document, "#login-page"),
               "data-layout"
             ) == ["desktop"]

      assert LazyHTML.attribute(
               LazyHTML.query(document, "#login-page"),
               "data-surface"
             ) == ["flat"]

      assert LazyHTML.attribute(
               LazyHTML.query(document, "#login-page"),
               "data-sizing"
             ) == ["intrinsic"]

      assert LazyHTML.attribute(
               LazyHTML.query(document, "#login-page"),
               "data-design-system"
             ) == ["carbon"]

      assert document |> LazyHTML.query("main.login-main") |> Enum.count() == 1

      assert LazyHTML.attribute(
               LazyHTML.query(document, "#login-tabs"),
               "data-panel-sizing"
             ) == ["matched"]

      assert document |> LazyHTML.query("#login_form_magic") |> Enum.count() == 1
      assert document |> LazyHTML.query("#login_form_password") |> Enum.count() == 1

      assert LazyHTML.attribute(
               LazyHTML.query(document, "#login-registration-link"),
               "href"
             ) == [~p"/users/register"]
    end

    test "renders login page with email filled in (sudo mode)", %{conn: conn, user: user} do
      document =
        conn
        |> log_in_user(user)
        |> get(~p"/users/log-in")
        |> html_response(200)
        |> LazyHTML.from_document()

      assert document
             |> LazyHTML.query("#login-page")
             |> LazyHTML.text() =~ "autentique-se novamente"

      assert document |> LazyHTML.query("#login-registration-link") |> Enum.empty?()

      assert LazyHTML.attribute(
               LazyHTML.query(document, "#login_form_magic input[type=email]"),
               "value"
             ) == [user.email]
    end

    test "renders login page (email + password)", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in?mode=password")
      document = conn |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("#login_form_magic") |> Enum.count() == 1
      assert document |> LazyHTML.query("#login_form_password") |> Enum.count() == 1
      assert document |> LazyHTML.query("#login-registration-link") |> Enum.count() == 1
    end
  end

  describe "GET /users/log-in/:token" do
    test "renders confirmation page for unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/log-in/#{token}")
      assert html_response(conn, 200) =~ "Confirmar e permanecer conectado"
    end

    test "renders login page for confirmed user", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/log-in/#{token}")
      html = html_response(conn, 200)
      assert html =~ "Entrar"
    end

    test "raises error for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in/invalid-token")
      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "O link é inválido ou expirou."
    end
  end

  describe "POST /users/log-in - email and password" do
    test "logs the user in", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_plataforma_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Bem-vindo de volta!"
    end

    test "emits error message with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in?mode=password", %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "Entrar"
      assert response =~ "E-mail ou senha inválidos"
    end
  end

  describe "POST /users/log-in - magic link" do
    test "sends magic link email when user exists", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) =~ "/users/log-in?sent=true"
      assert Plataforma.Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "login"
    end

    test "logs the user in", %{conn: conn, user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "confirms unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)
      refute user.confirmed_at

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Identidade confirmada com sucesso."

      assert Accounts.get_user!(user.id).confirmed_at
    end

    test "emits error message when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => "invalid"}
        })

      assert html_response(conn, 200) =~ "O link é inválido ou expirou."
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Sessão encerrada com sucesso."
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Sessão encerrada com sucesso."
    end
  end

  describe "GET /users/log-in?reauth=true" do
    test "renders reauth page with sidebar hidden", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/users/log-in?reauth=true")

      document = conn |> html_response(200) |> LazyHTML.from_document()
      assert html_response(conn, 200) =~ "Confirme sua senha"
      assert html_response(conn, 200) =~ "Por segurança, confirme sua senha"
      assert html_response(conn, 200) =~ "Sua sessão continua ativa"
      refute html_response(conn, 200) =~ "Ainda não possui uma conta?"
      refute html_response(conn, 200) =~ "Criar conta"
    end
  end

  describe "POST /users/log-in?reauth=true" do
    test "resets sudo mode and redirects to settings with correct password", %{
      conn: conn,
      user: user
    } do
      {:ok, {user, _tokens}} =
        Plataforma.Accounts.update_user_password(user, %{
          password: valid_user_password(),
          password_confirmation: valid_user_password()
        })

      conn =
        conn
        |> log_in_user(user)
        |> init_test_session(user_return_to: "/users/settings")
        |> post(~p"/users/log-in?reauth=true", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == "/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Identidade confirmada"
    end

    test "stays on reauth page with error for wrong password", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> init_test_session(user_return_to: "/users/settings")
        |> post(~p"/users/log-in?reauth=true", %{
          "user" => %{
            "email" => user.email,
            "password" => "wrong_password"
          }
        })

      assert html_response(conn, 200) =~ "Confirme sua senha"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "E-mail ou senha inválidos"
    end

    test "preserves return_to URL after successful reauth", %{conn: conn, user: user} do
      {:ok, {user, _tokens}} =
        Plataforma.Accounts.update_user_password(user, %{
          password: valid_user_password(),
          password_confirmation: valid_user_password()
        })

      conn =
        conn
        |> log_in_user(user)
        |> init_test_session(user_return_to: "/users/settings")
        |> post(~p"/users/log-in?reauth=true", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/users/settings"
    end
  end
end
