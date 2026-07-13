defmodule Plataforma.Agents.AgentTest do
  use Plataforma.DataCase, async: true

  alias Plataforma.Agents.Agent

  @valid_attrs %{
    machine_id: " machine-123 ",
    hostname: " PC-FINANCE-01 ",
    platform: "windows",
    architecture: "amd64",
    agent_version: "0.1.0"
  }

  test "enrollment_changeset/2 validates and normalizes public device attributes" do
    agent = protected_agent()
    changeset = Agent.enrollment_changeset(agent, @valid_attrs)

    assert changeset.valid?
    assert get_change(changeset, :machine_id) == "machine-123"
    assert get_change(changeset, :hostname) == "PC-FINANCE-01"
  end

  test "enrollment_changeset/2 rejects unsupported values and malformed versions" do
    changeset =
      Agent.enrollment_changeset(protected_agent(), %{
        @valid_attrs
        | platform: "plan9",
          architecture: "mips",
          agent_version: "latest"
      })

    refute changeset.valid?
    assert "is invalid" in errors_on(changeset).platform
    assert "is invalid" in errors_on(changeset).architecture
    assert "has invalid format" in errors_on(changeset).agent_version
  end

  test "enrollment_changeset/2 ignores protected client fields" do
    agent = protected_agent()

    changeset =
      Agent.enrollment_changeset(
        agent,
        Map.merge(@valid_attrs, %{
          organization_id: Ecto.UUID.generate(),
          credential_digest: <<1::256>>,
          active: false,
          enrolled_at: DateTime.add(agent.enrolled_at, 60, :second)
        })
      )

    refute get_change(changeset, :organization_id)
    refute get_change(changeset, :credential_digest)
    refute get_change(changeset, :active)
    refute get_change(changeset, :enrolled_at)
  end

  test "credential digest is redacted when inspected" do
    inspected = inspect(%Agent{credential_digest: <<0::256>>})

    refute inspected =~ "<<0"
    refute inspected =~ "credential_digest"
    assert inspected =~ "..."
  end

  defp protected_agent do
    %Agent{
      organization_id: Ecto.UUID.generate(),
      credential_digest: <<0::256>>,
      enrolled_at: DateTime.utc_now(),
      active: true
    }
  end
end
