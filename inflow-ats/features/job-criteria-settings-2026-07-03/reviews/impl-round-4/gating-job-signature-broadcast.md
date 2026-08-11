# Gating, Job Signature, Broadcast Lifecycle — Round 4

Round scope: fix commit 9ed954142, fix 1 (fresh-read broadcast lookup) lands squarely in this angle. Full adversarial re-read of `app/jobs/extract_job_criteria_job.rb`; gating (`job.rb`) untouched by the commit (verified via `git show --stat`) — rounds 2-3 findings stand.

## Fix 1 verification

Report text: replace `ai_job_criteria.reload` in `broadcast_completion` with a fresh read per backend/_base.md §8; compliant pattern `ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria.id)` then `return unless ai_job_criteria` before the terminal-status guard; behavior identical; update the broadcast test only if it stubs/depends on reload.

Shipped (extract_job_criteria_job.rb:46-47):
```ruby
ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria.id)
return unless ai_job_criteria
```
- Placement verified: after the `user` guard, BEFORE `return unless ai_job_criteria.status_succeeded? || ai_job_criteria.status_failed?` — exact report placement, and the analog's guard-ladder order (find user → refresh record → terminal check) is preserved.
- backend/_base.md §8 compliance confirmed: no `reload` remains anywhere in `app/` for this feature (`grep reload app/jobs/extract_job_criteria_job.rb` → zero). The §8 "fix the data flow" prescription is satisfied via re-fetch; the spec-file `reload` calls (extract_job_criteria_job_spec.rb:66, :134) are the §8-permitted spec exception and were correctly NOT churned.
- Broadcast-test conditional correctly a no-op: the spec never stubs `reload`; its assertions are behavioral (GlobalChannel.broadcast_to expectations + `ai_job_criteria.reload.status` DB-state checks in spec files). All extract_job_criteria_job_spec.rb examples green post-fix (runs 3-5).

## All three broadcast sites re-traced against the fresh read

1. **End of perform** (:23): `ai_job_criteria` found at method top, non-nil; ExtractCriteria mutates the row through its own instance via `update_columns`; the fresh read now observes the terminal write exactly as `reload` did. Identical broadcast decisions.
2. **retry_on exhaustion block** (:8-13): block re-finds the row (`AiJobCriteria.find_by(id: job.arguments.first)`), guards `if ai_job_criteria`, writes failed via `update_columns`, then calls the helper — helper's fresh read re-observes `failed`. Broadcast fires. SPEC :293's nil-row note honored: a nil row cannot reach the helper from this site.
3. **StandardError rescue** (:32-35): re-find, `&.update_columns` failed write, helper gated `if ai_job_criteria && requesting_organization_user_id`. Fresh read observes `failed`. Broadcast fires.

Behavioral delta hunted: the ONLY divergence from `reload` is the deleted-row case — `reload` raises `ActiveRecord::RecordNotFound`, the fresh read returns nil → bare return, no broadcast. Strictly safer (no spurious exception from the exhaustion handler); SPEC §7 amendment documents exactly this form. Not a regression: no production path destroys an `AiJobCriteria` row between the failure write and the broadcast.

## Non-reach check

Commit did not touch `app/models/job.rb`, the signature (`perform(ai_job_criteria_id, requesting_organization_user_id = nil)` — flag 4, standing), the payload shape, or the enqueue sites. Gating/guard-set asymmetry unchanged.

## Findings

No issues found.
