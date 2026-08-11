# Overnight Iteration Prompt

Paste this after compacting or in a new session from the `2026-06-08-ai-scoring` directory:

---

Read these files in order before doing anything:
1. `HANDOFF.md`
2. `docs/test-scoring/CONTEXT-FOR-ITERATION.md`
3. `docs/test-scoring/ITERATION-PLAN.md`

You are the orchestrator for an overnight scoring iteration session. Your job is to verify and improve a candidate scoring prompt, then run it at scale. You have until 9 AM CST. Do not stop before then unless you run out of API budget.

## Your responsibilities

1. **Score candidates** using the rake task: `rake ai:scoring:score_candidates JOB=teamlead|go VERSION=N BATCH_START=X BATCH_END=Y`
2. **Evaluate quality** by spawning subagents that read the scoring results AND the actual resume text, checking every criterion's reasoning against the resume content
3. **Compare results against ground truth** — only YOU read the ground truth files. Subagents never see them.
4. **Iterate the prompt** if you find patterns of error — one change at a time, then re-run to verify
5. **Scale up** once the prompt is stable

## Ground truth files (you only, never subagents)

- Team Lead: `docs/test-scoring/eyeball-scores-inbox.md`
- Go Engineer: `docs/test-scoring/go-engineer-ground-truth.md`

## Process

### Phase 1: Team Lead Customer Support (20 resumes)

Score inbox-1 through inbox-20 in batches of 5. For each batch:
1. Run the rake task with the current prompt version
2. Spawn a subagent to evaluate: it reads each `inbox-{N}-scores-vX.json` AND the corresponding `inbox-{N}.txt` resume. It checks every criterion: does the reasoning cite specific resume content? Is the score justified? It writes findings to a file.
3. You read the findings AND compare the scores against ground truth
4. If you see a pattern (same error type across multiple resumes), make ONE prompt change to `candidate_criteria_scoring.rb`, re-run that batch
5. Move to the next batch

After all 20: re-run all 20 as regression. Check rankings against ground truth.

### Phase 2: Backend Engineer Go (20 resumes)

Same process with go-{1-20}.txt using JOB=go. This is a completely different domain — the prompt should work without changes. If it doesn't, that tells you something important about the prompt being too domain-specific.

### Phase 3: Scale up

If the prompt is stable after both Phase 1 and Phase 2:

**Team Lead — all 108 inbox resumes:**
Pull remaining resumes from the database (Team Lead Customer Support, Stack 24, inbox stage). Score in batches of 10-20. Save results. Spot-check reasoning on a random sample from each batch.

**Go Engineer — at least 200 resumes:**
Pull resumes from the database (Backend Engineer Go, Convox org 128). Score in batches of 10-20. Save results. Spot-check reasoning.

At scale, you may find new issues. If so, iterate the prompt and re-run the 40-resume regression set (20 Team Lead + 20 Go) before scaling again.

### Phase 4: If time remains

Run nondeterminism tests — score the same 10 resumes 3 times each, measure variance. Write results to a file.

## Rules

- Score 5 at a time during iteration phases. Larger batches only at scale.
- Subagents check EVERY criterion on EVERY resume during iteration. At scale, spot-check a sample.
- Only iterate the prompt for patterns, not one-off judgment calls.
- Fewer rules = better. Do NOT add rules speculatively.
- If results regress after a change, REVERT and try a different approach.
- Sleep between API calls.
- Do NOT use gpt-4o or any expensive models. Stick with gemini-3.1-flash-lite for scoring. Do NOT benchmark against other models tonight — that work is done.
- Save all results to versioned files.
- Write evaluation reports for each batch.
- Keep going until 9 AM CST.
- If you think you're done, check the timestamp: `TZ='America/Chicago' date '+%H:%M %Z'`. If it's before 9:00 AM CST, you are NOT done. Score more resumes, run nondeterminism tests, expand to more candidates. There are 108 Team Lead resumes and 503 Go Engineer resumes — you will not run out of work.
