# Nick's Convox Harness — Component Inventory

Read-only inventory of `/Users/jessica/Projects/claude-outputs` ("Nick's" harness). Every component named by its exact identifier. Source repos (`convox/convox`, `convox/rack`, `convox/console3`, etc.) live elsewhere under `~/convox/github-clones/`; this repo holds launch infrastructure, prompt templates, CLAUDE.md tiers, and per-work-item scratch output.

Launcher = root `Makefile`. Templates appended via `claude --effort max --append-system-prompt-file <template>`. `EFFORT ?= max`, `TEMPLATES := $(HOME)/claude-outputs/_templates`, `DATE := $(shell date +%Y-%m-%d)`.

---

## 1. Makefile targets — complete table

`--append-system-prompt-file` abbreviated as **ASPF**. Templates resolve to `$(TEMPLATES)/<name>` = `_templates/<name>`.

### Develop — V3
| Target | Required vars | Work dir created | ASPF template | Launch prompt gist |
|--------|---------------|------------------|---------------|--------------------|
| `v3-patch` | `SLUG` | `convox/v3/patches/$(DATE)-$(SLUG)` | none | Bare interactive session in patch dir |
| `v3-patch-full` | `SLUG` | `convox/v3/patches/$(DATE)-$(SLUG)` | `convox-v3-working-prompt.md` | Patch session with full V3 working context |
| `v3-feature-plan` | `NUM`,`SLUG` | `convox/v3/features/$(NUM)-$(SLUG)` (mkdir); cd `convox/v3/features` | `$(NUM)-$(SLUG)/prompt-plan.md` (per-feature, not in `_templates`) | Plan a feature; template is the per-feature planning prompt |
| `v3-feature-impl` | `NUM`,`SLUG` | (none; cd `convox/v3/features`) | `$(NUM)-$(SLUG)/prompt-implement.md` | Implement a feature from approved plan |
| `v3-analysis` | `SLUG` | `convox/v3/analysis/$(SLUG)` | none | Bare investigation session |

### Develop — V2
| Target | Required vars | Work dir | ASPF template | Gist |
|--------|---------------|----------|---------------|------|
| `v2-patch` | `SLUG` | `convox/v2/patches/$(SLUG)` (no date prefix) | none | Bare V2 patch session |
| `v2-patch-full` | `SLUG` | `convox/v2/patches/$(SLUG)` | `convox-v2-working-prompt.md` | V2 patch with full working context |
| `v2-analysis` | `SLUG` | `convox/v2/analysis/$(SLUG)` | none | Bare V2 investigation |

### Develop — Console
| Target | Required vars | Work dir | ASPF template | Gist |
|--------|---------------|----------|---------------|------|
| `console` | none | (cd `convox/console`) | none | Bare console3 session |
| `console-patch` | `SLUG` | `convox/console/patches/$(DATE)-$(SLUG)` | none | Bare console patch session |
| `console-analysis` | `SLUG` | `convox/console/analysis/$(SLUG)` | none | Bare console investigation |
| `mcp` | none | (cd `convox/mcp`) | none | Bare Convox MCP server session |

### Review (plan-review + adversarial PR review)
| Target | Required vars | Work dir | ASPF template | Gist |
|--------|---------------|----------|---------------|------|
| `plan-review` | `DIR` | (cd `$(DIR)`) | `plan-review-agent.md` | Fresh-context fact-check of a plan; reads all files in DIR, verifies claims vs codebase, writes `plan-review.md` w/ standalone reviewed plan |
| `v3-plan-review` | `SLUG` | resolves `*$(SLUG)*` under `convox/v3/patches` then calls `plan-review` | `plan-review-agent.md` | Slug-resolved V3 plan review (errors on 0 / multi match) |
| `v2-plan-review` | `SLUG` | resolves under `convox/v2/patches` | `plan-review-agent.md` | Slug-resolved V2 plan review |
| `console-plan-review` | `SLUG` | resolves under `convox/console/patches` | `plan-review-agent.md` | Slug-resolved console plan review |
| `v3-review` | `PR` | `convox/v3/reviews/pr-$(PR)` | `adversarial-review-agent.md` | "Last line of defense" before release staging; reads full diff/commits/comments, checks failure patterns, writes `review.md` PASS/BLOCK, "When in doubt, BLOCK" |
| `v2-review` | `PR` | `convox/v2/reviews/pr-$(PR)` | `adversarial-review-agent.md` | Same, V2 (`convox/rack#PR`) |
| `console-review` | `PR` | `convox/console/reviews/pr-$(PR)` | `adversarial-review-agent.md` | Same + console-specific prompt: GraphQL schema stability, resolver timeout, V2+V3 cross-version API, Redis, DynamoDB key safety |

### Stage Release (shell scripts, run as Nick — git write)
| Target | Required vars | Action | Script |
|--------|---------------|--------|--------|
| `v3-stage` | `VERSION`,`PRS` | Combined `release/$(VERSION)` branch + `[RELEASE]` PR | `v3-stage-release.sh` |
| `v2-stage` | `VERSION`,`PRS` | Same for `convox/rack` | `v2-stage-release.sh` |
| `console-stage` | `VERSION`,`PRS` | Same for `convox/console3` | `console3-stage-release.sh` |

