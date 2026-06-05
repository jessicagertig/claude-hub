# First-Touch Pipeline — Spec / Proposed Structure

Status: draft for build. Assembled from `approved-decisions.md` (the email-craft decisions), the live prototype prompts in `prompts/`, and the `thought-leadership-automation` reuse map. Source repo to build: `/Users/jessica/first-touch-pipeline`.

## 1. Purpose

Automatically turn a new Polymer signup into a reviewed, ready-to-send first-touch outreach email in Jessica's voice — with zero manual steps until the final human pick.

Two phases (both in scope here):
- **Phase 1 — Qualify:** decide whether a signup is worth pursuing at all (drop the chaff).
- **Phase 2 — Service:** research the prospect → find a genuinely interesting, verified detail → draft variations in Jessica's voice → review/score → surface for a human pick → create a Gmail draft.

## 2. Compute model (reused from thought-leadership-automation)

Same spine, standalone repo, no inflow-ats dependency:
- **GitHub Actions = compute/orchestration.** Cron-triggered ingest + per-lead servicing run as Actions executing Python that calls the Claude API.
- **Thin AWS SAM Lambda = Slack interactivity webhook only.** Receives the human's button click, verifies the Slack signature, and fires a `workflow_dispatch` to the relevant Action. (Lifted near-verbatim from `lambdas/slack_handler/handler.py`.)
- **State = git-committed files** (CSV/JSON in the repo). This is also what makes the pipeline durable (see §5). If volume outgrows git-commit-per-item, swap state to DynamoDB + SQS — noted as the one infra escape hatch, not built now.
- **Claude** via the `anthropic` SDK behind a `call_anthropic()` retry wrapper (lifted from `scripts/utils.py`).

## 3. Stages

### Stage A — Capture (durable; runs first; never drops a lead)
Cron Action (every few minutes) reads the "New Company" Slack channel via `conversations.history` (bot token, cursor pagination).
1. **Parse** each `[production]` `New Company` message into a lead: `company_name` (`Name:`), `recipient_name` + `email` (`Created By: <name> - <email>`), `careers_slug` (from the `jobs.polymer.co/<slug>` URL). Skip non-`[production]` messages.
2. **Dedup** against the leads store (by email + Slack message ts) so re-reads don't re-process.
3. **Qualify gate** (Phase 1):
   - Email-domain blocklist → automatic **out**: free/consumer mailboxes (gmail, yahoo, hotmail, outlook, icloud, aol, proton, gmx, …) and common/shared domains (`.edu` and similar). Only a company-specific domain passes. This is a deterministic rule check; no LLM, no research.
   - (Hook left for richer qualification later — e.g. checking `jobs.polymer.co/<slug>` for posted jobs — but the email-domain gate is the v1 filter.)
4. On **pass**: write the lead to the durable leads store (`state/leads.csv`, status `qualified`) AND post a **"good lead found"** notification to the designated Slack channel. This commit + notify is the durability boundary: once here, the lead survives any downstream failure.
5. On **fail**: record as `skipped` (with reason) and move on. No notification.

### Stage B — Service (decoupled; retriable; failure never loses the lead)
A separate Action processes `qualified` leads that are not yet `serviced`. Because the lead is already committed in Stage A, a crash here just leaves it `qualified` to be retried next run. Per-lead steps (the prototype loop, now codified in `prompts/`):
1. **Research** (`01-research.md`) — find the company website and read it; research the individual recipient. Domain branch: if the email is a company domain, start there; if it's personal (gmail/etc. that slipped past — shouldn't, but the careers-slug or company name is the fallback), locate the company by **name**.
2. **Extract** (`02-extract.md`) — surface only genuinely cool/clever/distinctive items (uniqueness test: "does every company of this kind do this, or is it unique to them?"); capture each as a verbatim source quote; flag sensitivity.
3. **Verify loop** (`03-verify.md`) — confirm each candidate is true AND current (first-party sources trusted; currency is the bar). Stale → targeted re-research of that item → re-verify; cap 5 loops/item, then surface as an issue. A stale fact doesn't block the email if another candidate verifies.
4. **Draft** (`04-draft.md`) — N variations (default 5), grounded in the 88-record reference library, built only on verified facts passed verbatim. Voice rules live in the prompt (lead with the company name; plain words, no parroting their copy; no flowery/verdict clichés; no reaction-framing; no fabricated bio; short).
5. **Review/score loop** (`05-adversarial-reviewer.md` + `06-revise.md`) — score each variation 1–10; < 8 → revise → re-score; repeat until ≥ 8 or 5 rounds, then surface what couldn't pass.
6. Mark lead `serviced`; hand the shipping variations to Stage C.

### Stage C — Select & Gmail draft
1. Post the shipping variations to the **same** Slack channel as Block Kit options (button per variation, each carrying `lead_id|variant_n`), each with its source link. (Reuses `slack_notify.py` + `slack_draft_done.py` patterns.)
2. Human clicks a variation → Slack interactivity → SAM Lambda → `workflow_dispatch` to a "create-draft" Action.
3. That Action calls the **Gmail API** `users.drafts.create` for `jessica@polymer.co`, building the full email from the fixed template (greeting, `Thanks for checking out Polymer! <compliment>`, closer, `Cheers,\nJessica`, two blank lines, `Jessica Gertig\nPolymer | polymer.co`), To = recipient. The draft lands in Jessica's Drafts to review and send.
4. Record `draft_created` (+ Gmail draft id) in the leads store; post a confirmation to Slack.

