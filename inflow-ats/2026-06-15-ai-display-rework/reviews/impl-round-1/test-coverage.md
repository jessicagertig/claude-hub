# test-coverage

## Checked

1. `spec/models/ai_job_application_summary_spec.rb` -- new `#broadcast_status_change` describe block with 4 test groups:
   - Iterates over all `BROADCAST_STATUSES` and verifies `JobChannel.broadcast_to` is called with correct payload
   - Verifies `awaiting_job_criteria` and `retrying` do NOT trigger broadcast
   - Verifies no broadcast when status is unchanged (non-status attribute update)
   - Verifies no broadcast on create (callback is `before_update`)
   Coverage is thorough.

2. `pending` status is NOT explicitly tested for non-broadcast behavior. It is excluded from `BROADCAST_STATUSES` but not listed in the `%w[awaiting_job_criteria retrying]` non-broadcast test. However, `pending` is the initial status, so the summary is created with `pending` -- the create test implicitly covers that `pending` doesn't broadcast (since `before_update` doesn't fire on create). And transitioning from `pending` to `pending` would not pass `status_changed?`. So `pending` is indirectly covered.

3. Existing service specs (`orchestrate_spec.rb`, `score_job_application_spec.rb`, `integrate_analysis_spec.rb`) -- not modified but now need to handle callbacks firing. The test file sets up `create_credit_test_*` helpers which create proper job/job_application associations, so `job_application.job` exists for the broadcast. The `broadcast_status_change` rescue block prevents failures from bubbling up if ActionCable test adapter is not configured.

4. No Cypress tests reference Plato components (confirmed: zero matches in `cypress/`).

## Findings

None.
