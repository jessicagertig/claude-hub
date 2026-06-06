# Hardening Report

Rules added to `/Users/jessica/claude-hub/CLAUDE.md` under "Known Failure Patterns," based on actual failures from the QA Verification Harness spec, plan, and implementation reviews (both original runs and redos).

## Previously added rules (5)

These were added by the first hardening pass and remain unchanged:

1. **Stale references after amendments** -- spec rounds 2-3 stale `test_frr` and "in parallel" references
2. **Do not discard information callers need** -- impl round 1 (old) hardcoded `status_code: 200`
3. **Verify preconditions before network calls** -- spec round 1 seed/cleanup without health check
4. **Account for shared-resource conflicts in multi-agent designs** -- spec rounds 1-2 parallel agents racing on browser/database
5. **Do not embed pipeline-specific names in generic infrastructure** -- spec round 1 `test_frr` as generic name

## Newly added rules (3)

### 6. Hard rules cannot be rationalized away by plans

**Rule:** When a spec or global CLAUDE.md states a hard rule, the implementation must enforce it defensively even if another mechanism also provides it. Defense in depth is the point.

**Failures:**
- Impl review (redo) Round 1, HIGH-1: Plan rationalized omitting `env["RAILS_ENV"] = "test"` because the config's server command includes it inline. But the spec says "RAILS_ENV=test always" as a hard rule, and the analog enforces it defensively. A config author could omit it from the command string and the harness would silently start a dev-mode server.
- Plan review (old) Pass 1, Finding 2: Plan characterized `env = os.environ.copy()` without modification as "kept identical from InflowBootstrap" when the analog actually DOES modify env. The rationalization was accepted at plan review but caught at impl review.

**Frequency:** Surfaced in both plan review and impl review. The plan rationalized away the hard rule, the plan review accepted the rationalization, and the impl review caught it. The pattern -- "another layer handles it so I don't need to" -- bypasses defense-in-depth.

### 7. Verify the execution lifecycle matches before copying an analog pattern

**Rule:** When adapting code from an analog, check whether the new code has the same process lifecycle (long-lived vs. fire-and-forget, parent-stays-alive vs. parent-exits). Patterns correct for a long-lived context manager can be fatal for a CLI that spawns children and exits.

**Failures:**
- Impl review (redo) Round 3, HIGH-4: atexit handler copied from the analog (a long-lived context manager used inside `runner.py`) killed server subprocesses immediately when the `qa-harness start` CLI process exited after printing "READY." The analog stays alive for the entire pipeline run; the CLI exits after spawning.
- Impl review (redo) Round 4, HIGH-5: `subprocess.PIPE` from the same analog caused child processes to die via SIGPIPE when the parent exited. The analog reads subprocess output throughout its lifetime; the CLI never reads it.

**Frequency:** 2 HIGH findings across 2 consecutive rounds, both from the same root cause (different execution lifecycle). HIGH-4 was fixed but HIGH-5 persisted because the same lifecycle mismatch manifested through a different mechanism (SIGPIPE instead of atexit). This is the strongest pattern in the redo reviews -- the fix for one symptom did not address the underlying cause, and a second symptom appeared the next round.

### 8. Check whether target artifacts already exist before proposing creation

**Rule:** Before a plan says "create file X" or "add section Y," verify that X does not already exist and that Y is not already present. If the artifact exists, say "verify" or "update if needed," not "create" or "add."

**Failures:**
- Plan review Pass 1, HIGH-1: Plan said "Add Phase 8 section to LIFECYCLE.md" but LIFECYCLE.md already had Phase 8 defined at lines 115-128.
- Plan review Pass 1, HIGH-2: Plan put `prompts/qa-prompt.md` inside the qa-harness package at a non-standard path, but the prompt already existed at `~/claude-hub/features/qa-prompt.md` (the location the lifecycle's search mechanism expects). The implementation agent would have created a duplicate in the wrong location.

**Frequency:** 2 HIGH findings in the same pass, both "create something that already exists." The plan author did not check the filesystem before proposing creation.

## Findings NOT added (one-offs or already covered)

- **HIGH-2 (state file missing config_path):** Implementation omitted a field the plan specified. This is a one-off omission, not a generalizable pattern -- there is no rule that would prevent "forgot to include a field" beyond "read the plan."

- **Spec round 1 missing seed endpoints:** Specific to this feature's data catalog. Not a generalizable pattern.

- **Spec round 1 endpoint ordering dependencies undocumented:** Specific to seed data design. Could generalize to "document ordering dependencies for operations that have implicit prerequisites" but this is too vague to be actionable.

- **Spec round 1 unspecified team size default:** Covered by rule 4 (shared-resource conflicts). Team size only mattered because of its interaction with parallelism and resource sharing.

- **All MED findings across all rounds:** Non-blocking, and none repeated across multiple rounds in a pattern that would justify a new rule.

## Pattern analysis

The 8 rules cluster into three themes:

**Document consistency (rules 1, 8):** Keep specs, plans, and documents internally consistent. Don't leave stale references; don't propose creating things that already exist.

**Defensive implementation (rules 2, 3, 6):** Don't discard information, don't skip precondition checks, don't rationalize away hard rules. The implementation should be robust even when other layers also provide the same protection.

**Architecture awareness (rules 4, 5, 7):** Understand the execution model. Don't copy patterns across different lifecycles. Don't embed pipeline-specific concepts in generic layers. Don't share resources without explicit isolation.
