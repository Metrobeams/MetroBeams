defmodule Plataforma.Organizations.InvitationEmail do
  import Swoosh.Email

  alias Plataforma.Organizations.Invitation

  @spec build(Invitation.t(), String.t()) :: Swoosh.Email.t()
  def build(invitation, signed_token) do
    from = Application.fetch_env!(:plataforma, :invitation_email_from)
    base_url = Application.fetch_env!(:plataforma, :invitation_base_url)
    url = base_url <> "?" <> URI.encode_query(%{"token" => signed_token})
    organization_name = invitation.organization.name
    role = to_string(invitation.role)
    expires_at = Calendar.strftime(invitation.expires_at, "%Y-%m-%d %H:%M UTC")

    new()
    |> to(invitation.email)
    |> from(from)
    |> subject("Convite para #{organization_name}")
    |> text_body("""
    Você foi convidado para participar de #{organization_name} com o papel #{role}.
    O convite expira em #{expires_at}.
    Aceite em: #{url}
    Ignore esta mensagem se não reconhecer a organização.
    """)
    |> html_body("""
    <p>Você foi convidado para participar de <strong>#{organization_name}</strong> com o papel #{role}.</p>
    <p>O convite expira em #{expires_at}.</p>
    <p><a href="#{url}">Aceitar convite</a></p>
    <p>Ignore esta mensagem se não reconhecer a organização.</p>
    """)
  end
end
