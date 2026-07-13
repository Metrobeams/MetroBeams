defmodule Plataforma.Repo.Migrations.CreateManufacturers do
  use Ecto.Migration

  def change do
    create table(:manufacturers, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id,
          references(:organizations,
            type: :binary_id,
            on_delete: :delete_all
          ),
          null: false

      add :name, :string, null: false
      add :website, :string
      add :support_url, :string
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:manufacturers, [:organization_id])

    create unique_index(:manufacturers, [:organization_id, :name],
             where: "active = true",
             name: :manufacturers_active_name_index
           )
  end
end
