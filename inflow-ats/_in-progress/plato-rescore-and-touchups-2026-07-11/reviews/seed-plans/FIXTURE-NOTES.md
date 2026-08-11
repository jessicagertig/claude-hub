# FIXTURE-NOTES — Plato re-score Layer 5 (Playwright browser QA)

Companion to `plato-rescore-fixtures.rb`. Everything below was traced in the QA worktree
`/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings` (branch `job-criteria-settings-qa`).

## How to run

1. Seed with the UPDATED plan: `ai-org-with-candidates-plato-rescore.json` (same as
   `ai-org-with-candidates.json` but `/cypress/candidates` `amount: 63` instead of 3 —
   the fixture aborts if the job has fewer than 63 job applications).
2. Run the fixture ONCE: `test_frr plato-rescore-fixtures.rb` (aborts unless `Rails.env.test?`).
3. Re-running is safe: credits are re-zeroed/re-granted, existing fixtures are detected and
   skipped, stage assignment is re-applied.

## Page size (overestimate state)

- `app/controllers/api/v1/job_applications_controller.rb:36` — `@per = Rails.env.development? ? 10 : 50`
  (non-god-admin branch; Rezu May is not god admin). **In RAILS_ENV=test the page size is 50.**
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx:104` —
  `selectableCount = jobApplicationsForStageData?.pages?.[0]?.meta?.count` (server-side stage total).
- `app/javascript/shared/lib/bulkAiSummaryCount.ts:43` — `isExact = itemIdsSetType === "included" || jobApplications.length >= selectableCount`.
- Therefore Stage C has **55 candidates** (page size 50 + 5). To see the overestimate info block +
  tooltip: open Stage C (Interview), **Select-All via the stage-name checkbox WITHOUT scrolling**
  (scrolling loads page 2 → all 55 loaded → `isExact` true → block disappears), then open the
  bulk review modal. Expected: "Up to 55 of the 55 candidates ... " + "This count may be an overestimate."

## Stage layout and which selection produces which modal state

Job "Senior Engineer" (seeded description present — the cypress job seed writes a real android-engineer
description, `app/controllers/cypress/jobs_controller.rb:28`). Assignment is by job_application id order.

| Stage | Candidates | Fixtures | Per-stage modal states it produces |
|---|---|---|---|
| Inbox (Stage A) | 3 | ALL 3: resume PDF + succeeded TextractResult + succeeded non-stale summary + status row `current` | Select all 3, unchecked → **state 2 zero-processable** ("0 of the 3 ... Unless you select re-review below..."), submit disabled, checkbox enabled. Checked → **state 4**: "The 3 candidates selected ... including candidates that already have a review. Each successful review uses one AI credit, so running this uses up to **3** credit(s) from your balance of **20** available." REAL bulk re-score pool. |
| Screen (Stage B) | 5 | 2 with current reviews (full fixtures); 3 bare (no resume, no review, status row `none`) | Select all 5, unchecked → **state 3 normal copy**: "3 of the 5 candidates ... don't have a Plato review yet. ... up to **3** credit(s) from your balance of **20** available." (No "Up to " prefix — all rows loaded → count exact.) Checked → count 5, normal copy ("up to **5** ... of **20**"). |
| Interview (Stage C) | 55 | all bare | Select-All before scrolling, unchecked → **state 3 + "Up to " prefix + overestimate block + SHORTFALL copy**: "You are short **35** credits. The first 20 candidates will get reviews generated; the rest will be skipped." Checked → exact 55, shortfall 35, no info block. |
| No selection (any stage) | — | — | **State 1** verbatim no-selection copy; submit disabled; **re-score checkbox disabled** (`disabled={candidatesCount === 0}`, `BulkGenerateAiSummariesConfirmModal.tsx:206`). |

Job "Design Lead" (fixture-created, published, 2 candidates both with current reviews):

- All-stages modal (Run Plato CTA) unchecked → **zero-state**: "0 candidates in this job don't have a
  Plato review yet. Unless you select re-review below, no candidates will be reviewed." Button disabled.
- Checked → "2 candidates in this job will be reviewed, including candidates that already have a review."
  (no leading "The" — SPEC 1.5) + normal credit copy. A real all-stages re-score here is bounded at 2 candidates.

All-stages modal on "Senior Engineer" (candidatesCount 63, summaryCount 5):
unchecked → "58 candidates ... don't have a Plato review yet" + shortfall 38;
checked → "63 candidates in this job will be reviewed, including..." + shortfall 43.
(A real click here is SAFE-ish: only the 5 full-fixture candidates have resumes; see "accidental-run protection".)

## Credit-balance arithmetic (target = 20, addon bucket)

Fixture sequence (avoids a transient zero balance): snapshot buckets → `GrantAiCredits` +20 addon →
`admin_debit` transaction per pre-existing positive bucket (counter_culture maintains the columns,
`ai_credit_balance_transaction.rb:48-50`). End state: daily 0 / monthly 0 / addon_subscription 0 / **addon 20**.
The seeded org normally arrives with monthly ≈ 50 (starter plan allocation set by the plan-change hook,
`organization.rb:604-606`); the script zeroes whatever it finds, so the exact pre-state doesn't matter.

- `available` in both modals = `data?.totalCreditsRemaining` from `GET /api/v1/ai_credits`
  (`Api::V1::OrganizationAiCreditBalanceSerializer#total_credits_remaining` = sum of the four buckets).
