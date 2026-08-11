export const meta = {
  name: 'plato-ai-qa-and-docs',
  description: 'Map the Plato AI develop-vs-production diff and synthesize a solo-doable manual QA guide, a stakeholder scoring-pipeline manifest, and a feature changelog; then adversarially verify, prune, and judge human feasibility.',
  phases: [
    { title: 'Map', detail: '~22 agents each map one file-bucket of the 289-file diff' },
    { title: 'Synthesize', detail: 'D1 QA guide + D2 scoring manifest + D3 changelog + D4 regression' },
    { title: 'Verify', detail: 'iterative adversarial verify loop, <=6 rounds, 2 clean passes per doc' },
    { title: 'Prune', detail: 'remove unquestionably unhelpful QA additions until zero removals' },
    { title: 'Feasibility', detail: 'judge D1 manageable for one person solo in person; trim if not' },
  ],
}

const REPO = '/Users/jessica/wrk/wrk-corp/inflow-ats'
const OUT = '/Users/jessica/claude-hub/inflow-ats/qa-guides/plato-ai-manual-qa-2026-07-01'
const DIFF = `git -C ${REPO} diff production...develop`
const NAMES = `git -C ${REPO} diff --name-only production...develop`

const CTX = `FEATURE = "Plato AI": candidate AI summaries + AI scoring (job-criteria extraction pipeline + summary scoring pipeline) plus AI-credits billing (subscription + one-off).
The feature = everything on branch develop not yet on production.
Source repo: ${REPO}
Full feature diff (289 files, +27,925/-187): \`${DIFF}\`
List changed files: \`${NAMES}\`
Every file in this diff is AI-related directly or indirectly. Some AI changes touch SHARED/non-AI surfaces (serializers, shared components, cross-feature models, controllers, websockets, jobs, mailers) and could regress non-AI behavior.`

const D1_STYLE = `D1 (Manual QA guide) STYLE RULES — MANDATORY:
- Audience = the engineer who BUILT this feature. Expert. Solo. In person. One sitting. No beginner handholding.
- Define general test CASES and CONDITIONS: WHAT to verify + under what conditions/states/edge cases. NOT step-by-step click instructions.
- A few orienting notes on HOW to reach an area is enough (which page/tab), nothing more.
- UI-only. No backend, console, db, or API steps.
- Concise and DOABLE. Not exhaustive, not eons-long. Prioritize high-value and high-risk paths over trivial ones.`

