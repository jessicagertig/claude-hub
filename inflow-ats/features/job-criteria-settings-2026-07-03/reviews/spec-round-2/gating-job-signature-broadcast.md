# Round 2 — Angle 3: Gating change, job signature (flag 4), broadcast lifecycle

SPEC.md re-read in full. This angle owned 4 of Round 1's 10 amendments — all re-verified in place and correct:

1. §7 signature bullet: flag 4 RESOLVED, positional stands, deploy-compatibility rationale present and technically accurate (re-checked the mechanics: `set(wait: 30.seconds)` at job.rb:707, `retry_on ... wait: 2.minutes, attempts: 3` at extract_job_criteria_job.rb:5, ArgumentError-at-invocation bypassing method rescues and `retry_on`).
2. §14 flag 4 marked RESOLVED with pointer to the Round 1 evidence file.
3. §7 exhaustion bullet: row-presence guard mirroring analog :17-21 — matches the analog's actual code (re-read generate_ai_job_application_summary_job.rb:16-21).
4. §7 StandardError bullet: dual gate mirroring analog :45 — matches (`if textract_result && requesting_organization_user_id`).

**Stale-reference sweep for the flag-4 amendment** (hub CLAUDE.md "stale references after amendments" pattern): searched the full spec for any other kwargs/positional reference to `ExtractJobCriteriaJob`:
- §12 controller spec: "enqueues ExtractJobCriteriaJob with the row id and current_organization_user.id" — consistent with positional args ✓.
- §12 job-spec additions: "passes requesting_organization_user_id through to ExtractJobCriteriaJob args; nil default" — consistent ✓.
- §11 pattern table + §7 analog paragraph describe the ANALOG as kwarg-threaded — accurate descriptions of the analog file, not stale claims about the new job ✓.
- §4.1 replacement code enqueues `perform_later(new_ai_job_criteria.id, requesting_organization_user_id)` — positional ✓.
No stale references.

Gating change re-verified against DECISIONS verbatim + approved kwarg; guard-set asymmetry still untouched (trace note 4 adjudication stands).

## Findings

No issues found.

## Amendments Applied

None (this angle).
