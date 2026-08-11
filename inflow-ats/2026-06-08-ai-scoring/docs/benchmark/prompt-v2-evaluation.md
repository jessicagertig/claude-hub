# Prompt v2 Evaluation

Model: gpt-4o-mini | Prompt: prompt-v2.txt

## v2 Prompt Changes Applied

1. Added explicit "never drop content" rule
2. Strengthened null/null enforcement with an example
3. Changed to always populate inferred_section_type for non_criteria sections
4. Added JSON null formatting instruction
5. Expanded heading detection beyond HTML heading tags
6. Reinforced that role description prose is criteria
7. Added mixed section guidance
8. Added heading extraction rule (don't merge heading into content)
9. Added self-verification checklist

---

## 1. elixir.json -- Elixir Developer (Select)

**v1 defects:** Dropped entire second paragraph (MAJOR). "Base Requirements" plain `<p>` not extracted as heading. Section 2 content kept raw HTML `<ul>/<li>` tags.

**v2 result:** 2 sections.

### Did v1 defects get fixed?

**Dropped paragraph: FIXED.** The second paragraph ("We're seeking purpose-led, results oriented technology professionals...") is now present in Section 1's content, merged with the first paragraph as a single `company_about` section. All key phrases confirmed present: "seeking purpose-led," "agile methodology," "Thousands of client users."

**"Base Requirements" heading extraction: FIXED.** In v1, "Base Requirements" (a plain `<p>` tag with no bold/strong/heading markup) was not extracted as a heading. In v2, it is correctly extracted into the `heading` field of Section 2. The expanded heading detection rule (change #5) worked.

**HTML tags in content: FIXED.** v1 Section 2 content contained raw `<ul><li>` tags. v2 Section 2 content is plain text with periods as list item separators. No HTML tags remain.

### New defects introduced?

**NEW: Unescaped HTML entity `&#39;` in content.** Section 1 content contains `We&#39;re seeking` instead of `We're seeking`. The source HTML uses `&#39;` but v1 decoded it to an apostrophe. v2 passed it through literally. This is a regression -- the model should decode HTML entities to their character equivalents.

### Section count and tagging accuracy

2 sections, same as v1. Tagging is correct:
- Section 1: `non_criteria`, `inferred_section_type: "company_about"` -- correct.
- Section 2: `criteria`, `inferred_section_type: "criteria"`, `heading: "Base Requirements"` -- correct.

### Content completeness

Complete. Both paragraphs and all 7 list items present. The only content issue is the HTML entity not being decoded.

### inferred_section_type accuracy

Correct. Section 1 has `company_about`, Section 2 has `criteria`. Both appropriate. No null/null violations.

---

## 2. glide.json -- Senior Software Engineer Fullstack (Glide)

**v1 defects:** H1 "Welcome to Glide!" merged into content instead of heading field. Missing space between "Glide!" and "At" in content. Criteria sections had `inferred_section_type: null` instead of `"criteria"`. "Perks and Benefits" had `inferred_section_type: "benefits"` when rule said use null for explicit headings (inconsistency).

**v2 result:** 6 sections.

### Did v1 defects get fixed?

**Heading "Welcome to Glide!" extraction: NOT FIXED.** The H1 heading "Welcome to Glide!" is still not in the `heading` field. It remains merged into the content: `"content": "Welcome to Glide! At Glide we're..."`. The heading extraction rule (change #8) did not resolve this. The heading is `null` and the model relies on `inferred_section_type: "company_about"` to cover for the missing heading.

**Missing space: FIXED.** v1 had `"Welcome to Glide!At Glide"` (no space). v2 has `"Welcome to Glide! At Glide"` (space present).

**Criteria inferred_section_type: FIXED.** v1 had `null` for criteria sections with explicit headings (Your Responsibilities, Need-to-Have's, Nice-to-Have's). v2 correctly has `"criteria"` for all three. Change #3 worked here.

**Non-criteria inferred_section_type inconsistency: FIXED by design.** The v2 rule changed to "always populate inferred_section_type for non_criteria sections." "Perks and Benefits" now has `"benefits"`, "Any Questions?" has `"process_meta"`, and the intro has `"company_about"`. This is consistent and correct.

### New defects introduced?

None.

### Section count and tagging accuracy

6 sections, same as v1. All tagging correct:
- Section 1: `non_criteria` / `company_about` -- correct.
- Section 2 "Your Responsibilities:": `criteria` / `criteria` -- correct.
- Section 3 "Need-to-Have's:": `criteria` / `criteria` -- correct.
- Section 4 "Nice-to-Have's:": `criteria` / `criteria` -- correct.
- Section 5 "Perks and Benefits:": `non_criteria` / `benefits` -- correct.
- Section 6 "Any Questions?": `non_criteria` / `process_meta` -- correct.

### Content completeness

Complete. All content from source present. Benefits sub-sections (Competitive Compensation, Wellbeing Credits, Lunch on us, Best Tools) correctly merged into one section.

### inferred_section_type accuracy

All correct. No null/null violations. No invalid values.

---

## 3. housekeeper.json -- Housekeeper (Renjoy)

**v1 defects:** `inferred_section_type: null` for all sections (technically correct per v1 rules since all had explicit headings, but lost useful type metadata). "Job Overview" tagged `non_criteria` despite containing criteria-adjacent content ("Show up consistently, work hard, and communicate well"). "Pay & Schedule" tagged `non_criteria` despite "Sunday availability is mandatory" being a logistics requirement. "Why Renjoy" had no useful `inferred_section_type`.

**v2 result:** 6 sections (v1 had 5).

### Did v1 defects get fixed?

**inferred_section_type for non_criteria sections: PARTIALLY FIXED.** "Why Renjoy" now correctly has `inferred_section_type: "culture"` -- this is the best improvement. However, "Pay & Schedule" has `inferred_section_type: "non_criteria"` which is not a valid enum value (should be `"benefits"` or `"compensation"` or similar). Using the type value as the inferred_section_type value is circular and useless.

**"Job Overview" criteria classification: FIXED (with side effects).** The model split the "Job Overview" section into two pieces: Section 1 (headingless, `company_about`) gets the company description paragraph, and Section 2 (heading "Job Overview", `criteria`) gets only the "No resume required" criteria line. This correctly classifies the criteria content as criteria. However, the split is unusual -- "Job Overview" as a heading now covers only one sentence, and the company intro paragraph it originally headed has no heading at all.

**Mixed section handling for "Pay & Schedule": NOT FIXED.** "Pay & Schedule" remains tagged as `non_criteria` as a whole. The "Sunday availability is mandatory" requirement is still not tagged as criteria. This is consistent with the v2 guidance (tag based on dominant content, don't split), so it's working as designed. But the scorable requirement is still suppressed.

### New defects introduced?

**NEW: Questionable section split.** The "Job Overview" section was split into two sections. The first section has `heading: null` and covers the company intro paragraph. The second section inherits the "Job Overview" heading but covers only the single "No resume required" line. In the source HTML, "Job Overview" is a `<strong>` heading that covers both the company intro AND the "No resume required" line. The split separates content from its heading. This is a judgment call -- the split improves criteria accuracy but creates an orphaned heading relationship.

**NEW: `inferred_section_type: "non_criteria"` is not a valid enum value.** Section 3 "Pay & Schedule" uses `"non_criteria"` as the inferred_section_type value. The valid values per the prompt should be `company_about`, `benefits`, `culture`, `process_meta`, `legal`. Using `"non_criteria"` provides no additional information beyond the `type` field. This should be `"benefits"` or a similar value.

### Section count and tagging accuracy

6 sections (up from 5). The additional section comes from splitting "Job Overview" content.
- Section 1: `non_criteria` / `company_about` -- correct for the content.
- Section 2 "Job Overview": `criteria` / `criteria` -- correct for the one-line content.
- Section 3 "Pay & Schedule": `non_criteria` / `non_criteria` -- DEFECTIVE inferred value.
- Section 4 "What You'll Do": `criteria` / `criteria` -- correct.
- Section 5 "What We're Looking For": `criteria` / `criteria` -- correct.
- Section 6 "Why Renjoy": `non_criteria` / `culture` -- correct.

### Content completeness

Complete. All content from the source is present across the 6 sections. No content dropped.

### inferred_section_type accuracy

4/6 correct. Section 3 uses invalid value `"non_criteria"`. Section 2 using `"criteria"` is technically correct but the heading reattachment is debatable. No null/null violations.

---

## 4. levellr.json -- Full Stack Engineer (Levellr)

**v1 defects:** NULL/NULL VIOLATION on Section 1 (heading null, inferred_section_type null). "Benefits" had `inferred_section_type: "benefits"` when rule said null for explicit headings (inconsistency, same as Glide).

**v2 result:** 5 sections (v1 had 4).

### Did v1 defects get fixed?

**null/null violation: FIXED.** Section 1 now has `heading: null, inferred_section_type: "company_about"`. The null/null enforcement (change #2) worked.

**inferred_section_type inconsistency: FIXED by design.** Same as Glide -- the v2 rule now always populates inferred_section_type. "Benefits" still has `"benefits"`, which is now correct under the new rules.

### New defects introduced?

**NEW: "Who we are" section split and content loss.** v1 had a single "Who we are" section (1316 chars) containing both the company founding narrative and the bulleted values list ("We work remotely", "We work flexibly", etc.). v2 splits this into:
- Section 3 "Who we are" (553 chars): company founding narrative only.
- Section 4 heading `null`, `inferred_section_type: "culture"` (760 chars): the bulleted values list only.

The split itself is reasonable -- the company description and the culture values are conceptually different. But there is an issue: Section 3 "Who we are" has `inferred_section_type: "non_criteria"` which is not a valid enum value. Same defect as the housekeeper "Pay & Schedule" case. It should be `"company_about"`.

**NEW: `inferred_section_type: "non_criteria"` on Section 3.** Invalid enum value, same issue as housekeeper. The model used the type value as the inferred value instead of providing a meaningful classification like `"company_about"`.

### Section count and tagging accuracy

5 sections (up from 4). The additional section comes from splitting "Who we are" content.
- Section 1: `non_criteria` / `company_about` -- correct.
- Section 2 "Who are you?": `criteria` / `criteria` -- correct.
- Section 3 "Who we are": `non_criteria` / `non_criteria` -- DEFECTIVE inferred value.
- Section 4 (no heading): `non_criteria` / `culture` -- correct classification.
- Section 5 "Benefits": `non_criteria` / `benefits` -- correct.

### Content completeness

Complete. All content from the source is present. The company narrative and values list are both preserved, just in separate sections. The `&amp;` HTML entity in "Sprinklr &amp; Sprout" was not decoded (present as `&amp;`). Same entity appears in the "Hybrid remote &amp; flexible working hours" benefits item. This is the same HTML entity issue as the elixir `&#39;` case.

### inferred_section_type accuracy

4/5 correct. Section 3 uses invalid value `"non_criteria"`. No null/null violations.

---

## 5. sales-manager-de.json -- Sales Manager (Franklin Institute)

**v1 defects:** STRING `"null"` BUG on Section 1 (inferred_section_type was the string "null" instead of JSON null). null/null violation on Section 1 (even if it had been real null). "Deine Aufgaben" and "Dein Profil" headings correctly extracted from plain `<p>` text.

**v2 result:** 5 sections (v1 had 6).

### Did v1 defects get fixed?

**String "null" bug: FIXED.** No string "null" values anywhere in v2. All null values are JSON null. The JSON null formatting instruction (change #4) worked.

**null/null violation: FIXED.** Section 1 now has `heading: null, inferred_section_type: "company_about"`. The null/null enforcement (change #2) worked.

### New defects introduced?

**NEW: "Uber uns:" heading dropped.** v1 had 6 sections: the tagline (Section 1) and "Uber uns:" company description (Section 2) were separate sections with the "Uber uns:" heading properly extracted. v2 merged them into a single Section 1 with `heading: null` and `inferred_section_type: "company_about"`. The heading text "Uber uns:" does not appear anywhere in the v2 output -- not in the heading field, not in the content field. It was silently dropped.

This violates the "never drop content" rule (change #1). The heading text is part of the source document. Even if it's reasonable to merge the tagline and company description into one section, the heading text must be preserved somewhere (either as the section heading or within the content).

**NEW: Escaped newlines instead of actual newlines.** v2 content fields contain literal `\n` (two characters: backslash + n) instead of actual newline characters. For example, Section 2 content reads: `Fuhrung von Verkaufsgesprachen...\nUnterstutzung bei der Erstellung...` where `\n` is a literal two-character escape, not a newline. v1 used actual newline characters. This is a regression that will cause downstream display issues (content will show `\n` literally instead of line breaks). This defect is not present in the other v2 results (elixir, glide, levellr use period-separated sentences; housekeeper and video-production use actual newlines).

### Section count and tagging accuracy

5 sections (down from 6). The reduction comes from merging the tagline and company description.
- Section 1: `non_criteria` / `company_about` -- correct type, but heading "Uber uns:" dropped.
- Section 2 "Deine Aufgaben:": `criteria` / `criteria` -- correct.
- Section 3 "Dein Profil:": `criteria` / `criteria` -- correct.
- Section 4 "Wir bieten:": `non_criteria` / `benefits` -- correct.
- Section 5 (no heading): `non_criteria` / `process_meta` -- correct.

### Content completeness

INCOMPLETE. The heading text "Uber uns:" was dropped. All other content is present, including the full tagline, company description, all list items, and the trailing CTA.

### inferred_section_type accuracy

All 5 sections have correct inferred_section_type values. No null/null violations. No invalid values. This is the only v2 JD where inferred_section_type is fully correct.

---

## 6. video-production.json -- Video Production Specialist (Walrus Audio)

**v1 defects:** "Job Detail" section tagged `non_criteria` despite containing role requirements prose (criteria). `inferred_section_type: null` for criteria sections with explicit headings. "*Additional Skills and Responsibilities*" heading preserved with asterisks/formatting artifacts.

**v2 result:** 7 sections.

### Did v1 defects get fixed?

**"Job Detail" criteria classification: FIXED.** v1 had `type: "non_criteria"` for "Job Detail". v2 correctly has `type: "criteria"`. The role description prose reinforcement (change #6) worked. This is the single most impactful fix across all JDs -- the section contains real skill requirements (multi-disciplinary, writer/producer, cinematographer, editor, sound designer, animator, motion graphics, VFX, sound design, color correction) that will now be scored.

**Criteria inferred_section_type: FIXED.** All criteria sections now have `inferred_section_type: "criteria"` instead of `null`. Same improvement as Glide.

**Asterisks in heading: FIXED.** v1 heading was `"*Additional Skills and Responsibilities*"`. v2 heading is `"Additional Skills and Responsibilities"` (no asterisks). The model cleaned up the formatting artifacts.

### New defects introduced?

None. This is the cleanest v2 result.

### Section count and tagging accuracy

7 sections, same as v1. All tagging correct:
- Section 1 "Job Detail": `criteria` / `criteria` -- IMPROVED from v1.
- Section 2 "About Our Company": `non_criteria` / `company_about` -- correct.
- Section 3 "Responsibilities": `criteria` / `criteria` -- correct.
- Section 4 "Personal and Organizational Skills": `criteria` / `criteria` -- correct.
- Section 5 "Additional Skills and Responsibilities": `criteria` / `criteria` -- correct.
- Section 6 "Job Requirements": `criteria` / `criteria` -- correct.
- Section 7 "Compensation and Benefits": `non_criteria` / `benefits` -- correct.

### Content completeness

Complete. All content from the source is present. All 7 sections have full content. "Bachelor's degree preferred" standalone paragraph correctly included in the "Job Requirements" section.

### inferred_section_type accuracy

All 7 sections correct. No null/null violations. No invalid values.

---

## Cross-cutting Issues

### 1. `inferred_section_type: "non_criteria"` -- new invalid enum value (housekeeper, levellr)

Two JDs have sections where `inferred_section_type` is set to `"non_criteria"`, which is the same value as the `type` field and provides no additional information. This happens on:
- housekeeper Section 3 "Pay & Schedule" -- should be `"benefits"` or `"compensation"`
- levellr Section 3 "Who we are" -- should be `"company_about"`

The model appears to fall back to echoing the `type` value when it is unsure of the appropriate inferred_section_type enum value. The prompt needs to explicitly list the valid enum values and state that `inferred_section_type` must be one of those values, never the `type` value repeated.

### 2. Heading text dropped (sales-manager-de)

The "Uber uns:" heading text was dropped entirely when the model merged the tagline and company description into one section. The content of both original sections is present, but the heading text itself is gone. This violates the "never drop content" rule. The prompt's "never drop content" instruction focuses on sentences, but heading text is also content.

### 3. HTML entities not decoded (elixir, levellr)

v2 introduced a regression: `&#39;` in the elixir content and `&amp;` in the levellr content are passed through literally instead of being decoded to `'` and `&`. v1 decoded `&#39;` correctly for elixir (the v1 section 1 content had the second paragraph dropped, but the first paragraph decoded it). This is likely caused by v2 being more literal about preserving source content. The prompt needs a "decode HTML entities to their character equivalents" instruction.

### 4. Escaped newlines in sales-manager-de

The sales-manager-de result uses literal `\n` (two characters) instead of actual newline characters in all content fields. This is inconsistent with the other v2 results and will cause display issues downstream. The model may have been confused by the German content or the specific HTML structure. This is an intermittent model behavior issue, not a systematic prompt defect, but a prompt instruction could prevent it.

### 5. Heading extraction failure persists (glide)

The H1 "Welcome to Glide!" heading is still merged into content instead of being extracted to the heading field. The heading extraction rule (change #8) did not fix this case. The model may be treating the introductory H1 as "title" content rather than a section heading. The prompt may need a more explicit instruction: "If the first element in the HTML is an h1-h6 tag, extract its text as the heading of the first section."

### 6. Section over-splitting (housekeeper, levellr)

v2 produced more sections than v1 for two JDs:
- housekeeper: 6 sections (v1: 5) -- "Job Overview" split into company_about + criteria
- levellr: 5 sections (v1: 4) -- "Who we are" split into company_about + culture

Both splits are defensible (they separate content with different types), but they create sections with `heading: null` that didn't exist in the source structure. The housekeeper split is particularly odd because "Job Overview" now heads a single sentence. This may be an overcorrection from the "role description prose is criteria" reinforcement (change #6) and the mixed section guidance (change #7).

### 7. Content formatting inconsistency

v2 results show three different content formatting approaches:
- **Period-separated sentences** (elixir section 2, glide, levellr sections 2/3/4): list items joined with periods as sentence separators.
- **Newline-separated items** (housekeeper, video-production): list items separated by actual newline characters.
- **Escaped newline-separated items** (sales-manager-de): list items separated by literal `\n`.

v1 consistently used newline separation for list items. The v2 prompt changes may have inadvertently introduced variability. For scoring purposes, the format doesn't matter much, but the escaped newlines in sales-manager-de would cause issues.

---

## v1 Defect Scorecard

| # | Defect | JD | Status |
|---|---|---|---|
| D1 | Dropped second paragraph entirely | elixir | **FIXED** |
| D2 | "Base Requirements" plain `<p>` not extracted as heading | elixir | **FIXED** |
| D3 | Raw HTML `<ul>/<li>` tags in content | elixir | **FIXED** |
| D4 | H1 "Welcome to Glide!" merged into content, not heading | glide | **STILL PRESENT** |
| D5 | Missing space between "Glide!" and "At" | glide | **FIXED** |
| D6 | Criteria sections had `inferred_section_type: null` | glide | **FIXED** |
| D7 | Non-criteria inferred_section_type inconsistency (benefits vs null) | glide, levellr | **FIXED** (by design change) |
| D8 | `inferred_section_type: null` for all sections (lost type metadata) | housekeeper | **PARTIALLY FIXED** -- 4/6 correct, 1 invalid value, 1 debatable |
| D9 | "Job Overview" non_criteria despite criteria-adjacent content | housekeeper | **FIXED** (via split) |
| D10 | "Pay & Schedule" non_criteria despite Sunday requirement | housekeeper | **STILL PRESENT** (by design -- mixed section rule) |
| D11 | null/null violation on Section 1 | levellr | **FIXED** |
| D12 | String `"null"` instead of JSON null | sales-manager-de | **FIXED** |
| D13 | null/null violation on Section 1 | sales-manager-de | **FIXED** |
| D14 | "Job Detail" tagged non_criteria despite criteria prose | video-production | **FIXED** |
| D15 | `inferred_section_type: null` for criteria sections | video-production | **FIXED** |
| D16 | Asterisks in "*Additional Skills and Responsibilities*" heading | video-production | **FIXED** |

**Summary:** 11 FIXED, 1 PARTIALLY FIXED, 2 STILL PRESENT, 2 FIXED by design.

---

## New Defects in v2

| # | Defect | JD | Severity |
|---|---|---|---|
| N1 | HTML entity `&#39;` not decoded to apostrophe in content | elixir | LOW -- cosmetic but indicates model is too literal with source HTML |
| N2 | HTML entity `&amp;` not decoded in content | levellr | LOW -- same root cause as N1 |
| N3 | `inferred_section_type: "non_criteria"` -- invalid enum value | housekeeper, levellr | MEDIUM -- echoes type field instead of providing useful classification |
| N4 | "Uber uns:" heading text silently dropped | sales-manager-de | MEDIUM -- violates never-drop-content rule |
| N5 | Literal `\n` (two chars) instead of actual newlines | sales-manager-de | MEDIUM -- will cause display issues |
| N6 | "Job Overview" heading reassigned to cover only one sentence | housekeeper | LOW -- debatable, but odd heading/content relationship |
| N7 | "Who we are" section split creates headingless culture section | levellr | LOW -- the split is defensible but adds complexity |

---

## Prompt Changes for v3

### Must fix

1. **Explicitly list valid `inferred_section_type` enum values.** The current prompt should say: "inferred_section_type must be one of: `company_about`, `benefits`, `culture`, `process_meta`, `legal`, `criteria`. Never use `non_criteria` or any value not in this list." This fixes N3.

2. **Add HTML entity decoding instruction.** Add: "Decode all HTML entities to their character equivalents in the output (e.g., `&#39;` becomes `'`, `&amp;` becomes `&`, `&lt;` becomes `<`). Do not pass HTML entities through literally." This fixes N1 and N2.

3. **Extend "never drop content" rule to include heading text.** Amend to: "Every sentence AND every heading from the input must appear in the output. If you merge sections, the heading text of the absorbed section must appear either as the merged section's heading or within its content." This fixes N4.

4. **Add newline formatting instruction.** Add: "Use actual newline characters in JSON strings, not escaped `\\n` sequences. In JSON, a newline within a string value should be represented as `\n` (the JSON escape), not as a literal backslash followed by the letter n." This fixes N5.

### Should fix

5. **Strengthen first-element heading extraction.** The "Welcome to Glide!" H1 is still missed. Add: "If the input starts with an h1-h6 tag, always extract its text into the heading field of the first section, even if the heading text is a greeting or welcome message." This targets D4.

6. **Add guidance on section splitting vs. mixed tagging.** The model sometimes splits sections to isolate criteria content (housekeeper "Job Overview"), sometimes keeps them together (housekeeper "Pay & Schedule"). Add: "When splitting a section to separate criteria from non_criteria content, ensure the resulting sections each have meaningful content (at least 2-3 sentences or list items). Do not create single-sentence sections by splitting." This targets N6.

7. **Add `"compensation"` to the valid inferred_section_type enum.** "Pay & Schedule" sections don't fit cleanly into the existing enum. Adding `"compensation"` as a valid value would give the model a correct option for pay/schedule/salary sections that aren't benefits.

### Consider for v3 or later

8. **Content formatting consistency.** The model uses three different approaches for list items (periods, newlines, escaped newlines). Consider adding: "Format list items as one item per line, separated by newline characters. Do not join list items into a single sentence with period separators."

9. **Revisit mixed section handling.** "Pay & Schedule" still suppresses the "Sunday availability is mandatory" requirement. The current rule (tag by dominant content) is pragmatic but lossy. An alternative: "If a non_criteria section contains a concrete logistics or scheduling requirement that a candidate must meet (e.g., 'Sunday availability is mandatory', 'must be willing to relocate'), note this in a separate `has_criteria_items` boolean field." This avoids splitting but signals the downstream scorer to look inside.
