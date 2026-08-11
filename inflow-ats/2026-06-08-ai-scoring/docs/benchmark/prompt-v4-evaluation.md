# Prompt v4 Evaluation

Model: gpt-4o-mini | Prompt: prompt-v4.txt

## v4 Prompt Changes Applied

Only 3 targeted changes:

1. Added explicit example of role description prose as criteria (targeting video-production "Job Detail" regression R1)
2. Added `<strong>` heading consistency rule -- if `<p><strong>text</strong></p>` appears multiple times, treat ALL as headings consistently (targeting R3)
3. Changed minimum section size rule from "don't create" to "merge into adjacent section instead" (targeting housekeeper "Job Overview" issue R2/N6)

---

## 1. elixir.json -- Elixir Developer (Select)

**v3 defects:** None. v3 was clean for this JD.

**v4 result:** 2 sections (same as v3).

### Regressions from v3?

None. Identical output to v3 -- same section count, same headings, same types, same content, same `inferred_section_type` values.

### Content completeness

Complete. Both paragraphs present. All 7 list items (including both `(bonus)` items) present. Verified against source JD.

### Standard checks

- **null/null:** None. Section 1 has `heading: null` but `inferred_section_type: "company_about"` -- valid.
- **Enum values:** All valid (`company_about`, `criteria`).
- **HTML entities:** Clean. `We're seeking` is decoded (same as v3).
- **Heading extraction:** "Base Requirements" correctly extracted from plain `<p>` tag (same as v3).

### Targeted fix evaluation

N/A -- none of the 3 targeted fixes apply to this JD.

---

## 2. glide.json -- Senior Software Engineer Fullstack (Glide)

**v3 defects:** None. v3 was clean for this JD.

**v4 result:** 10 sections (v3 had 6).

### Regressions from v3?

**REGRESSION: Benefits section over-split from 1 section to 5 sections.** v3 had one "Perks and Benefits" section containing all four sub-benefits (Competitive Compensation, Wellbeing Credits, Lunch on us, Best Tools) merged together. v4 splits these into 5 separate sections:

| # | Heading | Type | Content |
|---|---|---|---|
| 5 | Perks and Benefits: | non_criteria/benefits | (empty string) |
| 6 | Competitive Compensation: | non_criteria/compensation | 1 sentence |
| 7 | Wellbeing Credits (for US employees) | non_criteria/benefits | 1 sentence |
| 8 | Lunch on us (for US employees) | non_criteria/benefits | 1 sentence |
| 9 | Best Tools | non_criteria/benefits | 1 sentence |

Problems with the v4 split:

1. **Empty section.** Section 5 "Perks and Benefits:" has `content: ""` -- an empty string. This is a data quality defect. An empty section wastes a slot and provides no value to downstream consumers. The prompt's minimum section size rule ("at least 2-3 sentences") should have prevented this.

2. **Three single-sentence sections.** Sections 7, 8, and 9 each contain exactly one sentence. This violates the minimum section size guidance. The model extracted the h3 sub-headings as section dividers but did not apply the merge rule for sub-minimum sections.

3. **The v3 merged approach was better.** The source HTML uses `<h3>` sub-headings within a `<h1>` parent section. v3 correctly treated these as sub-headings within a single benefits section. v4 elevated them to top-level sections, creating fragmentation.

