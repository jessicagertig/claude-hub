# Outstanding Items — AI Scoring Integration

Items identified during prompt iteration and testing that need to be addressed in future sessions.

## 1. Temperature Zero — Global Override

`app/services/ai_providers/openai.rb` applies `temperature: 0` to all OpenAI chat requests. This affects existing summary calls (Calls 1-4) which do analysis and creative writing work. Temperature should be an optional parameter that can be passed per call, not a global setting. Some calls benefit from `temperature: 0` (structured data extraction), others do not (role analysis, summaries).

## 2. Skills Extraction Gap

`ResumeStructuredData` (summary Call 1) only extracts `key_skills` if the resume has a dedicated "Skills" section. Candidates without a skills section get an empty `key_skills` array even though skills are evident throughout work experience descriptions. This affects the frontend display — candidates without a skills section appear to have no skills. The scoring pipeline is unaffected (it scores against criteria directly from resume text, not from `key_skills`).

## 3. Textract Stuck Record Handling

No timeout handling for `TextractResult` records stuck at `in_progress` beyond a reasonable time threshold. A record at `in_progress` for 3+ days sits there forever with no cleanup, no retry, no notification. The `get_resumes_from_textract` rake task polls them but AWS may return `in_progress` indefinitely for expired jobs. Needs: a mechanism to mark records as failed after X hours/days and trigger resubmission, or at minimum surface them for manual intervention.

The `.first` → `.order(created_at: :desc).first` fix in `GetResumeTextFromTextract` and the nil `textract_job_id` guard (resubmits via `SubmitResumeToTextractJob`) were applied this session but the broader timeout issue remains.

## 4. Temperature and "Extensive" Repetition in Role Analysis

The `ResumeSummary` prompt (summary Call 4) defaults to "extensive" as its go-to adjective in `role_analysis`. Since the integrated analysis receives `role_analysis` as input, it echoes the word. This causes "extensive" to appear in the framing sentence of nearly every candidate's integrated analysis regardless of fit bracket. Needs prompt iteration on `ResumeSummary` — either tell it to avoid overusing "extensive" or provide vocabulary variation guidance similar to what was done for the integrated analysis prompt.

## 5. Granular Hiring Team Permissions

Currently `hiring_team_ai_credits_control_enabled` is a single boolean. Needs to be split into three permissions:
- Per-candidate manual generation permission
- Bulk generation permission
- Auto-generate toggle for job permission

Seven touchpoints identified: model, migration, policy, controller, frontend type, settings UI, JobPolicy. Deferred as not MVP. Noted in SPEC.md scope section.