// ---------- MAP BUCKETS ----------
const buckets = [
  { label: 'fe-plato-tab-display', list: `${NAMES} | grep -E 'views/jobApplications/(Plato/|PlatoTab|PlatoSparkle|PlatoOverview|AiSummaryState)'`, hint: 'Plato tab, AI summary display/state, sparkle/overview UI' },
  { label: 'fe-run-plato-ctas-bulk', list: `${NAMES} | grep -E 'views/jobApplications/(RunPlato|useRunPlato|BulkGenerateAiSummaries|jobSetup/)'`, hint: 'Run-Plato CTA cards/modals, bulk generate modal, jobSetup' },
  { label: 'fe-jobapp-list-sidebar-stages', list: `${NAMES} | grep -E 'views/jobApplications/(JobApplication(Container|List|Nav|Sidebar|Activity)|JobStage|JobStages|FilterSort)'`, hint: 'candidate list, sidebar actions, stage menus, filters — shared surfaces AI touched (regression-relevant)' },
  { label: 'fe-account-billing', list: `${NAMES} | grep -E 'views/accountAdmin/(accountBilling/|OrganizationAiBilling)'`, hint: 'AI credits billing UI: subscribe, one-off purchase, balance, invoices' },
  { label: 'fe-account-platoai-settings', list: `${NAMES} | grep -E 'views/accountAdmin/(accountPlatoAi/|OrganizationAiSettings|OrganizationAiUsage|AccountContainer)'`, hint: 'org AI settings, auto-generate toggle, usage, plan gating' },
  { label: 'fe-shared-components', list: `${NAMES} | grep -E 'app/javascript/ats/src/(components/(shared|modals|forms)/|views/(layouts|admin)/)'`, hint: 'shared components/modals/forms/layouts touched by AI (regression-relevant)' },
  { label: 'fe-shared-types-hooks-ws', list: `${NAMES} | grep -E 'app/javascript/(shared/(types|queryHooks|lib)/|ats/src/(websockets/|lib/newLookups))'`, hint: 'TS types, query hooks, websocket handlers, lookups — data contracts + realtime updates' },
  { label: 'be-ai-action-a', list: `${NAMES} | grep -E '^app/services/ai_job_application_action/' | sort | sed -n '1,9p'`, hint: 'AI job-application action services (scoring/generation) — first half' },
  { label: 'be-ai-action-b', list: `${NAMES} | grep -E '^app/services/ai_job_application_action/' | sort | sed -n '10,20p'`, hint: 'AI job-application action services (extraction/bulk) — second half' },
  { label: 'be-ai-providers-pipeline', list: `${NAMES} | grep -E '^app/services/(ai_providers/|ai_client\\.rb|ai_relevance_benchmark\\.rb|submit_resume_to_textract\\.rb|get_resume_text_from_textract\\.rb)'`, hint: 'THE LLM/model pipeline: providers, ai_client, textract resume extraction, relevance benchmark. Trace exact models, prompts, call sequence — critical for the scoring manifest.' },
  { label: 'be-interactors', list: `${NAMES} | grep -E '^app/interactors/'`, hint: 'AI interactors: create/validate summary generation, credit grant/reset/refund/upgrade/subscription, bulk queue, find_or_create status' },
  { label: 'be-spec-interactors', list: `${NAMES} | grep -E '^spec/interactors/'`, hint: 'interactor specs — behavioral truth of the interactors' },
  { label: 'be-models', list: `${NAMES} | grep -E '^app/models/'`, hint: 'AI models: summary, status, credit balance/transaction/purchase, associations, enums, callbacks' },
  { label: 'be-spec-models', list: `${NAMES} | grep -E '^spec/models/'`, hint: 'model specs — validations, enums, lifecycle' },
  { label: 'be-controllers-policies', list: `${NAMES} | grep -E '^(app|spec)/(controllers|policies)/'`, hint: 'controllers + Pundit policies: permit params, bulk actions, authorization' },
  { label: 'be-jobs', list: `${NAMES} | grep -E '^(app|spec)/jobs/'`, hint: 'Sidekiq jobs: generate/bulk-generate summaries, retry/exhaustion, textract' },
  { label: 'be-serializers', list: `${NAMES} | grep -E '^(app|spec)/serializers/'`, hint: 'serializers — exactly what the frontend receives (data contract)' },
  { label: 'be-mailers-views', list: `${NAMES} | grep -E '^(app/mailers/|app/views/|spec/mailers/)'`, hint: 'mailers + views: low-credit / zero-credit / plan-change notifications' },
  { label: 'be-db', list: `${NAMES} | grep -E '^db/'`, hint: 'migrations + data migrations + schema: new columns/tables/enums' },
  { label: 'be-lib', list: `${NAMES} | grep -E '^lib/'`, hint: 'lib: tasks/backfills/helpers' },
  { label: 'be-stripe-billing', list: `${NAMES} | grep -E '^(app/services/(stripe/|sync_ai_credit_purchases_with_stripe\\.rb|plan_feature_gate\\.rb)|spec/services/)'`, hint: 'Stripe integration, credit-purchase sync, plan feature gate, service specs' },
  { label: 'meta-config-tests', list: `${NAMES} | grep -E '^(cursor_rules/|config/|cypress/|app/errors/|\\.chief|\\.claude)|^(Gemfile|README)'`, hint: 'config, cursor_rules, cypress, errors, gemfile, readme — infra/meta' },
]

function mapPrompt(b) {
  return `${CTX}

You are mapping ONE slice of the Plato AI feature diff. Your slice hint: ${b.hint}

STEPS:
1. List your files:  \`${b.list}\`
2. For each file, read its diff hunks:  \`git -C ${REPO} diff production...develop -- <file>\`  Use the Read tool on surrounding code when a hunk's behavior is unclear. Do NOT trace beyond what you need to state user-visible behavior.
3. Write a concise slice note to  ${OUT}/_map/${b.label}.md  containing:
   - What changed (behavior, not a line-by-line diff recap)
   - USER-VISIBLE / UI behavior and what user ACTIONS this enables or changes
   - Conditions / states / edge cases that gate the behavior
   - Any SHARED / non-AI surface touched that could regress (name it + how)
   - For pipeline/model/provider files: exact models, prompt roles, call order, inputs/outputs (needed for the scoring manifest)
4. Keep the note tight and factual. Return a 4-6 line summary plus the note path.

Return ONLY the structured object.`
}