### Test / RC / QC / QA — V3 (all ASPF `v3-release-testing.md`; QC/QA layer a second agent file on top)
| Target | Required vars | Work dir | ASPF | Gist (gating) |
|--------|---------------|----------|------|---------------|
| `v3-release` | `VERSION` (opt `PRS`,`RACK`) | `convox/v3/releases/$(VERSION)` | `v3-release-testing.md` | PRS set → PHASE 1 analyze PRs, propose numbered test order, present to Nick, do NOT execute, WAIT. No PRS → resume: re-read artifacts, present incomplete-task list, WAIT |
| `v3-release-rc` | `VERSION`,`RC`,`RACK` | `convox/v3/releases/$(VERSION)/combined-$(RC)` | `v3-release-testing.md` | PHASE 1 plan + write `scope.md` (karpenter/nvidia/arm/feature_test_suite/ang/helm_releases/internal_dns = yes\|no), WAIT; PHASE 2 execute Section 1→N saving `section-NN-*.md`; failure → `BLOCKING-FAILURE.md`, STOP, WAIT |
| `v3-release-qc` | `VERSION`,`RC`,`RACK` | `convox/v3/releases/$(VERSION)/combined-$(RC)` | `v3-release-testing.md` + reads `v3-release-qc-agent.md` | Pre-flight checks always-required section files + `scope.md` exist; refuses to dual-role (RC+QC on same fresh RC); "You are a DIFFERENT agent from the RC"; saves `qc-review.md` + `qc-test-results.md`; CONFIRM-PASS or BLOCK |
| `v3-release-qa` | `VERSION`,`RACK` | `convox/v3/releases/$(VERSION)/qa` | `v3-release-testing.md` + reads `v3-release-qa-agent.md` | PR-by-PR QA w/ simple apps; Phase 1 ANALYZE, WAIT for approval; resume-aware |
| `v3-release-qa-resume` | `VERSION`,`RACK` | (must exist) `.../qa` | `v3-release-testing.md` + `v3-release-qa-agent.md` | Follow Resume Semantics, STOP, present incomplete list, WAIT |
| `v3-qa` | `SLUG` (opt `RACK`) | `convox/v3/qa/$(DATE)-$(SLUG)` | `v3-release-testing.md` | Interactive (NOT regression): Phase 1 INTERVIEW → Phase 2 PLAN → Phase 3 EXECUTE → Phase 4 write `qa-results.md` |
| `v3-release-resume` | `VERSION` (opt `RACK`) | `convox/v3/releases/$(VERSION)` | `v3-release-testing.md` | Re-read artifacts, present incomplete-task list, WAIT |

### Test / RC / QC / QA — V2 (ASPF `v2-release-testing.md`; V2 versions are timestamps, `TAG`)
| Target | Required vars | Work dir | ASPF | Gist |
|--------|---------------|----------|------|------|
| `v2-release-rc` | `TAG`,`RACK` | `convox/v2/releases/$(TAG)` | `v2-release-testing.md` | PHASE 1 plan WAIT; PHASE 2 Section 1→N; V2 = AWS/CloudFormation/ECS, aws CLI is evidence only; failure → STOP/WAIT |
| `v2-release-qc` | `TAG`,`RACK` | `convox/v2/releases/$(TAG)` | `v2-release-testing.md` + reads `v2-release-qc-agent.md` | "A previous agent declared PASS"; DIFFERENT agent; `qc-review.md` + `qc-test-results.md`; CONFIRM-PASS or BLOCK |
| `v2-qa` | `SLUG` (opt `RACK`) | `convox/v2/qa/$(DATE)-$(SLUG)` | `v2-release-testing.md` | Interactive 4-phase, writes `qa-results.md` |
| `v2-release` | `TAG` (opt `PRS`,`RACK`) | `convox/v2/releases/$(TAG)` | `v2-release-testing.md` | PRS set → Section 1 start, plan, WAIT; else resume |
| `v2-release-resume` | `TAG` (opt `RACK`) | `convox/v2/releases/$(TAG)` | `v2-release-testing.md` | Resume, present incomplete list, WAIT |

### Post-release — Patch Notes + Docs
| Target | Required vars | Work dir | ASPF | Gist |
|--------|---------------|----------|------|------|
| `v3-patch-notes` | none | (cd `convox/v3/patch-notes`) | none | Bare patch-notes session |
| `v3-notes` | `VERSION`,`PR` | `convox/v3/patch-notes/$(VERSION)` | `v3-patch-notes-agent.md` | Reads `INSTRUCTIONS.md`, writes per-PR note + release note, Phase 1 analysis first |
| `v3-docs` | none | (cd `convox/v3/docs`) | none | Bare docs session |
| `v3-docs-update` | `VERSION`,`PR` | `convox/v3/docs/$(VERSION)` | `v3-docs-update-agent.md` | Reads `INSTRUCTIONS.md`; Phase 1 triage report → approval → edits docs repos |
| `v2-patch-notes` | none | (cd `convox/v2/patch-notes`) | none | Bare V2 patch-notes session |
| `v2-notes` | `VERSION`,`PR` | `convox/v2/patch-notes/$(VERSION)` | `v2-patch-notes-agent.md` | `convox/rack#PR`; reads `INSTRUCTIONS.md`; Phase 1 first |
| `v2-docs` | none | (cd `convox/v2/docs`) | none | Bare V2 docs session |
| `v2-docs-update` | `VERSION`,`PR` | `convox/v2/docs/$(VERSION)` | `v2-docs-update-agent.md` | Phase 1 triage → approval → edits |

### CX (customer issues)
| Target | Required vars | Work dir | ASPF | Gist |
|--------|---------------|----------|------|------|
| `cx` | `SLUG` | `convox/cx/$(SLUG)` | none | Bare CX session |
| `cx-deep` | `SLUG` | `convox/cx/$(SLUG)` | `cx-diagnostic-agent.md` | Full diagnostic methodology (Three Whys, disprove hypothesis) |
| `cx-resume` | `SLUG` | (must exist) `convox/cx/$(SLUG)` | none | Resume CX |

### Examples (convox-examples org)
| Target | Required vars | Work dir | ASPF | Gist |
|--------|---------------|----------|------|------|
| `examples-research` | none | `convox/examples/_research/$(DATE)` (cd `convox/examples`) | `examples-research-agent.md` | 5-phase landscape/gap research → ranked recs |
| `examples-decide` | none | (cd `convox/examples`) | `examples-arbiter-agent.md` | Score latest research, pick 1 app, update `_manifest.md` |
| `examples-build` | `SLUG` | `convox/examples/$(SLUG)/app` | `examples-builder-agent.md` | Design (STOP) → build → test on rack (STOP) → README → ship prep |
| `examples-test` | `SLUG` | (cd `convox/examples/$(SLUG)`) | `examples-builder-agent.md` | Test-only existing app, `test-results.md`, do NOT build |
| `examples-resume` | `SLUG` | (cd `convox/examples/$(SLUG)`) | none (`--resume`) | Resume examples session |

