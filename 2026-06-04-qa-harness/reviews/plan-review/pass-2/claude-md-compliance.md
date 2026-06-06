# CLAUDE.md Compliance — Pass 2

## Pass 1 Corrections Verification

No amendments were applied in Pass 1 for this angle. N/A.

## Fresh Scrutiny

- **Hub rule: "Never write files into source repos from a hub session."** After amendments, the plan creates files in `~/claude-hub/qa-harness/` (new package) and `~/claude-hub/inflow-ats/qa-config.yml` (pipeline config). Neither is inside a source repo (`/Users/jessica/wrk/wrk-corp/inflow-ats` or `/Users/jessica/polymer-help-pipeline`). The plan also no longer creates files in `~/claude-hub/features/` (the prompt already exists). COMPLIANT.

- **Hub rule: "Always create a subdirectory for new work."** The `qa-harness/` directory is a new subdirectory at the hub root level. The `qa-config.yml` goes at `inflow-ats/` root level, which is a pipeline directory. This is a config file, not a work item -- similar to how CLAUDE.md files live at pipeline roots. COMPLIANT.

- **Global rule: Pattern Matching.** The plan extensively maps every module to its help pipeline analog. Section 2 has two full tables. Each module in section 5 has an "Analog" section. The dependency graph, test plan, and build sequence all reference specific analog patterns. COMPLIANT.

- **Global rule: "NEVER set DATABASE_URL."** Checked the amended plan. Section 5 `server.py` explicitly says "The harness MUST NOT set `DATABASE_URL` per global hard rules." No other section introduces env var manipulation. COMPLIANT.

- **Global rule: "NEVER modify .env files."** The plan says "No env loading (`apply_env`) -- the harness does not read `.env` files." The spec constraint says "The harness must never modify `.env` files." COMPLIANT.

- **Global rule: "Cypress cleanup endpoint MUST be called as a direct HTTP request."** The plan's `SeedExecutor.cleanup()` uses `requests.Session` to make HTTP calls to the running Rails server. Not via Rake, not via rails runner. COMPLIANT.

- **Hub Known Failure Pattern: "Stale references after amendments."** The Pass 1 amendments updated 6 locations in the plan (sections 3, 4, 8, 10, 12, and the LOC table). I verified no stale references to `prompts/qa-prompt.md` or "add Phase 8" remain. COMPLIANT.

- **Hub Known Failure Pattern: "Do not discard information callers need."** The plan's `_execute_step` returns `{endpoint, status_code, response_body}` -- it preserves status codes and response data. This was a known failure pattern from the impl review. COMPLIANT.

- **Hub Known Failure Pattern: "Verify preconditions before network calls."** The plan's seed/cleanup operations verify server alive before making HTTP calls. This was a known failure pattern from the spec review. COMPLIANT.

- **Hub Known Failure Pattern: "Account for shared-resource conflicts."** The plan explicitly states sequential execution of agents within a round to avoid database conflicts. COMPLIANT.

- **Hub Known Failure Pattern: "Do not embed pipeline-specific names."** The plan uses `script_runner` (not `test_frr`), `supporting_commands` (not `sidekiq_command`), and `cleanup_endpoint` (not hardcoded `/cypress/cleanup`). COMPLIANT.

## Findings

No compliance violations found.

## Amendments Applied

None needed.
