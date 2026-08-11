# Modals: ModalContext frozen-props correctness (rule 22) — Pass 2

## Pass 1 corrections in this angle's scope
None were required.

## Fresh scrutiny
- Re-read F.3 in the amended plan: unchanged; no new inconsistencies.
- Fresh check (rule 22, both directions): the confirm modal's live-state need is met by INTERNAL hook ownership (F.3.2.1), and its frozen props are only `jobId` (immutable) and `onCancel` (stable context fn) — no state-derived prop is frozen. The view modal's frozen `criteria` prop is the consciously-accepted staleness case, display-only, opened only from state 4 where `criteria` is non-null. Both match SPEC 8.4/8.5 exactly.
- Fresh check: F.3.2.6's confirm handler passes call-site `{ onSuccess, onError }` to `mutate` while the hook keeps its own `onSuccess` invalidation — both fire in react-query v3 (hook-level then call-site); the section button's loading then derives from the invalidated payload/`isFetching` (D-5). The no-success-toast decision is coherent with the WS completion toast.
- Fresh check: `dismissModalWithAnimation(() => onCancel)` — odd-looking callback-returning-callback form is the analog's exact idiom (BulkGenerateAiSummariesConfirmModal.tsx:54, :91); copying it verbatim is correct analog behavior, not a typo to "fix".
- Fresh check: FullModal Esc/backdrop close paths call `onCancel` (verified in FullModal.tsx) — passing `removeModal` as `onCancel` (F.2.1.6 wiring) closes cleanly with no orphaned state.

## Completeness re-sweep (SPEC §8.4/§8.5)
All present: both modals' full anatomy, mutation ownership, both behavioral props on the primary, stays-open-on-error with the sanctioned toast fallback, staleness acceptance, decided-OUT exclusions (no TierHint, manual variant only). Nothing dropped.

## Findings
No new issues found.

## Amendments Applied
None.
