defmodule Plataforma.AssetsTest do
  use Plataforma.DataCase, async: true

  import Plataforma.AccountsFixtures

  alias Plataforma.Assets
  alias Plataforma.Assets.AssetCategory
  alias Plataforma.Assets.Supplier
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

      assert category.name == "notebooks"
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

      assert category.name == "laptops"
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

    test "delete_category/1 deactivates the category but preserves the record", %{
      organization: organization
    } do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})
      assert {:ok, %AssetCategory{}} = Assets.delete_category(category)

      # Record still exists but is inactive
      category = Assets.get_category!(organization.id, category.id)
      assert category.active == false

      # Can recreate with same name after soft delete
      assert {:ok, %AssetCategory{} = new_category} =
               Assets.create_category(organization.id, %{name: "Notebooks"})

      assert new_category.id != category.id
    end

    test "inactive categories do not appear in list_categories", %{organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})
      {:ok, _} = Assets.create_category(organization.id, %{name: "Desktops"})

      # Deactivate one category
      {:ok, _} = Assets.delete_category(category)

      categories = Assets.list_categories(organization.id)
      assert length(categories) == 1
      assert hd(categories).name == "desktops"
    end

    test "create_category/2 ignores organization_id from client", %{organization: organization} do
      # Try to inject a different organization_id
      other_org_id = Ecto.UUID.generate()

      {:ok, category} =
        Assets.create_category(organization.id, %{
          name: "Notebooks",
          organization_id: other_org_id
        })

      # Should use the provided organization_id, not the injected one
      assert category.organization_id == organization.id
    end

    test "create_category/2 ignores active field from client", %{organization: organization} do
      {:ok, category} =
        Assets.create_category(organization.id, %{
          name: "Notebooks",
          active: false
        })

      # Should default to active: true regardless of input
      assert category.active == true
    end

    test "get_category!/2 raises for invalid UUID", %{organization: organization} do
      assert_raise Ecto.Query.CastError, fn ->
        Assets.get_category!(organization.id, "invalid-uuid")
      end
    end

    test "get_category!/2 raises for nil UUID", %{organization: organization} do
      assert_raise ArgumentError, fn ->
        Assets.get_category!(organization.id, nil)
      end
    end

    test "get_category!/2 raises for non-existent UUID", %{organization: organization} do
      fake_uuid = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Assets.get_category!(organization.id, fake_uuid)
      end
    end

    test "change_category/1 returns a category changeset", %{organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})
      assert %Ecto.Changeset{} = Assets.change_category(category)
    end

    # Case insensitivity and trimming tests

    test "create_category/2 trims and downcases name", %{organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "  Notebook  "})
      assert category.name == "notebook"
    end

    test "create_category/2 downcases name", %{organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "NOTEBOOK"})
      assert category.name == "notebook"
    end

    test "create_category/2 with 'Notebook' and 'notebook' are considered duplicates", %{
      organization: organization
    } do
      {:ok, _category} = Assets.create_category(organization.id, %{name: "Notebook"})

      assert {:error, changeset} =
               Assets.create_category(organization.id, %{name: "notebook"})

      assert "já existe uma categoria com este nome nesta organização" in errors_on(changeset).name
    end

    test "Notebook can exist in different tenants", %{user: user, organization: organization} do
      {:ok, _category} = Assets.create_category(organization.id, %{name: "Notebook"})

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      assert {:ok, %AssetCategory{}} = Assets.create_category(other_org.id, %{name: "Notebook"})
    end

    test "after deactivating Notebook, it is possible to create notebook again", %{
      organization: organization
    } do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebook"})
      {:ok, _} = Assets.delete_category(category)

      # Should be able to create with same name (case insensitive)
      assert {:ok, %AssetCategory{} = new_category} =
               Assets.create_category(organization.id, %{name: "notebook"})

      assert new_category.name == "notebook"
      assert new_category.id != category.id
    end

    test "update_category/2 trims and downcases name", %{organization: organization} do
      {:ok, category} = Assets.create_category(organization.id, %{name: "Notebooks"})

      {:ok, updated} = Assets.update_category(organization.id, category, %{name: "  LAPTOPS  "})
      assert updated.name == "laptops"
    end
  end

  describe "suppliers" do
    setup do
      user = user_fixture()

      {:ok, %{organization: organization}} =
        Organizations.create_organization(user, %{
          name: "Org #{System.unique_integer([:positive])}"
        })

      membership = Organizations.get_active_membership(user, organization)

      %{user: user, organization: organization, membership: membership}
    end

    test "list_suppliers/1 returns only active suppliers for the organization", %{
      organization: organization
    } do
      {:ok, supplier} = Assets.create_supplier(organization.id, %{name: "Dell"})
      assert Assets.list_suppliers(organization.id) == [supplier]
    end

    test "list_suppliers/1 does not return suppliers from other organizations", %{
      user: user,
      organization: organization
    } do
      {:ok, _supplier} = Assets.create_supplier(organization.id, %{name: "Dell"})

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      {:ok, other_supplier} = Assets.create_supplier(other_org.id, %{name: "HP"})

      suppliers = Assets.list_suppliers(organization.id)
      refute Enum.any?(suppliers, &(&1.id == other_supplier.id))
    end

    test "get_supplier!/2 returns the supplier with given id", %{organization: organization} do
      {:ok, supplier} = Assets.create_supplier(organization.id, %{name: "Dell"})
      assert Assets.get_supplier!(organization.id, supplier.id) == supplier
    end

    test "get_supplier!/2 raises for id from another organization", %{
      user: user,
      organization: organization
    } do
      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      {:ok, other_supplier} = Assets.create_supplier(other_org.id, %{name: "HP"})

      assert_raise Ecto.NoResultsError, fn ->
        Assets.get_supplier!(organization.id, other_supplier.id)
      end
    end

    test "create_supplier/2 with valid data creates a supplier", %{organization: organization} do
      valid_attrs = %{
        name: "Dell",
        contact_name: "João Silva",
        email: "contato@dell.com.br",
        phone: "(11) 99999-9999",
        website: "https://dell.com.br",
        cnpj: "12.345.678/0001-90",
        address: "Rua Exemplo, 123"
      }

      assert {:ok, %Supplier{} = supplier} =
               Assets.create_supplier(organization.id, valid_attrs)

      assert supplier.name == "dell"
      assert supplier.contact_name == "João Silva"
      assert supplier.email == "contato@dell.com.br"
      assert supplier.phone == "(11) 99999-9999"
      assert supplier.website == "https://dell.com.br"
      assert supplier.cnpj == "12.345.678/0001-90"
      assert supplier.address == "Rua Exemplo, 123"
      assert supplier.organization_id == organization.id
      assert supplier.active == true
    end

    test "create_supplier/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      assert {:error, %Ecto.Changeset{}} =
               Assets.create_supplier(organization.id, %{name: nil})
    end

    test "create_supplier/2 with duplicate name in same organization returns error", %{
      organization: organization
    } do
      {:ok, _supplier} = Assets.create_supplier(organization.id, %{name: "Dell"})

      assert {:error, changeset} =
               Assets.create_supplier(organization.id, %{name: "Dell"})

      assert "já existe um fornecedor com este nome nesta organização" in errors_on(changeset).name
    end

    test "create_supplier/2 with same name in different organization succeeds", %{
      user: user,
      organization: organization
    } do
      {:ok, _supplier} = Assets.create_supplier(organization.id, %{name: "Dell"})

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      assert {:ok, %Supplier{}} = Assets.create_supplier(other_org.id, %{name: "Dell"})
    end

    test "update_supplier/2 with valid data updates the supplier", %{organization: organization} do
      {:ok, supplier} = Assets.create_supplier(organization.id, %{name: "Dell"})

      update_attrs = %{
        name: "Dell Technologies",
        contact_name: "Maria Santos",
        email: "vendas@dell.com.br"
      }

      assert {:ok, %Supplier{} = supplier} =
               Assets.update_supplier(organization.id, supplier, update_attrs)

      assert supplier.name == "dell technologies"
      assert supplier.contact_name == "Maria Santos"
      assert supplier.email == "vendas@dell.com.br"
    end

    test "update_supplier/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      {:ok, supplier} = Assets.create_supplier(organization.id, %{name: "Dell"})

      assert {:error, %Ecto.Changeset{}} =
               Assets.update_supplier(organization.id, supplier, %{name: nil})

      assert supplier == Assets.get_supplier!(organization.id, supplier.id)
    end

    test "deactivate_supplier/1 deactivates the supplier", %{organization: organization} do
      {:ok, supplier} = Assets.create_supplier(organization.id, %{name: "Dell"})
      assert {:ok, %Supplier{} = deactivated} = Assets.deactivate_supplier(organization.id, supplier)
      assert deactivated.active == false

      # Can recreate with same name after soft delete
      assert {:ok, %Supplier{} = new_supplier} =
               Assets.create_supplier(organization.id, %{name: "Dell"})

      assert new_supplier.id != supplier.id
    end

    test "inactive suppliers do not appear in list_suppliers", %{organization: organization} do
      {:ok, supplier} = Assets.create_supplier(organization.id, %{name: "Dell"})
      {:ok, _} = Assets.create_supplier(organization.id, %{name: "HP"})

      # Deactivate one supplier
      {:ok, _} = Assets.deactivate_supplier(organization.id, supplier)

      suppliers = Assets.list_suppliers(organization.id)
      assert length(suppliers) == 1
      assert hd(suppliers).name == "hp"
    end

    test "create_supplier/2 ignores organization_id from client", %{organization: organization} do
      other_org_id = Ecto.UUID.generate()

      {:ok, supplier} =
        Assets.create_supplier(organization.id, %{
          name: "Dell",
          organization_id: other_org_id
        })

      assert supplier.organization_id == organization.id
    end

    test "create_supplier/2 ignores active field from client", %{organization: organization} do
      {:ok, supplier} =
        Assets.create_supplier(organization.id, %{
          name: "Dell",
          active: false
        })

      assert supplier.active == true
    end

    test "get_supplier!/2 raises for invalid UUID", %{organization: organization} do
      assert_raise Ecto.Query.CastError, fn ->
        Assets.get_supplier!(organization.id, "invalid-uuid")
      end
    end

    test "get_supplier!/2 raises for non-existent UUID", %{organization: organization} do
      fake_uuid = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Assets.get_supplier!(organization.id, fake_uuid)
      end
    end

    test "change_supplier/1 returns a supplier changeset", %{organization: organization} do
      {:ok, supplier} = Assets.create_supplier(organization.id, %{name: "Dell"})
      assert %Ecto.Changeset{} = Assets.change_supplier(supplier)
    end

    # Validation tests

    test "create_supplier/2 validates email format", %{organization: organization} do
      assert {:error, changeset} =
               Assets.create_supplier(organization.id, %{
                 name: "Dell",
                 email: "invalid-email"
               })

      assert "deve ser um email válido" in errors_on(changeset).email
    end

    test "create_supplier/2 validates website URL", %{organization: organization} do
      assert {:error, changeset} =
               Assets.create_supplier(organization.id, %{
                 name: "Dell",
                 website: "not-a-url"
               })

      assert "deve ser uma URL válida" in errors_on(changeset).website
    end

    test "create_supplier/2 accepts valid website URLs", %{organization: organization} do
      assert {:ok, %Supplier{}} =
               Assets.create_supplier(organization.id, %{
                 name: "Dell",
                 website: "https://dell.com.br"
               })

      assert {:ok, %Supplier{}} =
               Assets.create_supplier(organization.id, %{
                 name: "HP",
                 website: "http://hp.com.br"
               })
    end

    # Normalization tests

    test "create_supplier/2 trims and downcases name", %{organization: organization} do
      {:ok, supplier} = Assets.create_supplier(organization.id, %{name: "  Dell  "})
      assert supplier.name == "dell"
    end

    test "create_supplier/2 converts empty strings to nil", %{organization: organization} do
      {:ok, supplier} =
        Assets.create_supplier(organization.id, %{
          name: "Dell",
          contact_name: "",
          email: "",
          phone: ""
        })

      assert supplier.contact_name == nil
      assert supplier.email == nil
      assert supplier.phone == nil
    end

    # Field length validation tests

    test "create_supplier/2 rejects name longer than 120 characters", %{organization: organization} do
      long_name = String.duplicate("a", 121)

      assert {:error, changeset} =
               Assets.create_supplier(organization.id, %{name: long_name})
    end

    test "create_supplier/2 rejects notes longer than 2000 characters", %{organization: organization} do
      long_notes = String.duplicate("a", 2001)

      assert {:error, changeset} =
               Assets.create_supplier(organization.id, %{
                 name: "Dell",
                 notes: long_notes
               })
    end
  end
end
