# Call 4 Scoring — Iteration Plan

## HOURS

Do not stop until 9:00 AM CST or until you run out of API budget. If it's not 9 AM and there are more resumes to check, keep going. There are 108 resumes for the Team Lead job and 503 for the Backend Engineer job. You will not run out of work.

## Current prompt state

File: `app/services/ai_job_application_action/scoring/prompts/candidate_criteria_scoring.rb`
Model: gemini-3.1-flash-lite
Provider: gemini
Enum: full_match / partial_match / not_found
One special rule: years of experience in a specific domain (tiered guidance)
Reasoning: must cite specific examples from the resume

## Scoring math

Compute this for every resume scored. Include it in the output.

```ruby
tier_weights = { 'tier_1' => 6, 'tier_2' => 4, 'tier_3' => 2 }
score_values = { 'full_match' => 1.0, 'partial_match' => 0.5, 'not_found' => 0 }
max_score = criteria.sum { |c| tier_weights[c['tier']] }
points = scores.sum { |s| tier_weights[s['tier']] * score_values[s['score']] }
percentage = (points / max_score * 100).round(1)
```

Physical criteria (lift, carry, sit and use, manual dexterity) are excluded before scoring.

## Test data

### Job 1: Team Lead, Customer Support (Remote) — Stack 24
- 108 inbox resumes with textract results
- 20 already sampled at `docs/test-scoring/inbox-{1-20}.txt`
- Eyeball scores at `docs/test-scoring/eyeball-scores-inbox.md`
- Previous AI results: v3 (minimal prompt), v4 (current prompt with full_match/partial_match enum)
- JD criteria extraction at `docs/test-scoring/team-lead-extraction.json`

### Job 2: Backend Engineer (Go) — Convox, org 128
- 503 resumes with textract results
- NOT YET EXTRACTED — must run Call 1 + Call 2 on the JD first
- No eyeball scores — this is a blind test
- Jessica's colleague posted this job and can validate results

## Phase 1: Team Lead Customer Support — iterate on the 20

### Process: 5 resumes at a time

**Batch 1**: inbox-1 through inbox-5
**Batch 2**: inbox-6 through inbox-10
**Batch 3**: inbox-11 through inbox-15
**Batch 4**: inbox-16 through inbox-20

For each batch:
1. Score 5 resumes
2. For EACH resume, for EACH criterion: read the actual resume text and verify the score + reasoning
3. The reasoning must cite specific content from the resume. "The candidate has experience" is not acceptable.
4. Flag issues. Classify: pattern or one-off?
5. If pattern: make ONE prompt change. Re-run same 5 to verify. Check for regressions.
6. Move to next batch.

After all 4 batches: re-run all 20 as regression. Compare final ranking against eyeball scores.

### Then: expand to all 108

Pull remaining 88 resumes. Score in batches of 10-20. Analyze distribution. Flag outliers. Spot-check reasoning on a random sample.

## Phase 2: Backend Engineer (Go) — new job, blind test

1. Run Call 1 + Call 2 on the Backend Engineer JD. Save extraction.
2. Sample 20 resumes from the 503, spread evenly. Save to files.
3. Score with the prompt that passed Phase 1. No domain-specific changes.
4. Evaluate same as Phase 1 — every criterion, every resume in batches of 5.
5. If issues, iterate. If the prompt needs Go-specific rules, something is wrong — the prompt should be domain-agnostic.
6. Expand to 200+ once the 20 look good.

## What constitutes an issue worth iterating on

### ITERATE if:
- Full_matches that can't be backed by specific resume content
- Not_founds where evidence clearly exists in the resume
- Reasoning that doesn't cite resume content (vague summaries)
- Domain confusion (general experience scored as domain experience)
- Same type of error repeating across the batch

### DO NOT ITERATE if:
- Single borderline judgment call where reasonable people could disagree
- Nondeterminism (re-run produces different result — model-level, not prompt-level)
- Non-English resume scoring differently — language is a separate concern

## Critical lessons from overnight Call 2 iteration

These apply equally to Call 4:

1. **Fewer rules = better results.** The minimal prompt massively outperformed the strict prompt. Do NOT add rules speculatively. Only add a rule when forced to by a clear pattern of failure.

2. **If results regress after a prompt change, consider reverting to a simpler prompt and changing only the specific rule you're focused on.** Don't pile fixes on top of a regression.

3. **Renaming categories in the enum produced excellent results with zero other changes.** Changing "matched" to "full_match" and "partial" to "partial_match" improved scoring quality. Small framing changes can have outsized impact. Consider framing before adding rules.

4. **The model's own judgment is often correct.** The review agent flagged 22 issues; upon closer inspection by Jessica, many were actually correct scores that the reviewer misjudged. Trust but verify.

5. **Test against TWO different job types.** A prompt that works on customer service but fails on engineering is too domain-specific. The Backend Engineer job is the generalization test.

## File conventions

- Scoring results: `inbox-{N}-scores-v{VERSION}.json` (Team Lead) or `go-{N}-scores-v{VERSION}.json` (Backend Engineer)
- Evaluation reports: `scoring-v{VERSION}-evaluation.md`
- Criteria extractions: `team-lead-extraction.json`, `go-engineer-extraction.json`
- Resumes: `inbox-{N}.txt` (Team Lead), `go-{N}.txt` (Backend Engineer)

## What success looks like

- Top candidates consistently score 75%+
- Bottom candidates consistently score below 40%
- Middle candidates land between 40-70%
- Reasoning cites specific resume content
- No systematic false positive or false negative patterns
- Ranking order roughly correlates with eyeball scores (Team Lead)
- Backend Engineer produces reasonable results without prompt changes
- The prompt has minimal rules — ideally fewer than 10 lines of instruction
