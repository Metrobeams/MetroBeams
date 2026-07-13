defmodule Plataforma.Agents do
  @moduledoc """
  Agent enrollment and lifecycle management.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Plataforma.Agents.Agent
  alias Plataforma.Agents.EnrollmentToken
  alias Plataforma.Agents.Secret
  alias Plataforma.Organizations.Organization
  alias Plataforma.Repo

  @default_token_ttl 15 * 60
  @maximum_token_ttl 24 * 60 * 60

  @spec create_enrollment_token(Organization.t(), keyword()) ::
          {:ok, %{token: EnrollmentToken.t(), plaintext: String.t()}}
          | {:error, :invalid_ttl | Ecto.Changeset.t()}
  def create_enrollment_token(%Organization{} = organization, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_token_ttl)

    if valid_ttl?(ttl) do
      plaintext = Secret.generate()

      token = %EnrollmentToken{
        organization_id: organization.id,
        token_digest: Secret.digest(plaintext)
      }

      case token
           |> EnrollmentToken.creation_changeset(%{
             expires_at: DateTime.add(DateTime.utc_now(), ttl, :second)
           })
           |> Repo.insert() do
        {:ok, persisted} -> {:ok, %{token: persisted, plaintext: plaintext}}
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, :invalid_ttl}
    end
  end

  @spec enroll_agent(String.t(), map()) ::
          {:ok, %{agent: Agent.t(), credential: String.t()}}
          | {:error, :invalid_enrollment_token | :agent_inactive | Ecto.Changeset.t()}
  def enroll_agent(enrollment_token, attrs)
      when is_binary(enrollment_token) and is_map(attrs) do
    now = DateTime.utc_now()
    credential_secret = Secret.generate()

    case fetch_valid_token(Repo, enrollment_token, now, lock: false) do
      {:ok, token_snapshot} ->
        machine_id = normalized_machine_id(attrs)
        observed_version = observe_agent_version(token_snapshot.organization_id, machine_id)

        enrollment_token
        |> enrollment_transaction(
          attrs,
          machine_id,
          observed_version,
          credential_secret,
          now
        )
        |> enrollment_result(credential_secret)

      {:error, :invalid_enrollment_token} ->
        {:error, :invalid_enrollment_token}
    end
  end

  def enroll_agent(_enrollment_token, _attrs), do: {:error, :invalid_enrollment_token}

  defp enrollment_transaction(
         enrollment_token,
         attrs,
         machine_id,
         observed_version,
         credential_secret,
         now
       ) do
    Multi.new()
    |> Multi.run(:token, fn repo, _changes ->
      fetch_valid_token(repo, enrollment_token, now, lock: true)
    end)
    |> Multi.run(:machine_lock, fn repo, %{token: token} ->
      lock_machine(repo, token.organization_id, machine_id)
    end)
    |> Multi.run(:agent, fn repo, %{token: token} ->
      enroll_agent_record(
        repo,
        token,
        attrs,
        machine_id,
        observed_version,
        credential_secret,
        now
      )
    end)
    |> Multi.update(:consumed_token, fn %{token: token} ->
      Ecto.Changeset.change(token, consumed_at: now)
    end)
    |> Repo.transaction()
  end

  defp enrollment_result({:ok, %{agent: :enrollment_conflict}}, _credential_secret) do
    {:error, :enrollment_conflict}
  end

  defp enrollment_result({:ok, %{agent: %Agent{} = agent}}, credential_secret) do
    {:ok, %{agent: agent, credential: Secret.credential(agent.id, credential_secret)}}
  end

  defp enrollment_result(
         {:error, :token, :invalid_enrollment_token, _changes},
         _credential_secret
       ) do
    {:error, :invalid_enrollment_token}
  end

  defp enrollment_result({:error, :agent, :agent_inactive, _changes}, _credential_secret) do
    {:error, :agent_inactive}
  end

  defp enrollment_result(
         {:error, :agent, %Ecto.Changeset{} = changeset, _changes},
         _credential_secret
       ) do
    {:error, changeset}
  end

  defp enroll_agent_record(
         repo,
         token,
         attrs,
         machine_id,
         observed_version,
         credential_secret,
         now
       ) do
    existing =
      Agent
      |> where(
        [agent],
        agent.organization_id == ^token.organization_id and
          agent.machine_id == ^machine_id
      )
      |> lock("FOR UPDATE")
      |> repo.one()

    if current_agent_version(existing) == observed_version do
      persist_enrollment(repo, existing, token, attrs, credential_secret, now)
    else
      {:ok, :enrollment_conflict}
    end
  end

  defp persist_enrollment(repo, existing, token, attrs, credential_secret, now) do
    case existing do
      nil ->
        %Agent{
          organization_id: token.organization_id,
          credential_digest: Secret.digest(credential_secret),
          enrolled_at: now
        }
        |> Agent.enrollment_changeset(attrs)
        |> repo.insert()

      %Agent{active: false} ->
        {:error, :agent_inactive}

      %Agent{} = agent ->
        agent
        |> Agent.enrollment_changeset(attrs)
        |> Ecto.Changeset.put_change(:credential_digest, Secret.digest(credential_secret))
        |> Ecto.Changeset.put_change(:enrolled_at, now)
        |> repo.update()
    end
  end

  defp fetch_valid_token(repo, plaintext, now, opts) do
    query =
      EnrollmentToken
      |> where([token], token.token_digest == ^Secret.digest(plaintext))

    query = if Keyword.fetch!(opts, :lock), do: lock(query, "FOR UPDATE"), else: query
    token = repo.one(query)

    case token do
      %EnrollmentToken{consumed_at: nil, expires_at: expires_at} = token ->
        if DateTime.after?(expires_at, now),
          do: {:ok, token},
          else: {:error, :invalid_enrollment_token}

      _other ->
        {:error, :invalid_enrollment_token}
    end
  end

  defp observe_agent_version(organization_id, machine_id) do
    Agent
    |> where(
      [agent],
      agent.organization_id == ^organization_id and agent.machine_id == ^machine_id
    )
    |> Repo.one()
    |> current_agent_version()
  end

  defp current_agent_version(nil), do: nil

  defp current_agent_version(%Agent{} = agent) do
    {agent.id, agent.updated_at, agent.credential_digest}
  end

  defp lock_machine(repo, organization_id, machine_id) do
    case Ecto.Adapters.SQL.query(
           repo,
           "SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2))",
           [organization_id, machine_id]
         ) do
      {:ok, _result} -> {:ok, :locked}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalized_machine_id(attrs) do
    case Map.get(attrs, :machine_id, Map.get(attrs, "machine_id")) do
      machine_id when is_binary(machine_id) -> String.trim(machine_id)
      _other -> ""
    end
  end

  defp valid_ttl?(ttl), do: is_integer(ttl) and ttl > 0 and ttl <= @maximum_token_ttl
end
