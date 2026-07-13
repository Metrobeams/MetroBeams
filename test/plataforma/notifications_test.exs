defmodule Plataforma.NotificationsTest do
  use Plataforma.DataCase, async: true

  import Plataforma.AccountsFixtures

  alias Plataforma.Notifications
  alias Plataforma.Notifications.Notification
  alias Plataforma.Accounts.User

  describe "create_notification/2 and summary/2" do
    test "creates a user-scoped unread notification with an internal action" do
      user = user_fixture()
      dedupe_key = "test:#{Ecto.UUID.generate()}"

      assert {:ok, notification} =
               Notifications.create_notification(user, %{
                 kind: :organization_invitation,
                 title: "Novo convite",
                 body: "Você recebeu um convite.",
                 action_path: "/invitations/accept/token",
                 dedupe_key: dedupe_key
               })

      assert notification.user_id == user.id
      assert notification.dedupe_key == dedupe_key
      refute notification.read_at

      summary = Notifications.summary(user)
      assert summary.unread_count == 1
      assert Enum.any?(summary.notifications, &(&1.id == notification.id))
    end

    test "rejects external and protocol-relative action paths" do
      user = user_fixture()

      for action_path <- ["https://malicious.example/path", "//malicious.example/path"] do
        assert {:error, changeset} =
                 Notifications.create_notification(user, %{
                   kind: :organization_invitation,
                   title: "Convite",
                   body: "Conteúdo",
                   action_path: action_path,
                   dedupe_key: "test:#{Ecto.UUID.generate()}"
                 })

        assert %{action_path: [_reason]} = errors_on(changeset)
      end
    end

    test "returns a changeset error when the owner does not exist" do
      missing_user = %User{id: -System.unique_integer([:positive])}

      assert {:error, changeset} =
               Notifications.create_notification(missing_user, valid_attrs())

      refute changeset.valid?
      assert %{user: [_reason]} = errors_on(changeset)
    end

    test "does not duplicate the same event for a user" do
      user = user_fixture()
      attrs = valid_attrs()

      assert {:ok, first} = Notifications.create_notification(user, attrs)
      assert {:ok, duplicate} = Notifications.create_notification(user, attrs)
      assert duplicate.id == first.id
      assert Notifications.summary(user).unread_count == 1
    end

    test "limits the dropdown summary without changing the unread total" do
      user = user_fixture()
      limit = 3

      notifications =
        for _index <- 1..(limit + 2) do
          {:ok, notification} = Notifications.create_notification(user, valid_attrs())
          notification
        end

      summary = Notifications.summary(user, limit: limit)

      assert summary.unread_count == length(notifications)
      assert length(summary.notifications) == limit
    end
  end

  describe "reading notifications" do
    test "marks only a notification owned by the user as read" do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, notification} = Notifications.create_notification(user, valid_attrs())

      assert {:error, :not_found} = Notifications.mark_as_read(other_user, notification.id)
      assert {:ok, read_notification} = Notifications.mark_as_read(user, notification.id)
      assert %DateTime{} = read_notification.read_at
      assert Notifications.summary(user).unread_count == 0
    end

    test "marking an already read notification is idempotent" do
      user = user_fixture()
      {:ok, notification} = Notifications.create_notification(user, valid_attrs())

      assert {:ok, first_read} = Notifications.mark_as_read(user, notification.id)
      assert {:ok, second_read} = Notifications.mark_as_read(user, notification.id)
      assert second_read.read_at == first_read.read_at
    end

    test "marks all notifications for one user without affecting another" do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, _first} = Notifications.create_notification(user, valid_attrs())
      {:ok, _second} = Notifications.create_notification(user, valid_attrs())
      {:ok, _other} = Notifications.create_notification(other_user, valid_attrs())

      assert {:ok, count} = Notifications.mark_all_as_read(user)
      assert count == 2
      assert Notifications.summary(user).unread_count == 0
      assert Notifications.summary(other_user).unread_count == 1
    end
  end

  describe "list_notifications/2" do
    test "returns only the authenticated user's notifications" do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, owned} = Notifications.create_notification(user, valid_attrs())
      {:ok, foreign} = Notifications.create_notification(other_user, valid_attrs())

      page = Notifications.list_notifications(user)

      assert Enum.any?(page.notifications, &(&1.id == owned.id))
      refute Enum.any?(page.notifications, &(&1.id == foreign.id))
    end
  end

  describe "notification status field" do
    test "notification has status field with default :info" do
      notification = %Notification{}
      assert Ecto.Changeset.get_field(notification |> Ecto.Changeset.change(), :status) == :info
    end

    test "notification accepts all valid statuses" do
      for status <- [:info, :success, :warning, :error] do
        changeset =
          Notification.changeset(%Notification{user_id: "test"}, %{
            status: status,
            title: "Test",
            body: "Body",
            kind: :organization_invitation,
            dedupe_key: "test-#{status}"
          })

        assert changeset.valid?
      end
    end
  end

  defp valid_attrs do
    %{
      kind: :organization_invitation,
      title: "Convite para organização",
      body: "Você foi convidado para participar.",
      action_path: "/invitations/accept/#{Ecto.UUID.generate()}",
      dedupe_key: "test:#{Ecto.UUID.generate()}"
    }
  end
end
