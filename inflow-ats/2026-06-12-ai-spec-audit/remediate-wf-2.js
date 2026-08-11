export const meta = {
  name: 'ai-spec-test-remediation-2',
  description: 'Rework the 7 weak/failing AI specs so each passes AND fails if its production logic were removed; DEFER honestly if not achievable',
  phases: [
    { title: 'Fix', detail: 'rework each weak/failing spec to a meaningful, passing test' },
    { title: 'Run Specs', detail: 'run each touched spec against the existing test DB' },
    { title: 'Adversarial Review', detail: 'ghost recheck + fragility audit on the working-tree diff' },
  ],
}

const SRC = '/Users/jessica/wrk/wrk-corp/inflow-ats'

const GROUND_RULES = `
GROUND RULES (non-negotiable):
- Production code is GROUND TRUTH. NOT TDD. Change the TEST only. NEVER edit app/, lib/, config/, db/. Specs only (spec/**).
- BAR FOR "FIXED": a test is acceptable ONLY if it PASSES and would FAIL if the production logic it claims to cover were deleted or no-opped. If you cannot reach that bar without editing app/ or adding fragile scaffolding, set outcome DEFER with a clear reason — do NOT ship a ghost.
- No \`not_to raise_error\`-only assertions. No assertions that merely echo the test's own fixture/before-block values. No over-stubbing the very boundary under test.
- DB SAFETY: never db:drop/reset/setup/schema:load/test:prepare; never set DATABASE_URL; never edit .env; never raw psql. Existing test DB only; db:migrate is the only allowed db command and only if clearly needed.
- Pattern #19: a JobApplication's after_commit eagerly creates AiJobApplicationSummaryStatus; for "record does not exist" contexts destroy it in a before block rather than asserting it's absent.
`