const MAP_SCHEMA = {
  type: 'object',
  properties: {
    area: { type: 'string' },
    files: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    ui_actions: { type: 'array', items: { type: 'string' } },
    shared_surfaces: { type: 'array', items: { type: 'string' } },
    notePath: { type: 'string' },
  },
  required: ['area', 'summary', 'notePath'],
}

// ================= PHASE A: MAP =================
phase('Map')
log(`Mapping ${buckets.length} buckets across the 289-file Plato AI diff`)
const maps = (await parallel(buckets.map((b) => () =>
  agent(mapPrompt(b), { label: `map:${b.label}`, phase: 'Map', schema: MAP_SCHEMA, effort: 'medium' })
))).filter(Boolean)

// coverage audit — every changed file must appear in some _map note
await agent(`${CTX}

COVERAGE AUDIT. The map agents each wrote a note under ${OUT}/_map/ describing a slice of the diff.
1. Get the full file list:  \`${NAMES}\`
2. For each changed file, check whether its path or basename is referenced anywhere in ${OUT}/_map/*.md (grep the dir).
3. Write ${OUT}/_map/00-coverage.md listing: total files, count covered, and ANY file not referenced in a map note (these are coverage gaps).
Return a 3-line summary with the gap count.`, { label: 'map:coverage-audit', phase: 'Map', effort: 'medium' })

// ================= PHASE B: SYNTHESIZE =================
phase('Synthesize')

const D1_AREAS = [
  { key: 'auto-generate', focus: 'Auto-generate AI summaries: org-level toggle + per-job settings, when it fires (new applicant, stage move), gating by plan/credits.' },
  { key: 'manual-and-display', focus: 'Manual single generate from a candidate; Plato tab + AI summary display, states (pending/generating/succeeded/failed/none), regenerate, score/headline/analysis rendering.' },
  { key: 'bulk-generate', focus: 'Bulk generate across candidates: all-candidates bulk action, job+stage scoping, INCLUDE vs EXCLUDE candidates that already have scores, confirmation modal, progress/failure toasts.' },
  { key: 'billing-credits-ui', focus: 'AI credits billing UI: subscribe to credit subscription, one-off credit purchase, balance display, low/zero-credit states, plan feature gating, cancel/upgrade.' },
]

function d1AreaPrompt(a) {
  return `${CTX}

${D1_STYLE}

Read the relevant slice notes in ${OUT}/_map/ (read the whole dir; focus on those matching your area). Your area: ${a.key} — ${a.focus}

Write ${OUT}/_qa/qa-${a.key}.md: a CASE-oriented QA section for this area. Each item = a test CASE (what to verify) + the CONDITION/state it applies under + at most a one-line note on where in the UI to do it. Group related cases. No step-by-step. UI-only. Concise. Cover the real behavior from the diff, prioritizing risky/high-value paths.
Return a 3-line summary + the file path.`
}

function verifyPromptBuilder() {}

