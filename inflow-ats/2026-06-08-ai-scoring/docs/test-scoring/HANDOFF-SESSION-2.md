# AI Scoring — Session 2 Handoff

## What happened this session

Started with overnight scoring results (865 resumes scored, v7 prompt stable). Jessica reviewed the Go Engineer ground truth results and found multiple issues with the extraction and scoring. We spent the session fixing Call 1, Call 2, adding Call 2b, and iterating on the scoring prompt.

## Current state of every prompt file

### Call 1 — Section Decomposition
**File:** `app/services/ai_job_application_action/scoring/prompts/job_description_structured_data.rb`
**Model:** gpt-4.1-mini (changed from gpt-4o-mini — better instruction adherence, 10/10 on sub-heading detection vs 4/10)
**Changes this session:**
- Added sub-heading detection: "When a section has sub-headings, split into separate sections. Set heading to parent - sub joined with ' - '"
- Added heading examples list (Required, Must Have, Nice to Have, Bonus, etc.)
- Added "A sub-heading can appear immediately after a section heading with no content between them"
- Added structural trigger: headings can be "short text that is the sole content of a block-level element (p, div, or li)"
- Added urgency: "It is essential that you correctly identify sub-headings. This is the foundation for a scoring system."
- Removed merge rule that was fighting decomposition splits
- Added sub-heading verification to checklist
- Added `title_technology` field to schema and prompt

