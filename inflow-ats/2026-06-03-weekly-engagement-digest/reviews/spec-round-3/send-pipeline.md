# Send Pipeline — Round 3

## Findings

No new issues found. Rechecked against `background_jobs.md` and `services.md` conventions:

- **Job naming:** spec says `weekly_digest_job.rb` / `WeeklyDigestJob`. The `background_jobs.md` naming convention suggests `{action}_{resource}_job.rb` with action verbs like `process_`, `send_`, etc. The analog `EngagementReport::GeneratorJob` also doesn't follow that pattern. The spec's naming is consistent with the analog. Not a new finding.
- **Job structure:** `find_by` + guard, method-level `rescue StandardError`, `ap` + `Rails.logger.error`, no re-raise — all match `background_jobs.md` rules 2 and 4.
- **Service naming:** `WeeklyDigestClassifier` does not include "Service" in the name, per `services.md` rule 1.
- **Mailer pattern:** `Emails::SendTemplateEmail.new(message_params).send` matches both mailer analogs.
- **Tag count:** spec says 1-2 tags; `SendTemplateEmail` enforces max 2 tags and auto-appends template name as 3rd. Consistent.
- **`deliver_later` vs `deliver_now`:** spec notes the job already backgrounds the work, so `deliver_now` is acceptable from inside the job. `background_jobs.md` rule 6 says `deliver_later` is already async -- calling it from a job would be double-backgrounding. The spec correctly identifies this.

## Amendments Applied

None.
