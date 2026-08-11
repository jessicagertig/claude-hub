# Prompt v3 Evaluation

Model: gpt-4o-mini | Prompt: prompt-v3.txt

## v3 Prompt Changes Applied

1. Explicitly listed valid `inferred_section_type` enum values (`company_about`, `benefits`, `compensation`, `culture`, `process_meta`, `legal`, `criteria`)
2. Added HTML entity decoding instruction
3. Extended "never drop content" rule to include heading text
4. Added newline formatting instruction (actual newlines, not escaped)
5. Strengthened first-element heading extraction for h1-h6
6. Added minimum section size for splits (at least 2-3 sentences)
7. Added "compensation" to the valid enum
8. Added list formatting guidance (one item per line)

---

## 1. elixir.json -- Elixir Developer (Select)

**v2 defects:** HTML entity `&#39;` not decoded to apostrophe (N1).

**v3 result:** 2 sections (same as v2).

### Did v2 defects get fixed?

**HTML entity `&#39;` not decoded: FIXED.** v2 content had `We&#39;re seeking`. v3 content has `We're seeking` -- the apostrophe is properly decoded. The HTML entity decoding instruction (change #2) worked.

### Regressions from v2?

None. Same section count, same structure, same headings, same types.

### Content completeness

Complete. Both paragraphs present. All 7 list items in Section 2 present. Compared against source JD: both `<p>` paragraphs fully preserved, all `<li>` items preserved including both `(bonus)` items.

### HTML entity decoding

Clean. No `&#39;`, `&amp;`, or other HTML entities remain in the output.

### Newline formatting

Correct. v3 uses actual newline characters. Section 1 separates the two paragraphs with `\n` (actual newline). Section 2 separates list items one per line with actual newlines. This is an improvement over v2, where section 2 used period-separated sentences.

### inferred_section_type

All valid:
- Section 1: `company_about` -- correct.
- Section 2: `criteria` -- correct.

### Heading extraction

N/A for this JD (no h1-h6 tags in source). "Base Requirements" still correctly extracted from plain `<p>` tag as in v2.

---

## 2. glide.json -- Senior Software Engineer Fullstack (Glide)

**v2 defects:** H1 "Welcome to Glide!" merged into content instead of heading field (D4, persisted from v1).

**v3 result:** 6 sections (same as v2).

### Did v2 defects get fixed?

**Heading "Welcome to Glide!" extraction: FIXED.** This was the most stubborn defect across v1 and v2. In v2, the heading was `null` and "Welcome to Glide!" was merged into the content as `"Welcome to Glide! At Glide we're..."`. In v3, `heading` is `"Welcome to Glide!"` (with the wave emoji preserved as in the source HTML) and the content starts with `"At Glide we're reimagining..."` -- clean separation. The strengthened first-element heading extraction rule (change #5) worked.

### Regressions from v2?

None. All 6 sections have identical structure, headings, types, and `inferred_section_type` values to v2. Content completeness is identical.

### Content completeness

Complete. All content from source present. The benefits sub-sections (Competitive Compensation, Wellbeing Credits, Lunch on us, Best Tools) are correctly merged into one section. The "Any Questions?" section with the email address is preserved.

Content formatting improved: v2 joined benefits sub-sections with spaces (single run-on paragraph). v3 separates them with newlines, making the structure much clearer with each sub-benefit on its own line.

### HTML entity decoding

Clean. The source uses `&amp;` in "infrastructure &amp; tooling" -- v3 renders this as `&` correctly.

### Newline formatting

Correct. All multi-item sections use actual newlines. The benefits section is particularly improved -- v2 had all four sub-benefits crammed into one space-separated paragraph; v3 puts each sub-benefit heading and description on separate lines.

### inferred_section_type

All valid:
- Section 1: `company_about` -- correct.
- Section 2-4: `criteria` -- correct.
- Section 5: `benefits` -- correct.
- Section 6: `process_meta` -- correct.

### Heading extraction

**FIXED.** The H1 `<h1><strong>Welcome to Glide!</strong></h1>` is now properly extracted into the heading field as `"Welcome to Glide!"`. The emoji is preserved. This was the single most persistent defect across v1 and v2.

---

## 3. housekeeper.json -- Housekeeper (Renjoy)

**v2 defects:** `inferred_section_type: "non_criteria"` invalid enum value on Pay & Schedule (N3). Questionable split of "Job Overview" into company_about + criteria single-sentence section (N6).

**v3 result:** 6 sections (same as v2).

### Did v2 defects get fixed?

**`inferred_section_type: "non_criteria"` on Pay & Schedule: FIXED.** v2 had `inferred_section_type: "non_criteria"` (echoing the type field). v3 correctly has `inferred_section_type: "benefits"`. The explicit enum list (change #1) worked.

**Single-sentence "Job Overview" split: PARTIALLY FIXED (with reclassification).** v2 split "Job Overview" into a headingless company_about section and a "Job Overview" criteria section containing only the single sentence "No resume required...". v3 keeps the same 6-section structure, but reclassifies "Job Overview" (Section 2) from `criteria` to `non_criteria` / `company_about`. The section is still a single sentence, which violates the minimum section size guidance (change #6), but the reclassification to `non_criteria` is arguably more defensible than `criteria` for the content "No resume required. Show up consistently, work hard, and communicate well."

### Regressions from v2?

**REGRESSION: "Job Overview" reclassified from criteria to non_criteria.** v2 correctly identified "No resume required. Show up consistently, work hard, and communicate well. That's what matters." as criteria -- it sets concrete expectations for candidates. v3 reclassifies it as `non_criteria` / `company_about`. While "Show up consistently, work hard" is cultural/aspirational, "No resume required" is a concrete criteria signal. The downstream scorer will now miss this section entirely. This is a criteria coverage regression -- the housekeeper JD went from 3 criteria sections in v2 to 2 in v3.

**Assessment of the regression:** This is a genuine regression, not a false alarm. The v2 evaluation noted the "Job Overview" split was questionable (N6) because it created a single-sentence section, but it correctly classified the criteria content. v3 fixed the classification problem by going the wrong direction -- instead of merging the sentence back into a larger section, it left it isolated and downgraded the type. The minimum section size rule (change #6) should have encouraged the model to merge it into the adjacent section rather than keeping it as a standalone non_criteria section.

### Content completeness

Complete. All content from the source JD is present. The company intro paragraph, all Pay & Schedule items, all "What You'll Do" prose, all "What We're Looking For" items (including the 5 bullet points), and all "Why Renjoy" prose are preserved.

### HTML entity decoding

N/A -- no HTML entities in source.

### Newline formatting

Mostly correct. Sections 3-6 use actual newlines for list separation. Sections 1-2 are single-sentence/paragraph content. Section 5 ("What We're Looking For") uses `\n- ` for the bulleted list items -- this preserves the dash prefix from the source HTML list markup, which is a reasonable formatting choice.

### inferred_section_type

All valid. No `"non_criteria"` echoing. All values are from the approved enum:
- Section 1: `company_about` -- correct.
- Section 2: `company_about` -- debatable (see regression above), but a valid enum value.
- Section 3: `benefits` -- FIXED from v2's `"non_criteria"`.
- Section 4-5: `criteria` -- correct.
- Section 6: `culture` -- correct.

### Heading extraction

N/A -- no h1-h6 tags in source. All headings come from `<strong>` tags and are correctly extracted.

---

## 4. levellr.json -- Full Stack Engineer (Levellr)

**v2 defects:** `inferred_section_type: "non_criteria"` on "Who we are" section (N3). HTML entity `&amp;` not decoded in content (N2). "Who we are" split creating headingless culture section (N7).

**v3 result:** 5 sections (same as v2).

### Did v2 defects get fixed?

**`inferred_section_type: "non_criteria"` on "Who we are": FIXED.** v2 had `inferred_section_type: "non_criteria"` on Section 3. v3 correctly has `inferred_section_type: "company_about"`. The explicit enum list (change #1) worked.

**HTML entity `&amp;` not decoded: FIXED.** v2 had `Sprinklr &amp; Sprout` and `Hybrid remote &amp; flexible working hours`. v3 has `Sprinklr & Sprout` and `Hybrid remote & flexible working hours` -- both decoded to `&`. The HTML entity decoding instruction (change #2) worked.

**"Who we are" split creating headingless culture section: STILL PRESENT.** v3 keeps the same 5-section structure as v2, with Section 3 "Who we are" covering the company narrative and Section 4 (heading null, `culture`) covering the bulleted values list. The split itself is defensible -- the two pieces are conceptually different. The headingless section is now correctly typed as `culture` (was `culture` in v2 too). This is not a regression, it's a structural choice that persists.

### Regressions from v2?

None. All sections have identical or improved content.

### Content completeness

Complete. All content from the source JD is present. Checked against source HTML:
- Intro paragraph with "fully remote full stack engineer" -- present in Section 1.
- All 10 "Who are you?" list items -- present in Section 2.
- Both "Who we are" company narrative paragraphs -- present in Section 3.
- All 6 culture bullet points -- present in Section 4.
- Benefits intro paragraph plus all 7 benefit items -- present in Section 5.

### HTML entity decoding

Clean. Both `&amp;` instances decoded:
- `Sprinklr & Sprout` (Section 1)
- `Hybrid remote & flexible working hours` (Section 5)

### Newline formatting

Mostly correct. Sections 2-5 use actual newlines. Section 1 (single paragraph) has no list items to separate. Minor inconsistency: Section 1 uses period-separation within the single paragraph (which is fine -- it's prose, not a list).

### inferred_section_type

All valid:
- Section 1: `company_about` -- correct.
- Section 2: `criteria` -- correct.
- Section 3: `company_about` -- FIXED from v2's `"non_criteria"`.
- Section 4: `culture` -- correct.
- Section 5: `benefits` -- correct.

### Heading extraction

N/A -- the source h1/h2 tags are "Who we are" and "Benefits", both correctly extracted in the heading field. No first-element heading issue.

---

## 5. sales-manager-de.json -- Sales Manager (Franklin Institute)

**v2 defects:** "Uber uns:" heading text silently dropped (N4). Literal `\n` (two characters) instead of actual newlines (N5).

**v3 result:** 5 sections (same as v2).

### Did v2 defects get fixed?

**"Uber uns:" heading text dropped: FIXED.** v2 merged the tagline and company description into one section and dropped the "Uber uns:" heading text entirely -- it appeared nowhere in the output. v3 preserves "Uber uns:" within the content of Section 1: the content reads `"Grenzen verschieben..." \n\nUber uns:\nDas Franklin Institute..."`. The heading text is preserved inline rather than in the heading field, which is acceptable given the section is a merged tagline + company description. The "never drop content" extension to heading text (change #3) worked.

**Literal `\n` instead of actual newlines: FIXED.** v2 had literal backslash-n two-character sequences throughout all content fields. When parsed by `json.load()`, v2 content contained `\\n` (literal backslash-n) while v3 content contains actual `\n` (newline characters). The newline formatting instruction (change #4) worked. This was confirmed by parsing: v3 sections have `has_actual_newlines=True` and `has_literal_backslash_n=False`, the exact inverse of v2.

### Regressions from v2?

None. Both defects fixed with no side effects.

### Content completeness

Complete. All content from the source JD is present:
- Tagline in quotes -- present in Section 1.
- "Uber uns:" heading text -- present in Section 1 content (was dropped in v2).
- Company description paragraph -- present in Section 1.
- All 5 "Deine Aufgaben" list items -- present in Section 2.
- All 5 "Dein Profil" list items -- present in Section 3.
- All 5 "Wir bieten" list items -- present in Section 4.
- Closing CTA paragraphs -- present in Section 5.

### HTML entity decoding

N/A -- no HTML entities in source (the source uses UTF-8 characters directly for umlauts and special characters).

### Newline formatting

Correct throughout. All list sections use actual newline characters to separate items. The tagline and company description in Section 1 are separated by a double newline. This is the single biggest improvement for this JD -- v2's escaped newlines would have caused display issues downstream.

### inferred_section_type

All valid:
- Section 1: `company_about` -- correct.
- Section 2-3: `criteria` -- correct.
- Section 4: `benefits` -- correct.
- Section 5: `process_meta` -- correct.

This remains the only JD where all `inferred_section_type` values are fully correct across all versions (v1 excluded due to string "null" bug).

### Heading extraction

N/A -- no h1-h6 tags in source. "Deine Aufgaben:", "Dein Profil:", and "Wir bieten:" are plain `<p>` text, correctly extracted as headings (unchanged from v2).

---

## 6. video-production.json -- Video Production Specialist (Walrus Audio)

**v2 defects:** None (v2 was the cleanest result).

**v3 result:** 7 sections (same as v2).

### Did v2 defects get fixed?

N/A -- v2 had no defects for this JD. v2 was the cleanest result.

### Regressions from v2?

**REGRESSION: "Job Detail" heading dropped and section reclassified from criteria to non_criteria.** This is the most significant regression in v3. In v2, Section 1 was:
- `heading: "Job Detail"`, `type: "criteria"`, `inferred_section_type: "criteria"`

In v3, Section 1 is:
- `heading: null`, `type: "non_criteria"`, `inferred_section_type: "company_about"`

This is a double regression:

1. **Heading "Job Detail" dropped.** The source HTML has `<p><strong>Job Detail</strong></p>` as a heading. v2 correctly extracted it. v3 dropped it entirely -- it does not appear in the heading field or in the content field. This violates the "never drop content" rule, including the v3 extension to heading text (change #3).

2. **Criteria content reclassified as non_criteria.** The section contains role requirements prose: "multi-disciplinary position," "writer/producer, cinematographer, editor, sound designer, and animator," "handles all aspects of film production -- editing, motion graphics design, visual effects, sound design and mixing, color correction, and encoding." This was the exact content that v2 correctly tagged as `criteria` after the v2 "role description prose is criteria" reinforcement. v3 undoes that fix.

The video-production JD went from 5 criteria sections in v2 to 4 in v3. The lost criteria section contains the richest description of required skills in the entire JD.

**Assessment:** This is a serious regression. The "Job Detail" section fix was called out in the v2 evaluation as "the single most impactful fix across all JDs." v3 reverted it entirely. The cause is likely the minimum section size rule (change #6) or the heading extraction strengthening (change #5) interfering with the model's understanding of `<strong>` headings in `<p>` tags. The model may have reinterpreted the "Job Detail" prose as a company/role description rather than criteria because the strengthened heading rules made it reconsider what constitutes a section header.

### Content completeness

INCOMPLETE. The heading text "Job Detail" is dropped. All other content (the two prose paragraphs, all list items across all sections) is present.

### HTML entity decoding

N/A -- no HTML entities in source.

### Newline formatting

Correct throughout. All list sections use actual newlines. v2 also used actual newlines for this JD, so no change. Minor improvement: period-ending punctuation is more consistent in v3 (list items don't have trailing periods added, matching the source more faithfully).

### inferred_section_type

All valid values, but Section 1 is misclassified:
- Section 1: `company_about` -- INCORRECT (should be `criteria`; see regression above).
- Section 2: `company_about` -- correct.
- Sections 3-6: `criteria` -- correct.
- Section 7: `benefits` -- correct.

### Heading extraction

The `<strong>` headings ("About Our Company", "Responsibilities", etc.) are all correctly extracted. But "Job Detail" (also a `<strong>` heading) was dropped. This is inconsistent -- the same markup pattern yields extraction in some cases and drops in others.

---

## Cross-cutting Analysis

### 1. HTML entity decoding: universally fixed

Both HTML entity defects from v2 are resolved:
- `&#39;` in elixir decoded to `'`
- `&amp;` in levellr decoded to `&` (both occurrences)

No remaining HTML entities found in any v3 result. The decoding instruction (change #2) was fully effective.

### 2. Newline formatting: universally fixed

The escaped newline defect in sales-manager-de is resolved. All v3 results use actual newline characters in JSON string values. Content formatting is also more consistent: most list sections use one-item-per-line newline separation. A few single-paragraph sections still use inline prose (no newlines), which is correct behavior for prose content.

Minor remaining inconsistency: the housekeeper "What We're Looking For" section uses `\n- ` (dash-prefixed list items) while other JDs use bare `\n` (no dash prefix). Both are acceptable, but it's a formatting variance.

### 3. `inferred_section_type` enum compliance: fully fixed

Zero instances of `"non_criteria"` as an `inferred_section_type` value in v3. All values are from the approved enum: `company_about`, `benefits`, `culture`, `process_meta`, `criteria`. The explicit enum list (change #1) was fully effective.

Zero null/null violations.

### 4. Heading text preservation: mixed results

The "never drop content" extension to heading text (change #3) produced mixed results:
- **sales-manager-de "Uber uns:"**: FIXED -- heading text preserved in content.
- **video-production "Job Detail"**: STILL DROPPED -- heading text lost entirely.

The video-production case is the more concerning one because "Job Detail" is a `<strong>` heading in a `<p>` tag, the same pattern used by other headings in the same JD ("About Our Company", "Responsibilities", etc.) that ARE extracted correctly. The model is applying the heading extraction inconsistently within a single JD.

### 5. Heading extraction for h1-h6 first elements: fixed

The "Welcome to Glide!" H1 heading is now correctly extracted into the heading field. This was the most persistent defect across v1 and v2. The strengthened first-element heading extraction rule (change #5) was effective.

### 6. Criteria classification regressions

Two JDs have criteria coverage regressions:

| JD | v2 criteria sections | v3 criteria sections | Lost section |
|---|---|---|---|
| housekeeper | 3 | 2 | "Job Overview" reclassified non_criteria |
| video-production | 5 | 4 | "Job Detail" reclassified non_criteria + heading dropped |

**Housekeeper regression severity: LOW.** The "Job Overview" content ("No resume required. Show up consistently, work hard, and communicate well.") is borderline criteria. The reclassification is defensible even if it loses a minor scoring signal.

**Video-production regression severity: HIGH.** The "Job Detail" content is the richest criteria prose in the entire JD, listing specific required disciplines (writer/producer, cinematographer, editor, sound designer, animator) and specific technical skills (editing, motion graphics, VFX, sound design, color correction). This was explicitly called out in the v2 evaluation as "the single most impactful fix." Losing it is a significant regression.

### 7. Content formatting improvements

v3 consistently improved content formatting:
- Benefits sections now have each sub-benefit on its own line (Glide "Perks and Benefits" went from one run-on paragraph to structured sub-sections).
- List items are consistently one per line across most JDs.
- The list formatting guidance (change #8) was effective.

### 8. Section structure stability

Section counts are identical to v2 for all 6 JDs. No new splits or merges were introduced. The minimum section size rule (change #6) appears to have stabilized the splitting behavior, though it did not fix the existing single-sentence "Job Overview" section in the housekeeper result.

---

## v2 Defect Scorecard

| # | Defect | JD | v3 Status |
|---|---|---|---|
| N1 | HTML entity `&#39;` not decoded to apostrophe | elixir | **FIXED** |
| N2 | HTML entity `&amp;` not decoded | levellr | **FIXED** |
| N3 | `inferred_section_type: "non_criteria"` invalid enum value | housekeeper, levellr | **FIXED** |
| N4 | "Uber uns:" heading text silently dropped | sales-manager-de | **FIXED** |
| N5 | Literal `\n` (two chars) instead of actual newlines | sales-manager-de | **FIXED** |
| N6 | "Job Overview" heading covering single sentence | housekeeper | **PARTIALLY FIXED** -- section still single-sentence, but reclassified to non_criteria (debatable improvement) |
| N7 | "Who we are" split creating headingless culture section | levellr | **STILL PRESENT** -- same structure, but now correctly typed |

**Summary:** 5 FIXED, 1 PARTIALLY FIXED, 1 STILL PRESENT.

---

## Persistent Defects from v1

| # | Defect | JD | Status across versions |
|---|---|---|---|
| D4 | H1 "Welcome to Glide!" not extracted as heading | glide | v1: PRESENT, v2: PRESENT, **v3: FIXED** |
| D10 | "Pay & Schedule" non_criteria despite Sunday requirement | housekeeper | v1: PRESENT, v2: PRESENT (by design), **v3: PRESENT (by design)** |

---

## New Defects in v3

| # | Defect | JD | Severity |
|---|---|---|---|
| R1 | "Job Detail" heading dropped AND section reclassified from criteria to non_criteria | video-production | **HIGH** -- reverts v2's most impactful fix, loses richest criteria prose |
| R2 | "Job Overview" reclassified from criteria to non_criteria | housekeeper | **LOW** -- borderline content, defensible reclassification |
| R3 | "Job Detail" heading text dropped entirely (not in heading field or content) | video-production | **MEDIUM** -- violates never-drop-content rule |

Note: R1 and R3 are related (same section, same JD) but distinct issues -- R1 is about criteria classification, R3 is about heading text preservation. R3 could be classified as part of R1 but is listed separately because it's a different rule violation.

---

## Prompt Changes for v4

### Must fix

1. **Reinforce "role description prose is criteria" with an explicit example.** The v2 prompt had this rule and it worked for video-production. v3 somehow regressed. Add an explicit example: "If a section describes the role's required disciplines, skills, or responsibilities in prose form (e.g., 'As a writer/producer, cinematographer, editor... he/she will be responsible for...'), classify it as `criteria` even if it reads like a job summary. Role description prose that names specific skills the candidate must have IS criteria." This directly targets R1.

2. **Add a `<strong>` heading consistency rule.** The video-production JD shows inconsistent treatment of `<strong>` headings within the same document -- "About Our Company", "Responsibilities", etc. are extracted, but "Job Detail" is dropped. Add: "When a `<p><strong>text</strong></p>` pattern appears multiple times in the same document, treat ALL instances consistently. If any are extracted as headings, all must be." This targets R3.

3. **Strengthen the minimum section size rule to encourage merging, not reclassification.** The current rule says "ensure resulting sections each have meaningful content (at least 2-3 sentences)." The model's response was to keep the single-sentence section but reclassify it. Amend to: "If a split would create a section with fewer than 2-3 sentences, merge the content into the adjacent section instead of creating a standalone section. Do not keep a sub-minimum section and reclassify it -- merge it." This targets the housekeeper "Job Overview" issue (R2/N6).

### Should fix

4. **Suppress list-item dash prefixes in output.** The housekeeper "What We're Looking For" section uses `\n- ` formatting (dash-prefixed items). Other JDs use bare `\n`. Add: "When converting HTML `<li>` items to plain text, use one item per line separated by newlines. Do not add dash or bullet prefixes." Minor consistency improvement.

### Probably not worth pursuing

5. **"Pay & Schedule" mixed-content handling (D10).** This has been present since v1 and classified "by design" in every evaluation. The "Sunday availability is mandatory" requirement remains buried in a `non_criteria` section. Possible approaches (a `has_criteria_items` flag, splitting the section) all add complexity for one edge case. Leave as-is unless scoring accuracy on this specific JD becomes a measurable problem.

6. **Headingless culture section in Levellr (N7).** Still present but harmless. The section is correctly typed as `culture`, the content is correctly separated from the company narrative, and the split is defensible. No downstream scoring impact.

---

## Diminishing Returns Assessment

v3 is approaching the point of diminishing returns for prompt-level fixes.

**What's working well:** HTML entity decoding, newline formatting, enum compliance, heading extraction for h1-h6 elements, content preservation for heading text, and list formatting are all either fully solved or close to it. These were systematic issues with clear prompt-level solutions, and the solutions worked.

**What's proving difficult:** Criteria classification consistency is the remaining problem area, and it's fundamentally harder to fix with prompt instructions. The video-production "Job Detail" regression (R1) is the most concerning: the model correctly classified it in v2 but regressed in v3, suggesting the new rules (possibly the minimum section size or heading extraction rules) are interfering with the existing criteria classification rule. This is a classic "whack-a-mole" pattern where fixing one behavior destabilizes another.

**Specific diminishing-returns indicators:**
- v1 to v2 fixed 11 of 16 defects and introduced 7 new ones. Net improvement: large.
- v2 to v3 fixed 5 of 7 defects and introduced 2 new regressions (one HIGH). Net improvement: moderate but mixed.
- The remaining defects are increasingly judgment calls (is "No resume required" criteria?) rather than clear rule violations.
- The video-production regression shows that adding more rules can destabilize existing correct behavior.

**Recommendation:** Implement the v4 "must fix" items (changes 1-3 above) to address the video-production regression, then pause prompt iteration and run the full benchmark suite again. If the video-production regression persists despite explicit reinforcement, consider alternative approaches:
- Few-shot examples showing the specific "Job Detail" pattern classified as criteria.
- A two-pass approach: first pass classifies sections, second pass reviews criteria classifications specifically.
- Model upgrade (if gpt-4o-mini is hitting its ceiling on this nuance).

The formatting and structural issues are solved. The remaining quality gap is in semantic judgment -- which is harder to fix with rules alone.
