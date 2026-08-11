# Pass 1 -- CLAUDE.md Compliance Check

## Global CLAUDE.md (~/.claude/CLAUDE.md)

### Database safety
- Plan makes NO database changes. Frontend-only feature. COMPLIANT.
- Plan does not reference any `rails db:*` commands, `psql`, or `.env` modifications. COMPLIANT.

### Never work directly on master
- Plan specifies branch `ai-display` based on `spike/scoring-display-prompt`. COMPLIANT.

### Pre-commit tests
- Plan does not suggest `--no-verify` or test rewrites. COMPLIANT.

### Pattern Matching -- Find It First, Then Build
- Plan includes extensive Pattern Precedents section referencing existing analogs. COMPLIANT.

## Source repo CLAUDE.md (/Users/jessica/wrk/wrk-corp/inflow-ats/CLAUDE.md)

### cursor_rules references
- Plan Required Reading lists `core_critical_rules.md`, `frontend/_base.md`, `frontend/ui_styling.md`. COMPLIANT.
- Each task lists specific cursor_rules to read first. COMPLIANT.

### Core Critical Rules compliance

Rule 2 (Theme Colors: Check Before Using): Plan references exact theme tokens and colors, all verified against lightTheme.ts and colors.ts. COMPLIANT.

Rule 7 (Backend snake_case, Frontend camelCase): All field paths in the plan use camelCase (roleAnalysis, applicableExperience, primaryDomain, keySkills, standoutAccomplishments). COMPLIANT.

Rule 9 (Never Deliberately Set undefined): Plan does not use `condition ? value : undefined` patterns. Plan uses `aiSummary?.id || 0` (falls back to 0, not undefined). COMPLIANT.

### Files You Should Never Edit
- Plan does not modify context files (ModalContext, ToastContext, CurrentSessionContext) or api.ts. COMPLIANT.

## Hub CLAUDE.md (~/claude-hub/CLAUDE.md)

### Never write files into source repos from a hub session
- This plan review runs in the hub. Plan outputs are in the hub scratchpad. COMPLIANT.

## Pipeline CLAUDE.md (~/claude-hub/inflow-ats/CLAUDE.md)

### Known Failure Pattern #1 (Emotion theme utilities)
- Plan Task 4A.10 explicitly warns: "Spread `${[t.text.xs]}` standalone -- do NOT put it inside `font-size:`." COMPLIANT.

### Known Failure Pattern #3 (test requirements)
- Plan includes Test Plan section (Tasks 8.1-8.3). States no existing frontend tests need updating and no new test infrastructure is in scope. COMPLIANT -- spec acknowledged this limitation.

### Known Failure Pattern #4 (ActionMailer .deliver_now)
- Not applicable (frontend-only feature). COMPLIANT.

### Known Failure Pattern #6 (Rename cascades)
- Not applicable (no renames in this plan). COMPLIANT.

## Always-on checks

1. **Known Failure Pattern #1:** Plan explicitly guards against `font-size: ${t.text.xs}` misuse in Task 4A.10. COMPLIANT.
2. **Known Failure Pattern #3:** Test Plan section addresses test requirements. COMPLIANT.
3. **Import cleanup:** Plan Task 7.1 removes `AiJobApplicationSummaryFeedItem` and `AiSummaryState` imports from `JobApplicationActivity.tsx`. COMPLIANT.
4. **No nullish coalescing (??):** Plan code uses `||` not `??`. The error toast uses `error?.data?.errors?.general?.[0] || "Failed to queue summary"`. Optional chaining (`?.`) is permitted; nullish coalescing (`??`) is not. COMPLIANT.
5. **No deliberately set undefined:** No `condition ? value : undefined` patterns in plan code. COMPLIANT.
6. **label: on every styled component:** Plan Tasks 3.8, 4G.2 specify label convention. COMPLIANT.
7. **Backward compatibility:** Plan Task 7.1 removes imports but not files. Plan Risks section confirms old files are not deleted. COMPLIANT.
8. **Spec-implementation mismatch:** One HIGH finding in Angle 1 (FeatureFlipper wrapping Route inside Switch). Addressed separately.

## Findings

No compliance violations found.