### Utility / Meta
| Target | Required vars | Action |
|--------|---------------|--------|
| `help` | none | Print all `## `-annotated targets |
| `tree` | none | `tree -L 3` of dir structure |
| `ls-patches` | none | List V3/V2/console patch dirs |
| `ls-features` | none | `cat convox/v3/features/_manifest.md` |
| `ls-cx` | none | List `convox/cx/*/` |
| `ls-releases` | none | List `convox/v3/releases/*/` |
| `resume` | `DIR` | Bare resume in any dir |
| `hdiu` | none | `cat _templates/hdiu.txt` (the lifecycle cheat-sheet) |
| `optimize` | none | Workspace optimization audit → `_optimization-report.md` (template archived to `_archive/optimize-workspace-2026-04-15.md`) |

Helper macro `resolve-slug` (Makefile lines 367-379): finds a single dir under a search root matching `*$(SLUG)*`, errors `ERROR_NO_MATCH` / `ERROR_MULTI_MATCH`. Used by the three `*-plan-review` targets.

---

## 2. Templates in `_templates/` — one subsection per file

24 entries: 21 `.md` agent/working/testing files + 3 `.sh` stage scripts.

### `convox-v3-working-prompt.md`
- **Loaded by:** `v3-patch-full`; base for `v3-feature-impl` per-feature prompts (per `convox/v3/features/CLAUDE.md`).
- **Role:** working-prompt (implementation context).
- **Headings:** File and Output Rules; Sub-Agent Permissions; Opportunistic Quick Adds; Feature Scoping Discipline (Find/Study Existing Parallel Patterns table; For Scheduling Features: Trace the Full Chain; Check Cross-Feature Interactions); Workflow (10 steps); Console3 Interaction Awareness; Rack Parameter Addition Guide (Downgrade Safety — CRITICAL).
- **Output artifacts:** `docs-note.md` (if user-facing), `patch-note.md` (single bullet `* [Description](PR-link-placeholder)`), `pr-description.md`, `commit-msg.txt` (≤7 words).
- **Discipline:** "If you cannot trace the full chain, stop and tell Nick"; quick-adds must be self-contained/trivial; downgrade-safety (console template must conditionally pass new TF vars by version).

### `convox-v2-working-prompt.md`
- **Loaded by:** `v2-patch-full`.
- **Role:** working-prompt.
- **Headings:** File and Output Rules; Workflow (10 steps); CloudFormation Deep Reference (Stack Hierarchy, Formation Template Mechanics, Rack Parameter Mechanics); ECS Task Definition Reference; DynamoDB Table Reference.
- **Output artifacts:** `docs-note.md`, `patch-note.md` (format per `../patch-notes/INSTRUCTIONS.md`), `pr-description.md`, `commit-msg.txt` (≤7 words).
- **Discipline:** identify gen1/gen2/both scope; no CF renames / no broken exports; summary must include "CF impact assessment, gen1/gen2 paths verified."

### `adversarial-review-agent.md`
- **Loaded by:** `v3-review`, `v2-review`, `console-review`.
- **Role:** adversarial-gate.
- **Headings:** Phase 1 Understand the Change; Phase 2 Known Failure Pattern Scan (V3 / V2 / Console pattern lists); Phase 3 Backward Compat & Downgrade Safety; Phase 4 Code-Level Scrutiny; Phase 5 What Could Go Wrong in Production; Phase 6 Testing Gap Analysis; Output: review.md; Verdict Rules.
- **Output artifact:** `review.md` — verdict **PASS / BLOCK**, Risk Level LOW/MEDIUM/HIGH/CRITICAL.
- **Discipline:** "find reasons to BLOCK, not to approve"; default skepticism, PR must earn PASS; "When in doubt, BLOCK. A false BLOCK costs a conversation. A false PASS costs a production incident"; per-pattern evidence with file:line, "N/A" only with one-line reason.

### `plan-review-agent.md`
- **Loaded by:** `plan-review`, `v3-plan-review`, `v2-plan-review`, `console-plan-review`.
- **Role:** adversarial-gate (fresh-context plan verifier).
- **Headings:** Step 0 Locate the Plan; Phase 1 Fact Check (+ Feasibility Checkpoint); Phase 2 Completeness; Phase 3 Safety Compliance; Phase 4 Scope and Ordering; Output: plan-review.md; Verdict Rules; Context Discipline.
- **Output artifact:** `plan-review.md` — verdict **APPROVED / NEEDS-REVISION**, plus a standalone "Reviewed Plan" section the patcher consumes directly.
- **Discipline:** fresh-context gate ("context was likely saturated"); "Do NOT read entire codebases — surgical reads"; circular-fix detection; **escalate-don't-rewrite** ("If fundamental … stop and flag to Nick — do not attempt to rewrite"); Context Discipline = no exploration, no redesign, no added suggestions.

### `cx-diagnostic-agent.md`
- **Loaded by:** `cx-deep`.
- **Role:** other (diagnostic methodology).
- **Headings:** Diagnostic Methodology (Three Whys; Disprove Your Hypothesis; Evidence Standards); Common Failure Pattern Library (Infra/State, Runtime/Workload, CLI/API tables V2|V3); Investigation Commands by Subsystem; Version Compatibility Checklist; Protocol.
- **Output artifacts:** (per `convox/cx/CLAUDE.md`) `diagnosis.md`, `blast-radius.md`, `workaround.md`, `recommendation.md`, `customer-response.md`; plus `commit-msg.txt`/`pr-description.md` if fix needed.
- **Discipline:** root cause to "level 3"; counts-as-evidence vs not (PR descriptions = intent not behavior); "Never propose infrastructure commands as fixes."

### `go-reviewer-agent.md`
- **Loaded by:** NO Makefile target references it (orphan/library template; invoked manually or as a sub-agent angle).
- **Role:** other (Go code-review checklist).
- **Headings:** Security Checks; Error Handling; Concurrency; Code Quality; Performance; Best Practices; Go-Specific Anti-Patterns; Review Output Format; Diagnostic Commands; Approval Criteria.
- **Output:** inline `[CRITICAL]`/`[HIGH]` findings; Approve / Warning / Block.

### `security-reviewer-agent.md`
- **Loaded by:** NO Makefile target (orphan/library; web-app/OWASP oriented, npm/JS). 
- **Role:** other (security review checklist).
- **Headings:** Core Responsibilities; Tools; OWASP Top 10 Analysis; Vulnerability Patterns to Detect; Security Review Report Format.
- **Output:** "Security Review Report" w/ Critical/High/Medium/Low counts + Risk Level + checklist.

