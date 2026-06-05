# Hardening Report — Weekly Engagement Digest
**Date:** 2026-06-03

## Rules Added

### Pattern #4: ActionMailer calls require `.deliver_now` or `.deliver_later`

**What went wrong:** `WeeklyDigestJob` called `WeeklyDigestMailer.weekly_digest(...)` without chaining `.deliver_now`. Rails returned a lazy `MessageDelivery` object and the mailer method body never executed. The email was silently never sent.

**Why the agent made this mistake:** The implementing agent wrote the mailer call without the delivery method. The job spec stubbed the mailer at the class level (`allow(WeeklyDigestMailer).to receive(:weekly_digest)`) which returned a generic double, masking the fact that `.deliver_now` was never called. The Round 1 reviewer actually noticed the deviation from existing callers (which all use `.deliver_later`) but classified it as MED and dismissed it as "functionally correct because the mailer method calls SendTemplateEmail#send directly as a side effect" -- which is wrong, since the method body never runs without a delivery call.

**Why this recurs:** ActionMailer's lazy evaluation is a well-known Rails footgun. The method name looks like it should do something, and it does return an object (not nil), so tests that only verify the class method was called will pass. Every existing caller in the codebase handles this correctly, but a new caller has no guardrail against omitting it.

**Motivated by:** impl-round-2 BLOCKER + HIGH

### Pattern #5: Full-stack feature specs must list all modified files, not just new files

**What went wrong:** The spec listed new files to create but omitted two existing files that needed modification: `MeController` (needs `settings_params` permit change for `email_weekly_digest`) and the `UserSettings` TypeScript interface (needs `emailWeeklyDigest: boolean`). Without these, the preference toggle would silently fail at the backend permit layer and lack type safety on the frontend.

**Why the agent made this mistake:** When specifying a new feature, it's natural to focus on what's being created. Modifications to existing files are less visible -- you have to trace the new field through every layer the analogous existing fields already flow through. The agent traced the new-file side but didn't systematically trace the modification side.

**Why this recurs:** Every full-stack feature in a Rails+React app touches both new files and existing files. The existing-file modifications are where things silently break (a missing permit key drops the value; a missing TS type lets bad data through). This is the same class of problem as Pattern #2 (parallel-field tracing), but applies more broadly to any feature that adds to existing pipelines.

**Motivated by:** spec-round-1 HIGH x2 (MeController, UserSettings)

## Existing Rules That Were Violated

### Pattern #3 (specs must include test requirements)

The spec initially had no test requirements section. This was caught as a BLOCKER in spec-round-1 and fixed before implementation. The rule already existed because the same failure happened during email-subjects-phase-1. The rule worked as intended -- the reviewer caught it -- but the spec-writing agent still did not include tests unprompted. This suggests the rule needs to be surfaced earlier in the spec-writing prompt, not just in the review checklist.

## Findings Skipped as One-Offs

### Spec: deploy-order constraint for JSONB column replacement

The spec review flagged that `MeController#update_settings` uses `ActiveRecord#update` which does full JSONB column replacement. If the backend permits `email_weekly_digest` before the frontend sends it, any preference save silently deletes the key. This is specific to the settings mechanism's architecture (full replacement vs merge) and was correctly caught by the spec review. Not adding a rule because: (a) the deploy-order constraint was documented in the spec after Round 1, (b) this is specific to the `update_settings` pattern, not a general class of mistake, and (c) the fix (deploy together) is standard practice for tightly-coupled frontend+backend changes.

### Impl Round 1: MED findings

Three MED and two LOW findings from impl-round-1 were all informational/cosmetic and not blocking. None represent patterns likely to recur as real failures.
