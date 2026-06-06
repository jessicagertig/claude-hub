# Seed Data Design — Round 1 Findings

## Angle: seed-data-design

### Finding 1: `_execute_step` hardcodes status_code 200 (HIGH)

(Cross-referenced from server-lifecycle finding 1 — same root cause, different impact surface.)

Seed plan execution results always report status code 200. This means agents cannot distinguish between a seed endpoint that returned 200 (success with body) and one that returned 201 (created) or 204 (no content). The `_request` method swallows the response object and returns only the parsed body.

This matters because QA agents rely on seed step output to verify data setup before testing. Misleading status codes undermine the seed execution evidence chain.

### Finding 2: `validate_plan` does not check for required params (MED)

The plan from the spec (Section 5, `seed.py`) lists `validate_plan` as checking: "method+path exists in catalog, required params present, ordering respects 'requires' dependencies."

The implementation checks method+path existence and dependency ordering, but does NOT check whether required params are present. The `SeedEndpoint.params` field describes what params an endpoint accepts, but `validate_plan` never inspects `step.get("body")` to verify the expected params are included.

This is MED because the Cypress endpoints generally work with defaults if params are missing (they have server-side defaults), so missing params rarely cause failures. But it deviates from the plan.

### Finding 3: Seed plan validation is solid for dependency ordering (PASS NOTE)

The `validate_plan` method correctly tracks `called_paths` and checks `requires` dependencies against previously-called paths. The placeholder matching logic (`_find_placeholder_match`) handles parameterized paths like `/cypress/invites/{email_base64}`. Tests cover the key scenarios including violation and satisfaction of dependencies. This matches the spec requirements well.

### Finding 4: Cleanup-before-seed is correctly automatic (PASS NOTE)

`execute_plan` calls `self.cleanup()` before executing any seed steps, matching the spec requirement that cleanup always precedes seeding. The test `test_calls_cleanup_before_seeding` verifies this ordering.
