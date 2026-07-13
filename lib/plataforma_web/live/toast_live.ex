defmodule PlataformaWeb.ToastLive do
  use PlataformaWeb, :live_view

  alias PlataformaWeb.ToastContainer

  def mount(_params, _session, socket) do
    {:ok, assign(socket, toasts: [])}
  end

  def handle_event("close-toast", %{"id" => id}, socket) do
    toasts = Enum.reject(socket.assigns.toasts, &(&1.id == id))
    {:noreply, assign(socket, toasts: toasts)}
  end

  def handle_info({:show_toast, toast}, socket) do
    toasts = [toast | socket.assigns.toasts] |> Enum.take(3)
    {:noreply, assign(socket, toasts: toasts)}
  end

  def render(assigns) do
    ~H"""
    <ToastContainer.toast_container toasts={@toasts} />
    """
  end
end
