defmodule Plataforma.Repo.Migrations.AddUserAvatarMetadata do
  use Ecto.Migration

  def change do
    rename table(:users), :avatar_url, to: :avatar_key

    alter table(:users) do
      add :avatar_content_type, :string
      add :avatar_size, :bigint
      add :avatar_updated_at, :utc_datetime
    end
  end
end
