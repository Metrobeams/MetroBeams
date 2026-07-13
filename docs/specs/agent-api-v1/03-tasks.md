# Tasks: Agent API v1 Enrollment

Each implementation task follows RED-GREEN-REFACTOR. The focused test listed in
`Verify` must be run once before production changes and observed failing for the
expected missing behavior, then run again after the minimum implementation.

## 1. Schemas and Migration

- [x] Test and add the agent enrollment-token schema.
  - Acceptance: protected token digest and tenant ownership are not cast from
    public attributes; expiration is required; digest fields are redacted.
  - Verify: `mix test test/plataforma/agents/enrollment_token_test.exs`
  - Files: `test/plataforma/agents/enrollment_token_test.exs`,
    `lib/plataforma/agents/enrollment_token.ex`.

- [x] Test and add the agent schema.
  - Acceptance: device fields follow the approved validation rules; tenant,
    digest, active state, and server timestamps cannot be set through the public
    changeset; digest fields are redacted.
  - Verify: `mix test test/plataforma/agents/agent_test.exs`
  - Files: `test/plataforma/agents/agent_test.exs`,
    `lib/plataforma/agents/agent.ex`.

- [x] Add and verify the database migration.
  - Acceptance: both tables, foreign keys, unique indexes, timestamps, required
    fields, and the active default match the approved specification.
  - Verify: `MIX_ENV=test mix ecto.reset` followed by both schema test files.
  - Files: one new migration under `priv/repo/migrations/`.

## 2. Secret Generation and Digests

- [x] Test and implement secret primitives.
  - Acceptance: secrets are cryptographically random and URL-safe; SHA-256 is
    deterministic; verification uses constant-time comparison; credentials use
    `<agent-id>.<secret>` without persisting plaintext.
  - Verify: `mix test test/plataforma/agents/secret_test.exs`
  - Files: `test/plataforma/agents/secret_test.exs`,
    `lib/plataforma/agents/secret.ex`.

## 3. Enrollment Token Creation

- [x] Test and implement enrollment-token creation in the Agents context.
  - Acceptance: trusted organization ownership is persisted; default lifetime
    is 15 minutes; only the digest is stored; plaintext is returned once;
    invalid lifetimes return an error.
  - Verify: `mix test test/plataforma/agents_test.exs --only token_creation`
  - Files: `test/plataforma/agents_test.exs`, `lib/plataforma/agents.ex`,
    `lib/plataforma/agents/enrollment_token.ex`.

- [x] Keep setup on the public context without a secret-bypassing fixture.
  - Acceptance: tests create organizations, enrollment tokens, and agents
    through public context functions without exposing production-only secret
    internals. A dedicated fixture is omitted because it would add no reuse and
    could encourage bypassing the one-time plaintext boundary.
  - Verify: rerun the token-creation and enrollment tests.
  - Files: no additional fixture file required.

## 4. Valid Enrollment of a New Agent

- [x] Test a valid new-agent enrollment transaction.
  - Acceptance: organization comes from the token; agent and consumption time
    commit atomically; `enrolled_at` is set; plaintext credential is returned
    once; protected request fields are ignored.
  - Verify: `mix test test/plataforma/agents_test.exs --only enrollment`
  - Files: `test/plataforma/agents_test.exs`, `lib/plataforma/agents.ex`,
    `lib/plataforma/agents/agent.ex`.

- [x] Test rollback on invalid device attributes.
  - Acceptance: invalid attributes return a changeset while the token remains
    unused and no agent is persisted.
  - Verify: `mix test test/plataforma/agents_test.exs --only enrollment_validation`
  - Files: `test/plataforma/agents_test.exs`, `lib/plataforma/agents.ex`.

## 5. Invalid, Expired, and Consumed Tokens

- [x] Test indistinguishable invalid token states.
  - Acceptance: unknown, expired, and consumed plaintext tokens all return
    `{:error, :invalid_enrollment_token}` and produce no agent or credential.
  - Verify: `mix test test/plataforma/agents_test.exs --only invalid_token`
  - Files: `test/plataforma/agents_test.exs`, `lib/plataforma/agents.ex`.

## 6. Re-enrollment and Rotation

- [x] Test active-agent re-enrollment.
  - Acceptance: a fresh token preserves agent ID and `inserted_at`, updates
    device metadata, rotates the digest, and advances `enrolled_at`.
  - Verify: `mix test test/plataforma/agents_test.exs --only reenrollment`
  - Files: `test/plataforma/agents_test.exs`, `lib/plataforma/agents.ex`,
    `lib/plataforma/agents/agent.ex`.

