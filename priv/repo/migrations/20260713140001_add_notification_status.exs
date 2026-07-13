defmodule Plataforma.Repo.Migrations.AddNotificationStatus do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add :status, :string, null: false, default: "info"
    end
  end
end
