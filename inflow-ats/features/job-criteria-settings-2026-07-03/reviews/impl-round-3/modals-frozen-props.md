# Angle 6 — Modals: ModalContext frozen-props correctness (rule 22) — Round 3

Read both modals line by line; re-read `ModalContext.dismissModalWithAnimation` (:47-63) and the analog's usage this round.

- **RegenerateJobCriteriaConfirmModal**: owns `useRegenerateAiJobCriteria()` INTERNALLY (:21) — live hook state, so `loading={isLoading}` + `disabled={isLoading}` on the primary (:68-69) genuinely block double-submits (rule 22 pattern; rule 11 both behavioral props). No mutation state or callbacks passed in as frozen props — only `jobId` and `onCancel` (both static). On success `dismissModalWithAnimation(() => onCancel)` — byte-identical to the analog's :91 form (ModalContext stores the callback and runs it at animation completion; verified semantics this round). No success toast (completion arrives over WS; section button enters loading via the invalidated payload). On error: warning toast `error?.data?.errors?.general?.[0] || "Could not regenerate job criteria"`, `delay: 10000`, modal stays open. `CenterModal` gets its required `headerTitleText`.
- **JobCriteriaViewModal**: display-only `{ criteria, onCancel }`, no fetching inside; frozen-`criteria` staleness is the SPEC 8.4 consciously-accepted case — nothing interactive depends on it. `FullModal` custom header: `headerTitleText` omitted and the built-in Dismiss header verified conditional on it (FullModal.tsx:104-111), custom sticky h2 + 28px X button calling `onCancel`; Esc/backdrop close free via `onCancel`.
- Section wiring: `openModal(<JobCriteriaViewModal ... onCancel={removeModal} />)` / `openModal(<RegenerateJobCriteriaConfirmModal jobId={job.id} onCancel={removeModal} />)` per the ChannelMessageListItem pattern; the confirm modal is reachable while `isInFlight` only via the disabled button — and even if opened, the backend no-op guard makes a stray POST idempotent.
- `ModalContext.tsx` / `ToastContext.tsx` not edited (never-edit files) — confirmed absent from the diff.
- Cancel-button `type` attribute and primary-button `size` deviations vs the analog remain within the recorded LOW carryover (F5); neither button sits inside a form, so no submit risk.

## Findings

No issues found.
