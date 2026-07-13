# Plan: Agent API v1 Enrollment

## Delivery Strategy

Implement one small vertical behavior at a time with strict
RED-GREEN-REFACTOR. Every Elixir production behavior starts with one focused
ExUnit test that is executed and observed failing for the intended reason.

The first deliverable ends when the enrollment endpoint is secure and tested.
Heartbeat and inventory remain contract-only.

## Dependency Flow

```text
schema/migration
      |
      v
secret primitives -> token creation
      |                  |
      +--------+---------+
               v
        valid enrollment
               |
       +-------+--------+
       v                v
 invalid states     re-enrollment
       |                |
       +-------+--------+
               v
          concurrency
               |
               v
       controller + JSON
               |
               v
         log redaction
               |
               v
          full suite
```

## Slice 1: Schemas and Migration

Add `agents` and `agent_enrollment_tokens` with UUID keys, organization foreign
keys, timestamp types, protected fields, and database indexes. Start with schema
changeset tests for allowed fields, validation, and tenant-owned protected
fields. Apply the migration only after observing the focused test fail because
the schemas/tables do not exist.

Checkpoint:

```sh
mix test test/plataforma/agents/agent_test.exs
```

## Slice 2: Secret Generation and Digests

Introduce private or narrowly scoped primitives for cryptographically secure,
URL-safe secrets, SHA-256 digests, and credential formatting. Tests prove
randomness shape, digest determinism, absence of plaintext persistence, and
constant-time verification behavior.

Checkpoint:

```sh
mix test test/plataforma/agents/secret_test.exs
```

## Slice 3: Enrollment Token Creation

Add a context function that accepts a trusted organization and lifetime,
creates an expiring token record, and returns plaintext once. The default
lifetime is 15 minutes. Tests cover ownership, expiration, digest storage, and
invalid lifetime values. No public controller is added for token creation.

Checkpoint:

```sh
mix test test/plataforma/agents_test.exs --only token_creation
```

## Slice 4: Valid Enrollment of a New Agent

Add the context transaction for a valid unused token and new machine. It
validates public attributes, derives the organization from the token, creates
the agent, consumes the token, sets `enrolled_at`, and returns the one-time
credential. Tests verify atomic state and that protected client fields are
ignored.

Checkpoint:

```sh
mix test test/plataforma/agents_test.exs --only enrollment
```

## Slice 5: Invalid, Expired, and Consumed Tokens

Add indistinguishable domain errors for invalid, expired, and consumed tokens.
Tests use the same public assertion for all three states and prove that no agent
or credential is created.

Checkpoint:

```sh
mix test test/plataforma/agents_test.exs --only invalid_token
```

## Slice 6: Re-enrollment and Rotation

For an existing active `organization_id + machine_id`, update device metadata,
rotate the credential digest, advance `enrolled_at`, and preserve the agent ID
and original `inserted_at`. Reject inactive agents with `:agent_inactive`.

Checkpoint:

```sh
mix test test/plataforma/agents_test.exs --only reenrollment
```

## Slice 7: Concurrency

Serialize enrollment attempts for the organization/machine identity using a
PostgreSQL transaction-level lock and verify the observed agent version before
mutation. The first mutation wins; a stale concurrent request consumes its
token and commits a conflict result without changing the agent credential.
Retain the unique index as the final database invariant.

Use non-async tests with separate sandbox connections and controlled task
synchronization. Avoid timing-only assertions where possible.

Checkpoint:

```sh
mix test test/plataforma/agents/enrollment_concurrency_test.exs --trace
```

## Slice 8: Controller and JSON Contract

Add a stateless API pipeline and `POST /api/v1/agents/enroll`. Do not use browser
sessions or CSRF. Test the route and exact `201`, `400`, `401`, `409`, and `415`
JSON envelopes before implementing the controller, JSON view, and error mapping.

Checkpoint:

```sh
mix test test/plataforma_web/controllers/agent_enrollment_controller_test.exs
```

## Slice 9: Log Redaction

Test Phoenix parameter filtering for enrollment tokens, credentials,
authorization, generic tokens, and secrets. Add the central filter configuration
and audit new Logger calls to ensure no sensitive value is interpolated or
attached as metadata.

Checkpoint:

```sh
mix test test/plataforma_web/agent_log_redaction_test.exs
```

## Slice 10: Complete Suite and Contract Review

Run formatting, compilation with warnings as errors, all focused tests, and the
full suite. Compare the implemented request/response examples with `01-spec.md`
and update documentation first if an approved decision changed.

Checkpoint:

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

## Major Risks and Mitigations

### Secret Leakage

Mitigation: return plaintext only from creation/enrollment calls, mark schema
digest fields as redacted where supported, configure Phoenix parameter filters,
and never inspect raw request params in logs.

### Tenant Confusion

Mitigation: derive organization only from the stored enrollment token, never
cast organization IDs from request attributes, and cover cross-tenant machine
IDs in tests.

### Enrollment Races

Mitigation: transaction-level serialization, observed-version comparison,
unique indexes, explicit concurrent tests, and transactional consumption of
the losing token.

### Transaction Returning a Conflict While Committing Token Consumption

Mitigation: represent the conflict as a successful internal transaction result,
then translate it to the public domain error after commit. Do not use a rollback
tuple for this case.

### Database-specific Locking

Mitigation: isolate PostgreSQL advisory-lock code in the Agents context and
cover its observable behavior. Do not introduce a new dependency.

## Sequential and Parallel Work

Slices 1 through 7 are sequential because each depends on the preceding domain
invariants. Controller contract tests may be drafted once domain return tuples
are stable, but production controller code waits for slice 7. Log redaction may
be tested independently after the endpoint parameter names are final. Only one
RED-GREEN cycle is active at a time.

## Completion Criteria

- Every slice has recorded RED and GREEN command output during implementation.
- The API endpoint matches the approved examples and exact error messages.
- No raw secret is persisted or visible through inspected schemas/logging.
- Tenant isolation, inactive behavior, rotation, and concurrency are tested.
- `mix format --check-formatted`, `mix compile --warnings-as-errors`, and
  `mix test` pass.
