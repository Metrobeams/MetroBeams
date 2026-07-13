defmodule Plataforma.Repo.Migrations.EnableCitext do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS citext")
  end

  def down, do: :ok
end
