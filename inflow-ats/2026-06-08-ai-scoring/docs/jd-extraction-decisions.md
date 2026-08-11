# Approved Decisions — JD Structured Extraction

Reference file: `docs/jd-headings-and-qualifiers.md`

---

## Decision 1 — Company/about sections excluded from criteria

Company/about section headings are excluded from scoring criteria generation. Content under these headings does not produce candidate scoring criteria. These sections are still extracted into their own section in the structured output (for display, not scoring).

Headings covered:
`about us`, `who we are`, `overview`, `about the team`, `company`, `company overview`, `position overview`, `about [company name]` variants, `who are we?`, and all non-English equivalents (`om arbeidsgiveren`, `公司简介`, `职位介绍`).

---

## Decision 2 — Benefits/compensation/perks sections excluded from criteria

Same treatment as company/about. Excluded from scoring criteria generation, extracted into their own section in structured output.

Headings covered:
`benefit`, `what we offer`, `salary`, `compensation`, `compensation & benefit`, `perk and benefit`, `perk`, `salary & benefit`, `remuneration`, `schedule and compensation`, `why join [company]`, `what you will get`, `what we can offer you?`, and all emoji/styled variants (`💸 competitive compensation`, `⚕️benefit`, `❤️ wellbeing credit`, `🥗 lunch on us`, `💎 what you will gain`, `🌸 salary 🌸`).

---

## Decision 3 — Meta/process sections excluded from criteria

Excluded from scoring criteria generation. Same treatment — extracted into structured output, not used for scoring. The principle: any section that is clearly not about the candidate is excluded.

Headings covered:
`job information`, `any question?`, `faq`, `how far along are we?`, `can i work remotely?`, `sounds amazing! what now!?`, `the interview process`, `application and process`, `application assessment`, `diversity, equity, and inclusion`, `our commitment`, `our operating principle`, `how to apply`, `our hiring process`, `hiring process`, `equal employment opportunity`, `everyone is welcome`, `learn more`, `additional detail`, and all emoji/styled/tagline variants.

NOT in this bucket: `job description` and `job purpose` — these are role content headers, classified separately. `mission statement: purpose` — company content, goes with company/about exclusion.

---

## Decision 4 — Culture/values/why-join sections excluded from criteria

Excluded from scoring criteria generation. These describe the company, not the candidate. Same treatment as other excluded sections — extracted into structured output, not used for scoring.

Headings covered:
`culture`, `team value`, `our promise to you`, `why join [company]`, `why work with us?`, `why join?`, `why join us?`, `our culture`, `company culture`, `company values and culture`, `spaeth hill core values`.

NOT in this bucket: `key personal value` — that describes the candidate, goes to criteria source.

---

## Decision 7 — Three-tier system: `tier_1`, `tier_2`, `tier_3`

Criteria are assigned one of three tiers. Names are intentionally generic to avoid biasing the AI during extraction.

- **`tier_1`** — must-have, critical, essential, minimum. Hard gates.
- **`tier_2`** — default for unlabeled items. Also where nice-to-haves land — things the employer cares about but won't reject without. In a JD with "must-haves" and "nice-to-haves" sections: must-haves → `tier_1`, nice-to-haves → `tier_2`.
- **`tier_3`** — bonus points, a plus, optional extras. Tiebreaker stuff.

In a JD with no sections or signals at all: everything → `tier_2`.

The prompt defines what each tier means and which language signals map to each. The tier names carry no connotation that would influence classification.

---

## Decision 8 — Inline modifiers override headings

Headings set a default tier for content underneath them. Inline modifiers can only override `tier_2` headings — moving items up to `tier_1` or down to `tier_3`.

Inline modifiers NEVER override `tier_1` or `tier_3` headings. If the JD author put something under a "Required" section, it stays `tier_1`. If they put it under a "Bonus" section, it stays `tier_3`.

---

## Decision 9 — AI must detect the JD's own tier structure first

Before applying default tier mappings, the AI checks what tier structure the JD itself establishes through its headings. If the JD has three distinct levels (e.g., "required", "nice to have", "bonus"), respect that structure and map content accordingly. If two levels, respect that split. If none, fall back to `tier_2` default with inline modifiers doing all the work.

The JD's own structure takes priority over our default heading-to-tier mappings. Our defaults are a fallback, not an override.

**Risk flag:** This may be a foot gun in the prompt. The AI could overthink the tier detection step and misclassify things the default mapping would have handled correctly. Needs A/B testing to determine if including this instruction improves or degrades output quality.

