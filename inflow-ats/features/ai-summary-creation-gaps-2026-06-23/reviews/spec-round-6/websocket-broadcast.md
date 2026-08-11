# websocket-broadcast contract (W4) — Round 6

Fresh-eyes deep dive into the EXISTING `ai_job_application_summary_spec.rb` broadcast tests vs the BROADCAST_STATUSES change.

## Findings
- F1 [MED] -- W4 breaks the `described_class::BROADCAST_STATUSES.each` test's "move off the target status first" helper (`ai_job_application_summary_spec.rb:43`) AND the `:57-62` block must be DELETED not inverted. Two coupled ripples:
  (1) The `.each` loop (`:37-55`) already asserts each BROADCAST_STATUS broadcasts; once W4 adds awaiting_job_criteria + retrying, the loop covers them positively -> inverting the `:57-62` "does not broadcast" block would DUPLICATE/CONTRADICT the loop. Correct edit: DELETE `:57-62`.
  (2) Line 43 (`summary.update!(status: :awaiting_job_criteria) if summary.status == broadcast_status`) relies on "awaiting_job_criteria is a non-broadcast status" (its own comment). After W4, awaiting_job_criteria broadcasts; in fact ALL TEN summary statuses are in BROADCAST_STATUSES (8 original + 2 new = the full enum), so NO non-broadcasting intermediate exists. The move-off runs at `:43` BEFORE the `allow(JobChannel).to receive(:broadcast_to)` stub (`:47`), so it would fire a real `ai_summary_status_change`. The helper must be redesigned. APPLIED.

## Re-verified correct (ripple completeness sweep)
- Exhaustive ripple sweep across spec/: the ONLY W4-affected broadcast assertions are in `ai_job_application_summary_spec.rb:37-62`. Others are unaffected: `:64,70` (unchanged-status / on-create guards, not status-specific); `generate_ai_job_application_summary_job_spec.rb:73,227` (GlobalChannel toast, not JobChannel); `get_resume_text_from_textract_job_spec.rb:53,73,83` (GlobalChannel C8, covered by Round-5 C8 amendment); `find_or_create_ai_job_application_summary_status_spec.rb:163,231` (the interactor's own broadcast, not driven by BROADCAST_STATUSES). CONFIRMED complete.
- BROADCAST_STATUSES is referenced in spec/ ONLY at `ai_job_application_summary_spec.rb:37`. CONFIRMED.

## Amendments Applied (Round 6)
- SPEC.md W4 (line 113): DELETE `:57-62` (not invert); REDESIGN the `.each` move-off helper at `:43` (no non-broadcasting status remains after W4); grep spec/ for other now-broadcasting "does not broadcast" assertions.
