# Conventions pass — contexts (ModalContext / ToastContext)

Rules checked: `cursor_rules/frontend/contexts/context_usage_and_rules.md` + `cursor_rules/frontend/contexts/context_reference.md` (as a unit).
Diff: `git diff develop...HEAD -- app/javascript/ats/src/views/jobApplications/jobSetup app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` at HEAD 68e5e6a4e.

No issues found.

Verification notes (evidence for the clean pass, not findings):

- **Context files untouched**: `git diff develop...HEAD -- app/javascript/shared/context/ app/javascript/ats/src/context/` is empty. `ModalContext.tsx` / `ToastContext.tsx` were read only.
- **No local modal state**: no `useState` modal management anywhere in the diff. The `useState` import in `JobSetupAiSettings.tsx:1` is pre-existing, unchanged form state.
- **openModal/removeModal wiring** (`JobCriteriaSection.tsx:34,152-155,163-165`): `const { openModal, removeModal } = useModalContext();` — both modals opened via `openModal(<Modal ... onCancel={removeModal} />)`, modal element defined inline in the handler, `removeModal` passed as `onCancel`. Matches the documented pattern exactly.
- **Form modal handles mutation internally** (`RegenerateJobCriteriaConfirmModal.tsx:19-42`): parent passes only `jobId` + `onCancel`; no `onSuccess`/`onError` props from parent (the documented anti-pattern). Modal closes itself on success and surfaces errors itself.
- **`dismissModalWithAnimation(() => onCancel)`** (`RegenerateJobCriteriaConfirmModal.tsx:24,33`): the double-arrow shape is the established mechanism, not a bug — `ModalContext.tsx` stores the callback via `setAnimationCompleteCallback(cb)`, so React's setState-updater semantics unwrap the outer arrow and store `onCancel` itself, which `CenterModal.tsx:64-65` (`handleAnimationDone`) invokes after the leave animation. Identical shape at 20+ existing call sites (e.g., `BulkMoveModal.tsx:86` with the explanatory comment at line 93, `AlertModal.tsx:26`, `CommentTemplateModal.tsx:74`).
- **useToastContext usage** (`RegenerateJobCriteriaConfirmModal.tsx:20,35-39`; `WebsocketGlobalChannelHandler.tsx:250-262`): `const addToast = useToastContext();` — correct hook shape. All toast objects use only documented fields (`title`, `kind`, `delay`) with valid kinds (`success`, `warning`). Error toast follows the documented error-case pattern: `error?.data?.errors?.general?.[0] || "Could not regenerate job criteria"`, kind `warning`.
- **Single result toast per action**: regenerate success path shows no mutation-time toast; the one completion toast arrives via the `JOB_CRITERIA_EXTRACTION_COMPLETE` websocket branch (mutually exclusive branches, one toast per event). No "Saving.../Saved!" doubles anywhere in the diff.
