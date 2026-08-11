# item1-mailer-recipients — Round 1

Trace: SPEC 1.6-1.7 → bulk_all_stages_ai_summary_result_mailer.rb (current) → job_application_mailer.rb:10-32 (recipient analog) → organization_user.rb:37,48 (scopes) → bulk_job_application_ai_summary_result_mailer.rb (must stay single-user) → spec/mailers/bulk_all_stages_ai_summary_result_mailer_spec.rb (stale)

## Source-accuracy checks (confirmed)
- `bulk_all_stages_ai_summary_result_mailer.rb`: `complete(user_id, job_id, succeeded_count, failed_count, skipped_count, total)` (6 args) and `failed(user_id, job_id, total_queued_count)` (3 args), each with single-user `to: [{ name: @user.full_name, email: @user.email }]`. CONFIRMED.
- Analog `job_application_mailer.rb:19` uses `.organization_users.actives.receives_new_job_application_emails.includes(:user)`, maps recipients (:28-32), `return unless recipients.any?` (:21). SPEC 1.6 drops `.receives_new_job_application_emails` (owner-ruled) and keeps `actives` + the map + the `any?` guard. CONFIRMED analog shape.
- `organization_user.rb`: `scope :actives, -> { where(is_active: true) }` (:48), `receives_new_job_application_emails` (:37). CONFIRMED.
- `bulk_job_application_ai_summary_result_mailer.rb` (per-stage) is a separate file, single-user, not referenced by any SPEC change. SPEC 1.6 says "no change." CONFIRMED it must stay untouched.

## Findings
- F1 [MED→ESCALATE] `user_first_name` in the multi-recipient send is unspecified. Both `complete` and `failed` pass `variables: { user_first_name: @user.first_name, ... }`, derived from the single triggering `@user = User.find(user_id)`. SPEC 1.6 broadens `to:` to the whole hiring team but is silent on `@user`/`user_first_name`. Two sub-parts:
  - ACCURACY (amendable): the implementer must NOT delete `@user` — if `to:` no longer reads it, a careless edit could drop `@user = User.find(user_id)` and leave `user_first_name: @user.first_name` referencing nil. AMENDED SPEC 1.6 to retain `@user` explicitly (see below).
  - DECISION (escalated, NOT amended): with `@user` retained, every hiring-team recipient's email carries `user_first_name` = the TRIGGERING user's first name. If the Postmark templates (`user-bulk-all-stages-ai-summary-complete` / `-failed`, external — not verifiable from repo) use it as a greeting, every teammate is greeted by the trigger's name. Per-recipient personalization is explicitly out of SPEC scope. Whether the trigger's-name greeting is acceptable, or the greeting variable should change, is a product decision for Jessica.
- F2 [MED] SPEC 1.7 says only "extend" `bulk_all_stages_ai_summary_result_mailer_spec.rb`, but that spec is ALREADY STALE against the current mailer and cannot pass as-is:
  - `#complete` example calls `complete(user.id, job.id, 5, 1, 2)` — 5 args against the 6-arg signature → `ArgumentError`.
  - `#complete` asserts subject `"Your AI summaries for #{job.title} are ready"`; mailer emits `"Your Plato reviews for #{@job.title} are ready"`.
  - `#complete` asserts tags `['polymer','user-facing','ai-summaries']`; mailer emits `['polymer','user-facing']`.
  - `#failed` asserts subject `"We couldn't generate AI summaries for #{job.title}"`; mailer emits `"We couldn't complete your Plato reviews for #{@job.title}"`.
  - `#complete`/`#failed` assert `params[:to].first[:email]).to eq(user.email)` — after the recipient change `to:` becomes the full active-team array, so this needs reconciling too.
  "Extend" without reconciling adds recipient assertions on top of already-failing expectations. AMENDED SPEC 1.7 to direct the reconciliation (arity, subject, tags, recipient assertions). This is the pre-flagged Phase-1 stale-spec issue; the fix is an accuracy amendment, not a decision change.
- F3 [LOW] SPEC 1.6 does not mention `.includes(:user)`. The analog uses it to avoid N+1 across `recipient.user`. "Resolved like JobApplicationMailer#hiring_team_new_job_application" arguably implies it. Optimization only; NOT amended.

## Amendments Applied
- SPEC 1.6: added a sentence retaining `@user = User.find(user_id)` and the `user_first_name: @user.first_name` variable — only the `to:` array broadens (accuracy; prevents dropping `@user`).
- SPEC 1.7: replaced the bare "extend" bullet with an explicit reconciliation directive (6-arg `complete` call, subject strings "Your Plato reviews…" / "We couldn't complete your Plato reviews…", tags `['polymer','user-facing']`, and multi-recipient `to:` assertions).

## Rejected as false positives (guardrails)
- Dropping `.receives_new_job_application_emails` — owner-ruled (SPEC 1.6, no Plato-bulk opt-out key). Not a deviation.
- Per-stage mailer staying single-user — owner-ruled (SPEC 1.6/1.8). Not a gap.
