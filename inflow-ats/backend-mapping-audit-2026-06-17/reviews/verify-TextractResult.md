# Verify — TextractResult topic

**Topic:** TextractResult data model (columns, enum `textract_job_status`, associations, callbacks) + its state-transition table + submission service `SubmitResumeToTextract` and polling service `GetResumeTextFromTextract` / `GetResumeTextFromTextractJob`.

**Files checked:**
- OLD: `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/backend-flow-map-2026-06-17.md`
- NEW: `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/backend-flow-map-2026-06-22-neutral.md`

## CHECK 1 — Fact preservation

Every load-bearing fact and file:line citation OLD states for the topic is present in NEW.

- **Data model** (OLD `:449-459`): `has_many :ai_job_application_summaries` (`textract_result.rb:5`), `after_commit :queue_ai_summary_job, on: [:create, :update]` (`:7`), enum `{not_started:0, in_progress:1, succeeded:2, failed:3} _prefix:true`, columns (`textract_job_id, textract_job_status, textract_job_result jsonb, textract_job_result_text, job_application_id`), `JobApplication has_many :textract_results dependent: :destroy`, "one effective" via staling + `destroy_previous_textract_results`, the `self.ai_job_application_summaries` firing-result scope note vs `orchestrate.rb:15` JobApplication scope — all in NEW `:25-41` (scope contrast also at NEW `:174/:311/:392`).
- **SubmitResumeToTextract** 7-step service: guards `:9-10`, file selection `:15-16`, conditional stale-mark `:18-20`, build `:22-24`, relink `:25-26`, poll schedule `:27`, AWS rescue `:31-40` (writes `:33,:39`), service path `app/services/`, called by `SubmitResumeToTextractJob#perform` `:7-8`, job-wrapper rescue `:9-11` — NEW `:124-133`, `:319-328`.
- **GetResumeTextFromTextract** polling: most-recent `:11`, self-healing nil `:14-17`, succeeded `.update` `:24-29,:31` (sole callback-firing write; only site writing both status + text; `saved_change_to_textract_job_result_text?` → bridge `:116`), AWS-failed `:40-41`, still-processing else `:44`, InvalidJobId `:46-47` (no raise, re-enters self-healing) — NEW `:135-144`, `:330-339`.
- **GetResumeTextFromTextractJob**: queue `:default`, `retry_on CustomErrorTextract wait:5.min attempts:3` (~17 min window), exhaustion `cleanup_orphaned_summary` `:6-8`/def `:10-23` returns at `:16` when no waiting summary, `failed`/`in_progress` result left intact — NEW `:146-149`, `:341-345`.
- **State-transition table (textract_job_status)** (OLD `:639-643`): all 5 writers (in_progress `submit_resume_to_textract.rb:22`, succeeded `get_resume_text_from_textract.rb:31`, AWS-failed `:40`+raise `:41`, InvalidJobId `:47`, submit-rescue `:33,39`) with preconditions/reached-by/resting columns — NEW `:447-451`. The two stuck-`in_progress` cases (`.update` returns false; AWS still processing past 3 retries) and the no-TextractResult-ever case (`has_resume` false / AWS raise before `@textract_result` assigned; Flipper-OFF) — NEW `:455-457`.
- **Enqueue-site enumeration** (6 app + 2 rake) — NEW `:271-280`, `:636`.

No DROPPED facts. No ALTERED file:line citations or flipped conditions. OLD's repetition (e.g. the `:10` "No resume attached" terminal restated per trigger) is de-duplicated; each underlying fact survives at least once.

## CHECK 2 — Neutrality

No banned vocabulary or defect-framing in the NEW topic text. Full-document grep for banned terms returned only `cleanup_orphaned_summary` (the explicitly allowed method name, NEW `:149/:232/:630`). OLD framing ("dead end," "stuck," "STUCK regenerating," "No advancing actor," "MAP-WRONG," ALL-CAPS "TEXTRACT IS NOT TRIGGERED," "Old map Gap N") is absent from NEW; mechanisms are stated factually ("stays `in_progress`, no text, bridge does not fire"; "is left intact"; resting/non-resting → advancing-actor table column).

## Verdict: CLEAN
