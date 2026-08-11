# Round 3 — Angle 4: API surface

SPEC.md re-read at round start. Round 2's §5.2 citation amendment verified in place (`useBulkMessage.ts:23` — correct job-nested path form). Route/controller/serializer/authorization content stable since Round 1 verification.

Fresh checks this round (previously unverified component/infrastructure claims the controller relies on):
- `Pundit` included in `ApplicationController` (application_controller.rb:6) with `rescue_from Pundit::NotAuthorizedError` (:10) — `authorize job, :show?` / `authorize job, :update_ai_settings?` are valid and failures render through the existing handler ✓.
- Payload-table/§12/§8.2 triple cross-check re-run on the final text: consistent (no "null/false" residue).

## Findings

No issues found.

## Amendments Applied

None.
