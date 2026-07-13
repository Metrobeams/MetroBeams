defmodule Plataforma.Repo.Migrations.CreateOrganizationsAndUpdateUsers do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text, null: false
      add :slug, :citext, null: false
      add :settings, :map, null: false, default: %{}

      timestamps(type: :timestamptz)
    end

    create unique_index(:organizations, [:slug])

    alter table(:users) do
      add :avatar_url, :text
      add :active, :boolean, null: false, default: true
    end
  end
end