- shortfall = `max(0, candidatesToScoreCount - 20)`.
- Normal copy needs count ≤ 20 (Stage A checked 3, Stage B unchecked 3 / checked 5, Design Lead checked 2).
- Shortfall copy needs count > 20 (Stage C 55 → short 35; all-stages 58 → 38; all-stages checked 63 → 43).
- Every successful REAL review consumes exactly 1 credit (`CreateAiCreditBalanceTransaction`, CREDIT_COST 1,
  consumption order daily → monthly → addon_subscription → addon). After the intended real runs
  (1 single-send Regenerate + 3-candidate Stage A bulk re-score) the balance is 20 − 4 = **16** —
  modal numbers shift accordingly; agents should treat the displayed balance as live, not fixed.
- `QueueBulkAiSummaryJobs` caps claims at `organization.total_ai_credits_remaining`
  (`queue_bulk_ai_summary_jobs.rb:58-61`) — 20 ≥ 3, so the Stage A run is never clipped.

## ValidateAiSummaryGeneration gates and how the fixture satisfies each

`app/interactors/validate_ai_summary_generation.rb`:

1. **job_application / organization present** — trivially satisfied.
2. **Flipper `AI_APPLICANT_SUMMARY`** (`:66`) — enabled globally by the seed plan (boolean gate);
   the fixture aborts if it is off.
3. **`has_resume`** (`:69` → `job_application.rb:624`, requires an attached resume with an allowed
   content type) — the 7 full-fixture candidates get `spec/fixtures/files/test-resume.pdf` attached
   directly via `job_application.resume.attach` (no controller involved, so the controller-only side
   effects — `DocxToPdfJob`, `SubmitResumeToTextractJob`, `set_ai_summaries_stale` — do NOT fire).
   Bare candidates intentionally fail this gate (see accidental-run protection).
4. **`credits_available?`** (`:77` → `organization.ai_credits_available?`) — balance 20 > 0.
5. **`has_job_description?`** (`:81`) — cypress seeds a real description on "Senior Engineer";
   "Design Lead" is created with one.
6. **Textract** (`:31-60`) — each full-fixture candidate has a `TextractResult` created directly with
   `textract_job_status: :succeeded` and plausible `textract_job_result_text` (shape copied from
   `spec/interactors/create_bulk_ai_summary_generation_spec.rb:25-30` and
   `spec/support/ai_credits_test_helpers.rb:129-134`) → `textract_text_ready?` true, `textract_pending` false.
   NO real AWS Textract call is ever made. Note: candidates WITHOUT a resume never reach the textract
   branch (gate 3 fails first), so `SubmitResumeToTextractJob` is never enqueued for them either.

Additional pipeline gates beyond the validator:

- **Job-criteria readiness** — `Orchestrate#check_criteria_and_score` requires
  `job.latest_ai_job_criteria&.status_succeeded?` (`orchestrate.rb:74-82`), and the bulk job resolves
  criteria up front via `extract_job_criteria_synchronously` (`bulk_generate_ai_summaries_job.rb:28-37`,
  returns the existing succeeded row). The fixture creates a **succeeded `AiJobCriteria` directly**
  (criteria entry shape `text`/`tier`/`contains_title_technology`/`source_heading` + metadata, copied from
  `spec/services/ai_job_application_action/orchestrate_spec.rb:119-124` and `ExtractCriteria`) — no real
  extraction call. Because it is the newest row, `extract_job_criteria_if_needed` (`textract_result.rb:70`)
  and `extract_job_criteria_synchronously` both short-circuit.
