defmodule Plataforma.Organizations.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organization_invitations" do
    field :email, :string
    field :role, Ecto.Enum, values: [admin: "admin", technician: "technician", member: "member"]
    field :expires_at, :utc_datetime_usec
    field :accepted_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :organization, Plataforma.Organizations.Organization
    belongs_to :invited_by_membership, Plataforma.Organizations.Membership

    timestamps(type: :utc_datetime_usec)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :role, :expires_at, :accepted_at, :revoked_at])
    |> update_change(:email, &(String.trim(&1) |> String.downcase()))
    |> validate_required([
      :organization_id,
      :invited_by_membership_id,
      :email,
      :role,
      :expires_at
    ])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/)
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email, name: :organization_invitations_open_email_unique_index)
    |> check_constraint(:role, name: :organization_invitations_role_check)
  end
end
