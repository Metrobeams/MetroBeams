defmodule Plataforma.Organizations.DepartmentTest do
  use Plataforma.DataCase, async: true

  import Plataforma.AccountsFixtures

  alias Plataforma.Organizations
  alias Plataforma.Organizations.Department

  describe "departments" do
    setup do
      user = user_fixture()

      {:ok, %{organization: organization}} =
        Organizations.create_organization(user, %{
          name: "Org #{System.unique_integer([:positive])}"
        })

      membership = Organizations.get_active_membership(user, organization)

      %{user: user, organization: organization, membership: membership}
    end

    test "list_departments/1 returns only active departments", %{organization: organization} do
      {:ok, department} = Organizations.create_department(organization.id, %{name: "TI"})
      assert Organizations.list_departments(organization.id) == [department]
    end

    test "list_departments/1 does not return departments from other organizations", %{
      user: user,
      organization: organization
    } do
      {:ok, _department} = Organizations.create_department(organization.id, %{name: "TI"})

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      {:ok, other_department} = Organizations.create_department(other_org.id, %{name: "RH"})

      departments = Organizations.list_departments(organization.id)
      refute Enum.any?(departments, &(&1.id == other_department.id))
    end

    test "get_department!/2 returns the department with given id", %{organization: organization} do
      {:ok, department} = Organizations.create_department(organization.id, %{name: "TI"})
      assert Organizations.get_department!(organization.id, department.id) == department
    end

    test "get_department!/2 raises for id from another organization", %{
      user: user,
      organization: organization
    } do
      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      {:ok, other_department} = Organizations.create_department(other_org.id, %{name: "RH"})

      assert_raise Ecto.NoResultsError, fn ->
        Organizations.get_department!(organization.id, other_department.id)
      end
    end

    test "create_department/2 with valid data creates a department", %{organization: organization} do
      valid_attrs = %{name: "Tecnologia da Informação", code: "TI", description: "Departamento de TI"}

      assert {:ok, %Department{} = department} =
               Organizations.create_department(organization.id, valid_attrs)

      assert department.name == "tecnologia da informação"
      assert department.code == "TI"
      assert department.description == "Departamento de TI"
      assert department.organization_id == organization.id
      assert department.active == true
    end

    test "create_department/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      assert {:error, %Ecto.Changeset{}} =
               Organizations.create_department(organization.id, %{name: nil})
    end

    test "create_department/2 with duplicate name in same organization returns error", %{
      organization: organization
    } do
      {:ok, _department} = Organizations.create_department(organization.id, %{name: "TI"})

      assert {:error, changeset} =
               Organizations.create_department(organization.id, %{name: "TI"})

      assert "já existe um departamento com este nome nesta organização" in errors_on(changeset).name
    end

    test "create_department/2 with same name in different organization succeeds", %{
      user: user,
      organization: organization
    } do
      {:ok, _department} = Organizations.create_department(organization.id, %{name: "TI"})

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(user, %{
          name: "Other Org #{System.unique_integer([:positive])}"
        })

      assert {:ok, %Department{}} = Organizations.create_department(other_org.id, %{name: "TI"})
    end

    test "update_department/2 with valid data updates the department", %{organization: organization} do
      {:ok, department} = Organizations.create_department(organization.id, %{name: "TI"})

      update_attrs = %{name: "TI Atualizado", code: "TIA", description: "Atualizado"}

      assert {:ok, %Department{} = department} =
               Organizations.update_department(organization.id, department, update_attrs)

      assert department.name == "ti atualizado"
      assert department.code == "TIA"
      assert department.description == "Atualizado"
    end

    test "update_department/2 with invalid data returns error changeset", %{
      organization: organization
    } do
      {:ok, department} = Organizations.create_department(organization.id, %{name: "TI"})

      assert {:error, %Ecto.Changeset{}} =
               Organizations.update_department(organization.id, department, %{name: nil})

      assert department == Organizations.get_department!(organization.id, department.id)
    end

    test "deactivate_department/1 deactivates the department", %{organization: organization} do
      {:ok, department} = Organizations.create_department(organization.id, %{name: "TI"})
      assert {:ok, %Department{} = deactivated} = Organizations.deactivate_department(organization.id, department)
      assert deactivated.active == false

      # Can recreate with same name after soft delete
      assert {:ok, %Department{} = new_department} =
               Organizations.create_department(organization.id, %{name: "TI"})

      assert new_department.id != department.id
    end

    test "inactive departments do not appear in list_departments", %{organization: organization} do
      {:ok, department} = Organizations.create_department(organization.id, %{name: "TI"})
      {:ok, _} = Organizations.create_department(organization.id, %{name: "RH"})

      # Deactivate one department
      {:ok, _} = Organizations.deactivate_department(organization.id, department)

      departments = Organizations.list_departments(organization.id)
      assert length(departments) == 1
      assert hd(departments).name == "rh"
    end

    test "create_department/2 ignores organization_id from client", %{organization: organization} do
      other_org_id = Ecto.UUID.generate()

      {:ok, department} =
        Organizations.create_department(organization.id, %{
          name: "TI",
          organization_id: other_org_id
        })

      assert department.organization_id == organization.id
    end

    test "create_department/2 ignores active field from client", %{organization: organization} do
      {:ok, department} =
        Organizations.create_department(organization.id, %{
          name: "TI",
          active: false
        })

      assert department.active == true
    end

    test "get_department!/2 raises for invalid UUID", %{organization: organization} do
      assert_raise Ecto.Query.CastError, fn ->
        Organizations.get_department!(organization.id, "invalid-uuid")
      end
    end

    test "get_department!/2 raises for non-existent UUID", %{organization: organization} do
      fake_uuid = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Organizations.get_department!(organization.id, fake_uuid)
      end
    end

    test "change_department/1 returns a department changeset", %{organization: organization} do
      {:ok, department} = Organizations.create_department(organization.id, %{name: "TI"})
      assert %Ecto.Changeset{} = Organizations.change_department(department)
    end

    # Normalization tests

    test "create_department/2 trims and downcases name", %{organization: organization} do
      {:ok, department} = Organizations.create_department(organization.id, %{name: "  TI  "})
      assert department.name == "ti"
    end

    test "create_department/2 upcases code", %{organization: organization} do
      {:ok, department} = Organizations.create_department(organization.id, %{name: "TI", code: "ti"})
      assert department.code == "TI"
    end

    test "create_department/2 converts empty strings to nil", %{organization: organization} do
      {:ok, department} =
        Organizations.create_department(organization.id, %{
          name: "TI",
          code: "",
          description: ""
        })

      assert department.code == nil
      assert department.description == nil
    end

    # Field length validation tests

    test "create_department/2 rejects name longer than 120 characters", %{organization: organization} do
      long_name = String.duplicate("a", 121)

      assert {:error, changeset} =
               Organizations.create_department(organization.id, %{name: long_name})
    end

    test "create_department/2 rejects code longer than 20 characters", %{organization: organization} do
      long_code = String.duplicate("A", 21)

      assert {:error, changeset} =
               Organizations.create_department(organization.id, %{name: "TI", code: long_code})
    end
  end
end
