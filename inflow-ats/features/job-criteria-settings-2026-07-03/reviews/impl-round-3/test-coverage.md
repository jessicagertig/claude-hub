# Test Coverage (always-on) — Round 3

Also carries the always-on check **Test coverage** from REVIEW-ANGLES §4 (folded here, as in rounds 1-2).

## Independent suite run against COMMITTED code

Clean worktree at HEAD `68e5e6a4e`. Ran the same 12 files as round 2 (the 11 diff spec files + develop's `create_bulk_ai_summary_generation_spec.rb`):

**140 examples, 9 failures — the failure set is IDENTICAL to round 2's list**: `bulk_generate_ai_summaries_job_spec.rb` example lines :158, :195, :220, :244, :284, :308, :336, :354, :380, all `NoMethodError: undefined method 'on_complete'`. Count and lines match round 2 exactly → confirmed the pre-existing out-of-scope set, unchanged. Every feature example, develop-rescore example, and merge-reconciled example passes.

## Load-bearing cases re-audited for ghosts (rule 26)

- Six serializer/controller payload states: real HTTP responses parsed and asserted per field, including the nil-vs-false split. Behavioral.
- `zero_criteria_failure?` truth table: 3 messages × failed = true; 3 messages × 4 non-failed statuses = false; blank-description / parse-failure / nil messages = false. Real records, real predicate calls. Falsifiable: deleting the predicate's message check flips assertions.
- Broadcast specs: `GlobalChannel.broadcast_to` expected with action + payload contents, driven by `perform_now` with real DB writes inside the stubbed service; retry path asserts `have_enqueued_job` AND no broadcast; nil-requester asserts no broadcast on success and failure. No reflection-only assertions, no assigned-but-unasserted variables.
- No-pending-guard documentation test present ("creates a row anyway, documenting the deliberate absence of a pending guard").
- Claim-row test rewritten from stays-`:processing` to `:failed`; zero-criteria batch test asserts row status + `AI_SUMMARY_BULK_FAILED` broadcast + failed mailer `deliver_later` on a mailer `instance_double` (pipeline rule 4 shape).
- Funnel-guard test asserts `extract_job_criteria_if_needed` NOT received and `Orchestrate` NOT instantiated — the ordering claim, tested behaviorally.
- Guard specs cover all three messages, the non-zero failure message, pending, and in-flight-over-zero (predicate-reads-latest semantics) in BOTH validators; queue interactor covers fail-fast + job-less compatibility.

Frontend tests: none — the DOCUMENTED SPEC §12 decision (no infra); no half-added harness in the diff.

## Findings

- F1 [LOW — carryover from rounds 1-2, unchanged] spec/jobs/extract_job_criteria_job_spec.rb / the `retry_on` exhaustion-block broadcast site still has no direct test / matches the adjudicated SPEC §12 / plan test scope; residual plan gap, not an implementation omission.

No MED+ findings.