const TARGETS = [
  {
    specFile: 'spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb',
    brief: `FAILING (6 ex, 1 failure) + ghost. Two problems:
(a) 'concurrent insert wins the race' (~lines 47-57): non-deterministic. It over-stubs save to raise RecordNotUnique and hand-fabricates the 'existing' record, and collides with the eagerly-created status row (Pattern #19) producing TWO rows, so it asserts the wrong one. Rework so the RecordNotUnique rescue branch is exercised deterministically and meaningfully (a real duplicate-insert collision that the interactor recovers from by reading back the existing row via reload), OR set outcome DEFER if a real race cannot be triggered deterministically without editing app/.
(b) 'leaves the record unchanged and does not broadcast' (~lines 126-138): ghost — the five eq(...) assertions just echo the values written by the test's own before-block update_columns. Replace with assertions that bind the production no-op branch: that no broadcast is sent and update_columns is NOT invoked when summary is not succeeded.`,
  },
  {
    specFile: 'spec/services/submit_resume_to_textract_spec.rb',
    brief: `FAILING (6 ex, 1 failure). 'when job_application is not found' dies in SubmitResumeToTextract#initialize (line 5) because a shared before block stubs find_by_id.with(job_application.id) — passing 99999999 hits the arg constraint and raises before reaching the guard at submit_resume_to_textract.rb:9 (return 'JobApplication not found' unless @job_application). Fix the stub to allow a default (e.g. stub find_by_id with no arg constraint returning the job_application, plus allow find_by_id with 99999999 returning nil), so the test actually reaches the not-found guard. Assert the returned message AND that send_to_textract / the Textract send path is never called.`,
  },
  {
    specFile: 'spec/services/ai_job_application_action/scoring/score_job_application_spec.rb',
    brief: `GHOST (passes but meaningless). 'persists the median score across the 5 runs' (~278-286) uses 5 IDENTICAL scoring responses (all 60.0) so it cannot distinguish median selection from first/last/min/max. Give the 5 scoring runs DISTINCT scores (e.g. 20,40,60,80,100 -> median 60) and assert the persisted score equals the true median — so the test would FAIL if production picked first/last/min/max or had an off-by-one in median_index. Also the boundary before-block (~257-267) stubs ai_client.chat with a fixed 6-value positional sequence; keep it but ensure the count/order matches production's exact calls and document why, so a call-count drift fails loudly rather than mis-routing responses.`,
  },
  {
    specFile: 'spec/services/ai_job_application_action/orchestrate_spec.rb',
    brief: `FRAGILE/ghost. Two problems:
(a) 'when the summary is failed after run_summary' (~345-370) is a ghost: its fixture has blank headline so summary_complete? is false and the SECOND guard (return unless summary_complete?) short-circuits scoring regardless of the failed guard (return if status_failed?). Use a COMPLETE-but-failed fixture (headline + summary_text present so summary_complete? is true) so the ONLY thing blocking scoring is the status_failed? guard — the test then fails if that guard is removed.
(b) the three pre-summarization contexts (textract_processing / extracting / retrying, ~281-342) assert Generate IS called but do not assert scoring/integration/extract_job_criteria are NOT called. Add not_to receive(:new) on the scoring and integration collaborators and not_to receive(:extract_job_criteria) so a regression that wrongly scored these statuses would be caught.`,
  },
  {
    specFile: 'spec/jobs/generate_ai_job_application_summary_job_spec.rb',
    brief: `BOTH (ghost + fragile). Three problems:
(a) 'when textract_result is not found' (~65-73) is a ghost: deleting the guard (return unless textract_result, job line 30) still passes because the resulting NoMethodError is swallowed by the job's rescue StandardError and the net effect is identical. Bind the guard by asserting the rescue's StandardError log is NOT emitted (the guard returns cleanly BEFORE reaching the call), so deleting the guard would make that log fire and the test fail.
(b) 're-raises CustomErrorAiSummary so retry_on fires' (~230-236) calls described_class.new.perform directly, bypassing ActiveJob, so it never exercises retry_on. Either use perform_now under the :test adapter and assert the job is re-enqueued/retried, or rename the test to honestly state it asserts the exception propagates out of perform (not that retry_on fires). Prefer actually observing the retry if feasible.
(c) zero-credits contexts (~33-62) are pure negative assertions blind to a silently-removed consumption path (with 0 credits determine_bucket returns nil so the real consumption code is observationally identical to no-op). Make the declined-consumption observable if feasible, otherwise DEFER this sub-item with a clear reason.`,
  },
  {
    specFile: 'spec/jobs/bulk_generate_ai_summaries_job_spec.rb',
    brief: `FRAGILE (low priority). 'does nothing when validation fails' (~line 81): the claim_row stays :processing assertion is an unchanged-state assertion that can pass whenever the row is simply never written. The test's OTHER two assertions (not_to receive(:generate_ai_summary_with_credit_flow) and empty ai_job_application_summaries) genuinely bind the line-60 guard, so the test is weak-but-not-empty. Confirm it meaningfully binds the guard; keep the binding assertions; the unchanged-state assertion is acceptable as secondary. Only change if you can strengthen without bloat.`,
  },
  {
    specFile: 'spec/interactors/grant_ai_credits_spec.rb',
    brief: `FRAGILE. 'when the transaction fails to save' over-stubs AiCreditBalanceTransaction#save to return false without populating txn.errors, so it does not simulate a real validation failure (the prod debug line was just fixed to ap txn.errors.full_messages, so it now passes). Replace the save->false stub with a record that is GENUINELY invalid so real validation runs and populates errors (violate an actual presence/numericality/inclusion validation on AiCreditBalanceTransaction), then assert result is failure with error :record_invalid and a non-empty message. If no validation can be naturally violated to reach the save-fails branch, keep the stub but document why. Low priority.`,
  },
]

const FIX_SCHEMA = {
  type: 'object',
  required: ['specFile', 'outcome', 'summary'],
  properties: {
    specFile: { type: 'string' },
    outcome: { type: 'string', enum: ['FIXED', 'PARTIAL', 'DEFER'] },
    touchedProdCode: { type: 'boolean', description: 'MUST be false' },
    deferReason: { type: 'string', description: 'if DEFER/PARTIAL: which sub-item was deferred and why' },
    summary: { type: 'string', description: 'concretely what changed and how each fixed test now binds production (would fail if prod logic removed)' },
  },
}

