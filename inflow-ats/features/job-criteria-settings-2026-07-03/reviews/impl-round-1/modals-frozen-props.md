# Angle 6 — Modals: ModalContext frozen-props correctness (rule 22) — Round 1

## RegenerateJobCriteriaConfirmModal.tsx

- OWNS its mutation: `const { mutate: regenerateAiJobCriteria, isLoading } = useRegenerateAiJobCriteria();` INSIDE the modal — internal hook state is live; no parent-passed `isLoading`/mutation props anywhere (the ai-billing-overhaul H1 failure shape is absent). Rule 22 satisfied.
- Primary button carries BOTH behavioral props: `loading={isLoading}` AND `disabled={isLoading}` (rule 11; analog `BulkGenerateAiSummariesConfirmModal.tsx:157-158` passes both). Double-submits blocked at the confirm point.
- On success: `dismissModalWithAnimation(() => onCancel)` — byte-identical to the analog idiom (:91 in the analog's onSuccess and its `handleOnCancel`); NO success toast (completion arrives over WebSocket; section button enters loading via the invalidated payload).
- On error: `addToast({ title: error?.data?.errors?.general?.[0] || "Could not regenerate job criteria", kind: "warning", delay: 10000 })`, modal STAYS open (no dismiss in onError) — matches analog :92-98. The `|| "…"` fallback string is the sanctioned exception (plan F.4.1).
- `CenterModal` with required `headerTitleText="Regenerate job criteria?"` and `onCancel={handleOnCancel}`. Statement box mirrors `Styled.Statement` (RunPlatoAddDescriptionModal:63-83) with `refresh-cw` icon and wrapper `svg { width: 1rem; height: 1rem; stroke-width: 2px; }` sizing (D-3). Lead paragraph is the manual variant only.
- Cancel button matches the analog exactly (styleType secondary, preventDefault wrapper, no dismiss-then-mutate hazard).

Surfaced analog deviations (visual/attribute-level, no behavioral effect — recorded per the surface-all rule, not counted MED+):
- Primary button: `type="button"` vs analog `type="submit"`; analog also passes `size="medium"` and `className="submit-button"`, new modal does not. There is no `<form>` in either modal's children, so `type` has no behavioral difference here; size/className are visual/test-hook only. LOW, listed in code-quality.md.

## JobCriteriaViewModal.tsx

- Display-only; props `{ criteria: AiJobCriterion[]; onCancel: () => void }` (type imported from the hook file); NO data fetching inside. Frozen-prop staleness is the SPEC 8.4 consciously-accepted behavior — nothing interactive depends on the frozen `criteria` (read-only rows only); the completion toast + invalidated payload keep the section behind it current. Accepted, per spec.
- `FullModal` with `onCancel={onCancel}`, `headerTitleText` OMITTED — verified FullModal renders its built-in Dismiss header only when `headerTitleText` is truthy (FullModal.tsx:104-111), so the custom header replaces it. Esc + backdrop close come free via `onCancel`.
- Custom sticky header: h2 "Job criteria" (22px/600/-0.02em) + 28×28 X icon button (Feather `x`, svg 16px/2px stroke via wrapper CSS) calling `onCancel`.
- Single bordered list container (7px radius) grouped by tier; tier head row = icon + label + tabular count; empty tiers omitted; tiers after the first get top border + margin (`&:not(:first-of-type)`); NO TierHint (diff grep clean); no footer; criterion rows have no hover states.

## Section wiring

`openModal(<JobCriteriaViewModal criteria={criteria} onCancel={removeModal} />)` and `openModal(<RegenerateJobCriteriaConfirmModal jobId={job.id} onCancel={removeModal} />)` per the ChannelMessageListItem pattern. View button rendered only in the criteria-present card state (adjudication in frontend-display-states.md). `ModalContext.tsx`/`ToastContext.tsx` NOT edited (not in diff).

## Findings

No issues found. (The section-level Regenerate button's missing `disabled` is F1, owned by frontend-display-states.md — it is outside both modals.)
