defmodule Plataforma.Repo.Migrations.AddDepartmentIdToMemberships do
  use Ecto.Migration

  def change do
    alter table(:organization_memberships) do
      add :department_id,
          references(:departments, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:organization_memberships, [:department_id])
  end
end