const RUN_SCHEMA = {
  type: 'object',
  required: ['specFile', 'passed', 'output'],
  properties: {
    specFile: { type: 'string' },
    passed: { type: 'boolean' },
    exampleCounts: { type: 'string' },
    output: { type: 'string', description: 'tail of rspec output incl any failure messages' },
    blockedReason: { type: 'string' },
  },
}

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['specFile', 'verdict', 'findings'],
  properties: {
    specFile: { type: 'string' },
    verdict: { type: 'string', enum: ['CLEAN', 'GHOST_REINTRODUCED', 'FRAGILE', 'BOTH'] },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['kind', 'location', 'problem'],
        properties: {
          kind: { type: 'string', enum: ['ghost', 'fragility'] },
          location: { type: 'string' },
          problem: { type: 'string' },
          evidence: { type: 'string', description: 'would-this-pass-if-prod-deleted reasoning, or the brittle construct' },
        },
      },
    },
  },
}

phase('Fix')
const results = await pipeline(
  TARGETS,
  (t) =>
    agent(
      `Rework ONE RSpec file so its tests are meaningful and pass. Minimal change, spec-only.

Spec file: ${SRC}/${t.specFile}

What's wrong and the required remedy:
${t.brief}

Before editing: read the spec fully, read the production code it covers, and read ${SRC}/cursor_rules/core_critical_rules.md plus the relevant area _base.md. Follow project test conventions exactly.

${GROUND_RULES}

Edit only this spec file. Do not run it (a later stage does). Report outcome FIXED only if every targeted test now meets the bar (passes AND would fail if its prod logic were removed); PARTIAL or DEFER otherwise with deferReason. touchedProdCode MUST be false.`,
      { schema: FIX_SCHEMA, label: `fix:${t.specFile.split('/').pop()}`, phase: 'Fix' }
    ),
  (fix, t) =>
    agent(
      `Run ONE RSpec file against the EXISTING test DB and report faithfully.

Run exactly: cd ${SRC} && bundle exec rspec ${t.specFile}

DB SAFETY: if it errors due to an unmigrated test DB, STOP and report in blockedReason. Never db:reset/setup/schema:load/test:prepare, never set DATABASE_URL, never edit .env. passed=true ONLY if rspec exits 0 with 0 failures. Capture counts + tail of output incl failures. Edit nothing.`,
      { schema: RUN_SCHEMA, label: `run:${t.specFile.split('/').pop()}`, phase: 'Run Specs' }
    ).then(run => ({ ...run, fix })),
  (run, t) =>
    agent(
      `Adversarially review the reworked spec for ONE file. You are reviewing the WORKING-TREE diff (uncommitted; Known Failure Pattern #15).

Get the diff: cd ${SRC} && git diff -- ${t.specFile}
Read the full current spec and the production code it covers.
Run-stage result: passed=${run?.passed}, ${run?.exampleCounts || ''} ${run?.blockedReason ? '(BLOCKED: ' + run.blockedReason + ')' : ''}

For every changed/added test check:
1. GHOST — would the assertion still pass if the production logic it covers were deleted/no-opped? Give the would-pass-if-deleted reasoning as evidence.
2. FRAGILITY — over-stubbing the boundary under test, hardcoded magic values, order/time dependence, mystery guests, assertions that echo the test's own fixture, passes-for-the-wrong-reason.

Be skeptical; green is not automatically clean. verdict CLEAN only if genuinely ghost-free and robust. Edit nothing.`,
      { schema: REVIEW_SCHEMA, label: `review:${t.specFile.split('/').pop()}`, phase: 'Adversarial Review' }
    ).then(review => ({ specFile: t.specFile, fix: run?.fix, run: { passed: run?.passed, exampleCounts: run?.exampleCounts, blockedReason: run?.blockedReason, output: run?.output }, review }))
).then(rs => rs.filter(Boolean))

const reds = results.filter(r => !r.run?.passed)
const dirty = results.filter(r => r.review && r.review.verdict !== 'CLEAN')
const deferred = results.filter(r => r.fix && r.fix.outcome !== 'FIXED')
log(`Done: ${results.length} specs, ${reds.length} not green, ${dirty.length} review-flagged, ${deferred.length} partial/deferred`)

return {
  results,
  notGreen: reds.map(r => ({ specFile: r.specFile, blockedReason: r.run?.blockedReason, output: r.run?.output })),
  flaggedByReview: dirty.map(r => ({ specFile: r.specFile, verdict: r.review.verdict, findings: r.review.findings })),
  partialOrDeferred: deferred.map(r => ({ specFile: r.specFile, outcome: r.fix?.outcome, deferReason: r.fix?.deferReason })),
}
