# How Plato AI Scores a Candidate

*A plain-language walkthrough for stakeholders. Exact model names and call order are in the Technical Appendix at the end.*

---

## The one-paragraph version

Plato does not "read a resume and guess a number." For each **job**, it first turns the job description into a structured **scorecard** of individual requirements, each tagged as core, preferred, or bonus. Then, for each **candidate**, it builds a de-identified profile of their experience, measures that profile against every requirement on the scorecard, and converts the results into a single fit score using **fixed, transparent math — not an AI's gut feeling**. Getting one candidate to a finished score can take **up to roughly a dozen separate AI model calls across two different AI providers**, plus several deterministic (non-AI) calculation steps. The complexity is deliberate: it separates *understanding the candidate* from *judging the fit*, and it strips out personal identity before any judgment happens.

---

## The big picture: two jobs, done in order

Think of it as **building a test, then grading against it.**

**1. Build the scorecard — once per job.**
The job description is broken down into a clean list of atomic requirements. "5+ years of React and a strong grasp of REST APIs" becomes several separate scorecard items, each labeled by importance. This happens **one time per job** and is reused for every applicant, so everyone applying to the same role is measured against the exact same bar.

**2. Grade each candidate against that scorecard.**
For each applicant, Plato reads the resume, builds a neutral profile of what they've actually done, checks that profile item-by-item against the scorecard, and computes a fit score and a written explanation.

A candidate is always scored **against their specific job's requirements** — never against a generic, one-size-fits-all rubric.

---

## Stage 1 — Building the scorecard (per job)

The job description is the **only** input here. No candidate, no resume, and no personal information is involved in building the scorecard — **the requirements bar is defined before a single applicant is looked at.**

Two specialized AI passes do this work:

- **Pass 1 — Decompose the job description.** The description is split into meaningful sections, and each section is classified: is this an actual *requirement*, or is it background (company blurb, benefits, compensation, culture, legal boilerplate)? Only the requirement sections move forward. The core technology named in the job title is also identified here.
- **Pass 2 — Extract atomic requirements.** Each requirement section is broken into individual, self-contained criteria. Compound sentences are split apart ("React **and** REST APIs" → two items). Each item is tagged with an importance **tier**:
  - **Core** (must-have)
  - **Preferred** (strongly wanted)
  - **Bonus** (nice-to-have)

After the AI passes, **fixed rules** clean up the result — no AI involved:

- Requirements under headings like "Required," "Must have," "Essential," or "Minimum" are forced to **Core**. Requirements under "Bonus," "Optional," or "Extra credit" are forced to **Bonus**. (One deliberate exception: a soft skill like "team player" is never auto-promoted to Core.)
- Duplicate or less-specific restatements of the same requirement are removed, so no single requirement is double-counted.

The result is a stable, structured scorecard attached to the job. Because the AI passes run with variability turned off and against a strict output format, re-running extraction on the same description produces essentially the same scorecard.

---

## Stage 2 — Understanding the candidate (per candidate)

Before Plato grades anyone, it builds a **neutral profile** of the candidate. This takes up to four AI passes, and this is where our single most important fairness control lives.

- **Pass 1 — Extract the facts.** The raw resume is read once and turned into structured data: work history, education, skills, dates. **This is the only step in the entire system that ever sees personal identity** — name, contact details, location, personal links. Its job is purely to structure the resume.
- **Pass 2 — Assess the experience.** Working from a **de-identified** version of that structured data, Plato characterizes the candidate's domains of experience, career narrative, key skills, and standout accomplishments.
- **Pass 3 — Compare to the role.** Still de-identified, Plato lines the candidate's experience up against the job title to identify applicable experience, overlaps, and gaps.
- **Pass 4 — Write the summary.** A final, **role-blind** pass produces the plain-language headline and summary you read on the candidate.

Two of these passes only run when they apply — for example, the comparison pass is skipped when there is no work history to compare. And crucially, the **length of a candidate's tenure is calculated by code, not guessed by AI**: overlapping jobs are de-duplicated so concurrent roles aren't double-counted, and any date the system genuinely can't read is skipped rather than invented.

---

## Stage 3 — Scoring against the scorecard (per candidate)