### `examples-research-agent.md`
- **Loaded by:** `examples-research`.
- **Role:** working-prompt (research).
- **Headings:** Phase 1 Inventory; Phase 2 Competitive Analysis; Phase 3 Search Demand; Phase 4 Gap Analysis; Phase 5 Ranked Recommendations; Iteration Model; Output; Rules.
- **Output artifacts (dated `_research/YYYY-MM-DD/`):** `inventory.md`, `competitive-analysis.md`, `search-demand.md`, `gap-analysis.md`, `delta.md` (if prior cycle).
- **Discipline:** proxy-signals only, "do NOT fabricate search volume"; present top 5 to Nick before building.

### `examples-arbiter-agent.md`
- **Loaded by:** `examples-decide`.
- **Role:** other (decision/scoring).
- **Headings:** Inputs; Evaluation Process (Step 1 Filter / Step 2 Score / Step 3 Recommend / Step 4 Update Manifest); Rules.
- **Output:** `Arbiter Recommendation` block; updates `_manifest.md` `[ ]` queued w/ score + research date.

### `examples-builder-agent.md`
- **Loaded by:** `examples-build`, `examples-test`.
- **Role:** working-prompt (build/test).
- **Headings:** Phase 1 Design (STOP); Phase 2 Build; Phase 3 Test (MANDATORY, STOP); Phase 4 README; Phase 5 Ship Prep; Rules.
- **Output artifacts:** app in `app/`, `test-results.md` (raw unedited output), `README.md`, `pr-description.md`, `commit-msg.txt` (≤7 words); updates `_manifest.md`.
- **Discipline:** two STOPs (after design, after testing); "Test on Convox, not locally"; "Agents cheat — raw output proves they didn't"; no AI attribution in public-repo files; agent never runs git on convox-examples.

### `v3-patch-notes-agent.md`
- **Loaded by:** `v3-notes`.
- **Role:** notes/docs agent.
- **Headings:** Workflow (Phase 1 Analysis / Phase 2 Writing / Phase 3 Verification); Requirements Section — Versioning Formula; Key Rules.
- **Output artifacts:** `pr-{number}-{short-slug}.md` per PR; `release-note.md`; per `INSTRUCTIONS.md` in same dir.
- **Discipline:** Convox YAML-tag field names not K8s; minimum-version formula `3.(X-1).0`; no AI attribution; reword, don't copy PR titles.

### `v2-patch-notes-agent.md`
- **Loaded by:** `v2-notes`.
- **Role:** notes/docs agent.
- **Headings:** Workflow (3 phases); Requirements Section Format; Key Rules.
- **Output artifacts:** `patch-note-{PR_NUMBER}.md`, `release-note-{VERSION}.md`.
- **Discipline:** V2 = AWS/CF/ECS, both gen1+gen2; type prefix `Feature/Fix/Update/Security`; no AI attribution.

### `v3-docs-update-agent.md`
- **Loaded by:** `v3-docs-update`.
- **Role:** notes/docs agent.
- **Headings:** Workflow (Phase 1 Analysis STOP-for-approval / Phase 2 Execution); Source Priority; Repos You Edit / Read; Critical Rules; Work Directory; Page Placement Default; Multi-Topic PRs.
- **Output artifacts:** `analysis-report.md` (Phase 1, gated), `changes-manifest.md` (Phase 2); edits `~/convox/github-clones/convox/docs/` + `docs-v3/navigation.json`.
- **Discipline:** STOP + wait for approval before edits; never commit/push; codebase is highest source of truth over patch notes; no new hub-and-spoke.

### `v2-docs-update-agent.md`
- **Loaded by:** `v2-docs-update`.
- **Role:** notes/docs agent. Same shape as V3 variant.
- **Output artifacts:** `analysis-report.md`, `changes-manifest.md`; edits `~/convox/github-clones/docs/docs/` + `docs-v2/navigation.json`.
- **Discipline:** never touch `cmd/web/main.go` (flag new categories); gen1/gen2 always specified; CF/ECS not TF/K8s.

### `v3-release-testing.md` (53 KB — the master V3 testing guide)
- **Loaded by:** `v3-release`, `v3-release-rc`, `v3-release-qc`, `v3-release-qa`, `v3-release-qa-resume`, `v3-qa`, `v3-release-resume`.
- **Role:** release-testing.
- **Headings:** Core Principle (convox CLI is the gate); Evidence Format (per-section scaffold + minimum-Evidence-blocks table + happy-path rule + Forbidden phrases two-scope); STOP — Read These Rules (1 All Workloads Through Convox … 7 Create Purpose-Built Test Apps); Agent Testing Access (kubectl Usage Boundary); Resources Available; Feature Test Suite; How to Check If a Rack Update Is Complete; Testing Philosophy; What "Testing" Actually Means; PR-Specific Testing Patterns; **Combined RC: Full Regression Test Plan** (Sections 1 Baseline → 13, incl. §6 Karpenter, §7 Parameter Matrix, §7.5 Downgrade Fingertrap MANDATORY, §8 PR Deep Tests, §9 CLI Gauntlet, §10 Edge Cases).
- **Output artifacts:** `section-NN-<name>.md` per section (Save-as names enumerated, e.g. `section-01-baseline.md`, `section-07-5-downgrade-fingertrap.md`, `section-09-cli-gauntlet.md`), `test-results.md` (final verdict; §13 writes here, NOT `section-13-*.md`), `scope.md`, `BLOCKING-FAILURE.md`.
- **Discipline:** verdict-not-prose ("convox observing IS the test"); per-round/per-param/per-app Evidence blocks with minimum counts; happy-path-required; Forbidden phrases (anywhere-in-file: "proceeding anyway"/"documenting and continuing"/etc.; verdict-line-only: "appears to work"/"FAIL (transient)"/etc.); verdict must be `PASS|FAIL|BLOCK|INCOMPLETE|N/A — <reason>`; "If you feel pressure to hurry, you are about to cheat."

