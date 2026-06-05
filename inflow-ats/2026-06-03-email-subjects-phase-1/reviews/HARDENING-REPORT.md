# Hardening Report -- Email Subjects Phase 1

## Summary

Both spec and impl reviews passed cleanly: zero BLOCKERs, zero HIGHs across all rounds (spec round 1 + 2, impl round 1 + 2). Total MED findings: 9 across all rounds (6 spec, 3 impl). All MEDs were non-functional (cosmetic, naming, style, process). No actual failures occurred.

Three patterns were extracted and added as rules. The remaining findings were one-offs or already covered by existing rules.

## Rules Added

### 1. Emotion theme utilities are complete CSS declarations, not raw values

**Added to:** `~/claude-hub/inflow-ats/CLAUDE.md` under "Known Failure Patterns"

**Motivating finding:** impl-round-2 frontend-contract F1 -- `ChannelMessageTemplateSelectionModal.tsx` line 207 used `font-size: ${t.text.sm};` which produces `font-size: font-size: 0.875rem;` (invalid CSS). The implementation agent treated `t.text.sm` as a raw value when it is a complete CSS declaration.

**Why it's a pattern:** Any agent unfamiliar with the theme API will make this mistake. The variable name `t.text.sm` reads like a size value, not a declaration. This applies to all `t.text.*` utilities and potentially other theme utilities.

### 2. Parallel-field features: trace every pipeline end-to-end before implementing

**Added to:** `~/claude-hub/inflow-ats/CLAUDE.md` under "Known Failure Patterns"

**Motivating finding:** The entire review structure -- both spec and impl reviews verified subject flowed through all 7 channel_message creation paths and 4 distinct pipelines. The implementation got this right because the spec and plan explicitly enumerated every path. Without that enumeration, the risk of missing a path is high.

**Why it's a pattern:** Inflow-ats has multiple messaging pipelines (single-send, bulk, automation, apply-response, inbound). Any feature that adds a parallel field to messages (or any multi-pipeline entity) must thread through all of them. The global CLAUDE.md rule about tracing entire pipelines applies broadly, but this rule is specific to the enumeration-before-implementation discipline needed when the same data shape flows through multiple independent code paths.

### 3. Specs and plans must include test requirements

**Added to:** `~/claude-hub/inflow-ats/CLAUDE.md` under "Known Failure Patterns"

**Motivating finding:** spec-round-1 always-on-checks F2 -- the spec had no test plan section. No tests were created during implementation (test infrastructure was unavailable, which is a valid reason, but it was documented only after review flagged it).

**Why it's a pattern:** Specs without test requirements lead to implementations without tests. Even when test infrastructure is unavailable, the spec should document what tests are needed so they can be added later.

## Existing Rules That Were Validated (Not Violated)

These existing rules were tested by the review and held correctly:

1. **`organization.rb` manual edit rule** (source repo CLAUDE.md: "You may make feature-related changes to `app/models/organization.rb` ... but do NOT fix formatting, linting, or style issues") -- The implementation agent correctly did NOT edit `organization.rb` to add `subject` to `default_channel_message_templates`. The review noted this as an expected manual edit (impl-round-1 seeding-and-defaults F1, excluded from HIGH count).

2. **No bang methods rule** (source repo CLAUDE.md rule #10) -- Existing `create!` in `BulkChannelMessageSendJob` was preserved unchanged. The plan and implementation correctly did not introduce new bang methods.

3. **camelCase/snake_case boundary rule** (source repo CLAUDE.md rule #7) -- All frontend code used camelCase (`applyResponseTemplateSubject`), all backend code used snake_case (`apply_response_template_subject`). Verified across all surfaces.

4. **No `undefined` deliberately set rule** (source repo CLAUDE.md rule #9) -- All defaults used `|| ''` or `|| defaultSubject` patterns. Verified in impl-round-2 frontend-contract check #6.

5. **One params method per controller rule** (source repo CLAUDE.md rule #5) -- All controllers maintained a single params method. Verified in impl reviews.

6. **Guard clauses: bare return rule** (source repo CLAUDE.md rule #8) -- `parse_text` methods used `return '' if text.blank?` (returning a value, not a falsy guard). Existing guards like `return unless id` in `send_candidate_confirmation_email` preserved correctly.

## Findings Skipped (One-Offs, Not Patterns)

### Spec review MEDs (not added as rules):

- **PP-F1** (parse_text signature ambiguity) -- Spec said "keep existing signatures" but the method needed a generalized argument. One-off wording issue specific to this rename. The implementer resolved it correctly.

- **TR-F1** (clean_incoming_message boundary) -- Concern that `clean_incoming_message` might be extended to touch subject. The spec's boundary language ("do not process subject through `remove_bad_line_breaks`") was sufficient. One-off.

- **TR-F2** (.html_safe on subject) -- Concern that `.html_safe` from `html_safe_apply_email` might be copied to subject. The spec's plain-text boundary was sufficient guidance. One-off.

- **FC-F1** (no single-send yup schema) -- The single-send composer had no yup schema; implementer had to create one. This is an implementation-time discovery, not a repeatable planning failure.

- **SD-F1** (legacy NULL subject on edit shows empty) -- UX edge case for legacy template editing. Implementation handled it with `|| defaultSubject` fallback. One-off UI concern.

### Impl review MEDs (not added as rules):

- **impl-round-1 schema-and-migration F1** (migration `def change` vs explicit `def up`/`def down`) -- Style preference. Rails auto-reversibility handles `add_column` correctly via `change`. The `cursor_rules/backend/migrations.md` already covers migration conventions.

- **impl-round-1 frontend-contract F1** (misleading handler name `handleChangeChannelMessageName` used for subject input) -- The handler is a generic `[name]: value` setter that works correctly regardless of which field it handles. The name is misleading but functional. This is pre-existing naming, not something the implementation agent introduced.

### Plan review findings:

- **P1-1, P1-2, P1-3** (line number off-by-ones) -- Navigational aids, no implementation impact. One-offs.
