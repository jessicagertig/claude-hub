# Call 2 Criteria Extraction -- Final Recommendations

## Best version: v6

Prompt file: `/Users/jessica/wrk/wrk-corp/inflow-ats/app/services/ai_job_application_action/scoring/prompts/job_description_criteria_extraction.rb`

v6 is currently checked into the prompt file. v7 confirmed that v6's remaining issues are nondeterministic model behavior, not prompt deficiencies.

## Iterations summary

7 iterations (v1-v7), 6 prompt versions (v7 reused v6's prompt for nondeterminism testing). Stopped at diminishing returns -- remaining issues are gpt-4o-mini model limitations, not prompt engineering gaps.

## What the prompt handles well

### Tier assignment
- **Heading-based tier structure**: correctly maps "Need-to-Have's:" to tier_1, "Nice-to-Have's:" to tier_2, "Responsibilities" to neutral/tier_2. Works across creative heading variants.
- **Signal word recognition**: reliably catches "excellent", "strong", "proficiency", "highly", "deep", "must", "minimum", and their non-English equivalents (German "Starke", "Mindestens").
- **Default tier_2**: unlabeled responsibilities and skills correctly default to tier_2 instead of being promoted to tier_1.
- **"Ability to" not promoted**: consistently kept at tier_2 even for physical requirements.
- **Years thresholds not treated as signals**: "3+ years experience" no longer falsely promoted to tier_1.

### Binary flagging
- Degrees ("Bachelor's degree preferred"): consistently binary: true
- Vehicle ownership: consistently binary: true
- Schedule availability ("Sundays required"): consistently binary: true
- Demo reel requirements: consistently binary: true
- Years of experience: consistently binary: false (recognized as a spectrum)

### Compound decomposition
- "5+ years... including frontend and backend" correctly decomposed when it fires
- "and/or" constructions correctly preserved as single criteria
- Different-tier compounds ("X required, Y preferred") correctly split with independent tiers

### Non-English
- German JD correctly handled -- signal words translated, tier assignment appropriate, all German text preserved in output

### Text preservation
- Non-compound criteria increasingly preserve source_text as-is (text == source_text)

### Tier reasoning quality
- Cites specific signal word from the lists
- Uses "default -- no signal word" when appropriate

## Remaining known issues

### 1. "proven" signal word -- systematic miss (0/7 runs)
"proven ability" is consistently not recognized as a tier_1 signal despite "proven" being in the signal list and having a dedicated example in the prompt. This appears to be a gpt-4o-mini blind spot -- the model may be parsing "proven ability" as a natural phrase rather than recognizing "proven" as a standalone qualifier. No prompt engineering fix has worked.

**Impact**: Low. "proven" is uncommon in JDs compared to "excellent", "strong", "proficiency". When it does appear, the criterion gets tier_2 instead of tier_1 -- a minor under-classification.

**Possible fix**: Try a higher-capability model (gpt-4o) or restructure the signal as a pattern match rather than a word list.

### 2. "Solid" signal word -- nondeterministic (4/7 runs recognized)
"Solid understanding" is recognized as tier_1 in about 60% of runs. The signal word IS in the list, and the prompt has an explicit example, but the model sometimes misses it.

**Impact**: Low. Same as "proven" -- minor under-classification when missed.

### 3. Compound decomposition -- nondeterministic
The Levellr JD's compound ("5+ years... including frontend and backend") is decomposed in about 60% of runs. When not decomposed, the compound stays as one criterion, meaning the frontend/backend sub-requirements are not separately scored.

**Impact**: Medium. Missed decompositions mean compound requirements can't be scored individually. The aggregate criterion still captures the overall requirement.

### 4. Housekeeper prose extraction variability
The housekeeper JD is written in narrative prose rather than bullet points. The AI's extraction count varies between 13-20 criteria across runs depending on how aggressively it extracts from prose paragraphs. Some runs extract sentence fragments ("You execute it.") as criteria.

**Impact**: Low. The JD is an outlier -- most JDs use bullet points. The core requirements (vehicle, schedule, physical fitness) are always extracted correctly.

### 5. "Mindestens 2 Jahre" binary: true on Sales Manager
Years of experience is explicitly listed as binary: false in the prompt, but the German "2 Jahre Vertriebserfahrung" consistently gets binary: true. The model may be treating the German minimum threshold differently.

**Impact**: Very low. One JD, one criterion. The tier (tier_1) is correct.

### 6. Levellr text preservation -- nondeterministic
"You have" prefixes are sometimes stripped (text != source_text on non-compound criteria) and sometimes preserved, varying by run. When the decomposition fires, the decomposed items correctly have different text. When it doesn't fire, the model sometimes still strips "You have".

**Impact**: Low. The data is correct either way; only the text formatting varies.

## Cost

~$0.006 per JD set (6 JDs). Per individual JD: $0.0004-$0.002 depending on size. Very cheap.

## Evaluation files

- `criteria-v1-evaluation.md` through `criteria-v6-evaluation.md` -- detailed per-version analysis
- `criteria-v1-results/` through `criteria-v7-results/` -- raw API outputs
- `criteria-v1.txt` through `criteria-v7.txt` -- prompt snapshots at each version
