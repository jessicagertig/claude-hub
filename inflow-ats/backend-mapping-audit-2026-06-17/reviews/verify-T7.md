# Verify T7 — External Resume URL Lazy Attachment

Verdict: CLEAN

## Files checked
- OLD: backend-flow-map-2026-06-17.md (lines 108-134, 413-430, 733, 757, 848)
- NEW: backend-flow-map-2026-06-22-neutral.md (lines 241-280, 568, 598-599, 628, 636, 653-656)

## CHECK 1 — Fact preservation

All load-bearing T7 facts confirmed present in NEW:

- Job namespace `JobApplication::AttachExternalResumeUrlJob` (`attach_external_resume_url_job.rb:3`), namespaced controller enqueue (`job_applications_controller.rb:58`) — NEW 254, 256.
- Job signature `perform(job_application_id:, organization_user_id:)` (`:6`); `OrganizationUser.find(organization_user_id)` (`:7`) → `@organization_user.user` (`:11`); controller supplies `current_organization_user.id` — NEW 256, 258.
- `attach_external_resume_url` at `job_application.rb:641-657`; `should_attach_external_resume_url?` at `709-711` (`external_resume_status_pending? && !has_resume`); enum `{pending:0,uploaded:1,error:2} _prefix:true` at `:94-98` — NEW 254.
- `:uploaded` path: `content_type == 'application/pdf'` → `resume.attach(io:..., filename: 'resume.pdf')` + `update_column(:external_resume_status, :uploaded)` (`:647-649`) — NEW 261.
- `:error` outcomes (non-PDF, or rescued StandardError) via `update_column(:external_resume_status, :error)` (`:651`/`:654`) — NEW 262.
- `update_column` bypasses callbacks — NEW 263, 267.
- Broadcast `attachExternalResumeComplete`; frontend invalidates only `jobApplication` query (`attach_external_resume_url_job.rb:11-12`, `WebsocketGlobalChannelHandler.tsx:152-154`) — NEW 265.
- Textract not triggered after attach; create-only `enqueue_new_job_application` at `:45,:168` fired at insert before resume existed — NEW 267.
- 6 app + 2 rake SubmitResumeToTextractJob sites: `job_application.rb:168`, `validate_ai_summary_generation.rb:39`, `validate_ai_summary_generation.rb:55`, `queue_bulk_ai_summary_jobs.rb:29`, `job_applications_controller.rb:114`, `get_resume_text_from_textract.rb:15`, rake `:409`/`:445` — NEW 271-278; summary 656 notes prior map omitted `:55` and both rake sites.
- Most-direct re-entry: `validate_ai_summary_generation.rb:38-39` gated by `has_resume?` at `:27`; `:55` needs failed latest with non-failed/absent prior — NEW 280.
- Resting `:uploaded` (has_resume true, no longer pending, later show won't re-enqueue, `:710`) — NEW 267.
- Resting `:error` no-retry — NEW 267.
- Job rescue StandardError only `ap`s (`:13-16`), no `retry_on`, ApplicationJob empty; raise before model rescue → no retry, no broadcast, frontend not invalidated — NEW 269.
- `should_attach_external_resume_url?` checked twice (enqueue `:59`, inside method `:642`); stale enqueue has no effect — NEW 258.
- Unresolved `params[:id]` forwarding: record found via `id_or_hash_id(params[:id])` (`:56`) but enqueue forwards raw `params[:id]`; job `JobApplication.find(job_application_id)` (`:8`) resolves by PK only; hash_id → `ActiveRecord::RecordNotFound`, caught by `rescue StandardError` (`:13`), attach does not run — NEW 256.

No DROPPED facts. No ALTERED facts (all line numbers and conditions match). The OLD "old map said 626-642" correction note is a prior-pass artifact; the corrected value `641-657` is preserved, and NEW summary 655 retains the "prior map only documented :uploaded" correction. Editorial outcome labels ("perpetual pending UI", "silently never runs") were reworded to neutral factual statements ("the attach does not run", "the frontend does not invalidate") — mechanism preserved, framing removed.

## CHECK 2 — Neutrality

No banned vocab or framing in NEW T7 text. OLD framing removed:
- OLD ALL-CAPS "TEXTRACT IS NOT TRIGGERED" → NEW "Textract is not triggered" (neutral factual).
- OLD "MAP-WRONG" → removed.
- OLD "perpetual pending UI" → removed; mechanism stated neutrally.
- OLD "silently never runs" → NEW "the attach does not run".
- OLD "safe no-op" → NEW "has no effect".
Substring matches on "find raises" / "find_by" are false positives, not framing.
