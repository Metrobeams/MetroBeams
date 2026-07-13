defmodule Plataforma.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :title, :string, null: false
      add :body, :text, null: false
      add :action_path, :string
      add :metadata, :map, null: false, default: %{}
      add :read_at, :utc_datetime_usec
      add :dedupe_key, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:notifications, [:user_id, :inserted_at])
    create index(:notifications, [:user_id, :read_at])
    create unique_index(:notifications, [:user_id, :dedupe_key])
  end
end
