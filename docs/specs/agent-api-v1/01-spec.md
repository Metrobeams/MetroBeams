# Spec: Agent API v1 and Enrollment

## Objective

Define the versioned HTTPS/JSON contract between the native Go agent and the
Phoenix application. The first implementation slice enrolls an agent into an
organization with a short-lived installation token and returns a per-agent
credential exactly once.

The users are organization administrators deploying the agent and managed
machines running it. Success means a valid token can enroll a Windows machine
without exposing tenant selection or storing plaintext secrets.

This first slice does not implement inventory persistence, heartbeat handling,
agent authentication middleware, an enrollment-token UI, installers, or remote
commands.

## Assumptions

- Windows is the first supported collection platform; the API remains portable.
- PostgreSQL is the source of truth and organization IDs remain UUIDs.
- An enrollment token is created for a known organization by an authorized
  server-side caller; the agent never submits an `organization_id`.
- API transport is JSON over HTTPS. TLS termination may happen before Phoenix.
- No new dependency is required; cryptographic random bytes, SHA-256, and secure
  comparison use Erlang/Elixir and Plug facilities already present.

## Tech Stack

- Elixir 1.15+ and Phoenix 1.8
- Ecto and PostgreSQL
- ExUnit and Phoenix.ConnTest
- Go agent consuming the contract, implemented in a later slice

## Commands

```sh
mix test test/plataforma/agents_test.exs
mix test test/plataforma_web/controllers/agent_enrollment_controller_test.exs
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```

## API Contract

All agent endpoints are below `/api/v1`. JSON errors use a stable machine
readable code and a human-readable message.

### Enroll an agent

```http
POST /api/v1/agents/enroll
Content-Type: application/json
```

```json
{
  "enrollment_token": "opaque-url-safe-token",
  "machine_id": "stable-os-machine-identifier",
  "hostname": "PC-FINANCE-01",
  "platform": "windows",
  "architecture": "amd64",
  "agent_version": "0.1.0"
}
```

Successful response:

```http
HTTP/1.1 201 Created
```

```json
{
  "data": {
    "agent_id": "01900000-0000-7000-8000-000000000000",
    "credential": "<agent-id>.<opaque-secret>"
  }
}
```

The credential is shown once. Phoenix stores only a SHA-256 digest of the
secret. A fresh token enrolling the same `organization_id + machine_id` reuses
an active agent record and rotates its credential. An inactive agent is never
reactivated implicitly by enrollment.

Errors:

- `400 invalid_request`: malformed JSON or missing, invalid, or oversized
  device attributes.
- `401 invalid_enrollment_token`: token is invalid, expired, or already used.
- `409 agent_inactive`: the matching machine belongs to an inactive agent.
- `409 enrollment_conflict`: another enrollment changed the same agent after
  this request observed it.
- `415 unsupported_media_type`: request is not JSON.

Invalid, expired, and used tokens intentionally share the same public response.
Consuming the token and inserting/updating the agent happen in one database
transaction. If the client loses the successful response, an administrator
must issue a new token.

Exact public error envelopes are:

```json
{
  "error": {
    "code": "invalid_enrollment_token",
    "message": "Enrollment token is invalid"
  }
}
```

Validation errors add a `details` object keyed by the public request field:

```json
{
  "error": {
    "code": "invalid_request",
    "message": "Request validation failed",
    "details": {
      "hostname": ["can't be blank"]
    }
  }
}
```

The other exact code/message pairs are:

- `agent_inactive` / `Agent is inactive`
- `enrollment_conflict` / `Agent enrollment conflicted with another request`
- `unsupported_media_type` / `Content-Type must be application/json`

### Heartbeat (contract only in this slice)

```http
POST /api/v1/agents/heartbeat
Authorization: Bearer <agent-id>.<opaque-secret>
Content-Type: application/json
```

```json
{
  "schema_version": 1,
  "sent_at": "2026-07-13T15:30:00Z",
  "agent_version": "0.1.0"
}
```

Success is `204 No Content`.

### Submit inventory (contract only in this slice)

```http
POST /api/v1/agents/inventory
Authorization: Bearer <agent-id>.<opaque-secret>
Idempotency-Key: <uuid>
Content-Type: application/json
```

```json
{
  "schema_version": 1,
  "collected_at": "2026-07-13T15:30:00Z",
  "device": {
    "hostname": "PC-FINANCE-01",
    "machine_id": "stable-os-machine-identifier",
    "platform": "windows",
    "os_version": "11 Pro",
    "architecture": "amd64",
    "manufacturer": "Dell",
    "model": "Latitude 5440",
    "serial_number": "ABC123"
  },
  "hardware": {
    "cpu": "Intel Core i7",
    "memory_bytes": 17179869184,
    "disks": []
  },
  "network_interfaces": [],
  "installed_software": []
}
```

Success is `202 Accepted`; repeated idempotency keys for the same agent return
the original acceptance without creating another snapshot.

## Data Model for the First Slice

### `agent_enrollment_tokens`