### Call 2 — Criteria Extraction
**File:** `app/services/ai_job_application_action/scoring/prompts/job_description_criteria_extraction.rb`
**Model:** gemini-3.1-flash-lite (unchanged)
**Changes this session:**
- Added soft skills exception: "EXCEPTION to heading lock AND inline signals: Soft skills are never tier_1." Lists: communication, organizational skills, time management, cross-functional collaboration, teamwork, problem-solving, critical thinking, decision-making, adaptability, flexibility, attention to detail, self-motivation, interpersonal skills, conflict resolution, creative thinking, multitasking, prioritization, mentoring. Leadership is NOT in this list (it's demonstrable, not a soft skill).
- Added self-review section at end: "After extracting all criteria, adversarially review your own tier assignments. Check every criterion against the soft skills exception."
- Replaced bad decomposition examples (the old "5+ years including frontend and backend" and "8+ years fundraising ideally in social sector" were not real compounds). New examples: communication + word processing + report writing; TypeScript + React; communication + software understanding; enterprise selling + domain preference.
- Added `contains_title_technology` boolean field per criterion
- Added `title_technology` parameter to messages method
- Changed "and/or" in do-not-decompose to just "or" (the "and/or" was making models afraid to decompose "and" constructions)

### Call 2b — Criteria Review (decomposition)
**File:** `app/services/ai_job_application_action/scoring/prompts/criteria_review.rb`
**Model:** gemini-3.1-flash-lite
**Purpose:** Reviews Call 2 output. Decides keep/decompose for each criterion. Does the decomposition itself.
**Current state:**
- Adversarial framing: "You are reviewing another model's work. Your job is to find compounds it missed."
- Reasoning step: "Before producing any output, go through criteria one at a time..."
- Decision schema: action = "keep" or "decompose", with reasoning and decomposed array
- Full JSON input (not formatted text summary)
- Has all 11 decomposition examples we agreed on
- Has "split on skills not verbs" rule
- Has do-not-decompose examples (Google Workspace, productivity tools list)
- Receives title_technology parameter
- **Known issues:**
  - Truncates output on JDs with 30+ criteria (5 of 49 JDs lost criteria)
  - Decomposition is nondeterministic: Go gets 1-5 decompositions per run, Team Lead gets 0-3
  - Decomposed criteria text varies each run even for the same criterion

### Call 2b Decomposer (NOT IN USE)
**File:** `app/services/ai_job_application_action/scoring/prompts/criteria_decomposer.rb`
**Model:** gpt-4.1-mini
**Status:** Built for two-step pipeline (Gemini judges, gpt-4.1-mini decomposes). We tested it but the two-step approach was MORE nondeterministic, not less. Currently not used — Gemini does both judging and decomposing in criteria_review.rb.

### Call 2b Judge (NOT IN USE)
**File:** `app/services/ai_job_application_action/scoring/prompts/criteria_decomposition_judge.rb`
**Model:** gemini-3.1-flash-lite
**Status:** Built for two-step pipeline. Had worse judgment than the combined review prompt because it didn't produce decomposition output (which acts as scaffolding for better decisions). Not used.

### Call 4 — Candidate Scoring
**File:** `app/services/ai_job_application_action/scoring/prompts/candidate_criteria_scoring.rb`
**Model:** gemini-3.1-flash-lite (unchanged)
**Current prompt rules (4 total):**
1. "When a criterion describes an ability, the candidate does not need to have done it in the exact same context. If they have the underlying technology, tooling, and methodology, that is a full_match." (NEW — helps candidates with transferable skills)
2. "Being multilingual is not evidence of strong communication skills."
3. "When a criterion names a specific tool or technology without allowing alternatives, only score full_match or not_found. Do not score partial_match for a different tool." (NEW — prevents Azure DevOps matching Terraform)
4. Years of experience domain guidance (full_match = domain, partial_match = adjacent domain with significant related duties)
**Removed this session:** The v7 inference guard ("If a criterion matches only because of what the role would typically involve...") — it was causing legitimate strong candidates to drop 12+ points.

### Scoring Math
**File:** `lib/tasks/ai_scoring_candidate.rake`
- Added `title_technology_multiplier = 3` — criteria with `contains_title_technology: true` get triple weight
- Added `da` job key for Data Analyst
- Timeout on OpenAI client raised from 60s to 120s

### Other files
- `app/services/ai_client.rb` — Added gpt-4.1-mini pricing ($0.40/$1.60)
- `app/services/ai_providers/openai.rb` — Raised timeout to 120s

## Stability test results (10 runs each job)

### What's stable
- Call 2 core extraction: same ~14 criteria (Team Lead) and ~12 criteria (Go) appear in every run
- Soft skills at tier_2: 0 leaks in 20 runs
- Key tier assignments: Go always tier_1, K8s always tier_1, communication always tier_2, 5+ years always tier_1
- Call 1 (gpt-4.1-mini): 10/10 stable on sub-heading detection

### What's unstable
- Call 2b decomposition: 0-5 decompositions per run, different criteria decomposed each time
- Total criteria count: 24-30 (Team Lead), 21-33 (Go)
- Decomposed criteria wording varies each run
- T1 count on Go varies 2-5 (heading lock on concatenated heading not consistently applied)

### Root cause of instability
Almost entirely from Call 2b decomposition. If we removed Call 2b, the pipeline would be much more stable but would miss compound decomposition.

## Known bugs

1. **Terraform tier**: "Experience working with Terraform" is under "Required Experience and Skills" heading but consistently gets tier_2 across all 10 runs. The heading lock should make it tier_1.

2. **Leadership tier**: "Excellent leadership skills" varies between tier_1 and tier_2 across runs. Leadership is NOT in the soft skills list — it should stay at whatever tier the heading/signal word assigns.

3. **Call 2b truncation**: On JDs with 30+ criteria, Call 2b truncates output and loses criteria. Affected 5 of 49 JDs in the audit (10%). Needs retry logic or batching.

4. **Call 2b over-decomposition on some runs**: Go criteria count ranged from 21-33. Some runs produce 5 decompositions, others 1.

## Scoring results (latest — v11)

### Go Engineer (27 criteria, Gemini v6 decomposition + ability rule)

| # | Candidate | Score | Expected |
|---|-----------|-------|----------|
| 2 | R Narendran | 81.7% | High |
| 4 | Ganesh Pawar | 73.2% | High |
| 3 | Kushagra Shukla | 60.4% | High |
| 17 | Matheus Caetano | 48.2% | Mid |
| 15 | Alan Niemiec | 45.1% | Mid |
| 1 | Abhishek | 43.3% | High |
| 19 | Anna Verkhogliadova | 42.7% | Mid |
| 18 | William H. Morris | 40.2% | Low |
| 5 | Nishant | 37.8% | High |
| 20 | Mayank Mohan | 52.4% | Mid |
| 14 | Ohm Patel | 52.4% | Low |
| 16 | Barruri Sai Suhas Sharma | 3.7% | Low |

### Team Lead (24 criteria, no decomposition)

| # | Candidate | Eyeball | Score |
|---|-----------|---------|-------|
| 13 | Abhidipta Kaviraj | 9 | 96.6% |
| 3 | Daniela Vasilev | 9 | 88.6% |
| 9 | Alexia Mboulé | 8 | 67.0% |
| 17 | Guillaume Ledogard | 6 | 47.7% |
| 8 | Ravi Patron | 2 | 12.5% |

## 50 JD Audit summary

49 JDs processed. Results in `docs/test-scoring/50jd-audit/`.
- 69% clean (no flags)
- 10% lost criteria (Call 2b truncation on 30+ criteria JDs)
- 4% soft skills leaked to tier_1
- 4% over 50% tier_1 (JD author used strong signal words everywhere)
- 4% over-decomposed (>8 decompositions)

## Key decisions made this session

1. **gpt-4.1-mini for Call 1** — better instruction adherence than gpt-4o-mini, negligible cost difference
2. **Soft skills never tier_1** — leadership is NOT a soft skill, everything else on the list is
3. **Title technology triple weight** — if job title names a specific tech (Go, Python, React), criteria matching it get 3x weight in scoring math
4. **Ability rule** — candidates don't need exact same context, just the underlying tech/tooling/methodology
5. **Specific tool rule** — if criterion names a tool without "or similar", don't give partial_match for a different tool
6. **Removed inference guard** — "if criterion matches only because of what role would typically involve" was hurting legitimate candidates
7. **Split on skills not verbs** — "design, build, and maintain X" is one skill, not three

## Jessica's pending directions

1. **Limit decompositions to 5 max** — "Realistically there probably aren't more than 5 that should really be decomposed." Add to Call 2b prompt.
2. **Handle truncation on large JDs** — determine strategy. Options: batch criteria into chunks of 15, or skip Call 2b on 30+ criteria JDs. Jessica said "if we have to divide up the job description into parts, that's what we do."
3. **Next session must read every criterion line by line** from the 50 JD audit and stability results. No summary statistics — actual evaluation of quality.
4. **Measure score variance across decomposition runs** — score the same candidates (Ganesh, Narendran, Daniela, Abhidipta) across multiple decomposition runs. If scores vary by less than 5%, decomposition instability doesn't matter for scoring and the pipeline is good enough.

## What needs to happen next

1. **Fix Terraform tier bug** — likely caused by deduplication. When Call 2 deduplicates, it keeps the more specific version but uses THAT version's tier instead of inheriting the higher tier. Add to Call 2's duplicate rule: "When deduplicating, the surviving criterion inherits the higher tier of the two."
2. **Fix Call 2b truncation** — either batch criteria or add retry logic for 30+ criteria JDs
3. **Decide on decomposition** — Call 2b decomposition is the main source of instability. Options:
   - Remove it entirely (most stable, loses compound handling)
   - Keep it but accept the variance
   - Make it deterministic (code-level splitting on semicolons, "as well as", etc.)
4. **Re-run the 50 JD audit** with the next agent actually reading every criterion and evaluating quality, not just counting
5. **Test on more ground truth candidates** once the pipeline is stable

## Frozen baseline

All prompts frozen at `docs/test-scoring/frozen-prompts-v11/`. If any iteration regresses, restore from there. Do NOT modify the frozen files.

## Files to read first in next session

1. This file
2. `app/services/ai_job_application_action/scoring/prompts/candidate_criteria_scoring.rb` — Call 4 prompt
3. `app/services/ai_job_application_action/scoring/prompts/job_description_structured_data.rb` — Call 1 prompt
4. `app/services/ai_job_application_action/scoring/prompts/job_description_criteria_extraction.rb` — Call 2 prompt
5. `app/services/ai_job_application_action/scoring/prompts/criteria_review.rb` — Call 2b prompt
6. `docs/test-scoring/stability-test-results.md` — stability analysis
7. `docs/test-scoring/50jd-audit-report.md` — 50 JD audit results
8. `docs/test-scoring/v11-both-jobs-results.md` — latest scoring results
