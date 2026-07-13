defmodule PlataformaWeb.PageControllerTest do
  use PlataformaWeb.ConnCase

  import Plataforma.AccountsFixtures

  test "GET / redirects visitors to login", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/users/log-in"
    assert get_session(conn, :user_return_to) == ~p"/"
  end

  test "GET / renders the authenticated user home", %{conn: conn} do
    name = unique_user_name()
    user = user_fixture(%{name: name})

    document =
      conn
      |> log_in_user(user)
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert_element(document, "#user-home[data-design-system='carbon']")

    assert_element(
      document,
      "#user-home-welcome[aria-labelledby='user-home-title'] #user-home-title"
    )

    assert_element(document, "#user-home-organizations")
    assert_element(document, "#user-home-empty")
    refute_element(document, "#welcome-register")
    refute_element(document, "#welcome-login")

    topbar_user = LazyHTML.query(document, "#header-user-menu-toggle [data-user-display-name]")
    assert LazyHTML.text(topbar_user) =~ name
    refute LazyHTML.text(topbar_user) =~ user.email
  end

  test "GET / lists only organizations accessible to the signed-in user", %{conn: conn} do
    user = user_fixture()
    other_user = user_fixture()

    {:ok, %{organization: organization}} =
      Plataforma.Organizations.create_organization(user, %{name: "Minha Organização"})

    {:ok, %{organization: hidden_organization}} =
      Plataforma.Organizations.create_organization(other_user, %{name: "Organização Oculta"})

    document =
      conn
      |> log_in_user(user)
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert_element(document, "#user-organization-#{organization.id}")
    refute_element(document, "#user-organization-#{hidden_organization.id}")
    refute_element(document, "#user-home-empty")
  end

  test "GET / renders organization card content without background fills", %{conn: conn} do
    user = user_fixture()

    {:ok, %{organization: organization}} =
      Plataforma.Organizations.create_organization(user, %{name: "Organização sem preenchimento"})

    document =
      conn
      |> log_in_user(user)
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()

    refute_element(document, "#user-organization-#{organization.id} [class*='bg-']")
  end

  test "GET / renders organizations as a semantic list", %{conn: conn} do
    user = user_fixture()

    {:ok, %{organization: organization}} =
      Plataforma.Organizations.create_organization(user, %{name: "Organização em grid"})

    document =
      conn
      |> log_in_user(user)
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert_element(
      document,
      "#user-home-organizations ul > li #user-organization-#{organization.id}"
    )
  end

  test "GET / renders the organization section with decorative Carbon icons", %{conn: conn} do
    user = user_fixture()

    {:ok, %{organization: _organization}} =
      Plataforma.Organizations.create_organization(user, %{name: "Organização com ícones"})

    document =
      conn
      |> log_in_user(user)
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert_element(document, "#user-home-organizations svg[data-carbon-icon][aria-hidden='true']")
    refute_element(document, "#user-home-organizations [class*='hero-']")
  end

  test "GET / offers organization creation and editing to an owner", %{conn: conn} do
    user = user_fixture()

    {:ok, %{organization: organization}} =
      Plataforma.Organizations.create_organization(user, %{
        name: "Organização gerenciável"
      })

    document =
      conn
      |> log_in_user(user)
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert_element(document, "#organization-create-link[href='/organizations/new']")

    assert_element(
      document,
      "#organization-edit-#{organization.id}[href='/organizations/#{organization.id}/edit']"
    )
  end

  test "GET / shows edit actions according to the current membership role", %{conn: conn} do
    user = user_fixture()
    admin_organization = organization_for_member(user, :admin)
    member_organization = organization_for_member(user, :member)
    technician_organization = organization_for_member(user, :technician)

    document =
      conn
      |> log_in_user(user)
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert_element(document, "#organization-edit-#{admin_organization.id}")
    refute_element(document, "#organization-edit-#{member_organization.id}")
    refute_element(document, "#organization-edit-#{technician_organization.id}")
  end

  test "GET / renders an accessible empty notification control", %{conn: conn} do
    user = user_fixture()

    document =
      conn
      |> log_in_user(user)
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert_element(
      document,
      "#header-notifications-toggle[aria-expanded='false'][data-notifications-toggle]"
    )

    assert_element(
      document,
      "#header-notifications-toggle[aria-controls='header-notifications-menu']"
    )

    assert_element(document, "#header-notifications-menu[data-notifications-menu]")
    assert_element(document, "#header-notifications-empty")
    refute_element(document, "#header-notifications-badge")
  end

  test "GET / renders unread count and recent notifications in the topbar", %{conn: conn} do
    user = user_fixture()

    {:ok, first} =
      Plataforma.Notifications.create_notification(user, notification_attrs())

    {:ok, second} =
      Plataforma.Notifications.create_notification(user, notification_attrs())

    document =
      conn
      |> log_in_user(user)
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert_element(document, "#header-notifications-badge[data-unread-count='2']")
    assert_element(document, "#header-notification-#{first.id}")
    assert_element(document, "#header-notification-#{second.id}")
    assert_element(document, "#header-notifications-read-all")
    assert_element(document, "#header-notifications-view-all")
  end

  defp assert_element(document, selector) do
    refute document |> LazyHTML.query(selector) |> LazyHTML.to_html() == ""
  end

  defp refute_element(document, selector),
    do: assert(document |> LazyHTML.query(selector) |> LazyHTML.to_html() == "")

  defp notification_attrs do
    %{
      kind: :organization_invitation,
      title: "Nova notificação",
      body: "Existe uma ação disponível.",
      action_path: "/notifications",
      dedupe_key: "page-test:#{Ecto.UUID.generate()}"
    }
  end

  defp organization_for_member(user, role) do
    owner_user = user_fixture()

    {:ok, %{organization: organization, owner: owner}} =
      Plataforma.Organizations.create_organization(owner_user, %{
        name: "Organização #{role} #{System.unique_integer([:positive])}"
      })

    {:ok, %{invitation: invitation}} =
      Plataforma.Organizations.invite_member(owner, organization, %{
        email: user.email,
        role: role
      })

    token =
      Phoenix.Token.sign(
        PlataformaWeb.Endpoint,
        Application.fetch_env!(:plataforma, :invitation_token_salt),
        invitation.id
      )

    assert {:ok, _membership} = Plataforma.Organizations.accept_invitation(user, token)
    organization
  end
end
