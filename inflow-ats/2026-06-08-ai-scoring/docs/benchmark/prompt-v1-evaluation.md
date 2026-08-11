# Prompt v1 Evaluation

Model: gpt-4o-mini | Prompt: prompt-v1.txt

## 1. elixir.json -- Elixir Developer (Select)

**Source:** 1 paragraph of company intro, 1 paragraph of role pitch, "Base Requirements" as bold text (not an HTML heading), then a `<ul>` list of 7 items.

**Result:** 2 sections.

### Section count

PROBLEM. The source has 3 logical blocks:
1. Company intro paragraph ("Select, a leading US consumer brand marketing firm...")
2. Role pitch paragraph ("We're seeking purpose-led, results oriented technology professionals...")
3. "Base Requirements" list

The model produced 2 sections: company_about and criteria. The role pitch paragraph was dropped entirely (see Content completeness below). If it had been preserved, the question is where it belongs -- it straddles company_about (describes the product) and criteria (describes the kind of candidate sought: "purpose-led, results oriented technology professionals"). The most defensible split would be 2 non_criteria sections (company + role pitch) and 1 criteria section (Base Requirements), or the role pitch merged into company_about. Either way, the content must not be dropped.

### criteria vs non_criteria tagging

Correct. Company intro is non_criteria; requirements list is criteria.

### inferred_section_type accuracy

Section 1: `inferred_section_type: "company_about"` -- correct.
Section 2: `inferred_section_type: "criteria"` -- this is the criteria section, but the heading is null and the prompt says "For criteria sections, always use: criteria." The heading is null because "Base Requirements" is bold text within a `<p>` tag, not a standalone heading. The model should have extracted "Base Requirements" as the heading. Since it didn't, it correctly used `inferred_section_type: "criteria"`. Acceptable but not ideal.

### null/null violations

None.

### Content completeness

MAJOR PROBLEM. The second paragraph is completely missing:

> "We're seeking purpose-led, results oriented technology professionals for remote location opportunities to help bring to life an exciting platform that changes how brands activate in market. The successful candidates will apply an agile methodology and simple test and learn toolkit to solving challenges as our application evolves in the market. Thousands of client users on the product allow a unique opportunity to iterate and make progress with both thought and pace."

This paragraph contains scorable content ("purpose-led, results oriented technology professionals," "agile methodology," "simple test and learn toolkit"). Dropping it silently is the worst kind of failure -- content lost with no indication.

### Other issues

- The "Base Requirements" bold text was not extracted as a heading. The source HTML is `<p>Base Requirements</p>` (not bold/strong), so the model may not have recognized it as a heading. But it functions as one contextually. The prompt says "bold/strong standalone text" counts as a heading, but this is a plain `<p>` -- so technically the prompt didn't cover this case. This is a prompt gap.

---

## 2. glide.json -- Senior Software Engineer Fullstack (Glide)

**Source:** H1 heading "Welcome to Glide!" with company intro paragraphs, then H1 sections for "Your Responsibilities:", "Need-to-Have's:", "Nice-to-Have's:", "Perks and Benefits:" (with H3 sub-headings for individual perks), and "Any Questions?".

**Result:** 6 sections.

### Section count

Correct. The 6 sections map cleanly to the 6 top-level blocks in the HTML. The "Perks and Benefits" section correctly flattened the H3 sub-headings (Competitive Compensation, Wellbeing Credits, Lunch on us, Best Tools) into a single benefits section rather than splitting each sub-heading into its own section. This is the right call -- they're all benefits.

### criteria vs non_criteria tagging

Correct across the board:
- Welcome/company intro: non_criteria
- Responsibilities, Need-to-Have's, Nice-to-Have's: criteria
- Perks and Benefits: non_criteria
- Any Questions: non_criteria

### inferred_section_type accuracy

- Section 1 (no heading extracted -- the H1 "Welcome to Glide!" was not captured): `company_about` -- correct.
- Section 2 "Your Responsibilities:": `null` -- correct per prompt rules (heading is explicit).
- Section 3 "Need-to-Have's:": `null` -- correct.
- Section 4 "Nice-to-Have's:": `null` -- correct.
- Section 5 "Perks and Benefits:": `benefits` -- correct, though the heading is already explicit. The prompt says "Use null when the heading is explicit and unambiguous." "Perks and Benefits" is unambiguous, so this should arguably be `null`. Minor inconsistency but not harmful.
- Section 6 "Any Questions?": `process_meta` -- correct classification.

