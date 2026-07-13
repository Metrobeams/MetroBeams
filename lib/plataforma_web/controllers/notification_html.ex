defmodule PlataformaWeb.NotificationHTML do
  use PlataformaWeb, :html

  embed_templates "notification_html/*"

  defp status_color(:info), do: "#0f62fe"
  defp status_color(:success), do: "#24a148"
  defp status_color(:warning), do: "#f1c21b"
  defp status_color(:error), do: "#da1e28"
  defp status_color(_), do: "#0f62fe"
end
