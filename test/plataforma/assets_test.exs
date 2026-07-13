defmodule Plataforma.AssetsTest do
  use Plataforma.DataCase, async: true

  import Plataforma.AccountsFixtures

  alias Plataforma.Assets
  alias Plataforma.Assets.AssetCategory
  alias Plataforma.Organizations

  describe "asset_categories" do
    setup do
      user = user_fixture()

      {:ok, %{organization: organization}} =
        Organizations.create_organization(user, %{
          name: "Org #{System.unique_integer([:positive])}"
        })

      membership = Organizations.get_active_membership(user, organization)

      %{user: user, organization: organization, membership: membership}
    end

    test "list_categories/2 returns only organization categories", %{organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})
      assert Assets.list_categories(organization.id) == [category]
    end

    test "list_categories/2 does not return categories from other organizations", %{
      user: user,
      organization: organization
    } do
      {:ok, _category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      {:ok, other_category} = Assets.create_category(other_org.id, %{name: "Desktops"})

      categories = Assets.list_categories(organization.id)
      refute Enum.any?(categories, &(&1.id == other_category.id))
    end

    test "get_category!/2 returns the category with given id", %{organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})
      assert Assets.get_category!(organization.id, category.id) == category
    end

    test "get_category!/2 raises for id from another organization", %{
      user: user,
      organization: organization
    } do
      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      {:ok, other_category} = Assets.create_category(other_org.id, %{name: "Desktops"})

      assert_raise Ecto.NoResultsError, fn ->
        Assets.get_category!(organization.id, other_category.id)
      end
    end

    test "create_category/2 with valid data creates a category", %{organization: organization} do
      valid_attrs = %{name: "Notebooks", description: "Laptops e notebooks"}

      assert {:ok, %AssetCategory{} = category} =
               Assets.create_category(organization.id, valid_attrs)

      assert category.name == "Notebooks"
      assert category.description == "Laptops e notebooks"
      assert category.organization_id == organization.id
      assert category.active == true
    end

    test "create_category/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      assert {:error, %Ecto.Changeset{}} =
               Assets.create_category(organization.id, %{name: nil})
    end

    test "create_category/2 with duplicate name in same organization returns error", %{
      organization: organization
    } do
      {:ok, _category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      assert {:error, changeset} =
               Assets.create_category(organization.id, %{name: "Notebooks"})

      assert "já existe uma categoria com este nome nesta organização" in errors_on(changeset).name
    end

    test "create_category/2 with same name in different organization succeeds", %{
      user: user,
      organization: organization
    } do
      {:ok, _category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      assert {:ok, %AssetCategory{}} = Assets.create_category(other_org.id, %{name: "Notebooks"})
    end

    test "update_category/2 with valid data updates the category", %{organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      update_attrs = %{name: "Laptops", description: "Atualizado"}

      assert {:ok, %AssetCategory{} = category} =
               Assets.update_category(organization.id, category, update_attrs)

      assert category.name == "Laptops"
      assert category.description == "Atualizado"
    end

    test "update_category/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      assert {:error, %Ecto.Changeset{}} =
               Assets.update_category(organization.id, category, %{name: nil})

      assert category == Assets.get_category!(organization.id, category.id)
    end

    test "delete_category/1 deactivates the category", %{organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})
      assert {:ok, %AssetCategory{}} = Assets.delete_category(category)

      category = Assets.get_category!(organization.id, category.id)
      assert category.active == false
    end

    test "change_category/1 returns a category changeset", %{organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})
      assert %Ecto.Changeset{} = Assets.change_category(category)
    end
  end
end
