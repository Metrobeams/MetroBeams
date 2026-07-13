defmodule Plataforma.Agents.Agent do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @platforms ~w(windows linux darwin)
  @architectures ~w(amd64 arm64 386)
  @version_format ~r/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/

  @type t :: %__MODULE__{}

  schema "agents" do
    field :machine_id, :string
    field :hostname, :string
    field :platform, :string
    field :architecture, :string
    field :agent_version, :string
    field :credential_digest, :binary, redact: true
    field :active, :boolean, default: true
    field :enrolled_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec

    belongs_to :organization, Plataforma.Organizations.Organization

    timestamps(type: :utc_datetime_usec)
  end

  @spec enrollment_changeset(t(), map()) :: Ecto.Changeset.t()
  def enrollment_changeset(agent, attrs) do
    agent
    |> cast(attrs, [:machine_id, :hostname, :platform, :architecture, :agent_version])
    |> trim_fields([:machine_id, :hostname, :agent_version])
    |> validate_required([:machine_id, :hostname, :platform, :architecture, :agent_version])
    |> validate_length(:machine_id, max: 255)
    |> validate_length(:hostname, max: 255)
    |> validate_length(:agent_version, max: 64)
    |> validate_inclusion(:platform, @platforms)
    |> validate_inclusion(:architecture, @architectures)
    |> validate_format(:agent_version, @version_format)
    |> unique_constraint([:organization_id, :machine_id],
      name: :agents_organization_machine_id_unique_index
    )
  end

  defp trim_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      update_change(acc, field, &String.trim/1)
    end)
  end
end
