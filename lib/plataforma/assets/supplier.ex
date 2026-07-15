defmodule Plataforma.Assets.Supplier do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "suppliers" do
    field :name, :string
    field :contact_name, :string
    field :email, :string
    field :phone, :string
    field :website, :string
    field :cnpj, :string
    field :address, :string
    field :notes, :string
    field :active, :boolean, default: true

    belongs_to :organization, Plataforma.Organizations.Organization, type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  @spec create_changeset(t(), map()) :: Ecto.Changeset.t()
  def create_changeset(supplier, attrs) do
    supplier
    |> cast(attrs, [:name, :contact_name, :email, :phone, :website, :cnpj, :address, :notes])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:contact_name, max: 120)
    |> validate_length(:email, max: 255)
    |> validate_length(:phone, max: 30)
    |> validate_length(:website, max: 500)
    |> validate_length(:cnpj, max: 20)
    |> validate_length(:address, max: 500)
    |> validate_length(:notes, max: 2000)
    |> normalize_fields()
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "deve ser um email válido")
    |> validate_url(:website)
    |> unique_constraint(:name,
      name: :suppliers_active_name_index,
      message: "já existe um fornecedor com este nome nesta organização"
    )
  end

  @doc false
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(supplier, attrs) do
    supplier
    |> cast(attrs, [:name, :contact_name, :email, :phone, :website, :cnpj, :address, :notes])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:contact_name, max: 120)
    |> validate_length(:email, max: 255)
    |> validate_length(:phone, max: 30)
    |> validate_length(:website, max: 500)
    |> validate_length(:cnpj, max: 20)
    |> validate_length(:address, max: 500)
    |> validate_length(:notes, max: 2000)
    |> normalize_fields()
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "deve ser um email válido")
    |> validate_url(:website)
    |> unique_constraint(:name,
      name: :suppliers_active_name_index,
      message: "já existe um fornecedor com este nome nesta organização"
    )
  end

  @doc false
  @spec deactivate_changeset(t()) :: Ecto.Changeset.t()
  def deactivate_changeset(supplier) do
    supplier
    |> change(active: false)
  end

  defp normalize_fields(changeset) do
    changeset
    |> normalize_name()
    |> normalize_empty_strings([:contact_name, :email, :phone, :website, :cnpj, :address, :notes])
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
