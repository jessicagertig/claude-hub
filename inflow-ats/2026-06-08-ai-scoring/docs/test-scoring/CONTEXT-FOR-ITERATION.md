# Context for Call 4 Scoring Iteration

This file captures the nuanced reasoning from the design session that files alone don't convey. Read this BEFORE starting iteration.

## The most important lesson

**Fewer rules = better results.** We tested three versions:
- v1 (strict, many rules): scored poorly. Penalized strong candidates.
- v3 (minimal, almost no rules): massive improvement. Top candidates scored 90%+, weak ones scored low.
- v4 (minimal + two targeted rules): further improvement.

The prompt is intentionally bare. Do NOT add rules speculatively. Only add a rule when you see the SAME error on multiple resumes.

## How we got here

The scoring prompt went through this evolution:
1. Started with many rules: "don't credit self-assessment", "count years from dates", "tools must match exactly"
2. These rules made the model too strict — it wouldn't credit "managed a team of 14" as evidence of leadership
3. Jessica said: strip it all out, start with almost no rules
4. The minimal prompt worked dramatically better
5. We added back TWO rules only:
   - Multilingual ≠ communication skills (saw this error on multiple resumes)
   - Years of experience domain guidance (tiered: domain experience = full_match, adjacent with significant duties = partial_match)
6. We renamed the enum from matched/partial/not_found to full_match/partial_match/not_found — this alone improved results

## What the prompt says now

Almost nothing. Read the actual file: `app/services/ai_job_application_action/scoring/prompts/candidate_criteria_scoring.rb`

It says:
- Here are criteria, here's a resume, score each one
- full_match / partial_match / not_found
- Cite specific examples from the resume in reasoning
- Multilingual ≠ communication skills
- Years of experience domain guidance

That's it. Do not add more unless forced.

## What the agent should do when evaluating

For each criterion on each resume:
1. Read the AI's score (full_match / partial_match / not_found)
2. Read the AI's reasoning
3. Read the actual resume text
4. Check: does the reasoning cite specific content from the resume?
5. Check: is the score justified by what's actually in the resume?

Do NOT:
- Judge based on what stage the candidate was in
- Judge based on what you think the candidate's overall quality is
- Add domain-specific rules (this prompt must work on any job type)
- Treat soft skills differently than hard skills in the prompt

## Architecture: orchestrator + subagents

The main session agent is the orchestrator. It:
- Reads ground truth files
- Kicks off subagents to run scoring and evaluate reasoning
- Compares subagent results against ground truth
- Decides whether to iterate the prompt

Subagents:
- Run the scoring rake task
- Evaluate reasoning quality (check every claim against resume text)
- Do NOT read ground truth files — they score and evaluate blind

Ground truth files (orchestrator only):
- Team Lead: `eyeball-scores-inbox.md` (Jessica reviewed 5: inbox-3, 8, 9, 13, 17)
- Go Engineer: `go-engineer-ground-truth.md`

## The two jobs

### Team Lead, Customer Support (Stack 24)
- 20 resumes: inbox-{1-20}.txt
- Criteria: team-lead-extraction.json
- 5 benchmark resumes reviewed by Jessica: inbox-3, inbox-8, inbox-9, inbox-13, inbox-17
- Previous results: inbox-{N}-scores-v3.json (minimal), inbox-{N}-scores-v4.json (current)

### Backend Engineer Go (Convox)
- 20 resumes: go-{1-20}.txt
- Criteria: go-engineer-extraction.json
- Ground truth: go-engineer-ground-truth.md (FOR JESSICA ONLY — do not use during evaluation)
- No previous scoring results — this is a fresh test

## Rake task

```
rake ai:scoring:score_candidates JOB=teamlead VERSION=5 BATCH_START=1 BATCH_END=5
rake ai:scoring:score_candidates JOB=go VERSION=1 BATCH_START=1 BATCH_END=5
```

Scores 5 at a time. Saves results with computed percentage. Retry logic built in.

## Physical criteria

Exclude before scoring: lift, carry, sit and use, manual dexterity. The rake task does this automatically.

## Duplicate criteria

Exclude criteria with duplicate: true. The rake task does this automatically.

## Scoring math

- tier_1: 6 points (full = 6, partial = 3, not_found = 0)
- tier_2: 4 points (full = 4, partial = 2, not_found = 0)  
- tier_3: 2 points (full = 2, partial = 1, not_found = 0)
- Percentage = points / max_possible × 100

## When to iterate the prompt

Only if you see the SAME type of error across multiple resumes in a batch. Examples of real errors we found:
- Model treated "multilingual" as evidence of communication skills (fixed — added rule)
- Model treated 14 years of admin experience as "5+ years of customer service" (fixed — added domain guidance)
- Model gave vague reasoning like "the candidate has experience" without citing resume content (fixed — added "cite specific examples")

Examples of things that looked like errors but weren't:
- "Excellent organizational skills" scored full_match for an Office Manager — Jessica confirmed this is correct
- "Excellent leadership skills" scored full_match for someone with Lean leadership training — Jessica confirmed this is correct
- Soft skills scored from self-described profile summaries WITH supporting job responsibilities — acceptable

## If results regress after a prompt change

REVERT to the simpler version. Then try a different approach to the rule. Earlier, just renaming the enum categories (matched → full_match) produced better results than adding rules.
