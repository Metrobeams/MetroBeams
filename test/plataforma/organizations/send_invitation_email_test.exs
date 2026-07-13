defmodule Plataforma.Organizations.SendInvitationEmailTest do
  use Plataforma.DataCase
  use Oban.Testing, repo: Plataforma.Repo

  import Plataforma.AccountsFixtures
  import Swoosh.TestAssertions

  alias Plataforma.Organizations
  alias Plataforma.Organizations.Invitation
  alias Plataforma.Organizations.Workers.SendInvitationEmail
  alias Plataforma.Repo

  test "worker signs and sends a usable invitation" do
    user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(user, %{name: "Acme"})

    {:ok, %{invitation: invitation}} =
      Organizations.invite_member(owner, organization, %{email: "new@example.com", role: :member})

    assert_email_sent()

    assert :ok = perform_job(SendInvitationEmail, %{"invitation_id" => invitation.id})
    assert_email_sent(subject: "Convite para Acme", to: "new@example.com")
  end

  test "worker cancels expired invitations" do
    user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(user, %{name: "Acme"})

    {:ok, %{invitation: invitation}} =
      Organizations.invite_member(owner, organization, %{email: "old@example.com", role: :member})

    invitation
    |> Invitation.changeset(%{expires_at: DateTime.add(DateTime.utc_now(), -1, :day)})
    |> Repo.update!()

    assert {:cancel, :expired} =
             perform_job(SendInvitationEmail, %{"invitation_id" => invitation.id})
  end
end