Now Plato grades the neutral candidate profile against the job's scorecard. Every requirement gets one of three verdicts:

- **Full match** — the candidate clearly meets it.
- **Partial match** — partially met.
- **Not found** — no evidence.

Each verdict comes with a short written justification citing concrete evidence from the profile — with no personal identity attached.

**Guarding decision boundaries.** Fit scores fall into bands (excellent / good / mixed / weak / poor). If a candidate's first score lands **near the edge of a band**, Plato doesn't trust a single run — it **scores the candidate five times and takes the median**, so one unusually generous or harsh pass can't tip a borderline candidate into a different band. Candidates that land comfortably inside a band are scored once.

Finally, a separate AI pass writes the recruiter-facing **"Fit for this role"** narrative, tying together the strengths, gaps, and criteria results.

---

## How the final score is calculated (the math is fixed, not AI-decided)

This is the part people most want to trust, so it is intentionally **not** left to an AI. Once the AI has assigned full / partial / not-found to each requirement, the overall percentage is pure arithmetic:

**Step 1 — Weight each requirement by its tier.**

| Tier | Weight |
|---|---|
| Core | 6 |
| Preferred | 4 |
| Bonus | 2 |

**Step 2 — Score each match.** Full match = 100% of the weight, Partial = 70%, Not found = 0%.

**Step 3 — Boost the core technology.** A requirement that names the job's core title technology counts **triple**, because the actual skill the role is built around matters more than a peripheral nice-to-have.

**Step 4 — Add it up.** The final **fit score is the points earned divided by the maximum points possible**, expressed as a percentage. The same formula runs for every candidate, every time.

That percentage maps to a fit label:

| Fit score | Rating |
|---|---|
| 90% and above | Excellent fit |
| 60% to under 90% | Good fit |
| 35% to under 60% | Mixed fit |
| 15% to under 35% | Weak fit |
| Under 15% | Poor fit |

Because the score is deterministic math over the AI's per-requirement verdicts, two people reading the same review can always see *why* a candidate got the number they got.

---

## What the recruiter ends up with

For each candidate, Plato produces:

- An **overall fit score and rating** (poor → excellent).
- A **headline** and a plain-language **summary**.
- A **"Fit for this role" narrative** explaining the verdict.
- A **requirement-by-requirement breakdown** across core, preferred, and bonus criteria — showing what was met, partially met, or missing, each with a one-sentence, evidence-based explanation.

Plato is **decision support**: it surfaces the reasoning and the breakdown so a human recruiter can review it and decide. **It does not auto-reject or auto-advance anyone.**

---

## Bias prevention and fairness

This section describes the fairness controls that are actually built into the pipeline. It is an accurate description of the system's design — **not** a claim of an independent bias audit or a fairness certification.

### What the pipeline deliberately does

- **Identity is removed before any judgment.** The candidate's **name, email, phone, physical location, and personal web links are stripped out** before the assessment, comparison, summary, and *all* scoring steps run. Only the very first fact-extraction step ever sees those identifiers, and its output is de-identified before anything else uses it. Grading is done on a profile with the person's identity removed.
- **Everyone on a job is measured against the same bar.** The scorecard is built from the job description alone, once, before any applicant is examined. Every candidate for that role is scored against the identical set of requirements — the bar cannot drift from one applicant to the next.
- **The final number is fixed math, not AI intuition.** The AI decides *met / partially met / not met* per requirement, with a written justification; the overall score is then computed by a transparent, unchanging formula. An AI never simply "picks a percentage."
- **Consistency is enforced at the low level.** The AI steps that build the scorecard and structure the candidate run with randomness turned off and against a strict, fixed output format, so results are stable when repeated.
- **Borderline cases are stabilized.** Near a band boundary, the candidate is scored five times and the median is used, so a single noisy run cannot push someone into a worse (or better) band.
- **Specific prompt-level guardrails.** The AI is instructed to write **without gendered pronouns**, to base every requirement verdict on **concrete evidence**, not to hand out partial credit for a specifically-required tool the candidate simply does not have, and **not to treat speaking multiple languages as evidence of communication skill** (so a candidate's language background isn't quietly converted into a job qualification).
- **Identity must never resurface.** By design, the candidate's name and contact details are not supposed to appear anywhere in the summary, the criteria breakdown, or the fit narrative.

