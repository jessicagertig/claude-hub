# Handoff — AI Change Spec (Phase 1)

Branch: `feature-ai-credits-summaries-scoring`. Goal: Phase 1 of `docs/ai-change-spec-session-directions.md` — turn the 38 prioritized items in `docs/ai-jessicas-notes-on-changes.md` into a change-only spec, working in priority order, one note at a time.

## Artifacts (all under `~/claude-hub/inflow-ats/_in-progress/ai-change-spec/`)
- `approved-decisions.md` — the authoritative record. The change spec is assembled ONLY from this file. Each note's decision is written here after Jessica explicitly confirms it.
- `investigations/` — per-note ground-truth investigation files (note-01 … note-13).
- `scope-and-outline.md` — non-authoritative scope reference.
- `stripe-price-fetch-commands.txt` — Rails console / Stripe CLI commands to list the AI credit pack prices.

## Status — DONE (written to approved-decisions.md)
- **#1** is_admin? mailer fix + first mailer spec (+ `create_credit_test_organization_user` helper).
- **#2** `AiResumeStructuredData` full backend-shape mirror (remove phantom fields; add fields; evaluative fields optional `?`).
- **#3** `ApplyAiCreditRefund` selects the most recent purchase-credit row (`.last`), not `.first`.
- **#4** AI credit top-up: enable `invoice_creation`, grant on `invoice.paid` keyed on `ai_credit_pack_top_up` invoice metadata; remove the `mode == 'payment'` credit branch.
- **#5** Rename the `auto_generate_ai_summaries_setting` enum + org setting + cascade method (`should_auto_generate_ai_summaries?`); in-place migration edits.
- **#6A** Move `AiCreditPacks` onto `OrganizationAiCreditPurchase`; **#6B** delete `RoleCategoryGroups`.
- **#7** verified no-change (cancellation doesn't refund).
- **#8** Gate daily credits behind Flipper flag `:AI_DAILY_CREDITS` in `ResetDailyAiCredits`.
- **#9A** Restructure AI-credit controllers/policies/hooks to model-aligned (`OrganizationAiCreditBalanceController` + `OrganizationAiCreditPurchasesController`, aliased routes, policy renames, consolidated `useOrganizationAiCreditPurchase.ts`, `subscribe`→`checkout`, `#show` uses `render_one`). **Resolves #11** (keep both serializers).
- **#9B-1** correct the pack lookup keys/credits to the four real packs.
- **#9B-2** add `#prices` (Stripe-only) + `aiCreditPrices` transform + `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` in `planHelpers.ts` (CODE EXCEPTION — Jessica approved code in the decisions doc here).
- **#9B-3** stop the AI-credit subscription overriding the main plan: `Stripe::SubscriptionStatusChecker.valid_base_plan?` + `sync_with_stripe` fetches all subs (`auto_paging_each`) and selects the first base-plan sub (active/trialing, else any status, else nil).
- **#9B-5** record the credit-pack subscription at checkout (mirror the plan handshake on `OrganizationAiCreditPurchase`): create at checkout, link `stripe_subscription_id` on `checkout.session.completed` (metadata `== 'true'` branch), grant on `invoice.paid`; remove the `else`/`apply_subscription` create path.
- **#9B-4** was MOVED into note #16 (billing UI must render active AI credits).
- **#10** moot (technical-map doc, rewritten after our changes regardless).
- **#12** Rename `ConsumeAiCredits` to `CreateAiCreditBalanceTransaction` (file, class, all call sites, specs, logger strings, comments).
- **#25** (out of order, prerequisite for #13) Fix dead `retry_on` in `BulkGenerateAiSummariesJob`: swap declaration order (`discard_on StandardError` first, `retry_on CustomErrorAiSummary` second). TDD spec required — spec must fail before the fix, pass after with no spec modifications.
- **#13** (depends on #25) Add `BulkJobApplicationAiSummaryResultMailer` with `complete` and `failed` methods. Two Mailgun templates (`user-bulk-ai-summary-complete`, `user-bulk-ai-summary-failed`). Two helper methods on the job (`notify_complete`, `notify_failure`). Failure condition: succeeded == 0 AND failed > 0; all other cases use complete. `notify_failure` called from `discard_on` block, `retry_on` exhaustion block, and `on_complete` when failure condition met. Frontend: new WebSocket failure action + payload type.
- **#14** Table review: keep both `OrganizationAiCreditPurchase` and `AiApiRequest` as-is. Keep the three aggregate methods on `AiJobApplicationSummary` (`total_cost`, `total_input_tokens`, `total_output_tokens`) for Rails console use. Full reasoning documented in the decision.
- **#15** Jessica said was irrelevant, removed.
- **#19** Create `lib/tasks/AI_TASKS_README.md` documenting AI rake tasks: recurring (daily Heroku Scheduler: `reset_daily`, `process_overdue_resets`, `reconcile`, `cleanup_orphaned_bulk_claims`) and on-demand (`grant`, `show`, `bulk_extract`, `relevance_benchmark`, `comparison_benchmark`).
- **#20 + #38** (consolidated) Rename template references in `AiCreditNotificationMailer` to `user-ai-credit-balance-low` and `user-ai-credit-balance-zero`. Four Mailgun templates to create before deploy (early enough to test): `user-ai-credit-balance-low`, `user-ai-credit-balance-zero`, `user-bulk-ai-summary-complete`, `user-bulk-ai-summary-failed`.
- **#21** No change — when auto-generate is on, the org has already decided to consume credits automatically; modal would contradict the setting. Resume re-uploads are low-incidence (managed by hiring team, not candidate).
- **#23** Already covered by #19 (`ai_credits:reconcile` listed as daily Heroku Scheduler task).
- **#24** No change to `job_iteration_max_job_runtime` (stays 10 minutes). Job-iteration gem handles re-enqueueing gracefully — batch resumes from cursor, no work lost. Shorter runtimes preferred since the job runs on the `default` queue.
- **#26** Remove `prompt_text` column from `AiJobApplicationSummary` entirely. Roll back migration `20260311120000_create_ai_job_application_summaries`, edit in place to remove the column, re-migrate. Remove three write sites in `generate.rb` and `ai_bulk_extract.rake`. Per-call prompt data already stored in `AiApiRequest.prompt_text`.
- **#27** Remove `period_overdue?`, `OVERDUE_RESET_GRACE`, and `reset_ai_credits_if_overdue` from `OrganizationAiCreditBalance`. Rename `process_overdue_ai_credit_resets` to `process_ai_credit_resets` on `Organization`. Replace call to `reset_ai_credits_if_overdue` with `org.organization_ai_credit_balance.reset_ai_credits`.

