defmodule Plataforma.Agents.EnrollmentTokenTest do
  use Plataforma.DataCase, async: true

  alias Plataforma.Agents.EnrollmentToken
  alias Plataforma.Organizations

  import Plataforma.AccountsFixtures

  test "creation_changeset/2 accepts expiration but protects ownership and digest" do
    expires_at = DateTime.add(DateTime.utc_now(), 15, :minute)
    protected_id = Ecto.UUID.generate()

    changeset =
      EnrollmentToken.creation_changeset(%EnrollmentToken{}, %{
        expires_at: expires_at,
        organization_id: protected_id,
        token_digest: <<0::256>>
      })

    assert changeset.valid?
    assert get_change(changeset, :expires_at)
    refute get_change(changeset, :organization_id)
    refute get_change(changeset, :token_digest)
  end

  test "token digest is redacted when inspected" do
    inspected = inspect(%EnrollmentToken{token_digest: <<0::256>>})

    refute inspected =~ "<<0"
    refute inspected =~ "token_digest"
    assert inspected =~ "..."
  end

  test "persists a tenant-owned enrollment token" do
    user = user_fixture()

    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{name: "Acme"})

    token = %EnrollmentToken{
      organization_id: organization.id,
      token_digest: :crypto.hash(:sha256, "secret")
    }

    assert {:ok, persisted} =
             token
             |> EnrollmentToken.creation_changeset(%{
               expires_at: DateTime.add(DateTime.utc_now(), 15, :minute)
             })
             |> Repo.insert()

    assert persisted.organization_id == organization.id
  end
end
