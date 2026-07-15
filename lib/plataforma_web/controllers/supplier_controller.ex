defmodule PlataformaWeb.SupplierController do
  use PlataformaWeb, :controller

  import Ecto.Query

  alias Plataforma.Assets
  alias Plataforma.Assets.Supplier
  alias Plataforma.Accounts.Scope

  plug :require_organization

  def index(%{assigns: %{organization: organization}} = conn, _params) do
    suppliers = Assets.list_suppliers(organization.id)
    render(conn, :index, suppliers: suppliers)
  end

  def show(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    supplier = Assets.get_supplier!(organization.id, id)
    render(conn, :show, supplier: supplier)
  end

  def new(%{assigns: %{organization: organization}} = conn, _params) do
    changeset =
      Supplier.create_changeset(%Supplier{organization_id: organization.id}, %{})

    form = Phoenix.Component.to_form(changeset)
    render(conn, :new, form: form)
  end

  def create(
        %{assigns: %{organization: organization}} = conn,
        %{"supplier" => supplier_params}
      ) do
    case Assets.create_supplier(organization.id, supplier_params) do
      {:ok, _supplier} ->
        conn
        |> put_flash(:info, "Fornecedor criado com sucesso.")
        |> redirect(to: ~p"/suppliers")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:new, form: Phoenix.Component.to_form(changeset))
    end
  end

  def edit(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    supplier = Assets.get_supplier!(organization.id, id)
    changeset = Supplier.update_changeset(supplier, %{})
    form = Phoenix.Component.to_form(changeset)
    render(conn, :edit, supplier: supplier, form: form)
  end

  def update(
        %{assigns: %{organization: organization}} = conn,
        %{"id" => id, "supplier" => supplier_params}
      ) do
    supplier = Assets.get_supplier!(organization.id, id)

    case Assets.update_supplier(organization.id, supplier, supplier_params) do
      {:ok, _supplier} ->
        conn
        |> put_flash(:info, "Fornecedor atualizado com sucesso.")
        |> redirect(to: ~p"/suppliers")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:edit, supplier: supplier, form: Phoenix.Component.to_form(changeset))
    end
  end

  def delete(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    supplier = Assets.get_supplier!(organization.id, id)
    {:ok, _supplier} = Assets.deactivate_supplier(organization.id, supplier)

    conn
    |> put_flash(:info, "Fornecedor desativado com sucesso.")
    |> redirect(to: ~p"/suppliers")
  end

  defp require_organization(conn, _opts) do
    case conn.assigns do
      %{current_scope: %Scope{user: user}} ->
        query =
          from org in Plataforma.Organizations.Organization,
            join: m in Plataforma.Organizations.Membership,
            on: m.organization_id == org.id and m.user_id == ^user.id and m.active,
            where: org.active,
            select: {org, m},
            limit: 1

        case Plataforma.Repo.one(query) do
          nil ->
            conn
            |> put_flash(:error, "Você precisa pertencer a uma organização.")
            |> redirect(to: ~p"/")
            |> Plug.Conn.halt()

          {organization, membership} ->
            permit_and_assign(conn, membership, organization)
        end

      _ ->
        conn
        |> put_flash(:error, "Faça login para continuar.")
        |> redirect(to: ~p"/users/log-in")
        |> Plug.Conn.halt()
    end
  end

  defp permit_and_assign(conn, membership, organization) do
    case Bodyguard.permit(
           Plataforma.Organizations.Policy,
           :manage_suppliers,
           membership,
           organization
         ) do
      :ok ->
        conn
        |> Plug.Conn.assign(:organization, organization)
        |> Plug.Conn.assign(:membership, membership)

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "Você não tem permissão para acessar esta funcionalidade.")
        |> redirect(to: ~p"/")
        |> Plug.Conn.halt()
    end
  end
end
