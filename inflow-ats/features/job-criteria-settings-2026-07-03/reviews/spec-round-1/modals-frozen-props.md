# Round 1 — Angle 6: Modals — ModalContext frozen-props correctness (rule 22) for both new modals

## Verified against source

**ModalContext freezing mechanism:** `openModal` stores the element via `setModal(modal)` (ModalContext.tsx:24-35) — every prop captured at call time, never re-rendered with new values ✓ (rule 22 premise confirmed).

**RegenerateJobCriteriaConfirmModal (SPEC 8.5) vs the analog `BulkGenerateAiSummariesConfirmModal.tsx`:**
- Analog owns its mutation internally: `const { mutate: bulkGenerate, isLoading } = useBulkGenerateAiSummaries()` at :43 — spec requires the same ownership (`useRegenerateAiJobCriteria()` inside the modal) ✓; internal hook state is live, so the frozen-prop trap does not apply.
- BOTH behavioral props on the primary button: analog passes `loading={isLoading}` AND `disabled={isLoading || ...}` (:157-158) — spec 8.5 requires both (pipeline rule 11) ✓.
- Success path: `dismissModalWithAnimation(() => onCancel)` (analog :90) ✓; NO success toast — completion arrives over WebSocket, section button enters loading via invalidated payload ✓ (the analog DOES toast on success because its response is a synchronous queue summary; the spec's no-toast deviation is deliberate and correct for an async-completion flow whose toast comes from the backend — consistent with DECISIONS "WebSocket success toast").
- Error path: warning toast `error?.data?.errors?.general?.[0] || fallback`, `delay: 10000`, modal stays open (analog :92-98; same pattern already in JobSetupAiSettings.tsx:39-45) ✓.
- `CenterModal` requires `headerTitleText` (CenterModal.tsx:13 — non-optional in Props) ✓; statement box mirrors `Styled.Statement` (RunPlatoAddDescriptionModal.tsx:63-83) with `refresh-cw` icon ✓ (Icon component exists at components/shared/Icon/, name-based usage verified in RunPlatoAddDescriptionModal :23).
- Props `{ jobId, onCancel }` — both stable values; freezing harmless ✓.

**JobCriteriaViewModal (SPEC 8.4):**
- **Phase-1 trace note 2 ADJUDICATED: frozen `criteria` prop staleness ACCEPTED.** Display-only viewer; nothing interactive depends on the frozen array; if a regeneration completes while open, content is stale until closed/reopened — the completion toast and invalidated payload keep the section current, and reopening shows fresh data. The live-read alternative (query state inside the modal) adds fetch/loading complexity to a read-only panel for a marginal edge case. Acceptance now DOCUMENTED in the spec (amendment below) so the plan and Phase 6 review inherit the decision instead of re-litigating it.
- `FullModal` custom header: built-in "Dismiss" header renders ONLY when `headerTitleText` is passed (conditional at FullModal.tsx:104-111; prop optional at :14) — omitting it for the custom sticky h2 + X header is correct ✓. Esc close (:43-53) and backdrop close (:55-65, :98) both route through `onCancel` (via checkUnsavedChanges with default `hasUnsavedChanges: false`) ✓. 50%-width right panel at lg (:158-162) ✓.
- View button rendered only in the criteria-present state (SPEC 8.2 row 4 / 8.3 action row) ✓.

**Section wiring:** `openModal(<Modal ... onCancel={removeModal} />)` per ChannelMessageListItem.tsx (~:49-64 — two openModal call sites verified) ✓.

**Never-edit files:** spec touches neither ModalContext.tsx nor ToastContext.tsx (section 13 verified) ✓.

## Taken on trust from the spec
Nothing load-bearing; analog files and both modal-infrastructure components read this round.

## Findings

- F1 [LOW] SPEC 8.4 accepted the frozen-`criteria` staleness implicitly (display-only props) but did not RECORD the acceptance, leaving the decision open for the plan/impl review to re-litigate or "fix" into a live-read modal. Fix: acceptance note added to 8.4.

## Amendments Applied

1. SPEC 8.4: frozen-prop staleness acceptance note added (rule 22, pattern-2 alternative consciously declined) (F1). Patched section re-read and verified.
