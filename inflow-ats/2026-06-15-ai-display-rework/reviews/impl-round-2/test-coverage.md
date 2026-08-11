# test-coverage (Round 2)

## Re-verified

1. `#broadcast_status_change` describe block: 11 test cases covering all BROADCAST_STATUSES (7), excluded statuses (2), unchanged status (1), and create (1). Thorough.
2. `pending` non-broadcast behavior is indirectly covered: `pending` is not in BROADCAST_STATUSES, and the "does not broadcast on create" test creates with status `:pending`. The "does not broadcast when status is unchanged" test also starts from a non-pending state.
3. Test fixtures use `create_credit_test_*` helpers which set up proper associations. `job_application.job` exists for the broadcast.
4. The `broadcast_status_change` rescue block means tests won't fail if ActionCable test adapter isn't configured -- but the `expect(JobChannel).to receive(:broadcast_to)` expectation stubs the method call, so ActionCable is never actually invoked. Correct test structure.
5. Existing service specs not modified but `update` now triggers callbacks. The rescue block in `broadcast_status_change` ensures no test failures from ActionCable. Guard clauses on existing callbacks ensure no unexpected side effects.

## Findings

None.
