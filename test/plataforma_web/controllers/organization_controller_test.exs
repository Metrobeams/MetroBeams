defmodule PlataformaWeb.OrganizationControllerTest do
  use PlataformaWeb.ConnCase, async: true

  import Plataforma.AccountsFixtures

  alias Plataforma.Organizations
  alias Plataforma.Organizations.Membership

  setup :register_and_log_in_user

  test "GET /organizations/new renders the organization form", %{conn: conn} do
    document =
      conn
      |> get(~p"/organizations/new")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert_element(document, "#organization-form")
    assert_element(document, "#organization-name[name='organization[name]']")
    refute_element(document, "[name='organization[slug]']")
    refute_element(document, "[name='organization[settings]']")
    refute_element(document, "[name='organization[active]']")
  end

  test "POST /organizations creates the organization with the current user as owner", %{
    conn: conn,
    user: user
  } do
    name = "Organização #{System.unique_integer([:positive])}"

    conn = post(conn, ~p"/organizations", %{organization: %{name: name}})

    assert redirected_to(conn) == ~p"/"
    assert Phoenix.Flash.get(conn.assigns.flash, :info)
    assert {:ok, {organizations, %Flop.Meta{}}} = Organizations.list_organizations(user)
    assert organization = Enum.find(organizations, &(&1.name == name))

    assert %Membership{role: :owner, active: true} =
             Organizations.get_active_membership(user, organization)
  end

  test "POST /organizations renders invalid data without creating an organization", %{
    conn: conn,
    user: user
  } do
    conn = post(conn, ~p"/organizations", %{organization: %{name: "A"}})

    document = conn |> html_response(422) |> LazyHTML.from_document()

    assert_element(document, "#organization-form")
    assert_element(document, "#organization-name[value='A']")
    assert {:ok, {[], %Flop.Meta{}}} = Organizations.list_organizations(user)
  end

  test "POST /organizations ignores organization fields outside the form contract", %{
    conn: conn,
    user: user
  } do
    name = "Organização protegida #{System.unique_integer([:positive])}"

    conn =
      post(conn, ~p"/organizations", %{
        organization: %{
          name: name,
          slug: "slug-enviado",
          settings: %{"injected" => true},
          active: false
        }
      })

    assert redirected_to(conn) == ~p"/"

    assert {:ok, {organizations, %Flop.Meta{}}} =
             Organizations.list_organizations(user, %{}, include_inactive: true)

    assert organization = Enum.find(organizations, &(&1.name == name))
    assert organization.active
    assert organization.settings == %{}
    refute organization.slug == "slug-enviado"
  end

  test "GET /organizations/:id/edit renders the form for the owner", %{
    conn: conn,
    user: user
  } do
    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{
        name: "Organização editável #{System.unique_integer([:positive])}"
      })

    document =
      conn
      |> get(~p"/organizations/#{organization}/edit")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert_element(document, "#organization-edit")
    assert_element(document, "#organization-form")
    assert_element(document, "#organization-name[value='#{organization.name}']")
  end

  test "PUT /organizations/:id updates the name and preserves the slug for the owner", %{
    conn: conn,
    user: user
  } do
    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{
        name: "Nome original #{System.unique_integer([:positive])}"
      })

    new_name = "Nome atualizado #{System.unique_integer([:positive])}"
    conn = put(conn, ~p"/organizations/#{organization}", %{organization: %{name: new_name}})

    assert redirected_to(conn) == ~p"/"
    assert Phoenix.Flash.get(conn.assigns.flash, :info)
    assert {:ok, updated} = Organizations.get_organization_for_user(user, organization.id)
    assert updated.name == new_name
    assert updated.slug == organization.slug
  end

  test "PUT /organizations/:id renders invalid data without changing the organization", %{
    conn: conn,
    user: user
  } do
    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{
        name: "Nome preservado #{System.unique_integer([:positive])}"
      })

    conn = put(conn, ~p"/organizations/#{organization}", %{organization: %{name: "A"}})
    document = conn |> html_response(422) |> LazyHTML.from_document()

    assert_element(document, "#organization-edit")
    assert_element(document, "#organization-name[value='A']")
    assert {:ok, unchanged} = Organizations.get_organization_for_user(user, organization.id)
    assert unchanged.name == organization.name
    assert unchanged.slug == organization.slug
  end

  test "PUT /organizations/:id ignores organization fields outside the form contract", %{
    conn: conn,
    user: user
  } do
    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{
        name: "Organização protegida #{System.unique_integer([:positive])}"
      })

    new_name = "Nome permitido #{System.unique_integer([:positive])}"

    conn =
      put(conn, ~p"/organizations/#{organization}", %{
        organization: %{
          name: new_name,
          slug: "slug-injetado",
          settings: %{"injected" => true},
          active: false
        }
      })

    assert redirected_to(conn) == ~p"/"
    assert {:ok, updated} = Organizations.get_organization_for_user(user, organization.id)
    assert updated.name == new_name
    assert updated.slug == organization.slug
    assert updated.settings == organization.settings
    assert updated.active == organization.active
  end

  test "an admin can open and update an organization", %{conn: conn, user: user} do
    organization = organization_for_member(user, :admin)
    new_name = "Nome administrativo #{System.unique_integer([:positive])}"

    assert conn |> get(~p"/organizations/#{organization}/edit") |> html_response(200)

    update_conn =
      put(conn, ~p"/organizations/#{organization}", %{organization: %{name: new_name}})

    assert redirected_to(update_conn) == ~p"/"
    assert {:ok, updated} = Organizations.get_organization_for_user(user, organization.id)
    assert updated.name == new_name
  end

  test "edit returns 404 for roles without permission and unavailable organizations", %{
    conn: conn,
    user: user
  } do
    member_organization = organization_for_member(user, :member)
    technician_organization = organization_for_member(user, :technician)
    other_user = user_fixture()

    {:ok, %{organization: other_organization}} =
      Organizations.create_organization(other_user, %{
        name: "Outro tenant #{System.unique_integer([:positive])}"
      })

    unavailable_ids = [
      member_organization.id,
      technician_organization.id,
      other_organization.id,
      Ecto.UUID.generate(),
      "uuid-invalido"
    ]

    for id <- unavailable_ids do
      assert conn |> get("/organizations/#{id}/edit") |> response(404)
    end
  end

  test "update returns 404 without changing an organization for a member", %{
    conn: conn,
    user: user
  } do
    organization = organization_for_member(user, :member)

    update_conn =
      put(conn, ~p"/organizations/#{organization}", %{
        organization: %{name: "Alteração indevida"}
      })

    assert response(update_conn, 404)
    assert {:ok, unchanged} = Organizations.get_organization_for_user(user, organization.id)
    assert unchanged.name == organization.name
  end

  test "organization routes require authentication" do
    assert build_conn()
           |> get(~p"/organizations/new")
           |> redirected_to() == ~p"/users/log-in"
  end

  defp assert_element(document, selector) do
    refute document |> LazyHTML.query(selector) |> LazyHTML.to_html() == ""
  end

  defp refute_element(document, selector),
    do: assert(document |> LazyHTML.query(selector) |> LazyHTML.to_html() == "")

  defp organization_for_member(user, role) do
    owner_user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Organizations.create_organization(owner_user, %{
        name: "Organização #{role} #{System.unique_integer([:positive])}"
      })

    {:ok, %{invitation: invitation}} =
      Organizations.invite_member(owner, organization, %{email: user.email, role: role})

    token =
      Phoenix.Token.sign(
        PlataformaWeb.Endpoint,
        Application.fetch_env!(:plataforma, :invitation_token_salt),
        invitation.id
      )

    assert {:ok, %Membership{role: ^role}} = Organizations.accept_invitation(user, token)
    organization
  end
end
