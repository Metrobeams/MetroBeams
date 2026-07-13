defmodule Plataforma.Repo.Migrations.CreateOrganizationInvitations do
  use Ecto.Migration

  def change do
    create table(:organization_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :invited_by_membership_id,
          references(:organization_memberships, type: :binary_id, on_delete: :restrict),
          null: false

      add :email, :citext, null: false
      add :role, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :accepted_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:organization_invitations, :organization_invitations_role_check,
             check: "role IN ('admin', 'technician', 'member')"
           )

    create unique_index(:organization_invitations, [:organization_id, :email],
             where: "accepted_at IS NULL AND revoked_at IS NULL",
             name: :organization_invitations_open_email_unique_index
           )

    create index(:organization_invitations, [:organization_id, :inserted_at])
  end
end
