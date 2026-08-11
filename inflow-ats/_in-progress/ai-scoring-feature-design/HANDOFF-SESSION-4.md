# AI Scoring Feature Design — Session 4 Handoff

## Where we are

Spec written, adversarial review complete (4 rounds, 2 consecutive clean passes). Jessica is reviewing the spec and review angles before proceeding to planning.

## Branch

`feature-ai-summaries-integrating-scoring-v3` in `/Users/jessica/wrk/wrk-corp/inflow-ats`
Branched from: `feature-ai-credits-summaries-scoring-qa-qa`

## Files in the working directory

All at `~/claude-hub/inflow-ats/_in-progress/ai-scoring-feature-design/`:

| File | What it is |
|------|-----------|
| `SPEC.md` | The spec — amended by 4 rounds of adversarial review |
| `approved-decisions.md` | All captured design decisions (8 sections) |
| `reviews/REVIEW-ANGLES.md` | 7 review angles + 5 always-on checks |
| `reviews/spec-round-1/` through `spec-round-4/` | Per-round adversarial review findings |
| `reviews/SPEC-REVIEW-COMPLETE.md` | Completion record |
| `investigation-results.md` | Deep investigation of existing codebase (5 agents) |
| `scoring-pipeline-current-state.md` | Current state of all prompts, models, config |
| `decision-journey.md` | How each pipeline decision was reached |
| `textract-ai-summary-map-6-6-2026.md` | Existing Textract/AI summary flow map — critical reference |
| `branch-notes.md` | Changes on the branch that aren't part of the scoring spec |
| `vague-scope.md` | Agreed scope |
| `rough-outline.md` | 8 components |
| `shallow-decisions.md` | Pre-investigation decisions |
| `prompts/` | Copies of all prompt files (including deleted ones) |
| `REPO-PATH` | Points to `/Users/jessica/wrk/wrk-corp/inflow-ats` |

## What was committed to the branch

See `branch-notes.md` for full details. Summary:
1. `retrying: 7` status added to `AiJobApplicationSummary` enum
2. `GenerateAiJobApplicationSummaryJob` — exhaustion block, no intermediate broadcasts
3. `Summary::Generate` — sets `retrying` on `CustomErrorAiSummary`, `retrying` in reuse list
4. Unused scoring prompt files deleted (saved to `prompts/`)
5. `candidate_criteria_scoring.rb` renamed to `job_application_scoring.rb` (class + rake references)
6. MODEL constants pinned to API-returned versions
7. AiClient PRICING hash keys updated to match API-returned model names
8. `ai_scoring_expansion.rake` deleted
9. Bulk frontend refactor (controller, modal, hook — from stash)
10. Data migration made reversible (from stash)
11. OpenAI provider `temperature: 0` (from stash)

## QA harness hardening (committed to hub, not source repo)

Three files updated with "analog structural matching" as BLOCKER severity:
- `~/claude-hub/inflow-ats/CLAUDE.md` — Known Failure Pattern #14
- `~/claude-hub/inflow-ats/features/generate-review-angles-prompt.md` — always-on check
- `~/claude-hub/features/qa-prompt.md` — Layer 2 check #7

All three have inline examples (bulk controller params, missing exhaustion block) — no references to other files.

## What the next session needs to do

1. **Read `SPEC.md`** — Jessica is reviewing it
2. **Read `reviews/REVIEW-ANGLES.md`** — Jessica reviewing these too
3. **Address any feedback** Jessica has on the spec or angles
4. **After spec approved** → invoke `writing-plans` skill to create implementation plan
5. The brainstorming-plus checklist is at step 10 (user reviews spec) — step 11 is invoke `writing-plans`

## Key design decisions (summary)

- **No separate scoring table** — scoring data (`score_percentage`, `criteria_results`, `integrated_role_analysis`) lives on `AiJobApplicationSummary`
- **Two new tables:** `ai_job_criteria` (per-job) and `ai_job_application_summary_statuses` (lightweight read model per-application)
- **Redesigned status enum** on `AiJobApplicationSummary`: 11 values (pending through failed), `succeeded` = terminal = full pipeline done
- **`retrying` status** — on `CustomErrorAiSummary`, set `retrying` and raise. Record reused on retry. `failed` only on exhaustion or non-retryable error. One broadcast per evaluation.
- **Orchestrator** (`AiJobApplicationAction::Orchestrate`) replaces the single `generate_ai_summary` call inside `TextractResult#generate_ai_summary_with_credit_flow`. Status checkpointing for resume.
- **Four scoring services:** `ExtractCriteria`, `ScoreJobApplication`, `Calculate`, `IntegrateAnalysis`
- **Job lifecycle:** `extract_job_criteria` on publish, `handle_description_change` on JD update, 2-minute debounce, `pending` gate
- **`textract_result_id` stays** as the job parameter — don't break the mapping
- **1 credit for the entire evaluation** — consumed only at `succeeded`
- **Same Flipper flag** `:AI_APPLICANT_SUMMARY`

## Don't repeat these mistakes

- Don't use `git stash pop` — always `git stash apply`
- Don't present integer enum values as search targets — Rails uses symbol names
- Don't say "replaces the internals" when it replaces one method call
- Don't bundle multiple decisions in one message
- Don't ask "what do you want to do next"
- Restate decisions with full detail, not abbreviated summaries
- Use actual identifiers, not vague labels
- Investigate before claiming — read the actual code
