# JD Extraction Prompt — Outline

Reference: `docs/jd-extraction-decisions.md`

May be one prompt or two phases. Outlined as one for now.

---

## Phase 1 — Decompose into structured sections

Parse the job description HTML into structured sections. Every heading becomes its own keyed section. Each section is tagged as `criteria` or `non_criteria`.

**Non-criteria sections (excluded from scoring — Decisions 1-4):**

- Company/about
- Benefits/compensation/perks
- Meta/process (FAQ, how to apply, EEO, interview process, application deadlines)
- Culture/values/why-join

**Criteria sections (Decisions 5-6, requirements-type headings):**

- Requirements/qualifications
- Responsibilities
- Physical/logistics requirements
- Preferred/bonus sections
- Generic role content (job description, job purpose)

**Headingless content:**

Some JDs have no headings or have content before the first heading. This content still needs to be captured and classified — likely criteria by default unless it reads as company description.

**Output structure (rough):**

```json
{
  "sections": [
    {
      "heading": "About Us",
      "inferred_section_type": null,
      "type": "non_criteria",
      "content": "..."
    },
    {
      "heading": null,
      "inferred_section_type": "company_about",
      "type": "non_criteria",
      "content": "..."
    },
    {
      "heading": "Qualifications",
      "inferred_section_type": null,
      "type": "criteria",
      "content": "..."
    },
    {
      "heading": "🌸 Our dream Character Artist 🌸",
      "inferred_section_type": "criteria",
      "type": "criteria",
      "content": "..."
    },
    {
      "heading": "Nice to Have",
      "inferred_section_type": null,
      "type": "criteria",
      "content": "..."
    },
    {
      "heading": "Benefits",
      "inferred_section_type": null,
      "type": "non_criteria",
      "content": "..."
    }
  ]
}
```

`heading` = actual text from the JD, or `null` if no heading exists.
`inferred_section_type` = AI's determination of what this section is, based on content. `null` when the heading is explicit and unambiguous.

---

## Phase 2 — Extract and tier criteria from criteria sections

For each `criteria` section, extract individual requirements. Assign each requirement a tier (`tier_1`, `tier_2`, `tier_3`) based on:

1. First, detect the JD's own tier structure from its headings (Decision 9 — flagged for A/B testing)
2. Heading default tier (Decision 7 heading mappings)
3. Inline modifier override (Decisions 10-15)

**Tier assignment rules:**

- `tier_1`: Required/must-have signals (Decision 10 Group A), strong expectation signals (Decision 10 Group B), "skilled in" (from Decision 11)
- `tier_2`: Default for unlabeled items. Neutral signals (Decision 11). Nice-to-have, ideally, preferably, etc. (Decision 12). Compound modifier phrases treated as whole units (Decision 12).
- `tier_3`: Bonus/bonus points, is a bonus, interest in, willing to (Decision 13)
- Positive modifier phrases ("advantage", "advantageous") increase importance of the surrounding skill/experience (Decision 12)
- Removed from criteria: welcome, consideration, open to, don't need (Decision 14)
- Context-dependent, no default: will help, enthusiasm, passion for / excited to when not around skills (Decision 15)

**Combo requirement decomposition:**

Requirements that pack multiple criteria into one sentence must be decomposed into atomic criteria, each with its own tier. Example:

"5+ years of professional software development experience, including both frontend and backend work"
→ Three criteria:
1. 5+ years of professional software development
2. Frontend development experience
3. Backend development experience

"8+ years of fundraising experience, ideally in the social sector"
→ Two criteria, different tiers:
1. 8+ years of fundraising experience (`tier_1` — years + domain)
2. Social sector experience (`tier_2` — signaled by "ideally")

---

## Prompt priority order

What the agent needs to know, in order:

1. **Task**: Extract structured data from a job description
2. **Phase 1 — Section decomposition**: Split into sections, tag each as criteria or non_criteria
3. **Non-criteria definitions**: What sections to exclude (company, benefits, meta, culture) — agent needs to know this FIRST to avoid wasting work on excluded content
4. **Phase 2 — Criteria extraction**: From criteria sections only, extract individual requirements
5. **Tier system**: Three tiers, generic names, what each means
6. **Tier assignment rules**: Heading defaults, inline modifiers, compound phrases
7. **Combo decomposition**: Split multi-criteria sentences into atomic criteria
8. **Multi-language support**: JDs may be in any language. The extraction and tier assignment rules apply identically regardless of language — the AI translates the section classification and inline modifier logic, not the content itself. Output structured data preserves the original language of the content.
9. **Edge cases**: Headingless content, minimal JDs with nothing to extract, trailing non-criteria content after the last criteria section (common pattern: diversity statement / benefits / company pitch appears after the final nice-to-have/bonus list with no heading — classify as non_criteria)
