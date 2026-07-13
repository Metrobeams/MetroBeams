defmodule PlataformaWeb.OrganizationController do
  use PlataformaWeb, :controller

  alias Plataforma.Accounts.Scope
  alias Plataforma.Organizations
  alias Plataforma.Organizations.Membership
  alias Plataforma.Organizations.Organization
  alias Plataforma.Organizations.Policy

  def new(%{assigns: %{current_scope: %Scope{user: _user}}} = conn, _params) do
    form =
      %Organization{}
      |> Organizations.change_organization()
      |> Phoenix.Component.to_form()

    render(conn, :new, form: form)
  end

  def create(
        %{assigns: %{current_scope: %Scope{user: user}}} = conn,
        %{"organization" => params}
      ) do
    case Organizations.create_organization(user, Map.take(params, ["name"])) do
      {:ok, %{organization: %Organization{}}} ->
        conn
        |> put_flash(:info, "Organização criada com sucesso.")
        |> redirect(to: ~p"/")

      {:error, :organization, changeset, _changes} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:new, form: Phoenix.Component.to_form(changeset))
    end
  end

  def edit(%{assigns: %{current_scope: %Scope{user: user}}} = conn, %{"id" => id}) do
    case editable_organization(user, id) do
      {:ok, organization, %Membership{}} ->
        form = organization |> Organizations.change_organization() |> Phoenix.Component.to_form()
        render(conn, :edit, form: form, organization: organization)

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Not Found")
    end
  end

  def update(
        %{assigns: %{current_scope: %Scope{user: user}}} = conn,
        %{"id" => id, "organization" => params}
      ) do
    case editable_organization(user, id) do
      {:ok, organization, %Membership{} = actor} ->
        case Organizations.update_organization(
               actor,
               organization,
               Map.take(params, ["name"])
             ) do
          {:ok, %Organization{}} ->
            conn
            |> put_flash(:info, "Organização atualizada com sucesso.")
            |> redirect(to: ~p"/")

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(:edit,
              form: Phoenix.Component.to_form(changeset),
              organization: organization
            )
        end

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Not Found")
    end
  end

  defp editable_organization(user, id) do
    with {:ok, organization_id} <- Ecto.UUID.cast(id),
         {:ok, %Organization{} = organization} <-
           Organizations.get_organization_for_user(user, organization_id),
         %Membership{} = actor <- Organizations.get_active_membership(user, organization),
         true <- Policy.authorize(:update_organization, actor, organization) do
      {:ok, organization, actor}
    else
      _reason -> {:error, :not_found}
    end
  end
end
