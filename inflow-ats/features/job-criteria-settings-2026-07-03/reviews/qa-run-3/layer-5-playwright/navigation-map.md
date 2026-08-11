# Layer 5 Navigation Map — Job criteria in Plato AI settings

All navigation is via CLICKS from the jobs list (do NOT type deep URLs — that is what you are testing). The one allowed direct navigate is `http://app.lvh.me:5007/jobs` (or `/auth` for login).

## Auth (magic-link dev flow)
The shared browser may already be logged in as `rezu.may@wrkhq.com` (org "Acme Inc."). Check first: navigate to `http://app.lvh.me:5007/jobs`. If you land on the jobs list, you are logged in. If redirected to `/auth`:
1. Fill the "Email" textbox with `rezu.may@wrkhq.com`.
2. Click "Continue with email".
3. On the verify-email page, find the "**** DEVELOPMENT ONLY WORKAROUND ****" section and its link "Click here to confirm email" (href `.../magic_links/validate?token=...`). Extract the href and navigate to it.
4. You land on `/` then the jobs list. Login complete.

## Path to the Job criteria section (per job)
Jobs list → click the job title (e.g. "QA Succeeded") → the job page opens → click "Job setup" (left nav) → the setup sidebar appears → click the "Plato AI settings" nav item (second column; gated by the AI_APPLICANT_SUMMARY flag, which is ON) → the "Plato AI settings" content shows the "Plato reviews" section then the **"Job criteria"** section (heading level 4). URL ends `/jobs/:id/setup/ai`.

The Job criteria section contains (depending on state):
- An intro paragraph with an inline "job description" link (→ `/jobs/:id/setup/description`).
- State-dependent body: a criteria CARD (Plato disc + "Job criteria" + "Plato extracted these ... N ago" + count rail Core/Preferred/Bonus) OR an EmptyState.
- An action row: "Generate criteria" (never-ran only) OR "View criteria" + "Regenerate criteria".
- A right sidebar "Criteria tiers" glossary (Core/Preferred/Bonus).

## Seeded state jobs (org "Acme Inc.", all published, all visible in the jobs list)
Use these to reach each display state. Prefer navigating by clicking the job title in the jobs list; the id is given so you can confirm you are on the right job (`/jobs/:id/setup/ai`).
| State (SPEC §8.2) | Job title | job id |
|---|---|---|
| 5 Never ran (no rows) | "QA Never Ran" | 28054 |
| 4 Succeeded (criteria card) | "QA Succeeded" | 28055 |
| 2 Zero-criteria failure | "QA Zero Criteria Failure" | 28056 |
| 3 Other failure | "QA Other Failure" | 28057 |
| 1 In-flight (first extraction) | "QA In Flight" | 28058 |
| 4+1 Regenerating over success | "QA Regenerating Over Success" | 28059 |

Also present: "Senior Engineer" (seeded published job, never-ran state).

## Expected per-state UI (SPEC §8.2)
- **Never ran (28054):** EmptyState icon `file-text`, title "No job criteria have been generated", message about publish/generate. Action row: **"Generate criteria"** only (no View).
- **Succeeded (28055):** criteria card + count rail (Core 2 / Preferred 1 / Bonus 1 for the seed) + "Plato extracted these ... ago". Action row: **"View criteria" + "Regenerate criteria"**.
- **Zero-criteria failure (28056):** EmptyState icon `alert-triangle`, title "No criteria found", message "No scoring criteria were found in the job description. Plato won't review candidates until it has criteria to score against." Action row: **"Regenerate criteria"** only (no View).
- **Other failure (28057):** EmptyState icon `alert-triangle`, title "Criteria generation failed", message "Something went wrong while extracting criteria from the job description. Regenerate to try again." Action row: **"Regenerate criteria"** only.
- **In-flight (28058):** underlying never-extracted EmptyState with the Generate/Regenerate button in a **loading** state (backend-driven; survives reload). No View button (no criteria).
- **Regenerating over success (28059):** criteria CARD still shows the OLD criteria (Core 2 / Preferred 1 / Bonus 1) with the Regenerate button in **loading** state; View criteria still available.

## View criteria slide-over (SPEC §8.4)
Opens from "View criteria". Header "Job criteria" + Close (X). Description: "New reviews score candidates against these. To change them, edit the job description. Reviews that have already run keep the criteria they were scored against." Then a tier-grouped list (Core/Preferred/Bonus with counts and the criterion texts). NO tier-hint sentences. Read-only. Close via the X or Esc or backdrop.

## Regenerate confirm modal (SPEC §8.5)
Opens from "Regenerate criteria" (or "Generate criteria"). CenterModal titled "Regenerate job criteria?". Lead paragraph "Plato will re-extract scoring criteria from the current job description. Reviews that have already run keep the criteria they were scored against." A bordered statement box (refresh-cw icon) about regenerating rarely. Footer: primary "Regenerate criteria" + secondary "Cancel".

## KNOWN pre-existing console errors (ignore — NOT feature findings)
4 react-router `history` deprecation warnings; 2 "Store does not have a valid reducer" Redux warnings; 1 `heap-api.com` 404. Only flag NEW errors that reference the feature (aiJobCriteria, JobCriteria, useAiJobCriteria, /ai_job_criteria requests failing, React errors in the criteria section).