---

## Decision 10 — Inline modifier mapping: `tier_1`

These inline signals push a requirement to `tier_1`:

```
"required"
"at least"
"critical"
"essential"
"must be"
"minimum"
"necessary"
"you need"
"must have"
"we need"
"is required"
"you must"
"mandatory"
"non-negotiable"
"we require"
"are required"
```

**Group B — Strong expectation signals (also `tier_1`):**

```
"excellent"
"strong [X]"
"proficient/proficiency"
"proven"
"exceptional"
"highly [X]"
"track record"
"deep [X]"
"advanced"
"demonstrated"
"solid [X]"
"in-depth"
"thorough"
"extensive"
"expert/expertise"
```

---

## Decision 11 — Inline modifier mapping: `tier_2`

```
"experience with/in/using"
"ability to"
"understanding of"
"knowledge of"
"familiar/familiarity with"
"capable of"
"comfortable with"
"basic [X]"
"working knowledge"
```

**Also `tier_1` (moved from this group):**
- "skilled in"

**Also `tier_3` (moved from this group):**
- "awareness of"
- "exposure to"

**Ambiguous — requires context, no default tier:**
- "willingness to"

---

## Decision 12 — Inline modifier mapping: `tier_2` (from preferred/optional signals group)

**Standalone `tier_2` signals:**
- "is a plus"
- "preferred"
- "desirable"
- "nice to have" / "nice-to-have"
- "great if"
- "a big plus"
- "would love" / "we'd love"
- "ideally"
- "preferably"
- "passion for" — only when around skills/experience/tools
- "excited to" — only when around skills/experience/tools

**Compound modifier phrases — `tier_2` as a full phrase, not as individual words:**

These words are never standalone tier signals. They appear as part of compound phrases where the full phrase determines the tier. The AI must recognize and extract the full modifier phrase, not the individual word.

- "preferred but not required"
- "is nice but not required"
- "is a plus but not required"
- "is preferred but not required"
- "a plus but not required"
- "is a bonus but not required"
- "while not necessary, it will help"
- "not mandatory but it's definitely super plus"
- "we appreciate but don't require"

The individual words in these compounds ("not required", "not mandatory", "not necessary", "we appreciate") are NOT standalone tier signals. They only function as part of the compound phrase. Do not extract or classify them alone.

**Positive modifier phrases — increase the importance of the skill/experience they surround:**
- "advantage" — not a tier signal by itself; it modifies the surrounding skill/experience by increasing its importance
- "advantageous" — same treatment; the prior portion of the sentence states the criteria, "advantageous" elevates it

---

## Decision 13 — Inline modifier mapping: `tier_3`

- "bonus / bonus points / bonus if"
- "is a bonus"
- "interest in" — note: may need A/B testing to confirm this placement
- "willing to"

---

## Decision 14 — Signals removed from criteria entirely

These do not produce or modify criteria:
- "welcome" — almost never criteria-related in context
- "consideration" — refers to application process, not candidate requirements
- "open to" — too ambiguous for AI to classify even with context
- "don't need" — too vague to indicate anything by itself, exclude from criteria

---

## Decision 15 — Highly context-dependent signals, no default tier

These require the AI to determine tier from surrounding context. No default assignment:
- "will help" — sometimes a job duty (not criteria), sometimes a real requirement
- "enthusiasm" — too ambiguous
- "passion for" — when NOT around skills/experience/tools
- "excited to" — when NOT around skills/experience/tools

---

## Decision 21 — Duplicate flag on criteria

Extract all criteria even if duplicated in the JD. After extraction, review the full list and mark duplicates with `duplicate: true`. The more specific version stays `duplicate: false`. Example: "Bachelor's degree in Accounting" = `duplicate: false`, "Four year degree" = `duplicate: true`. Scoring will skip criteria marked `duplicate: true` so candidates aren't scored twice for the same thing.

---

## Decision 16 — Section output has `heading` and `inferred_section_type`

Each section in the structured output has two fields:

- `heading` — the actual heading text from the JD, or `null` if none exists
- `inferred_section_type` — what the AI determines this section is based on content. `null` when the heading is explicit and unambiguous. Filled in when:
  - There is no heading (`heading: null`)
  - The heading is creative or ambiguous (e.g., "🌸 Our dream Character Artist 🌸" → `inferred_section_type: "criteria"`, "enough about us, let's talk about you" → `inferred_section_type: "criteria"`)

