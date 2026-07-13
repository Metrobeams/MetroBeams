defmodule PlataformaWeb.ErrorJSONTest do
  use PlataformaWeb.ConnCase, async: true

  test "renders 404" do
    assert PlataformaWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert PlataformaWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
