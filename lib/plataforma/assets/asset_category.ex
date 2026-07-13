defmodule Plataforma.Assets.AssetCategory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "asset_categories" do
    field :name, :string
    field :description, :string
    field :active, :boolean, default: true

    belongs_to :organization, Plataforma.Organizations.Organization

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(asset_category, attrs) do
    asset_category
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 100)
    |> unique_constraint(:name,
      name: :asset_categories_organization_name_unique_index,
      message: "já existe uma categoria com este nome nesta organização"
    )
  end
end
