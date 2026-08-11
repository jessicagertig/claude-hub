# Shallow Decisions (pre-investigation, non-authoritative)

Captured during brainstorming-plus clarifying questions. These inform the deep investigation but are not yet formally captured via decision-capture protocol.

## Diff check on JD updates
- Diff on alphabetical characters only, stripping HTML, punctuation, numbers, whitespace, formatting
- Threshold TBD (deep investigation)

## Scoring runs per candidate
- Build for 1 run but make the count configurable — easy to switch to 5-run median later without restructuring

## Display sentences (Call 5)
- Separate API call, not combined with scoring call. We haven't tested combining them and don't want to risk degrading scoring quality.

## Scoring-informed role analysis
- Keep existing role_analysis as-is (don't modify the current summary pipeline)
- Add a NEW field that incorporates scoring results
- Two separate outputs — original role_analysis and scoring-aware version. Compare and decide later which to surface.

## Criteria extraction trigger
- Triggers when a job is published (paid plans including trials only)
- Re-triggers when JD content changes (subject to diff check)
- Free plan users: only extract when they purchase AI credits, then process their one published job at that time
- Do NOT extract for free plan users who aren't paying for AI

## Backfill
- Already-published jobs on paid plans need a one-time bulk extraction

## Broadcast
- Single websocket broadcast when BOTH summary and scoring are complete
- Same pattern as existing AI_SUMMARY_COMPLETE
- Intermediate status updates (textract → evaluating → scoring) are nice-to-have, not MVP

## Data model
- Jessica's inclination: separate model for scoring (not on AiJobApplicationSummary). The naming was designed with scoring as a separate concept.
- Open to putting it on AiJobApplicationSummary if investigation shows that's better
- Deep investigation should examine existing models and schema before making this decision
