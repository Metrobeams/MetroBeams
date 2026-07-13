defmodule Plataforma.Organizations.PolicyTest do
  use ExUnit.Case, async: true

  alias Plataforma.Organizations.Membership
  alias Plataforma.Organizations.Organization
  alias Plataforma.Organizations.Policy

  @organization_id "00000000-0000-0000-0000-000000000001"

  test "enforces the complete role matrix" do
    organization = %Organization{id: @organization_id}

    expected = %{
      owner:
        ~w(view_organization update_organization deactivate_organization list_members invite_member update_member deactivate_member change_member_role)a,
      admin:
        ~w(view_organization update_organization list_members invite_member update_member deactivate_member)a,
      technician: ~w(view_organization list_members)a,
      member: ~w(view_organization)a
    }

    for {role, allowed} <- expected,
        action <-
          ~w(view_organization update_organization deactivate_organization list_members invite_member update_member deactivate_member change_member_role)a do
      actor = %Membership{organization_id: @organization_id, role: role, active: true}
      assert Policy.authorize(action, actor, organization) == action in allowed
    end
  end

  test "always denies inactive and cross-tenant actors" do
    organization = %Organization{id: @organization_id}

    refute Policy.authorize(
             :view_organization,
             %Membership{organization_id: @organization_id, role: :owner, active: false},
             organization
           )

    refute Policy.authorize(
             :view_organization,
             %Membership{organization_id: Ecto.UUID.generate(), role: :owner, active: true},
             organization
           )

    refute Policy.authorize(:unknown, nil, organization)
  end
end
