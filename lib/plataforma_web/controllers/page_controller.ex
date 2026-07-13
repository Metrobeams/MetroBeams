defmodule PlataformaWeb.PageController do
  use PlataformaWeb, :controller

  alias Plataforma.Accounts.Scope
  alias Plataforma.Organizations
  alias Plataforma.Organizations.Membership
  alias Plataforma.Organizations.Organization
  alias Plataforma.Organizations.Policy

  def home(%{assigns: %{current_scope: %Scope{user: user}}} = conn, _params) do
    {:ok, {organizations, _meta}} = Organizations.list_organizations_for_user(user)
    organization_cards = Enum.map(organizations, &organization_card/1)

    render(conn, :home,
      organizations: organization_cards,
      organization_count: length(organization_cards)
    )
  end

  defp organization_card(%Organization{memberships: [%Membership{} = membership]} = organization) do
    %{
      organization: organization,
      editable?: Policy.authorize(:update_organization, membership, organization)
    }
  end
end
