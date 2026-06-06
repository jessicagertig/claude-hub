# cascade-and-cleanup — Round 1

## Findings

- F1 [INFO] `TextractResult has_many :ai_job_application_summaries, dependent: :destroy` (textract_result.rb:5). When a TextractResult is destroyed, all summaries with that `textract_result_id` are cascade-destroyed. A `textract_processing` summary with nil `textract_result_id` is NOT associated with any TextractResult and survives the cascade. This is correct behavior — the nil-FK summary belongs to the job_application, not the TextractResult. Change 1 updates the FK to link it to the new TextractResult once created.

- F2 [INFO] `SubmitResumeToTextract` lines 18-20: when a `textract_processing` summary already exists (non-stale), the service skips the `update_all(stale: true)` call. This prevents a re-submission from marking the waiting summary as stale. Correct behavior — the waiting summary should survive and get updated by Change 1.

- F3 [MED] If `SubmitResumeToTextract` runs for a resume re-upload (Trigger 2) while a `textract_processing` summary with nil `textract_result_id` exists from a prior failed attempt, Change 1 would update it with the new TextractResult. However, this summary was from a DIFFERENT user action. The user may have expected a new summary, not the old one being repurposed. This is a pre-existing design ambiguity outside the 3 spec changes — MED per scope rules.

## Amendments Applied

None.
