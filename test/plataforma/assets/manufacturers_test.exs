defmodule Plataforma.Assets.ManufacturersTest do
  use Plataforma.DataCase, async: true

  import Plataforma.AccountsFixtures

  alias Plataforma.Assets
  alias Plataforma.Assets.Manufacturer
  alias Plataforma.Organizations

  describe "manufacturers" do
    setup do
      user = user_fixture()

      {:ok, %{organization: organization}} =
        Organizations.create_organization(user, %{
          name: "Org #{System.unique_integer([:positive])}"
        })

      membership = Organizations.get_active_membership(user, organization)

      %{user: user, organization: organization, membership: membership}
    end

    # List tests

    test "list_manufacturers/2 returns only active manufacturers", %{organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})
      assert Assets.list_manufacturers(organization.id) == [manufacturer]
    end

    test "list_manufacturers/2 does not return manufacturers from other organizations", %{
      user: user,
      organization: organization
    } do
      {:ok, _manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      {:ok, other_manufacturer} = Assets.create_manufacturer(other_org.id, %{name: "Lenovo"})

      manufacturers = Assets.list_manufacturers(organization.id)
      refute Enum.any?(manufacturers, &(&1.id == other_manufacturer.id))
    end

    test "list_manufacturers/2 does not return inactive manufacturers", %{
      organization: organization
    } do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})
      {:ok, _} = Assets.create_manufacturer(organization.id, %{name: "Lenovo"})

      {:ok, _} = Assets.deactivate_manufacturer(organization.id, manufacturer)

      manufacturers = Assets.list_manufacturers(organization.id)
      assert length(manufacturers) == 1
      assert hd(manufacturers).name == "Lenovo"
    end

    test "list_manufacturers/2 orders by name", %{organization: organization} do
      {:ok, _} = Assets.create_manufacturer(organization.id, %{name: "Lenovo"})
      {:ok, _} = Assets.create_manufacturer(organization.id, %{name: "Dell"})
      {:ok, _} = Assets.create_manufacturer(organization.id, %{name: "Apple"})

      manufacturers = Assets.list_manufacturers(organization.id)
      names = Enum.map(manufacturers, & &1.name)
      assert names == ["Apple", "Dell", "Lenovo"]
    end

    # Get tests

    test "get_manufacturer!/2 returns the manufacturer with given id", %{
      organization: organization
    } do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})
      assert Assets.get_manufacturer!(organization.id, manufacturer.id) == manufacturer
    end

    test "get_manufacturer!/2 raises for id from another organization", %{
      user: user,
      organization: organization
    } do
      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      {:ok, other_manufacturer} = Assets.create_manufacturer(other_org.id, %{name: "Lenovo"})

      assert_raise Ecto.NoResultsError, fn ->
        Assets.get_manufacturer!(organization.id, other_manufacturer.id)
      end
    end

    test "get_manufacturer!/2 raises for inactive manufacturer", %{organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})
      {:ok, _} = Assets.deactivate_manufacturer(organization.id, manufacturer)

      assert_raise Ecto.NoResultsError, fn ->
        Assets.get_manufacturer!(organization.id, manufacturer.id)
      end
    end

    test "get_manufacturer!/2 raises for invalid UUID", %{organization: organization} do
      assert_raise Ecto.Query.CastError, fn ->
        Assets.get_manufacturer!(organization.id, "invalid-uuid")
      end
    end

    test "get_manufacturer!/2 raises for non-existent UUID", %{organization: organization} do
      fake_uuid = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Assets.get_manufacturer!(organization.id, fake_uuid)
      end
    end

    # Create tests

    test "create_manufacturer/2 with valid data creates a manufacturer", %{
      organization: organization
    } do
      valid_attrs = %{
        name: "Dell",
        website: "https://dell.com",
        support_url: "https://support.dell.com"
      }

      assert {:ok, %Manufacturer{} = manufacturer} =
               Assets.create_manufacturer(organization.id, valid_attrs)

      assert manufacturer.name == "Dell"
      assert manufacturer.website == "https://dell.com"
      assert manufacturer.support_url == "https://support.dell.com"
      assert manufacturer.organization_id == organization.id
      assert manufacturer.active == true
    end

    test "create_manufacturer/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      assert {:error, %Ecto.Changeset{}} =
               Assets.create_manufacturer(organization.id, %{name: nil})
    end

    test "create_manufacturer/2 with duplicate name in same organization returns error", %{
      organization: organization
    } do
      {:ok, _} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      assert {:error, changeset} =
               Assets.create_manufacturer(organization.id, %{name: "Dell"})

      assert "já existe um fabricante com este nome nesta organização" in errors_on(changeset).name
    end

    test "create_manufacturer/2 with same name in different organization succeeds", %{
      user: user,
      organization: organization
    } do
      {:ok, _} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      assert {:ok, %Manufacturer{}} = Assets.create_manufacturer(other_org.id, %{name: "Dell"})
    end

    test "create_manufacturer/2 ignores organization_id from client", %{
      organization: organization
    } do
      other_org_id = Ecto.UUID.generate()

      {:ok, manufacturer} =
        Assets.create_manufacturer(organization.id, %{
          name: "Dell",
          organization_id: other_org_id
        })

      assert manufacturer.organization_id == organization.id
    end

    test "create_manufacturer/2 ignores active field from client", %{organization: organization} do
      {:ok, manufacturer} =
        Assets.create_manufacturer(organization.id, %{
          name: "Dell",
          active: false
        })

      assert manufacturer.active == true
    end

    # Update tests

    test "update_manufacturer/2 with valid data updates the manufacturer", %{
      organization: organization
    } do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      update_attrs = %{name: "Dell Inc.", website: "https://dell.com"}

      assert {:ok, %Manufacturer{} = manufacturer} =
               Assets.update_manufacturer(organization.id, manufacturer, update_attrs)

      assert manufacturer.name == "Dell Inc."
      assert manufacturer.website == "https://dell.com"
    end

    test "update_manufacturer/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      assert {:error, %Ecto.Changeset{}} =
               Assets.update_manufacturer(organization.id, manufacturer, %{name: nil})

      assert manufacturer == Assets.get_manufacturer!(organization.id, manufacturer.id)
    end

    # Deactivate tests

    test "deactivate_manufacturer/1 deactivates the manufacturer but preserves the record", %{
      organization: organization
    } do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      assert {:ok, %Manufacturer{}} =
               Assets.deactivate_manufacturer(organization.id, manufacturer)

      # Manufacturer is inactive, so get_manufacturer! should raise
      assert_raise Ecto.NoResultsError, fn ->
        Assets.get_manufacturer!(organization.id, manufacturer.id)
      end

      # But the record still exists in the database
      import Ecto.Query

      db_manufacturer =
        from(m in Manufacturer, where: m.id == ^manufacturer.id)
        |> Plataforma.Repo.one!()

      assert db_manufacturer.active == false
    end

    test "after deactivating Dell, it is possible to create dell again", %{
      organization: organization
    } do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})
      {:ok, _} = Assets.deactivate_manufacturer(organization.id, manufacturer)

      assert {:ok, %Manufacturer{} = new_manufacturer} =
               Assets.create_manufacturer(organization.id, %{name: "dell"})

      assert new_manufacturer.name == "dell"
      assert new_manufacturer.id != manufacturer.id
    end

    # Name normalization tests

    test "create_manufacturer/2 trims name", %{organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "  Dell  "})
      assert manufacturer.name == "Dell"
    end

    test "create_manufacturer/2 preserves capitalization", %{organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "DELL"})
      assert manufacturer.name == "DELL"
    end

    # URL validation tests

    test "create_manufacturer/2 rejects invalid URL", %{organization: organization} do
      assert {:error, changeset} =
               Assets.create_manufacturer(organization.id, %{
                 name: "Dell",
                 website: "not-a-url"
               })

      assert "deve ser uma URL válida" in errors_on(changeset).website
    end

    test "create_manufacturer/2 rejects javascript URL", %{organization: organization} do
      assert {:error, changeset} =
               Assets.create_manufacturer(organization.id, %{
                 name: "Dell",
                 website: "javascript:alert(1)"
               })

      assert "deve ser uma URL válida" in errors_on(changeset).website
    end

    test "create_manufacturer/2 rejects file URL", %{organization: organization} do
      assert {:error, changeset} =
               Assets.create_manufacturer(organization.id, %{
                 name: "Dell",
                 website: "file:///etc/passwd"
               })

      assert "deve ser uma URL válida" in errors_on(changeset).website
    end

    test "create_manufacturer/2 normalizes empty string to nil for website", %{
      organization: organization
    } do
      {:ok, manufacturer} =
        Assets.create_manufacturer(organization.id, %{name: "Dell", website: ""})

      assert manufacturer.website == nil
    end

    test "create_manufacturer/2 normalizes empty string to nil for support_url", %{
      organization: organization
    } do
      {:ok, manufacturer} =
        Assets.create_manufacturer(organization.id, %{name: "Dell", support_url: ""})

      assert manufacturer.support_url == nil
    end
  end
end
