defmodule Plataforma.Agents.EnrollmentToken do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "agent_enrollment_tokens" do
    field :token_digest, :binary, redact: true
    field :expires_at, :utc_datetime_usec
    field :consumed_at, :utc_datetime_usec

    belongs_to :organization, Plataforma.Organizations.Organization

    timestamps(type: :utc_datetime_usec)
  end

  @spec creation_changeset(t(), map()) :: Ecto.Changeset.t()
  def creation_changeset(token, attrs) do
    token
    |> cast(attrs, [:expires_at])
    |> validate_required([:expires_at])
  end
end