## 4. Email craft (authoritative: `approved-decisions.md`)
- Reference library: `reference-files/first_touch_library.jsonl` (88 records, 10 fields).
- Opener: automated flow uses "Thanks for checking out Polymer!" (signup = Stripe status nil).
- Compliment: one genuinely interesting verified detail, named-company-first, Jessica's voice (see `04-draft.md`).
- Closer (default): "Happy to answer any questions you might have about Polymer."
- Sign-off: `Cheers,\nJessica`. Signature (template, not a stored field): `Jessica Gertig` / `Polymer | polymer.co`, two blank lines above so Gmail grays it.

## 5. Durability / resilience
- **Capture before service** (§3A→§3B): the lead is committed + notified the instant it qualifies, so a Stage B error can't drop it.
- **Status machine in `state/leads.csv`**: `qualified → serviced → draft_created` (+ `skipped`, `error`). Stage B reprocesses anything stuck at `qualified`.
- **Idempotency**: dedup by email + Slack ts on ingest; re-clicking a Slack button is a no-op if a draft already exists (mirrors `mark_used.py`).
- **Retries**: `call_anthropic` (5 tries, backoff on 429/529); HTTP fetch + Slack read backoff helpers (lifted).
- **Failure surfacing**: `post_error_to_slack` to the channel; Actions have `if: failure()` notify steps.
- Per-item Action concurrency (`concurrency: group: ...-${lead_id}`, cancel-in-progress false) to serialize per lead.

## 6. Repo structure (proposed)
```
first-touch-pipeline/
  template.yaml                      # SAM: Slack interactivity Lambda + API GW (adapted from TL)
  samconfig.toml                     # stack first-touch-slack, profile polymer, us-east-1
  Makefile                           # deploy (sources .env), local run targets
  lambdas/slack_handler/handler.py   # signature verify + dispatch table + workflow_dispatch (lifted/adapted)
  scripts/
    utils.py                         # call_anthropic, slack post/read, git push, backoff (lifted)
    slack_leads_reader.py            # conversations.history reader + [production] New Company parser (adapted from slack_jobs_reader.py)
    qualify.py                       # email-domain blocklist gate (net-new)
    research.py                      # Stage B step 1 (Claude + web search)
    extract.py                       # step 2
    verify.py                        # step 3 (+ loop control)
    draft.py                         # step 4 (reads reference library)
    review.py                        # step 5 score
    revise.py                        # step 6 rewrite
    service_lead.py                  # orchestrates B steps with the verify + review/score loops
    slack_post_variations.py         # Stage C post (adapted from slack_notify.py/slack_draft_done.py)
    gmail_draft.py                    # users.drafts.create (net-new)
    prompts/                         # the 6 step prompts, copied from the design dir
    prompt_constants.py              # shared Polymer/email blocks
  reference-files/first_touch_library.jsonl   # the 88-record library
  state/leads.csv                    # durable lead status store (git-committed)
  .github/workflows/
    ingest_qualify.yml               # cron: Stage A (ingest → qualify → notify)
    service_lead.yml                 # Stage B (per-lead service; cron sweep of `qualified` + workflow_dispatch)
    create_draft.yml                 # Stage C: dispatched by Slack pick → Gmail draft
  .env.example                       # documents all keys
  README.md  CLAUDE.md
```

## 7. Reuse map (summary)
- **Lift:** SAM Slack-webhook Lambda + signature verify + dispatch table + modal/`views.open`; `call_anthropic` + retry/backoff helpers; Slack post + button-select + threaded-result patterns; run-dated/idempotent state pattern; deploy via `make deploy` sourcing `.env`.
- **Adapt:** `slack_jobs_reader.py` → `slack_leads_reader.py` (New Company parse, not jobs regex); dispatch-table prefixes (`ft_pick_…`); `generate_blog_long.py` research→write blueprint → our research→draft; catalogue CSV → `leads.csv` status store.
- **Net-new:** `qualify.py` gate; the closed verify-loop and review/score-loop orchestration; `gmail_draft.py` (Gmail API draft create).

## 8. Secrets & config (set at deploy via `.env` → SAM params / GH Actions secrets)
- `ANTHROPIC_API_KEY`
- `SLACK_BOT_TOKEN`, `SLACK_SIGNING_SECRET`, `SLACK_LEADS_CHANNEL_ID` (source New-Company channel), `SLACK_REVIEW_CHANNEL_ID` (the "good lead" + variations channel Jessica will provide)
- `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_TOKEN` (dispatch PAT)
- **Gmail API** for `jessica@polymer.co`: OAuth client id/secret + a stored refresh token (one-time consent), OR a Workspace service account with domain-wide delegation. Scope: `https://www.googleapis.com/auth/gmail.compose` (draft create). This is the one credential that needs Jessica; everything else can be written now.
- Claude model IDs: research/web-search lane = Sonnet; draft/review lane = a current Opus. (Pin exact IDs at build.)

## 9. Deployment
`make deploy` → `sam build && sam deploy --parameter-overrides …` (stack `first-touch-slack`, profile `polymer`, region `us-east-1`). GitHub Actions deploy by being committed.

## 10. What needs Jessica (cannot be done without her)
- The **Slack review channel id** (the "good lead" + variations destination).
- **Gmail API credentials** for `jessica@polymer.co` (OAuth consent / service-account) — required for draft creation and for end-to-end verification.
- Confirming the **GitHub repo** location (this repo) + the dispatch PAT.
- Final **deploy** + live **verification** (sending one through end to end).
Everything else — code, prompts, workflows, parsers, qualify gate, the Claude chain, Slack + Gmail clients — is written without her.
