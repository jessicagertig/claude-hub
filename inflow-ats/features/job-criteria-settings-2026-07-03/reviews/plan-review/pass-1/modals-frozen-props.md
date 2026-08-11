# Modals: ModalContext frozen-props correctness (rule 22) for BOTH new modals — Pass 1

## Fact Check

| Plan claim | Verified against | Result |
|---|---|---|
| ModalContext stores the element as frozen state | ModalContext.tsx:28-35 (`openModal` → `setModal(modal)`) | ✓ (plan cites :24-34; setModal callback spans :28-35 — within drift tolerance). Props captured at `openModal()` time forever — rule 22 premise real |
| F.3.2.1: RegenerateJobCriteriaConfirmModal OWNS its mutation internally | P9 analog: BulkGenerateAiSummariesConfirmModal.tsx:43 (`const { mutate: bulkGenerate, isLoading } = useBulkGenerateAiSummaries();` inside the modal) | ✓ analog confirmed; plan requires `useRegenerateAiJobCriteria()` INSIDE the modal and explicitly rejects parent-passed isLoading (the ai-billing-overhaul H1 failure). Props limited to `{ jobId, onCancel }` — no mutation callbacks passed in (modal_form_and_confirmation_patterns.md "DON'T: Pass onSuccess/onError to Form Modals" honored) |
| F.3.2.5: BOTH `loading={isLoading}` AND `disabled={isLoading}` on primary (rule 11) | Analog :157-158 (`loading={isLoading}`, `disabled={isLoading || processableCount === 0}`) | ✓ analog passes both; plan requires both |
| Success: `dismissModalWithAnimation(() => onCancel)`, NO success toast | Analog :91 (same call in onSuccess) + SPEC 8.5 (completion arrives over WebSocket) | ✓; analog's success toast is analog-specific (sync queue counts), SPEC 8.5 explicitly specifies no queue toast for this feature — spec-adjudicated, plan matches SPEC |
| Error: warning toast `error?.data?.errors?.general?.[0] || "Could not regenerate job criteria"`, `delay: 10000`, modal STAYS open | Analog :93-99 (identical shape, `delay: 10000`, no dismiss in onError) + JobSetupAiSettings.tsx:39-45 (same pattern in the target file) | ✓ both precedents exact; fallback string is the sanctioned analog-matching toast exception (F.4.1 documents it) |
| `CenterModal` `headerTitleText` required | CenterModal.tsx:13 (`headerTitleText: string` — not optional) | ✓ F.3.2.2 passes it |
| Statement box mirror | RunPlatoAddDescriptionModal.tsx Styled.Statement :63-83 with svg sizing :75-81 | ✓ exact; `refresh-cw` icon per DECISIONS |
| F.3.1: JobCriteriaViewModal display-only, props `{ criteria, onCancel }`, frozen-prop staleness consciously accepted | SPEC 8.4 (identical acceptance, "do not fix with live reads") | ✓ plan carries the acceptance verbatim; nothing interactive depends on the frozen criteria (read-only list); View button rendered ONLY in state 4 (F.2.1.6), so `criteria` is non-null at open time |
| FullModal custom header by omitting `headerTitleText` | FullModal.tsx:104-111 (`{headerTitleText && (<Styled.Header>...Dismiss...)}` conditional) | ✓ exact — omitting the prop suppresses the built-in Dismiss header; Esc + backdrop close via `onCancel` built in |
| Custom sticky header: h2 + X icon button calling `onCancel`; NO TierHint | F.3.1.2, F.3.1.4 vs SPEC 8.4 + DECISIONS decided-OUT | ✓ specced structure carried; TierHint prohibition explicit |
| Section wiring `openModal(<Modal ... onCancel={removeModal} />)` | ChannelMessageListItem.tsx:52-64 (P14) | ✓ pattern exact in analog |
| ModalContext/ToastContext never edited | C NOT-touched list + core_critical_rules "Files You Should Never Edit" | ✓ consistent — no task touches them |
| `AiJobCriterion` type imported from `useAiJobCriteria.ts` | F.3.1 + F.1.1 (type exported there) | ✓ export present in the F.1.1 code block |

## Completeness (vs SPEC §8.4, §8.5, §12)

- SPEC 8.4 FullModal slide-over: open/close mechanics, custom sticky header spec, body copy, bordered tier-grouped list (empty tiers omitted, tiers after first get top border), read-only (no hover, no footer), props, staleness acceptance → F.3.1.1-F.3.1.4 ✓ every element present
- SPEC 8.5 confirm modal: CenterModal + required title, manual-only lead, statement box copy + icon, footer buttons, mutation ownership, success/error handling, props → F.3.2.1-F.3.2.6 ✓ every element present
- SPEC 12: no frontend tests (documented) → H ✓

## Findings

No issues found.

## Amendments Applied

None.
