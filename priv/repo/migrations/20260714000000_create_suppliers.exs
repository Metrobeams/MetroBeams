defmodule Plataforma.Repo.Migrations.CreateSuppliers do
  use Ecto.Migration

  def change do
    create table(:suppliers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :contact_name, :string
      add :email, :string
      add :phone, :string
      add :website, :string
      add :cnpj, :string
      add :address, :string
      add :notes, :string
      add :active, :boolean, default: true, null: false

      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :nothing),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:suppliers, [:organization_id])

    create unique_index(:suppliers, [:organization_id, :name],
             where: "active = true",
             name: :suppliers_active_name_index
           )
  end
end
