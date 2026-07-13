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
      assert html_response(conn, 200) =~ "notebooks"
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
      assert html_response(conn, 200) =~ "notebooks"
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
      assert html_response(conn, 200) =~ "laptops"
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

  describe "authorization" do
    test "user from another tenant sees only their categories", %{
      conn: conn,
      organization: organization
    } do
      # Create another user with their own organization
      other_user = user_fixture()

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(other_user, %{name: "Other Org"})

      # Create a category in the other organization
      {:ok, _other_category} = Assets.create_category(other_org.id, %{name: "Desktops"})

      # Create a category in the current organization
      {:ok, _category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      # User should only see their own organization's categories
      conn = get(conn, ~p"/asset-categories")
      response = html_response(conn, 200)
      assert response =~ "notebooks"
      refute response =~ "desktops"
    end

    test "user without organization is redirected", %{user: _user} do
      # Create a new user without any organization
      new_user = user_fixture()

      # Login as the new user
      conn =
        build_conn()
        |> Plug.Test.init_test_session(
          user_token: Plataforma.Accounts.generate_user_session_token(new_user)
        )

      conn = get(conn, ~p"/asset-categories")
      assert html_response(conn, 302)
      assert redirected_to(conn) == ~p"/"
    end

    test "member role is redirected when trying to access categories", %{
      organization: organization
    } do
      # Create a member user
      member_user = user_fixture()

      # Directly create membership with member role
      {:ok, _membership} =
        Plataforma.Repo.insert(%Plataforma.Organizations.Membership{
          organization_id: organization.id,
          user_id: member_user.id,
          role: :member,
          active: true
        })

      # Login as member
      conn =
        build_conn()
        |> Plug.Test.init_test_session(
          user_token: Plataforma.Accounts.generate_user_session_token(member_user)
        )

      # Try to access categories - should be redirected
      conn = get(conn, ~p"/asset-categories")
      assert html_response(conn, 302)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "não tem permissão"
    end

    test "technician role can access categories", %{organization: organization} do
      # Create a technician user
      technician_user = user_fixture()

      # Directly create membership with technician role
      {:ok, _membership} =
        Plataforma.Repo.insert(%Plataforma.Organizations.Membership{
          organization_id: organization.id,
          user_id: technician_user.id,
          role: :technician,
          active: true
        })

      # Login as technician
      conn =
        build_conn()
        |> Plug.Test.init_test_session(
          user_token: Plataforma.Accounts.generate_user_session_token(technician_user)
        )

      # Technician should be able to access categories
      conn = get(conn, ~p"/asset-categories")
      assert html_response(conn, 200)
    end

    test "admin role can access categories", %{organization: organization} do
      # Create an admin user
      admin_user = user_fixture()

      # Directly create membership with admin role
      {:ok, _membership} =
        Plataforma.Repo.insert(%Plataforma.Organizations.Membership{
          organization_id: organization.id,
          user_id: admin_user.id,
          role: :admin,
          active: true
        })

      # Login as admin
      conn =
        build_conn()
        |> Plug.Test.init_test_session(
          user_token: Plataforma.Accounts.generate_user_session_token(admin_user)
        )

      # Admin should be able to access categories
      conn = get(conn, ~p"/asset-categories")
      assert html_response(conn, 200)
    end

    test "owner role can access categories", %{conn: conn} do
      # Owner is the user who created the organization (from setup)
      # They should be able to access categories
      conn = get(conn, ~p"/asset-categories")
      assert html_response(conn, 200)
    end
  end
end