## Deferred to end — UI notes
- **#16** and **#17** moved to last by Jessica's decision.

## Remaining — NOT started: #18 (then #16, #17 at end)

**#28 through #37 are now all decided** (written to approved-decisions.md).

**#18** (Trial-to-Paid Credit Transition) was skipped — large note, Jessica was not ready to tackle it. Investigation was started but not completed. Come back to it when Jessica is ready.

- Large (real design): #18.
- UI (deferred to end): #16, #17.

### Order & special notes
- **Work in priority order. Do NOT reorder or skip — Jessica: "that's how things get lost."**
- **#16 and #17** moved to the end by Jessica's explicit decision (UI notes).
- **#18** skipped for now (Jessica: "not tonight"), resume when she's ready.
- **#22 is amended: do NOT delete `AiRelevanceBenchmark`.** Kept on purpose for pricing analysis until the whole feature is done.
- **#38 was consolidated into #20** — template naming convention fix.

## Working conventions (learned across sessions — see memory files for details)
- Protocol: present each decision → Jessica explicitly confirms → write to `approved-decisions.md`. NEVER write to that file without explicit approval. "Let's write them" during discussion means draft together in chat, not commit.
- Investigate every note in the live code (don't trust prior agent claims). Per-note investigation files. INVOKE the investigating-before-answering skill properly — incomplete investigation is same as none.
- Captures are lean: exact identifiers + the change, no editorializing, no rationale unless asked. No editorializing code comments either.
- Ripple sites = file locations only, grouped by change; the planning/implementation agent finds the exact edits. No line numbers (they rot), no pre-written edits. No descriptions of what to do at each file — just the paths.
- Renames spelled out ("rename X to Y"), never an arrow. Don't call methods "predicates" or hook request functions "fetchers"; use the codebase's terms.
- Code blocks in the decisions doc only where Jessica explicitly approves the exception (so far: #9B-2).
- When proposing names: check existing codebase conventions FIRST (e.g., interactor naming uses `Verb + NounObject` matching the record created). Don't propose names based on "business meaning" when the codebase has a mechanical convention.
- Don't present intermediate findings during investigation — complete the investigation, then present the full picture.
- Don't contradict yourself across answers. If you say "don't propagate" and then agree "should retry," you've contradicted yourself. Be consistent.
- Don't ask Jessica if she already knows what she wants before investigating. Just investigate and present findings.
- Use precise, accurate terminology. An ActiveRecord query is not "raw SQL" or a "SQL prefilter." Name things correctly.

## Repo state
- The prior test agent's working-tree changes were reverted; Jessica kept ONE change in `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBilling.tsx` (a missing import). Do not read/touch `db/schema.rb` (Jessica's instruction).
- Note file now has 38 items (added #38 in a prior session).
