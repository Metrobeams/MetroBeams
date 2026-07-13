defmodule PlataformaWeb.AssetCategoryNewButtonTest do
  use PlataformaWeb.ConnCase, async: true

  alias Plataforma.Organizations

  setup :register_and_log_in_user

  setup %{user: user} do
    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{
        name: "Org #{System.unique_integer([:positive])}"
      })

    %{organization: organization}
  end

  test "renders an explicit submit action and cancel navigation", %{conn: conn} do
    document =
      conn
      |> get(~p"/asset-categories/new")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert document
           |> LazyHTML.query("#asset-category-new[data-design-system='carbon']")
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query(
             "form[action='/asset-categories'] button[type='submit'][data-carbon-button='primary']"
           )
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query("form[action='/asset-categories'] a[href='/asset-categories']")
           |> Enum.count() == 1
  end
end
