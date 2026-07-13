defmodule Plataforma.Repo.Migrations.CreateAssetCategories do
  use Ecto.Migration

  def change do
    create table(:asset_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :description, :string
      add :active, :boolean, null: false, default: true
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:asset_categories, [:organization_id, :name],
             name: :asset_categories_organization_name_unique_index
           )

    create index(:asset_categories, [:organization_id, :active])
  end
end