- UUID primary key
- required organization UUID foreign key with restricted deletion
- required `token_digest` binary, unique; plaintext is never persisted
- required UTC expiration timestamp
- nullable UTC consumption timestamp
- timestamps in UTC with microseconds

### `agents`

- UUID primary key
- required organization UUID foreign key with restricted deletion
- required stable `machine_id`, unique within the organization
- required hostname, platform, architecture, and agent version
- required `credential_digest` binary; plaintext is never persisted
- required active flag, defaulting to true
- required `enrolled_at` UTC timestamp, meaning the latest successful enrollment
- nullable `last_seen_at` UTC timestamp
- timestamps in UTC with microseconds

Client input cannot set organization, credential digest, active state, or
server-maintained timestamps.

`inserted_at` records when the agent was first created. `enrolled_at` advances
on every successful re-enrollment and credential rotation.

## Concurrency Semantics

Enrollments for one `organization_id + machine_id` are serialized in the
database. Each request observes the current agent version before attempting its
transaction. The first transaction that creates or rotates the agent wins. A
request that later detects a changed version:

- receives `409 enrollment_conflict`;
- consumes its enrollment token;
- does not rotate the credential or update `enrolled_at`;
- must obtain a new token before retrying.

This applies both to concurrent creation with two tokens and concurrent
re-enrollment. A unique database constraint remains the final invariant.

## Log Redaction

Phoenix parameter filtering must redact keys containing `enrollment_token`,
`credential`, `authorization`, `secret`, and `token`. Production code must not
place raw request bodies, bearer values, plaintext secrets, or their inspected
containers in Logger messages or metadata. Logs may include request ID, agent
ID, organization ID, result code, and non-sensitive timing information.

## Validation

- `machine_id`: trimmed, 1 to 255 bytes.
- `hostname`: trimmed, 1 to 255 bytes.
- `platform`: one of `windows`, `linux`, or `darwin`.
- `architecture`: one of `amd64`, `arm64`, or `386` for v1.
- `agent_version`: trimmed semantic version in `MAJOR.MINOR.PATCH` form, maximum
  64 bytes.
- Unknown JSON keys are ignored, but protected fields are never cast.
- Request bodies remain subject to the existing Phoenix body-size limit.

## Project Structure

```text
docs/specs/agent-api-v1/                 Living API specification and plan
lib/plataforma/agents.ex                 Domain context
lib/plataforma/agents/                   Agent and enrollment-token schemas
lib/plataforma_web/controllers/          Enrollment controller and JSON view
priv/repo/migrations/                    Agent tables and indexes
test/plataforma/                         Context and schema tests
test/plataforma_web/controllers/         HTTP contract tests
test/support/fixtures/                   Agent test fixtures
```

## Code Style

Use explicit return tuples at the domain boundary and pattern matching in the
controller. Do not expose Ecto changesets or token-state details in API errors.

```elixir
case Agents.enroll_agent(params) do
  {:ok, %{agent: agent, credential: credential}} ->
    conn
    |> put_status(:created)
    |> render(:show, agent: agent, credential: credential)

  {:error, :invalid_enrollment_token} ->
    render_error(conn, :unauthorized, "invalid_enrollment_token")
end
```

## Testing Strategy

- Follow strict RED-GREEN-REFACTOR for every Elixir production behavior.
- Context tests cover token hashing, expiration, one-time use, tenant isolation,
  credential rotation, validation, and transaction rollback.
- Controller tests cover the JSON contract and public status/error mapping.
- Concurrency tests cover one-time token consumption and machine uniqueness.
- Run the focused failing test before implementation, then the focused passing
  test, and finally the complete suite.

## Boundaries

- Always: scope agents through the token's organization, store only secret
  digests, compare secrets in constant time, validate input, and run all tests.
- Ask first: change these two database schemas after approval, add a dependency,
  change the API response contract, or expand the first slice beyond enrollment.
- Never: accept `organization_id` from an agent, log raw tokens or credentials,
  return secrets after enrollment, execute server-provided commands, disable a
  failing test, or weaken tenant isolation.

## Success Criteria

- The API contract for enrollment, heartbeat, and inventory is documented and
  versioned.
- A server-side function creates a time-limited enrollment token and returns its
  plaintext exactly once while storing only its digest.
- `POST /api/v1/agents/enroll` returns `201` and a one-time credential for a
  valid token and device payload.
- The endpoint never accepts tenant identity from the request body.
- Invalid, expired, and consumed tokens return the same `401` response.
- Enrollment consumes the token and persists/updates the agent atomically.
- A new token for the same machine rotates the credential without duplicating
  the agent.
- Focused tests and the full Elixir suite pass with no compilation warnings.

## Open Questions

- How administrators will generate and deliver enrollment tokens (UI, CLI, or
  deployment integration) is intentionally deferred.
- The production token lifetime will be configurable; the initial default is
  proposed as 15 minutes.
- Software-inventory privacy rules and retention policy must be decided before
  inventory persistence is implemented.