### `v2-release-testing.md` (18 KB)
- **Loaded by:** `v2-release-rc`, `v2-release-qc`, `v2-qa`, `v2-release`, `v2-release-resume`.
- **Role:** release-testing.
- **Headings:** Core Principle; Evidence Format; Resources; How to Check Rack Update Complete; What "Testing" Means; **V2 Full Regression Test Plan** (1 Baseline … 9 Backward-Compat Sweep MANDATORY for CF param adds, 10 Downgrade Safety MANDATORY-when-triggered, 11 Final Verdict); Testing Rules; Companion Skills.
- **Output artifacts:** `section-NN-*.md`, `test-results.md`, `BLOCKING-FAILURE.md`.
- **Discipline:** convox is gate / aws is evidence only; "aws describe-stacks returning instantly is the trap"; ONE param change at a time.

### `v3-release-qc-agent.md`
- **Loaded by:** `v3-release-qc` (read by agent on top of `v3-release-testing.md`).
- **Role:** adversarial-gate (QC re-test).
- **Headings:** Mission; The pass/fail gate; Audit checklist (10 items incl. existence-check filename table); Re-run don't just review; Wait discipline; Accuracy over speed; On any failure; Deliverables.
- **Output artifacts:** `qc-review.md`, `qc-test-results.md` (re-runs tagged `[NEW]`/`[DEEPER]`).
- **Discipline:** "**You are a DIFFERENT agent from the RC**" (cites `ai-regression-testing` ECC skill — same-model self-review blind spots); existence-check table = silent skip → BLOCK; "Re-run, don't just review"; verdict CONFIRM-PASS or BLOCK, "No halfway"; priority rule: this file beats the testing template on conflict.

### `v2-release-qc-agent.md`
- **Loaded by:** `v2-release-qc`.
- **Role:** adversarial-gate. Same shape; 9-item audit checklist; explicit "Inherited layers you MUST re-read."
- **Output:** `qc-review.md`, `qc-test-results.md`; CONFIRM-PASS or BLOCK.

### `v3-release-qa-agent.md`
- **Loaded by:** `v3-release-qa`, `v3-release-qa-resume`.
- **Role:** release-testing (PR-by-PR targeted QA, lighter than RC).
- **Headings:** Scope; pass/fail gate; Understanding the release branch; The QA process (Phase 1 ANALYZE-WAIT … Phase 5 VERDICT); Rules; Resume semantics.
- **Output artifacts:** `pr-NNN-results.md` per PR (saved immediately), `qa-results.md` final.
- **Discipline:** simple purpose-built apps, no feature-test-suite; GPU prohibition; one PR at a time; save after every PR; STOP-on-failure.

### `v3-stage-release.sh`
- **Loaded by:** `v3-stage` (executed, not ASPF).
- **Role:** other (git automation, run as Nick). Creates `release/$(VERSION)` from master, merges each PR branch, runs `go build ./...` + `go vet ./...` build-verification gate, prompts before push, opens `[RELEASE] VERSION` PR with `closes #NNN` per PR. (Note: line 154 has a stray duplicate `done"` — cosmetic.)

### `v2-stage-release.sh`
- **Loaded by:** `v2-stage`. V2 analog for `convox/rack` (not GPG-signed tags per releases CLAUDE.md). [Not read in full; role confirmed by Makefile + hdiu.]

### `console3-stage-release.sh`
- **Loaded by:** `console-stage`. Console3 analog for `convox/console3`. [Not read in full.]

### `hdiu.txt`
- **Loaded by:** `hdiu` (`cat`).
- **Role:** other (human lifecycle cheat-sheet). Sections: V3 (Develop → Review → Stage Release → Test PRs Individually → RC Regression → QC → PR-by-PR QA → QA interactive → Final Release → Post-Release → Resume → Squash), V2 (parallel), Console, Cross-Cutting, Utility. **Authoritative source for the intended end-to-end sequence** (Section 7 below).

---

## 3. Per-work-item artifact conventions

Observed across `convox/v3/patches/COMPLETED/*`, `convox/console/ui-ux-initiative/phase-*`, `convox/v3/releases/3.24.2/*`, and `convox/gpu-ai-inference-vertical/_archive/**`.

### Recurring patch artifact filenames (and roles)
- `commit-msg.txt` — ≤7-word commit message (universal).
- `pr-description.md` — GitHub PR body (universal).
- `patch-note.md` — single-bullet customer note `* [Description](PR-link-placeholder)`.
- `docs-note.md` — handoff to the docs-updater agent (standalone).
- `PLAN.md` / `plan.md` — implementation plan (case varies by dir).
- `SPEC.md` / `design-spec.md` — design spec (brainstorming output, precedes PLAN).
- `implementation-plan.md` — alternate plan filename (e.g. `mask-convox-env-secrets`).
- `plan-v1-archived.md`, `plan-v2-archived.md` — superseded plan drafts kept for audit.
- `HANDOFF.md` — cross-session state handoff (auth inventory of what landed).
- `BLOCKING-FAILURE.md` — STOP-and-wait failure record (fields: command / expected+citation / actual / assessment).
- `PHASE1-DELIVERED.md`, `STATUS-*.md` — phase/status checkpoints.
- `reviewer-response.md` — response to received review feedback.
- `AGENT-FAILURES.md` — referenced throughout release Makefile prompts as a resume input (record of agent self-failures); not present in every dir but a first-class convention.

### Review artifacts — single-pass (patches)
- `PASS-1-findings.md`, `PASS-2-findings.md` — double-pass review for bundled/feeder PRs (per `convox/v3/patches/CLAUDE.md`): Pass-1 STATUS = READY|REBASE_REQUIRED|BLOCKED|SUPERSEDED + rebase plan; Pass-2 verifies each Pass-1 finding resolved then re-runs full checklist; **exit = STATUS==READY in both passes AND no unresolved Pass-1 findings**; third pass if Pass-2 surfaces FINDING-UNRESOLVED.
- `plan-review.md` — output of the plan-review-agent.

