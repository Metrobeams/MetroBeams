defmodule PlataformaWeb.ManufacturerControllerTest do
  use PlataformaWeb.ConnCase, async: true

  import Plataforma.AccountsFixtures

  alias Plataforma.Assets
  alias Plataforma.Organizations

  setup :register_and_log_in_user

  setup %{user: user} do
    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{name: "Org #{System.unique_integer([:positive])}"})

    %{organization: organization}
  end

  describe "index" do
    test "lists all manufacturers", %{conn: conn, organization: organization} do
      {:ok, _manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      conn = get(conn, ~p"/manufacturers")
      assert html_response(conn, 200) =~ "Dell"
    end

    test "does not list manufacturers from other organizations", %{
      conn: conn,
      organization: organization
    } do
      {:ok, _} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      other_user = user_fixture()

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(other_user, %{name: "Other Org"})

      {:ok, _} = Assets.create_manufacturer(other_org.id, %{name: "Lenovo"})

      conn = get(conn, ~p"/manufacturers")
      response = html_response(conn, 200)
      assert response =~ "Dell"
      refute response =~ "Lenovo"
    end

    test "does not list inactive manufacturers", %{conn: conn, organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})
      {:ok, _} = Assets.deactivate_manufacturer(organization.id, manufacturer)

      conn = get(conn, ~p"/manufacturers")
      refute html_response(conn, 200) =~ "Dell"
    end

    test "shows empty state when no manufacturers", %{conn: conn} do
      conn = get(conn, ~p"/manufacturers")
      response = html_response(conn, 200)
      assert response =~ "Nenhum fabricante cadastrado"
      assert response =~ "Criar primeiro fabricante"
    end
  end

  describe "show" do
    test "renders manufacturer", %{conn: conn, organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      conn = get(conn, ~p"/manufacturers/#{manufacturer}")
      assert html_response(conn, 200) =~ "Dell"
    end

    test "returns 404 for manufacturer from another organization", %{conn: conn} do
      other_user = user_fixture()

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(other_user, %{name: "Other Org"})

      {:ok, other_manufacturer} = Assets.create_manufacturer(other_org.id, %{name: "Lenovo"})

      assert_raise Ecto.NoResultsError, fn ->
        get(conn, ~p"/manufacturers/#{other_manufacturer}")
      end
    end

    test "returns 404 for invalid UUID", %{conn: conn} do
      assert_raise Ecto.Query.CastError, fn ->
        get(conn, ~p"/manufacturers/invalid-uuid")
      end
    end

    test "returns 404 for inactive manufacturer", %{conn: conn, organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})
      {:ok, _} = Assets.deactivate_manufacturer(organization.id, manufacturer)

      assert_raise Ecto.NoResultsError, fn ->
        get(conn, ~p"/manufacturers/#{manufacturer}")
      end
    end
  end

  describe "new manufacturer" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/manufacturers/new")
      assert html_response(conn, 200) =~ "Novo Fabricante"
    end
  end

  describe "create manufacturer" do
    test "redirects to index when data is valid", %{conn: conn} do
      conn =
        post(conn, ~p"/manufacturers", %{
          manufacturer: %{name: "Dell", website: "https://dell.com"}
        })

      assert redirected_to(conn) == ~p"/manufacturers"

      conn = get(conn, ~p"/manufacturers")
      assert html_response(conn, 200) =~ "Dell"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/manufacturers", %{
          manufacturer: %{name: nil}
        })

      assert html_response(conn, 422) =~ "erro"
    end

    test "ignores organization_id from client", %{conn: conn} do
      other_org_id = Ecto.UUID.generate()

      conn =
        post(conn, ~p"/manufacturers", %{
          manufacturer: %{name: "Dell", organization_id: other_org_id}
        })

      assert redirected_to(conn) == ~p"/manufacturers"
    end

    test "ignores active field from client", %{conn: conn} do
      conn =
        post(conn, ~p"/manufacturers", %{
          manufacturer: %{name: "Dell", active: false}
        })

      assert redirected_to(conn) == ~p"/manufacturers"
    end

    test "shows error for duplicate name", %{conn: conn, organization: organization} do
      {:ok, _} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      conn =
        post(conn, ~p"/manufacturers", %{
          manufacturer: %{name: "Dell"}
        })

      assert html_response(conn, 422) =~ "já existe"
    end

    test "shows error for invalid URL", %{conn: conn} do
      conn =
        post(conn, ~p"/manufacturers", %{
          manufacturer: %{name: "Dell", website: "not-a-url"}
        })

      assert html_response(conn, 422) =~ "deve ser uma URL válida"
    end
  end

  describe "edit manufacturer" do
    test "renders form for editing", %{conn: conn, organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      conn = get(conn, ~p"/manufacturers/#{manufacturer}/edit")
      assert html_response(conn, 200) =~ "Editar Fabricante"
    end
  end

  describe "update manufacturer" do
    test "redirects to index when data is valid", %{conn: conn, organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      conn =
        put(conn, ~p"/manufacturers/#{manufacturer}", %{
          manufacturer: %{name: "Dell Inc."}
        })

      assert redirected_to(conn) == ~p"/manufacturers"

      conn = get(conn, ~p"/manufacturers")
      assert html_response(conn, 200) =~ "Dell Inc."
    end

    test "renders errors when data is invalid", %{conn: conn, organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      conn =
        put(conn, ~p"/manufacturers/#{manufacturer}", %{
          manufacturer: %{name: nil}
        })

      assert html_response(conn, 422) =~ "erro"
    end

    test "does not change organization", %{conn: conn, organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      conn =
        put(conn, ~p"/manufacturers/#{manufacturer}", %{
          manufacturer: %{name: "Dell Inc."}
        })

      assert redirected_to(conn) == ~p"/manufacturers"
    end

    test "does not change active status", %{conn: conn, organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      conn =
        put(conn, ~p"/manufacturers/#{manufacturer}", %{
          manufacturer: %{name: "Dell Inc.", active: false}
        })

      assert redirected_to(conn) == ~p"/manufacturers"
    end

    test "returns 404 for manufacturer from another organization", %{conn: conn} do
      other_user = user_fixture()

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(other_user, %{name: "Other Org"})

      {:ok, other_manufacturer} = Assets.create_manufacturer(other_org.id, %{name: "Lenovo"})

      assert_raise Ecto.NoResultsError, fn ->
        put(conn, ~p"/manufacturers/#{other_manufacturer}", %{
          manufacturer: %{name: "Hacked"}
        })
      end
    end
  end

  describe "delete manufacturer" do
    test "deactivates the manufacturer", %{conn: conn, organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      conn = delete(conn, ~p"/manufacturers/#{manufacturer}")
      assert redirected_to(conn) == ~p"/manufacturers"

      assert_raise Ecto.NoResultsError, fn ->
        Assets.get_manufacturer!(organization.id, manufacturer.id)
      end
    end

    test "preserves record in database", %{conn: conn, organization: organization} do
      {:ok, manufacturer} = Assets.create_manufacturer(organization.id, %{name: "Dell"})

      conn = delete(conn, ~p"/manufacturers/#{manufacturer}")
      assert redirected_to(conn) == ~p"/manufacturers"

      # Record still exists but is inactive
      import Ecto.Query

      db_manufacturer =
        from(m in Plataforma.Assets.Manufacturer, where: m.id == ^manufacturer.id)
        |> Plataforma.Repo.one!()

      assert db_manufacturer.active == false
    end

    test "returns 404 for manufacturer from another organization", %{conn: conn} do
      other_user = user_fixture()

      {:ok, %{organization: other_org}} =
        Organizations.create_organization(other_user, %{name: "Other Org"})

      {:ok, other_manufacturer} = Assets.create_manufacturer(other_org.id, %{name: "Lenovo"})

      assert_raise Ecto.NoResultsError, fn ->
        delete(conn, ~p"/manufacturers/#{other_manufacturer}")
      end
    end

    test "returns 404 for invalid UUID", %{conn: conn} do
      assert_raise Ecto.Query.CastError, fn ->
        delete(conn, ~p"/manufacturers/invalid-uuid")
      end
    end
  end

  describe "authorization" do
    test "member role is redirected", %{organization: organization} do
      member_user = user_fixture()

      {:ok, _membership} =
        Plataforma.Repo.insert(%Plataforma.Organizations.Membership{
          organization_id: organization.id,
          user_id: member_user.id,
          role: :member,
          active: true
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(
          user_token: Plataforma.Accounts.generate_user_session_token(member_user)
        )

      conn = get(conn, ~p"/manufacturers")
      assert html_response(conn, 302)
      assert redirected_to(conn) == ~p"/"
    end

    test "inactive membership is redirected", %{organization: organization} do
      member_user = user_fixture()

      {:ok, membership} =
        Plataforma.Repo.insert(%Plataforma.Organizations.Membership{
          organization_id: organization.id,
          user_id: member_user.id,
          role: :technician,
          active: true
        })

      # Deactivate membership
      membership
      |> Ecto.Changeset.change(active: false)
      |> Plataforma.Repo.update()

      conn =
        build_conn()
        |> Plug.Test.init_test_session(
          user_token: Plataforma.Accounts.generate_user_session_token(member_user)
        )

      conn = get(conn, ~p"/manufacturers")
      assert html_response(conn, 302)
      assert redirected_to(conn) == ~p"/"
    end

    test "external user without membership is redirected" do
      external_user = user_fixture()

      conn =
        build_conn()
        |> Plug.Test.init_test_session(
          user_token: Plataforma.Accounts.generate_user_session_token(external_user)
        )

      conn = get(conn, ~p"/manufacturers")
      assert html_response(conn, 302)
      assert redirected_to(conn) == ~p"/"
    end

    test "technician role can access", %{organization: organization} do
      technician_user = user_fixture()

      {:ok, _membership} =
        Plataforma.Repo.insert(%Plataforma.Organizations.Membership{
          organization_id: organization.id,
          user_id: technician_user.id,
          role: :technician,
          active: true
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(
          user_token: Plataforma.Accounts.generate_user_session_token(technician_user)
        )

      conn = get(conn, ~p"/manufacturers")
      assert html_response(conn, 200)
    end

    test "admin role can access", %{organization: organization} do
      admin_user = user_fixture()

      {:ok, _membership} =
        Plataforma.Repo.insert(%Plataforma.Organizations.Membership{
          organization_id: organization.id,
          user_id: admin_user.id,
          role: :admin,
          active: true
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(
          user_token: Plataforma.Accounts.generate_user_session_token(admin_user)
        )

      conn = get(conn, ~p"/manufacturers")
      assert html_response(conn, 200)
    end

    test "owner role can access", %{conn: conn} do
      conn = get(conn, ~p"/manufacturers")
      assert html_response(conn, 200)
    end
  end
end
