defmodule Plataforma.Organizations.TenantIsolationTest do
  use Plataforma.DataCase

  import Plataforma.AccountsFixtures

  alias Plataforma.Organizations
  alias Plataforma.Organizations.Invitation
  alias Plataforma.Organizations.Membership
  alias Plataforma.Organizations.Organization
  alias Plataforma.Repo

  setup do
    user_a = user_fixture()
    user_b = user_fixture()
    member_user_b = user_fixture(%{email: "member-b@example.com"})

    {:ok, %{organization: organization_a, owner: owner_a}} =
      Organizations.create_organization(user_a, %{name: "Organização A"})

    {:ok, %{organization: organization_b, owner: owner_b}} =
      Organizations.create_organization(user_b, %{name: "Organização B"})

    {:ok, %{invitation: accepted_invitation_b}} =
      Organizations.invite_member(owner_b, organization_b, %{
        email: member_user_b.email,
        role: :member
      })

    {:ok, member_b} =
      Organizations.accept_invitation(
        member_user_b,
        sign_invitation(accepted_invitation_b.id)
      )

    {:ok, %{invitation: open_invitation_b}} =
      Organizations.invite_member(owner_b, organization_b, %{
        email: "pending-b@example.com",
        role: :member
      })

    %{
      user_a: user_a,
      organization_a: organization_a,
      owner_a: owner_a,
      organization_b: organization_b,
      member_b: member_b,
      open_invitation_b: open_invitation_b
    }
  end

  test "membership de A não obtém organização B pelo UUID", context do
    assert {:error, :not_found} =
             Organizations.get_organization_for_user(
               context.user_a,
               context.organization_b.id
             )
  end

  test "membership de A não atualiza organização B", context do
    assert {:error, :unauthorized} =
             Organizations.update_organization(
               context.owner_a,
               context.organization_b,
               %{name: "Tenant comprometido"}
             )

    assert Repo.get!(Organization, context.organization_b.id).name == "Organização B"
  end

  test "membership de A não lista membros de B", context do
    assert {:error, :unauthorized} =
             Organizations.list_members(context.owner_a, context.organization_b)
  end

  test "membership de A não revoga convite de B", context do
    assert {:error, :not_found} =
             Organizations.revoke_invitation(
               context.owner_a,
               context.open_invitation_b
             )

    refute Repo.get!(Invitation, context.open_invitation_b.id).revoked_at
  end

  test "membership de A não altera membership de B", context do
    assert {:error, :unauthorized} =
             Organizations.change_member_role(
               context.owner_a,
               context.organization_b,
               context.member_b,
               :admin
             )

    assert Repo.get!(Membership, context.member_b.id).role == :member
  end

  test "revogação recarrega o convite por tenant e rejeita struct adulterado", context do
    forged_invitation = %{
      context.open_invitation_b
      | organization_id: context.organization_a.id
    }

    assert {:error, :not_found} =
             Organizations.revoke_invitation(context.owner_a, forged_invitation)

    refute Repo.get!(Invitation, context.open_invitation_b.id).revoked_at
  end

  test "alteração recarrega o membership por tenant e rejeita struct adulterado", context do
    forged_member = %{context.member_b | organization_id: context.organization_a.id}

    assert {:error, :not_found} =
             Organizations.change_member_role(
               context.owner_a,
               context.organization_a,
               forged_member,
               :admin
             )

    assert Repo.get!(Membership, context.member_b.id).role == :member
  end

  test "desativação recarrega o membership por tenant e rejeita struct adulterado", context do
    forged_member = %{context.member_b | organization_id: context.organization_a.id}

    assert {:error, :not_found} =
             Organizations.deactivate_member(
               context.owner_a,
               context.organization_a,
               forged_member
             )

    assert Repo.get!(Membership, context.member_b.id).active
  end

  test "autorização recarrega o ator e rejeita tenant ou papel adulterado", context do
    forged_actor = %{
      context.owner_a
      | organization_id: context.organization_b.id,
        role: :owner
    }

    assert {:error, :unauthorized} =
             Organizations.update_organization(
               forged_actor,
               context.organization_b,
               %{name: "Tenant comprometido"}
             )

    assert Repo.get!(Organization, context.organization_b.id).name == "Organização B"
  end

  defp sign_invitation(invitation_id) do
    Phoenix.Token.sign(
      PlataformaWeb.Endpoint,
      Application.fetch_env!(:plataforma, :invitation_token_salt),
      invitation_id
    )
  end
end
