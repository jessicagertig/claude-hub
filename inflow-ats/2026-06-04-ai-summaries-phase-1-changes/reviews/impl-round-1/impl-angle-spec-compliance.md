# Spec Compliance — Round 1

## Findings

- F1 [MED] `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:52` / Spec says subscription records created at checkout should have `subscription_status` nil. Implementation sets `subscription_status: :active`. This is a spec deviation. Not blocking because the field is a display hint and the pre-checkout state is transient.

- F2 [MED] `app/mailers/bulk_job_application_ai_summary_result_mailer.rb:12` / Spec (Note #13) says pattern is `app/mailers/job_resume_export_mailer.rb`. The analog includes `name:` in the `to:` field. The implementation omits `name:`.

All other spec requirements are correctly implemented across all ~30 changes.
