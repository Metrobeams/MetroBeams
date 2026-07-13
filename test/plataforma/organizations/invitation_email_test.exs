defmodule Plataforma.Organizations.InvitationEmailTest do
  use Plataforma.DataCase

  import Plataforma.AccountsFixtures

  alias Plataforma.Organizations
  alias Plataforma.Organizations.InvitationEmail
  alias Plataforma.Repo

  test "build/2 creates configured HTML and text alternatives" do
    user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(user, %{name: "Acme"})

    {:ok, %{invitation: invitation}} =
      Organizations.invite_member(owner, organization, %{email: "new@example.com", role: :member})

    invitation = Repo.preload(invitation, :organization)

    email = InvitationEmail.build(invitation, "signed-token")

    assert email.to == [{"", "new@example.com"}]
    assert email.from == {"Plataforma test", "no-reply@test.local"}
    assert email.subject =~ "Acme"
    assert email.html_body =~ "signed-token"
    assert email.text_body =~ "signed-token"
    assert email.text_body =~ "member"
  end
end