### null/null violations

Section 1 has heading null but inferred_section_type is `company_about`, so no violation. However, the H1 heading "Welcome to Glide!" exists in the HTML and should have been extracted as the heading. The model dropped it.

### Content completeness

Good. All content from the source is present. The benefits sub-sections are correctly merged into one content block. No dropped content.

### Other issues

- The H1 "Welcome to Glide!" heading was not captured. The model merged the heading text into the content field (the content starts with "Welcome to Glide!At Glide we're..."). This is a heading extraction failure -- the text is there but it should be in the `heading` field.
- Minor: missing space between "Glide!" and "At" in the content ("Welcome to Glide!At Glide we're"). This is a whitespace handling issue from the HTML parsing, not a prompt issue.

---

## 3. housekeeper.json -- Housekeeper (Renjoy)

**Source:** Bold standalone text headings (via `<strong>` inside `<p>`): "Job Overview", "Pay & Schedule", "What You'll Do", "What We're Looking For", "Why Renjoy". All prose-heavy, non-tech.

**Result:** 5 sections.

### Section count

Correct. All 5 sections from the source are present.

### criteria vs non_criteria tagging

- "Job Overview": `non_criteria` -- DEBATABLE. The section includes company description ("Renjoy manages 200+ vacation rental properties...") and a brief role context statement. But it also includes "No resume required. Show up consistently, work hard, and communicate well." -- which is a candidate requirement (consistency, hard work, communication). The company intro portion is non_criteria, but the "what matters" statement is criteria-adjacent. Tagging the whole section as non_criteria is a reasonable judgment call since the bulk is company/role overview.
- "Pay & Schedule": `non_criteria` -- CORRECT. This is compensation/logistics info, not candidate requirements. However, it contains "Sunday availability is mandatory" which is a scheduling requirement that a candidate must meet. The prompt says "Physical or logistics requirements" are criteria. This is a mixed section where the model chose the dominant theme. Defensible but lossy for scoring purposes -- the Sunday requirement should be scorable.
- "What You'll Do": `criteria` -- correct.
- "What We're Looking For": `criteria` -- correct.
- "Why Renjoy": `non_criteria` -- correct. This is culture/employer value prop.

### inferred_section_type accuracy

All sections have explicit headings extracted correctly. `inferred_section_type` is `null` for all 5 sections. Per the prompt rule ("Use null when the heading is explicit and unambiguous"), this is technically correct for "Pay & Schedule" (unambiguous heading). But "Job Overview" and "Why Renjoy" are somewhat ambiguous -- "Job Overview" could be company_about or criteria, and "Why Renjoy" is clearly culture. Using null for these is consistent with the prompt rule, but it means downstream consumers have no machine-readable signal for section type beyond the heading text and the criteria/non_criteria flag.