### Multi-round / multi-angle adversarial review structure (the spine of large features)
Seen in `gpu-ai-inference-vertical/_archive/.../2026-04-30-prometheus-unification/` and `phase-h-rounds/`:
- `spec-reviews/RN-<angle>.md` and `plan-reviews/RN-<angle>.md` — one file per round N per **angle**. Angles named explicitly, e.g.: `data-flow`, `helm-chart-conflict`, `tf-reconciler`, `console3-mutation`, `conventions`, `docs-gui-accuracy`, `test-gates`, `backcompat-firewall` (spec side); `source-grounding`, `code-completeness`, `sequencing`, `risk-mitigation`, `test-coverage`, `spec-coverage`, `handoff-readiness`, `task-atomicity` (plan side).
- `RN-CONSOLIDATED.md` per round — merges all angles, headline BLOCKER/HIGH counts table (R(N-1)→R(N)), single verdict BLOCK/PASS.
- `phase-h-rounds/round-NN/NN-<angle>.md` — numbered angle files per round (e.g. `round-13/01-wire-format-parity.md` … `09-verdict-regression-final.md` … `10-doc-crosslinks-examples.md`).
- `ROUND-LOG.md` — appended per-round log (findings F1…Fn with `[Angle, SEVERITY]` tags, amendments applied in-line to the plan, pass status).

### The two-clean rule (confirmed, explicit)
The iterative adversarial review loop terminates on **TWO CONSECUTIVE FULL PASSES** = two rounds in a row with **ZERO new BLOCKER or HIGH findings AND ZERO new plan amendments**. A PASS-with-amendment resets the counter. Hard cap **5 rounds** per iteration → escalate to Nick; a fresh iteration re-starts the round counter. Source: `gpu-ai-inference-vertical/_archive/r1-shipped/R1-ITERATIVE-REVIEW-PROMPT.md` and `ROUND-LOG.md` ("TWO CONSECUTIVE FULL PASSES ACHIEVED"). The prometheus PLAN.md header records "8 rounds × 10 angles = 80 reviews. R7 + R8 both 0 BLOCKER + 0 HIGH (two consecutive PASS — converged)." All amendments are applied **in-line to the plan text** (no code), and findings that are precision/file:line drift are amended rather than triggering redesign.

### Release directory layout (per `convox/v3/releases/3.24.2/`)
`plan.md`, `phase1-summary.md`, `preflight-inventory.md`, `retrospective.md`, per-PR dirs `pr-NNN-slug/test-results.md`, combined-RC dirs `combined-rc1/`…`combined-rc9/` (each with `section-NN-*.md`, `test-results.md`, `scope.md`, `qc-review.md`, `qc-test-results.md`), plus topical dirs like `karpenter-stress-test/`.

---

## 4. Workflow-tier CLAUDE.md files (under `convox/`)

Tier order: root → `convox/CLAUDE.md` → engine (`convox/v3`, `convox/v2`, `convox/console`) → workflow subdir.

- **`convox/CLAUDE.md`** — Shared rules for ALL Convox work. Git/commit rules (NEVER write-git; produce `commit-msg.txt` ≤7w + `pr-description.md`); No AI Attribution; Public-Repo Image; Backward Compatibility ("No customer left behind"); **kubectl/aws/terraform CLI Boundary** (forbidden write ops; permitted troubleshooting escapes); Repository Map; Cross-System Dependency Guide (→ `CONVOX-ECOSYSTEM-GUIDE.md`); API/SDK Safety; **Known Failure Patterns** (TF State Fingertrap V3 incl. `reconcileVarsWithModule` at `pkg/rack/terraform.go:440-482`; CF Stack Deadlock V2; Rack Update Lifecycle; **How to Wait — authoritative polling-cadence table**; GHA monitoring; **Failure Handling — STOP/VERIFY/PRESENT/WAIT** + `BLOCKING-FAILURE.md` schema + Forbidden phrases); Automated Safety Checks (`make lint-new`/`lint-tf`/`lint-security`); Shared Completion Checklist.
- **`convox/v3/CLAUDE.md`** — V3 engine facts. convox-only QA gate; never `terraform` against rack state; K8s-churn slow-op cadence; **GPU Test-Fleet Prohibition** (g4dn/g5/p3/p4/p5/inf1/inf2/trn1); Architecture/providers; Provider isolation; Terraform Safety (no rename w/o `moved`, no output removal); Rack Param Downgrade Safety (6 steps incl. console template version-gating); kubectl detailed allowed/forbidden; High-Conflict Files; TF validation; V3 Completion Checklist.
- **`convox/v2/CLAUDE.md`** — V2 engine facts. convox-only gate / aws evidence; no tight `describe-stacks` loops; AWS/ECS/CF architecture; CloudFormation Safety (no logical-ID rename, no Output removal — `Fn::ImportValue` chain); ECS family naming `{rack}-{app}-{service}`; DynamoDB key safety; Generation Compatibility (gen1 `pkg/manifest1/` vs gen2 `pkg/manifest/`); What NOT To Do; V2 Completion Checklist.
- **`convox/console/CLAUDE.md`** — Console3 engine facts. Architecture (Go GraphQL + Vue3 + DynamoDB + Redis); Data Flow; Cross-Engine (talks to BOTH V2+V3 racks); Console safety (GraphQL schema stability, resolver timeout, Redis cache keys, DynamoDB keys, frontend bundle/subscription cleanup); Known Failure Patterns (Resolver Timeout Cascade `unk-rack-fix`, Cross-Version API Mismatch, Redis Cache Poisoning, GraphQL Schema Break); Automated Checks; High-Conflict Files; Console Completion Checklist.
- **`convox/cx/CLAUDE.md`** — CX methodology ONLY. 5-phase protocol (Triage / Evidence / Hypothesis-disprove / Blast Radius / Output); output-file table (`diagnosis.md`, `blast-radius.md`, `workaround.md`, `recommendation.md`, `customer-response.md`); "Never propose raw infra commands as fixes."
- **`convox/v3/patches/CLAUDE.md`** — V3 patch methodology. Dated dir naming; Superpowers-driven workflow (9 steps); Quick Adds; **Bundled Release PRs** (per-feeder review subdirs w/ `PASS-1/PASS-2-findings.md`; double-pass exit criteria; older-PR review lens; Release PR assembly artifacts `release-pr-body.md`/`cherry-pick-plan.md`/`commit-msg.txt`/`rollback-plan.md`; git-piloting reminder).
- **`convox/v3/features/CLAUDE.md`** — V3 feature-queue methodology. `_manifest.md` sequence; `NN-kebab-slug/` dirs; `prompt-plan.md`/`prompt-implement.md`; Planning→Review→Implementation phases; status flags `[ ]→[P]→[R]→[I]→[D]`; base prompt = `convox-v3-working-prompt.md`.
- **`convox/v2/patches/CLAUDE.md`** — V2 patch methodology. `kebab-slug/` dirs; Superpowers workflow (9 steps); gen1/gen2 scope; CloudFormation Validation documentation requirements.
- **`convox/console/patches/CLAUDE.md`** — Console patch methodology. `YYYY-MM-DD-kebab-slug/`; 9-step workflow; V2+V3 contract checking; "a resolver change can break 4 ways."
- **`convox/v3/releases/CLAUDE.md`** — V3 release lifecycle. make-release flow (GPG-signed tag); Handoff Boundary (Nick=git/GPG, Agent=monitor+convox+test); Phase 1 Individual PR Testing / Phase 2 Stage+Combined RC / Phase 3 Final Release; per-release dir structure; Rules (never git-write, never destroy rack, never kubectl-create workloads, no GHA sleep-loops).
- **`convox/v2/releases/CLAUDE.md`** — V2 release lifecycle. Two-step build-then-publish gate; Handoff Boundary; points to `_templates/v2-release-testing.md` for methodology.
- **`convox/v3/reviews/CLAUDE.md`** / **`convox/v2/reviews/CLAUDE.md`** — adversarial review workflow; `pr-{number}/review.md` convention; "Not a code style review."
- **`convox/console/reviews/CLAUDE.md`** — console adversarial review; `pr-{number}/review.md`; cross-engine (V2+V3) focus; uses shared adversarial template.
- **`convox/v3/patch-notes/CLAUDE.md`** / **`convox/v2/patch-notes/CLAUDE.md`** — patch-notes workflow; points to local `INSTRUCTIONS.md` for format; gh fetch commands; per-PR note vs per-tag release note.
- **`convox/v3/docs/CLAUDE.md`** / **`convox/v2/docs/CLAUDE.md`** — docs workflow; source-of-truth = codebase not existing docs; style rules (no filler, product terms capitalized); dated `YYYY-MM-DD-slug/` + `docs-note.md`.
- **`convox/examples/CLAUDE.md`** — examples project (ICP definition + README standards; referenced by the three examples agents). [Not read in full; role confirmed by agent templates.]

