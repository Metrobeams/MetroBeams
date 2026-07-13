defmodule PlataformaWeb.ManufacturerController do
  use PlataformaWeb, :controller

  import Ecto.Query

  alias Plataforma.Assets
  alias Plataforma.Assets.Manufacturer
  alias Plataforma.Accounts.Scope

  plug :require_organization

  def index(%{assigns: %{organization: organization}} = conn, _params) do
    manufacturers = Assets.list_manufacturers(organization.id)
    render(conn, :index, manufacturers: manufacturers)
  end

  def show(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    manufacturer = Assets.get_manufacturer!(organization.id, id)
    render(conn, :show, manufacturer: manufacturer)
  end

  def new(%{assigns: %{organization: organization}} = conn, _params) do
    changeset =
      Manufacturer.create_changeset(%Manufacturer{organization_id: organization.id}, %{})

    form = Phoenix.Component.to_form(changeset)
    render(conn, :new, form: form)
  end

  def create(
        %{assigns: %{organization: organization}} = conn,
        %{"manufacturer" => manufacturer_params}
      ) do
    case Assets.create_manufacturer(organization.id, manufacturer_params) do
      {:ok, _manufacturer} ->
        conn
        |> put_flash(:info, "Fabricante criado com sucesso.")
        |> redirect(to: ~p"/manufacturers")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:new, form: Phoenix.Component.to_form(changeset))
    end
  end

  def edit(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    manufacturer = Assets.get_manufacturer!(organization.id, id)
    changeset = Manufacturer.update_changeset(manufacturer, %{})
    form = Phoenix.Component.to_form(changeset)
    render(conn, :edit, manufacturer: manufacturer, form: form)
  end

  def update(
        %{assigns: %{organization: organization}} = conn,
        %{"id" => id, "manufacturer" => manufacturer_params}
      ) do
    manufacturer = Assets.get_manufacturer!(organization.id, id)

    case Assets.update_manufacturer(organization.id, manufacturer, manufacturer_params) do
      {:ok, _manufacturer} ->
        conn
        |> put_flash(:info, "Fabricante atualizado com sucesso.")
        |> redirect(to: ~p"/manufacturers")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:edit, manufacturer: manufacturer, form: Phoenix.Component.to_form(changeset))
    end
  end

  def delete(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    manufacturer = Assets.get_manufacturer!(organization.id, id)
    {:ok, _manufacturer} = Assets.deactivate_manufacturer(organization.id, manufacturer)

    conn
    |> put_flash(:info, "Fabricante desativado com sucesso.")
    |> redirect(to: ~p"/manufacturers")
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
           :manage_manufacturers,
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
