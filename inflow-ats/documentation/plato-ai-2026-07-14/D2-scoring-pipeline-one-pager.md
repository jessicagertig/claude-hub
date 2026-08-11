# Plato AI — How a Candidate Gets Scored

**One page, one idea:** build a scorecard from the job, build a de-identified profile of the candidate, grade the profile against the scorecard, compute the score with fixed math. AI judges evidence; arithmetic produces the number.

---

## The pipeline

### Stage 1 — Build the scorecard *(once per job · 2 AI calls)*

| Step | What happens |
|---|---|
| Decompose | Job description is split into sections; only real requirements move forward (benefits, culture, boilerplate are discarded). The job's core technology is identified. |
| Extract | Requirements are broken into atomic criteria — compound sentences split apart — each tagged **Core / Preferred / Bonus**. |
| Clean up *(code, no AI)* | Headings like "Required" or "Bonus" override tiers by fixed rule; AI-flagged duplicates are dropped so nothing double-counts. |

Input is the job description **only** — the bar is set before any applicant is looked at, and every candidate on the job is measured against the same scorecard.

### Stage 2 — Build the candidate profile *(per candidate · 2–4 AI calls)*

| Step | What happens |
|---|---|
| Structure the resume | Raw resume → structured work history, education, skills, dates. **The only step that ever sees identity** (name, contact, location, links). |
| De-identify *(code)* | Identity fields are stripped before every step below. |
| Assess & compare | De-identified profile → domains of experience, key skills, career narrative; lined up against the role to find applicable experience and gaps. |
| Summarize | Plain-language headline and summary. Tenure lengths are **calculated by code** — overlapping jobs de-duplicated, unreadable dates skipped, never guessed. |

### Stage 3 — Score against the scorecard *(per candidate · 1–5 scoring calls + 2)*

| Step | What happens |
|---|---|
| Judge each requirement | Every scorecard item gets **Full / Partial / Not found**, each with an evidence-citing justification. |
| Stabilize borderline scores | Lands near a band edge → scored **five times, median taken**. Comfortably inside a band → scored once. |
| Compute the score *(code, no AI)* | Fixed formula below. An AI never "picks a percentage." |
| Explain | A final pass writes the recruiter-facing "Fit for this role" narrative. |

---

## The math (fixed, transparent, identical for every candidate)

- **Tier weights:** Core = 6 · Preferred = 4 · Bonus = 2
- **Match values:** Full = 1.0 · Partial = 0.7 · Not found = 0.0
- **Core-technology boost:** requirements naming the job's core technology count **×3**
- **Fit score % = points earned ÷ points possible** → `≥90 Excellent · 60–90 Good · 35–60 Mixed · 15–35 Weak · <15 Poor`

## Fairness controls built into the design

- Identity fields are removed before assessment, comparison, summary, and all scoring — judgment never sees name, contact, location, or links.
- One scorecard per job: same bar for every applicant while the description is unchanged.
- Deterministic settings (no randomness, strict output formats) on profile and scorecard steps; median-of-five on borderline scores.
- Prompt-level guardrails: evidence required for every verdict, no gendered pronouns, multilingualism never converted into a "communication skills" credit.

*These are engineering guardrails, not an independent bias audit — and identity written inside free-text prose is not scrubbed.*

---

**Plato is decision support.** It scores, explains, and shows the per-requirement breakdown; it never auto-rejects or auto-advances anyone. A finished review takes roughly **5–11 AI calls across two providers** and consumes **exactly one credit** — failed reviews consume nothing.
