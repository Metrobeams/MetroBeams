defmodule Plataforma.Organizations.LocationTest do
  use Plataforma.DataCase, async: true

  import Plataforma.AccountsFixtures

  alias Plataforma.Organizations
  alias Plataforma.Organizations.Location

  describe "locations" do
    setup do
      user = user_fixture()

      {:ok, %{organization: organization}} =
        Organizations.create_organization(user, %{
          name: "Org #{System.unique_integer([:positive])}"
        })

      membership = Organizations.get_active_membership(user, organization)

      %{user: user, organization: organization, membership: membership}
    end

    test "list_locations/1 returns only active locations", %{organization: organization} do
      {:ok, location} = Organizations.create_location(organization.id, %{name: "São Paulo"})
      assert Organizations.list_locations(organization.id) == [location]
    end

    test "list_locations/1 does not return locations from other organizations", %{
      user: user,
      organization: organization
    } do
      {:ok, _location} = Organizations.create_location(organization.id, %{name: "São Paulo"})

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      {:ok, other_location} = Organizations.create_location(other_org.id, %{name: "Rio"})

      locations = Organizations.list_locations(organization.id)
      refute Enum.any?(locations, &(&1.id == other_location.id))
    end

    test "get_location!/2 returns the location with given id", %{organization: organization} do
      {:ok, location} = Organizations.create_location(organization.id, %{name: "São Paulo"})
      assert Organizations.get_location!(organization.id, location.id) == location
    end

    test "get_location!/2 raises for id from another organization", %{
      user: user,
      organization: organization
    } do
      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      {:ok, other_location} = Organizations.create_location(other_org.id, %{name: "Rio"})

      assert_raise Ecto.NoResultsError, fn ->
        Organizations.get_location!(organization.id, other_location.id)
      end
    end

    test "create_location/2 with valid data creates a location", %{organization: organization} do
      valid_attrs = %{
        name: "Filial São Paulo",
        tag_color: "#0f62fe",
        city: "São Paulo",
        state: "SP",
        country: "Brasil"
      }

      assert {:ok, %Location{} = location} =
               Organizations.create_location(organization.id, valid_attrs)

      assert location.name == "filial são paulo"
      assert location.tag_color == "#0f62fe"
      assert location.city == "São Paulo"
      assert location.state == "SP"
      assert location.country == "Brasil"
      assert location.organization_id == organization.id
      assert location.active == true
    end

    test "create_location/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      assert {:error, %Ecto.Changeset{}} =
               Organizations.create_location(organization.id, %{name: nil})
    end

    test "create_location/2 with duplicate name in same organization returns error", %{
      organization: organization
    } do
      {:ok, _location} = Organizations.create_location(organization.id, %{name: "São Paulo"})

      assert {:error, changeset} =
               Organizations.create_location(organization.id, %{name: "São Paulo"})

      assert "já existe uma localização com este nome nesta organização" in errors_on(changeset).name
    end

    test "create_location/2 with same name in different organization succeeds", %{
      user: user,
      organization: organization
    } do
      {:ok, _location} = Organizations.create_location(organization.id, %{name: "São Paulo"})

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      assert {:ok, %Location{}} = Organizations.create_location(other_org.id, %{name: "São Paulo"})
    end

    test "update_location/2 with valid data updates the location", %{organization: organization} do
      {:ok, location} = Organizations.create_location(organization.id, %{name: "São Paulo"})

      update_attrs = %{
        name: "Filial Atualizada",
        tag_color: "#da1e28",
        city: "Campinas",
        state: "SP",
        country: "Brasil"
      }

      assert {:ok, %Location{} = location} =
               Organizations.update_location(organization.id, location, update_attrs)

      assert location.name == "filial atualizada"
      assert location.tag_color == "#da1e28"
      assert location.city == "Campinas"
    end

    test "update_location/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      {:ok, location} = Organizations.create_location(organization.id, %{name: "São Paulo"})

      assert {:error, %Ecto.Changeset{}} =
               Organizations.update_location(organization.id, location, %{name: nil})

      assert location == Organizations.get_location!(organization.id, location.id)
    end

    test "deactivate_location/1 deactivates the location", %{organization: organization} do
      {:ok, location} = Organizations.create_location(organization.id, %{name: "São Paulo"})
      assert {:ok, %Location{} = deactivated} = Organizations.deactivate_location(organization.id, location)
      assert deactivated.active == false

      # Can recreate with same name after soft delete
      assert {:ok, %Location{} = new_location} =
               Organizations.create_location(organization.id, %{name: "São Paulo"})

      assert new_location.id != location.id
    end

    test "inactive locations do not appear in list_locations", %{organization: organization} do
      {:ok, location} = Organizations.create_location(organization.id, %{name: "São Paulo"})
      {:ok, _} = Organizations.create_location(organization.id, %{name: "Rio"})

      # Deactivate one location
      {:ok, _} = Organizations.deactivate_location(organization.id, location)

      locations = Organizations.list_locations(organization.id)
      assert length(locations) == 1
      assert hd(locations).name == "rio"
    end

    test "create_location/2 ignores organization_id from client", %{organization: organization} do
      other_org_id = Ecto.UUID.generate()

      {:ok, location} =
        Organizations.create_location(organization.id, %{
          name: "São Paulo",
          organization_id: other_org_id
        })

      assert location.organization_id == organization.id
    end

    test "create_location/2 ignores active field from client", %{organization: organization} do
      {:ok, location} =
        Organizations.create_location(organization.id, %{
          name: "São Paulo",
          active: false
        })

      assert location.active == true
    end

    test "get_location!/2 raises for invalid UUID", %{organization: organization} do
      assert_raise Ecto.Query.CastError, fn ->
        Organizations.get_location!(organization.id, "invalid-uuid")
      end
    end

    test "get_location!/2 raises for non-existent UUID", %{organization: organization} do
      fake_uuid = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Organizations.get_location!(organization.id, fake_uuid)
      end
    end

    test "change_location/1 returns a location changeset", %{organization: organization} do
      {:ok, location} = Organizations.create_location(organization.id, %{name: "São Paulo"})
      assert %Ecto.Changeset{} = Organizations.change_location(location)
    end

    # Normalization tests

    test "create_location/2 trims and downcases name", %{organization: organization} do
      {:ok, location} = Organizations.create_location(organization.id, %{name: "  São Paulo  "})
      assert location.name == "são paulo"
    end

    test "create_location/2 converts empty strings to nil", %{organization: organization} do
      {:ok, location} =
        Organizations.create_location(organization.id, %{
          name: "São Paulo",
          city: "",
          state: "",
          country: ""
        })

      assert location.city == nil
      assert location.state == nil
      assert location.country == nil
    end

    # Field length validation tests

    test "create_location/2 rejects name longer than 120 characters", %{organization: organization} do
      long_name = String.duplicate("a", 121)

      assert {:error, changeset} =
               Organizations.create_location(organization.id, %{name: long_name})
    end

    test "create_location/2 rejects tag_color longer than 7 characters", %{organization: organization} do
      long_color = String.duplicate("#", 8)

      assert {:error, changeset} =
               Organizations.create_location(organization.id, %{name: "SP", tag_color: long_color})
    end
  end
end
