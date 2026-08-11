# AI Scoring Feature Design — Handoff

## Where we are

Brainstorming-plus in progress. Completed:
1. Working directory established
2. Vague scope agreed
3. Rough outline agreed (8 components)
4. Shallow clarifying questions done

Next step: **deep investigation** scoped by the rough outline, then **invoke decision-capture** skill, then continue with approaches and design sections.

## Files in this directory

All at `~/claude-hub/inflow-ats/_in-progress/ai-scoring-feature-design/`:

| File | What it is |
|------|-----------|
| `vague-scope.md` | Agreed scope — backend for unified AI candidate evaluation |
| `rough-outline.md` | 8 components to design |
| `shallow-decisions.md` | Pre-investigation decisions from clarifying questions |
| `scoring-pipeline-current-state.md` | Current state of all prompts, models, config, results |
| `decision-journey.md` | How we got to each decision, what we tried, mistakes not to repeat |
| `textract-ai-summary-map-6-6-2026.md` | Existing Textract/AI summary orchestration map (may not be fully accurate) |
| `prompts/` | Copies of all prompt files, providers, and ai_client.rb as of 2026-06-11 |
| `SCORING-COST-ESTIMATE.md` is at `~/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/test-scoring/SCORING-COST-ESTIMATE.md` |

## What the next session needs to do

1. **Read all files in this directory** — especially `shallow-decisions.md`, `rough-outline.md`, and `decision-journey.md`
2. **Read the source repo's CLAUDE.md** and relevant `cursor_rules/` files
3. **Invoke `brainstorming-plus` skill** — we are mid-process. Resume from the deep investigation step (checklist item 4). The vague scope, rough outline, and shallow clarifying questions are done.
4. **Deep investigation** — exhaustive inventory of existing code for each of the 8 outline components:
   - Job model lifecycle (publish, update, callbacks)
   - AiJobApplicationSummary model and schema
   - Generate service (the 4-call summary pipeline)
   - GenerateAiJobApplicationSummaryJob and its trigger chain
   - TextractResult bridge to AI summary
   - Serializers (shallow + full)
   - API controllers for AI summaries
   - Sidekiq queues, rate limits, concurrency
   - Flipper feature flags for AI features
   - AiApiRequest model (cost tracking)
   - AiClient and providers
   - Websocket broadcast pattern (GlobalChannel)
   - Plan/subscription/billing gates
4. **Invoke decision-capture** skill after investigation
5. **Continue brainstorming-plus** from "Propose 2-3 approaches" step

## Key context

- **Pipeline decided:** Call 1 (gpt-4.1-mini) → Call 2 (gpt-4o) → code heading override → Call 4 (Gemini scoring, configurable runs) → Call 5 (Gemini display sentences). No judge/decomposer.
- **Partial match weight:** 0.7
- **Jessica's inclination:** separate model for scoring data, not on AiJobApplicationSummary
- **Scoring-informed role analysis:** new field alongside existing role_analysis, not replacing it
- **Broadcast:** single websocket when both summary and scoring complete. Intermediate status nice-to-have, not MVP.
- **Trigger:** on job publish (paid plans + trials only). Re-extract on meaningful JD change (diff on alphabetical characters only). Free plan: extract only when AI credits purchased.
- **Old scores stay:** scored against criteria at time of application. No invalidation on JD change.
- **Spike branch:** `spike/scoring-display-prompt` has the display prompt file

## Don't repeat these mistakes

Read `decision-journey.md` "Mistakes Made" section. Key ones:
- Always save complete API response data
- Never use test data as prompt examples
- Don't change methodology or add rules without explicit direction
- Don't present speculation as fact
- Do exactly what's asked, don't over-scope
