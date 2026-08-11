# Round 3 — Angle 3: Gating change, job signature (flag 4), broadcast lifecycle

SPEC.md re-read at round start. §4.1 and §7 stable since the Round 1 amendments (verified in place during Round 2 with a whole-document stale-reference sweep — no kwargs/positional contradictions anywhere). Flag 4 ruling stands: optional positional, deploy-compatibility grounds, evidence in spec-round-1/gating-job-signature-broadcast.md. Round 2 amendments do not intersect this angle.

Fresh check this round: `have_enqueued_job` retry-path test pattern in the spec plan matches the EXISTING spec's proven pattern (`expect { described_class.perform_now(id) }.to have_enqueued_job(described_class)`, extract_job_criteria_job_spec.rb:49-50) — `retry_on` is `rescue_from`-based and fires under `perform_now`, so the planned CustomErrorAiSummary test is behaviorally sound (rule 26).

## Findings

No issues found.

## Amendments Applied

None.
