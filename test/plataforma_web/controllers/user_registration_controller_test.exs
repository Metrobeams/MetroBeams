defmodule PlataformaWeb.UserRegistrationControllerTest do
  use PlataformaWeb.ConnCase, async: true

  import Plataforma.AccountsFixtures
  alias Plataforma.Accounts

  describe "GET /users/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      document = conn |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("#app-content.max-w-7xl") |> Enum.count() == 1

      assert LazyHTML.attribute(
               LazyHTML.query(document, "#registration-page"),
               "data-design-system"
             ) == ["carbon"]

      assert document |> LazyHTML.query("#registration-form") |> Enum.count() == 1

      assert document |> LazyHTML.query("#registration-name[name='user[name]']") |> Enum.count() ==
               1

      assert LazyHTML.attribute(
               LazyHTML.query(document, "#registration-form"),
               "action"
             ) == [~p"/users/register"]

      assert LazyHTML.attribute(
               LazyHTML.query(document, "#registration-login-link"),
               "href"
             ) == [~p"/users/log-in"]
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/users/register")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /users/register" do
    @tag :capture_log
    test "creates account but does not log in", %{conn: conn} do
      email = unique_user_email()
      name = unique_user_name()

      conn =
        post(conn, ~p"/users/register", %{
          "user" => valid_user_attributes(email: email, name: name)
        })

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Accounts.get_user_by_email(email).name == name

      assert conn.assigns.flash["info"] =~
               ~r/An email was sent to .*, please access it to confirm your account/
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{"email" => "with spaces"}
        })

      document = conn |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("#registration-form") |> Enum.count() == 1

      assert document
             |> LazyHTML.query("#registration-form p")
             |> LazyHTML.text() =~ "must have the @ sign and no spaces"
    end
  end
end
