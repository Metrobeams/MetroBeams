defmodule Plataforma.Organizations.Department do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "departments" do
    field :name, :string
    field :code, :string
    field :description, :string
    field :active, :boolean, default: true

    belongs_to :organization, Plataforma.Organizations.Organization, type: :binary_id

    has_many :memberships, Plataforma.Organizations.Membership

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  @spec create_changeset(t(), map()) :: Ecto.Changeset.t()
  def create_changeset(department, attrs) do
    department
    |> cast(attrs, [:name, :code, :description])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:code, max: 20)
    |> validate_length(:description, max: 500)
    |> normalize_fields()
    |> unique_constraint(:name,
      name: :departments_active_name_index,
      message: "já existe um departamento com este nome nesta organização"
    )
  end

  @doc false
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(department, attrs) do
    department
    |> cast(attrs, [:name, :code, :description])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:code, max: 20)
    |> validate_length(:description, max: 500)
    |> normalize_fields()
    |> unique_constraint(:name,
      name: :departments_active_name_index,
      message: "já existe um departamento com este nome nesta organização"
    )
  end

  @doc false
  @spec deactivate_changeset(t()) :: Ecto.Changeset.t()
  def deactivate_changeset(department) do
    department
    |> change(active: false)
  end

  defp normalize_fields(changeset) do
    changeset
    |> normalize_name()
    |> normalize_code()
    |> normalize_empty_strings([:description])
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

  defp normalize_code(changeset) do
    case get_change(changeset, :code) do
      nil ->
        changeset

      code ->
        normalized = code |> String.trim() |> String.upcase()
        put_change(changeset, :code, normalized)
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
