defmodule Plataforma.Repo.Migrations.CreateLocations do
  use Ecto.Migration

  def change do
    create table(:locations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :tag_color, :string
      add :city, :string
      add :state, :string
      add :country, :string
      add :active, :boolean, default: true, null: false

      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :nothing),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:locations, [:organization_id])

    create unique_index(:locations, [:organization_id, :name],
             where: "active = true",
             name: :locations_active_name_index
           )
  end
end
