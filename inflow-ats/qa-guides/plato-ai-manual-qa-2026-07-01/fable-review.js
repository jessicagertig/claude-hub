export const meta = {
  name: 'plato-ai-fable-review',
  description: 'Independent Fable (claude-fable-5) review of the post-verify D1 QA guide, D2 scoring manifest, and D3 changelog: find new real issues and adjudicate the prior Opus verify findings against real code.',
  phases: [
    { title: 'Fable review', detail: '3 Fable doc reviewers + 1 Fable code-truth adjudicator', model: 'fable' },
  ],
}

const REPO = '/Users/jessica/wrk/wrk-corp/inflow-ats'
const OUT = '/Users/jessica/claude-hub/inflow-ats/qa-guides/plato-ai-manual-qa-2026-07-01'
const DIFF = `git -C ${REPO} diff production...develop`

const CTX = `You are an INDEPENDENT reviewer running on a DIFFERENT model (Fable) than the pipeline that produced these docs. Your job is fresh adversarial scrutiny, not agreement.

FEATURE = "Plato AI": candidate AI summaries + scoring (job-criteria EXTRACTION pipeline + summary SCORING pipeline) + AI-credits billing (subscription + one-off).
The feature = everything on branch develop not on production. Source repo: ${REPO}. Full diff: \`${DIFF}\`.
Map notes describing the diff: ${OUT}/_map/*.md
OWNER-CONFIRMED GROUND TRUTH (authoritative, from the engineer who built it): ${OUT}/CORRECTIONS.md — READ THIS FIRST. Prior review conflated three distinct controls; do not repeat that.

Verify claims against REAL CODE in ${REPO} (read the actual files). Do not trust the docs or the prior findings — check.`

const D1_STYLE = `D1 is a MANUAL QA GUIDE with these intended style rules: audience = the engineer who built the feature (expert, solo, in person, one sitting); define general test CASES + CONDITIONS (WHAT to test), NOT step-by-step clicks; UI-only; concise and doable, not exhaustive. Judge D1 against these rules.`

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    doc: { type: 'string' },
    new_findings: { type: 'array', items: { type: 'object', properties: {
      severity: { type: 'string', enum: ['blocker', 'high', 'med', 'low'] },
      location: { type: 'string' },
      problem: { type: 'string' },
      fix: { type: 'string' },
      evidence: { type: 'string', description: 'file:line or code fact proving it' },
    }, required: ['severity', 'location', 'problem', 'fix', 'evidence'] } },
    adjudications: { type: 'array', items: { type: 'object', properties: {
      prior_finding: { type: 'string' },
      verdict: { type: 'string', enum: ['CONFIRMED', 'REFUTED', 'PARTIAL'] },
      evidence: { type: 'string' },
    }, required: ['prior_finding', 'verdict', 'evidence'] } },
    overall: { type: 'string', description: '2-3 sentence bottom line on this doc' },
  },
  required: ['doc', 'new_findings', 'adjudications', 'overall'],
}

const priorD1 = [
  'Several cases require backend/error/exact-value state not producible UI-only (§3.4, 4.4, 5.3, 3.7) — contradicts the guide\'s own UI-only rule',
  'Not doable in one sitting; §5 walks a full Stripe subscribe→upgrade→downgrade lifecycle; overall length too long',
  'Prioritization (MUST-RUN vs APPENDIX triage) applied to only 1 of 6 sections (§5); other sections un-triaged',
  'Same websocket "live-transition-without-reload" case re-verified as a full pipeline run in 4 places (§2.1, 3.3, 3.5, 4.5) — redundant',
  'Notifications settings sub-feature missing from §1 (OrganizationAiSettings FormSection, ~3 fields)',
  'Job-criteria EXTRACTION pipeline (named in FEATURE) has no dedicated test case',
  'Manual single-generate async completion toast never verified (§3.3)',
  'Org DELETION missing (§6.6) — Organization gained has_one/has_many AI credit records with dependent: destroy',
  'Score exactly 0 → "Poor, 0 stars" state asserted but does not exist (min 1 fill)',
  'Highest-value cases need credit-balance/subscription preconditions expensive to reach UI-only; guide never says how',
]
const priorD2 = [
  'Fit-band table (lines ~97-103) uses overlapping ranges (90% in both Excellent & Good; 60% in both Good & Mixed; etc.)',
  '"roughly 4-11 AI calls" floor is wrong — true minimum is 5 (extraction + scoring calls in generate.rb)',
]
const priorD3 = [
  'Auto-generate "every new applicant with a resume is reviewed" is an absolute claim; code gates on more (job criteria / enabled)',
  'Candidate list "shows a fit rating with a color swatch and star band" — claimed not shipped (JobApplicationNavItem renders a FitHarvey ball, no stars/color)',
  '"Run Plato" button label reference — prior review called it a false Plato-tab control (see CORRECTIONS.md: Run Plato is the SIDEBAR whole-job bulk control)',
  'Balance "each resets" per-source claim is imprecise',
]

