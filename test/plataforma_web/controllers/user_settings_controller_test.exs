defmodule PlataformaWeb.UserSettingsControllerTest do
  use PlataformaWeb.ConnCase, async: true

  alias Plataforma.Accounts
  alias Plataforma.{ImageProcessorMock, Repo, StorageMock}
  import Mox
  import Plataforma.AccountsFixtures

  setup :verify_on_exit!
  setup :register_and_log_in_user

  describe "GET /users/settings" do
    test "renders settings page", %{conn: conn} do
      conn = get(conn, ~p"/users/settings")
      response = html_response(conn, 200)
      assert response =~ "Conta"
    end

    test "renders accessible avatar controls with preview support", %{conn: conn} do
      document =
        conn |> get(~p"/users/settings") |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("#avatar-settings") |> Enum.count() == 1

      assert document
             |> LazyHTML.query("#avatar-preview[src='/images/default-avatar.svg']")
             |> Enum.count() == 1

      assert document |> LazyHTML.query("#avatar-upload-form[data-avatar-form]") |> Enum.count() ==
               1

      assert document
             |> LazyHTML.query("#avatar-input[accept='image/jpeg,image/png,image/webp']")
             |> Enum.count() == 1

      assert document |> LazyHTML.query("#avatar-submit[data-loading-label]") |> Enum.count() == 1
    end

    test "redirects if user is not logged in" do
      conn = build_conn()
      conn = get(conn, ~p"/users/settings")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    @tag token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
    test "redirects if user is not in sudo mode", %{conn: conn} do
      conn = get(conn, ~p"/users/settings")
      assert redirected_to(conn) == ~p"/users/log-in?reauth=true"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Você precisa confirmar sua identidade para acessar esta página."
    end
  end

  describe "PUT /users/settings/avatar" do
    test "uploads an avatar and returns to settings", context do
      source_path =
        Path.join(System.tmp_dir!(), "settings-source-#{System.unique_integer([:positive])}")

      output_path =
        Path.join(System.tmp_dir!(), "settings-output-#{System.unique_integer([:positive])}.webp")

      File.write!(source_path, :crypto.strong_rand_bytes(32))
      File.write!(output_path, :crypto.strong_rand_bytes(64))

      on_exit(fn ->
        File.rm(source_path)
        File.rm(output_path)
      end)

      processed = %{
        path: output_path,
        content_type: "image/webp",
        size: File.stat!(output_path).size
      }

      expect(ImageProcessorMock, :process, fn ^source_path -> {:ok, processed} end)
      expect(StorageMock, :put, fn _key, ^output_path, "image/webp" -> :ok end)

      upload = %Plug.Upload{path: source_path, filename: "avatar.png", content_type: "image/png"}
      conn = put(context.conn, ~p"/users/settings/avatar", %{avatar: upload})

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info)
      assert Repo.reload!(context.user).avatar_key
    end
  end

  describe "PUT /users/settings (change password form)" do
    test "updates the user password and resets tokens", %{conn: conn, user: user} do
      new_password_conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_password",
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == ~p"/users/settings"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_password",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(old_password_conn, 200)
      assert response =~ "Conta"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"

      assert get_session(old_password_conn, :user_token) == get_session(conn, :user_token)
    end
  end

  describe "PUT /users/settings (change email form)" do
    @tag :capture_log
    test "updates the user email", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_email",
          "user" => %{"email" => unique_user_email()}
        })

      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "A link to confirm your email"

      assert Accounts.get_user_by_email(user.email)
    end

    test "does not update email on invalid data", %{conn: conn} do
      conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_email",
          "user" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      assert response =~ "Conta"
      assert response =~ "must have the @ sign and no spaces"
    end
  end

  describe "GET /users/settings/confirm-email/:token" do
    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      conn = get(conn, ~p"/users/settings/confirm-email/#{token}")
      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Email changed successfully"

      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      conn = get(conn, ~p"/users/settings/confirm-email/#{token}")

      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, ~p"/users/settings/confirm-email/oops")
      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"

      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, ~p"/users/settings/confirm-email/#{token}")
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end
end
