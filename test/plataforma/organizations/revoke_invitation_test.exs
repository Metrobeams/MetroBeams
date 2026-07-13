defmodule Plataforma.Organizations.RevokeInvitationTest do
  use Plataforma.DataCase

  import Plataforma.AccountsFixtures

  alias Plataforma.Organizations

  test "authorized actor soft revokes an open invitation" do
    user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(user, %{name: "Acme"})

    {:ok, %{invitation: invitation}} =
      Organizations.invite_member(owner, organization, %{email: "new@example.com", role: :member})

    assert {:ok, revoked} = Organizations.revoke_invitation(owner, invitation)
    assert revoked.revoked_at
  end
end