// D1 area writers + D4 regression tracer run together; then D4 cases; then D1 assembler.
// D2 and D3 run concurrently with the whole D1 chain.
const [_d1areas, _regression, _d2, _d3] = await parallel([
  // --- D1 area writers, then regression cases, then assemble ---
  async () => {
    await parallel(D1_AREAS.map((a) => () =>
      agent(d1AreaPrompt(a), { label: `synth:qa-${a.key}`, phase: 'Synthesize' })
    ))
    return true
  },
  // --- D4 regression: trace AI->shared intersections, then convert to QA cases ---
  async () => {
    await agent(`${CTX}

Read ${OUT}/_map/ (especially serializers, shared components, cross-feature models, controllers, websockets, jobs, mailers).
Identify where Plato AI changes touch SHARED / non-AI surfaces such that NON-AI behavior could regress. For each: name the surface, the AI change, and the plausible non-AI breakage.
Write ${OUT}/_map/regression-intersections.md. Return a 3-line summary.`, { label: 'synth:regression-trace', phase: 'Synthesize' })

    await agent(`${CTX}

${D1_STYLE}

Read ${OUT}/_map/regression-intersections.md. Convert the real risks into a SHORT set of regression QA CASES (what non-AI behavior to spot-check + the condition). Same case-oriented style, UI-only, concise — only genuinely at-risk non-AI behavior, not everything.
Write ${OUT}/_qa/qa-regression.md. Return a 2-line summary.`, { label: 'synth:qa-regression', phase: 'Synthesize' })
    return true
  },
  // --- D2 scoring manifest: extraction + scoring writers, then stakeholder merge ---
  async () => {
    await parallel([
      () => agent(`${CTX}

Read ${OUT}/_map/ (focus: be-ai-providers-pipeline, be-ai-action-*, textract, criteria extraction). Also read the actual pipeline code in ${REPO} where the map notes point, to get exact models and call order.
Write ${OUT}/_manifest/extraction.md: precisely how the JOB-CRITERIA EXTRACTION pipeline works — inputs (job description, resume via textract), model(s) used, prompt roles, call sequence, outputs. Factual and exact.
Return a 3-line summary.`, { label: 'synth:manifest-extraction', phase: 'Synthesize' }),
      () => agent(`${CTX}

Read ${OUT}/_map/ (focus: scoring interactors, ai_job_application_action, summary generation, providers). Read the actual code where needed for exactness.
Write ${OUT}/_manifest/scoring.md: precisely how the SUMMARY / SCORING pipeline works — how a candidate is scored against criteria, model(s), call sequence, what score/headline/analysis are produced, how credits are consumed.
Return a 3-line summary.`, { label: 'synth:manifest-scoring', phase: 'Synthesize' }),
    ])
    await agent(`${CTX}

Read ${OUT}/_manifest/extraction.md and ${OUT}/_manifest/scoring.md.
Write ${OUT}/D2-scoring-pipeline-manifest.md — a STAKEHOLDER-facing document a non-engineer executive can follow and that Jessica can turn into a slide deck:
- Explain, end to end, exactly how candidates are scored (extraction -> scoring), showing the pipeline's real complexity (multiple model calls, structured criteria) WITHOUT drowning them in code.
- A clear BIAS-PREVENTION section: what the pipeline does and does NOT do re: fairness (what inputs it uses, what it ignores, guardrails present) — accurate, not overstated, not an audit claim.
- Keep prose stakeholder-readable; put exact model names / call order in a short technical appendix.
Return a 3-line summary.`, { label: 'synth:manifest-merge', phase: 'Synthesize' })
    return true
  },
  // --- D3 changelog ---
  async () => {
    await agent(`${CTX}

Read ${OUT}/_map/.
Write ${OUT}/D3-feature-changelog.md — a PUBLIC, changelog-style description of the shipped Plato AI capabilities, written for end users. Cover at minimum: enabling AUTO-GENERATE, MANUAL generation, BULK generation, and INCLUDING vs EXCLUDING candidates that already have scores. Group by capability, benefit-oriented, accurate to what actually shipped in the diff.
Return a 3-line summary.`, { label: 'synth:changelog', phase: 'Synthesize' })
    return true
  },
])

// D1 assembler — after area writers + regression cases exist
await agent(`${CTX}

${D1_STYLE}

Read every ${OUT}/_qa/*.md section (auto-generate, manual-and-display, bulk-generate, billing-credits-ui, regression).
Assemble ${OUT}/D1-manual-qa-guide.md — ONE ordered manual QA guide:
- Case-oriented throughout. WHAT to test + condition. No step-by-step.
- Logical order a solo tester would follow (settings/enablement -> generation modes -> display -> billing -> regression spot-checks).
- Dedupe overlap between sections. Cut low-value cases. Keep it concise and solo-doable in one sitting.
- A one-paragraph preamble stating scope + assumptions (expert tester, UI-only).
Return the doc path + rough case count.`, { label: 'synth:D1-assemble', phase: 'Synthesize' })

