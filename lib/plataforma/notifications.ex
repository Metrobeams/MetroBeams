defmodule Plataforma.Notifications do
  @moduledoc """
  Context for managing user notifications.
  """

  import Ecto.Query

  alias Plataforma.Accounts.User
  alias Plataforma.Notifications.Notification
  alias Plataforma.Organizations.{Invitation, Organization}
  alias Plataforma.Repo

  @default_summary_limit 10
  @page_size 20

  def create_notification(%User{id: user_id}, attrs) do
    insert_notification(Repo, user_id, attrs)
  end

  def notify_organization_invitation(
        repo,
        %User{id: user_id},
        %Invitation{} = invitation,
        %Organization{} = organization
      ) do
    insert_notification(repo, user_id, %{
      kind: :organization_invitation,
      title: "Convite para #{organization.name}",
      body: "Você foi convidado para participar como #{invitation.role}.",
      action_path: "/notifications",
      dedupe_key: "organization_invitation:#{invitation.id}",
      metadata: %{
        "invitation_id" => invitation.id,
        "organization_id" => organization.id,
        "role" => Atom.to_string(invitation.role)
      }
    })
  end

  defp insert_notification(repo, user_id, attrs) do
    changeset =
      %Notification{user_id: user_id}
      |> Notification.changeset(attrs)

    case repo.insert(changeset) do
      {:ok, notification} ->
        {:ok, notification}

      {:error, changeset} ->
        find_duplicate_or_error(repo, user_id, attrs, changeset)
    end
  end

  def summary(%User{id: user_id}, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_summary_limit)
    query = scoped_query(user_id)

    %{
      unread_count:
        Repo.aggregate(where(query, [notification], is_nil(notification.read_at)), :count),
      notifications:
        query
        |> order_by([notification], desc: notification.inserted_at, desc: notification.id)
        |> limit(^limit)
        |> Repo.all()
    }
  end

  def list_notifications(%User{id: user_id}, params \\ %{}) do
    notifications =
      user_id
      |> scoped_query()
      |> before_cursor(params)
      |> order_by([notification], desc: notification.inserted_at, desc: notification.id)
      |> limit(^@page_size)
      |> Repo.all()

    %{
      notifications: notifications,
      next_before: next_cursor(notifications)
    }
  end

  def mark_as_read(%User{id: user_id}, notification_id) do
    case Repo.one(
           where(scoped_query(user_id), [notification], notification.id == ^notification_id)
         ) do
      nil ->
        {:error, :not_found}

      %Notification{read_at: %DateTime{}} = notification ->
        {:ok, notification}

      %Notification{} = notification ->
        notification
        |> Ecto.Changeset.change(read_at: DateTime.utc_now(:microsecond))
        |> Repo.update()
    end
  end

  def mark_all_as_read(%User{id: user_id}) do
    {count, _notifications} =
      user_id
      |> scoped_query()
      |> where([notification], is_nil(notification.read_at))
      |> Repo.update_all(set: [read_at: DateTime.utc_now(:microsecond)])

    {:ok, count}
  end

  defp scoped_query(user_id) do
    from notification in Notification, where: notification.user_id == ^user_id
  end

  defp find_duplicate_or_error(repo, user_id, attrs, changeset) do
    with dedupe_key when is_binary(dedupe_key) <- Map.get(attrs, :dedupe_key),
         %Notification{} = notification <-
           repo.get_by(Notification, user_id: user_id, dedupe_key: dedupe_key) do
      {:ok, notification}
    else
      _reason -> {:error, changeset}
    end
  end

  defp before_cursor(query, %{"before" => value}) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        where(query, [notification], notification.inserted_at < ^datetime)

      {:error, _reason} ->
        query
    end
  end

  defp before_cursor(query, _params), do: query

  defp next_cursor(notifications) when length(notifications) == @page_size do
    notifications |> List.last() |> Map.fetch!(:inserted_at) |> DateTime.to_iso8601()
  end

  defp next_cursor(_notifications), do: nil
end
