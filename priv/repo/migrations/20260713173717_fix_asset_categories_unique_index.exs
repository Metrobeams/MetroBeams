defmodule Plataforma.Repo.Migrations.FixAssetCategoriesUniqueIndex do
  use Ecto.Migration

  def change do
    # Drop the existing unique index
    drop_if_exists index(:asset_categories, [:organization_id, :name],
                     name: :asset_categories_organization_name_unique_index
                   )

    # Create a partial unique index that only applies to active records
    create unique_index(:asset_categories, [:organization_id, :name],
             name: :asset_categories_organization_name_unique_index,
             where: "active = true"
           )
  end
end
