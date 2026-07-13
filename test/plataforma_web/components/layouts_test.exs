defmodule PlataformaWeb.LayoutsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias PlataformaWeb.Layouts

  @current_scope %{user: %{name: "Test User", email: "test@example.com"}}

  test "dropdown shows status icon for each notification" do
    notification = %{id: "1", title: "Test", body: "Body", read_at: nil, status: :info, inserted_at: DateTime.utc_now()}
    html = render_component(&Layouts.app_header/1, notification_summary: %{unread_count: 1, notifications: [notification]}, current_scope: @current_scope, current_path: "/")
    assert html =~ "notification-status-icon"
  end

  test "dropdown shows close button for all notifications regardless of read status" do
    unread = %{id: "1", title: "Unread", body: "Body", read_at: nil, status: :info, inserted_at: DateTime.utc_now()}
    read = %{id: "2", title: "Read", body: "Body", read_at: DateTime.utc_now(), status: :info, inserted_at: DateTime.utc_now()}
    html = render_component(&Layouts.app_header/1, notification_summary: %{unread_count: 1, notifications: [unread, read]}, current_scope: @current_scope, current_path: "/")
    assert html =~ "Fechar notificação"
  end
end
