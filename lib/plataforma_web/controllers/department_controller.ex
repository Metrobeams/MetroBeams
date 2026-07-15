defmodule PlataformaWeb.DepartmentController do
  use PlataformaWeb, :controller

  import Ecto.Query

  alias Plataforma.Organizations
  alias Plataforma.Organizations.Department
  alias Plataforma.Accounts.Scope

  plug :require_organization

  def index(%{assigns: %{organization: organization}} = conn, _params) do
    departments = Organizations.list_departments(organization.id)
    render(conn, :index, departments: departments)
  end

  def show(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    department = Organizations.get_department!(organization.id, id)
    render(conn, :show, department: department)
  end

  def new(%{assigns: %{organization: organization}} = conn, _params) do
    changeset =
      Department.create_changeset(%Department{organization_id: organization.id}, %{})

    locations = Organizations.list_locations(organization.id)
    form = Phoenix.Component.to_form(changeset)
    render(conn, :new, form: form, locations: locations)
  end

  def create(
        %{assigns: %{organization: organization}} = conn,
        %{"department" => department_params}
      ) do
    case Organizations.create_department(organization.id, department_params) do
      {:ok, _department} ->
        conn
        |> put_flash(:info, "Departamento criado com sucesso.")
        |> redirect(to: ~p"/departments")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:new, form: Phoenix.Component.to_form(changeset))
    end
  end

  def edit(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    department = Organizations.get_department!(organization.id, id)
    changeset = Department.update_changeset(department, %{})
    locations = Organizations.list_locations(organization.id)
    form = Phoenix.Component.to_form(changeset)
    render(conn, :edit, department: department, form: form, locations: locations)
  end

  def update(
        %{assigns: %{organization: organization}} = conn,
        %{"id" => id, "department" => department_params}
      ) do
    department = Organizations.get_department!(organization.id, id)

    case Organizations.update_department(organization.id, department, department_params) do
      {:ok, _department} ->
        conn
        |> put_flash(:info, "Departamento atualizado com sucesso.")
        |> redirect(to: ~p"/departments")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:edit, department: department, form: Phoenix.Component.to_form(changeset))
    end
  end

  def delete(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    department = Organizations.get_department!(organization.id, id)
    {:ok, _department} = Organizations.deactivate_department(organization.id, department)

    conn
    |> put_flash(:info, "Departamento desativado com sucesso.")
    |> redirect(to: ~p"/departments")
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
           :manage_departments,
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
