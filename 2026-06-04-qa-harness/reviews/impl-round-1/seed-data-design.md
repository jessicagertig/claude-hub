# seed-data-design — Round 1 Findings

## MED-1: validate_plan does not check required params presence

**Severity:** MED

**File:** `src/qa_harness/seed.py`, lines 102-150

**Finding:** The plan (section 5, seed.py, `validate_plan`) says it "Checks: method+path exists in catalog, required params present, ordering respects 'requires' dependencies." The implementation checks method+path existence and dependency ordering, but does NOT check required params presence. The `params` field in `SeedEndpoint` is `dict[str, str]` mapping param names to type hints, but `validate_plan` never compares plan step `body` keys against the endpoint's `params`.

This is MED rather than HIGH because params validation is a convenience check (the actual endpoint will reject bad params with an HTTP error), and the plan itself notes this as a v1 scope limitation. The analog `seed_parser.py` also doesn't validate params at parse time.

---

## MED-2: cleanup() does not call check_server_alive

**Severity:** MED

**File:** `src/qa_harness/seed.py`, lines 49-57

**Finding:** The spec says "Before making any HTTP calls, `seed` and `cleanup` commands verify the server is alive" (spec section "Data seeding / Seed execution"). `execute_plan` calls `check_server_alive`, and `cmd_cleanup` in cli.py calls `check_server_alive` before calling `cleanup()`. But the `cleanup()` method itself does not call `check_server_alive`. This means if someone calls `executor.cleanup()` directly (not through the CLI), the health check is skipped.

The CLI path is correct, so agents using the CLI will get the check. But `execute_plan` also calls `cleanup()` internally (line 85), and by that point `check_server_alive` was already called at the top of `execute_plan` (line 63). So functionally this is fine for all current call paths.

---

## No HIGH or BLOCKER findings.
