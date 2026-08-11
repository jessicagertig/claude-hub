# Verify T6 — CSV bulk import

**Verdict: ISSUES**

## Files checked
- OLD: backend-flow-map-2026-06-17.md — changelog T6 (lines 105-118), Part 1 body Trigger 6 (lines 410-419), Part 7 matrix row 6 (line 732), census (line 848)
- NEW: backend-flow-map-2026-06-22-neutral.md — T6 section (lines 236-251), Triggers preamble (120-122), submission service (124-133), T7 cross-ref (251-267), matrix row 6 (598), census (628, 653)

## CHECK 1 — Fact preservation

Verified present in NEW (no drop):
- conditional `external_resume_status: record['Resume URL'].nil? ? nil : :pending` (`:21`) — NEW 241
- present-URL stores `external_resume_url`+`:pending`, no file, Textract exits `has_resume` false (`submit_resume_to_textract.rb:10`, `job_application.rb:589-590`) → no TextractResult; status `'none'` (`:170`) — NEW 242
- Flipper gate `:167`, flag-OFF same terminal — NEW 242
- permanent no-Textract terminal even after later `show` attach via `update_column(:external_resume_status,:uploaded)` `:649` bypassing callbacks — NEW 251 + 267
- no-URL sub-case terminal (`should_attach_external_resume_url?` requires `external_resume_status_pending?` `:710`) — NEW 243
- created_via precision (candidate `:created_via_manual_add` `:17` newly-built only; existing reused `:14-20` no `candidate_data`; `assign_attributes(job_application_data)` `:22` both branches; job_application `:created_via_bulk_manual_add` `:20`; identical new/existing) — NEW 245
- trigger entry actor `JobCsvImportController#create` (`:4/:6/:8/:10-14/:16-17`) — NEW 239
- load-bearing missing `resume_url:` key (`attach_resume_url` `:24`/`:34-37`; CSV passes only job/candidate_data/job_application_data `:14-22`) — NEW 247
- per-row rejection (`:26`/`:27`), per-row swallow+continue (`:23-24`), divergence from T4/T5 — NEW 249
- whole-job rescue `:28-31` — NEW 249
- matrix row 6 — NEW 598

### DROPPED
- **build-vs-retrieve asymmetry** — OLD line 115 (NOTE pass-6): "On the new-candidate branch, `CreateCandidateJobApplication` retrieves the job_application via `@candidate.job_applications.first` (`create_candidate_job_application.rb:19`) — the auto-built join from `@job.candidates.build` (`:18`; `job.candidates` is `through: :job_applications`, `job.rb:38`)." Absent from NEW T6 (236-251) and nowhere else in NEW (grep for `job_applications.first`, `candidates.build` returns nothing). OLD marks it "out-of-Textract-scope / immaterial to the Textract terminal," but it is a distinct stated fact with three cites (`:19`, `:18`, `job.rb:38`) and is not pure repetition of any other T6 fact.

### ALTERED
- none

## CHECK 2 — Neutrality
No banned vocab or framing in the NEW T6 text. OLD's judgmental caps ("PERMANENT", "STILL never triggered") and "benign terminal" framing were neutralized; "no-op" replaced by "have no effect"; "swallow" retained as a factual description of `rescue` behavior (not in the banned set). Clean.
