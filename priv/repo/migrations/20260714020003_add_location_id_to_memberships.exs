defmodule Plataforma.Repo.Migrations.AddLocationIdToMemberships do
  use Ecto.Migration

  def change do
    alter table(:organization_memberships) do
      add :location_id,
          references(:locations, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:organization_memberships, [:location_id])
  end
end
