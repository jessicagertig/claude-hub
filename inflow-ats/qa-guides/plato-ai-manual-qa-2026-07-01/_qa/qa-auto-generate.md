# QA — Auto-generate AI summaries (org toggle, per-job override, firing triggers, plan/credit gating)

Scope: the org-level `autoGenerateAiSummariesEnabled` setting, the per-job `autoGenerateAiSummaries`
override (default / enabled / disabled), WHEN auto-generation actually fires, and the gates
(flag / resume / description / credits) that silently suppress it.

Two facts drive every case here:
- **Auto-generation is bound to applicant CREATE only** (`enqueue_new_job_application` runs
  `after_commit … on: [:create]`). Nothing about stage moves, edits, or toggling a setting
  retroactively triggers it.
- **The auto path is SILENT** — no completion toast on success OR failure, and a failed gate produces
  no toast and no summary row. Verify by watching the candidate-list status badge and the credit
  balance, never by expecting a growl.

Feature flag: `AI_APPLICANT_SUMMARY` must be on for the org. Credit/plan states are set up via
Account → Plato AI billing; several cases require deliberately draining the org to 0 credits.

---

## 1. Org-level toggle (Account → Plato AI → Settings)

- **Toggle persists both ways.** Setting "Auto-generate Plato reviews for new applicants" to
  Enabled/Disabled saves (success toast "Plato AI settings saved"), clears the dirty state, and the
  value survives a reload. Condition: admin user, flag on.
- **Default is OFF for a fresh org.** A never-touched org shows the setting Disabled — new applicants
  are NOT auto-reviewed until an admin turns it on. Condition: org that never saved Plato AI settings.
- **Copy is accurate.** The field copy states each successful review spends one credit and that
  individual jobs can override — confirm it matches the behavior verified in §2/§6.
- **Nav visibility vs. reachability.** The "Plato AI" account-nav item appears only with the flag on;
  with the flag off, direct-URL `/hire/settings/plato-ai` still mounts but the admin gate governs.
  Non-admins see nothing (container returns null). Condition: toggle flag; try admin vs non-admin.
- **Unsaved-changes guard.** Changing the toggle and navigating away triggers the guard; discarding
  leaves the stored value unchanged.

## 2. Per-job override + resolution cascade (Job Setup → Plato AI settings tab)

The per-job value is default / enabled / disabled; the effective decision is
`should_auto_generate_ai_summaries?` = job-enabled→ON, job-disabled→OFF, job-default→inherit org.
Verify the full matrix by creating a NEW applicant on the job (that is the only trigger — see §4) and
checking whether a review starts:

- **Org ON + job "default"** → auto-review fires.
- **Org ON + job "disabled"** → does NOT fire (job override beats org-on).
- **Org OFF + job "enabled"** → fires (job override beats org-off).
- **Org OFF + job "default"** → does NOT fire.
- Confirm the per-job select defaults to "default" on a job never configured, and that the saved
  value round-trips through reload.

## 3. Per-job toggle authorization gating (Job Setup → Plato AI)

The extra auth branch fires ONLY when the auto-generate field is in the job-update payload — a
normal job edit by the same user takes the ordinary path.

- **Admin can always change the per-job setting.** Condition: admin org user.
- **Hiring-team member gated by org control setting.** With `hiringTeamAiCreditsControlEnabled`
  (Account → Plato AI → Settings) ON, a non-admin org user can change the per-job auto-generate
  setting; with it OFF, saving that setting is rejected (authorization). Verify both states as a
  non-admin.
- **Non-AI job edit unaffected.** As the same non-admin (control setting OFF), a normal job edit that
  does NOT touch the auto-generate field must still save — the auth gate must not block ordinary
  job updates.

## 4. When auto-generate FIRES — new applicant (candidate list / applicant drawer)

Auto-generation triggers ONLY when a NEW job application is created on a job where auto-generate
resolves to ON AND all gates pass. On the auto path the summary is created in a waiting
(textract-processing) state first, then advances once OCR text is ready — so expect a brief
in-progress state before a score appears. Observe on the candidate-list row / applicant Plato area:

- **New applicant, resume, auto on, org has credits, job has description** → the row shows the
  in-progress state (PlatoHourglass / "Review in progress"), then transitions live (no reload) to a
  fit score + band once the pipeline succeeds. Exactly one credit is consumed on success — reconcile
  in Account → Plato AI → Usage before/after.
