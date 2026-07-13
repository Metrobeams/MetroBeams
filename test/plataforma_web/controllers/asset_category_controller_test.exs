defmodule PlataformaWeb.AssetCategoryControllerTest do
  use PlataformaWeb.ConnCase, async: true

  import Plataforma.AccountsFixtures

  alias Plataforma.Assets
  alias Plataforma.Organizations

  setup :register_and_log_in_user

  setup %{user: user} do
    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{name: "Org #{System.unique_integer([:positive])}"})

    %{organization: organization}
  end

  describe "index" do
    test "lists all asset categories", %{conn: conn, organization: organization} do
      {:ok, _category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      conn = get(conn, ~p"/asset-categories")
      assert html_response(conn, 200) =~ "Notebooks"
    end
  end

  describe "new asset_category" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/asset-categories/new")
      assert html_response(conn, 200) =~ "Nova Categoria"
    end
  end

  describe "create asset_category" do
    test "redirects to index when data is valid", %{conn: conn, organization: organization} do
      conn =
        post(conn, ~p"/asset-categories", %{
          asset_category: %{name: "Notebooks", description: "Laptops"}
        })

      assert redirected_to(conn) == ~p"/asset-categories"

      conn = get(conn, ~p"/asset-categories")
      assert html_response(conn, 200) =~ "Notebooks"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/asset-categories", %{
          asset_category: %{name: nil}
        })

      assert html_response(conn, 422) =~ "erro"
    end
  end

  describe "edit asset_category" do
    test "renders form for editing chosen asset_category", %{
      conn: conn,
      organization: organization
    } do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      conn = get(conn, ~p"/asset-categories/#{category}/edit")
      assert html_response(conn, 200) =~ "Editar Categoria"
    end
  end

  describe "update asset_category" do
    test "redirects to index when data is valid", %{conn: conn, organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      conn =
        put(conn, ~p"/asset-categories/#{category}", %{
          asset_category: %{name: "Laptops"}
        })

      assert redirected_to(conn) == ~p"/asset-categories"

      conn = get(conn, ~p"/asset-categories")
      assert html_response(conn, 200) =~ "Laptops"
    end

    test "renders errors when data is invalid", %{conn: conn, organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      conn =
        put(conn, ~p"/asset-categories/#{category}", %{
          asset_category: %{name: nil}
        })

      assert html_response(conn, 422) =~ "erro"
    end
  end

  describe "delete asset_category" do
    test "deactivates the chosen asset_category", %{conn: conn, organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      conn = delete(conn, ~p"/asset-categories/#{category}")
      assert redirected_to(conn) == ~p"/asset-categories"

      category = Assets.get_category!(organization.id, category.id)
      assert category.active == false
    end
  end
end
