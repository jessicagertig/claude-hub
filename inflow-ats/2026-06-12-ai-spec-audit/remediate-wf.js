export const meta = {
  name: 'ai-spec-test-remediation',
  description: 'Triage AI spec audit findings, fix the tests (not prod code), verify green, adversarially recheck for ghosts + fragility',
  phases: [
    { title: 'Triage', detail: 'read handoff + audit files, classify every BLOCKER/HIGH finding FIX-SPEC vs DEFER' },
    { title: 'Verify Triage', detail: 'independently re-check each classification against real spec + prod code' },
    { title: 'Fix', detail: 'one agent per spec file, minimal-change spec edits, prod code untouched' },
    { title: 'Run Specs', detail: 'run each touched spec against the existing test DB, capture green/red' },
    { title: 'Adversarial Review', detail: 'ghost recheck + fragility audit on the working-tree diff' },
  ],
}

// ---- constants ----
const AUDIT_DIR = '/Users/jessica/claude-hub/inflow-ats/2026-06-12-ai-spec-audit'
const SRC = '/Users/jessica/wrk/wrk-corp/inflow-ats'
const CATEGORY_FILES = ['interactors.md', 'jobs.md', 'models.md', 'services.md', 'other.md']

const DEFERRED = [
  'spec/interactors/apply_ai_credit_purchase_spec.rb',
  'spec/interactors/apply_ai_credit_refund_spec.rb',
  'spec/interactors/cancel_ai_credit_subscription_spec.rb',
  'spec/jobs/stripe_webhook_handler_ai_credits_spec.rb',
  'spec/services/stripe/cancel_credit_pack_subscription_spec.rb',
  'spec/models/organization_ai_credit_purchase_spec.rb',
]

const GROUND_RULES = `
GROUND RULES (non-negotiable):
- Production code is GROUND TRUTH. This is NOT TDD. Every fix changes a TEST so it correctly exercises the EXISTING production code. NEVER edit any file under app/, lib/, config/, db/ — specs only (spec/**).
- A "will FAIL" finding means the TEST drifted (assertion stale vs current code), NOT that the code is buggy. Resync the test to current production behavior.
- Ghost test = a test whose assertions pass even if the production logic it claims to cover were deleted (e.g. only \`not_to raise_error\`). Ghosts are BLOCKER.
- DB SAFETY: never run db:drop / db:reset / db:setup / db:schema:load / db:test:prepare. Never set DATABASE_URL. Never edit .env. Never run raw psql. Run specs against the EXISTING test DB only.
- The 6 DEFERRED billing specs are OUT OF SCOPE — ignore any finding on them: ${DEFERRED.join(', ')}
`

const TRIAGE_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'severity', 'specFile', 'location', 'problem', 'classification', 'rationale'],
        properties: {
          id: { type: 'string', description: 'stable id e.g. BLOCKER-1, HIGH-orchestrate-2' },
          severity: { type: 'string', enum: ['BLOCKER', 'HIGH'] },
          specFile: { type: 'string', description: 'repo-relative path e.g. spec/models/ai_job_criteria_spec.rb' },
          location: { type: 'string', description: 'file:line(s)' },
          problem: { type: 'string', description: 'what is wrong with the TEST' },
          classification: { type: 'string', enum: ['FIX-SPEC', 'DEFER'] },
          proposedFix: { type: 'string', description: 'for FIX-SPEC: the concrete test edit, naming exact assertions/identifiers. empty if DEFER' },
          deferReason: { type: 'string', description: 'for DEFER: why not easily fixable + what stays uncovered. empty if FIX-SPEC' },
          rationale: { type: 'string', description: 'why this classification' },
        },
      },
    },
  },
}

const VERIFY_SCHEMA = {
  type: 'object',
  required: ['verified'],
  properties: {
    verified: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'agreed', 'finalClassification', 'note'],
        properties: {
          id: { type: 'string' },
          agreed: { type: 'boolean', description: 'true if triage classification + proposed fix hold up against real spec + code' },
          finalClassification: { type: 'string', enum: ['FIX-SPEC', 'DEFER'] },
          correctedFix: { type: 'string', description: 'if the proposed fix was wrong/incomplete, the corrected one; else empty' },
          note: { type: 'string', description: 'what was checked and any correction reason' },
        },
      },
    },
  },
}

const FIX_SCHEMA = {
  type: 'object',
  required: ['specFile', 'applied', 'summary'],
  properties: {
    specFile: { type: 'string' },
    applied: { type: 'array', items: { type: 'string' }, description: 'finding ids fixed' },
    skipped: { type: 'array', items: { type: 'string' }, description: 'finding ids NOT fixed + why (as "id: reason")' },
    touchedProdCode: { type: 'boolean', description: 'MUST be false; true is a violation' },
    summary: { type: 'string', description: 'what changed in the spec, concretely' },
  },
}

