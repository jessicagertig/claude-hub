# Layer 1: Diff-to-Spec Review -- qa-run-4, Round 1

## Fix-by-Fix Verification

All 12 fixes verified against SPEC.md and approved-decisions.md:

- F-001 (apply_one_off metadata): MATCHES Note #4 -- uses invoice metadata directly
- F-002 (charge.refunded restored): MATCHES Note #33 approved decision -- "no change"
- F-003 (name keys added): MATCHES Note #9B-1 -- pack hashes now have name fields
- F-005/F-006 (README tasks+schedule): MATCHES Note #19 -- 4 recurring + 5 on-demand
- F-007 (exact={false}): MATCHES Note #16 constraints
- F-008 (TDD behavioral test): MATCHES Note #25 -- tests re-enqueue behavior
- F-009 (notify_failure tests): MATCHES Note #13 -- verify deliver_later
- F-010/F-011 (mailer assertions): MATCHES Note #1 -- god_admin + full param assertions
- F-012 (instance vars): MATCHES Note #13 pattern convention
- F-013 (webhook metadata test): MATCHES Note #4 -- no list_line_items

## HIGH findings: 0

## MED findings update: M1, M4, M5, M6, M8 now RESOLVED. M2, M3, M7 carried.

## Result: Round 1 clean. Proceeding to Round 2.
