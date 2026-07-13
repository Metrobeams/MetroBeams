defmodule Plataforma.Notifications.Notification do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "notifications" do
    field :kind, Ecto.Enum, values: [:organization_invitation]
    field :status, Ecto.Enum, values: [:info, :success, :warning, :error], default: :info
    field :title, :string
    field :body, :string
    field :action_path, :string
    field :metadata, :map, default: %{}
    field :read_at, :utc_datetime_usec
    field :dedupe_key, :string

    belongs_to :user, Plataforma.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:kind, :status, :title, :body, :action_path, :metadata, :dedupe_key])
    |> validate_required([:user_id, :kind, :title, :body, :dedupe_key])
    |> validate_length(:title, max: 160)
    |> validate_length(:body, max: 1_000)
    |> validate_length(:action_path, max: 2_048)
    |> validate_internal_action_path()
    |> assoc_constraint(:user)
    |> unique_constraint([:user_id, :dedupe_key])
  end

  defp validate_internal_action_path(changeset) do
    validate_change(changeset, :action_path, fn :action_path, path ->
      if String.starts_with?(path, "/") and not String.starts_with?(path, "//") do
        []
      else
        [action_path: "must be an internal path"]
      end
    end)
  end
end
