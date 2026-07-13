defmodule Plataforma.Organizations.Workers.SendInvitationEmail do
  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5,
    unique: [period: :infinity, fields: [:worker, :args], keys: [:invitation_id]]

  alias Plataforma.Mailer
  alias Plataforma.Organizations.Invitation
  alias Plataforma.Organizations.InvitationEmail
  alias Plataforma.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"invitation_id" => invitation_id}}) do
    invitation = Invitation |> Repo.get(invitation_id) |> preload_organization()

    with :ok <- deliverable?(invitation),
         token <- sign(invitation.id),
         {:ok, _metadata} <- invitation |> InvitationEmail.build(token) |> Mailer.deliver() do
      :ok
    end
  end

  defp preload_organization(nil), do: nil
  defp preload_organization(invitation), do: Repo.preload(invitation, :organization)

  defp deliverable?(nil), do: {:cancel, :not_found}

  defp deliverable?(%Invitation{accepted_at: accepted_at}) when not is_nil(accepted_at),
    do: {:cancel, :already_accepted}

  defp deliverable?(%Invitation{revoked_at: revoked_at}) when not is_nil(revoked_at),
    do: {:cancel, :revoked}

  defp deliverable?(%Invitation{expires_at: expires_at}) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :gt, do: :ok, else: {:cancel, :expired}
  end

  defp sign(invitation_id) do
    Phoenix.Token.sign(
      PlataformaWeb.Endpoint,
      Application.fetch_env!(:plataforma, :invitation_token_salt),
      invitation_id
    )
  end
end