const RUN_SCHEMA = {
  type: 'object',
  required: ['specFile', 'passed', 'output'],
  properties: {
    specFile: { type: 'string' },
    passed: { type: 'boolean' },
    exampleCounts: { type: 'string', description: 'e.g. "12 examples, 0 failures"' },
    output: { type: 'string', description: 'tail of rspec output incl any failure messages' },
    blockedReason: { type: 'string', description: 'if could not run (e.g. test DB not migrated), why; else empty' },
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

// ---- Phase 0: Triage ----
phase('Triage')
const triage = await agent(
  `You are the triage agent for an AI-backend RSpec audit remediation. Do FULL investigation discipline before classifying anything.

STEP 1 — read, in this order, completely:
- ${AUDIT_DIR}/HANDOFF.md
- ${AUDIT_DIR}/CLAUDE.md (the audit methodology — three-prong audit, ghost = BLOCKER)
- ${CATEGORY_FILES.map(f => AUDIT_DIR + '/' + f).join('\n- ')}
- ${SRC}/CLAUDE.md and the relevant ${SRC}/cursor_rules/ files for any spec area you classify

STEP 2 — enumerate EVERY BLOCKER and HIGH finding documented in the 5 category files (the handoff says 12 BLOCKER + 30 HIGH actionable; reconcile against the category files, which are authoritative for detail). For each finding, open the actual spec file under ${SRC} and the production code it claims to cover, and confirm the documented problem still holds.

STEP 3 — classify each finding:
- FIX-SPEC: the test can be made to genuinely exercise current production behavior with a bounded spec edit (resync a drifted assertion, replace \`not_to raise_error\` theater with a real behavioral assertion, correct a stub's args, add the missing assertion). Give the concrete proposedFix naming exact assertions/identifiers.
- DEFER: a ghost that is NOT easily fixable — fixing it would require substantial new test scaffolding, the thing it claims to cover is genuinely hard to assert, or the right fix is unclear. Give deferReason + what stays uncovered. DO NOT propose deletion.

${GROUND_RULES}

Return the full findings array. Be exhaustive — every BLOCKER and HIGH, grouped logically, each with a stable id and the repo-relative specFile path.`,
  { schema: TRIAGE_SCHEMA, label: 'triage' }
)

const findings = (triage?.findings || []).filter(f => !DEFERRED.includes(f.specFile))
log(`Triage: ${findings.length} findings (${findings.filter(f => f.classification === 'FIX-SPEC').length} FIX-SPEC, ${findings.filter(f => f.classification === 'DEFER').length} DEFER)`)

// group by spec file for verification + fix
const byFile = {}
for (const f of findings) (byFile[f.specFile] ||= []).push(f)
const fileGroups = Object.entries(byFile).map(([specFile, fs]) => ({ specFile, findings: fs }))

// ---- Phase 1: Verify Triage (per spec-file group, parallel) ----
phase('Verify Triage')
const verifications = await parallel(
  fileGroups.map(g => () =>
    agent(
      `Independently verify the triage classifications for ONE spec file. Do NOT trust the triage agent — re-derive from the real code.

Spec file: ${SRC}/${g.specFile}

Findings to verify (with triage's call + proposed fix):
${JSON.stringify(g.findings, null, 2)}

For each finding: open the spec at the cited location and the production code it covers. Decide independently whether the triage classification (FIX-SPEC vs DEFER) is correct and whether the proposedFix would actually work and is minimal. Common errors to catch: a ghost mislabeled FIX-SPEC; an easily-fixable drift mislabeled DEFER; a proposedFix that touches production code or adds out-of-scope scaffolding; a proposedFix that would itself be a ghost.

${GROUND_RULES}

Return one entry per finding id.`,
      { schema: VERIFY_SCHEMA, label: `verify:${g.specFile.split('/').pop()}`, phase: 'Verify Triage' }
    )
  )
).then(rs => rs.filter(Boolean))

// merge verifier decisions back onto findings
const decision = {}
for (const v of verifications) for (const e of (v.verified || [])) decision[e.id] = e
const finalFindings = findings.map(f => {
  const d = decision[f.id]
  if (!d) return f
  return {
    ...f,
    classification: d.finalClassification || f.classification,
    proposedFix: d.correctedFix && d.correctedFix.length ? d.correctedFix : f.proposedFix,
    verifyNote: d.note,
  }
})

const deferred = finalFindings.filter(f => f.classification === 'DEFER')
const toFix = finalFindings.filter(f => f.classification === 'FIX-SPEC')

// rebuild fix work items grouped by spec file
const fixByFile = {}
for (const f of toFix) (fixByFile[f.specFile] ||= []).push(f)
const fixItems = Object.entries(fixByFile).map(([specFile, fs]) => ({ specFile, findings: fs }))
log(`After verify: ${fixItems.length} spec files to fix, ${deferred.length} deferred ghosts`)

// ---- Phases 2-4: Fix -> Run -> Review (pipeline, one chain per spec file) ----
phase('Fix')
const results = await pipeline(
  fixItems,
  // stage 1: fix the spec
  (item) =>
    agent(
      `Fix ONE RSpec file so its tests genuinely exercise the EXISTING production code. Minimal change only.

Spec file: ${SRC}/${item.specFile}

Findings to fix (apply ALL of them):
${JSON.stringify(item.findings, null, 2)}

Before editing: read the spec file fully, read the production code it covers, and read ${SRC}/cursor_rules/core_critical_rules.md plus the area _base.md relevant to this spec. Follow project test conventions exactly.

HARD CONSTRAINTS (Known Failure Pattern #10 — fix agents must not exceed defect scope):
- Edit ONLY this spec file. NEVER touch app/, lib/, config/, db/. Production code is ground truth.
- Make the MINIMUM change that resolves each finding. Do NOT rewrite untouched tests, do NOT add new helpers/contexts beyond what the fix needs, do NOT "improve" adjacent code.
- Each fixed test must assert real behavior — it must FAIL if the production logic it covers were removed. No \`not_to raise_error\`-only assertions.
- Do NOT run the spec yet (a later stage does that). Just edit.

${GROUND_RULES}

Return what you applied. touchedProdCode MUST be false.`,
      { schema: FIX_SCHEMA, label: `fix:${item.specFile.split('/').pop()}`, phase: 'Fix' }
    ),
  // stage 2: run the spec
  (fix, item) =>
    agent(
      `Run ONE RSpec file against the EXISTING test DB and report results faithfully.

Run exactly: cd ${SRC} && bundle exec rspec ${item.specFile}

DB SAFETY (hard): if the spec errors because the test DB is not migrated / pending migrations, STOP and report it in blockedReason. NEVER run db:reset/db:setup/db:schema:load/db:test:prepare, never set DATABASE_URL, never edit .env. db:migrate (apply pending) is the ONLY db command allowed, and only if clearly needed — prefer to just report.

Report passed=true ONLY if rspec exits 0 with 0 failures. Capture the example/failure counts and the tail of output including any failure messages. Do not edit any file.`,
      { schema: RUN_SCHEMA, label: `run:${item.specFile.split('/').pop()}`, phase: 'Run Specs' }
    ).then(run => ({ ...run, fix })),
  // stage 3: adversarial review of the working-tree diff
  (run, item) =>
    agent(
      `Adversarially review the spec changes for ONE file. You are reviewing the WORKING-TREE diff (uncommitted) — note that explicitly (Known Failure Pattern #15: this is working-tree, not a committed branch).

Get the diff: cd ${SRC} && git diff -- ${item.specFile}
Also read the full current spec and the production code it covers.

Run-stage result for context: passed=${run?.passed}, ${run?.exampleCounts || ''} ${run?.blockedReason ? '(BLOCKED: ' + run.blockedReason + ')' : ''}

Check TWO things on every changed/added test:
1. GHOST RECHECK — would this assertion still pass if the production logic it claims to cover were deleted or no-opped? If yes, it's a ghost (the fix relocated theater instead of removing it). Give the would-pass-if-deleted reasoning as evidence.
2. FRAGILITY — over-stubbing that stubs the very boundary under test, hardcoded magic values, order/time dependence, mystery guests (relying on unseen global state), passes-for-the-wrong-reason. Green but brittle.

Be skeptical. A passing spec is not automatically clean. Report every ghost or fragility finding with location + evidence. verdict CLEAN only if genuinely both ghost-free and robust. Do not edit any file.`,
      { schema: REVIEW_SCHEMA, label: `review:${item.specFile.split('/').pop()}`, phase: 'Adversarial Review' }
    ).then(review => ({ specFile: item.specFile, fix: run?.fix, run: { passed: run?.passed, exampleCounts: run?.exampleCounts, blockedReason: run?.blockedReason, output: run?.output }, review }))
).then(rs => rs.filter(Boolean))

// ---- final assembly ----
const reds = results.filter(r => !r.run?.passed)
const dirty = results.filter(r => r.review && r.review.verdict !== 'CLEAN')
log(`Done: ${results.length} specs fixed, ${reds.length} not green, ${dirty.length} flagged by adversarial review, ${deferred.length} deferred ghosts`)

return {
  triageCount: findings.length,
  fixedSpecCount: fixItems.length,
  deferredGhosts: deferred.map(f => ({ id: f.id, specFile: f.specFile, location: f.location, problem: f.problem, deferReason: f.deferReason })),
  results,
  notGreen: reds.map(r => ({ specFile: r.specFile, blockedReason: r.run?.blockedReason, output: r.run?.output })),
  flaggedByReview: dirty.map(r => ({ specFile: r.specFile, verdict: r.review.verdict, findings: r.review.findings })),
}
