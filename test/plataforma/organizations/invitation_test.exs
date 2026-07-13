defmodule Plataforma.Organizations.InvitationTest do
  use Plataforma.DataCase
  use Oban.Testing, repo: Plataforma.Repo

  import Plataforma.AccountsFixtures

  alias Plataforma.Organizations
  alias Plataforma.Organizations.Invitation
  alias Plataforma.Notifications
  alias Plataforma.Organizations.Workers.SendInvitationEmail
  alias Plataforma.Repo

  test "changeset normalizes email and rejects owner" do
    base = %Invitation{
      organization_id: Ecto.UUID.generate(),
      invited_by_membership_id: Ecto.UUID.generate(),
      expires_at: DateTime.add(DateTime.utc_now(), 7, :day)
    }

    valid = Invitation.changeset(base, %{email: "  PESSOA@EXAMPLE.COM ", role: :member})
    assert valid.valid?
    assert get_change(valid, :email) == "pessoa@example.com"

    invalid = Invitation.changeset(base, %{email: "invalid", role: :owner})
    refute invalid.valid?
    assert %{email: [_], role: [_]} = errors_on(invalid)
  end

  test "invite_member/3 persists no token and enqueues only the invitation id" do
    user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(user, %{name: "Acme"})

    assert {:ok, %{invitation: invitation, invitation_email_job: job}} =
             Organizations.invite_member(owner, organization, %{
               email: "new@example.com",
               role: :member
             })

    assert %Invitation{} = invitation
    refute Map.has_key?(Map.from_struct(invitation), :token)
    assert job.args == %{"invitation_id" => invitation.id}
    assert_enqueued worker: SendInvitationEmail, args: %{"invitation_id" => invitation.id}
  end

  test "partial index rejects two open invitations for the same tenant and email" do
    user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(user, %{name: "Acme"})

    assert {:ok, %{invitation: _invitation}} =
             Organizations.invite_member(owner, organization, %{
               email: "Person@Example.com",
               role: :member
             })

    assert {:error, :invitation, changeset, _changes} =
             Organizations.invite_member(owner, organization, %{
               email: "person@example.com",
               role: :member
             })

    assert %{email: [_message]} = errors_on(changeset)
  end

  test "the same open email is allowed in another organization" do
    user_a = user_fixture()
    user_b = user_fixture()

    {:ok, %{organization: organization_a, owner: owner_a}} =
      Organizations.create_organization(user_a, %{name: "Acme A"})

    {:ok, %{organization: organization_b, owner: owner_b}} =
      Organizations.create_organization(user_b, %{name: "Acme B"})

    assert {:ok, %{invitation: _invitation}} =
             Organizations.invite_member(owner_a, organization_a, %{
               email: "person@example.com",
               role: :member
             })

    assert {:ok, %{invitation: _invitation}} =
             Organizations.invite_member(owner_b, organization_b, %{
               email: "person@example.com",
               role: :member
             })
  end

  test "revokes an expired open invitation before replacing it" do
    user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(user, %{name: "Acme"})

    {:ok, %{invitation: expired_invitation}} =
      Organizations.invite_member(owner, organization, %{
        email: "person@example.com",
        role: :member
      })

    expired_invitation
    |> Invitation.changeset(%{expires_at: DateTime.add(DateTime.utc_now(), -1, :day)})
    |> Repo.update!()

    assert {:ok, %{invitation: replacement}} =
             Organizations.invite_member(owner, organization, %{
               email: "PERSON@example.com",
               role: :admin
             })

    assert replacement.id != expired_invitation.id
    assert replacement.role == :admin
    assert Repo.get!(Invitation, expired_invitation.id).revoked_at
  end

  test "invite_member/3 creates an in-app notification for an existing user" do
    owner_user = user_fixture()
    invited_user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(owner_user, %{name: "Acme"})

    assert {:ok, %{invitation: invitation}} =
             Organizations.invite_member(owner, organization, %{
               email: invited_user.email,
               role: :member
             })

    summary = Notifications.summary(invited_user)

    assert summary.unread_count == 1

    assert Enum.any?(summary.notifications, fn notification ->
             notification.kind == :organization_invitation and
               notification.metadata["invitation_id"] == invitation.id
           end)
  end

  test "invite_member/3 keeps email-only delivery for a recipient without an account" do
    owner_user = user_fixture()
    invited_email = unique_user_email()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(owner_user, %{name: "Acme"})

    assert {:ok, %{invitation: _invitation}} =
             Organizations.invite_member(owner, organization, %{
               email: invited_email,
               role: :member
             })

    later_user = user_fixture(%{email: invited_email})
    assert Notifications.summary(later_user).unread_count == 0
  end
end
