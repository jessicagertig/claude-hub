# Angle 6 — Modals: ModalContext frozen-props correctness (rule 22) — Round 2

Both modal files byte-identical to round-1-reviewed state; merge did not touch them. Re-verified:

- **RegenerateJobCriteriaConfirmModal:** owns `useRegenerateAiJobCriteria()` internally (:21) — live hook state; primary Button has BOTH `loading={isLoading}` and `disabled={isLoading}` (:68-69); success → `dismissModalWithAnimation(() => onCancel)`, no queue toast; error → warning toast `error?.data?.errors?.general?.[0] || "Could not regenerate job criteria"`, `delay: 10000`, modal stays open. `CenterModal` with required `headerTitleText`. Statement box with `refresh-cw` icon. No parent-passed mutation state anywhere (the ai-billing-overhaul H1 anti-pattern absent).
- **JobCriteriaViewModal:** display-only `{ criteria, onCancel }`, no fetching inside (grep: no `useQuery`/`apiGet`); frozen-prop staleness consciously accepted per SPEC 8.4 (read-only viewer). `FullModal` WITHOUT `headerTitleText` → built-in Dismiss header suppressed; custom sticky header with h2 + X close button calling `onCancel`.
- **Section wiring:** `openModal(<JobCriteriaViewModal criteria={criteria} onCancel={removeModal} />)` only in the card state; `openModal(<RegenerateJobCriteriaConfirmModal jobId={job.id} onCancel={removeModal} />)` on the Generate/Regenerate button — which is now `disabled` while in flight (round-1 F1 fix), closing the double-enqueue path through the modal.
- ModalContext/ToastContext files untouched by the diff.

## Findings

No issues found. (Round-1 LOW carryover: primary-button attribute deviations vs the analog (`type="button"`, no `size="medium"`, no `className="submit-button"`) remain; recorded in code-quality.md.)
