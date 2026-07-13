defmodule PlataformaWeb.NotificationCloseButtonTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias PlataformaWeb.NotificationCloseButton

  test "renders close button with correct aria label" do
    html =
      render_component(&NotificationCloseButton.close_button/1,
        notification_id: "123",
        action: "/notifications/123/read"
      )

    assert html =~ "Fechar notificação"
    assert html =~ "type=\"submit\""
  end
end
