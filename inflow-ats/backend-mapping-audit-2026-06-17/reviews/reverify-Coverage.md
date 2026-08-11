# Re-verify: Coverage — Rake-layer write sites (NEW ~line 634-635)

## Verdict: CLEAN

## Previously-flagged finding (resolved)

**ai_bulk_extract.rake stale enum-writes must state the runtime consequence (ArgumentError), not only that the value is invalid.**

RESOLVED — NEW `backend-flow-map-2026-06-22-neutral.md:635`:

> the first two assign enum values not present in the current 10-value `AiJobApplicationSummary` enum, which raises `ArgumentError` at runtime (Rails enum setter on an unknown value).

The runtime consequence is now stated explicitly ("raises `ArgumentError` at runtime"), not merely that the value is invalid.

## Code verification

- `app/models/ai_job_application_summary.rb:10-21` — enum has exactly 10 values (`pending:0` … `failed:9`). `:in_progress` and `:extracted` are NOT among them. Confirms "10-value enum" and the not-present claim.
- `lib/tasks/ai_bulk_extract.rake` line numbers confirmed: create(`status: :in_progress`) block `:34-38` (status at :37); `summary.update(status: :extracted)` `:59-62` (status at :60); `summary&.update(status: :failed)` `:89`.
- Rails enum setter on an unknown value raises `ArgumentError` — accurate.

## Dropped/altered fact check (OLD :854-856 → NEW :634-636)

All load-bearing facts present:
- `:34-38 create(status: :in_progress)` — present (:635)
- `:59-62 update(status: :extracted)` — present (:635)
- `:89 summary&.update(status: :failed)` — present (:635)
- reachable only via the rake task — present (:635 "Reachable only via the rake task")
- owned by no trigger/structural path — present (:634 header)
- housekeeping_tasks.rake :409/:445 enqueue SubmitResumeToTextractJob (backfill/replay) — present (:636)

No facts dropped or altered.

## Framing check

No banned vocab or judgment in NEW :634-636. OLD's "STALE", ALL-CAPS "NOT", "newly surfaced", and "would error/would raise" framing were removed/neutralized; the consequence is stated factually ("raises ArgumentError at runtime"). No should/broken/problem/defect/silently/no-op/dead-end/gap-as-defect.
