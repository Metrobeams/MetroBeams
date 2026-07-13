defmodule PlataformaWeb.NotificationIcons do
  @moduledoc """
  SVG icon components for notification types (info, success, warning, error).
  """

  use Phoenix.Component

  @icon_colors %{
    info: "#0f62fe",
    success: "#24a148",
    warning: "#f1c21b",
    error: "#da1e28"
  }

  @icon_names %{
    info: "information--filled",
    success: "checkmark--filled",
    warning: "warning--filled",
    error: "error--filled"
  }

  @icon_paths %{
    info:
      "M11 15h2v2h-2zm0-8h2v6h-2zm.93-6.37l-1.42.5A9.966 9.966 0 0 0 8 2a10 10 0 0 0-10 10 10 10 0 0 0 10 10 10 10 0 0 0 9.93-8.63l-1.42-.5A8 8 0 1 1 8 0a8 8 0 0 1 7.93 6.63z",
    success:
      "M16 48a48 48 0 1 1 48-48 48 48 0 0 1-48 48zm21.89-76.29l-21-21a1.47 1.47 0 0 0-2.08 0l-25 25a1.42 1.42 0 0 0 0 2l21 21a1.47 1.47 0 0 0 2.08 0l25-25a1.42 1.42 0 0 0 0-2z",
    warning:
      "M46.07 34.51l-19-28A2 2 0 0 0 25.39 5h-.78a2 2 0 0 0-1.68.92l-19 28A2 2 0 0 0 4.61 37h38.78a2 2 0 0 0 1.68-2.49zM24 30a2 2 0 0 1-2-2v-4a2 2 0 0 1 4 0v4a2 2 0 0 1-2 2zm4 12a2 2 0 0 1-2 2h-4a2 2 0 0 1 0-4h4a2 2 0 0 1 2 2z",
    error:
      "M34.5 30.3L13.9 5.9a1.5 1.5 0 0 0-2.6 0L.5 30.3a1.5 1.5 0 0 0 1.3 2.2h39.4a1.5 1.5 0 0 0 1.3-2.2zM23 36a2 2 0 1 1 2-2 2 2 0 0 1-2 2zm4-12a2 2 0 0 1-4 0V16a2 2 0 0 1 4 0z"
  }

  attr :status, :atom, required: true
  attr :class, :string, default: ""

  def status_icon(assigns) do
    color = @icon_colors[assigns.status]
    path = @icon_paths[assigns.status]
    icon_name = @icon_names[assigns.status]

    assigns =
      assigns
      |> assign(:color, color)
      |> assign(:path, path)
      |> assign(:icon_name, icon_name)

    ~H"""
    <svg
      class={["notification-status-icon", @class]}
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 48 48"
      width="16"
      height="16"
      data-icon={@icon_name}
    >
      <path fill={@color} d={@path} />
    </svg>
    """
  end
end