// ================= PHASE C: VERIFY LOOP =================
phase('Verify')
const DOCS = [
  { key: 'D1', path: `${OUT}/D1-manual-qa-guide.md`, lenses: [
    { key: 'style', ask: `Is it CASE+CONDITION oriented (NOT step-by-step), expert-audience, UI-only? Flag any step-by-step click sequences, beginner handholding, or backend/console/db steps.` },
    { key: 'coverage', ask: `Compare against ${OUT}/_map/. Flag any MAJOR feature area or high-risk path from the diff that is missing. Do not demand trivial coverage.` },
    { key: 'doability', ask: `Is it concise and realistically doable by ONE person in one sitting? Flag bloat, eons-long sprawl, redundant cases.` },
    { key: 'accuracy', ask: `Spot-check cases against the map notes / code. Flag cases describing behavior that does not exist in this diff, or wrong conditions.` },
  ] },
  { key: 'D2', path: `${OUT}/D2-scoring-pipeline-manifest.md`, lenses: [
    { key: 'technical-accuracy', ask: `Trace claims to the real pipeline code/map notes. Flag any inaccurate model name, call order, input, or invented step.` },
    { key: 'bias-claims', ask: `Are the bias-prevention claims accurate and not overstated (no false audit/fairness guarantee)? Flag over- or under-statements.` },
    { key: 'stakeholder-clarity', ask: `Is it readable by a non-engineer exec yet conveys real complexity, and slide-deck-craftable? Flag jargon walls or oversimplification.` },
  ] },
  { key: 'D3', path: `${OUT}/D3-feature-changelog.md`, lenses: [
    { key: 'shipped-accuracy', ask: `Does every described capability actually exist in the diff? Flag anything not shipped.` },
    { key: 'completeness', ask: `Are auto-generate, manual, bulk, and include/exclude-already-scored all covered accurately? Flag omissions.` },
  ] },
]
const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    clean: { type: 'boolean' },
    findings: { type: 'array', items: { type: 'object', properties: {
      severity: { type: 'string', enum: ['blocker', 'high', 'med', 'low'] },
      location: { type: 'string' },
      problem: { type: 'string' },
      fix: { type: 'string' },
    }, required: ['severity', 'problem', 'fix'] } },
  },
  required: ['clean', 'findings'],
}
const state = {}
DOCS.forEach((d) => { state[d.key] = { streak: 0, done: false, outstanding: [] } })

for (let round = 1; round <= 6; round++) {
  const activeDocs = DOCS.filter((d) => !state[d.key].done)
  if (!activeDocs.length) break
  log(`Verify round ${round}: judging ${activeDocs.map((d) => d.key).join(', ')}`)
  await parallel(activeDocs.map((d) => async () => {
    const verdicts = (await parallel(d.lenses.map((l) => () =>
      agent(`${CTX}

Adversarially verify ${d.path} through the "${l.key}" lens.
${l.ask}
${d.key === 'D1' ? D1_STYLE : ''}
Read the doc and the relevant ${OUT}/_map/ notes (and code if needed). Report ONLY real, actionable findings; set clean=true with empty findings if the doc passes this lens. Do not invent nitpicks.`,
        { label: `verify:${d.key}:${l.key}:r${round}`, phase: 'Verify', schema: FINDINGS_SCHEMA })
    ))).filter(Boolean)
    const findings = verdicts.flatMap((v) => v.findings || []).filter((f) => f && f.severity !== 'low')
    if (!findings.length) {
      state[d.key].streak++
      state[d.key].outstanding = []
      if (state[d.key].streak >= 2) { state[d.key].done = true; log(`${d.key} cleared 2 consecutive clean passes`) }
    } else {
      state[d.key].streak = 0
      state[d.key].outstanding = findings
      await agent(`${CTX}

Revise ${d.path} to resolve these verified findings. Apply the MINIMUM change per finding — do not rewrite beyond the finding, do not add unspecified scope, do not delete unrelated content.
${d.key === 'D1' ? D1_STYLE : ''}
Findings:
${findings.map((f, i) => `${i + 1}. [${f.severity}] ${f.location || ''}: ${f.problem} -> FIX: ${f.fix}`).join('\n')}
Edit the file in place. Return a 2-line summary of what you changed.`,
        { label: `revise:${d.key}:r${round}`, phase: 'Verify' })
    }
  }))
}
const unresolved = DOCS.filter((d) => !state[d.key].done)
if (unresolved.length) {
  log(`Verify hit 6-round cap with unresolved: ${unresolved.map((d) => `${d.key}(${state[d.key].outstanding.length})`).join(', ')}`)
}

