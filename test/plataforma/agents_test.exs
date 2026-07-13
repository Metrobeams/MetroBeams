defmodule Plataforma.AgentsTest do
  use Plataforma.DataCase

  import Plataforma.AccountsFixtures

  alias Plataforma.Agents
  alias Plataforma.Agents.Agent
  alias Plataforma.Agents.EnrollmentToken
  alias Plataforma.Agents.Secret
  alias Plataforma.Organizations

  setup do
    user = user_fixture()

    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{
        name: "Agent Org #{System.unique_integer([:positive])}"
      })

    %{organization: organization}
  end

  @tag :token_creation
  test "create_enrollment_token/1 returns plaintext once and stores only its digest", %{
    organization: organization
  } do
    before_creation = DateTime.utc_now()

    assert {:ok, %{token: %EnrollmentToken{} = token, plaintext: plaintext}} =
             Agents.create_enrollment_token(organization)

    assert token.organization_id == organization.id
    assert Secret.verify?(plaintext, token.token_digest)
    refute inspect(token) =~ plaintext
    assert DateTime.diff(token.expires_at, before_creation, :second) in 899..901
  end

  @tag :token_creation
  test "create_enrollment_token/2 rejects invalid lifetimes", %{organization: organization} do
    assert {:error, :invalid_ttl} = Agents.create_enrollment_token(organization, ttl: 0)
    assert {:error, :invalid_ttl} = Agents.create_enrollment_token(organization, ttl: :infinity)
    assert Repo.aggregate(EnrollmentToken, :count) == 0
  end

  @tag :enrollment
  test "enroll_agent/2 atomically creates a tenant-scoped agent and consumes the token", %{
    organization: organization
  } do
    {:ok, %{token: token, plaintext: enrollment_token}} =
      Agents.create_enrollment_token(organization)

    attrs =
      valid_agent_attrs(%{
        organization_id: Ecto.UUID.generate(),
        credential_digest: <<1::256>>,
        active: false
      })

    assert {:ok, %{agent: %Agent{} = agent, credential: credential}} =
             Agents.enroll_agent(enrollment_token, attrs)

    assert agent.organization_id == organization.id
    assert agent.machine_id == attrs.machine_id
    assert agent.active
    assert agent.enrolled_at
    assert credential =~ "#{agent.id}."
    [credential_agent_id, secret] = String.split(credential, ".", parts: 2)
    assert credential_agent_id == agent.id
    assert Secret.verify?(secret, agent.credential_digest)
    assert Repo.get!(EnrollmentToken, token.id).consumed_at
  end

  @tag :enrollment_validation
  test "enroll_agent/2 rolls back token consumption for invalid device data", %{
    organization: organization
  } do
    {:ok, %{token: token, plaintext: enrollment_token}} =
      Agents.create_enrollment_token(organization)

    assert {:error, %Ecto.Changeset{}} =
             Agents.enroll_agent(enrollment_token, valid_agent_attrs(%{hostname: ""}))

    refute Repo.get!(EnrollmentToken, token.id).consumed_at
    assert Repo.aggregate(Agent, :count) == 0
  end

  @tag :invalid_token
  test "enroll_agent/2 makes unknown, expired, and consumed tokens indistinguishable", %{
    organization: organization
  } do
    assert {:error, :invalid_enrollment_token} =
             Agents.enroll_agent("unknown-token", valid_agent_attrs(%{}))

    {:ok, %{token: expired, plaintext: expired_plaintext}} =
      Agents.create_enrollment_token(organization)

    expired
    |> change(expires_at: DateTime.add(DateTime.utc_now(), -1, :second))
    |> Repo.update!()

    assert {:error, :invalid_enrollment_token} =
             Agents.enroll_agent(expired_plaintext, valid_agent_attrs(%{}))

    {:ok, %{token: consumed, plaintext: consumed_plaintext}} =
      Agents.create_enrollment_token(organization)

    consumed
    |> change(consumed_at: DateTime.utc_now())
    |> Repo.update!()

    assert {:error, :invalid_enrollment_token} =
             Agents.enroll_agent(consumed_plaintext, valid_agent_attrs(%{}))

    assert Repo.aggregate(Agent, :count) == 0
  end

  @tag :reenrollment
  test "enroll_agent/2 rotates credentials for an existing active machine", %{
    organization: organization
  } do
    {:ok, %{plaintext: first_token}} = Agents.create_enrollment_token(organization)
    attrs = valid_agent_attrs(%{})
    {:ok, %{agent: original}} = Agents.enroll_agent(first_token, attrs)

    {:ok, %{plaintext: second_token}} = Agents.create_enrollment_token(organization)

    assert {:ok, %{agent: reenrolled, credential: credential}} =
             Agents.enroll_agent(
               second_token,
               Map.merge(attrs, %{hostname: "PC-FINANCE-RENAMED", agent_version: "0.2.0"})
             )

    assert reenrolled.id == original.id
    assert reenrolled.inserted_at == original.inserted_at
    assert reenrolled.hostname == "PC-FINANCE-RENAMED"
    assert reenrolled.agent_version == "0.2.0"
    assert reenrolled.credential_digest != original.credential_digest
    assert DateTime.after?(reenrolled.enrolled_at, original.enrolled_at)
    [_agent_id, secret] = String.split(credential, ".", parts: 2)
    assert Secret.verify?(secret, reenrolled.credential_digest)
    assert Repo.aggregate(Agent, :count) == 1
  end

  @tag :inactive_agent
  test "enroll_agent/2 rejects an inactive machine without changing it", %{
    organization: organization
  } do
    {:ok, %{plaintext: first_token}} = Agents.create_enrollment_token(organization)
    attrs = valid_agent_attrs(%{})
    {:ok, %{agent: original}} = Agents.enroll_agent(first_token, attrs)
    inactive = original |> change(active: false) |> Repo.update!()

    {:ok, %{plaintext: second_token}} = Agents.create_enrollment_token(organization)

    assert {:error, :agent_inactive} = Agents.enroll_agent(second_token, attrs)

    persisted = Repo.get!(Agent, original.id)
    refute persisted.active
    assert persisted.credential_digest == inactive.credential_digest
    assert persisted.enrolled_at == inactive.enrolled_at
  end

  defp valid_agent_attrs(overrides) do
    Map.merge(
      %{
        machine_id: "machine-#{System.unique_integer([:positive])}",
        hostname: "PC-FINANCE-01",
        platform: "windows",
        architecture: "amd64",
        agent_version: "0.1.0"
      },
      overrides
    )
  end
end