- **Live status transition without reload.** The list badge and the applicant drawer update in place
  as the summary moves through its pipeline; no manual refresh needed.
- **Two applicants in quick succession** each start their own review and each consume one credit —
  confirm no cross-talk and no double-charge on a single applicant.
- **Resume added after applicant creation.** Applicant created without a resume (no review starts),
  then a resume uploaded later on an auto-on job → a review starts once OCR text lands (this fires
  through the resume/OCR callback, and is also SILENT — no toast). Watch it fire once, not per edit.

## 5. When auto-generate must NOT fire — negative cases (high value)

- **Stage move does NOT auto-generate.** Moving an existing candidate between stages (single or bulk
  move) must NOT start a review and must NOT consume a credit. Firing is bound to applicant CREATE
  only. Confirm balance unchanged and no new in-progress badge. (Note: a stage move DOES invalidate
  the AI-summary query cache — a brief refetch is expected, but no new review.)
- **Flag off** → no auto-review for any new applicant regardless of org/job settings.
- **Existing applicants when the toggle is switched on** are NOT retroactively auto-reviewed — only
  applicants created after the setting is on. Condition: enable the org toggle on a job with
  pre-existing candidates; confirm they stay unscored.

## 6. Gating by credits / plan (Account → Plato AI → Usage for balance)

- **Zero credits → silent no-op (highest-risk path).** With the org drained to 0 total credits (all
  four buckets empty: monthly plan, subscription add-on, top-up, daily), a new applicant on an
  auto-on job does NOT get a review and NO error toast appears. Confirm the row shows no in-progress
  badge and the balance stays 0. A user could believe auto-review is on yet nothing happens.
- **Plan with no monthly AI allocation behaves as zero credits.** An org whose plan grants 0 monthly
  AI credits with no add-on/top-up = no auto-generation even with the toggle on. Verifies plan-tier
  gating routes through the same `ai_credits_available?` check.
- **Credits restored → resumes.** After a top-up or subscription grant restores a positive balance,
  the NEXT new applicant auto-reviews normally. Condition: drain then restore, add applicant.
- **Balance decrements by exactly one per successful auto-review** — reconcile Usage before/after,
  and confirm the debit hits the correct bucket order (daily → monthly → subscription → top-up).

## 7. Gating by resume / job description

- **No resume → no auto-review, silently.** New applicant with no resume file: no review starts.
- **Job with no description → no auto-review.** Even with auto on, credits, and a resume, an
  applicant on a job with a blank description does NOT auto-generate. (This is why the Run Plato CTA
  educates the user to add a description — cross-check that path if convenient.)
- **DOCX vs non-DOCX resume both eventually auto-review.** A .docx resume converts to PDF and submits
  to OCR after conversion; a non-docx resume submits to OCR directly at applicant creation. Both must
  end in a completed review for an auto-on job — verify a .docx-resume new applicant is not silently
  stuck and does eventually score.

## 8. Silent auto path vs. manual — no toast, but live display

- **Auto path fires NO completion toast** (unlike the manual "Generate" button, which growls on
  success/failure). After an auto-review completes, expect only the in-place status/score update on
  the row and drawer — no success growl. Do not treat the absent toast as a failure.
- **Auto-review failure is also silent.** A failed auto-review surfaces no growl, while a
  manually-requested one does — that's how the two paths stay distinguishable. Confirm a forced
  auto-path failure (e.g., corrupt/unreadable resume) resolves the row without a toast.

## Cross-feature regression notes (shared new-applicant path)

`enqueue_new_job_application` runs for EVERY new applicant, AI or not, so exercise the generic
applicant-creation path with the AI flag OFF:

- **New applicants still process normally with the flag OFF** — resume OCR, NewJobApplication work,
  and the applicant appearing in the list are unaffected. Both non-docx and docx resumes handled.
- **Companion status row is created for every new applicant** (even non-AI) — confirm the candidate
  list renders unchanged (no error, no stray badge) for orgs/jobs with auto off.
- **DOCX resume timing changed** (docx now submits to OCR after PDF conversion, not directly at
  create) — regression-check that .docx resumes still get processed on a normal (non-auto) job.
