defmodule Plataforma.Assets.Manufacturer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "manufacturers" do
    field :name, :string
    field :website, :string
    field :support_url, :string
    field :active, :boolean, default: true

    belongs_to :organization, Plataforma.Organizations.Organization, type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  @spec create_changeset(t(), map()) :: Ecto.Changeset.t()
  def create_changeset(manufacturer, attrs) do
    manufacturer
    |> cast(attrs, [:name, :website, :support_url])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:website, max: 500)
    |> validate_length(:support_url, max: 500)
    |> normalize_fields()
    |> validate_url(:website)
    |> validate_url(:support_url)
    |> unique_constraint(:name,
      name: :manufacturers_active_name_index,
      message: "já existe um fabricante com este nome nesta organização"
    )
  end

  @doc false
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(manufacturer, attrs) do
    manufacturer
    |> cast(attrs, [:name, :website, :support_url])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:website, max: 500)
    |> validate_length(:support_url, max: 500)
    |> normalize_fields()
    |> validate_url(:website)
    |> validate_url(:support_url)
    |> unique_constraint(:name,
      name: :manufacturers_active_name_index,
      message: "já existe um fabricante com este nome nesta organização"
    )
  end

  @doc false
  @spec deactivate_changeset(t()) :: Ecto.Changeset.t()
  def deactivate_changeset(manufacturer) do
    manufacturer
    |> change(active: false)
  end

  defp normalize_fields(changeset) do
    changeset
    |> normalize_name()
    |> normalize_empty_strings([:website, :support_url])
  end

  defp normalize_name(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        trimmed = String.trim(name)
        put_change(changeset, :name, trimmed)
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

  defp validate_url(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      url ->
        case URI.parse(url) do
          %URI{scheme: scheme, host: host}
          when scheme in ["http", "https"] and is_binary(host) and byte_size(host) > 0 ->
            changeset

          _ ->
            add_error(changeset, field, "deve ser uma URL válida")
        end
    end
  end
end
