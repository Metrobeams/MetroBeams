defmodule PlataformaWeb.ToastContainerTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias PlataformaWeb.ToastContainer

  test "renders toast container with correct id" do
    html = render_component(&ToastContainer.toast_container/1, toasts: [])
    assert html =~ "id=\"toast-container\""
  end

  test "renders toast with status icon" do
    toast = %{id: "1", status: :info, title: "Test", body: "Body"}
    html = render_component(&ToastContainer.toast_container/1, toasts: [toast])
    assert html =~ "notification-status-icon"
    assert html =~ "Test"
  end
end