---

## 5. Where superpowers skills plug in

- **`brainstorming` / `writing-plans`** — SPEC then PLAN authoring. `convox/v3/patches/CLAUDE.md:11` and `convox/v2/patches/CLAUDE.md:11`: "Use the Superpowers plugin (`/superpowers`) … Use Superpowers brainstorm if the scope is unclear." `convox/v3/features/CLAUDE.md:4`: "Use the Superpowers plugin (`/superpowers`) for all feature work."
- **`subagent-driven-development` / `executing-plans`** — invoked at execution time, cited in the **PLAN.md header**: `gpu-ai-inference-vertical/_archive/.../2026-04-30-prometheus-unification/PLAN.md:3` — "> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`." Same skills named in `convox/v3/patches/CLAUDE.md` Bundled-Release section and `R1-EXECUTION-PROMPT.md`.
- **`verification-before-completion`** — cited in `_templates/v3-release-testing.md:69` and `convox/CLAUDE.md:262` Failure Handling "Companion skills" ("evidence before assertions, always").
- **`systematic-debugging`** — `_templates/v3-release-testing.md:70` and `convox/CLAUDE.md:263` as the methodology for the VERIFY step of Failure Handling.
- **ECC `ai-regression-testing`** — cited in `_templates/v3-release-qc-agent.md:6` and `v2-release-qc-agent.md:13` to justify "You are a DIFFERENT agent from the RC" (same-model self-review blind spot). Also `_templates/v3-release-testing.md:71`.
- **ECC `verification-loop`** — `_templates/v3-release-testing.md:72` (phased STOP-on-fail discipline).
- **`v2-release-testing.md`** has a "Companion Skills (for agents that support Skill invocation)" heading (line ~275) listing the same set.
- **Custom adversarial layer** (NOT a superpowers skill): the multi-round/multi-angle review loop with the two-consecutive-clean-pass rule is encoded in the work-item review prompts (`R1-ITERATIVE-REVIEW-PROMPT.md`) and the `adversarial-review-agent.md` / `plan-review-agent.md` / `v3-release-qc-agent.md` templates — layered on top of the superpowers methodology spine.

Note: superpowers skills are referenced mainly via CLAUDE.md instructions and work-item PLAN.md headers, not embedded in the `_templates/` agent files themselves (those reference ECC/superpowers only in the "Companion skills" footers).

---

## 6. INSTRUCTIONS.md pattern

INSTRUCTIONS.md files found (non-archive):
- `convox/v3/patch-notes/INSTRUCTIONS.md` — V3 patch-note + release-note format spec, dir structure, versioning formula, verification checklist. Consumed by `v3-patch-notes-agent.md`.
- `convox/v2/patch-notes/INSTRUCTIONS.md` — V2 analog. Consumed by `v2-patch-notes-agent.md` and referenced by `convox-v2-working-prompt.md` step 7.
- `convox/v3/docs/INSTRUCTIONS.md` — V3 docs style guide / conventions / triage rules / analysis-report template. Consumed by `v3-docs-update-agent.md`.
- `convox/v2/docs/INSTRUCTIONS.md` — V2 analog. Consumed by `v2-docs-update-agent.md`.
- `convox/v3/features/ARCHIVE/10-cli-config-and-param-validation/INSTRUCTIONS.md` — a per-feature instruction file (archived feature).
- `convox/v3/patches/COMPLETED/2026-04-09-empty-string-json-param-desync/INSTRUCTIONS.md` — a per-work-item instruction file (one-off).

