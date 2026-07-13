# Implementation Log: Agent API v1 Enrollment

Implemented on 2026-07-13 with strict RED-GREEN cycles.

## RED checkpoints observed

- Missing `EnrollmentToken` and `Agent` schemas caused compile failures.
- Missing tables caused PostgreSQL `undefined_table`.
- Missing `Secret` functions caused `UndefinedFunctionError`.
- Missing token creation and enrollment functions caused focused context failures.
- Expired tokens enrolled before state checks were restored.
- Re-enrollment hit the organization/machine unique constraint before rotation.
- Concurrent creation and rotation both returned success before version checks.
- Missing route/controller and missing error clauses failed HTTP tests.
- Non-JSON content returned `201` before content-type enforcement.
- Sensitive values were visible before Phoenix parameter filtering.
- Normalized re-enrollment returned conflict before lookup normalization.
- HTTP conflict returned `400` before the exact `409` mapping was restored.
- Malformed JSON returned Phoenix's default error before the stable envelope.

## GREEN checkpoints

- Schema tests: 7 passed after migration.
- Secret tests: 3 passed.
- Token creation: 2 passed.
- Enrollment state, validation, and re-enrollment focused tests passed.
- Concurrency tests: 2 passed.
- Controller tests include success, validation, token, inactive, conflict,
  content-type, routing, and malformed JSON.
- Agent API focused suite: 19 passed before the last two HTTP edge tests.
- Clean test database migration completed through
  `20260713200000_create_agents_and_enrollment_tokens`.
- Final complete suite: 358 passed, 0 failed.
- `mix format --check-formatted`, `mix compile --warnings-as-errors`, and
  `git diff --check` completed successfully.

Two warnings printed by the final test run are preexisting unused variables in
the asset-category and user-session controller tests; Agent API compilation has
no warnings.
