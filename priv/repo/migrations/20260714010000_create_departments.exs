defmodule Plataforma.Repo.Migrations.CreateDepartments do
  use Ecto.Migration

  def change do
    create table(:departments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :code, :string
      add :description, :string
      add :active, :boolean, default: true, null: false

      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :nothing),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:departments, [:organization_id])

    create unique_index(:departments, [:organization_id, :name],
             where: "active = true",
             name: :departments_active_name_index
           )
  end
end