**The agent-template-vs-INSTRUCTIONS split** (confirmed against `docs/superpowers/specs/2026-04-06-docs-updater-design.md`, "Make Target Structure" section): the design doc states the split explicitly — the agent prompt template in `_templates/` (e.g. `v3-docs-update-agent.md`) holds **workflow phases, rules, source-priority hierarchy, repo paths, can/cannot-modify** and is loaded via ASPF; the co-located `INSTRUCTIONS.md` (e.g. `convox/v3/docs/INSTRUCTIONS.md`) holds the **reusable reference content**: full style guide (frontmatter, structure, naming, markdown conventions), PR triage rules with examples, page-placement heuristics, navigation update rules, cross-linking strategy, analysis-report template, safety guardrails. Rationale quoted in the design doc: "This separation keeps the agent prompt focused on workflow while INSTRUCTIONS.md is the reusable reference document." The make targets pass the template via ASPF and instruct the agent in the launch prompt to "Read INSTRUCTIONS.md" — confirmed in the `v3-docs-update`, `v2-docs-update`, `v3-notes`, `v2-notes` launch prompts. The patch-notes INSTRUCTIONS files follow the same pattern (format spec lives in INSTRUCTIONS, workflow in the `*-patch-notes-agent.md` template).

---

## 7. End-to-end feature/patch lifecycle (concrete sequence)

Traced from `_templates/hdiu.txt` (intended) and verified against real dirs (`convox/v3/releases/3.24.2/`, `gpu-ai-inference-vertical/`, `convox/v3/patches/COMPLETED/*`). A V3 patch/feature:

1. **Develop** — `make v3-patch SLUG=…` (bare) or `make v3-patch-full SLUG=…` (ASPF `convox-v3-working-prompt.md`); feature path: `make v3-feature-plan NUM=NN SLUG=…` (ASPF per-feature `prompt-plan.md`) then `make v3-feature-impl …` (ASPF `prompt-implement.md`). Skills: `superpowers:brainstorming` → `writing-plans`. Artifacts: `SPEC.md`/`design-spec.md`, then `PLAN.md`/`plan.md`.
2. **Plan review** — `make v3-plan-review SLUG=…` (ASPF `plan-review-agent.md`). For large features: the iterative multi-round/multi-angle loop → `spec-reviews/RN-<angle>.md`, `plan-reviews/RN-<angle>.md`, `RN-CONSOLIDATED.md`, `ROUND-LOG.md`, driven to **two consecutive clean passes** (cap 5/iteration). Output: `plan-review.md` APPROVED/NEEDS-REVISION with standalone reviewed plan.
3. **Implement** — execution via `superpowers:subagent-driven-development` / `executing-plans` (named in PLAN.md header). Following `convox-v3-working-prompt.md` step list. Artifacts on completion: code (left unstaged), `docs-note.md`, `patch-note.md`, `pr-description.md`, `commit-msg.txt` (≤7 words). Nick pilots all git.
4. **Adversarial PR review** — `make v3-review PR=NNN` (ASPF `adversarial-review-agent.md`) → `convox/v3/reviews/pr-NNN/review.md` PASS/BLOCK, "When in doubt BLOCK." (Bundled feeder PRs use the double-pass `PASS-1/PASS-2-findings.md` flow from `convox/v3/patches/CLAUDE.md`.)
5. **Stage release** — `make v3-stage VERSION=X.Y.Z PRS="…"` runs `v3-stage-release.sh` (as Nick): branch `release/X.Y.Z`, merge PR branches, `go build`/`go vet` gate, `[RELEASE] X.Y.Z` PR with `closes #NNN`.
6. **Individual PR testing** — `make v3-release VERSION=X.Y.Z PRS="…" RACK=…` (ASPF `v3-release-testing.md`): Phase 1 plan, WAIT; per-PR `pr-NNN-slug/test-results.md`.
7. **Combined RC regression** — `make v3-release-rc VERSION=X.Y.Z RC=rc1 RACK=…`: Phase 1 writes `scope.md`, WAIT; Phase 2 writes `section-NN-*.md` + `test-results.md`; failure → `BLOCKING-FAILURE.md`.
8. **QC (different agent)** — `make v3-release-qc …` (ASPF `v3-release-testing.md` + reads `v3-release-qc-agent.md`): re-run skeptical sections, existence-check section files, → `qc-review.md` + `qc-test-results.md`, CONFIRM-PASS/BLOCK. Optional lighter path: `make v3-release-qa …` → `pr-NNN-results.md` + `qa-results.md`.
9. **Final release** — Nick merges `[RELEASE]` PR (auto-closes sub-PRs), tags from master, marks GitHub Release "Latest", `git push origin master:staging` (steps printed in hdiu / releases CLAUDE.md).
10. **Post-release notes** — `make v3-notes VERSION=X.Y.Z PR=NNN` (ASPF `v3-patch-notes-agent.md`, reads patch-notes `INSTRUCTIONS.md`) → `pr-{n}-{slug}.md` + `release-note.md`.
11. **Post-release docs** — `make v3-docs-update VERSION=X.Y.Z PR=NNN` (ASPF `v3-docs-update-agent.md`, reads docs `INSTRUCTIONS.md`) → `analysis-report.md` (gated) → edits to `docs/` + `navigation.json`, `changes-manifest.md`.

(The V2 path is the structural twin with `TAG` timestamps, `convox/rack`, `v2-*` targets, and the two-step build-then-publish gate.)

---

## Ambiguities / gaps explicitly noted
- `go-reviewer-agent.md` and `security-reviewer-agent.md` have **no Makefile target loading them** — they are library/manual sub-agent templates (security one is npm/OWASP-oriented, an outlier vs the Go/TF platform). Could not find a launcher; likely invoked ad hoc or as dispatched review angles.
- `v2-stage-release.sh` and `console3-stage-release.sh` were not read in full (confirmed only via Makefile + hdiu as V2/console analogs of `v3-stage-release.sh`).
- `convox/examples/CLAUDE.md` not read in full (role confirmed via the three examples agent templates that reference its ICP/README sections).
- `_manifest.md` (features queue, examples queue) referenced by targets/agents but contents not enumerated here.
- `AGENT-FAILURES.md` is referenced as a resume input across release prompts but was not present in the specific dirs sampled; it is a defined convention, used when an RC/QA agent records its own failures.
- The two-clean rule and multi-angle loop live in **work-item review prompts** (e.g. `R1-ITERATIVE-REVIEW-PROMPT.md`), not in a `_templates/` file — there is no generic "iterative-review" template in `_templates/`; it is hand-authored per large feature.
