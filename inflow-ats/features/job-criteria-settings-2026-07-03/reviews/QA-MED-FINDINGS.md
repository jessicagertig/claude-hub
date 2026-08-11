# QA-MED-FINDINGS — Job criteria in Plato AI settings (qa-run-3)

All findings below are **MED = report-only, do NOT fix**. None block QA approval. Collected across Layers 3, 4, and 5 of qa-run-3 (Layers 1-2 produced 0 MED this run). Deduplicated.

## 1. `JobPolicy#is_org_admin?` is not record-org-scoped (org isolation rests on controller scoping)
- **Source:** L3-r2-a3-001.
- **Detail:** `JobPolicy.new(adminOfOrgA, jobInOrgB).update?`/`.show?` return `true` because `is_org_admin?` reads the caller's own `current_organization_user`, ignoring the record's org. The criteria endpoints are safe because the controller's `exists(current_organization.jobs.where(id: params[:job_id]), 'no job found')` returns 422 not-found for any cross-org id BEFORE the policy runs.
- **Why MED:** pre-existing shared-infra property of `JobPolicy`; the feature is secure as written; SPEC §9 (line 474) explicitly documents org scoping via the controller lookup. Changing the shared policy is out of scope (pipeline rules 20/23).

## 2. `latest_ai_job_criteria` / `latest_succeeded_ai_job_criteria` have no secondary sort key
- **Source:** L3-r2-a4-001.
- **Detail:** `order(created_at: :desc).first` has no tie-breaker; an exact-microsecond `created_at` tie is not SQL-guaranteed to pick a deterministic row. Observed: rows are milliseconds apart in practice (double-POST test: 3.4ms) and the query never raised or corrupted state.
- **Why MED:** backend edge case, practically unreachable; matches SPEC §3/§4.3 verbatim. Do not fix without owner direction.

## 3. Canonical zero-criteria guard message is a triplicated inline string literal
- **Source:** L3-r2-a14-001.
- **Detail:** The 123-byte guard message is duplicated verbatim in `ValidateAiSummaryGeneration`, `ValidateAutoAiSummaryGeneration`, and `QueueBulkAiSummaryJobs`. Verified byte-identical today (`uniq == [canonical]`); nothing enforces equality on future edits.
- **Why MED:** SPEC §6.2 specifies inline literals and the surrounding interactors use inline-literal errors throughout — matches convention. Latent drift risk only.

## 4. GET `/ai_job_criteria` wire payload uses snake_case top-level keys
- **Source:** L5-r1-a8-001.
- **Detail:** The raw HTTP response uses `extracted_at` / `zero_criteria_failure` (snake_case); the frontend `api.ts` interceptor camelCases them to `extractedAt` / `zeroCriteriaFailure`.
- **Why MED:** matches the documented design (SPEC §5.3 "frontend camelCase after api.ts transform"). Not a defect.

## 5. Pre-existing regression-suite failures (NOT feature regressions)
- **Source:** L4-med-001, L4-med-002.
- **Detail (a) — 9 failures** in `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` (:158, :195, :220, :244, :284, :308, :336, :354, :380): the spec calls/stubs `job_instance.on_complete` as an instance method, but `BulkGenerateAiSummariesJob` defines `on_complete` only via the job-iteration DSL block (not an instance method); rspec verify_partial_doubles raises "does not implement #on_complete".
- **Detail (b) — 1 failure** in `spec/jobs/generate_ai_job_application_summary_job_spec.rb:233` ("broadcasts failed status when the pipeline raises"): the stub raises before an `AiJobApplicationSummary` exists, so the analog job's own `broadcast_completion` returns early on `return unless ai_job_application_summary` and skips the broadcast.
- **Why MED:** both are PRE-EXISTING and proven broken byte-identically at the develop base (the failing production code + spec examples are absent from the feature diff; the analog job and its spec are `git diff develop HEAD`-empty). The feature's OWN new tests pass. Not caused by this feature.

## 6. (Carried from L2) Success broadcast inside the rescue-structured job mirrors the blessed analog
- **Source:** L2 qa-run-3 (surfaced from a LOW).
- **Detail:** `ExtractJobCriteriaJob` broadcasts completion in a structure that mirrors `GenerateAiJobApplicationSummaryJob` (the spec-designated analog), including the success-path broadcast placement.
- **Why MED:** intentional analog replication per SPEC §7; the analog is the approved reference. No change.

---
**Also noted (LOW, not MED):** L5-r1-a1-001 — the never-ran "Generate criteria" button opens the shared "Regenerate job criteria?" confirm modal ("re-extract" wording). This is SPEC-sanctioned (§8.3/§8.5 reuse `RegenerateJobCriteriaConfirmModal` for both actions; only the section button label differs). Report-only.
