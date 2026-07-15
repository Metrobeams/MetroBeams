defmodule Plataforma.Organizations.Policy do
  @moduledoc """
  Bodyguard policy for organization authorization rules.
  """

  @behaviour Bodyguard.Policy

  alias Plataforma.Organizations.Membership
  alias Plataforma.Organizations.Organization

  @permissions %{
    view_organization: [:owner, :admin, :technician, :member],
    update_organization: [:owner, :admin],
    deactivate_organization: [:owner],
    list_members: [:owner, :admin, :technician],
    invite_member: [:owner, :admin],
    update_member: [:owner, :admin],
    deactivate_member: [:owner, :admin],
    change_member_role: [:owner],
    manage_categories: [:owner, :admin, :technician],
    manage_manufacturers: [:owner, :admin, :technician],
    manage_suppliers: [:owner, :admin, :technician]
  }

  @impl true
  def authorize(
        action,
        %Membership{active: true, organization_id: organization_id, role: role},
        %Organization{id: organization_id}
      ) do
    role in Map.get(@permissions, action, [])
  end

  def authorize(_action, _actor, _resource), do: false
end
