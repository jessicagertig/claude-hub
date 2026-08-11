# backward-compatibility -- Round 3

## Assessment

### Enum value renumbering

The status enum integer values changed (e.g., `succeeded` from 2 to 7, `failed` from 3 to 9). Per spec Section 3: "Since the feature is not in production/staging, no data migration is needed -- existing dev data will be invalid but that's acceptable." Verified the feature is on a pre-release branch. Acceptable.

### All consumers of modified code

Exhaustive grep for `AiJobApplicationSummary` status references across `app/` and `spec/`:

- `Summary::Generate`: Updated (working tree). BLOCKER-1 addresses committed version.
- `TextractResult#generate_ai_summary_with_credit_flow`: `status_succeeded?` -- unchanged, still correct.
- `TextractResult#queue_ai_summary_job`: `status: :textract_processing` -- symbol name unchanged.
- `GenerateAiJobApplicationSummaryJob`: `status: :failed`, `status_succeeded?` -- symbol names unchanged.
- `BulkGenerateAiSummariesJob`: `status: %i[succeeded failed]`, `status: :succeeded` -- symbol names unchanged.
- `CreateAiSummaryGeneration`: `status: :textract_processing`, `status: :pending`, `where.not(status: :failed)` -- symbol names unchanged.
- `SubmitResumeToTextract`: `status: :textract_processing` -- symbol name unchanged.
- `GetResumeTextFromTextractJob`: `status: :textract_processing` -- symbol name unchanged.
- All spec files: use symbol names, which map correctly to new integer values.

### Removed enum values

`in_progress` (was 1) and `extracted` (was 4) are removed. No committed reference to either on `AiJobApplicationSummary` remains, except in `Summary::Generate` (BLOCKER-1).

## Findings

No NEW findings beyond BLOCKER-1.
