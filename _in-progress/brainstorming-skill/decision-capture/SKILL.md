---
name: decision-capture
description: Use whenever you are about to ask the user a question that decides something — initial design questions, follow-up design refinement, or questions about changes to existing code. Use when capturing decisions through back-and-forth before writing any spec or design doc. Use when tempted to bundle multiple decisions in one message, compress approved decisions into a bulleted list, treat vague affirmation as approval, offer alternatives where only one or two genuinely exist, or write a spec with vague verbs or code blocks instead of exact identifiers.
---

# decision-capture (Decision Capture Protocol)

## Overview

Capture design decisions one at a time: restate the user's input in concrete content → wait for explicit confirmation → write to `approved-decisions.md` in the same agent turn.

**Iron Rule:** No bundling separate decision topics under any pressure. No spec writing while any captured decision is unconfirmed. No skipping the file write.

## When to use

Use any time you are about to ask the user a question that decides something — invoke before asking, so it shapes the question. Question types:

- **Initial design** — questions that shape a new feature, component, or architecture
- **Follow-up design** — refinement or clarification questions on a design in progress
- **Changes to existing code** — questions about modifying, refactoring, or extending code that already exists

Also fires at any moment tempted to bundle decisions, compress approved decisions into a recap, treat "yeah" or "I like that" as approval, or offer alternatives when only one or two genuinely exist.

