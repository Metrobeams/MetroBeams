defmodule PlataformaWeb.Plugs.FetchNotifications do
  import Plug.Conn

  alias Plataforma.Notifications

  def init(opts), do: opts

  def call(%{assigns: %{current_scope: %{user: user}}} = conn, _opts) do
    assign(conn, :notification_summary, Notifications.summary(user))
  end

  def call(conn, _opts) do
    assign(conn, :notification_summary, %{unread_count: 0, notifications: []})
  end
end
