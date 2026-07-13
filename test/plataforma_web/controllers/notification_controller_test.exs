defmodule PlataformaWeb.NotificationControllerTest do
  use PlataformaWeb.ConnCase, async: true

  import Plataforma.AccountsFixtures

  alias Plataforma.Notifications

  setup :register_and_log_in_user

  setup %{user: user} do
    {:ok, notification} = Notifications.create_notification(user, notification_attrs())
    %{notification: notification}
  end

  test "GET /notifications requires authentication" do
    conn = build_conn() |> get(~p"/notifications")
    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "GET /notifications lists only the current user's history", context do
    other_user = user_fixture()
    {:ok, foreign} = Notifications.create_notification(other_user, notification_attrs())

    document =
      context.conn
      |> get(~p"/notifications")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert document
           |> LazyHTML.query("#notification-#{context.notification.id}")
           |> Enum.count() == 1

    assert document |> LazyHTML.query("#notification-#{foreign.id}") |> Enum.empty?()
  end

  test "PATCH /notifications/:id/read marks an owned notification and follows its internal action",
       context do
    conn = patch(context.conn, ~p"/notifications/#{context.notification.id}/read")

    assert redirected_to(conn) == context.notification.action_path
    assert Notifications.summary(context.user).unread_count == 0
  end

  test "PATCH /notifications/:id/read returns 404 for another user's notification", context do
    other_user = user_fixture()
    {:ok, foreign} = Notifications.create_notification(other_user, notification_attrs())

    conn = patch(context.conn, ~p"/notifications/#{foreign.id}/read")

    assert response(conn, 404)
    assert Notifications.summary(other_user).unread_count == 1
    assert Notifications.summary(context.user).unread_count == 1
  end

  test "PATCH /notifications/read-all marks all current user notifications", context do
    {:ok, _second} = Notifications.create_notification(context.user, notification_attrs())

    conn = patch(context.conn, ~p"/notifications/read-all")

    assert redirected_to(conn) == ~p"/notifications"
    assert Notifications.summary(context.user).unread_count == 0
  end

  test "GET /notifications shows status icons for unread notifications", %{conn: conn, user: user} do
    {:ok, _notification} =
      Notifications.create_notification(user, %{
        status: :success,
        title: "Test Success",
        body: "Body",
        kind: :organization_invitation,
        dedupe_key: "test-success"
      })

    document =
      conn
      |> get(~p"/notifications")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert document |> LazyHTML.query(".notification-status-icon") |> Enum.count() > 0
  end

  test "GET /notifications shows close button for unread notifications", %{conn: conn, user: user} do
    {:ok, _notification} =
      Notifications.create_notification(user, %{
        status: :success,
        title: "Test Close",
        body: "Body",
        kind: :organization_invitation,
        dedupe_key: "test-close"
      })

    document =
      conn
      |> get(~p"/notifications")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert document |> LazyHTML.query(".notification-close-btn") |> Enum.count() > 0
  end

  test "GET /notifications uses status-specific left border for unread notifications", %{conn: conn, user: user} do
    {:ok, notification} =
      Notifications.create_notification(user, %{
        status: :warning,
        title: "Test Warning",
        body: "Body",
        kind: :organization_invitation,
        dedupe_key: "test-warning"
      })

    document =
      conn
      |> get(~p"/notifications")
      |> html_response(200)
      |> LazyHTML.from_document()

    [notification_el] = document |> LazyHTML.query("#notification-#{notification.id}") |> Enum.to_list()
    [class_attr] = LazyHTML.attribute(notification_el, "class")
    assert class_attr =~ "border-l-[#f1c21b]"
  end

  test "GET /notifications shows status-specific left border color per status", %{conn: conn, user: user} do
    {:ok, success_notif} =
      Notifications.create_notification(user, %{
        status: :success,
        title: "Success",
        body: "Body",
        kind: :organization_invitation,
        dedupe_key: "test-success-border"
      })

    {:ok, error_notif} =
      Notifications.create_notification(user, %{
        status: :error,
        title: "Error",
        body: "Body",
        kind: :organization_invitation,
        dedupe_key: "test-error-border"
      })

    document =
      conn
      |> get(~p"/notifications")
      |> html_response(200)
      |> LazyHTML.from_document()

    [success_el] = document |> LazyHTML.query("#notification-#{success_notif.id}") |> Enum.to_list()
    [error_el] = document |> LazyHTML.query("#notification-#{error_notif.id}") |> Enum.to_list()

    [success_class] = LazyHTML.attribute(success_el, "class")
    [error_class] = LazyHTML.attribute(error_el, "class")

    assert success_class =~ "border-l-[#24a148]"
    assert error_class =~ "border-l-[#da1e28]"
  end

  defp notification_attrs do
    %{
      kind: :organization_invitation,
      title: "Convite disponível",
      body: "Você possui uma nova ação.",
      action_path: "/notifications",
      dedupe_key: "controller-test:#{Ecto.UUID.generate()}"
    }
  end
end
