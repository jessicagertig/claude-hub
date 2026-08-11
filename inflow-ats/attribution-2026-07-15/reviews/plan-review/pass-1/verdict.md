# Plan Review — Pass 1 Verdict
**Date:** 2026-07-16 00:15

## Counts
- BLOCKER: 0
- HIGH: 1
- MED: 0
- LOW: 4

## Findings
- F1 [HIGH] test-coverage-and-ghost-tests — T4.1 omitted `@request.env['devise.mapping'] = Devise.mappings[:api_v1_user]`; devise 4.8.1 `assert_is_devise_resource!` (prepend_before_action) raises `AbstractController::ActionNotFound` in every T4 example without it.
- F2 [LOW] frontend-capture-and-sanitization — F3.6 cited `AuthRegister.tsx:134`; live line is 136.
- F3 [LOW] posthog-events-and-identity — `AppAuthRouter.tsx:165-176` cited in pattern table and F7.2; effect actually spans 166–177 (cited as 165–177).
- F4 [LOW] conventions-compliance — Files-list header count "(7 backend + 8 frontend + schema)" and "Total: ~10 modified files" inconsistent with the (correct) itemized list.
- F5 [LOW] conventions-compliance — independent steps not marked parallelizable (sequential order given is safe; noted only).

## Amendments Applied
- T4.1: added the `devise.mapping` before-block with the devise 4.8.1 rationale (F1).
- F3.6: `AuthRegister.tsx:134` → `:136` (F2).
- Pattern table + F7.2: `AppAuthRouter.tsx:165-176` → `:165-177` (F3).
- Files-list header → "(6 backend + 9 frontend incl. posthog.ts + schema)"; Estimated scope total → "16 modified files" (F4).

## Feasibility checkpoint
- Runtime assumptions verified in the actual environment: query-string 6.1.0 parse/extract behavior (installed node_modules source read), actionpack 6.1.7.7 `as_json` delegation (installed gem source read), devise 4.8.1 mapping assertion (installed gem source read), Rails default `action_on_unpermitted_parameters` (no config override), jest default testMatch picks up the new test path, omniauth callback GET route exists for the controller spec, `Recaptcha::Verifier` test-env bypass, ActiveJob `:inline` test adapter (hence mandatory around blocks). No untestable assumptions; no circular fixes.

## Everything fact-checked clean
All file:line claims across B1–B7/F1–F9/T1–T6 verified against the live tree except the two LOW line-ref drifts above; C.1–C.6 check-before-create claims re-verified; `from_omniauth` census re-run (2 files exactly); open-PR conflict claim re-verified via `gh` (#3035 newest 2026-06-05; #3005 touches `organization_params` only); working tree state matches C.6 (`posthog.ts` sole dirty file); no decision deviation found against D1–D17.

## Verdict: FAIL
(1 HIGH — amendment applied; Pass 2 verifies.)
