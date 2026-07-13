defmodule PlataformaWeb.AssetCategoryController do
  use PlataformaWeb, :controller

  import Ecto.Query

  alias Plataforma.Assets
  alias Plataforma.Assets.AssetCategory
  alias Plataforma.Accounts.Scope

  plug :require_organization

  def index(
        %{assigns: %{current_scope: %Scope{}, organization: organization}} = conn,
        _params
      ) do
    categories = Assets.list_categories(organization.id)
    render(conn, :index, categories: categories)
  end

  def new(%{assigns: %{organization: organization}} = conn, _params) do
    changeset = Assets.change_category(%AssetCategory{organization_id: organization.id})
    form = Phoenix.Component.to_form(changeset)
    render(conn, :new, form: form)
  end

  def create(
        %{assigns: %{current_scope: %Scope{user: _user}, organization: organization}} = conn,
        %{"asset_category" => category_params}
      ) do
    case Assets.create_category(organization.id, category_params) do
      {:ok, _category} ->
        conn
        |> put_flash(:info, "Categoria criada com sucesso.")
        |> redirect(to: ~p"/asset-categories")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:new, form: Phoenix.Component.to_form(changeset))
    end
  end

  def edit(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    category = Assets.get_category!(organization.id, id)
    changeset = Assets.change_category(category)
    form = Phoenix.Component.to_form(changeset)
    render(conn, :edit, category: category, form: form)
  end

  def update(
        %{assigns: %{current_scope: %Scope{user: _user}, organization: organization}} = conn,
        %{"id" => id, "asset_category" => category_params}
      ) do
    category = Assets.get_category!(organization.id, id)

    case Assets.update_category(organization.id, category, category_params) do
      {:ok, _category} ->
        conn
        |> put_flash(:info, "Categoria atualizada com sucesso.")
        |> redirect(to: ~p"/asset-categories")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:edit, category: category, form: Phoenix.Component.to_form(changeset))
    end
  end

  def delete(%{assigns: %{organization: organization}} = conn, %{"id" => id}) do
    category = Assets.get_category!(organization.id, id)
    {:ok, _category} = Assets.delete_category(category)

    conn
    |> put_flash(:info, "Categoria removida com sucesso.")
    |> redirect(to: ~p"/asset-categories")
  end

  defp require_organization(conn, _opts) do
    case conn.assigns do
      %{current_scope: %Scope{user: user}} ->
        # Get the first organization the user belongs to
        query =
          from org in Plataforma.Organizations.Organization,
            join: m in Plataforma.Organizations.Membership,
            on: m.organization_id == org.id and m.user_id == ^user.id and m.active,
            where: org.active,
            limit: 1

        case Plataforma.Repo.one(query) do
          nil ->
            conn
            |> put_flash(:error, "Você precisa pertencer a uma organização.")
            |> redirect(to: ~p"/")
            |> Plug.Conn.halt()

          organization ->
            Plug.Conn.assign(conn, :organization, organization)
        end

      _ ->
        conn
        |> put_flash(:error, "Faça login para continuar.")
        |> redirect(to: ~p"/users/log-in")
        |> Plug.Conn.halt()
    end
  end
end