`inferred_section_type` uses a fixed set of values. Criteria sections are ALL typed as `"criteria"` — no subdivision into requirements/responsibilities/preferred/bonus at the section level. This prevents section-level labels from biasing the agent during tier assignment. Tier assignment happens per-requirement using inline modifiers, not section type.

**Non-criteria types:**
- `company_about`
- `benefits`
- `culture`
- `process_meta`
- `legal` (diversity/EEO statements)

**Criteria type:**
- `criteria`

---

## Decision 17 — Output has two top-level objects

1. **`sections`** — the full JD decomposed into sections (Phase 1). Headings, content, criteria/non-criteria tags. Preserves the whole JD.
2. **`criteria`** — flat list of individual requirements extracted from all criteria sections (Phase 2). Combo requirements already decomposed into atomic items. This is what scoring consumes.

---

## Decision 18 — Criterion object includes `tier_reasoning`

Each criterion object includes a `tier_reasoning` field where the agent explains why it assigned that tier. Requiring the agent to provide reasoning produces better tier assignments, even if we never read the reasoning.

---

## Decision 19 — Criterion object includes `binary` flag

Each criterion has a `binary` field. `true` when the criterion is either met or not — no spectrum. `false` when there's a range of how well it can be met.

- `binary: true` — degree, license, certification, legal authorization
- `binary: false` — skills, experience, domain knowledge, soft skills

`binary` is independent of tier. A "Bachelor's degree preferred" is `binary: true, tier: tier_2`. A "CPA required" is `binary: true, tier: tier_1`. The `binary` flag describes the nature of the criterion (met or not met), not its importance. Tier is determined by the JD's language as usual.

The extraction step identifies the nature of the criterion. How scoring uses this flag (knockout, weighted differently, etc.) is a separate scoring design decision.

**Non-compound criterion:**
```json
{
  "text": "Licensed to practice medicine",
  "tier": "tier_1",
  "tier_reasoning": "...",
  "binary": true
}
```

---

## Decision 20 — Every criterion has `source_text`

Every criterion includes `source_text` — the full original sentence or full bullet point from the JD. Not a fragment, not a substring. If it ends with punctuation, the full sentence. If it's a bullet with no punctuation, the full bullet.

All criteria get `source_text`, not just decomposed ones. For non-compound criteria, `text` and `source_text` may be identical — that's fine. Consistency matters more than avoiding duplication.

**Non-compound:**
```json
{
  "text": "Ability to write clear and maintainable tests",
  "tier": "tier_2",
  "tier_reasoning": "...",
  "binary": false,
  "source_text": "Ability to write clear and maintainable tests"
}
```

**Decomposed from compound:**
```json
{
  "text": "Frontend development experience",
  "tier": "tier_2",
  "tier_reasoning": "...",
  "binary": false,
  "source_text": "5+ years of professional software development experience, including both frontend and backend work"
}
```

---

## Decision 5 — Responsibilities sections ARE a criteria source

Responsibilities describe things the candidate must be able to do. The section heading doesn't change that — "manage a team of 10" stated as a responsibility is still a requirement on the candidate.

Responsibilities produce criteria. Tier assignment follows inline qualifying language, same rules as any other section. No qualifier → `standard`. "Must" / "you need to" → `required`. Etc.

Headings covered:
`responsibility`, `key responsibility`, `the role`, `about the role`, `what you will do`, `job responsibility`, `your responsibility`, `what you will be doing`, `what would you be doing?`, `duty & responsibility`, `essential job duty and responsibility`, `description of duty and task`, `responsibility include`, `what will your typical day look like?`, `role overview`, `role`, `your main responsibility`, `what you will contribute`, `core responsibility`, `your main task`, `your primary task`, `what the job entails`, `what will your day to day look like?`, and all non-English equivalents.

Also includes generic role content headers: `job description` (12), `job purpose` (2). Same treatment — criteria source, inline qualifiers determine tier.

---

## Decision 6 — Physical/logistics requirement sections ARE a criteria source

`physical requirement`, `pre-employment requirement`, `location` — these are real candidate requirements. Criteria source, inline qualifiers determine tier.

Scoring will need to handle the "no signal in resume" case separately from "contradicts requirement" — but that's a scoring design decision, not an extraction decision. For extraction purposes, these are treated the same as any other candidate-facing requirement.
