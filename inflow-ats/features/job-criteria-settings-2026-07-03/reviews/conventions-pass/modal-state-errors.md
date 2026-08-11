# Conventions review: modal_state_errors_and_loading.md

Diff: `git diff develop...HEAD` (HEAD 68e5e6a4e) — JobCriteriaViewModal.tsx, RegenerateJobCriteriaConfirmModal.tsx
Rules file: cursor_rules/frontend/modals/modal_state_errors_and_loading.md

No issues found.

Checks performed:
- Button loading state: RegenerateJobCriteriaConfirmModal.tsx:63-70 — confirm Button has `loading={isLoading}` and `disabled={isLoading}` from `useRegenerateAiJobCriteria`. Compliant.
- Error handling: RegenerateJobCriteriaConfirmModal.tsx:36-42 — `onError` shows `addToast({ kind: "warning" })` and does NOT dismiss the modal; modal stays open for retry, `isLoading` resets. `onSuccess` (line 33-35) is the only close path. Compliant.
- Dismiss pattern: `dismissModalWithAnimation(() => onCancel)` (lines 24, 34) matches the established call form used across the codebase (e.g., BulkGenerateAiSummariesConfirmModal.tsx:53, ConfirmationModal.tsx:49; thunk form documented at BulkMoveModal.tsx:93).
- isDirty / hasUnsavedChanges: rule scoped to form modals with user-editable inputs. RegenerateJobCriteriaConfirmModal has no form inputs (confirm-only); JobCriteriaViewModal is read-only display. N/A.
- Loading Modal special case: N/A — mutation runs inside the confirm modal, no parent-opened loading modal.
- JobCriteriaViewModal.tsx: no mutations, no loading states, no error paths, no form inputs — no rules in this file apply.
