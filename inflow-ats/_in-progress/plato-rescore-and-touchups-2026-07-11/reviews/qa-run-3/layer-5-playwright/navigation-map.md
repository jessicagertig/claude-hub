# Layer 5 Navigation Map — Plato re-score (qa-run-3)

Navigate by CLICKS. Allowed direct URLs: `http://app.lvh.me:5007/jobs` (start/reset) and `/auth` (login only).

## Auth (magic-link dev flow)
The shared browser may already be logged in as `rezu.may@wrkhq.com` (org "Acme Inc"). Navigate to `http://app.lvh.me:5007/jobs`; if you land on the jobs list you are logged in. If redirected to `/auth`:
1. Fill the Email textbox with `rezu.may@wrkhq.com`. 2. Click "Continue with email". 3. On the verify page find the "**** DEVELOPMENT ONLY WORKAROUND ****" section, extract the "Click here to confirm email" link href (`.../magic_links/validate?token=...`) and navigate to it. 4. You land on the jobs list.

## Jobs (org "Acme Inc", balance starts at 20 AI credits)
- **"Senior Engineer"** (job 29092, published). Stages: Inbox 3 candidates (ALL with current "Seeded review —" Plato reviews), Screen 5 (2 reviewed: Cornelius Jenkins, Yesenia Bernhard; 3 bare without resume), Interview 55 (all bare, > one 50-row page).
- **"Design Lead"** (job 29093, published). Inbox: 2 candidates (Quinn Barrett, Rowan Ellis), both with current reviews.

## Click paths
- **Job page:** jobs list → click the job title. Candidates view opens (Inbox selected). Column 1 = hiring stages (click a stage name to switch). Column 2 = candidate list with checkboxes; the stage-name checkbox at the top selects ALL. Column 3 = candidate header with tabs (Overview, Resume, Messages, Files, Private notes, and the Plato/AI tab).
- **Per-stage bulk modal** (`BulkGenerateAiSummariesConfirmModal`): in a stage's candidate list, select candidates via checkboxes (or the stage-name Select-All checkbox), then open the "Bulk options" three-dot menu at the top right of the stages column → click "Run Plato reviews".
  - The menu also works with NOTHING selected — that renders the modal's no-selection state.
- **All-stages modal** (`RunPlatoReviewAllModal`): on the job page, the "Plato Reviews" card (sparkle disc icon, text "Plato βeta scores every candidate...") in the stages column → click "Run Plato".
- **PlatoTab:** click a candidate name in column 2 → click the Plato tab in column 3. Candidates with a current review show the review (headline starts "Seeded review —" until a real re-score) and a "Regenerate" button in the header-right. Bare candidates show the "needs a resume" empty state.

## Overestimate state (Stage C only)
Open Interview stage → click the stage-name Select-All checkbox WITHOUT scrolling the list (scrolling loads page 2 of 50/55 rows and the block disappears by design) → Bulk options → Run Plato reviews. Expect "Up to 55 of the 55..." + info block "This count may be an overestimate." with tooltip on hover.

## Credit math (balance is LIVE — read the displayed number)
Start 20. Real runs consume 1/success: agent 11's single-send Regenerate → 19; agent 12's Stage A bulk re-score (3) → 16. Shortfall = count − balance (Stage C 55 → "short 35" at balance 20; all-stages Senior Engineer unchecked 58 → 38, checked 63 → 43 at balance 20). If the balance you see differs because a prior agent's run already landed, recompute expectations from the DISPLAYED balance and say so in your report.

## Timing (test env runs jobs INLINE — inside the HTTP request)
- Single-send Regenerate POST: ~30-90 s. Per-stage bulk (3 candidates): ~2-5 min. The UI may look frozen — WAIT (use browser_wait_for with generous time, re-snapshot). Do not re-click submit.
- Do NOT edit any job description (inline-adapter trap: the update request 500s by design in test env — pre-existing, not a feature bug).

## Known pre-existing console noise (NOT findings)
react-router `history` deprecation warnings; "Store does not have a valid reducer" Redux warnings; `heap-api.com` 404s. Only NEW feature-referencing errors count (rescore, BulkGenerateAiSummaries, PlatoTab, ai_job_application_summaries requests failing, React errors).

## Fixture quirks (NOT findings)
- Resume tab shows a generic `test-resume.pdf` for reviewed candidates while review content differs — fixture artifact.
- "Senior Engineer" description is an android-engineer text; criteria match the description, not the title.
- Seeded review headlines start "Seeded review —"; only re-scored candidates get organic AI copy.
- After a re-score a candidate has TWO succeeded summaries; UI shows the newest via the status row — intended (SPEC 2.7).
- Candidate list order is updated_at desc, not id order.