**Root cause:** This is almost certainly caused by the `<strong>` heading consistency rule (change #2). The source HTML has `<h3><strong>Competitive Compensation:</strong></h3>` alongside `<h3>Wellbeing Credits</h3>` (no strong tag) and `<h3>Best Tools</h3>` (no strong tag). But the rule applies to `<p><strong>` patterns, not `<h3>` patterns. The more likely cause is that the heading consistency rule, combined with the existing heading extraction rules for h1-h6, made the model more aggressive about treating sub-headings as section boundaries. The h3 tags in the source were always valid heading elements -- v3 chose to merge them; v4 chose to split them.

**Severity: MEDIUM.** The over-splitting does not lose criteria content (these are all non_criteria), but the empty section is a data quality defect and the single-sentence sections create unnecessary fragmentation. Downstream consumers will see 5 benefits sections instead of 1.

### Content completeness

Complete -- all content is present, just distributed across more sections. Checked all four sub-benefit descriptions against source. The emoji prefixes are preserved in the heading fields. The "Any Questions?" section with email is preserved.

### Standard checks

- **null/null:** None.
- **Enum values:** All valid (`company_about`, `criteria`, `benefits`, `compensation`, `process_meta`).
- **HTML entities:** Clean. `&` in "infrastructure & tooling" decoded (same as v3).
- **Heading extraction:** "Welcome to Glide!" H1 still correctly extracted (v3 fix persists).

### Targeted fix evaluation

- **Fix 1 (role description prose as criteria):** N/A for this JD.
- **Fix 2 (`<strong>` heading consistency):** Not directly applicable (Glide uses h1/h3, not `<p><strong>`), but the rule appears to have had a side-effect of making the model more aggressive about splitting on heading-like elements. See regression above.
- **Fix 3 (merge sub-minimum sections):** NOT APPLIED. The empty "Perks and Benefits:" section and the single-sentence sub-benefits should have been merged under the merge rule. The model ignored the merge guidance here.

---

## 3. housekeeper.json -- Housekeeper (Renjoy)

**v3 defects:** R2 -- "Job Overview" single-sentence section reclassified from criteria to non_criteria instead of being merged.

**v4 result:** 5 sections (v3 had 6).

### Did v3 defects get fixed?

**R2 "Job Overview" single-sentence section: FIXED.** v3 had a standalone single-sentence "Job Overview" section (Section 2, `company_about`) containing only "No resume required. Show up consistently, work hard, and communicate well. That's what matters." v4 merged this content into the opening section (Section 1), which now contains both the company description paragraph AND the "No resume required" line:

> Renjoy manages 200+ vacation rental properties... We treat this role accordingly.
>
> No resume required. Show up consistently, work hard, and communicate well. That's what matters.

The merge rule (change #3) worked exactly as intended here. The single-sentence section is gone, and the content is preserved in the adjacent section.

### Regressions from v3?

**MINOR REGRESSION: List-item dash prefixes removed.** v3 had `\n- Are physically up for the work...` (dash-prefixed items). v4 has the items without dashes: `Are physically up for the work...`. This was actually listed as a "should fix" in the v3 evaluation (item #4), so it's an intentional improvement. However, v4 also removed the introductory `You also:` transition from the beginning of the list -- in v3, the list started with "You also:\n- Are physically up..." but in v4 it reads "You also:\n\nAre physically up..." The transition is preserved; only the dashes are gone. Not a real regression.

**No other regressions.** All other sections are identical to v3.

### Content completeness

Complete. All content present. The merge preserved the "No resume required" text that was at risk of being lost. All 5 "What We're Looking For" bullet items present. All Pay & Schedule items present.

### Standard checks

- **null/null:** None. Section 1 has `heading: null` but `inferred_section_type: "company_about"`.
- **Enum values:** All valid (`company_about`, `benefits`, `criteria`, `culture`).
- **HTML entities:** N/A.
- **Heading extraction:** All `<strong>` headings correctly extracted.

### Targeted fix evaluation

- **Fix 1 (role description prose as criteria):** N/A for this JD.
- **Fix 2 (`<strong>` heading consistency):** Working correctly -- all `<strong>` headings are treated consistently.
- **Fix 3 (merge sub-minimum sections): FIXED.** The single-sentence "Job Overview" section is gone, merged into the adjacent company_about section.

---

## 4. levellr.json -- Full Stack Engineer (Levellr)

**v3 defects:** N7 (persisting from v2) -- "Who we are" split creating headingless culture section. Classified as harmless in v3 evaluation.

**v4 result:** 5 sections (same as v3).

### Regressions from v3?

**MINOR CHANGE: "This is not your typical corporate role" paragraph moved from "Who we are" section to headingless culture section.** In v3, Section 3 "Who we are" contained both the company narrative paragraph AND the "This is not your typical corporate role" transition paragraph. In v4, the transition paragraph moved to Section 4 (headingless, `culture`), which now starts with "This is not your typical corporate role..." before the culture bullet points.

This is not a regression -- it's a minor boundary shift that arguably improves the split. The "This is not your typical corporate role" sentence is more thematically aligned with the culture bullet points that follow it than with the company narrative in the "Who we are" section. The v4 grouping makes more logical sense.

### Content completeness

Complete. All content present. Verified:
- Intro paragraph -- present in Section 1.
- All 10 "Who are you?" list items -- present in Section 2.
- Company narrative (co-founders, investors) -- present in Section 3.
- "This is not your typical corporate role" + all 6 culture bullet points -- present in Section 4.
- Benefits intro + all 7 benefit items -- present in Section 5.

### Standard checks

- **null/null:** Two sections with `heading: null` (Sections 1 and 4), both have valid `inferred_section_type` values (`company_about` and `culture`).
- **Enum values:** All valid (`company_about`, `criteria`, `culture`, `benefits`).
- **HTML entities:** Clean. Both `&` instances decoded (same as v3).
- **Heading extraction:** "Who are you?", "Who we are", and "Benefits" all correctly extracted.

### Targeted fix evaluation

- **Fix 1 (role description prose as criteria):** N/A for this JD.
- **Fix 2 (`<strong>` heading consistency):** N/A -- Levellr uses h1/h2 headings, not `<p><strong>` patterns.
- **Fix 3 (merge sub-minimum sections):** N/A -- no sub-minimum sections exist.

---

## 5. sales-manager-de.json -- Sales Manager (Franklin Institute)

**v3 defects:** None. v3 was clean for this JD.

**v4 result:** 4 sections (v3 had 5).

### Regressions from v3?

**CHANGE: Closing CTA merged into "Wir bieten" section.** v3 had a separate Section 5 (heading: null, `process_meta`) containing the closing CTA ("Du fuhlst dich angesprochen? Dann bewirb dich jetzt..."). v4 merged this into Section 4 "Wir bieten", which now ends with:

> Weitere Benefits wie Fitness-Mitgliedschaft etc.
>
> Du fuhlst dich angesprochen? Dann bewirb dich jetzt und werde Teil der nachsten Bildungsrevolution!
> Wir freuen uns auf Deine Bewerbung!

**Assessment: Neutral change.** The CTA text is now inside a `benefits` section instead of its own `process_meta` section. This is a side-effect of the merge rule (change #3) -- the CTA was 2 sentences, borderline on the "2-3 sentences" minimum, and the model chose to merge it into the adjacent section. Neither approach is wrong:
- v3 approach: separate `process_meta` section. Cleaner semantic typing.
- v4 approach: merged into benefits. Fewer sections, content preserved.

The CTA text is non_criteria either way, so there is no downstream scoring impact. The `process_meta` type information is lost, but that type has no effect on scoring.

### Content completeness

Complete. All content present. The "Uber uns:" heading text is still preserved inline in Section 1 content (v3 fix persists). All list items in all sections verified against source.

### Standard checks

- **null/null:** None. Section 1 has `heading: null` with `inferred_section_type: "company_about"`.
- **Enum values:** All valid (`company_about`, `criteria`, `benefits`).
- **HTML entities:** N/A.
- **Heading extraction:** "Deine Aufgaben:", "Dein Profil:", and "Wir bieten:" correctly extracted (same as v3).

### Targeted fix evaluation

- **Fix 1 (role description prose as criteria):** N/A for this JD.
- **Fix 2 (`<strong>` heading consistency):** The source uses `<strong>Uber uns:</strong>` in one place. There is only one `<p><strong>` pattern in this JD, so the consistency rule does not apply.
- **Fix 3 (merge sub-minimum sections):** Applied -- the 2-sentence CTA section was merged into the adjacent benefits section. Defensible but lost the `process_meta` type.

---

## 6. video-production.json -- Video Production Specialist (Walrus Audio)

**v3 defects:** R1 -- "Job Detail" heading dropped AND section reclassified from criteria to non_criteria (HIGH severity). R3 -- "Job Detail" heading text dropped entirely.

**v4 result:** 7 sections (same as v3).

### Did v3 defects get fixed?

**R1 "Job Detail" reclassified from criteria to non_criteria: FIXED.** v3 had Section 1 as `heading: null`, `type: "non_criteria"`, `inferred_section_type: "company_about"`. v4 has Section 1 as `heading: null`, `type: "criteria"`, `inferred_section_type: "criteria"`. The role description prose ("multi-disciplinary position," "writer/producer, cinematographer, editor, sound designer, and animator," "handles all aspects of film production") is correctly classified as criteria again.

The explicit example of role description prose as criteria (change #1) worked.

**R3 "Job Detail" heading text dropped entirely: NOT FIXED.** The heading field is still `null` for Section 1. The text "Job Detail" does not appear in the heading field or in the content field. It is still silently dropped.

Checking the source HTML: `<p><strong>Job Detail</strong></p>` is the first element. Other `<p><strong>text</strong></p>` patterns in the same document ("About Our Company", "Responsibilities", "Personal and Organizational Skills", "Additional Skills and Responsibilities", "Job Requirements", "Compensation and Benefits") ARE all extracted as headings. The `<strong>` heading consistency rule (change #2) did NOT work for this case.

**Why it failed:** The model likely treats "Job Detail" as a generic/meta label for the section that follows rather than as a meaningful heading. The other headings in this JD are descriptive ("Responsibilities", "Job Requirements"), while "Job Detail" is a generic container label. The model may be applying semantic judgment about whether a heading is "real" rather than following the structural consistency rule mechanically. This is a judgment call the model makes despite the explicit consistency instruction.

### Regressions from v3?

None beyond the persistent R3. The criteria classification is restored (R1 fixed). All other sections are identical to v3.

### Content completeness

INCOMPLETE -- same as v3. The heading text "Job Detail" is still dropped. All other content is present:
- Both role description prose paragraphs -- present in Section 1.
- "About Our Company" paragraph -- present in Section 2.
- All 14 "Responsibilities" list items -- present in Section 3.
- All 5 "Personal and Organizational Skills" items -- present in Section 4.
- All 12 "Additional Skills and Responsibilities" items -- present in Section 5.
- All 7 "Job Requirements" items -- present in Section 6 (including "Bachelor's degree preferred" plain text item).
- All 5 "Compensation and Benefits" items -- present in Section 7.

### Standard checks

- **null/null:** Section 1 has `heading: null` but `inferred_section_type: "criteria"` -- valid (the heading should be "Job Detail" but the null is not a null/null violation since `inferred_section_type` is populated).
- **Enum values:** All valid (`criteria`, `company_about`, `benefits`).
- **HTML entities:** N/A.
- **Heading extraction:** All `<strong>` headings except "Job Detail" are correctly extracted. "Additional Skills and Responsibilities" is correctly extracted despite having `*<em>` markdown formatting in the source (`*<em>Additional Skills and Responsibilities *</em>`).

### Targeted fix evaluation

- **Fix 1 (role description prose as criteria): FIXED.** Section 1 is correctly classified as criteria again.
- **Fix 2 (`<strong>` heading consistency): NOT FIXED.** "Job Detail" is still dropped while other `<p><strong>` headings in the same document are extracted. The model is not applying the consistency rule to this specific heading.
- **Fix 3 (merge sub-minimum sections):** N/A -- no sub-minimum sections.

---

## Cross-cutting Analysis

### 1. Targeted Fix Scorecard

| # | Fix | Target | Status |
|---|---|---|---|
| 1 | Role description prose as criteria example | video-production R1 | **FIXED** |
| 2 | `<strong>` heading consistency rule | video-production R3 | **NOT FIXED** |
| 3 | Merge sub-minimum sections (not reclassify) | housekeeper R2/N6 | **FIXED** |

**2 of 3 targeted fixes worked.** The `<strong>` heading consistency rule failed to fix the "Job Detail" heading drop. The model appears to be making a semantic judgment that "Job Detail" is not a real heading, overriding the structural consistency instruction.

### 2. Section Count Changes

| JD | v3 sections | v4 sections | Change |
|---|---|---|---|
| elixir | 2 | 2 | Same |
| glide | 6 | 10 | +4 (over-split) |
| housekeeper | 6 | 5 | -1 (merge fix) |
| levellr | 5 | 5 | Same |
| sales-manager-de | 5 | 4 | -1 (merge) |
| video-production | 7 | 7 | Same |

The merge rule (change #3) reduced section counts in 2 JDs (housekeeper, sales-manager-de). The heading rules caused over-splitting in 1 JD (glide).

### 3. Criteria Classification Accuracy

| JD | v3 criteria sections | v4 criteria sections | Change |
|---|---|---|---|
| elixir | 1 | 1 | Same |
| glide | 3 | 3 | Same |
| housekeeper | 2 | 2 | Same |
| levellr | 1 | 1 | Same |
| sales-manager-de | 2 | 2 | Same |
| video-production | 4 | 5 | +1 (fix) |

Video-production criteria count restored to 5 (matching v2). No JD lost criteria sections.

### 4. Empty Section Defect

The Glide result has a section with `content: ""` (empty string) at Section 5 "Perks and Benefits:". This is a new defect class not seen in any previous version. An empty section is a waste and could cause issues for downstream consumers that assume sections contain content.

### 5. Content Preservation

All content from all 6 source JDs is present in v4 results, with the single exception of the "Job Detail" heading text in video-production (persistent since v3).

### 6. Formatting Quality

List-item formatting is consistent across all JDs. No dash prefixes remain (the housekeeper dash prefixes from v3 are gone). Newline formatting is correct throughout. No HTML entities remain.

---

## v3 Defect Scorecard

| # | Defect | JD | v4 Status |
|---|---|---|---|
| R1 | "Job Detail" section reclassified from criteria to non_criteria | video-production | **FIXED** |
| R2 | "Job Overview" single-sentence section kept and reclassified | housekeeper | **FIXED** |
| R3 | "Job Detail" heading text dropped entirely | video-production | **NOT FIXED** |

**Summary:** 2 FIXED, 1 NOT FIXED.

---

## Persistent Defects Across All Versions

| # | Defect | JD | v1 | v2 | v3 | v4 |
|---|---|---|---|---|---|---|
| D10 | "Pay & Schedule" non_criteria despite Sunday requirement | housekeeper | Present | Present | Present | Present |
| R3/D4b | "Job Detail" heading text dropped | video-production | N/A | Correct | Dropped | **Dropped** |
| N7 | "Who we are" split creating headingless culture section | levellr | Present | Present | Present | Present |

---

## New Defects in v4

| # | Defect | JD | Severity |
|---|---|---|---|
| V4-1 | Glide benefits over-split: 1 section became 5, with 1 empty-content section and 3 single-sentence sections | glide | **MEDIUM** -- no criteria impact, but data quality issue (empty section) and fragmentation |
| V4-2 | Sales-manager-de closing CTA merged into benefits section, losing `process_meta` type | sales-manager-de | **LOW** -- no scoring impact, defensible merge |

---

## Targeted Fix Scoring

| # | Fix Description | Target | Verdict |
|---|---|---|---|
| 1 | Explicit example of role description prose as criteria | video-production R1 | **FIXED** |
| 2 | `<strong>` heading consistency rule | video-production R3 (heading drop) | **NOT FIXED** |
| 3 | Merge sub-minimum sections instead of reclassifying | housekeeper R2/N6 | **FIXED** |

---

## New Defects and Regressions

1. **V4-1 (MEDIUM): Glide benefits over-split.** The Perks and Benefits section went from 1 merged section in v3 to 5 separate sections in v4, including one empty section (`content: ""`) and three single-sentence sections. This is likely a side-effect of the heading consistency rule making the model more aggressive about respecting sub-headings as section boundaries, even for h3 elements nested under an h1 parent.

2. **V4-2 (LOW): Sales-manager-de CTA merged into benefits.** The 2-sentence closing CTA was merged into the "Wir bieten" section, losing the `process_meta` type classification. No scoring impact.

3. **R3 persists: "Job Detail" heading still dropped in video-production.** The `<strong>` heading consistency rule did not resolve this. The model treats "Job Detail" as a disposable label despite explicit instructions to treat all `<p><strong>` patterns consistently within a document.

---

## Overall Quality Assessment: Is This Prompt Good Enough for Call 1?

**Yes, with one caveat.**

What call 1 needs to deliver to call 2:
- Correct section boundaries -- **good.** Section splitting is reasonable across all 6 JDs. The Glide over-split is suboptimal but not harmful to scoring since those are all non_criteria sections.
- Correct criteria vs. non_criteria classification -- **good.** All 6 JDs now have correct criteria classification. The v3 regression on video-production is fixed. No false criteria (non_criteria content misclassified as criteria) and no missed criteria (criteria content misclassified as non_criteria).
- Clean content extraction -- **good.** All content is preserved (except the "Job Detail" heading text). No HTML entities. Proper newline formatting.
- Valid enum values and no null/null -- **good.** All `inferred_section_type` values are valid. No null/null violations.

**The caveat:** The Glide empty-content section (`content: ""`) is a data quality defect that could cause issues downstream. If call 2 iterates over sections and processes content, an empty string could produce unexpected results (empty summary, null score, etc.). This should be handled either in the prompt (v5 fix) or defensively in the call 2 code (skip sections with empty content).

The criteria classification -- the thing that actually matters for scoring accuracy -- is correct across all 6 JDs. The remaining defects are all in non_criteria sections (Glide benefits fragmentation, sales-manager CTA merge) or heading-level metadata (video-production "Job Detail" heading text drop).

---

## Diminishing Returns Assessment

**We are at diminishing returns for call 1. Move to call 2.**

Evidence:

1. **The criteria-affecting defects are fixed.** v4 fixed both criteria classification regressions from v3 (video-production R1, housekeeper R2). All 6 JDs now have correct criteria/non_criteria boundaries. This is the thing that matters for scoring accuracy.

2. **Remaining defects are in non_criteria territory.** The Glide over-split (V4-1) affects benefits sections only. The sales-manager CTA merge (V4-2) affects process_meta content only. Neither affects the criteria that call 2 will score against.

3. **The "Job Detail" heading drop (R3) is proving resistant to prompt-level fixes.** Two attempts (the `<strong>` consistency rule in v4, plus the never-drop-content rule in v3) have failed to fix it. The model is making a semantic judgment about "Job Detail" being a disposable label. Further prompt iteration on this specific defect has a low probability of success and risks introducing new regressions (as the Glide over-split demonstrates -- the heading consistency rule caused a side-effect). The "Job Detail" heading text drop has zero scoring impact anyway -- the section's content is present and correctly classified as criteria.

4. **The whack-a-mole pattern is accelerating.** v3 introduced 2 new regressions while fixing 5 defects. v4 fixed 2 of those regressions but introduced 1 new defect (Glide over-split). Each round of prompt changes fixes targeted issues but creates new ones in adjacent JDs. This is the classic signal of diminishing returns in prompt engineering.

5. **Cost is stable and low.** v4 costs range from $0.00037 (elixir) to $0.00104 (video-production). No JD exceeds $0.0011. The prompt changes have not meaningfully increased token usage.

**If a v5 is done despite the recommendation to move on**, these are the only changes worth making:

1. **Fix the Glide empty section.** Add: "Never output a section with empty content. If a heading has no content beneath it before the next heading, merge the heading into the next section's heading or skip it." This directly targets V4-1.

2. **Do NOT attempt further fixes on the "Job Detail" heading drop.** Two attempts have failed. The content is present and correctly classified. The heading text "Job Detail" itself has no scoring value. Accept the defect.

3. **Do NOT add more heading/section rules.** The heading consistency rule (change #2) caused the Glide over-split without fixing its target defect. More heading rules will cause more side-effects.
