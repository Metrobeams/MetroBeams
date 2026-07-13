defmodule PlataformaWeb.ToastContainer do
  use Phoenix.Component
  alias PlataformaWeb.NotificationIcons

  attr :toasts, :list, default: []

  def toast_container(assigns) do
    ~H"""
    <div id="toast-container" class="toast-container" phx-hook="ToastHook">
      <div
        :for={toast <- @toasts}
        id={"toast-#{toast.id}"}
        class="toast-item"
        data-status={toast.status}
      >
        <div class="toast-icon">
          <NotificationIcons.status_icon status={toast.status} />
        </div>
        <div class="toast-content">
          <p class="toast-title">{toast.title}</p>
          <p :if={toast.body} class="toast-body">{toast.body}</p>
        </div>
        <button
          class="toast-close"
          aria-label="Fechar"
          phx-click="close-toast"
          phx-value-id={toast.id}
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="16" height="16">
            <path fill="currentColor" d="M24 9.4L22.6 8 16 14.6 9.4 8 8 9.4l6.6 6.6L8 22.6 9.4 24l6.6-6.6 6.6 6.6 1.4-1.4-6.6-6.6z" />
          </svg>
        </button>
      </div>
    </div>
    """
  end
end