Not for: single-question factual retrieval, or the act of reviewing and critiquing code itself (that's `code-review` / `receiving-code-review`). But the moment a review turns into deciding a change — a refactor, a follow-up edit — that is a "changes to existing code" decision and this protocol applies before you ask about it.

## Decision scenarios — when to apply the protocol

The protocol fires the moment you are **about to present a decision to the user — before you ask, not after they answer.** It shapes the question itself: one topic at a time, the right kind of question, honest option counts, precise identifiers. It cannot do that if it starts after the user has already responded, so invoke it as you compose what you put in front of them. Recognize the scenario by what you are about to present:

- **About to ask a clarifying question** — invoke before sending; ask one topic at a time, at the level of detail the spec will contain
- **About to present approaches** — invoke before sending; offer alternatives as a set (e.g. an a/b/c choice) only when they genuinely exist, never an invented filler option
- **About to present a spec section for approval** — invoke before sending; one section's decision per approval moment
- **About to reopen a previously confirmed decision** — invoke before raising it; the change re-runs the protocol and replaces that entry in `approved-decisions.md`

Once the user responds, complete the protocol: restate the resolution in concrete content → confirm → write to `approved-decisions.md` in the same turn. Spec writing presents no new decisions — it is assembled from `approved-decisions.md` (see Spec content rules).

## The Decision Capture Protocol

One decision = one topic + its resolution. Resolution may be yes/no, selection from alternatives, open-ended answer, or multi-part for one topic. **Presenting 2-3 alternatives for one topic is NOT bundling**; bundling is multiple separate topics in one approval moment.

Steps:
1. Identify the decision being captured.
2. Restate the user's resolution in concrete content — actual identifiers and values, never references like "Approach A" or "option C."
3. Restatement length scales with the decision (one sentence for a rename; enumerate every class for a multi-class structure).
4. Wait for explicit confirmation. If corrected, restate the correction. Iterate restate-correct cycles until concurrence.
5. On confirmation, immediately write the decision to `approved-decisions.md` in the same agent turn.

**Restatement fires on ambiguous affirmation:** vague mid-discussion wording ("that's good," "I like that"), pronouns without unambiguous referent ("that one"), affirmation in multi-part discussion that could bind to several items, model interpretive uncertainty.

**Does NOT fire** when the immediately preceding agent message was a single-decision present-for-approval prompt AND the user gives direct affirmation — write directly without restatement.

## Forbidden

- Bundling separate topics, even when framed as "tightly coupled" or "these go together"
- Compressing approved decisions into a recap or "lock it" summary
- Treating "sound good?", silence, "ok," or "moving on" as confirmation
- Restating with references ("Approach A confirmed") instead of actual content
- Moving to spec writing with any captured decision unconfirmed
- Asking the user for codebase-discoverable detail without first investigating
- Fabricating a third alternative when only two genuinely exist
- Silent absorption of garbled/dictation-error input (surface parse failures, ask)
- Code blocks, pseudocode, signatures, or JSON literals in spec body
- Vague verbs in spec ("update," "handle," "process," "manage") and invented case labels ("empty email") — use actual identifiers and describe cases by content + condition
- File paths ending with a period (breaks terminal-clickable links)

## Spec content rules

When drafting the spec (Phase 4):

- **Imperative tense for work** ("Rename X to Y"). Not passive ("X is renamed"), future ("X will be renamed"), or hedged ("should be renamed," "consider renaming"). Background/state sections use present tense for existing code.
- **Names and identifiers only.** No code blocks; the spec describes WHAT and WHERE, not HOW the code is shaped at the line level. Implementation details change without invalidating the design.
- **Precision everywhere.** Actual identifiers (`job_application_ai_summary`, not "the summary"). Cases by content + condition (the email where `applications_count` and `messages_received` are 0 — not "the empty email"). Specific verbs (rename, extract, dispatch, persist). `update` only when naming a specific framework concept (the `update` action, ActiveRecord `update`).
- **Question specificity matches spec specificity.** Questions ask at the detail level the spec will contain.

## Investigation

For codebase-discoverable detail (callers, file paths, method signatures, schema, existing patterns), invoke `investigating-before-answering` and present findings for review. The user's review of findings is the confirmation; no separate "are these all?" question. Findings may be written to `investigations/<topic>.md` in the working directory when voluminous.

For intent, scope, or behavioral choice the codebase can't answer, ask an open question.

## Common rationalizations and their counters

Each captured from baseline subagent runs. When you find yourself reaching for one of these, stop and run the protocol.

| Rationalization | Counter |
|---|---|
| "User is frustrated → bundling helps" | Frustration ≠ permission to bundle. If frustration is about non-issues you raised, stop raising non-issues, don't bundle. |
| "Decisions are small/low-stakes → bundle is fine" | Size doesn't qualify. One topic per decision regardless of stakes. |
| "User signaled flexibility on content → can skip protocol" | Flexibility on a decision's content ≠ approval to skip the per-decision protocol. |
| "One-at-a-time is the slow drip frustrating her" | The protocol is the protocol. Reframing it as the problem is the rationalization. |
| "Bundle with recommendations = approve in one pass" | Approval throughput is not the goal. Per-decision capture is. |
| "'Approach C' is just A reworded → pick the direct one (A)" | Both are bundling. Neither is correct. The correct move is one-at-a-time. |
| "Tightly coupled, propose as a unit" | Coupling is implementation property, not decision property. Each topic is its own decision. |
| "User said 'yeah' or 'I like that one'" | Ambiguous. Restatement protocol fires. |
| "Time pressure means shortcut" | Time pressure is the exact moment the protocol matters most. |

## Red flags — STOP and use the protocol

- About to write "sound good?" or "approve these?" with multiple decisions in one message
- About to write "let's lock these in together"
- About to compress recently-approved decisions into bullets for a recap
- About to treat "yeah" / "ok" / "moving on" as definitive approval of one specific thing
- About to write spec content without consulting `approved-decisions.md`
- About to enumerate callers or files from memory that grep could answer
- About to present "Approach C" that is just "Approach A reworded"
- About to absorb a garbled user phrase as if it parsed
- About to use "the summary" / "the controller" when a specific identifier exists
- About to write a code block in spec body

## File mechanics

- Path: `approved-decisions.md` in the brainstorm's working directory (a subdir under `_in-progress/`)
- Each decision: heading + full content as presented and approved
- On modification: restate, re-confirm, replace the section
- On file/conversation disagreement: stop, surface both, ask which is correct
- Spec assembly in Phase 4 reads from this file; no spec content arises that wasn't in the file

## Required sub-skill

`investigating-before-answering` — for all codebase-investigation moments. Its discipline (read every identifier's definition, file-read floors, area-specific rule reads, three-examples minimum for pattern claims) makes investigation thorough enough to be relied upon.
