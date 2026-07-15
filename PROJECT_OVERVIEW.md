# Visão geral da plataforma MetroBeams

> Snapshot técnico em 14 de julho de 2026. A estrutura do PostgreSQL foi
> extraída do banco de desenvolvimento `plataforma_dev`, e os módulos foram
> catalogados a partir do código-fonte atual.

## 1. Arquitetura atual

O projeto está dividido em dois repositórios:

| Projeto | Tecnologia | Repositório | Responsabilidade |
| --- | --- | --- | --- |
| Plataforma | Elixir, Phoenix, Ecto e PostgreSQL | [Metrobeams/MetroBeams](https://github.com/Metrobeams/MetroBeams) | API, autenticação, organizações, cadastros, notificações e administração |
| Agent | Go | [Metrobeams/agent](https://github.com/Metrobeams/agent) | Aplicação nativa instalada nas máquinas para inscrição e futura coleta de inventário |

Fluxo arquitetural previsto:

```text
┌──────────────────────┐       HTTPS/JSON        ┌─────────────────────────┐
│ Agent nativo em Go   │ ──────────────────────> │ Phoenix / Elixir        │
│                      │                         │                         │
│ - identificação      │ <────────────────────── │ - enrollment           │
│ - coleta futura      │    credencial própria   │ - autenticação futura   │
│ - envio futuro       │                         │ - inventário futuro     │
└──────────────────────┘                         └────────────┬────────────┘
                                                            │ Ecto
                                                            ▼
                                                  ┌──────────────────────┐
                                                  │ PostgreSQL           │
                                                  │ plataforma_dev       │
                                                  └──────────────────────┘
```

Serviços auxiliares presentes na plataforma:

- Oban para processamento assíncrono;
- MinIO/S3 para armazenamento de arquivos e avatares;
- ImageMagick para processamento de imagens;
- Phoenix Components, Tailwind CSS e Carbon Design System para a interface;
- ExUnit para testes.

## 2. Funcionalidades já existentes

### Plataforma Elixir

- cadastro, login, confirmação e recuperação de usuários;
- autenticação por sessão e magic link;
- organizações multi-tenant;
- memberships com papéis `owner`, `admin`, `technician` e `member`;
- convites para organizações e envio assíncrono de e-mail;
- notificações de usuário;
- upload e processamento de avatar;
- categorias de ativos;
- fabricantes;
- API de enrollment do agente;
- tokens de enrollment com validade e consumo único;
- digest de tokens e credenciais, sem persistir segredos em texto puro;
- re-enrollment com rotação da credencial;
- rejeição de agentes inativos;
- proteção contra concorrência no enrollment da mesma máquina;
- validação de `Content-Type` JSON e redação de dados sensíveis nos logs.

### Interface (Carbon Design System)

- Lead Space Short (320px) na página inicial com wayfinding tag e saudação personalizada;
- Tiles estáticos sem borda para features (padrão Carbon);
- Grid de 16 colunas para layout responsivo;
- Tokens de cor `--carbon-blue-*` para consistência visual;
- Componentes Phoenix com classes Tailwind alinhadas ao Carbon.

### Agente Go

- comando `agent enroll`;
- configuração por flags e variáveis de ambiente;
- envio de hostname, plataforma, arquitetura e versão;
- geração e persistência de um `machine_id` estável;
- exigência de HTTPS, com liberação explícita de HTTP local;
- cliente HTTP para a API Phoenix;
- persistência local segura do estado e da credencial;
- tratamento de erros da API;
- testes e build do executável.

Exemplo de enrollment local:

```bash
./agent enroll \
  --server-url http://localhost:4000 \
  --token TOKEN_DE_ENROLLMENT \
  --allow-insecure-http
```

O estado local fica, por padrão, em:

```text
~/.metrobeams/agent/agent-state.json
```

## 3. Estrutura atual do PostgreSQL

### Relacionamentos principais

```text
users
├──< users_tokens
├──< organization_memberships >── organizations
└──< notifications                  ├──< organization_invitations
                                     ├──< asset_categories
organization_memberships            ├──< manufacturers
└──< organization_invitations       ├──< agents
                                     └──< agent_enrollment_tokens

oban_jobs e oban_peers: infraestrutura de jobs
schema_migrations: controle de migrations do Ecto
```

### `users`

Usuários da plataforma.

| Coluna | Tipo | Regras principais |
| --- | --- | --- |
| `id` | `bigint` | chave primária |
| `email` | `citext` | obrigatório e único |
| `hashed_password` | `varchar` | opcional |
| `confirmed_at` | `timestamp` | opcional |
| `name` | `varchar` | obrigatório |
| `active` | `boolean` | obrigatório, padrão `true` |
| `avatar_key` | `text` | opcional |
| `avatar_content_type` | `varchar` | opcional |
| `avatar_size` | `bigint` | opcional |
| `avatar_updated_at` | `timestamp` | opcional |
| `inserted_at` | `timestamp` | obrigatório |
| `updated_at` | `timestamp` | obrigatório |

Índice único: `email`.

### `users_tokens`

Tokens de sessão, magic link, confirmação e alteração de e-mail.

| Coluna | Tipo | Regras principais |
| --- | --- | --- |
| `id` | `bigint` | chave primária |
| `user_id` | `bigint` | FK para `users.id` |
| `token` | `bytea` | obrigatório |
| `context` | `varchar` | obrigatório |
| `sent_to` | `varchar` | opcional |
| `authenticated_at` | `timestamp` | opcional |
| `inserted_at` | `timestamp` | obrigatório |

Índices: `user_id` e combinação única de `context` com `token`.

### `organizations`

Tenant principal da aplicação.

| Coluna | Tipo | Regras principais |
| --- | --- | --- |
| `id` | `uuid` | chave primária, gerada pelo PostgreSQL |
| `name` | `text` | obrigatório |
| `slug` | `citext` | obrigatório e único |
| `settings` | `jsonb` | obrigatório, padrão `{}` |
| `active` | `boolean` | obrigatório, padrão `true` |
| `inserted_at` | `timestamptz` | obrigatório |
| `updated_at` | `timestamptz` | obrigatório |

### `organization_memberships`

Associação de usuários às organizações.

| Coluna | Tipo | Regras principais |
| --- | --- | --- |
| `id` | `uuid` | chave primária |
| `organization_id` | `uuid` | FK para `organizations.id` |
| `user_id` | `bigint` | FK para `users.id` |
| `role` | `varchar` | obrigatório e validado por constraint |
| `active` | `boolean` | obrigatório, padrão `true` |
| `job_title` | `varchar` | opcional |
| `department` | `varchar` | opcional |
| `employee_code` | `varchar` | opcional |
| `inserted_at` | `timestamp` | obrigatório |
| `updated_at` | `timestamp` | obrigatório |

Restrições e índices principais:

- associação única entre organização e usuário;
- `employee_code` único por organização quando preenchido;
- índices por usuário/estado e organização/papel.

### `organization_invitations`

Convites pendentes, aceitos ou revogados.

| Coluna | Tipo | Regras principais |
| --- | --- | --- |
| `id` | `uuid` | chave primária |
| `organization_id` | `uuid` | FK para `organizations.id` |
| `invited_by_membership_id` | `uuid` | FK para `organization_memberships.id` |
| `email` | `citext` | obrigatório |
| `role` | `varchar` | obrigatório e validado por constraint |
| `expires_at` | `timestamp` | obrigatório |
| `accepted_at` | `timestamp` | opcional |
| `revoked_at` | `timestamp` | opcional |
| `inserted_at` | `timestamp` | obrigatório |
| `updated_at` | `timestamp` | obrigatório |

Há somente um convite aberto por organização e endereço de e-mail.

### `notifications`

Notificações entregues aos usuários.

| Coluna | Tipo | Regras principais |
| --- | --- | --- |
| `id` | `uuid` | chave primária |
| `user_id` | `bigint` | FK para `users.id` |
| `kind` | `varchar` | obrigatório |
| `title` | `varchar` | obrigatório |
| `body` | `text` | obrigatório |
| `action_path` | `varchar` | opcional |
| `metadata` | `jsonb` | obrigatório, padrão `{}` |
| `status` | `varchar` | obrigatório, padrão `info` |
| `read_at` | `timestamp` | opcional |
| `dedupe_key` | `varchar` | obrigatório |
| `inserted_at` | `timestamp` | obrigatório |
| `updated_at` | `timestamp` | obrigatório |

A combinação `user_id` e `dedupe_key` é única.

### `asset_categories`

Categorias de ativos isoladas por organização.

| Coluna | Tipo | Regras principais |
| --- | --- | --- |
| `id` | `uuid` | chave primária |
| `organization_id` | `uuid` | FK para `organizations.id` |
| `name` | `varchar` | obrigatório |
| `description` | `varchar` | opcional |
| `active` | `boolean` | obrigatório, padrão `true` |
| `inserted_at` | `timestamp` | obrigatório |
| `updated_at` | `timestamp` | obrigatório |

O nome é único por organização entre categorias ativas.

### `manufacturers`

Fabricantes isolados por organização.

| Coluna | Tipo | Regras principais |
| --- | --- | --- |
| `id` | `uuid` | chave primária |
| `organization_id` | `uuid` | FK para `organizations.id` |
| `name` | `varchar` | obrigatório |
| `website` | `varchar` | opcional |
| `support_url` | `varchar` | opcional |
| `active` | `boolean` | obrigatório, padrão `true` |
| `inserted_at` | `timestamp` | obrigatório |
| `updated_at` | `timestamp` | obrigatório |

O nome é único por organização entre fabricantes ativos.

### `agents`

Máquinas inscritas na plataforma.

| Coluna | Tipo | Regras principais |
| --- | --- | --- |
| `id` | `uuid` | chave primária |
| `organization_id` | `uuid` | FK para `organizations.id` |
| `machine_id` | `varchar` | identificador estável da instalação |
| `hostname` | `varchar` | obrigatório |
| `platform` | `varchar` | obrigatório |
| `architecture` | `varchar` | obrigatório |
| `agent_version` | `varchar` | obrigatório |
| `credential_digest` | `bytea` | digest da credencial do agente |
| `active` | `boolean` | obrigatório, padrão `true` |
| `enrolled_at` | `timestamp` | momento do enrollment atual |
| `last_seen_at` | `timestamp` | opcional; reservado para heartbeat |
| `inserted_at` | `timestamp` | obrigatório |
| `updated_at` | `timestamp` | obrigatório |

A combinação de `organization_id` e `machine_id` é única.

### `agent_enrollment_tokens`

Tokens temporários utilizados para autorizar o enrollment.

| Coluna | Tipo | Regras principais |
| --- | --- | --- |
| `id` | `uuid` | chave primária |
| `organization_id` | `uuid` | FK para `organizations.id` |
| `token_digest` | `bytea` | obrigatório e único |
| `expires_at` | `timestamp` | obrigatório |
| `consumed_at` | `timestamp` | opcional; preenchido após uso |
| `inserted_at` | `timestamp` | obrigatório |
| `updated_at` | `timestamp` | obrigatório |

O valor original do token não é armazenado; somente seu digest permanece no
banco.

### Infraestrutura do Oban e Ecto

| Tabela | Finalidade |
| --- | --- |
| `oban_jobs` | fila, argumentos, tentativas, erros, prioridade, estado e timestamps dos jobs |
| `oban_peers` | coordenação dos nós do Oban |
| `schema_migrations` | versões de migrations aplicadas pelo Ecto |

`oban_jobs` possui índices GIN para `args` e `meta`, além de índices para
estado, fila e agendamento.

## 4. Módulos Elixir atuais

### Núcleo da aplicação

- `Plataforma`
- `Plataforma.Application`
- `Plataforma.Release`
- `Plataforma.Repo`

### Contas e autenticação

- `Plataforma.Accounts`
- `Plataforma.Accounts.Scope`
- `Plataforma.Accounts.User`
- `Plataforma.Accounts.UserNotifier`
- `Plataforma.Accounts.UserToken`

### Agentes

- `Plataforma.Agents`
- `Plataforma.Agents.Agent`
- `Plataforma.Agents.EnrollmentToken`
- `Plataforma.Agents.Secret`

### Ativos

- `Plataforma.Assets`
- `Plataforma.Assets.AssetCategory`
- `Plataforma.Assets.Manufacturer`

### Organizações

- `Plataforma.Organizations`
- `Plataforma.Organizations.Organization`
- `Plataforma.Organizations.Membership`
- `Plataforma.Organizations.Invitation`
- `Plataforma.Organizations.InvitationEmail`
- `Plataforma.Organizations.Policy`
- `Plataforma.Organizations.Workers.SendInvitationEmail`

### Notificações

- `Plataforma.Notifications`
- `Plataforma.Notifications.Notification`

### E-mail, mídia e armazenamento

- `Plataforma.Mailer`
- `Plataforma.Media.Avatar`
- `Plataforma.Media.ImageProcessor`
- `Plataforma.Media.ImageProcessor.ImageMagick`
- `Plataforma.S3Client`
- `Plataforma.Storage`
- `Plataforma.Storage.MinIO`

### Infraestrutura web

- `PlataformaWeb`
- `PlataformaWeb.Endpoint`
- `PlataformaWeb.Router`
- `PlataformaWeb.Telemetry`
- `PlataformaWeb.Gettext`
- `PlataformaWeb.UserAuth`
- `PlataformaWeb.Plugs.FetchNotifications`
- `PlataformaWeb.Plugs.RequireJSONContentType`
- `PlataformaWeb.ToastLive`

### Componentes web

- `PlataformaWeb.CoreComponents`
- `PlataformaWeb.Layouts`
- `PlataformaWeb.NotificationCloseButton`
- `PlataformaWeb.NotificationIcons`
- `PlataformaWeb.OrganizationComponents`
- `PlataformaWeb.Sidebar`
- `PlataformaWeb.ToastContainer`

### Controllers e serialização

- `PlataformaWeb.AccountController`
- `PlataformaWeb.AgentEnrollmentController`
- `PlataformaWeb.AgentEnrollmentJSON`
- `PlataformaWeb.AssetCategoryController`
- `PlataformaWeb.AssetCategoryHTML`
- `PlataformaWeb.ErrorHTML`
- `PlataformaWeb.ErrorJSON`
- `PlataformaWeb.ManufacturerController`
- `PlataformaWeb.ManufacturerHTML`
- `PlataformaWeb.NotificationController`
- `PlataformaWeb.NotificationHTML`
- `PlataformaWeb.OrganizationController`
- `PlataformaWeb.OrganizationHTML`
- `PlataformaWeb.PageController`
- `PlataformaWeb.PageHTML`
- `PlataformaWeb.UserRegistrationController`
- `PlataformaWeb.UserRegistrationHTML`
- `PlataformaWeb.UserSessionController`
- `PlataformaWeb.UserSessionHTML`
- `PlataformaWeb.UserSettingsController`
- `PlataformaWeb.UserSettingsHTML`

## 5. API do agente implementada

### Enrollment

```http
POST /api/v1/agents/enroll
Content-Type: application/json
```

Responsabilidades atuais do endpoint:

1. validar o token de enrollment;
2. rejeitar tokens inexistentes, expirados ou já consumidos;
3. identificar a organização associada ao token;
4. criar um novo agente ou atualizar a máquina já inscrita;
5. rotacionar a credencial durante o re-enrollment;
6. consumir o token dentro da transação;
7. devolver o identificador do agente e a credencial uma única vez.

Os tokens e as credenciais são tratados como segredos. A plataforma armazena
digests e filtra os campos sensíveis dos logs.

## 6. O que ainda falta para a coleta de ativos

A fundação de enrollment está pronta, mas a coleta completa de inventário ainda
precisa destas etapas:

1. autenticação das requisições do agente com a credencial recebida;
2. endpoint de heartbeat e atualização de `last_seen_at`;
3. definição do contrato versionado do inventário;
4. schemas e migrations para ativos coletados, hardware, software e interfaces;
5. coletores nativos no agente Go;
6. fila local e política de novas tentativas quando a plataforma estiver indisponível;
7. endpoint para envio idempotente de snapshots;
8. processamento e persistência do inventário na plataforma;
9. telas para listar agentes, status e ativos descobertos;
10. geração de tokens de enrollment pela interface administrativa ou por uma Mix task;
11. instalação do agente como serviço do sistema e criação de instaladores;
12. observabilidade, métricas, auditoria e política de atualização do agente.

Uma sequência recomendada é implementar primeiro autenticação, heartbeat e o
contrato mínimo de inventário. Depois, adicionar um coletor simples no Go e
percorrer todo o fluxo até a persistência e visualização na plataforma.

## 7. Observações de segurança

- tokens de enrollment devem ter expiração curta e uso único;
- a credencial retornada ao agente não deve aparecer em logs;
- o arquivo de estado local deve permanecer acessível somente ao usuário do serviço;
- em produção, o agente deve aceitar apenas HTTPS com certificado válido;
- a API de inventário deve validar organização, agente ativo, tamanho do payload e versão do contrato;
- dados sensíveis da máquina devem ser definidos explicitamente antes da coleta.

Este documento não contém tokens, credenciais ou outros segredos reais.
