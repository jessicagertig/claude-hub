# Plato usage check — handoff

Console methods for checking Plato (AI candidate summary/scoring) usage in inflow-ats. Paste into `rails console`, then call.

## Data model facts (load-bearing)

- **Each attempt = one `AiJobApplicationSummary` row.** Built at generation start with `status: pending`. Success or failure, a row exists.
- **A failed attempt = that row with `status: failed`.** Set by the job rescue (`generate_ai_job_application_summary_job.rb`) or the scoring/criteria failure paths. `error_message` holds the cause.
- **Failures are NOT readable off the status table.** `AiJobApplicationSummaryStatus` has no `failed` state (only `none / initial_summary_pending / current / regenerating`). On a failed first attempt it goes `initial_summary_pending → none` (looks like never-attempted); on a failed regeneration it stays `current`. Read failures from `AiJobApplicationSummary.status` only.
- **Regenerations build a NEW `AiJobApplicationSummary` row** each time. So summary rows > distinct job applications attempted.
- **API requests split by `AiApiRequest.requestable_type`:** `'AiJobApplicationSummary'` = summary pipeline (user-triggered); `'AiJobCriteria'` = job-criteria extraction (auto-triggered on job publish, NOT user usage — excluded from these reports).
- Org path: summary → `job_application` → `job` → `organization`.

## Function 1 — usage by organization

Per org: succeeded / failed / pending counts. `pending` = the literal `pending` status only (not all in-flight).

```ruby
def ai_summary_usage_by_organization
  base = AiJobApplicationSummary.joins(job_application: :job)
  succeeded_by_organization_id = base.where(status: :succeeded).group('jobs.organization_id').count
  failed_by_organization_id    = base.where(status: :failed).group('jobs.organization_id').count
  pending_by_organization_id   = base.where(status: :pending).group('jobs.organization_id').count

  organization_ids = (succeeded_by_organization_id.keys + failed_by_organization_id.keys + pending_by_organization_id.keys).uniq
  organization_names = Organization.where(id: organization_ids).pluck(:id, :name).to_h

  ap organization_ids
    .map { |organization_id|
      {
        organization_id: organization_id,
        organization: organization_names[organization_id],
        succeeded: succeeded_by_organization_id[organization_id].to_i,
        failed: failed_by_organization_id[organization_id].to_i,
        pending: pending_by_organization_id[organization_id].to_i
      }
    }
    .sort_by { |row| -(row[:succeeded] + row[:failed] + row[:pending]) }

  ap "Done", color: { string: :green }
end
```

Run: `ai_summary_usage_by_organization`

## Function 2 — failures for one organization

Detail per failed summary: job, requesting user, `error_message`, timestamps. Takes an org id.

```ruby
def ai_summary_failures_for_organization(organization_id)
  organization = Organization.find(organization_id)
  ap "===== AI SUMMARY FAILURES: #{organization.name} (##{organization.id}) =====", color: { string: :white }

  failed_ai_job_application_summaries = AiJobApplicationSummary
    .where(status: :failed)
    .joins(job_application: :job)
    .where(jobs: { organization_id: organization.id })
    .includes(job_application: :job)
    .order(:created_at)

  ap failed_ai_job_application_summaries.map { |ai_job_application_summary|
    {
      id: ai_job_application_summary.id,
      job_application_id: ai_job_application_summary.job_application_id,
      job_id: ai_job_application_summary.job_application.job_id,
      job: ai_job_application_summary.job_application.job.title,
      requested_by_organization_user_id: ai_job_application_summary.requested_by_organization_user_id,
      error_message: ai_job_application_summary.error_message,
      created_at: ai_job_application_summary.created_at,
      updated_at: ai_job_application_summary.updated_at
    }
  }

  ap "Done", color: { string: :green }
end
```

Run: `ai_summary_failures_for_organization(8750)` (8750 = AirVu Media, 3 failed summaries)

Group-by-error variant (`.group(:error_message)` on the base relation throws `PG::GroupingError` because `.order(:created_at)` leaks into `GROUP BY`; strip the order with `.reorder(nil)` first): `failed_ai_job_application_summaries.reorder(nil).group(:error_message).count`

## Open items

- **Move both functions to internal methods** — requested location `AiJobApplicationSummary` model (or better home TBD). Not yet done.
- Add the error_message grouping back into function 2 cleanly (`.reorder(nil)`).

## Related files (scratchpad)

- `~/claude-hub/inflow-ats/ai-usage-report-2026-07-20/ai_feature_usage_report.rb` — fuller report (totals, attempt rollup, by-org, by-job, API tokens/cost). Superseded by function 1 for day-to-day use.
- `~/claude-hub/inflow-ats/ai-usage-report-2026-07-20/ai_summary_failures_for_organization.rb`
