defmodule PlataformaWeb.NotificationCloseButton do
  use Phoenix.Component

  attr :notification_id, :string, required: true
  attr :action, :string, required: true

  def close_button(assigns) do
    ~H"""
    <.form for={%{}} action={@action} method="patch">
      <button
        type="submit"
        class="notification-close-btn"
        aria-label="Fechar notificação"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="16" height="16">
          <path fill="currentColor" d="M24 9.4L22.6 8 16 14.6 9.4 8 8 9.4l6.6 6.6L8 22.6 9.4 24l6.6-6.6 6.6 6.6 1.4-1.4-6.6-6.6z" />
        </svg>
      </button>
    </.form>
    """
  end
end
