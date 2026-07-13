defmodule Plataforma.Repo.Migrations.EnsureOrganizationActiveAndSlugIndex do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add_if_not_exists :active, :boolean, null: false, default: true
    end

    create_if_not_exists unique_index(:organizations, [:slug],
                           name: :organizations_slug_unique_index
                         )
  end
end
