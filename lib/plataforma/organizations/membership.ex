defmodule Plataforma.Organizations.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organization_memberships" do
    field :role, Ecto.Enum,
      values: [owner: "owner", admin: "admin", technician: "technician", member: "member"]

    field :active, :boolean, default: true
    field :job_title, :string
    field :department, :string
    field :employee_code, :string

    belongs_to :organization, Plataforma.Organizations.Organization
    belongs_to :user, Plataforma.Accounts.User, type: :id

    timestamps(type: :utc_datetime_usec)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :active, :job_title, :department, :employee_code])
    |> trim_optional_fields()
    |> validate_required([:organization_id, :user_id, :role, :active])
    |> validate_length(:job_title, max: 120)
    |> validate_length(:department, max: 120)
    |> validate_length(:employee_code, max: 80)
    |> unique_constraint([:organization_id, :user_id],
      name: :organization_memberships_organization_user_unique_index
    )
    |> unique_constraint([:organization_id, :employee_code],
      name: :organization_memberships_employee_code_unique_index
    )
    |> check_constraint(:role, name: :organization_memberships_role_check)
  end

  defp trim_optional_fields(changeset) do
    Enum.reduce([:job_title, :department, :employee_code], changeset, fn field, acc ->
      update_change(acc, field, &String.trim/1)
    end)
  end
end