- [x] Test inactive-agent rejection.
  - Acceptance: enrollment returns `{:error, :agent_inactive}`, consumes no
    credential rotation, and does not reactivate or update the agent.
  - Verify: `mix test test/plataforma/agents_test.exs --only inactive_agent`
  - Files: `test/plataforma/agents_test.exs`, `lib/plataforma/agents.ex`.

## 7. Concurrency

- [x] Test and implement per-machine transaction serialization.
  - Acceptance: concurrent first enrollments cannot duplicate the agent; one
    wins and the stale request returns a committed conflict result.
  - Verify:
    `mix test test/plataforma/agents/enrollment_concurrency_test.exs --trace`
  - Files: `test/plataforma/agents/enrollment_concurrency_test.exs`,
    `lib/plataforma/agents.ex`.

- [x] Test concurrent credential rotation.
  - Acceptance: only one re-enrollment changes the credential; the stale token
    is consumed; the winning credential remains valid.
  - Verify:
    `mix test test/plataforma/agents/enrollment_concurrency_test.exs --trace`
  - Files: `test/plataforma/agents/enrollment_concurrency_test.exs`,
    `lib/plataforma/agents.ex`, `lib/plataforma/agents/secret.ex`.

## 8. Controller and JSON Contract

- [x] Test and add the stateless agent API route.
  - Acceptance: `POST /api/v1/agents/enroll` reaches the enrollment controller
    without browser session or CSRF requirements; unsupported methods are not
    routed.
  - Verify:
    `mix test test/plataforma_web/controllers/agent_enrollment_controller_test.exs --only routing`
  - Files: `test/plataforma_web/controllers/agent_enrollment_controller_test.exs`,
    `lib/plataforma_web/router.ex`.

- [x] Test and implement the successful JSON response.
  - Acceptance: valid enrollment returns exactly `201` with `data.agent_id` and
    `data.credential`, and does not return a digest or organization selected by
    the client.
  - Verify:
    `mix test test/plataforma_web/controllers/agent_enrollment_controller_test.exs --only success`
  - Files: `test/plataforma_web/controllers/agent_enrollment_controller_test.exs`,
    `lib/plataforma_web/controllers/agent_enrollment_controller.ex`,
    `lib/plataforma_web/controllers/agent_enrollment_json.ex`.

- [x] Test and implement exact domain and validation errors.
  - Acceptance: `400`, `401`, and both `409` responses match the approved
    `code`, `message`, and optional `details` envelopes.
  - Verify:
    `mix test test/plataforma_web/controllers/agent_enrollment_controller_test.exs --only errors`
  - Files: `test/plataforma_web/controllers/agent_enrollment_controller_test.exs`,
    `lib/plataforma_web/controllers/agent_enrollment_controller.ex`,
    `lib/plataforma_web/controllers/agent_enrollment_json.ex`.

- [x] Test and implement JSON content-type enforcement.
  - Acceptance: non-JSON requests return exactly `415` with
    `unsupported_media_type`.
  - Verify:
    `mix test test/plataforma_web/controllers/agent_enrollment_controller_test.exs --only content_type`
  - Files: `test/plataforma_web/controllers/agent_enrollment_controller_test.exs`,
    `lib/plataforma_web/plugs/require_json_content_type.ex`,
    `lib/plataforma_web/router.ex`.

## 9. Log Redaction

- [x] Test and configure sensitive parameter filtering.
  - Acceptance: `enrollment_token`, `credential`, `authorization`, `secret`,
    and generic `token` values are replaced by `[FILTERED]` through Phoenix's
    central parameter filter.
  - Verify: `mix test test/plataforma_web/agent_log_redaction_test.exs`
  - Files: `test/plataforma_web/agent_log_redaction_test.exs`,
    `config/config.exs`.

- [x] Audit endpoint logging for raw secrets.
  - Acceptance: no new Logger call contains raw params, request bodies,
    credentials, enrollment tokens, or authorization values.
  - Verify: targeted `rg` audit plus the controller and redaction test files.
  - Files: no production change expected unless the audit finds a violation.

## 10. Complete Suite

- [x] Format, compile, migrate, and run all tests.
  - Acceptance: formatter reports no diff; compilation has no warnings; test
    database migrates from scratch; focused enrollment tests and the complete
    suite pass.
  - Verify:
    `mix format --check-formatted`, `mix compile --warnings-as-errors`,
    `MIX_ENV=test mix ecto.reset`, and `mix test`.
  - Files: only formatting corrections or approved spec synchronization.

- [x] Review implementation against the approved API examples.
  - Acceptance: request fields, exact response envelopes, statuses, security
    boundaries, and documented deferred scope match `01-spec.md`.
  - Verify: manual contract checklist recorded in the implementation handoff.
  - Files: `docs/specs/agent-api-v1/01-spec.md` only if an approved decision
    changed during implementation.
