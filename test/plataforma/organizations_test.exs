defmodule Plataforma.OrganizationsTest do
  use Plataforma.DataCase

  import Plataforma.AccountsFixtures

  alias Plataforma.Organizations
  alias Plataforma.Organizations.Membership
  alias Plataforma.Organizations.Organization
  alias Plataforma.Repo

  test "change_organization/2 returns a changeset without persisting changes" do
    organization = %Organization{name: "Nome atual", slug: "nome-atual"}

    changeset = Organizations.change_organization(organization, %{name: "Novo nome"})

    assert %Ecto.Changeset{data: ^organization, valid?: true} = changeset
    assert Ecto.Changeset.get_change(changeset, :name) == "Novo nome"
    assert organization.name == "Nome atual"
  end

  test "create_organization/2 atomically creates its owner" do
    user = user_fixture()

    assert {:ok, %{organization: %Organization{} = organization, owner: %Membership{} = owner}} =
             Organizations.create_organization(user, %{name: "Empresa Acme"})

    assert owner.organization_id == organization.id
    assert owner.user_id == user.id
    assert owner.role == :owner
    assert owner.active
  end

  test "create_organization/2 rolls organization back when owner is invalid" do
    user = user_fixture()

    assert {:error, :owner, _changeset, %{organization: organization}} =
             Organizations.create_organization(user, %{name: "Rollback"},
               owner: %{role: :invalid}
             )

    refute Repo.get(Organization, organization.id)
  end

  test "update_organization/3 authorizes the actor and denies another tenant" do
    user = user_fixture()
    other_user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(user, %{name: "Original"})

    {:ok, %{owner: other_owner}} = Organizations.create_organization(other_user, %{name: "Outra"})

    assert {:ok, updated} =
             Organizations.update_organization(owner, organization, %{name: "Atualizada"})

    assert updated.name == "Atualizada"

    assert {:error, :unauthorized} =
             Organizations.update_organization(other_owner, organization, %{name: "Vazamento"})
  end

  test "list_organizations/2 is scoped and excludes inactive organizations" do
    user = user_fixture()
    other_user = user_fixture()
    {:ok, %{organization: visible}} = Organizations.create_organization(user, %{name: "Visível"})

    {:ok, %{organization: inactive}} =
      Organizations.create_organization(user, %{name: "Inativa", active: false})

    {:ok, %{organization: hidden}} =
      Organizations.create_organization(other_user, %{name: "Oculta"})

    assert {:ok, {organizations, %Flop.Meta{}}} = Organizations.list_organizations(user, %{})
    assert Enum.map(organizations, & &1.id) == [visible.id]
    refute inactive.id in Enum.map(organizations, & &1.id)
    refute hidden.id in Enum.map(organizations, & &1.id)
  end

  test "list_organizations/2 preloads only the current user's active membership" do
    user = user_fixture()
    other_user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(user, %{name: "Membership escopada"})

    {:ok, %{invitation: invitation}} =
      Organizations.invite_member(owner, organization, %{
        email: other_user.email,
        role: :admin
      })

    token =
      Phoenix.Token.sign(
        PlataformaWeb.Endpoint,
        Application.fetch_env!(:plataforma, :invitation_token_salt),
        invitation.id
      )

    assert {:ok, %Membership{}} = Organizations.accept_invitation(other_user, token)
    assert {:ok, {[listed], %Flop.Meta{}}} = Organizations.list_organizations(user)
    assert [%Membership{user_id: user_id, active: true}] = listed.memberships
    assert user_id == user.id
  end

  test "public lookup APIs remain tenant scoped" do
    user = user_fixture()
    other = user_fixture()

    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{name: "Minha Empresa"})

    assert {:ok, ^organization} = Organizations.get_organization_for_user(user, organization.id)
    assert {:ok, found} = Organizations.get_organization_by_slug_for_user(user, "Minha Empresa")
    assert found.id == organization.id
    assert {:error, :not_found} = Organizations.get_organization_for_user(other, organization.id)
    assert %Membership{} = Organizations.get_membership(user, organization)
  end

  test "deactivate_organization/2 uses soft deletion and authorization" do
    user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(user, %{name: "Acme"})

    assert {:ok, deactivated} = Organizations.deactivate_organization(owner, organization)
    refute deactivated.active
    assert Repo.get!(Organization, organization.id)
  end

  test "deactivate_member/3 protects the last active owner" do
    user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(user, %{name: "Acme"})

    assert {:error, :last_owner} = Organizations.deactivate_member(owner, organization, owner)
    assert Repo.get!(Membership, owner.id).active
  end

  test "lists members and changes roles without removing the last owner" do
    owner_user = user_fixture()
    invited_user = user_fixture(%{email: "member@example.com"})

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(owner_user, %{name: "Acme"})

    {:ok, %{invitation: invitation}} =
      Organizations.invite_member(owner, organization, %{email: invited_user.email, role: :member})

    token =
      Phoenix.Token.sign(
        PlataformaWeb.Endpoint,
        Application.fetch_env!(:plataforma, :invitation_token_salt),
        invitation.id
      )

    {:ok, member} = Organizations.accept_invitation(invited_user, token)

    assert {:ok, members} = Organizations.list_members(owner, organization)
    assert Enum.sort(Enum.map(members, & &1.id)) == Enum.sort([owner.id, member.id])
    assert {:ok, promoted} = Organizations.change_member_role(owner, organization, member, :admin)
    assert promoted.role == :admin

    assert {:error, :last_owner} =
             Organizations.change_member_role(owner, organization, owner, :member)
  end
end