QUESTION FOR v2: Should `inferred_section_type` always be populated for non_criteria sections, even when the heading is explicit? The current rule ("Use null when the heading is explicit and unambiguous") leaves non_criteria sections without useful type metadata. The type field only says "non_criteria" -- it doesn't distinguish company_about from benefits from culture. For criteria sections this doesn't matter (they're all just "criteria"), but for non_criteria it loses information.

### null/null violations

None. All sections have explicit headings.

### Content completeness

Complete. All source content is present in the result.

### Other issues

- "Why Renjoy" has `inferred_section_type: null` when it could usefully be tagged as `culture`. The heading "Why Renjoy" is not self-evidently "culture" to a machine -- a human can infer it, but the heading alone doesn't say it. This is a case where `inferred_section_type` would add value but the prompt rule suppresses it.
- "Pay & Schedule" has `inferred_section_type: null` but should probably be `benefits` if we want non_criteria type information preserved.

---

## 4. levellr.json -- Full Stack Engineer (Levellr)

**Source:** Opening paragraph (no heading), then H2 "Who are you?", H1 "Who we are" (with intro paragraphs + bullet values list), H1 "Benefits" (with intro paragraph + bullet list).

**Result:** 4 sections.

### Section count

Correct. The 4 sections map to: intro paragraph, "Who are you?" requirements, "Who we are" company description, "Benefits" list.

### criteria vs non_criteria tagging

- Intro paragraph: `non_criteria` -- correct. Company/role pitch.
- "Who are you?": `criteria` -- correct. This is requirements despite the creative heading.
- "Who we are": `non_criteria` -- correct. Company description.
- "Benefits": `non_criteria` -- correct.

The prompt says "When a heading is ambiguous or creative, classify based on the content, not the heading." The model correctly identified "Who are you?" as criteria based on content (requirements list) rather than the question-format heading. Good.

### inferred_section_type accuracy

- Section 1 (heading null): `null` -- **NULL/NULL VIOLATION.** See below.
- Section 2 "Who are you?": `criteria` -- correct. The heading is creative/ambiguous, so providing `inferred_section_type` is appropriate here.
- Section 3 "Who we are": `company_about` -- correct. The heading is creative/ambiguous, so inference is appropriate.
- Section 4 "Benefits": `benefits` -- the heading "Benefits" is explicit and unambiguous, so per the prompt rule this should be `null`. Same inconsistency as the Glide "Perks and Benefits" case. Minor.

### null/null violations

**Section 1: heading is null, inferred_section_type is null.** This violates the prompt rule: "heading and inferred_section_type must never both be null. When there is no heading, you must infer the section type from its content." The content is a company/role pitch paragraph. `inferred_section_type` should be `company_about`.

### Content completeness

Complete. All source content is present.

### Other issues

- The null/null violation on Section 1 is the primary defect.
- The "Who we are" section correctly includes both the intro paragraphs and the bulleted values list as one section. Good -- these are all part of the company description, not separate culture vs. company sections.

---

## 5. sales-manager-de.json -- Sales Manager (Franklin Institute)

**Source:** German language. Opening italic quote, then bold "Uber uns:" followed by company description, then plain-text headings "Deine Aufgaben:" (tasks), "Dein Profil:" (requirements), "Wir bieten:" (benefits), and a trailing CTA paragraph.

**Result:** 6 sections.

### Section count

Correct. The 6 sections map to: opening quote, company section, tasks, profile/requirements, benefits, and trailing CTA. Good split.

### criteria vs non_criteria tagging

- Opening quote: `non_criteria` -- correct. It's a tagline/motto.
- "Uber uns:": `non_criteria` -- correct. Company description.
- "Deine Aufgaben:": `criteria` -- correct. Job responsibilities.
- "Dein Profil:": `criteria` -- correct. Candidate requirements.
- "Wir bieten:": `non_criteria` -- correct. Benefits.
- Trailing CTA: `non_criteria` -- correct. Application invitation.

### inferred_section_type accuracy

- Section 1 (heading null): `"null"` -- **STRING "null" BUG.** The value is the string `"null"` (with quotes in the JSON), not JSON null. This is likely a model output formatting error. The model was trying to say "I can't infer the type" but produced the string "null" instead of the JSON value null. Furthermore, even if it were real null, this would be a null/null violation -- heading is null, so inferred_section_type must be populated. The content is an inspirational tagline/motto. This could be tagged as `company_about` or `culture`.
- Section 2 "Uber uns:": `company_about` -- correct.
- Section 3 "Deine Aufgaben:": `criteria` -- correct. The heading is explicit in German ("Your Tasks") but since it's non-English, the model may have correctly inferred rather than assumed it's unambiguous. Acceptable.
- Section 4 "Dein Profil:": `criteria` -- correct.
- Section 5 "Wir bieten:": `benefits` -- correct.
- Section 6 (heading null): `process_meta` -- correct. This is a "how to apply" CTA.

### null/null violations

**Section 1: heading is null, inferred_section_type is the string `"null"`.** This is both a null/null violation (the intent was null) and a JSON formatting bug (string "null" instead of JSON null). The content is a tagline that should be classified as `company_about` or `culture`.

### Content completeness

Complete. All German text is preserved in original language. The trailing CTA was correctly separated from the "Wir bieten" list.

### Other issues

- The string `"null"` bug is a model output issue. The prompt should be more explicit about output format, or the parsing code should handle this case.
- The source HTML has "Deine Aufgaben:" and "Dein Profil:" as plain `<p>` text, not bold/strong. The model correctly identified them as section headings despite the lack of HTML heading markup. But the "Uber uns:" heading has `<strong>` in the source, while the others don't. The model handled this inconsistent markup well.
- NOTE: In the source HTML, the trailing CTA is nested inside the last `<li>` of the "Wir bieten:" list (after empty `<p>` tags). The model correctly separated it as its own section despite this malformed nesting. Good.

---

## 6. video-production.json -- Video Production Specialist (Walrus Audio)

**Source:** Bold headings: "Job Detail", "About Our Company", "Responsibilities", "Personal and Organizational Skills", "*Additional Skills and Responsibilities*" (italic with asterisks), "Job Requirements", "Compensation and Benefits". Dense, many sections.

**Result:** 7 sections.

### Section count

Correct. All 7 sections from the source are present with proper boundaries.

### criteria vs non_criteria tagging

- "Job Detail": `non_criteria` -- DEBATABLE. This section describes what the role does ("responsible for creating incredible video content," "handles all aspects of film production -- editing, motion graphics design, visual effects, sound design and mixing, color correction, and encoding"). The prompt says "Generic role descriptions (job description, job purpose)" are criteria. This section is a role description with embedded skill requirements (multi-disciplinary, writer/producer, cinematographer, editor, sound designer, animator). Tagging it as non_criteria means these implied requirements won't be scored. The section reads more like a criteria section that happens to be written in narrative form.
- "About Our Company": `non_criteria` -- correct.
- "Responsibilities": `criteria` -- correct.
- "Personal and Organizational Skills": `criteria` -- correct.
- "*Additional Skills and Responsibilities*": `criteria` -- correct.
- "Job Requirements": `criteria` -- correct.
- "Compensation and Benefits": `non_criteria` -- correct.

### inferred_section_type accuracy

- Section 1 "Job Detail": `null` -- the heading is explicit but ambiguous. "Job Detail" could be company_about, criteria, or a role overview. Since the model tagged it non_criteria, having `inferred_section_type: null` means there's no signal about what kind of non_criteria it is. It should probably have an inference.
- Section 2 "About Our Company": `company_about` -- correct. Heading is fairly explicit, but inference is useful.
- Sections 3-6 (criteria sections): all `null` -- correct per prompt rules (explicit headings on criteria sections).
- Section 7 "Compensation and Benefits": `benefits` -- correct.

### null/null violations

None. All sections have explicit headings.

### Content completeness

Complete. All content from the source is present. The "*Additional Skills and Responsibilities*" heading was captured including the asterisks (the source uses `*<em>...</em>*` which is unusual markup). The content under "Job Requirements" correctly includes "Bachelor's degree preferred" which is a standalone `<p>` before the `<ul>` list in the source.

### Other issues

- "Job Detail" as non_criteria is the biggest concern. The section contains role-defining content that a recruiter would match candidates against: "multi-disciplinary position," "writer/producer, cinematographer, editor, sound designer, and animator," "handles all aspects of film production." These are effectively criteria expressed as a job description narrative.
- The "*Additional Skills and Responsibilities*" heading was preserved with its asterisks. This is faithful to the source but means the heading has formatting artifacts. Minor.

---

## Cross-cutting Issues

### 1. Content dropped silently (elixir.json)

The entire second paragraph of the Elixir JD was dropped. This is the most serious defect found. If the model doesn't understand where content belongs, it should still include it somewhere -- dropping it silently means the scoring pipeline will never see it.

### 2. null/null violations (levellr.json, sales-manager-de.json)

Two JDs have sections where both heading and inferred_section_type are null (or the string "null"), violating the explicit prompt rule. The prompt states this clearly, but the model ignores it in edge cases (headingless intro paragraphs).

### 3. String "null" vs JSON null (sales-manager-de.json)

The model produced the string `"null"` instead of JSON null for inferred_section_type. This is a parsing hazard -- code checking `section.inferred_section_type == null` will not match the string "null".

### 4. Heading extraction failures

- elixir.json: "Base Requirements" in a plain `<p>` tag was not extracted as a heading.
- glide.json: The H1 "Welcome to Glide!" was merged into content instead of being captured as the heading.

Both are HTML parsing issues. The prompt says to split on "h1-h6, bold/strong standalone text" but doesn't cover plain `<p>` text that functions as a heading (elixir case). The Glide case is a straightforward extraction failure.

### 5. inferred_section_type inconsistency for explicit non_criteria headings

The prompt says "Use null when the heading is explicit and unambiguous." This is applied inconsistently:
- glide.json "Perks and Benefits:" gets `inferred_section_type: "benefits"` (should be null per rule)
- levellr.json "Benefits" gets `inferred_section_type: "benefits"` (should be null per rule)
- housekeeper.json "Pay & Schedule" gets `inferred_section_type: null` (correct per rule)

But the null-when-explicit rule is actually counterproductive for non_criteria sections. Without inferred_section_type, the only metadata is `type: "non_criteria"` and the heading text. Downstream consumers can't distinguish company_about from benefits from culture without parsing the heading themselves. The model's "incorrect" behavior (always providing inferred_section_type for non_criteria) is actually more useful.

### 6. "Job Detail" / role description sections misclassified as non_criteria

The video-production "Job Detail" section contains role requirements expressed as narrative prose. The prompt lists "Generic role descriptions (job description, job purpose)" as criteria, but the model tagged it non_criteria. This suggests the model is biased toward treating narrative prose as non_criteria and only tagging bullet-list-style content as criteria.

### 7. Mixed sections lose scorable content

- housekeeper.json "Pay & Schedule" is tagged non_criteria but contains "Sunday availability is mandatory" -- a concrete logistics requirement.
- housekeeper.json "Job Overview" is tagged non_criteria but contains "Show up consistently, work hard, and communicate well. That's what matters." -- candidate attributes.

The prompt doesn't address mixed sections. When a section has both compensation info and logistics requirements, the model must choose one tag. Currently it picks the dominant theme, which means minority-content criteria items get suppressed.

---

## Prompt v2 Changes

### Must fix

1. **Add explicit rule: never drop content.** Add to the prompt: "Every sentence from the input must appear in exactly one section's content field. Do not drop, summarize, or omit any content. If you are unsure where content belongs, include it in the nearest section."

2. **Strengthen null/null enforcement with an example.** The current rule is clear ("heading and inferred_section_type must never both be null") but the model violates it. Add an explicit example:
   ```
   Example -- content before any heading:
   heading: null
   inferred_section_type: "company_about"  <-- REQUIRED when heading is null
   ```

3. **Always populate inferred_section_type for non_criteria sections.** Change the rule from "Use null when the heading is explicit and unambiguous" to: "For non_criteria sections, always provide inferred_section_type (one of: company_about, benefits, culture, process_meta, legal), even when the heading is explicit. For criteria sections, always use inferred_section_type: 'criteria'." This eliminates the inconsistency and ensures downstream consumers always have a machine-readable section type.

4. **Add JSON formatting instruction for null.** Add: "When a value should be null, output JSON null (without quotes), not the string 'null'."

5. **Expand heading detection beyond HTML heading tags.** Change "Split the job description into sections based on headings (h1-h6, bold/strong standalone text)" to: "Split the job description into sections based on headings (h1-h6, bold/strong standalone text, or any short standalone text line that introduces a list or new topic -- even if it lacks heading markup)." This covers the elixir "Base Requirements" case where a plain `<p>` functions as a heading.

### Should fix

6. **Reinforce that role description prose is criteria.** Add an explicit example or note: "A narrative paragraph describing what the role does and what skills the person needs is criteria, even if it reads like a 'job overview' rather than a bullet-point requirements list. Classify based on whether the content could be used to evaluate a candidate."

7. **Address mixed sections.** Add: "If a section contains both criteria and non_criteria content (e.g., a 'Pay & Schedule' section that includes compensation details AND a mandatory scheduling requirement), tag the section based on its dominant content but note that individual items within it may differ. Do not split the section -- keep it as one section with the dominant tag."
   - Alternative (more aggressive): "If a section contains both criteria and non_criteria content, split it into two sections at the boundary." This is cleaner for scoring but risks over-splitting.

8. **Heading extraction: capture the actual heading text.** Add: "When an HTML heading tag (h1-h6) contains text, always extract that text into the heading field. Do not merge heading text into the content field."

### Consider for v2 or later

9. **Add output validation rules the model can self-check.** Add a "Before returning, verify:" checklist:
   - Every sentence from the input appears in exactly one section
   - No section has both heading and inferred_section_type as null
   - Every non_criteria section has an inferred_section_type value
   - inferred_section_type for criteria sections is always "criteria"

10. **Consider whether "Job Detail" / "Job Overview" headings need special guidance.** These are common JD headings that can go either way (role overview vs. requirements narrative). Rather than adding a rule, this might be better addressed by the general "classify based on content" rule + the reinforcement in item 6 above.
