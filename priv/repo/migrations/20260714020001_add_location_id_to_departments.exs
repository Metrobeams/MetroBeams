defmodule Plataforma.Repo.Migrations.AddLocationIdToDepartments do
  use Ecto.Migration

  def change do
    alter table(:departments) do
      add :location_id,
          references(:locations, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:departments, [:location_id])
  end
end
