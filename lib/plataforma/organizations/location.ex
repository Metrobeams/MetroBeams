defmodule Plataforma.Organizations.Location do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "locations" do
    field :name, :string
    field :tag_color, :string
    field :city, :string
    field :state, :string
    field :country, :string
    field :active, :boolean, default: true

    belongs_to :organization, Plataforma.Organizations.Organization, type: :binary_id

    has_many :departments, Plataforma.Organizations.Department

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  @spec create_changeset(t(), map()) :: Ecto.Changeset.t()
  def create_changeset(location, attrs) do
    location
    |> cast(attrs, [:name, :tag_color, :city, :state, :country])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:tag_color, max: 7)
    |> validate_length(:city, max: 100)
    |> validate_length(:state, max: 100)
    |> validate_length(:country, max: 100)
    |> normalize_fields()
    |> unique_constraint(:name,
      name: :locations_active_name_index,
      message: "já existe uma localização com este nome nesta organização"
    )
  end

  @doc false
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(location, attrs) do
    location
    |> cast(attrs, [:name, :tag_color, :city, :state, :country])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:tag_color, max: 7)
    |> validate_length(:city, max: 100)
    |> validate_length(:state, max: 100)
    |> validate_length(:country, max: 100)
    |> normalize_fields()
    |> unique_constraint(:name,
      name: :locations_active_name_index,
      message: "já existe uma localização com este nome nesta organização"
    )
  end

  @doc false
  @spec deactivate_changeset(t()) :: Ecto.Changeset.t()
  def deactivate_changeset(location) do
    location
    |> change(active: false)
  end

  defp normalize_fields(changeset) do
    changeset
    |> normalize_name()
    |> normalize_empty_strings([:tag_color, :city, :state, :country])
  end

  defp normalize_name(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        normalized = name |> String.trim() |> String.downcase()
        put_change(changeset, :name, normalized)
    end
  end

  defp normalize_empty_strings(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      case get_change(acc, field) do
        "" -> put_change(acc, field, nil)
        _ -> acc
      end
    end)
  end
end
