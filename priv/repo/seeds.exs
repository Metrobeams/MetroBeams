# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Plataforma.Repo.insert!(%Plataforma.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Plataforma.Repo
alias Plataforma.Accounts.User
alias Plataforma.Organizations.{Organization, Membership}
alias Plataforma.Assets.{AssetCategory, Manufacturer}
alias Plataforma.Notifications.Notification
alias Plataforma.Agents.Agent

import Ecto.Query

# ── Helpers ──────────────────────────────────────────────────────────────────

defmodule Seeds do
  @password "secretpassword123"

  def password_hash, do: Argon2.hash_pwd_salt(@password)
  def now_usec, do: DateTime.utc_now(:microsecond)
  def now_sec, do: DateTime.utc_now(:second)
  def days_ago(n), do: DateTime.utc_now(:microsecond) |> DateTime.add(-n * 86400, :second)

  def get_or_insert_user(email, name) do
    case Repo.get_by(User, email: email) do
      nil ->
        %User{}
        |> User.registration_changeset(%{name: name, email: email})
        |> Ecto.Changeset.put_change(:hashed_password, password_hash())
        |> Ecto.Changeset.put_change(:confirmed_at, days_ago(30))
        |> Ecto.Changeset.put_change(:active, true)
        |> Repo.insert!()

      user ->
        user
    end
  end

  def get_or_insert_organization(name) do
    case Repo.get_by(Organization, name: name) do
      nil ->
        %Organization{}
        |> Organization.changeset(%{name: name})
        |> Repo.insert!()

      org ->
        org
    end
  end

  def get_or_insert_membership(org_id, user_id, attrs) do
    case Repo.get_by(Membership, organization_id: org_id, user_id: user_id) do
      nil ->
        %Membership{organization_id: org_id, user_id: user_id}
        |> Membership.changeset(attrs)
        |> Repo.insert!()

      membership ->
        membership
    end
  end

  def get_or_insert_category(org_id, name, description \\ nil) do
    normalized = name |> String.trim() |> String.downcase()

    case Repo.one(
           from(c in AssetCategory,
             where: c.organization_id == ^org_id and fragment("lower(?)", c.name) == ^normalized
           )
         ) do
      nil ->
        %AssetCategory{organization_id: org_id}
        |> AssetCategory.changeset(%{name: name, description: description})
        |> Repo.insert!()

      cat ->
        cat
    end
  end

  def get_or_insert_manufacturer(org_id, name, attrs \\ %{}) do
    case Repo.one(
           from(m in Manufacturer, where: m.organization_id == ^org_id and m.name == ^name)
         ) do
      nil ->
        %Manufacturer{organization_id: org_id}
        |> Manufacturer.create_changeset(Map.merge(attrs, %{name: name}))
        |> Repo.insert!()

      mfr ->
        mfr
    end
  end

  def get_or_insert_notification(user_id, dedupe_key, attrs) do
    case Repo.one(
           from(n in Notification, where: n.user_id == ^user_id and n.dedupe_key == ^dedupe_key)
         ) do
      nil ->
        %Notification{user_id: user_id}
        |> Notification.changeset(Map.merge(attrs, %{dedupe_key: dedupe_key}))
        |> Repo.insert!()

      notif ->
        notif
    end
  end
end

IO.puts("\nSeeding database...")

# ── Users ────────────────────────────────────────────────────────────────────

IO.puts("  Creating users...")

admin_user = Seeds.get_or_insert_user("admin@exemplo.com", "Carlos Silva")
tech_user = Seeds.get_or_insert_user("tecnico@exemplo.com", "Ana Oliveira")
member_user = Seeds.get_or_insert_user("membro@exemplo.com", "João Santos")

IO.puts("    Users ready (password: secretpassword123)")

# ── Organizations ────────────────────────────────────────────────────────────

IO.puts("  Creating organizations...")

org1 = Seeds.get_or_insert_organization("Empresa Alpha")
org2 = Seeds.get_or_insert_organization("Indústria Beta")

IO.puts("    Organizations ready")

# ── Memberships ──────────────────────────────────────────────────────────────

IO.puts("  Creating memberships...")

Seeds.get_or_insert_membership(org1.id, admin_user.id, %{
  role: "owner",
  active: true,
  job_title: "Diretor de TI",
  department: "Tecnologia da Informação",
  employee_code: "EMP001"
})

Seeds.get_or_insert_membership(org1.id, tech_user.id, %{
  role: "technician",
  active: true,
  job_title: "Técnico de Manutenção",
  department: "Manutenção",
  employee_code: "EMP002"
})

Seeds.get_or_insert_membership(org1.id, member_user.id, %{
  role: "member",
  active: true,
  job_title: "Analista",
  department: "Operações",
  employee_code: "EMP003"
})

Seeds.get_or_insert_membership(org2.id, admin_user.id, %{
  role: "admin",
  active: true,
  job_title: "Gerente",
  department: "Administração",
  employee_code: "IND001"
})

Seeds.get_or_insert_membership(org2.id, tech_user.id, %{
  role: "technician",
  active: true,
  job_title: "Engenheiro de Manutenção",
  department: "Engenharia",
  employee_code: "IND002"
})

IO.puts("    Memberships ready")

# ── Asset Categories ─────────────────────────────────────────────────────────

IO.puts("  Creating asset categories...")

categories_org1 = [
  {"Equipamentos de TI", "Computadores, monitores, impressoras"},
  {"Mobiliário", "Mesas, cadeiras, armários"},
  {"Veículos", "Automóveis, caminhonetes, motos"},
  {"Ferramentas", "Ferramentas manuais e elétricas"},
  {"Equipamentos de Segurança", "CFTV, alarmes, cercas elétricas"}
]