- **Summary reuse / stale check** — fixture summaries are created `status: :succeeded, stale: false` and
  **linked to the fixture TextractResult**; `CreateBulkAiSummaryGeneration`'s mismatch check
  (`create_bulk_ai_summary_generation.rb:40-43`) therefore never marks them stale.
- **Status row `current`** — produced by the app's own `FindOrCreateAiJobApplicationSummaryStatus`
  (resolves `current` from the succeeded summary and denormalizes score/headline/analysis). This is what
  makes the PlatoTab **Regenerate** button render (`PlatoTab.tsx:247`, `statusValue === "current"`), the
  frontend processable count exclude them (`bulkAiSummaryCount.ts:40`), and the backend exclude them at
  enqueue when unchecked (`queue_bulk_ai_summary_jobs.rb:41-48`).
- Fixture headlines all start with **"Seeded review —"**: after a real re-score the headline is
  AI-generated, so "a NEW review was created" is directly observable in the UI.

## Auto-generation safety (why fixture creation triggers no AI calls)

`TextractResult` has `after_commit :queue_ai_summary_job, on: [:create, :update]`
(`textract_result.rb:7`). For fixture-created rows the auto-generate branch is reached and returns at
`job.should_auto_generate_ai_summaries?` — the org default is `auto_generate_ai_summaries_enabled: false`
(`organization.rb:1312`) and the job enum default cascades to the org (`job.rb:974-981`). The fixture
**aborts up front** if auto-generate is on. Summaries are created already-`succeeded`
(`handle_after_update_commit` is `on: :update` only — no broadcasts/side effects at create).

The "Design Lead" publish would fire `auto_extract_job_criteria` (real OpenAI extraction, inline) because
`AI_APPLICANT_SUMMARY` is enabled at fixture time — the script wraps `published!` in
`Flipper.disable(:AI_APPLICANT_SUMMARY)` / `ensure Flipper.enable(...)` so the hook no-ops
(`job.rb:699-700` gates on the flipper).

## Test-env execution model (IMPORTANT for the QA agents)

- `config/environments/test.rb:64` — **`config.active_job.queue_adapter = :inline`**. Every
  `perform_later` runs synchronously inside the enqueuing process. The harness's Sidekiq process is
  effectively idle for this feature: the bulk run (`BulkGenerateAiSummariesJob`, job-iteration) and the
  single-send run (`GenerateAiJobApplicationSummaryJob`) execute INSIDE the Rails server request.
  Practical effect: the POST for a single-send Regenerate returns only after the whole pipeline
  (2-4 real AI calls, ~30-90 s), and the Stage A bulk re-score POST returns only after all 3 candidates
  are scored (~2-5 min). **Playwright must use generous request/navigation timeouts and should not
  assume a fast 200.** Intermediate "regenerating" UI states may be visible only via websocket
  broadcasts that fire mid-request (cable adapter is redis in test, `config/cable.yml`).
- **Inline adapter cannot schedule delayed jobs** (`enqueue_at` raises `NotImplementedError`). Two traps:
  - Do NOT meaningfully edit the description of a published job that already has criteria during QA:
    `auto_extract_job_criteria` uses `ExtractJobCriteriaJob.set(wait: 30.seconds)` (`job.rb:711`) →
    raises inline → the job-update request 500s.
  - If a real AI call fails with the retryable `CustomErrorAiSummary`, `retry_on ... wait: 2.minutes`
    (both generation jobs) attempts a delayed re-enqueue → `NotImplementedError` (not a `StandardError`,
    so `discard_on StandardError` does not catch it) → the request errors. Transient AI-provider failures
    therefore surface as request failures instead of silent retries. Rare, but if the run dies mid-way,
    this is the first suspect.

## Accidental-run protection (why the big stages are resume-less)

Bulk enqueue eligibility is `scope.with_resume.has_succeeded_latest_textract_result`
(`queue_bulk_ai_summary_jobs.rb:23`). Stage C's 55 candidates and Stage B's 3 unreviewed candidates have
NO resume, so clicking "Generate reviews" there (even in the shortfall state, even with re-score checked)
queues ZERO candidates and makes ZERO AI calls — the toast reports everything skipped. They also never
get `SubmitResumeToTextractJob` kicked (that path requires `with_resume`, `:25-27`). The ONLY selections
that can trigger real AI calls are: Stage A (3), Stage B's 2 reviewed (with re-score checked), Design
Lead's 2 (with re-score checked), and single-send on any full-fixture candidate. Maximum possible spend
if an agent runs everything: 7 candidates + regenerates, bounded by the 20-credit balance.

