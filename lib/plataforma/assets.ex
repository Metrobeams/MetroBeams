defmodule Plataforma.Assets do
  @moduledoc """
  The Assets context.
  """

  import Ecto.Query

  alias Plataforma.Assets.AssetCategory
  alias Plataforma.Repo

  @doc """
  Returns the list of asset categories for an organization.

  ## Examples

      iex> list_categories(organization_id)
      [%AssetCategory{}, ...]

  """
  @spec list_categories(String.t()) :: [AssetCategory.t()]
  def list_categories(organization_id) do
    AssetCategory
    |> where([c], c.organization_id == ^organization_id and c.active)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  @doc """
  Gets a single asset category.

  Raises `Ecto.NoResultsError` if the AssetCategory does not exist or belongs to a different organization.

  ## Examples

      iex> get_category!(organization_id, id)
      %AssetCategory{}

      iex> get_category!(organization_id, bad_id)
      ** (Ecto.NoResultsError)

  """
  @spec get_category!(String.t(), String.t()) :: AssetCategory.t()
  def get_category!(organization_id, id) do
    AssetCategory
    |> where([c], c.id == ^id and c.organization_id == ^organization_id)
    |> Repo.one!()
  end

  @doc """
  Creates a asset category.

  ## Examples

      iex> create_category(organization_id, %{name: "Notebooks"})
      {:ok, %AssetCategory{}}

      iex> create_category(organization_id, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_category(String.t(), map()) ::
          {:ok, AssetCategory.t()} | {:error, Ecto.Changeset.t()}
  def create_category(organization_id, attrs) do
    %AssetCategory{organization_id: organization_id}
    |> AssetCategory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a asset category.

  ## Examples

      iex> update_category(organization_id, category, %{name: "Laptops"})
      {:ok, %AssetCategory{}}

      iex> update_category(organization_id, category, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_category(String.t(), AssetCategory.t(), map()) ::
          {:ok, AssetCategory.t()} | {:error, Ecto.Changeset.t()}
  def update_category(organization_id, %AssetCategory{} = category, attrs) do
    # Verify category belongs to organization
    if category.organization_id != organization_id do
      raise ArgumentError, "Category does not belong to this organization"
    end

    category
    |> AssetCategory.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deactivates a asset category (soft delete).

  ## Examples

      iex> delete_category(category)
      {:ok, %AssetCategory{}}

  """
  @spec delete_category(AssetCategory.t()) :: {:ok, AssetCategory.t()}
  def delete_category(%AssetCategory{} = category) do
    category
    |> Ecto.Changeset.change(active: false)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking asset category changes.

  ## Examples

      iex> change_category(category)
      %Ecto.Changeset{data: %AssetCategory{}}

  """
  @spec change_category(AssetCategory.t()) :: Ecto.Changeset.t()
  def change_category(%AssetCategory{} = category) do
    AssetCategory.changeset(category, %{})
  end
end
