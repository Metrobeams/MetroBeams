defmodule PlataformaWeb.LocationController do
  use PlataformaWeb, :controller

  import Ecto.Query

  alias Plataforma.Organizations
  alias Plataforma.Organizations.Location
  alias Plataforma.Accounts.Scope

  plug :require_organization

  def index(%{assigns: %{organization: organization}} = conn, _params) do
    locations = Organizations.list_locations(organization.id)
    render(conn, :index, locations: locations)
  end

  def show(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    location = Organizations.get_location!(organization.id, id)
    render(conn, :show, location: location)
  end

  def new(%{assigns: %{organization: organization}} = conn, _params) do
    changeset =
      Location.create_changeset(%Location{organization_id: organization.id}, %{})

    form = Phoenix.Component.to_form(changeset)
    render(conn, :new, form: form)
  end

  def create(
        %{assigns: %{organization: organization}} = conn,
        %{"location" => location_params}
      ) do
    case Organizations.create_location(organization.id, location_params) do
      {:ok, _location} ->
        conn
        |> put_flash(:info, "Localização criada com sucesso.")
        |> redirect(to: ~p"/locations")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:new, form: Phoenix.Component.to_form(changeset))
    end
  end

  def edit(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    location = Organizations.get_location!(organization.id, id)
    changeset = Location.update_changeset(location, %{})
    form = Phoenix.Component.to_form(changeset)
    render(conn, :edit, location: location, form: form)
  end

  def update(
        %{assigns: %{organization: organization}} = conn,
        %{"id" => id, "location" => location_params}
      ) do
    location = Organizations.get_location!(organization.id, id)

    case Organizations.update_location(organization.id, location, location_params) do
      {:ok, _location} ->
        conn
        |> put_flash(:info, "Localização atualizada com sucesso.")
        |> redirect(to: ~p"/locations")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:edit, location: location, form: Phoenix.Component.to_form(changeset))
    end
  end

  def delete(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    location = Organizations.get_location!(organization.id, id)
    {:ok, _location} = Organizations.deactivate_location(organization.id, location)

    conn
    |> put_flash(:info, "Localização desativada com sucesso.")
    |> redirect(to: ~p"/locations")
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
           :manage_locations,
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