Bare candidates double as the single-send empty-state sanity check: PlatoTab shows the **noResume**
empty state for them (`PlatoTab.tsx:217`, status row `none` + `hasResume` false).

## Env-var presence (names only; values not read beyond presence)

Checked via `foreman run bash -c 'test -n "$VAR"'` in the worktree (loads `.env`):

| Variable | Result |
|---|---|
| `STAGING_OPENAI_API_KEY` | **PRESENT** |
| `STAGING_GEMINI_API_KEY` | **PRESENT** |
| `AI_DAILY_CREDIT_ALLOCATION` | MISSING (defaults to 5 — irrelevant, fixture zeroes buckets) |
| `AI_MONTHLY_CREDIT_STARTER` | MISSING (defaults to 50 — irrelevant, fixture zeroes buckets) |
| `config/master.key` or `RAILS_MASTER_KEY` | PRESENT (credentials fallback available; test env reads the `:development` credentials namespace, `config/application.rb:82`) |

The pipeline needs exactly two providers at run time (criteria are pre-created, so `ExtractCriteria` never
runs): **openai** (`Summary::Generate`, `IntegrateAnalysis` — `Variables::OPENAI_API_KEY =
ENV['STAGING_OPENAI_API_KEY'] || credentials`, `config/initializers/01_variables.rb:116`) and **gemini**
(`ScoreJobApplication` — `Variables::GEMINI_API_KEY`, `:120`). Both PRESENT → **the real end-to-end runs
are feasible; no blockers.**

## Mailer behavior in test env

- The bulk-complete/failed mailers (`BulkAllStagesAiSummaryResultMailer`,
  `BulkJobApplicationAiSummaryResultMailer`) do not use ActionMailer's `mail()` — they build a Mailgun
  API payload and call `Emails::SendTemplateEmail#send`, whose `send_message` is explicitly skipped:
  `... unless Rails.env.test?` (`app/services/emails/send_template_email.rb:31-35`). **No real email is
  sent when the bulk-complete email fires.**
- Consequence for QA: the email is NOT observable — `ActionMailer::Base.deliveries` also stays empty
  (the mailer method returns a NullMail since `mail()` is never called). Layer 5 can only verify the run
  completes without error; recipient logic (SPEC 1.6) is covered by the mailer specs
  (`spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb`), not the browser layer.
- `config/environments/test.rb:48` additionally sets `delivery_method = :test` for the ActionMailer-based
  mailers (magic links etc. — that is how login still works via the dev-workaround link).

## Known cosmetic / behavioral quirks to not misreport as bugs

- The Resume tab shows the generic `test-resume.pdf` for every full-fixture candidate, while Plato content
  reflects the per-candidate `textract_job_result_text`. Scoring reads the textract text, never the PDF —
  a content mismatch between the Resume tab and the review is a fixture artifact, not a defect.
- The "Senior Engineer" seeded description is an android-engineer text (cypress fixture); the fixture
  criteria match that description, not the job title.
- Pre-re-score reviews carry the "Seeded review —" headline and fixture analysis text; only re-scored
  candidates get organic AI copy.
- Stage list order is `updated_at desc`; fixture stage-moves touch `updated_at`, so list order will not
  match candidate id order.
- After the Stage A bulk re-score completes, each candidate has TWO succeeded summaries
  (`status: succeeded, stale: false`); readers resolve the newest via the status row — expected per
  SPEC 2.7, not a duplicate-data bug.

## Base seed plan change

`ai-org-with-candidates-plato-rescore.json` (alongside this file) is the base plan with ONE change:
`/cypress/candidates` `amount` 3 → **63** (Stage A 3 + Stage B 5 + Stage C 55). Everything else
(flags incl. `AI_APPLICANT_SUMMARY`, paid subscription, published "Senior Engineer") is unchanged.
The two "Design Lead" candidates are script-created (the `/cypress/candidates` endpoint only targets
`Job.first`). `TEXTRACT_RESUME_PROCESSING` is intentionally NOT enabled — keep it that way, or resume
uploads through the UI will submit real AWS Textract jobs.
