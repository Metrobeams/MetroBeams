defmodule Plataforma.Repo.Migrations.AlignOrganizationsWithMultiTenantSpec do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add_if_not_exists :active, :boolean, null: false, default: true
    end

    drop_if_exists unique_index(:organizations, [:slug])

    create unique_index(:organizations, [:slug], name: :organizations_slug_unique_index)
  end
end
