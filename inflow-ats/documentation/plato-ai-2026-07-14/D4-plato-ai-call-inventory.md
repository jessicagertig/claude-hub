# Plato AI — Every AI Call

**Basis:** read from code, not from the 2026-07-01 mapping snapshot. The pipeline (`app/services/ai_job_application_action/`, `app/services/ai_providers/`) is byte-identical between local `production` (`e2f45fabe`, 2026-07-23) and `ai-credit-posthog-events` (`3af005159`, 2026-08-05).

**A finished review is 7 or 11 AI calls per candidate.** The only variable is whether the borderline rescore triggers — that adds exactly 4. Every other call runs every time.

The 2 scorecard calls are per *job*, shared by every candidate on that role, and are not charged per candidate.

---

## Per job — build the scorecard · 2 calls

Runs once per job, reused for every applicant. Input is the job description only.

| # | Call | Model | Provider | Produces |
|---|---|---|---|---|
| **J1** | `jd_structured_data` | `gpt-4.1-mini-2025-04-14` | OpenAI | Job description split into classified sections; the role's title technology identified |
| **J2** | `jd_criteria_extraction` | `gpt-4o-2024-08-06` | OpenAI | Atomic criteria, each tiered Core / Preferred / Bonus, each with a duplicate flag |

Between and after, no AI:
- Only sections typed `criteria` move forward — benefits, culture, boilerplate are dropped.
- Any `[tier_n]` label the model leaked into the criterion text is stripped.
- Headings matching `require|must|essential|minimum` force Core; `bonus|optional|extra credit` forces Bonus. Soft skills are exempt from the Core override.
- Criteria the model flagged as duplicates are removed so nothing double-counts.

---

## Per candidate — build the profile · 4 calls, always

All four are OpenAI, all `gpt-4o-mini`.

| # | Call | Model | Sees identity | Produces |
|---|---|---|---|---|
| **C1** | `extraction` | `gpt-4o-mini` | **Yes — the only call that ever does** | Structured work history, education, skills, dates |
| **C2** | `assessment` | `gpt-4o-mini` | No | Primary/secondary domains, key skills, career narrative, standout accomplishments |
| **C3** | `comparison` | `gpt-4o-mini` | No | Applicable experience, gaps, overlap against the role |
| **C4** | `summary` | `gpt-4o-mini` | No | Recruiter-facing headline and summary |

Between them, no AI:
- After C1, `AnonymizeForAi` deletes name, email, phone, location and links. Everything from C2 onward runs on the de-identified profile.
- Total tenure is computed by merging overlapping date intervals, so concurrent jobs are not double-counted. Dates that will not parse are skipped, never guessed.
- After C2, months-by-domain is computed the same way from the domain classifications.

---

## Per candidate — score against the scorecard · 3 or 7 calls

| # | Call | Model | Provider | Produces |
|---|---|---|---|---|
| **C5** | `scoring` | `gemini-3.1-flash-lite` | Google Gemini | Full match / partial match / not found for every criterion, each with reasoning |
| **C6** | `scoring_display` | `gemini-3.1-flash-lite` | Google Gemini | Each verdict rewritten as an evidence-citing sentence for the UI |
| **C7** | `integrated_analysis` | `gpt-4.1-mini-2025-04-14` | OpenAI | The "Fit for this role" narrative |

**C5 is the only call that can repeat.** It runs once; if that first score lands within 5 points of a band boundary — 90, 60, 35 or 15 — it runs 4 more times and the median run is selected. C6 and C7 then run once on the selected run's results.

C6 and C7 always run exactly once each.

---

## The count

| | Calls |
|---|---|
| Profile (C1–C4) | 4 |
| Scoring (C5) | 1, or 5 when near a band boundary |
| Display (C6) | 1 |
| Narrative (C7) | 1 |
| **Per candidate** | **7 or 11** |
| Scorecard (J1–J2), per job | 2 |

**4 distinct models across 2 providers:** `gpt-4.1-mini-2025-04-14`, `gpt-4o-2024-08-06`, `gpt-4o-mini` (OpenAI) and `gemini-3.1-flash-lite` (Google Gemini).

A successfully completed review consumes exactly **one credit** (`CREDIT_COST = 1`), charged only after the summary reaches `succeeded`. Failed or incomplete reviews consume nothing.

---

## The math (fixed, identical for every candidate)

- **Tier weights:** Core = 6 · Preferred = 4 · Bonus = 2
- **Match values:** Full = 1.0 · Partial = 0.7 · Not found = 0.0
- **Title-technology boost:** criteria naming the role's title technology count **×3**
- **Fit score % = points earned ÷ points possible** → `≥90 Excellent · 60–90 Good · 35–60 Mixed · 15–35 Weak · <15 Poor`

An AI never picks a percentage. Every score is this arithmetic over the per-criterion verdicts.

---

## Determinism

`AiProviders::Openai` hardcodes `temperature: 0` on every OpenAI call — J1, J2, C1–C4 and C7. `AiProviders::Gemini` sets no temperature at all, so C5 and C6 carry real run-to-run variance. That is exactly why borderline scores are run five times and the median taken.

All prompts use strict JSON response formats.

---

## Fairness controls

- Identity fields are removed after C1 and never reach assessment, comparison, summary, scoring, display or narrative.
- One scorecard per job: the same bar for every applicant while the description is unchanged.
- Prompt-level guardrails: evidence required for every verdict; no pronouns of any kind; no partial credit for a specifically-named tool the candidate does not have; multilingualism never counted as communication skill.

*These are engineering guardrails, not an independent bias audit. De-identification is field-level — identity written inside free-text prose (professional summary, work-history descriptions) is not scrubbed and does reach the scoring calls.*

---

**Plato is decision support.** It scores, explains, and shows the per-requirement breakdown. It never auto-rejects or auto-advances anyone.

---

*Footnote on completeness: `Summary::Prompts::ResumeRelevance` (`deepseek-chat`) and `Summary::Prompts::RoleCategorization` exist in the codebase but are referenced by no orchestrator and issue no calls. The seven above are the complete set.*
