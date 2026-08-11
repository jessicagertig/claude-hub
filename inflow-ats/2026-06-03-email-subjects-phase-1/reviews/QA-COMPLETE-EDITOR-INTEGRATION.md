# QA Complete — Integrate Subject into Editor.tsx

**Verdict: APPROVED**

## Summary

The subject input was moved from separate `FormInput` elements in 4 parent forms into `Editor.tsx`, gated behind `enableMessageMailMergeMenuBar`. Merge tag buttons now route insertion to whichever field (subject or body) has focus. All 5 QA layers passed.

## Per-layer results

| Layer | Rounds | Runs | Status |
|---|---|---|---|
| L1: Diff-to-Spec | 4 rounds across 4 runs | 4 | PASS (3 bugs found and fixed) |
| L2: Code Correctness | 2 rounds | 1 | PASS (1 bug found and fixed) |
| L3: Script Runner | N/A | — | Skipped (frontend-only change) |
| L4: Regression | 1 round | 1 | PASS (Cypress 1/1 passing) |
| L5: Playwright | 1 round | 1 | PASS (15/15 agents clean) |

## Bugs found and fixed during QA

1. **Subject repopulation on validation error** missing from ChannelMessageTemplateModal + BulkMessageModal (L1 Run 1)
2. **Same repopulation** missing from HiringStageAutomationModal `handleSaveTemplate` (L1 Run 2)
3. **Subject input ignores `disabled` prop** — body and merge buttons disabled but subject stayed interactive (L2 Run 1)

## Playwright verification coverage (Layer 5)

| Agent | Surface | Test | Result |
|---|---|---|---|
| 1 | Template create modal | Subject field present, default, editable, persists | PASS |
| 2 | Template create modal | Merge tags route to subject when focused, body when body focused | PASS |
| 3 | Bulk message modal | Subject field, template selection updates subject, merge tags | PASS |
| 4 | Automation modal | Inline create template subject, merge tags, PreviewSubject | PASS |
| 5 | Job setup automations | Apply response template subject, 5 merge buttons (no sender), persists | PASS |
| 6 | Bulk message modal | Disabled state — subject input disabled with 0 candidates | PASS |
| 7 | Template create modal | Validation error + subject repopulation | PASS |
| 8 | Bulk message modal | Merge tag focus routing | PASS |
| 9 | Automation modal | Merge tag focus routing in inline create | PASS |
| 10 | Job setup automations | Merge tag focus routing | PASS |
| 11 | Template edit modal | Subject persists across edit cycle | PASS |
| 12 | Bulk message modal | Validation error + subject repopulation | PASS |
| 13 | Automation modal | Validation error + subject repopulation in inline create | PASS |
| 14 | Single-send composer | ChannelMessageNew.tsx unaffected — no merge buttons, own subject pattern | PASS |
| 15 | Bulk message modal | Send with custom subject — subject persists on sent message | PASS |

## MED findings (do not block)

See existing `QA-MED-FINDINGS.md` for prior Phase 1a MEDs. From this integration pass:

- M1: Subject hooks unconditional in Editor.tsx (React Rules of Hooks)
- M2: `insertTagIntoSubject` could use functional update form (defensive)
- M3: No guard on `insertTagIntoSubject` when undefined (can't happen in practice)
- M4/M6: Pre-existing body append on template switch in BulkMessageModal
- M5: Pre-existing CSS label mismatch in JobSetupAutomations

**Note:** Prior QA findings #2 (automation preview missing subject) and #3 (template modal missing repopulation) are now resolved by this change.

## Total agents dispatched

- L1: 24 review agents + 8 verification agents = 32
- L2: 10 agents
- L4: 1 Cypress runner
- L5: 15 Playwright agents
- **Total: 58 agents**