function reviewPrompt(docKey, docPath, prior, styleNote) {
  return `${CTX}

REVIEW TARGET: ${docPath}
${styleNote || ''}

Read: the target doc, ${OUT}/CORRECTIONS.md, the relevant ${OUT}/_map/*.md notes, and the actual code in ${REPO} for anything you assert.

TASK A — NEW findings: independently find real, actionable defects in this doc (factual accuracy vs code, missing high-risk coverage, ${docKey === 'D1' ? 'doability solo-in-one-sitting, UI-only compliance, case-oriented style' : 'clarity and correctness'}). Every finding MUST cite code evidence (file:line or a concrete code fact). Do not invent nitpicks; do not pad.

TASK B — ADJUDICATE these findings from the prior (Opus) review. For each, verify against real code and return CONFIRMED / REFUTED / PARTIAL with evidence:
${prior.map((p, i) => `${i + 1}. ${p}`).join('\n')}

Return the structured object for doc="${docKey}".`
}

phase('Fable review')
log('Launching independent Fable (claude-fable-5) review over D1/D2/D3 + code-truth adjudicator')

const CONTESTED = [
  'Candidate list fit indicator: does JobApplicationNavItem render a "color swatch and star band", a FitHarvey ball, or something else? State exactly what ships.',
  'Minimum AI calls for a candidate review to reach "succeeded": is the floor 4 or 5? Trace generate.rb and the scoring pipeline call sequence.',
  'The three generate/run controls per CORRECTIONS.md ("Generate review", "Generate review now", "Run Plato"): confirm each label, its surface (Plato tab vs sidebar), its trigger condition, and whether it is single-candidate or whole-job bulk. Verify D1 and D3 describe them correctly.',
  'Free / no-plan orgs: do they receive a monthly AI credit allocation, or are there zero-allocation plan states? Check the plan credit allocation logic.',
  'Auto-generate trigger: what are ALL the conditions gating auto-review of a new applicant (resume present, job enabled, criteria, plan/credits)? Is "every new applicant with a resume is reviewed" accurate?',
]

const results = (await parallel([
  () => agent(reviewPrompt('D1', `${OUT}/D1-manual-qa-guide.md`, priorD1, D1_STYLE), { label: 'fable:review-D1', phase: 'Fable review', model: 'fable', schema: REVIEW_SCHEMA }),
  () => agent(reviewPrompt('D2', `${OUT}/D2-scoring-pipeline-manifest.md`, priorD2), { label: 'fable:review-D2', phase: 'Fable review', model: 'fable', schema: REVIEW_SCHEMA }),
  () => agent(reviewPrompt('D3', `${OUT}/D3-feature-changelog.md`, priorD3), { label: 'fable:review-D3', phase: 'Fable review', model: 'fable', schema: REVIEW_SCHEMA }),
  () => agent(`${CTX}

CODE-TRUTH ADJUDICATOR. Do NOT rely on the docs. For each contested claim below, go to the real code in ${REPO} and state the ground truth with file:line evidence. Read CORRECTIONS.md first.

${CONTESTED.map((c, i) => `${i + 1}. ${c}`).join('\n\n')}

Return an object: doc="ADJUDICATOR", new_findings=[] (unless you find a code fact that contradicts any doc — then add it), adjudications=[one per contested claim above with verdict CONFIRMED/REFUTED/PARTIAL relative to what the docs currently say, plus the code ground truth in evidence], overall=bottom line.`, { label: 'fable:code-truth-adjudicator', phase: 'Fable review', model: 'fable', schema: REVIEW_SCHEMA }),
])).filter(Boolean)

// write a consolidated report
const report = results.map((r) => {
  const nf = (r.new_findings || []).map((f) => `- [${f.severity}] ${f.location}: ${f.problem}\n  FIX: ${f.fix}\n  EVIDENCE: ${f.evidence}`).join('\n')
  const adj = (r.adjudications || []).map((a) => `- ${a.verdict}: ${a.prior_finding}\n  EVIDENCE: ${a.evidence}`).join('\n')
  return `## ${r.doc}\n\n**Bottom line:** ${r.overall}\n\n### New findings\n${nf || '_(none)_'}\n\n### Adjudication of prior findings\n${adj || '_(none)_'}\n`
}).join('\n---\n\n')

await agent(`Write this exact markdown to ${OUT}/FABLE-REVIEW.md verbatim (create/overwrite the file). Return a 1-line confirmation.\n\n---\n\n# Fable (claude-fable-5) Independent Review — Plato AI docs\n\n${report}`,
  { label: 'fable:write-report', phase: 'Fable review', model: 'fable' })

return {
  reviewer: 'claude-fable-5',
  report: `${OUT}/FABLE-REVIEW.md`,
  docsReviewed: results.map((r) => r.doc),
  totals: Object.fromEntries(results.map((r) => [r.doc, {
    new_findings: (r.new_findings || []).length,
    confirmed: (r.adjudications || []).filter((a) => a.verdict === 'CONFIRMED').length,
    refuted: (r.adjudications || []).filter((a) => a.verdict === 'REFUTED').length,
    partial: (r.adjudications || []).filter((a) => a.verdict === 'PARTIAL').length,
  }])),
}