// ================= PHASE D: QA PRUNE LOOP =================
phase('Prune')
const PRUNE_SCHEMA = {
  type: 'object',
  properties: {
    removals: { type: 'array', items: { type: 'object', properties: {
      location: { type: 'string' }, reason: { type: 'string' },
    }, required: ['location', 'reason'] } },
  },
  required: ['removals'],
}
let pruneRounds = 0
for (let r = 1; r <= 4; r++) {
  pruneRounds = r
  const flag = await agent(`${CTX}

Read ${OUT}/D1-manual-qa-guide.md. Flag ONLY QA additions that are UNQUESTIONABLY unhelpful — clear-cut noise, useless or trivially-true checks, or exact duplicates. Be strict: if a case is borderline or arguably useful, DO NOT flag it. Empty list is the expected common outcome.
Return the removals list.`, { label: `qa-prune-flag:r${r}`, phase: 'Prune', schema: PRUNE_SCHEMA, effort: 'medium' })
  if (!flag || !flag.removals || !flag.removals.length) { log(`Prune round ${r}: nothing unquestionably unhelpful — done`); break }
  await agent(`${CTX}

Edit ${OUT}/D1-manual-qa-guide.md to REMOVE exactly these unquestionably-unhelpful items and nothing else:
${flag.removals.map((x, i) => `${i + 1}. ${x.location} — ${x.reason}`).join('\n')}
Do not touch anything else. Return a 1-line confirmation.`, { label: `qa-prune-apply:r${r}`, phase: 'Prune' })
}

// ================= PHASE E: HUMAN-SOLO FEASIBILITY =================
phase('Feasibility')
const FEAS_SCHEMA = {
  type: 'object',
  properties: {
    manageable: { type: 'boolean' },
    est_minutes: { type: 'number' },
    reasoning: { type: 'string' },
    trims: { type: 'array', items: { type: 'string' } },
  },
  required: ['manageable', 'reasoning'],
}
function feasPrompt(pass) {
  return `${CTX}

FINAL FEASIBILITY JUDGE (pass ${pass}). Read ${OUT}/D1-manual-qa-guide.md AS CURRENTLY FORMATTED.
Judge: can ONE person, solo, in person, realistically execute this in a single sitting? Consider total volume, sequencing, and whether any case secretly needs a second person or non-UI access.
Also WRITE/UPDATE ${OUT}/E-feasibility-verdict.md with your verdict, estimated time, and any recommended trims.
Return the structured verdict.`
}
let verdict = await agent(feasPrompt(1), { label: 'feasibility-judge', phase: 'Feasibility', schema: FEAS_SCHEMA })
if (verdict && verdict.manageable === false) {
  log(`Feasibility: NOT manageable as-is — trimming to solo scope`)
  await agent(`${CTX}

${D1_STYLE}

The feasibility judge found ${OUT}/D1-manual-qa-guide.md is too much for one person solo in one sitting.
Reasoning: ${verdict.reasoning}
Recommended trims: ${(verdict.trims || []).join('; ')}
Edit the guide to fit solo-in-one-sitting scope: cut or merge the lowest-value cases, keep all high-risk/high-value coverage. Do not add anything. Return a 2-line summary.`, { label: 'feasibility-trim', phase: 'Feasibility' })
  verdict = await agent(feasPrompt(2), { label: 'feasibility-rejudge', phase: 'Feasibility', schema: FEAS_SCHEMA })
}

return {
  mappedBuckets: maps.length,
  docs: {
    D1: `${OUT}/D1-manual-qa-guide.md`,
    D2: `${OUT}/D2-scoring-pipeline-manifest.md`,
    D3: `${OUT}/D3-feature-changelog.md`,
    regression: `${OUT}/_map/regression-intersections.md`,
    feasibility: `${OUT}/E-feasibility-verdict.md`,
  },
  verify: Object.fromEntries(DOCS.map((d) => [d.key, { clean: state[d.key].done, outstanding: state[d.key].outstanding.length }])),
  pruneRounds,
  feasibility: verdict,
}