### What the pipeline does NOT do (stated honestly)

- **It is not a certified or independently audited fairness system.** These are engineering guardrails, not a third-party audit result.
- **It removes explicit identifiers, not all possible signals.** Stripping name / contact / location / links de-identifies the profile, but the substance of the resume — employer names, school names, dates, and the like — is still what gets analyzed. Plato does not claim to detect or neutralize every indirect signal that a resume's content could carry.
- **It does not make hiring decisions.** Plato scores and explains; a human decides. There is no automatic advancement or rejection.
- **It does not replace human judgment or legal review.** The fit score is a screening aid, not a compliance determination.

---

## Technical appendix

### End-to-end call order

**Per job — build the scorecard (2 AI calls, OpenAI):**

| # | Purpose | Model | Provider |
|---|---|---|---|
| 1 | Decompose job description into classified sections + identify title technology | `gpt-4.1-mini-2025-04-14` | OpenAI |
| 2 | Extract atomic, tiered criteria | `gpt-4o-2024-08-06` | OpenAI |
| — | Fixed-rule cleanup: strip leaked tier labels, heading-based tier overrides, de-duplicate | *(code, no AI)* | — |

**Per candidate — build the profile (2–4 AI calls, OpenAI; passes 2–3 conditional):**

| # | Purpose | Model | Sees personal identity? |
|---|---|---|---|
| 1 | Structure the raw resume | `gpt-4o-mini` | **Yes — the only step that does** |
| 2 | Assess experience / domains (only if work history present) | `gpt-4o-mini` | No (de-identified) |
| 3 | Compare candidate to role (only if job title + domain months present) | `gpt-4o-mini` | No (de-identified) |
| 4 | Write headline + summary | `gpt-4o-mini` | No (role-blind) |
| — | Tenure math: de-overlap concurrent roles, skip unreadable dates | *(code, no AI)* | — |

**Per candidate — score against the scorecard (1 or 5 scoring calls + 1 display call + 1 narrative call):**

| # | Purpose | Model | Provider |
|---|---|---|---|
| 1 | Score each requirement (full / partial / not found) | `gemini-3.1-flash-lite` | Google Gemini |
| — | If near a band edge (within 5 points of 90 / 60 / 35 / 15): run 4 additional scoring calls, take the **median** | `gemini-3.1-flash-lite` | Google Gemini |
| — | Compute fit percentage from tier weights + match values + title-tech ×3 | *(code, no AI)* | — |
| 2 | Rewrite each result as an evidence-citing sentence | `gemini-3.1-flash-lite` | Google Gemini |
| 3 | Write the final "Fit for this role" narrative | `gpt-4.1-mini-2025-04-14` | OpenAI |

**Providers:** OpenAI (run at `temperature: 0` with strict JSON output schemas) handles the scorecard, the candidate profile, and the final narrative. Google Gemini handles the scoring and display calls; scoring's run-to-run variability is exactly why borderline candidates are scored five times and the median is taken.

### Scoring formula (deterministic)

- Tier weights: **Core = 6, Preferred = 4, Bonus = 2**.
- Match values: **Full = 1.0, Partial = 0.7, Not found = 0.0**.
- Title-technology multiplier: **×3** on any requirement naming the job's core title technology.
- `fit score % = (Σ effective_weight × match_value) ÷ (Σ effective_weight) × 100`.

### Fit bands

`≥90 excellent · 60–90 good · 35–60 mixed · 15–35 weak · <15 poor` (lower bound inclusive). These same thresholds define the "near a boundary" trigger for median-of-five scoring.

### De-identification (bias control)

Before the assessment, comparison, summary, and all scoring / display calls, the candidate profile has **name, email, phone, location, and links** removed. Only the first resume-structuring call ever sees personal identity; its output is de-identified before any downstream reuse. The scorecard-building stage never sees candidate data at all.

### A note on cost

A candidate's finished review takes roughly **5 to 11 AI calls** depending on how much history there is to analyze and whether the score lands near a band boundary. Regardless of that count, **a successfully completed review consumes exactly one credit**. Failed or incomplete reviews consume nothing. (The 2 scorecard calls are per-job and shared across every candidate on the role, not charged per candidate.)
