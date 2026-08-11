# Extraction Service — Round 3

## Findings

- F1 [MED] SPEC.md line 241 vs line 201 / **Test description contradicts service error behavior.** Line 201 says: "The service raises this on API failure." Line 241 says: "API failure is handled gracefully (does not raise)." These directly contradict. The service SHOULD raise `CustomErrorStructuredExtraction` on API failure so the job's `retry_on` can catch it and retry. The test description should say the service raises `CustomErrorStructuredExtraction` on API failure, not "does not raise." / Fix: change the service unit test description from "API failure is handled gracefully (does not raise)" to "API failure raises `CustomErrorStructuredExtraction`".

## Verified — No Other Issues

- **Flattening algorithm** (lines 179-191): Complete. All 11 schema fields accounted for: 6 scalars (step 1), 3 string arrays (step 2), 2 object arrays with all sub-fields (step 3). Null handling (step 4), separator (step 5), no JSON syntax (step 6), no labels (step 7). Edge cases covered: empty arrays produce no output (correct), all-null result produces empty string (tsvector trigger handles this — sets vector to NULL).
- **AiApiRequest** (line 174): Fully specified — all required fields listed, `call_type: 'keyword_extraction'` is distinct, organization access path explicit with nil guard.
- **Custom error class** (line 201): `CustomErrorStructuredExtraction` in `app/errors/`, matches existing pattern.
- **Service method**: `extract`, takes ID, passes `job_title` — all specified.
- **Prompt/schema match**: Confirmed against `resume_structured_data.rb`.

## Amendments Needed

1. (F1) Fix test description at line 241 to match service error behavior.
