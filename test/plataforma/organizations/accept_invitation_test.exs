defmodule Plataforma.Organizations.AcceptInvitationTest do
  use Plataforma.DataCase

  import Plataforma.AccountsFixtures

  alias Plataforma.Organizations
  alias Plataforma.Organizations.Invitation
  alias Plataforma.Repo

  test "accepts a signed invitation atomically" do
    owner_user = user_fixture()
    invited_user = user_fixture(%{email: "invited@example.com"})

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(owner_user, %{name: "Acme"})

    {:ok, %{invitation: invitation}} =
      Organizations.invite_member(owner, organization, %{email: invited_user.email, role: :member})

    assert {:ok, membership} = Organizations.accept_invitation(invited_user, sign(invitation.id))
    assert membership.organization_id == organization.id
    assert membership.user_id == invited_user.id
    assert membership.role == :member
    assert Repo.get!(Invitation, invitation.id).accepted_at
  end

  test "rejects a different email without accepting" do
    owner_user = user_fixture()
    wrong_user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(owner_user, %{name: "Acme"})

    {:ok, %{invitation: invitation}} =
      Organizations.invite_member(owner, organization, %{
        email: "other@example.com",
        role: :member
      })

    assert {:error, :email_mismatch} =
             Organizations.accept_invitation(wrong_user, sign(invitation.id))

    refute Repo.get!(Invitation, invitation.id).accepted_at
  end

  defp sign(invitation_id) do
    Phoenix.Token.sign(
      PlataformaWeb.Endpoint,
      Application.fetch_env!(:plataforma, :invitation_token_salt),
      invitation_id
    )
  end
end
