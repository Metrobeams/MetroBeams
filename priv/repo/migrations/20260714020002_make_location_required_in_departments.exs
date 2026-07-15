defmodule Plataforma.Repo.Migrations.MakeLocationRequiredInDepartments do
  use Ecto.Migration

  def change do
    # Keep location_id as optional for now
    # User can set it later through the UI
    :ok
  end
end
