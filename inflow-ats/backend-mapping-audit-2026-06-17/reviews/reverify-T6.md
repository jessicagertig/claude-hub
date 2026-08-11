# Re-verify T6 — CSV Bulk Import (build/retrieve)

Verdict: CLEAN

## Previously-flagged finding (build-vs-retrieve asymmetry)
Resolved: TRUE. Present and correct in NEW at `backend-flow-map-2026-06-22-neutral.md:245`.

NEW:245 states: on the new-candidate branch `CreateCandidateJobApplication` retrieves the job_application via `@candidate.job_applications.first` (`create_candidate_job_application.rb:19`), the auto-built join from `@job.candidates.build` (`:18`; `job.candidates` is `through: :job_applications`, `job.rb:38`); "this does not affect the Textract outcome."

Code verified:
- `create_candidate_job_application.rb:18` — `@candidate = @job.candidates.build(@candidate_data.merge(organization_id: @job.organization_id))`
- `create_candidate_job_application.rb:19` — `@job_application = @candidate.job_applications.first`
- `job.rb:38` — `has_many :candidates, through: :job_applications`

All three line cites are accurate.

## Fresh fact-coverage check (OLD → NEW)
Every load-bearing OLD T6 fact is carried into NEW (lines 236-251):
- Controller entry actor (authorize, ValidateJobCsvImport, perform_later) — NEW:239
- `external_resume_status` conditional `:pending`/nil — NEW:241
- Present-URL terminal + Flipper gate (`job_application.rb:167`, `submit_resume_to_textract.rb:10`, `589-590`) — NEW:242
- No-URL row (`should_attach_external_resume_url?`) — NEW:243
- created_via precision + assign_attributes applies to both branches — NEW:245
- build-vs-retrieve asymmetry — NEW:245
- attach_resume_url key-dependence (no `resume_url:` key passed) — NEW:247
- Per-row rejection + batch swallow + mid-loop raise — NEW:249
- T7 lazy-attach terminal pointer — NEW:251

No newly dropped or altered load-bearing fact. The OLD "MAP-WRONG (enum)" item (OLD:107) is audit meta-framing, not a code fact; its omission is correct de-dup, not a dropped fact.

## Framing check
No banned vocab or judgment in NEW T6. The only `should_`/"no effect" hits are the real method name `should_attach_external_resume_url?` and neutral descriptive "have no effect" — both acceptable. The corrected build-vs-retrieve line uses neutral "this does not affect the Textract outcome."
