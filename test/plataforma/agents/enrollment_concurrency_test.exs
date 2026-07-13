defmodule Plataforma.Agents.EnrollmentConcurrencyTest do
  use Plataforma.DataCase

  import Plataforma.AccountsFixtures

  alias Plataforma.Agents
  alias Plataforma.Agents.Agent
  alias Plataforma.Agents.EnrollmentToken
  alias Plataforma.Agents.Secret
  alias Plataforma.Organizations

  test "concurrent tokens for a new machine produce one winner and one conflict" do
    user = user_fixture()

    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{name: "Acme"})

    {:ok, %{plaintext: first_token}} = Agents.create_enrollment_token(organization)
    {:ok, %{plaintext: second_token}} = Agents.create_enrollment_token(organization)

    attrs = %{
      machine_id: "concurrent-machine",
      hostname: "PC-CONCURRENT",
      platform: "windows",
      architecture: "amd64",
      agent_version: "0.1.0"
    }

    tasks = start_enrollments_together([first_token, second_token], attrs)
    results = Enum.map(tasks, &Task.await(&1, 5_000))

    assert [{:error, :enrollment_conflict}, {:ok, %{agent: agent, credential: credential}}] =
             Enum.sort_by(results, &result_order/1)

    assert Repo.aggregate(Agent, :count) == 1
    [_agent_id, secret] = String.split(credential, ".", parts: 2)
    assert Secret.verify?(secret, Repo.get!(Agent, agent.id).credential_digest)
  end

  test "concurrent re-enrollments rotate once and consume the stale token" do
    user = user_fixture()

    {:ok, %{organization: organization}} =
      Organizations.create_organization(user, %{name: "Acme"})

    {:ok, %{plaintext: initial_token}} = Agents.create_enrollment_token(organization)

    attrs = %{
      machine_id: "reenrollment-machine",
      hostname: "PC-CONCURRENT",
      platform: "windows",
      architecture: "amd64",
      agent_version: "0.1.0"
    }

    {:ok, %{agent: original}} = Agents.enroll_agent(initial_token, attrs)

    {:ok, %{token: first_record, plaintext: first_token}} =
      Agents.create_enrollment_token(organization)

    {:ok, %{token: second_record, plaintext: second_token}} =
      Agents.create_enrollment_token(organization)

    tasks = start_enrollments_together([first_token, second_token], attrs)
    results = Enum.map(tasks, &Task.await(&1, 5_000))

    assert [{:error, :enrollment_conflict}, {:ok, %{agent: winner, credential: credential}}] =
             Enum.sort_by(results, &result_order/1)

    persisted = Repo.get!(Agent, original.id)
    assert winner.id == original.id
    [_agent_id, secret] = String.split(credential, ".", parts: 2)
    assert Secret.verify?(secret, persisted.credential_digest)
    assert Repo.get!(EnrollmentToken, first_record.id).consumed_at
    assert Repo.get!(EnrollmentToken, second_record.id).consumed_at
  end

  defp start_enrollments_together(tokens, attrs) do
    parent = self()

    tasks =
      Enum.map(tokens, fn token ->
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :enroll -> Agents.enroll_agent(token, attrs)
          end
        end)
      end)

    pids =
      Enum.map(tasks, fn _task ->
        assert_receive {:ready, pid}
        pid
      end)

    Enum.each(pids, &send(&1, :enroll))
    tasks
  end

  defp result_order({:error, :enrollment_conflict}), do: 0
  defp result_order({:ok, _result}), do: 1
  defp result_order(_other), do: 2
end
