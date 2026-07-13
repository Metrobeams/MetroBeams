defmodule PlataformaWeb.NotificationController do
  use PlataformaWeb, :controller

  alias Plataforma.Notifications

  def index(conn, params) do
    page = Notifications.list_notifications(conn.assigns.current_scope.user, params)
    render(conn, :index, notification_page: page)
  end

  def read(conn, %{"id" => notification_id}) do
    case Notifications.mark_as_read(conn.assigns.current_scope.user, notification_id) do
      {:ok, notification} -> redirect(conn, to: safe_action_path(notification.action_path))
      {:error, :not_found} -> send_resp(conn, :not_found, "Not Found")
    end
  end

  def read_all(conn, _params) do
    {:ok, _count} = Notifications.mark_all_as_read(conn.assigns.current_scope.user)
    redirect(conn, to: ~p"/notifications")
  end

  defp safe_action_path(path) when is_binary(path) do
    if String.starts_with?(path, "/") and not String.starts_with?(path, "//") do
      path
    else
      ~p"/notifications"
    end
  end

  defp safe_action_path(_path), do: ~p"/notifications"
end