categories_org2 = [
  {"Maquinário Industrial", "Máquinas de produção e linha de montagem"},
  {"Equipamentos de Medição", "Calibradores, micrômetros, multímetros"},
  {"Equipamentos de Segurança", "EPIs, extintores, luvas, capacetes"}
]

for {name, desc} <- categories_org1 do
  Seeds.get_or_insert_category(org1.id, name, desc)
end

for {name, desc} <- categories_org2 do
  Seeds.get_or_insert_category(org2.id, name, desc)
end

IO.puts("    Asset categories ready")

# ── Manufacturers ────────────────────────────────────────────────────────────

IO.puts("  Creating manufacturers...")

manufacturers_org1 = [
  {"Dell", "https://www.dell.com", "https://www.dell.com/support"},
  {"HP", "https://www.hp.com", "https://support.hp.com"},
  {"Lenovo", "https://www.lenovo.com", "https://support.lenovo.com"},
  {"Samsung", "https://www.samsung.com", "https://www.samsung.com/support"},
  {"Apple", "https://www.apple.com", "https://support.apple.com"}
]

manufacturers_org2 = [
  {"Siemens", "https://www.siemens.com", "https://support.siemens.com"},
  {"ABB", "https://new.abb.com", "https://new.abb.com/support"},
  {"Schneider Electric", "https://www.se.com", "https://www.se.com/support"},
  {"Emerson", "https://www.emerson.com", "https://www.emerson.com/support"}
]

for {name, website, support} <- manufacturers_org1 do
  Seeds.get_or_insert_manufacturer(org1.id, name, %{website: website, support_url: support})
end

for {name, website, support} <- manufacturers_org2 do
  Seeds.get_or_insert_manufacturer(org2.id, name, %{website: website, support_url: support})
end

IO.puts("    Manufacturers ready")

# ── Notifications ────────────────────────────────────────────────────────────

IO.puts("  Creating notifications...")

Seeds.get_or_insert_notification(
  admin_user.id,
  "org:#{org1.id}:member_added:#{member_user.id}",
  %{
    kind: :organization_invitation,
    status: :info,
    title: "Novo membro adicionado",
    body: "João Santos foi adicionado à organização Empresa Alpha.",
    action_path: "/organizations/#{org1.id}/members",
    metadata: %{"user_name" => "João Santos"}
  }
)

Seeds.get_or_insert_notification(tech_user.id, "maintenance:7090:2026-07-15", %{
  kind: :organization_invitation,
  status: :warning,
  title: "Lembrete de manutenção",
  body: "O equipamento Dell OptiPlex 7090 está agendado para manutenção preventiva amanhã.",
  action_path: "/assets",
  metadata: %{"equipment" => "Dell OptiPlex 7090"}
})

Seeds.get_or_insert_notification(
  admin_user.id,
  "org:#{org1.id}:invitation_accepted:#{tech_user.id}",
  %{
    kind: :organization_invitation,
    status: :success,
    title: "Convite aceito",
    body: "Ana Oliveira aceitou o convite para a organização Empresa Alpha.",
    action_path: "/organizations/#{org1.id}/members",
    metadata: %{"user_name" => "Ana Oliveira"}
  }
)

IO.puts("    Notifications ready")

# ── Agents ───────────────────────────────────────────────────────────────────

IO.puts("  Creating agents...")

agents_data = [
  %{
    organization_id: org1.id,
    machine_id: "WS-001-ALPHA",
    hostname: "desktop-carlos",
    platform: "windows",
    architecture: "amd64",
    agent_version: "1.2.0",
    credential_digest: :crypto.hash(:sha256, "credential-ws001"),
    active: true,
    enrolled_at: Seeds.now_usec(),
    last_seen_at: Seeds.now_usec()
  },
  %{
    organization_id: org1.id,
    machine_id: "SRV-001-ALPHA",
    hostname: "srv-web-01",
    platform: "linux",
    architecture: "amd64",
    agent_version: "1.2.0",
    credential_digest: :crypto.hash(:sha256, "credential-srv001"),
    active: true,
    enrolled_at: Seeds.days_ago(15),
    last_seen_at: Seeds.days_ago(1)
  },
  %{
    organization_id: org2.id,
    machine_id: "PC-FAB-001",
    hostname: "pc-fabrica-01",
    platform: "linux",
    architecture: "amd64",
    agent_version: "1.1.5",
    credential_digest: :crypto.hash(:sha256, "credential-fab001"),
    active: true,
    enrolled_at: Seeds.days_ago(45),
    last_seen_at: Seeds.now_usec()
  }
]

for a <- agents_data do
  case Repo.one(
         from(ag in Agent,
           where: ag.organization_id == ^a.organization_id and ag.machine_id == ^a.machine_id
         )
       ) do
    nil ->
      %Agent{organization_id: a.organization_id}
      |> Agent.enrollment_changeset(a)
      |> Ecto.Changeset.put_change(:credential_digest, a.credential_digest)
      |> Ecto.Changeset.put_change(:enrolled_at, a.enrolled_at)
      |> Ecto.Changeset.put_change(:last_seen_at, a.last_seen_at)
      |> Repo.insert!()

    _existing ->
      :ok
  end
end

IO.puts("    Agents ready")

IO.puts("\nSeeding complete!")
IO.puts("────────────────────────────────────────────────────────")
IO.puts("Login credentials (all users):")
IO.puts("  Email: admin@exemplo.com / tecnico@exemplo.com / membro@exemplo.com")
IO.puts("  Senha: secretpassword123")
IO.puts("────────────────────────────────────────────────────────\n")
