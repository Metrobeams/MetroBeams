defmodule Plataforma.Organizations do
  @moduledoc """
  Context for managing organizations, memberships, and invitations.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Plataforma.Organizations.Membership
  alias Plataforma.Organizations.Invitation
  alias Plataforma.Organizations.Organization
  alias Plataforma.Organizations.Policy
  alias Plataforma.Organizations.Workers.SendInvitationEmail
  alias Plataforma.{Accounts, Notifications}
  alias Plataforma.Repo

  @spec change_organization(Organization.t(), map()) :: Ecto.Changeset.t()
  def change_organization(%Organization{} = organization, attrs \\ %{}) do
    Organization.changeset(organization, attrs)
  end

  @spec create_organization(struct(), map(), keyword()) ::
          {:ok, %{organization: Organization.t(), owner: Membership.t()}}
          | {:error, atom(), Ecto.Changeset.t(), map()}
  def create_organization(user, attrs, opts \\ []) do
    owner_attrs = Keyword.get(opts, :owner, %{})

    Multi.new()
    |> Multi.insert(:organization, Organization.changeset(%Organization{}, attrs))
    |> Multi.insert(:owner, fn %{organization: organization} ->
      %Membership{organization_id: organization.id, user_id: user.id}
      |> Membership.changeset(Map.merge(%{role: :owner}, owner_attrs))
    end)
    |> Repo.transaction()
  end

  @spec get_active_membership(struct(), Ecto.UUID.t() | Organization.t()) :: Membership.t() | nil
  def get_active_membership(user, %Organization{id: organization_id}) do
    get_active_membership(user, organization_id)
  end

  def get_active_membership(user, organization_id) when is_binary(organization_id) do
    Repo.one(
      from membership in Membership,
        where:
          membership.user_id == ^user.id and membership.organization_id == ^organization_id and
            membership.active
    )
  end

  @spec get_membership(struct(), Organization.t()) :: Membership.t() | nil
  def get_membership(user, %Organization{id: organization_id}) do
    Repo.get_by(Membership, user_id: user.id, organization_id: organization_id)
  end

  @spec update_organization(Membership.t(), Organization.t(), map()) ::
          {:ok, Organization.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def update_organization(actor, organization, attrs) do
    with {:ok, _actor} <- permit_actor(actor, :update_organization, organization) do
      organization
      |> Organization.changeset(attrs)
      |> Repo.update()
    end
  end

  @spec list_organizations(struct(), map(), keyword()) ::
          {:ok, {[Organization.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_organizations(user, params \\ %{}, opts \\ []) do
    include_inactive? = Keyword.get(opts, :include_inactive, false)

    query =
      from organization in Organization,
        join: membership in Membership,
        on:
          membership.organization_id == organization.id and membership.user_id == ^user.id and
            membership.active,
        where: ^include_inactive? or organization.active,
        where: not (^include_inactive?) or membership.role in [:owner, :admin],
        preload: [memberships: membership]

    Flop.validate_and_run(query, params, for: Organization, repo: Repo)
  end

  @spec list_organizations_for_user(struct(), map(), keyword()) ::
          {:ok, {[Organization.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_organizations_for_user(user, params \\ %{}, opts \\ []) do
    list_organizations(user, params, opts)
  end

  @spec get_organization(struct(), Ecto.UUID.t()) ::
          {:ok, Organization.t()} | {:error, :not_found}
  def get_organization(user, organization_id) do
    case scoped_organizations(user)
         |> where([organization], organization.id == ^organization_id)
         |> Repo.one() do
      nil -> {:error, :not_found}
      organization -> {:ok, organization}
    end
  end

  @spec get_organization_for_user(struct(), Ecto.UUID.t()) ::
          {:ok, Organization.t()} | {:error, :not_found}
  def get_organization_for_user(user, organization_id),
    do: get_organization(user, organization_id)

  @spec get_organization_by_slug(struct(), String.t()) ::
          {:ok, Organization.t()} | {:error, :not_found}
  def get_organization_by_slug(user, slug) do
    normalized_slug = Slug.slugify(slug)

    case scoped_organizations(user)
         |> where([organization], organization.slug == ^normalized_slug)
         |> Repo.one() do
      nil -> {:error, :not_found}
      organization -> {:ok, organization}
    end
  end

  @spec get_organization_by_slug_for_user(struct(), String.t()) ::
          {:ok, Organization.t()} | {:error, :not_found}
  def get_organization_by_slug_for_user(user, slug), do: get_organization_by_slug(user, slug)

  @spec deactivate_organization(Membership.t(), Organization.t()) ::
          {:ok, Organization.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def deactivate_organization(actor, organization) do
    with {:ok, _actor} <- permit_actor(actor, :deactivate_organization, organization) do
      Repo.transaction(fn -> do_deactivate_organization(organization) end)
    end
  end

  defp do_deactivate_organization(organization) do
    case organization |> Organization.changeset(%{active: false}) |> Repo.update() do
      {:ok, deactivated} -> deactivated
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  @spec deactivate_member(Membership.t(), Organization.t(), Membership.t()) ::
          {:ok, Membership.t()} | {:error, :unauthorized | :last_owner | Ecto.Changeset.t()}
  def deactivate_member(actor, organization, target) do
    with {:ok, _actor} <- permit_actor(actor, :deactivate_member, organization) do
      Repo.transaction(fn -> do_deactivate_member(organization, target) end)
    end
  end

  defp do_deactivate_member(organization, target) do
    locked_owners = lock_active_owners(organization.id)
    active_owner_count = count_active_owners(organization.id)

    with {:ok, scoped_target} <- locked_target_ok(target.id, organization.id, locked_owners),
         :ok <- check_not_last_owner(scoped_target, active_owner_count) do
      update_membership(scoped_target, %{active: false})
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  @spec list_members(Membership.t(), Organization.t(), map()) ::
          {:ok, [Membership.t()]} | {:error, :unauthorized}
  def list_members(actor, organization, _params \\ %{}) do
    with {:ok, _actor} <- permit_actor(actor, :list_members, organization) do
      members =
        Membership
        |> where([membership], membership.organization_id == ^organization.id)
        |> order_by([membership], asc: membership.inserted_at)
        |> preload(:user)
        |> Repo.all()

      {:ok, members}
    end
  end

  @spec change_member_role(Membership.t(), Organization.t(), Membership.t(), atom()) ::
          {:ok, Membership.t()}
          | {:error, :unauthorized | :last_owner | Ecto.Changeset.t()}
  def change_member_role(actor, organization, target, role) do
    with {:ok, _actor} <- permit_actor(actor, :change_member_role, organization) do
      Repo.transaction(fn -> do_change_member_role(organization, target, role) end)
    end
  end

  defp do_change_member_role(organization, target, role) do
    locked_owners = lock_active_owners(organization.id)
    active_owner_count = count_active_owners(organization.id)

    with {:ok, scoped_target} <- locked_target_ok(target.id, organization.id, locked_owners),
         :ok <- check_role_change_allowed(scoped_target, role, active_owner_count) do
      update_membership(scoped_target, %{role: role})
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp lock_active_owners(organization_id) do
    Membership
    |> where(
      [membership],
      membership.organization_id == ^organization_id and membership.role == :owner and
        membership.active
    )
    |> order_by([membership], asc: membership.id)
    |> lock("FOR UPDATE")
    |> Repo.all()
  end

  defp count_active_owners(organization_id) do
    Repo.aggregate(
      from(membership in Membership,
        where:
          membership.organization_id == ^organization_id and membership.role == :owner and
            membership.active
      ),
      :count
    )
  end

  defp locked_target(target_id, organization_id, locked_owners) do
    Enum.find(locked_owners, &(&1.id == target_id)) ||
      get_scoped_membership(target_id, organization_id, lock: true)
  end

  defp locked_target_ok(target_id, organization_id, locked_owners) do
    case locked_target(target_id, organization_id, locked_owners) do
      nil -> {:error, :not_found}
      target -> {:ok, target}
    end
  end

  defp check_not_last_owner(scoped_target, active_owner_count) do
    if removes_last_owner?(scoped_target, active_owner_count),
      do: {:error, :last_owner},
      else: :ok
  end

  defp check_role_change_allowed(_scoped_target, :owner, _active_owner_count), do: :ok

  defp check_role_change_allowed(scoped_target, _role, active_owner_count) do
    check_not_last_owner(scoped_target, active_owner_count)
  end

  defp update_membership(membership, attrs) do
    case membership |> Membership.changeset(attrs) |> Repo.update() do
      {:ok, updated} -> updated
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp removes_last_owner?(%Membership{role: :owner, active: true}, active_owner_count),
    do: active_owner_count <= 1

  defp removes_last_owner?(_membership, _active_owner_count), do: false

  defp scoped_organizations(user) do
    from organization in Organization,
      join: membership in Membership,
      on:
        membership.organization_id == organization.id and membership.user_id == ^user.id and
          membership.active,
      where: organization.active
  end

  @spec invite_member(Membership.t(), Organization.t(), map()) ::
          {:ok, %{invitation: Invitation.t(), invitation_email_job: Oban.Job.t()}}
          | {:error, atom(), term(), map()}
          | {:error, :unauthorized}
  def invite_member(actor, organization, attrs) do
    with {:ok, actor} <- permit_actor(actor, :invite_member, organization) do
      expires_at = Map.get(attrs, :expires_at, DateTime.add(DateTime.utc_now(), 7, :day))

      invitation_changeset =
        %Invitation{organization_id: organization.id, invited_by_membership_id: actor.id}
        |> Invitation.changeset(Map.put(attrs, :expires_at, expires_at))

      email = Ecto.Changeset.get_field(invitation_changeset, :email)

      Multi.new()
      |> Multi.run(:expired_invitation, fn repo, _changes ->
        revoke_expired_open_invitation(repo, organization.id, email)
      end)
      |> Multi.insert(:invitation, invitation_changeset)
      |> Multi.run(:notification, fn repo, %{invitation: invitation} ->
        notify_invitation(repo, invitation, organization)
      end)
      |> Oban.insert(:invitation_email_job, fn %{invitation: invitation} ->
        SendInvitationEmail.new(%{"invitation_id" => invitation.id})
      end)
      |> Repo.transaction()
    end
  end

  defp revoke_expired_open_invitation(repo, organization_id, email) do
    now = DateTime.utc_now()

    invitation =
      repo.one(
        from invitation in Invitation,
          where:
            invitation.organization_id == ^organization_id and invitation.email == ^email and
              is_nil(invitation.accepted_at) and is_nil(invitation.revoked_at) and
              invitation.expires_at <= ^now,
          lock: "FOR UPDATE"
      )

    case invitation do
      nil ->
        {:ok, nil}

      invitation ->
        invitation
        |> Ecto.Changeset.change(revoked_at: now)
        |> repo.update()
    end
  end

  defp notify_invitation(repo, invitation, organization) do
    case Accounts.get_user_by_email(invitation.email) do
      nil ->
        {:ok, nil}

      user ->
        Notifications.notify_organization_invitation(repo, user, invitation, organization)
    end
  end

  @spec accept_invitation(struct(), String.t()) ::
          {:ok, Membership.t()}
          | {:error,
             :invalid_token
             | :not_found
             | :expired
             | :revoked
             | :already_accepted
             | :email_mismatch}
  def accept_invitation(user, signed_token) do
    salt = Application.fetch_env!(:plataforma, :invitation_token_salt)

    case Phoenix.Token.verify(PlataformaWeb.Endpoint, salt, signed_token,
           max_age: 7 * 24 * 60 * 60
         ) do
      {:ok, invitation_id} -> accept_invitation_id(user, invitation_id)
      {:error, _reason} -> {:error, :invalid_token}
    end
  end

  @spec revoke_invitation(Membership.t(), Invitation.t()) ::
          {:ok, Invitation.t()} | {:error, :unauthorized | :already_accepted | Ecto.Changeset.t()}
  def revoke_invitation(actor, invitation) do
    with {:ok, actor} <- reload_actor(actor),
         {:ok, scoped_invitation} <- find_scoped_invitation(invitation, actor) do
      revoke_with_permission(scoped_invitation, actor)
    end
  end

  defp find_scoped_invitation(invitation, actor) do
    case Repo.one(
           from item in Invitation,
             join: organization in assoc(item, :organization),
             where: item.id == ^invitation.id and item.organization_id == ^actor.organization_id,
             preload: [organization: organization]
         ) do
      nil -> {:error, :not_found}
      scoped -> {:ok, scoped}
    end
  end

  defp revoke_with_permission(invitation, actor) do
    with :ok <- Bodyguard.permit(Policy, :invite_member, actor, invitation.organization),
         :ok <- revocable_invitation?(invitation) do
      invitation
      |> Ecto.Changeset.change(revoked_at: DateTime.utc_now())
      |> Repo.update()
    end
  end

  defp revocable_invitation?(%Invitation{accepted_at: nil}), do: :ok
  defp revocable_invitation?(%Invitation{}), do: {:error, :already_accepted}

  defp accept_invitation_id(user, invitation_id) do
    Repo.transaction(fn ->
      invitation =
        Invitation
        |> where([invitation], invitation.id == ^invitation_id)
        |> lock("FOR UPDATE")
        |> Repo.one()

      with :ok <- acceptable_invitation?(invitation, user),
           {:ok, membership} <- upsert_invited_membership(invitation, user),
           {:ok, _invitation} <- mark_accepted(invitation) do
        membership
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp acceptable_invitation?(nil, _user), do: {:error, :not_found}

  defp acceptable_invitation?(%Invitation{accepted_at: accepted_at}, _user)
       when not is_nil(accepted_at), do: {:error, :already_accepted}

  defp acceptable_invitation?(%Invitation{revoked_at: revoked_at}, _user)
       when not is_nil(revoked_at), do: {:error, :revoked}

  defp acceptable_invitation?(%Invitation{} = invitation, user) do
    cond do
      DateTime.compare(invitation.expires_at, DateTime.utc_now()) != :gt ->
        {:error, :expired}

      String.downcase(user.email) != String.downcase(invitation.email) ->
        {:error, :email_mismatch}

      true ->
        :ok
    end
  end

  defp upsert_invited_membership(invitation, user) do
    case Repo.get_by(Membership, organization_id: invitation.organization_id, user_id: user.id) do
      nil ->
        %Membership{organization_id: invitation.organization_id, user_id: user.id}
        |> Membership.changeset(%{role: invitation.role, active: true})
        |> Repo.insert()

      membership ->
        membership
        |> Membership.changeset(%{role: invitation.role, active: true})
        |> Repo.update()
    end
  end

  defp mark_accepted(invitation) do
    invitation
    |> Ecto.Changeset.change(accepted_at: DateTime.utc_now())
    |> Repo.update()
  end

  defp get_scoped_membership(membership_id, organization_id, opts) do
    query =
      from membership in Membership,
        where: membership.id == ^membership_id and membership.organization_id == ^organization_id

    query = if Keyword.get(opts, :lock, false), do: lock(query, "FOR UPDATE"), else: query
    Repo.one(query)
  end

  defp permit_actor(actor, action, organization) do
    with {:ok, persisted_actor} <- reload_actor(actor),
         :ok <- Bodyguard.permit(Policy, action, persisted_actor, organization) do
      {:ok, persisted_actor}
    end
  end

  defp reload_actor(%Membership{id: membership_id}) when not is_nil(membership_id) do
    case Repo.get(Membership, membership_id) do
      %Membership{active: true} = membership -> {:ok, membership}
      _membership -> {:error, :unauthorized}
    end
  end

  defp reload_actor(_actor), do: {:error, :unauthorized}
end
