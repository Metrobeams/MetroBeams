defmodule Plataforma.Assets do
  @moduledoc """
  The Assets context.
  """

  import Ecto.Query

  alias Plataforma.Assets.AssetCategory
  alias Plataforma.Assets.Manufacturer
  alias Plataforma.Assets.Supplier
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

  # Manufacturers

  @doc """
  Returns the list of active manufacturers for an organization.
  """
  @spec list_manufacturers(String.t()) :: [Manufacturer.t()]
  def list_manufacturers(organization_id) do
    Manufacturer
    |> where([m], m.organization_id == ^organization_id and m.active)
    |> order_by([m], asc: m.name)
    |> Repo.all()
  end

  @doc """
  Gets a single manufacturer.

  Raises `Ecto.NoResultsError` if the Manufacturer does not exist,
  belongs to a different organization, or is inactive.
  """
  @spec get_manufacturer!(String.t(), String.t()) :: Manufacturer.t()
  def get_manufacturer!(organization_id, id) do
    Manufacturer
    |> where([m], m.id == ^id and m.organization_id == ^organization_id and m.active)
    |> Repo.one!()
  end

  @doc """
  Creates a manufacturer.
  """
  @spec create_manufacturer(String.t(), map()) ::
          {:ok, Manufacturer.t()} | {:error, Ecto.Changeset.t()}
  def create_manufacturer(organization_id, attrs) do
    %Manufacturer{organization_id: organization_id}
    |> Manufacturer.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a manufacturer.
  """
  @spec update_manufacturer(String.t(), Manufacturer.t(), map()) ::
          {:ok, Manufacturer.t()} | {:error, Ecto.Changeset.t()}
  def update_manufacturer(organization_id, %Manufacturer{} = manufacturer, attrs) do
    if manufacturer.organization_id != organization_id do
      raise ArgumentError, "Manufacturer does not belong to this organization"
    end

    manufacturer
    |> Manufacturer.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deactivates a manufacturer (soft delete).
  """
  @spec deactivate_manufacturer(String.t(), Manufacturer.t()) ::
          {:ok, Manufacturer.t()}
  def deactivate_manufacturer(organization_id, %Manufacturer{} = manufacturer) do
    if manufacturer.organization_id != organization_id do
      raise ArgumentError, "Manufacturer does not belong to this organization"
    end

    manufacturer
    |> Manufacturer.deactivate_changeset()
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking manufacturer changes.
  """
  @spec change_manufacturer(Manufacturer.t()) :: Ecto.Changeset.t()
  def change_manufacturer(%Manufacturer{} = manufacturer) do
    Manufacturer.create_changeset(manufacturer, %{})
  end

  # Suppliers

  @doc """
  Returns the list of active suppliers for an organization.
  """
  @spec list_suppliers(String.t()) :: [Supplier.t()]
  def list_suppliers(organization_id) do
    Supplier
    |> where([s], s.organization_id == ^organization_id and s.active)
    |> order_by([s], asc: s.name)
    |> Repo.all()
  end

  @doc """
  Gets a single supplier.

  Raises `Ecto.NoResultsError` if the Supplier does not exist,
  belongs to a different organization, or is inactive.
  """
  @spec get_supplier!(String.t(), String.t()) :: Supplier.t()
  def get_supplier!(organization_id, id) do
    Supplier
    |> where([s], s.id == ^id and s.organization_id == ^organization_id and s.active)
    |> Repo.one!()
  end

  @doc """
  Creates a supplier.
  """
  @spec create_supplier(String.t(), map()) ::
          {:ok, Supplier.t()} | {:error, Ecto.Changeset.t()}
  def create_supplier(organization_id, attrs) do
    %Supplier{organization_id: organization_id}
    |> Supplier.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a supplier.
  """
  @spec update_supplier(String.t(), Supplier.t(), map()) ::
          {:ok, Supplier.t()} | {:error, Ecto.Changeset.t()}
  def update_supplier(organization_id, %Supplier{} = supplier, attrs) do
    if supplier.organization_id != organization_id do
      raise ArgumentError, "Supplier does not belong to this organization"
    end

    supplier
    |> Supplier.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deactivates a supplier (soft delete).
  """
  @spec deactivate_supplier(String.t(), Supplier.t()) ::
          {:ok, Supplier.t()}
  def deactivate_supplier(organization_id, %Supplier{} = supplier) do
    if supplier.organization_id != organization_id do
      raise ArgumentError, "Supplier does not belong to this organization"
    end

    supplier
    |> Supplier.deactivate_changeset()
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking supplier changes.
  """
  @spec change_supplier(Supplier.t()) :: Ecto.Changeset.t()
  def change_supplier(%Supplier{} = supplier) do
    Supplier.create_changeset(supplier, %{})
  end
end
