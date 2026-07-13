defmodule PlataformaWeb.AgentEnrollmentControllerTest do
  use PlataformaWeb.ConnCase

  import Plataforma.AccountsFixtures

  alias Plataforma.Agents
  alias Plataforma.Agents.Agent
  alias Plataforma.Organizations
  alias Plataforma.Repo

  setup do
    user = user_fixture()

    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{name: "Acme"})

    {:ok, %{plaintext: enrollment_token}} = Agents.create_enrollment_token(organization)

    %{organization: organization, enrollment_token: enrollment_token}
  end

  @tag :routing
  test "POST /api/v1/agents/enroll routes to the stateless enrollment controller" do
    assert %{plug: PlataformaWeb.AgentEnrollmentController, plug_opts: :create} =
             Phoenix.Router.route_info(
               PlataformaWeb.Router,
               "POST",
               "/api/v1/agents/enroll",
               "localhost"
             )

    assert :error =
             Phoenix.Router.route_info(
               PlataformaWeb.Router,
               "PUT",
               "/api/v1/agents/enroll",
               "localhost"
             )
  end

  @tag :success
  test "returns 201 with the public agent id and one-time credential", %{
    conn: conn,
    enrollment_token: enrollment_token
  } do
    conn =
      post_json(conn, %{
        "enrollment_token" => enrollment_token,
        "machine_id" => "machine-http-1",
        "hostname" => "PC-HTTP-01",
        "platform" => "windows",
        "architecture" => "amd64",
        "agent_version" => "0.1.0",
        "organization_id" => Ecto.UUID.generate()
      })

    assert %{
             "data" => %{
               "agent_id" => agent_id,
               "credential" => credential
             }
           } = json_response(conn, 201)

    assert credential =~ "#{agent_id}."
    refute json_response(conn, 201)["data"]["credential_digest"]
    refute json_response(conn, 201)["data"]["organization_id"]
  end

  @tag :errors
  test "returns the exact generic 401 envelope for an invalid token", %{conn: conn} do
    conn = post_json(conn, valid_params("invalid"))

    assert json_response(conn, 401) == %{
             "error" => %{
               "code" => "invalid_enrollment_token",
               "message" => "Enrollment token is invalid"
             }
           }
  end

  @tag :errors
  test "returns 400 with field details for invalid device data", %{
    conn: conn,
    enrollment_token: enrollment_token
  } do
    conn = post_json(conn, valid_params(enrollment_token, %{"hostname" => ""}))

    assert %{
             "error" => %{
               "code" => "invalid_request",
               "message" => "Request validation failed",
               "details" => %{"hostname" => ["can't be blank"]}
             }
           } = json_response(conn, 400)
  end

  @tag :errors
  test "returns 400 when enrollment_token is missing", %{conn: conn} do
    conn = post_json(conn, Map.delete(valid_params("unused"), "enrollment_token"))

    assert json_response(conn, 400) == %{
             "error" => %{
               "code" => "invalid_request",
               "message" => "Request validation failed",
               "details" => %{"enrollment_token" => ["can't be blank"]}
             }
           }
  end

  @tag :errors
  test "returns the exact 409 envelope for an inactive agent", %{
    conn: conn,
    organization: organization,
    enrollment_token: enrollment_token
  } do
    params = valid_params(enrollment_token)
    {:ok, %{agent: agent}} = Agents.enroll_agent(enrollment_token, params)
    agent |> Ecto.Changeset.change(active: false) |> Repo.update!()
    {:ok, %{plaintext: new_token}} = Agents.create_enrollment_token(organization)

    conn = post_json(conn, %{params | "enrollment_token" => new_token})

    assert json_response(conn, 409) == %{
             "error" => %{
               "code" => "agent_inactive",
               "message" => "Agent is inactive"
             }
           }

    refute Repo.get!(Agent, agent.id).active
  end

  @tag :errors
  test "renders the exact enrollment conflict envelope" do
    assert PlataformaWeb.AgentEnrollmentJSON.error(%{
             code: "enrollment_conflict",
             message: "Agent enrollment conflicted with another request"
           }) == %{
             error: %{
               code: "enrollment_conflict",
               message: "Agent enrollment conflicted with another request"
             }
           }
  end

  @tag :content_type
  test "rejects non-JSON content types with the exact 415 envelope", %{
    conn: conn,
    enrollment_token: enrollment_token
  } do
    conn = post(conn, ~p"/api/v1/agents/enroll", valid_params(enrollment_token))

    assert json_response(conn, 415) == %{
             "error" => %{
               "code" => "unsupported_media_type",
               "message" => "Content-Type must be application/json"
             }
           }
  end

  @tag :conflict_http
  test "concurrent HTTP enrollments return one 201 and one exact 409", %{
    organization: organization
  } do
    {:ok, %{plaintext: first_token}} = Agents.create_enrollment_token(organization)
    {:ok, %{plaintext: second_token}} = Agents.create_enrollment_token(organization)
    params = valid_params(first_token, %{"machine_id" => "http-concurrent-machine"})

    tasks = start_http_enrollments_together([first_token, second_token], params)

    responses =
      tasks
      |> Enum.map(&Task.await(&1, 5_000))
      |> Enum.sort_by(& &1.status)

    assert [%Plug.Conn{status: 201}, %Plug.Conn{status: 409} = conflict] = responses

    assert Jason.decode!(conflict.resp_body) == %{
             "error" => %{
               "code" => "enrollment_conflict",
               "message" => "Agent enrollment conflicted with another request"
             }
           }
  end

  @tag :malformed_json
  test "malformed JSON returns the stable invalid_request envelope", %{conn: conn} do
    {_status, _headers, body} =
      assert_error_sent 400, fn ->
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/v1/agents/enroll", "{")
      end

    assert Jason.decode!(body) == %{
             "error" => %{
               "code" => "invalid_request",
               "message" => "Request body is invalid"
             }
           }
  end

  defp valid_params(enrollment_token, overrides \\ %{}) do
    Map.merge(
      %{
        "enrollment_token" => enrollment_token,
        "machine_id" => "machine-http-#{System.unique_integer([:positive])}",
        "hostname" => "PC-HTTP-01",
        "platform" => "windows",
        "architecture" => "amd64",
        "agent_version" => "0.1.0"
      },
      overrides
    )
  end

  defp post_json(conn, params) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/api/v1/agents/enroll", Jason.encode!(params))
  end

  defp start_http_enrollments_together(tokens, params) do
    parent = self()

    tasks =
      Enum.map(tokens, fn token ->
        Task.async(fn ->
          send(parent, {:http_ready, self()})

          receive do
            :post ->
              post_json(
                Phoenix.ConnTest.build_conn(),
                %{params | "enrollment_token" => token}
              )
          end
        end)
      end)

    pids =
      Enum.map(tasks, fn _task ->
        assert_receive {:http_ready, pid}
        pid
      end)

    Enum.each(pids, &send(&1, :post))
    tasks
  end
end
