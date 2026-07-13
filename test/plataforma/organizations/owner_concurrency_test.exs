defmodule Plataforma.Organizations.OwnerConcurrencyTest do
  use Plataforma.DataCase

  import Plataforma.AccountsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Plataforma.Organizations
  alias Plataforma.Organizations.Membership
  alias Plataforma.Repo

  setup do
    owner_user_a = user_fixture()
    owner_user_b = user_fixture(%{email: "second-owner@example.com"})

    {:ok, %{organization: organization, owner: owner_a}} =
      Organizations.create_organization(owner_user_a, %{name: "Owners concorrentes"})

    {:ok, %{invitation: invitation}} =
      Organizations.invite_member(owner_a, organization, %{
        email: owner_user_b.email,
        role: :member
      })

    {:ok, member_b} =
      Organizations.accept_invitation(owner_user_b, sign_invitation(invitation.id))

    {:ok, owner_b} =
      Organizations.change_member_role(owner_a, organization, member_b, :owner)

    %{organization: organization, owner_a: owner_a, owner_b: owner_b}
  end

  test "bloqueia todos os owners ativos antes de contar e atualizar", context do
    handler_id = "owner-lock-#{System.unique_integer([:positive])}"
    test_pid = self()

    :ok =
      :telemetry.attach(
        handler_id,
        [:plataforma, :repo, :query],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:sql, metadata.query})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    assert {:ok, _membership} =
             Organizations.deactivate_member(
               context.owner_a,
               context.organization,
               context.owner_b
             )

    queries = collect_queries([])

    owner_lock_index =
      Enum.find_index(queries, fn query ->
        query =~ ~s(FROM "organization_memberships") and
          query =~ ~s("role" = ) and query =~ ~s("active") and query =~ "FOR UPDATE"
      end)

    count_index = Enum.find_index(queries, &String.contains?(&1, "count("))
    update_index = Enum.find_index(queries, &String.starts_with?(&1, "UPDATE"))

    assert is_integer(owner_lock_index)
    assert is_integer(count_index)
    assert is_integer(update_index)
    assert owner_lock_index < count_index
    assert count_index < update_index
  end

  test "duas desativações concorrentes deixam exatamente um owner ativo", context do
    parent = self()

    tasks =
      [
        {context.owner_a, context.owner_b},
        {context.owner_b, context.owner_a}
      ]
      |> Enum.map(fn {actor, target} ->
        Task.async(fn ->
          Sandbox.allow(Repo, parent, self())
          send(parent, {:ready, self()})

          receive do
            :go -> Organizations.deactivate_member(actor, context.organization, target)
          end
        end)
      end)

    task_pids = Enum.map(tasks, & &1.pid)
    Enum.each(task_pids, fn pid -> assert_receive {:ready, ^pid} end)
    Enum.each(task_pids, &send(&1, :go))

    results = Enum.map(tasks, &Task.await(&1, 5_000))

    assert Enum.count(results, &match?({:ok, %Membership{}}, &1)) == 1
    assert Enum.count(results, &match?({:error, :last_owner}, &1)) == 1

    assert Repo.aggregate(
             from(membership in Membership,
               where:
                 membership.organization_id == ^context.organization.id and
                   membership.role == :owner and membership.active
             ),
             :count
           ) == 1
  end

  defp collect_queries(queries) do
    receive do
      {:sql, query} -> collect_queries([query | queries])
    after
      0 -> Enum.reverse(queries)
    end
  end

  defp sign_invitation(invitation_id) do
    Phoenix.Token.sign(
      PlataformaWeb.Endpoint,
      Application.fetch_env!(:plataforma, :invitation_token_salt),
      invitation_id
    )
  end
end
