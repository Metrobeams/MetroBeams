defmodule Plataforma.Repo.Migrations.CreateAgentsAndEnrollmentTokens do
  use Ecto.Migration

  def change do
    create table(:agents, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :restrict),
          null: false

      add :machine_id, :string, null: false
      add :hostname, :string, null: false
      add :platform, :string, null: false
      add :architecture, :string, null: false
      add :agent_version, :string, null: false
      add :credential_digest, :binary, null: false
      add :active, :boolean, null: false, default: true
      add :enrolled_at, :utc_datetime_usec, null: false
      add :last_seen_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:agents, [:organization_id])

    create unique_index(:agents, [:organization_id, :machine_id],
             name: :agents_organization_machine_id_unique_index
           )

    create table(:agent_enrollment_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :restrict),
          null: false

      add :token_digest, :binary, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :consumed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:agent_enrollment_tokens, [:organization_id])
    create unique_index(:agent_enrollment_tokens, [:token_digest])
  end
end
