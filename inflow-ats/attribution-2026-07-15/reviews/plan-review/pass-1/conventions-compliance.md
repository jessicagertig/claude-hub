# Conventions Compliance — Pass 1

Note: the REVIEW-ANGLES fan-out (one reviewer per cursor_rules file) applies to the IMPLEMENTATION diff at Phase 6/6.5. At plan review the check is: does the plan's prescribed code comply with the rules it will be reviewed against, and does the plan direct the implementer to the right rules files per task.

## Rules-file directives in the plan

Every task carries a `_Read first:_` line naming the relevant cursor_rules files (B1–B7, F1–F8, T1–T2). Spot-checked against the angle list in REVIEW-ANGLES.md — coverage matches (migrations.md, controller_patterns_and_crud.md, pundit_policies.md, _base.md, code_style_and_structure.md, react_hooks.md, forms/*, react_query/*, component_architecture.md, boolean_variables_and_naming.md, core_critical_rules.md rule callouts).

## Per-rule check of the plan's verbatim code

| Rule | Check | Result |
|---|---|---|
| core 1 (no begin blocks in controllers) | No new rescue/begin anywhere | ✓ |
| core 5 (one params method) | No new params methods; `sign_up_params` extended in place | ✓ |
| core 7 (snake_case/camelCase; enum exception) | camelCase payload fields; snake wire via `allKeysToSnake`; SSO inputs snake on purpose (form POST bypasses the API layer); `utm_data` inner keys raw = approved deviation 4 (D2) | ✓ |
| core 8 (bare guard returns) | F6.2 `if (!emailConfirmed) return;` is JS (rule is Ruby-scoped); no new Ruby guards | ✓ |
| core 9 (never deliberately set undefined) | F3.3/F4.3 pass `trackingParams.utmSource` etc. as direct property reads — the rule's "pass values directly" form; nothing conditionally set to undefined | ✓ |
| core 10 (never fabricate fallbacks) | Helper has no `\|\| ""`/`\|\| {}`; `utmData` only when non-empty; nil-for-absent at every layer | ✓ |
| core 11 (no bang methods; spec exception) | `create!`/`update!`/`.tap(&:confirm)` confined to specs | ✓ |
| core 12 (check save returns) | No new saves; B4 copy lines feed the existing `if @organization.save` | ✓ |
| core 13 (strict comparisons; loose only vs undefined) | F5.2 `utmData != undefined` = house form; F6.2 `id != undefined && email != undefined` = house form; F1.2's `!== undefined` is a DELIBERATE, documented deviation (null must count as present — spec §5.1) with an explicit do-not-"fix" note for reviewers | ✓ pre-justified |
| core 2a (window.logger encouraged) | posthog.ts diff + existing loggers untouched | ✓ |
| backend string quoting (single unless interpolating) | B7.1 double-quoted interpolated redirect ✓; migrations use symbols only ✓ | ✓ |
| frontend double quotes | All TSX/JS blocks double-quoted | ✓ |
| migrations.md shape | Plain `add_column`, frozen_string_literal, `[6.1]`, timestamped names, no data migration | ✓ |
| pundit_policies.md | `authorize @organization` untouched; no policy edits | ✓ |
| Files-never-edit list | api.ts, contexts, organization.rb all on the plan's Do-NOT-touch list | ✓ |
| Variable naming for records | Spec code uses `user`, `organization` for User/Organization records — full-model-name snake_case | ✓ |

## Pipeline rules (~/claude-hub/inflow-ats/CLAUDE.md)

- Rule 15 (review committed code): implementation-order step 5 mandates commit before review ✓
- Rule 26 (ghost tests): explicit anti-ghost design section ✓ (see test angle)
- Rule 27 (per-rules-file fan-out): honored by REVIEW-ANGLES angle 7 for Phase 6; plan doesn't subvert it ✓
- Rule 6 (rename cascades): B6.3 census + re-grep after converting ✓
- Rule 10/23 (fix-agent scope): N/A at plan stage; Do-NOT-touch list guards it ✓

## Findings

- F4 [LOW] plan.md "Files to create or modify" header says "(7 backend + 8 frontend + schema)" but the itemized list is 6 backend files (items 9–14), 8 frontend files (15–22), plus `db/schema.rb` (23) and `posthog.ts` (24); the Estimated-scope section itself says "6 backend files edited". Also "Total: ~10 modified files" vs 16 itemized. Cosmetic count drift; the itemized list is authoritative and correct. Fix: correct the header and total.
- F5 [LOW] The phase checklist item "independent steps are marked as parallelizable" is unmet — the plan gives a strict sequential order with no parallel markers. The order given is safe and dependency-correct; sequential execution is the conservative reading. Noted, no amendment (marking parallelism is optional guidance, and the fully-ordered plan loses nothing but wall-clock time).

## Amendments Applied

- plan.md "Files to create or modify" header: corrected to "(6 backend + 9 frontend incl. posthog.ts + schema)".
- plan.md Estimated scope: "Total: ~10 modified files" → "Total: 16 modified files".
