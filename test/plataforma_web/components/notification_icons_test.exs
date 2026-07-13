defmodule PlataformaWeb.NotificationIconsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias PlataformaWeb.NotificationIcons

  test "renders info icon with blue color" do
    html = render_component(&NotificationIcons.status_icon/1, status: :info)
    assert html =~ "#0f62fe"
    assert html =~ "information"
  end

  test "renders success icon with green color" do
    html = render_component(&NotificationIcons.status_icon/1, status: :success)
    assert html =~ "#24a148"
    assert html =~ "checkmark"
  end

  test "renders warning icon with yellow color" do
    html = render_component(&NotificationIcons.status_icon/1, status: :warning)
    assert html =~ "#f1c21b"
    assert html =~ "warning"
  end

  test "renders error icon with red color" do
    html = render_component(&NotificationIcons.status_icon/1, status: :error)
    assert html =~ "#da1e28"
    assert html =~ "error"
  end
end
