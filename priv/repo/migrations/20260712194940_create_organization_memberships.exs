defmodule Plataforma.Repo.Migrations.CreateOrganizationMemberships do
  use Ecto.Migration

  def change do
    create table(:organization_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, on_delete: :restrict), null: false
      add :role, :string, null: false
      add :active, :boolean, null: false, default: true
      add :job_title, :string
      add :department, :string
      add :employee_code, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:organization_memberships, [:organization_id, :user_id],
             name: :organization_memberships_organization_user_unique_index
           )

    create unique_index(:organization_memberships, [:organization_id, :employee_code],
             where: "employee_code IS NOT NULL",
             name: :organization_memberships_employee_code_unique_index
           )

    create index(:organization_memberships, [:user_id, :active])
    create index(:organization_memberships, [:organization_id, :role], where: "active = true")

    create constraint(:organization_memberships, :organization_memberships_role_check,
             check: "role IN ('owner', 'admin', 'technician', 'member')"
           )
  end
end
