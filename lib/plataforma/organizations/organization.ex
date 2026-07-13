defmodule Plataforma.Organizations.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    filterable: [:name, :slug, :active],
    sortable: [:name, :slug, :inserted_at, :updated_at],
    default_limit: 20,
    max_limit: 100,
    default_order: %{order_by: [:name], order_directions: [:asc]},
    pagination_types: [:page]
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organizations" do
    field :name, :string
    field :slug, :string
    field :settings, :map, default: %{}
    field :active, :boolean, default: true

    has_many :memberships, Plataforma.Organizations.Membership
    has_many :invitations, Plataforma.Organizations.Invitation
    timestamps(type: :utc_datetime_usec)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug, :settings, :active])
    |> trim_name()
    |> validate_required([:name])
    |> put_normalized_slug()
    |> validate_required([:slug, :active])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:slug, min: 2, max: 80)
    |> validate_change(:settings, fn :settings, value ->
      if is_map(value), do: [], else: [settings: "must be a map"]
    end)
    |> unique_constraint(:slug, name: :organizations_slug_unique_index)
  end

  defp trim_name(changeset) do
    update_change(changeset, :name, &String.trim/1)
  end

  defp put_normalized_slug(changeset) do
    source =
      cond do
        present_string?(get_change(changeset, :slug)) -> get_change(changeset, :slug)
        present_string?(get_field(changeset, :slug)) -> get_field(changeset, :slug)
        present_string?(get_field(changeset, :name)) -> get_field(changeset, :name)
        true -> nil
      end

    case slugify(source) do
      nil -> add_error(changeset, :slug, "could not be generated")
      slug -> put_change(changeset, :slug, slug)
    end
  end

  defp slugify(value) when is_binary(value) do
    case Slug.slugify(String.trim(value), separator: "-", lowercase: true, truncate: 80) do
      "" -> nil
      slug -> slug
    end
  end

  defp slugify(_value), do: nil

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
end
