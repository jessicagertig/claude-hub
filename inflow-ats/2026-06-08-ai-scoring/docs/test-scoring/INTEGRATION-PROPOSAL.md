# Scoring + AI Summary Integration Proposal

## Current State

### AI Summary Pipeline (4 calls, all gpt-4o-mini)
1. **Extraction**: Resume text → structured data (name, work experiences, education, skills)
2. **Assessment**: Role-blind → primary/secondary domains, career narrative, key skills, standout accomplishments
3. **Comparison**: Role-aware → applicable_experience, gaps, overlap_summary (uses job title + assessment data)
4. **Summary**: → headline, summary, role_analysis (uses assessment + comparison data)

Final `structured_data` stored on `AiJobApplicationSummary` contains everything from all 4 calls.

### Scoring Pipeline (4-5 calls, mixed models)
1. **Call 1** (gpt-4.1-mini): JD HTML → sections
2. **Call 2** (gemini-flash-lite): Sections → criteria with tiers
3. **Code**: Heading tier override
4. **Judge** (gpt-4o-mini): Which criteria to decompose
5. **Decomposer** (gpt-4.1-mini): Decompose flagged criteria
6. **Call 4** (gpt-4o-mini): Criteria + resume → scores (full_match/partial_match/not_found)

Scoring currently runs via rake tasks. Results saved to JSON files. Not integrated into the app.

### UI Display Plan
- **Fit for this role** (= role_analysis from summary)
- **Notable achievements** (= standout_accomplishments from assessment)
- **Relevant experience** (= applicable_experience from comparison)
- **Gaps to probe** (= gaps from comparison)
- **Criteria match display** (= NEW from scoring — checkmarks/neutral/X)

## Integration Design

### Where scoring fits

Scoring is a separate pipeline that runs per JD, not per candidate. The JD criteria extraction (Calls 1-3) happens once per job. Candidate scoring (Call 4) happens once per candidate per job.

Current summary pipeline is per-candidate-per-job (triggered when a candidate applies or when a user requests it). Scoring is per-candidate-per-job too, but the criteria extraction part is per-job.

### Proposed flow

1. **Job-level**: When a job is created/updated, run the criteria extraction pipeline (Calls 1-3). Store the extracted criteria on the Job (new column or associated model).

2. **Candidate-level**: When AI summary is generated, ALSO run scoring (Call 4) against the job's stored criteria. Store scoring results alongside the summary.

3. **Alternative**: Run scoring as a separate step after summary generation. The summary's `structured_data` already has `key_skills` and work experience — Call 4 could use the resume text directly (as it does now) or use the already-extracted structured data.

### Data model options

**Option A: Add scoring to AiJobApplicationSummary**
- Add `scoring_data` jsonb column to `ai_job_application_summaries`
- Contains: criteria list, scores per criterion, computed percentage
- Pro: One record per candidate per job, everything in one place
- Con: Summary and scoring have different lifecycles (summary is per-candidate, criteria are per-job)

**Option B: Separate model for job criteria + scoring**
- New `AiJobCriteria` model on Job (stores extracted criteria)
- New `AiJobApplicationScore` model on JobApplication (stores per-candidate scores)
- Pro: Clean separation, criteria extracted once per job, scoring references the criteria
- Con: More models, more joins

**Option B is better** because:
- Criteria extraction is expensive and should happen once per job
- Multiple candidates scored against the same criteria
- If criteria change (JD updated), old scores can be invalidated
- Scoring can be triggered independently of summary generation

### New models

```ruby
# Stores extracted criteria for a job (output of Calls 1-3)
class AiJobCriteria < ApplicationRecord
  belongs_to :job
  # columns: criteria_data (jsonb), title_technology (string), status (enum), version (integer)
end

# Stores scoring results per candidate
class AiJobApplicationScore < ApplicationRecord
  belongs_to :job_application
  belongs_to :ai_job_criteria
  # columns: scoring_data (jsonb), percentage (decimal), status (enum)
end
```

### What scoring_data contains (per candidate)

```json
{
  "scores": [
    {
      "criterion_text": "Strong programming experience in Go",
      "tier": "tier_1",
      "score": "full_match",
      "reasoning": "Candidate has 4 years of Go production experience at two companies",
      "user_facing_text": "Go programming experience",
      "user_facing_evidence": "4 years of production Go at Acme Corp and Widget Inc"
    }
  ],
  "computed_score": {
    "percentage": 64.6,
    "points": 103.0,
    "max_points": 160.0
  }
}
```

### User-facing criteria display

The `user_facing_text` and `user_facing_evidence` fields need to be generated. Options:

1. **Add to Call 4 (scoring prompt)**: Ask the scorer to also return user-friendly text. Risk: increases output complexity, might degrade scoring quality.

2. **Separate Call 5**: Takes scoring results + criteria + resume, generates user-facing summaries. Pro: scoring quality preserved, display text is purpose-built. Con: additional API call per candidate.

3. **Generate at display time**: Frontend or a view helper transforms the raw scoring data into display text. Pro: no API call. Con: raw criterion text may not be user-friendly.

**Recommendation: Option 2** (separate call). The scoring prompt is tuned for accuracy. Adding display text generation would change the prompt dynamics. A separate call can be optimized purely for recruiter-friendly language.

### Integration with existing summary fields

The summary already has `applicable_experience` and `gaps`. Scoring provides EVIDENCE for these:
- `applicable_experience` says "strong Go and K8s background" → scoring shows checkmarks on Go and K8s criteria
- `gaps` says "no CI/CD experience" → scoring shows X on CI/CD criterion

The scoring display sits under or alongside the narrative summary fields, providing structured proof.

### Triggering

- Criteria extraction triggers when: job is created with a description, or description is updated
- Scoring triggers when: AI summary is generated (add scoring as a final step), or manually by user
- Re-scoring triggers when: criteria are re-extracted (JD updated)

### What needs to happen

1. Create `AiJobCriteria` model + migration
2. Create `AiJobApplicationScore` model + migration
3. Move criteria extraction pipeline into a service (currently rake tasks)
4. Wire scoring into the summary generation flow (or as a separate job)
5. Add Call 5 for user-facing text generation
6. Frontend: display criteria matches alongside summary fields
7. Serializer changes to expose scoring data to the frontend
