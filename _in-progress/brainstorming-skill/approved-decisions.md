# Brainstorming Skill — Approved Decisions

This file is the canonical record of design decisions approved during the brainstorming session for the custom brainstorming skill (Jessica's own brainstorming skill, intended to replace reliance on `superpowers:brainstorming`). The file is maintained per Rule 7 of the skill being designed: writes happen at the moment of explicit user approval of a specific presented decision; the file always reflects the most recently approved version of each decision.

## Rule 1 — Imperative tense in spec descriptions of work

Every sentence in the spec that describes work to be done uses imperative verb form. The reader can execute each sentence as an action item without translation or re-interpretation.

Examples of correct form: "Rename `JobApplication#is_active?` to `JobApplication#active?`." "Add `metadata` jsonb column to `job_applications`." "Delete `LegacyApplicationsController` and all of its references in `routes.rb`, `application_controller.rb`, and `spec/controllers/legacy_applications_controller_spec.rb`." "Extract the candidate-decline confirmation step from `CandidateDeclineModal` into a new component file `CandidateDeclineConfirmation` in the same directory." "Replace every occurrence of the string `\"deprecated_status\"` with `\"archived\"` in the files listed below."

This rule forbids:

- **Passive declarative** — "X is renamed to Y," "Column Z is added to T." This describes the end state as if it already exists, which is ambiguous: the reader cannot tell whether the spec is reporting current code or prescribing a change. It also makes diff review harder because verbs like "is" appear identically in spec sentences about current state and spec sentences about future state.
- **Future declarative** — "X will be renamed to Y," "Column Z will be added." This puts a layer of indirection between the spec and the reader's action. The reader must mentally convert "will be done" → "do this." Imperative removes the conversion step.
- **Past tense** — "X was renamed to Y." Wrong category for descriptions of work to be done — past tense describes completed work or history.
- **Hedged or conditional forms** — "X should be renamed to Y," "X needs to be renamed to Y," "we might want to rename X to Y," "consider renaming X to Y." If a decision is settled enough to appear in the spec, the verb is imperative. If it is not settled, it does not belong in the spec yet — it belongs in an open question, a follow-up clarifying question, or a Trade-offs section.
- **Recommendation framing inside the prescriptive body** — "I recommend renaming X to Y" or "the better approach is to rename X to Y." Recommendations live in the Approaches section before the design is locked. Once the design is locked and the spec is being written, recommendations become prescriptions and lose the framing verbs.

Where this rule does NOT apply:

- Background sections describing existing codebase state. Those use present tense for what exists ("the `JobApplicationsController#create` method validates the request body by calling `JobApplicationsValidator.validate`") and past tense for history ("the `legacy_status` column was added in migration 20241015_..."). The rule applies to descriptions of CHANGES, not descriptions of STATE.
- Clarifying questions. Questions are questions, not statements of work.
- The Approaches section where 2-3 options are being weighed. Those options use conditional language because they are not yet decided ("Approach A would rename X to Y; Approach B would alias X and migrate callers gradually").

Where in the brainstorming flow this is enforced: at spec-writing time, with a self-check pass over the spec body before presenting to the user. The skill scans the spec for the forbidden verb patterns (`is renamed`, `will be`, `was renamed`, `should be`, `needs to be`, `might want`, `consider`, `I recommend`, `the better approach is to`) inside any section labeled as work/changes/plan, and rewrites violations to imperative before the user sees the spec.

## Rule 2 — No code blocks; names and identifiers only in spec body

Statement: The spec body contains names and identifiers — file names, class names, model names, method names, function names, column names, route paths, exact string values that appear in the codebase verbatim, and enumerations of files or call sites — but never code blocks, pseudocode, function signatures, or other implementation detail. The spec describes WHAT changes and WHERE; it does not prescribe HOW the code is structured at the line level.

This rule exists because the spec is the source of truth for the design decisions, not for the implementation. Implementation details — the choice of early-return vs nested-if, the use of a guard clause vs a conditional, the formatting of a multi-line method call, the choice of `map` vs `each_with_object`, the exact ordering of attribute assignments — can and do change during implementation without invalidating the design. If the spec embeds those details, every implementation choice that differs from the embedded code becomes a contradiction the reader must reconcile, and the spec stops being a stable reference. The spec must be specific enough to BE the source of truth (it must name which classes are changed, which methods are renamed, which columns are added, which call sites are affected) but must stop short of constraining implementation in ways that legitimately change between draft and final code.

What this rule requires:

- Identifiers and names appear in the spec body wherever the design refers to a specific thing in code. Examples: "Add a `metadata` jsonb column to the `job_applications` table with a default value of `'{}'` and a `NOT NULL` constraint." "Rename the `is_active?` predicate on `JobApplication` to `active?` and update its callers in `JobApplicationsController`, `JobApplicationSerializer`, and the six view files under `app/views/job_applications/`."
- Call-site enumerations appear as lists of file paths with the specific identifier or string being affected. The spec says where to look and what name or string is at play, not what the code at that location should look like after the change.
- Exact string values that appear verbatim in the codebase (status enum values like `"pending_review"`, route paths like `/api/v1/job_applications`, env var names like `DATABASE_URL`, configuration keys) appear in the spec body as those exact strings, in inline backticks or quoted form.
- Structural names of new artifacts the design introduces (a new class name, a new file path, a new column name, a new route, a new mailer, a new validator class) appear in the spec body. The class's body, the file's contents, and any implementation-level detail of the artifact beyond what is essential to the design (such as a column's data type, default value, null constraint, or index) are not specified.
- File names and file paths in any output (spec body, clarifying questions, design presentations, restatements) appear without a trailing period or other sentence-ending punctuation immediately following them. Trailing punctuation on a file path breaks terminal-clickable links. When a sentence would otherwise end on a file path, restructure the sentence so the path is not the final token, or end with whitespace and no punctuation.

What this rule forbids:

- Code blocks in any form. No triple-backtick fenced blocks containing Ruby, TypeScript, SQL, JSON, YAML, shell, or any other language. The spec body has no triple-backtick fences.
- Pseudocode that reads like code, whether or not it is in a code block. Sentences like "the method should look like: if foo then bar else baz end" are forbidden by this rule.
- Function or method signatures, even single-line ones. A line like `def create_engagement_digest(user, window:, sent_at:)` is implementation detail, not design. The design says "introduce a method on `EngagementDigestMailer` that creates an engagement digest for a given user, aggregation window, and sent-at timestamp"; the signature is the implementer's choice.
- JSON, hash, or YAML literals showing example payloads or example return values. The design names what fields a payload contains and what their semantic meaning is; the literal form is implementation detail.
- Type signatures, interface declarations, or TypeScript type definitions. The design names the type or interface; the declaration is implementation detail.
- Embedded SQL beyond the column-level identifiers and constraints essential to the design. "Add `metadata` jsonb with a default value of `'{}'` and `NOT NULL`" is fine because the column name, type, default, and constraint are essential to the design. A full `CREATE TABLE` or `ALTER TABLE` statement is not.
- Code-style decisions. Whether a return is bare or explicit, whether a method uses a guard clause or a conditional, whether attributes are assigned in one line or across separate lines, whether an array literal is wrapped — none of these belong in the spec.

Where this rule does NOT apply:

- The "background" or "current state" section of a spec that describes existing code the design depends on the reader understanding. A short quoted excerpt of existing code with a file path and line numbers is acceptable as background. This is not the spec describing what to build — it is the spec citing what already exists. The excerpt is a quotation of existing reality, not a prescription.
- Clarifying questions during brainstorming. A clarifying question can quote a short code excerpt from the existing codebase to ask about a specific existing line ("the validation at `JobApplicationsController#create:42` calls `JobApplicationsValidator.validate` — is the new validator extracted from that exact call site, or from a different one?"). The excerpt is a reference for the question, not a design statement.
- The approaches-proposal phase, when an approach hinges on a code-shape choice that genuinely distinguishes it from another approach. In that case the approaches section may contrast the code-shape choices to make the distinction concrete. Once an approach is selected, code-shape details that are not part of the design decision drop out before reaching the spec body.

Where in the brainstorming flow this is enforced: at spec-writing time, with a self-check pass over the spec body before presenting to the user. The skill scans the spec body for triple-backtick fences, for sentences that match common pseudocode shapes (`if ... then`, `def `, `function `, `=>` arrow functions, `{...}` blocks outside of inline identifier references), and for embedded SQL, JSON, or YAML literals beyond the column-level constraints carve-out. Violations are either rewritten as names-and-identifiers descriptions or surfaced to the user for resolution before the spec is presented.

## Rule 3 — Precision everywhere

Statement: Every word in every clarifying question and every spec sentence describes its referent specifically enough that a reader can identify it in code or behavior without ambiguity. No aspect of brainstorming or spec writing is exempt — not identifiers, not cases, not behaviors, not data, not conditions, not changes, not artifacts, not anything. Generic terms ("the data," "the response," "handle it," "empty X") are not descriptions. Invented labels that collapse multiple traits into a single phrase are not descriptions. Vague verbs ("process," "manage") are not descriptions. The model derives precise terms from conversation, diff, and codebase. It does not ask the user for terminology that is already evident.

Examples of what this requires (drawn from feature, refactor, and architecture work):

- An identifier in code is referred to by its actual name, not by a category. "`JobApplication#active?`" not "the active predicate"; "`JobApplicationsController#create`" not "the create action"; "`EngagementDigestMailer`" not "the digest mailer."
- A case, scenario, or branch is described by what it actually contains AND the specific condition that distinguishes it. For the weekly engagement digest's "no activity" case: "the email contains the `applications_count` and `messages_sent_count` fields, with both values at 0." Not "the empty email." Not "the zero-activity email."
- A behavior is described by inputs and outputs, in specific terms. "Calling `EngagementDigest.for(user, week)` returns an `EngagementDigest` with `applications_count`, `messages_sent_count`, and `interview_invites_count` aggregated across the given week, with each count being the integer count of records associated with the user during that week." Not "computes the digest."
- A data shape is described by its actual fields and what they hold. "The `metadata` jsonb column stores a hash with keys `source` (string identifying which integration created the record), `external_id` (the source system's primary key as a string), and `legacy_payload` (the raw payload received from the source system, retained for debugging)." Not "extra fields."
- A condition is described by its specific predicate. "When `job_applications.archived_at` is non-null." Not "when archived."
- A change is described by the specific identifier and what specifically changes about it. "Rename the predicate `JobApplication#is_active?` to `JobApplication#active?` and update its callers in `JobApplicationsController`, `JobApplicationSerializer`, and the six view files under `app/views/job_applications/`." Not "rename the active method."
- Questions are formed at the same level of detail the spec will contain about the area being asked about. If the spec will name specific classes, the question asks about specific classes. If the spec will enumerate caller files, the question asks about caller files. If the spec will name specific conditions or attributes or scopes, the question asks for the specific ones. A question more abstract than the spec's eventual detail leaves the spec unsupported (the user never confirmed the specific detail); a question more specific than the spec needs wastes user attention. This applies to clarifying questions, follow-up questions, refinement questions, and any other question form during brainstorming. (This principle was originally drafted as Rule 4 and absorbed into Rule 3.)

What this rule forbids:

- Generic terms that could apply to multiple specific things. "The data," "the model," "the controller," "the response," "the email," "the file," "the job" — forbidden in design statements unless the referent is unambiguous from the immediately surrounding text (typically the same sentence or the prior sentence naming the specific identifier).
- Invented labels that collapse multiple distinct traits into a single phrase. "Empty email," "zero-activity email," "the success case," "the failure case," "the happy path," "the edge case" — forbidden because they hide which fields are at which values and which traits are at play. A case is named by stating its distinguishing condition (which value at which field or input) and what the artifact actually contains.
- Vague verbs in design statements about behavior. "Process," "manage," "handle," "deal with," "support" — forbidden. The verb names what specifically happens: rename, add, delete, extract, replace, aggregate, transform, dispatch, persist, render, validate, enqueue, retry, log, raise.
- Use of words that have specific meanings in the codebase context without naming the specific meaning intended. The word `update` is the canonical example: in a Ruby on Rails context it can mean the HTTP PUT/PATCH method, the `update` controller action that responds to those requests, the ActiveRecord `update` instance method, the `update!` bang variant that raises on validation failure, or a general English "modify" that maps to no specific framework concept. Using `update` in a design statement without specifying which is meant risks downstream misinterpretation. The design statement names the specific intent: "call `record.update(attrs)` from `JobApplicationsController#update`" is precise; "update the job application" is not. The same caution applies to other words that map to specific framework concepts in the relevant codebase.
- Asking the user for terminology that is derivable from context. If the conversation, the diff being analyzed, or the codebase already evidences a precise name for a thing, the model derives that name rather than asking the user to coin one. The model only asks for terminology when the name is genuinely not derivable — for example, when introducing a new concept that has no existing referent anywhere in the codebase or conversation.
- Pronoun references that do not bind unambiguously to the immediately prior sentence's noun. "That," "it," "this" in design statements without an immediately clear and unique referent.

Where this rule does NOT apply:

- Casual conversational acknowledgments ("got it," "noted," "moving on") that do not constitute design content. These can be loose because they do not enter the spec.
- The user's own dictation, which the model does not enforce precision on. The rule constrains the model's output, not the user's input. When the user's input is itself imprecise, the rule fires on the model's next action — which is to surface the imprecision and ask per Rule 5, not to silently absorb it.

Where in the brainstorming flow this is enforced: at multiple points across the flow.

- During clarifying questions: each question, before being sent, is self-checked for precise identifiers and specific referents. A clarifying question that uses a generic term, an invented label, a vague verb, or an unanchored pronoun is rewritten to specific form before sending.
- During approaches-proposal: each of the 2-3 approaches is described in precise terms — specific class names, method names, behavior descriptions, file paths — not in categorical labels ("the simple way," "the heavy way") and not in generic verbs.
- During design-decision presentation (per Rule 7's full-detail format): each presentation is self-checked for precision before sending. Generic terms, invented labels, vague verbs, and unanchored pronouns are rewritten to precise form.
- At restatement-before-write (when Rule 7's restatement protocol fires): the restatement itself is held to precision; a restatement that uses generic terms is rewritten before being sent.
- At spec-writing time: the spec body is self-checked end to end against the lists above. Violations are either rewritten to precise form or surfaced to the user for resolution before the spec is presented.

## Rule 7 — Decision Capture Protocol (per-decision restate-confirm-write)

Statement: When the brainstorming skill captures a decision from the user, it does so via a per-decision restate-confirm-write protocol. The protocol applies wherever a decision is being captured: clarifying questions (Phase 2), approaches selections (Phase 3), section-by-section spec approval if the user chooses that review mode (part of Phase 5), and any modification flow that breaks out of the normal sequence (for example, when the user interrupts mid-brainstorm to change direction, or when the user raises an issue with a spec section during section-by-section review).

A decision concerns one topic and its resolution. The resolution may be a yes or no answer, a selection among alternatives, an open-ended answer the user supplies, or a multi-part answer that genuinely belongs to one topic (for example, naming all five classes in a new module structure is one decision, not five). Presenting 2-3 alternatives for one topic is the correct form for capturing that one decision; it is not bundling.

What this rule requires:

- When the user gives input that resolves a decision (an answer, a selection, a modification), the model restates its interpretation in concrete content. The restatement names the actual values, identifiers, and content of any chosen option — never references like "option C" or "the chosen approach." Example: after the user picks Approach A from a timezone options set, the restatement says "to confirm: we are handling the timezone source in the digest by storing timezone on the `User` model and using that for all engagement emails," not "to confirm: we are going with Approach A."
- The restatement is whatever length the decision requires to be unambiguous. A simple rename may be one sentence ("to confirm: rename variable `x` to `archived_count`"). A multi-class module structure may enumerate every class name and its location. The form serves the content; there is no maximum or minimum length.
- The user then confirms the restatement or corrects it. If corrected, the model restates the corrected understanding. Iterate restate-correct cycles until the user explicitly confirms the model's restatement matches her intent.
- On final confirmation, the skill writes the decision to `approved-decisions.md` immediately, in the same turn as the confirmation acknowledgment, with no gap.
- When the user modifies a previously-confirmed decision (later in the brainstorm), the modified version goes through the same restate-confirm-write cycle; the previous entry in `approved-decisions.md` is replaced with the new approved text.
- When a new sub-decision emerges during the discussion of another, the new one is captured separately, in its own cycle, after the current decision is resolved.

Examples of decision capture flows (illustrating the protocol applied to different decision formats):

**Flow A — Open question with answer interpretation.** Used wherever the model asks an open-ended question that requires interpretation of the user's free-form answer.

Flow: Model asks the question. User answers in free form. Model restates its interpretation in concrete terms — specific class names, specific values, specific behaviors — not the user's exact words but the model's interpretation of what those words mean. User confirms the restatement or corrects it. If corrected, model restates with the correction. Iterate restate-correct cycles until the user confirms the restatement matches what she meant.

Concrete example: model asks "should the new authorization rule apply to internal admin controllers too?" User answers "yeah but only for the read-only ones." Model restates: "to confirm: the new authorization rule applies to internal admin controllers but only those that handle GET requests — specifically `Admin::JobApplicationsController#index`, `Admin::JobApplicationsController#show`, `Admin::CandidatesController#index`, and `Admin::CandidatesController#show` based on the routes file. Not the create/update/destroy actions in those controllers. Confirm?" User confirms, OR corrects (for example: "no, also include `Admin::JobApplicationsController#export`"). If corrected, model restates with the correction and asks for confirmation again. Iterate until concurrence.

**Flow B — Alternatives presented for selection.** Used wherever the model presents 2-3 alternatives for one topic.

Flow: Model presents the alternatives, each described in concrete content. User picks one, asks for a hybrid of two, modifies one, or rejects all. Model restates the resulting selection in concrete content — naming the actual chosen content with all its specifics — never as a reference like "approach A." User confirms or corrects. If corrected, model restates with the correction. Iterate until concurrence.

Concrete example: model presents three timezone-source alternatives for the digest. User says "approach A." Model restates: "to confirm: we are handling the timezone source in the digest by storing timezone on the `User` model and using that for all engagement emails." User confirms. Written to file.

Hybrid variant: User says "A but use it for digest emails only, not all engagement emails." Model restates the hybrid: "to confirm: we are storing timezone on the `User` model and using it for engagement digest emails only; other engagement emails continue to use their existing timezone source (the `Organization`'s primary timezone)." User confirms or corrects. Iterate.

What this rule forbids:

- Bundling multiple SEPARATE topics into one approval moment. Example: "I'm going to split `JobApplicationsController` into a public-facing and an `Admin::` version, move methods `archive`, `bulk_update`, `force_unarchive` to the admin controller, change the route prefix to `/admin/job_applications`, and update `JobApplicationPolicy` to use a new `admin?` predicate — sound good?" — that is four decisions on four different topics (whether to split at all, which specific methods move, the route prefix string, the policy predicate name) bundled into one approval. Each is its own decision.
- Compressing previously-confirmed decisions into a bullet list for a final-review or "lock it" message at the end of brainstorming. Once a decision is in `approved-decisions.md`, the canonical form is the detailed entry there, not a later compressed summary.
- Treating vague affirmation as confirmation. "Sound good?", absence of objection, "ok," "moving on" — these are not confirmations of a specific decision. The skill waits for direct affirmative response, or fires the restatement protocol if the response is ambiguous.
- Moving to spec writing while any captured decision is unconfirmed.
- Restating with references instead of actual content. "We're going with Approach A" is wrong; "we are storing timezone on the `User` model and using it for all engagement emails" is right. The restatement contains the actual content the user is being asked to confirm.

Where this rule does NOT apply:

- Spec writing (Phase 4) — no user input being interpreted; the spec is assembled from `approved-decisions.md`.
- Phase 5 file-read review (the alternative to section-by-section review). When the user chooses to read the spec file directly, she gives feedback at the end as a single response; there is no per-section restate-confirm cycle.
- Casual conversational responses that do not represent decisions or substantive clarifications ("got it," "moving on," "thanks").

Restatement protocol — when it fires and when it does not:

- Fires when the user's affirmation is ambiguous about what is being approved: vague affirmation wording delivered mid-discussion ("that's good," "I like that") without a preceding present-for-approval prompt; pronoun reference ("that one") without an unambiguous referent in the immediately preceding agent message; affirmation arriving in the middle of a multi-part discussion where it could bind to several pending items; any interpretive uncertainty on the model's part about what the user meant.
- Does NOT fire when the immediately preceding agent message was a present-for-approval message containing one specific decision AND the user's response is a direct affirmation of that decision. In that case the originally presented decision is the canonical content; the skill writes it directly to `approved-decisions.md` without restatement.

Sub-clause — surface lingering questions before restating: if the model has any uncertainty about what the user meant by the affirmation, the model surfaces those questions and resolves them with the user before composing the restatement. The model never composes a restatement on a guess in the hope that the user will catch any error.

No hanging decisions: Once the user has confirmed (either directly to a present-for-approval prompt or via restatement re-confirmation) and the skill has written that decision to `approved-decisions.md`, the decision is definitively done. No separate "in-flight," "pending," or "to-be-finalized" status lingers for it anywhere — not in the conversation, not in the agent's tracking, not in any list. The file is the only place "approved" status lives, and any decision contained in the file is by definition approved and final.

Staleness mitigation: The file is updated only at explicit confirmation moments, only with content the user has affirmatively confirmed, and the write happens in the same turn as the confirmation acknowledgment so there is no gap where the file lags behind the conversation. No speculative writes. No status tracking embedded in the file. If at any point the conversation and the file appear to disagree — for example, the user references a previously-confirmed decision that does not appear in the file, or the file contains a decision the conversation has no record of confirming — the skill stops, surfaces the discrepancy by displaying both the conversation reference and the file contents to the user, and asks the user to confirm which is correct before continuing. The skill never silently picks one as authoritative.

Why this rule exists: The spec is the leverage point of the entire design → plan → implementation process. A wrong or vague decision in the spec causes downstream waste in every plan-writing and implementation pass that flows from it. Compressed summaries let details slip past that the user would have caught in the full form. Investing time in per-decision capture upfront pays back in every later phase. The `approved-decisions.md` file makes the leverage explicit by giving the spec doc a direct, mechanical source to assemble from: the spec is not re-derived from conversation memory at the end, it is composed from the file of confirmations that accumulated turn by turn.

## `_in-progress/` directory pattern for working artifacts at both hub and pipeline levels

Statement: `_in-progress/` is a directory naming convention applied at two levels of `~/claude-hub/`:

- At the hub root (`~/claude-hub/_in-progress/`) for cross-pipeline and hub-level working artifacts — things like the brainstorming skill design we are doing right now, new template designs that apply across pipelines, hub-structural experiments, and any other working artifact that is not the responsibility of a single pipeline.
- Inside each pipeline subdirectory (`~/claude-hub/<pipeline>/_in-progress/`) for working artifacts that belong to one specific pipeline — for example, a draft agent specifically for inflow-ats lives in `~/claude-hub/inflow-ats/_in-progress/<artifact-name>/`, not in the hub-root `_in-progress/`.

At either level, each work item gets its own per-item subdirectory inside the relevant `_in-progress/`.

What this requires:

- A working artifact that is hub-level (applies across pipelines, is about the hub itself, or is not the responsibility of a single pipeline) lives in `~/claude-hub/_in-progress/<artifact-name>/`.
- A working artifact that is specific to one pipeline lives in that pipeline's own `_in-progress/` directory at `~/claude-hub/<pipeline>/_in-progress/<artifact-name>/`.
- The user retains complete control of all `_in-progress/` contents: graduating an artifact to its permanent location is a deliberate move (for example moving a finalized skill from `~/claude-hub/_in-progress/brainstorming-skill/` to `~/.claude/skills/` or to `~/claude-hub/_skills/`); deleting an entire `_in-progress/` subdirectory at either level is safe and affects nothing outside that subdirectory.

What this forbids:

- Storing a pipeline-specific working artifact in the hub-root `_in-progress/`. For example, a draft agent specifically for inflow-ats does not live in `~/claude-hub/_in-progress/`; it lives in `~/claude-hub/inflow-ats/_in-progress/`.
- Storing a hub-level working artifact in any pipeline's `_in-progress/`. For example, the brainstorming skill design (which applies across pipelines) does not live in `~/claude-hub/inflow-ats/_in-progress/`; it lives in `~/claude-hub/_in-progress/`.

Scope exceptions: none.

Where this is enforced: through CLAUDE.md updates that put the convention where Claude actually reads it.

- The hub root `CLAUDE.md` gains a new entry describing `_in-progress/` alongside the existing entries for `_templates/`, `_skills/`, and the pipeline subdirs. The entry documents both levels of the convention (hub-root vs pipeline-specific) and the rule for which artifact goes where.
- Each pipeline's `CLAUDE.md` gains a brief note that pipeline-specific working artifacts belong inside the pipeline's own `_in-progress/`, not at the hub root.

## Phase 5 spec review — offer section-by-section or file-read choice

When the brainstorming skill completes spec writing (Phase 4), it offers the user a choice between two review modes on entry to Phase 5:

- **Section-by-section approval.** The skill presents each section of the spec to the user for approval one at a time. Each section approval goes through the per-decision approval mechanic (Rule 7). User-raised issues with a section trigger a modification flow that applies Rule 7's restate-confirm-write protocol.
- **File-read review.** The user reads the spec file directly and gives feedback at the end as a single response. No per-section approval.

The skill asks the user which mode she wants; it does not assume. The default is to ask, not to pick.
