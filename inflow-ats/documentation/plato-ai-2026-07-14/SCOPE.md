# Plato AI — Documentation & Mapping — Scope

**Date:** 2026-07-14
**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`

## Provenance

Contents moved 2026-07-14 from `~/claude-hub/inflow-ats/qa-guides/plato-ai-manual-qa-2026-07-01/`, where they were produced as secondary deliverables of the manual QA effort. Focus of THIS directory is documentation and codebase mapping; manual QA assets (D1 guide, `_qa/` per-feature docs, QA checklist, review harness) remain in the original directory.

## Diff basis (as of 2026-07-01 — the mapping snapshot)

The mapped delta is pinned to commits, NOT branch names. The feature has since shipped to production, so `git diff production...develop` today does NOT reproduce this delta — use the SHAs:

**Diff: `git diff a92bcdd25...41554141b`** — 289 files, +27,925 / −187.

| Commit | Was (2026-07-01) | Date |
|---|---|---|
| `a92bcdd25` (PR #3037) | `production` tip | 2026-06-15 |
| `41554141b` (PR #3050) | `develop` tip | 2026-07-01 |

All mapping and manifests describe the repo at `41554141b`. Changes merged after 2026-07-01 are NOT reflected here.

## Production divider (found 2026-07-14)

**The `production` branch is READ-ONLY for agents. No fetch, no fast-forward, no checkout, no ref updates — Jessica pulls it herself. Agents only read history that is already local.**

- **Divider PR: #3058**, merge commit `e44e3de9f`, merged to production 2026-07-06 — the first production merge containing AI content. Production immediately before it (`e44e3de9f^1` = `a92bcdd25`) has zero AI files.
- Pre-AI baseline `a92bcdd25` (PR #3037, 2026-06-15) is the SAME commit as the mapping snapshot's production base above.
- **All develop→production promotes since baseline (4):** #3058 (2026-07-06), #3061 (2026-07-06), #3063 (2026-07-07), #3066 (2026-07-13).
- **Feature PRs riding inside those promotes (~24, merged to develop):**
  - #3038, #3039 — ai-feature-work-v5 (2026-06-17)
  - #3040, #3041, #3042 — UI-polishes (2026-06-17/18)
  - #3044 — ai-summary-creation-gaps (2026-06-23)
  - #3045 — all-candidates-bulk-action (2026-06-25)
  - #3046 — billing-bonanza (2026-06-29)
  - #3047, #3048, #3049, #3050 — ai-billing-refinements (2026-06-30 – 07-01)
  - #3051 — ai-billing-refinements (2026-07-02) — **post-mapping-snapshot**
  - #3052–#3057, #3059, #3060, #3062, #3064, #3065 — qa-refinements (2026-07-02 – 07-13) — **all post-mapping-snapshot**
- **Full shipped-feature diff: `git diff a92bcdd25 production`** — 298 files, +28,946 / −280 (production at `f26d89cf4`, 2026-07-13).
- Drift vs the 2026-07-01 mapping snapshot (289 files, +27,925): ~9 files / ~1,000 lines net, but composed of 13 post-snapshot PRs (#3051 + the qa-refinements series) — documentation passes must absorb this drift PR by PR, not just by net line count.

## Contents

- `D2-scoring-pipeline-manifest.md` — stakeholder-grade walkthrough of the candidate scoring pipeline (plain language + technical appendix)
- `D3-feature-changelog.md` — public-facing "What's New: Plato AI" changelog
- `_manifest/extraction.md` — technical manifest, job-criteria extraction pipeline (per-job)
- `_manifest/scoring.md` — technical manifest, summary + scoring pipeline (per-candidate)
- `_map/` — 24 codebase-map files covering the full develop∆production delta (backend, frontend, config, regression intersections)
- `_pre-fable-snapshot/` — D1/D2/D3 versions from before the Fable review pass
- `CORRECTIONS.md` — owner-confirmed ground truth (three generate/run controls); copy also lives in the QA dir

## Review findings

D2 and D3 were adversarially reviewed alongside D1. Findings live in
`~/claude-hub/inflow-ats/qa-guides/plato-ai-manual-qa-2026-07-01/FABLE-REVIEW.md` (sections "D2" and "D3", plus adjudication of prior Opus findings). The review file stays in the QA dir because its bulk is D1.
