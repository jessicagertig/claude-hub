# SPEC ADDITIONS — conversion events

Phase 1 spec review, run `wf_f572c2d9-f78`. 27 agents, 0 errors, 3 rounds.
Round 1: 26 fresh findings (3 blocker). Round 2: 13 fresh, 0 blocker. Round 3: 11 fresh, 0 blocker.

Nothing here is a blocker and nothing here changes `SPEC.md`. These are details the spec leaves to the
implementer that have an answer derivable from the code, conventions that apply, and ripple sites the
spec does not name. The implementation agent reads this alongside the spec.

Blockers are in `spec-blockers.md`.

---

## D1 (ripples into D15 and the duplicate check in D17)

### `pending: 0` shifted every existing event_type integer by +1 and no data migration shifts the existing rows, so every pre-branch row now decodes as the wrong event_type

`d1-enum-renumber-no-row-backfill`

origin/develop's enum is `assigned_free_plan_on_creation: 0 … trial_converted_to_paid: 8`. HEAD (ada2feb9a) inserts `pending: 0` and renumbers everything to 1–9. `db/data/` contains no migration touching `subscription_events.event_type` (only 20260727185945, which writes rows, does not renumber them). `Organization#log_assigned_free_plan_event` has been writing rows since 2025-09-07 (b0aaccd32), so production rows hold the old integers and each now reads one name lower: stored 0 (`assigned_free_plan_on_creation`) reads `pending`; 2 (`converted_to_paid`) reads `assigned_free_plan`; 3 (`canceled_subscription`) reads `converted_to_paid`; 8 (`trial_converted_to_paid`) reads `trial_started`. Consequences for the code being written: D1's diagnostic — a row at `pending` means the column was never assigned, a defect to investigate — is false for every historical `assigned_free_plan_on_creation` row; D15's `case event_type` names the wrong branch for any pre-branch row it reads; the interactor's duplicate check (create_subscription_event.rb:26-29) compares `event_type` against the new integer, so a historical row is never seen as a duplicate; and the backfill's own idempotency guard (db/data/20260727185945_...rb:9-10) compiles to `event_type IN (3, 9)` and will not match rows written as 2/8. The remedy is not fully determined by the code because it depends on whether 20260727185945 has already run in a given environment: on a database where it has NOT run, this branch's release runs `db:migrate` then `data:migrate` (bin/heroku-release:24-26) so the backfill writes the NEW numbering, and a blanket `event_type = event_type + 1` would corrupt exactly those rows. Any renumber has to be scoped to rows written before this branch's code was loaded.

**Evidence:** app/models/subscription_event.rb:18-29 vs `git show origin/develop:app/models/subscription_event.rb` lines 14-24; `git log -S"pending: 0" -- app/models/subscription_event.rb` → ada2feb9a only; db/data/ listing (no renumber migration); db/data/20260727185945_create_subscription_events_for_existing_paid_organizations.rb:9-10; app/interactors/create_subscription_event.rb:26-29; app/models/organization.rb:1230-1249; bin/heroku-release:24-26

## D10

### D10's "local development only" needs the trailing `if Rails.env.development?` house form and `ap` — the interactor's neighbouring prints are unguarded, so copying them ships a production print

`d10-dev-only-print-form`

D10 says "Print the Stripe object the interactor receives. Local development only" but names no mechanism. `CreateSubscriptionEvent` already contains three unguarded prints (`ap 'Create Subscription Event Interactor'` and the two `stripe_subscription_in_good_standing` lines) plus a commented-out `# ap context`. An implementer adding the new print alongside them will produce a print that runs in every environment, which is not what D10 asked for.

The house form is a trailing conditional — `... if Rails.env.development?` — used 40 times in `app/`, including for exactly this purpose (dumping a params/resource object during a flow). And the print itself must be `ap`, never `pp`, per `core_critical_rules.md` rule 3 "Use Awesome Print (Not Pretty Print)", which also matches the file's existing lines.

**Evidence:** app/interactors/create_subscription_event.rb:7-8,13-14; app/controllers/api/v1/registrations_controller.rb:17-18; app/controllers/auth/invites_controller.rb:69-70; app/models/textract_result.rb:33; cursor_rules/core_critical_rules.md:67-72

## D12 vs D15 (and D7)

### downgraded_to_free is the only cell where the $set list and the dispatch table disagree — it gets no `when` branch

`d12-downgraded-to-free-cell`

Diffing D12, D13 and D15 row by row, trial_started, trial_converted_to_paid, converted_to_paid, canceled_subscription and upgraded_plan agree in every cell (D12's shorter entries are subsets of D13's, and D15 matches D13 exactly). downgraded_to_free is the one disagreement: D12 assigns it `$set is_paying: false`, while D15 has no row for it and its else — which is a bare return — names downgraded_to_free explicitly, and D7 says the feature never writes it. Resolution an implementer must not get backwards: write no `when downgraded_to_free` branch; that event_type falls into the bare-return else and fires no capture, so D12's is_paying: false for it is inert until downgrades are recorded elsewhere. Same for downgraded_plan.

**Evidence:** SPEC D7, D12, D13, D15; app/models/subscription_event.rb:38-55 (today's dispatch has no downgrade branch)

## D12, D13

### The `$set` key must be written `'$set' =>` or `:"$set" =>` — the label form `{ $set: ... }` is a Ruby syntax error

`d12-set-key-literal`

`$set:` does not parse (`syntax error, unexpected ':', expecting =>`, verified on ruby 3.1.6); a label key must be an identifier and `$set` is a global-variable name. Only `'$set' => {...}` or `:"$set" => {...}` are valid. Either one is correct end to end, which also closes D13's flagged "verify against a real event" item: I ran the round trip and the key survives intact. ActiveJob serializes/deserializes the nested hash under the `$set` key unchanged (`$set` is not in ActiveJob's RESERVED_KEYS); `PosthogTrackJob#perform` `deep_symbolize_keys` makes it `:"$set"`; `Posthog::Track#track` merges it under `properties:`; `PostHog::FieldParser.parse_for_capture` passes `properties` through untouched apart from adding `$lib`/`$lib_version` (`symbolize_keys!` is top-level-only on `attrs`, `isoify_dates!` rewrites values only), and JSON encoding turns the symbol back into the string key. Executed output: `{"properties":{"amount":49.99,"$set":{"is_paying":true,"is_trialing":false},"$lib":"posthog-ruby",...},"type":"capture","event":"converted_to_paid"}`. D12's mechanism is confirmed exactly as written — no stringification, no second call, no defensive handling needed.

**Evidence:** app/jobs/posthog_track_job.rb:10; app/services/posthog/track.rb:13-17; posthog-ruby-2.11.0/lib/posthog/field_parser.rb:16-40; posthog-ruby-2.11.0/lib/posthog/utils.rb:12-19, 34-41

## D13, D15

### `upgraded_plan` "carries no `$set` at all" — merge the `$set` inside `posthog_properties` before its `.compact` and the absence is free

`d13-upgraded-plan-absent-set`

D15 gives `upgraded_plan` a `when` branch with no `$set` that still reaches the single `enqueue_posthog_track`. `posthog_properties` ends in `.compact` (subscription_event.rb:84), so if the `$set` is merged into the hash BEFORE that `.compact`, the `upgraded_plan` case's nil `$set` is stripped and the key is genuinely absent. Merging afterwards sends a literal `"$set": null`, and defaulting the threaded argument to `{}` sends `"$set": {}` — both contradict "no `$set` at all", and neither is stripped by anything downstream (`parse_for_capture` only adds keys). Two safe properties of `.compact` worth knowing here: it removes nil only, so `is_paying: false` and `is_trialing: false` survive it, and it is shallow, so it never touches the inside of the `$set` hash.

**Evidence:** app/models/subscription_event.rb:57-61 and :63-85 (`.compact` at :84); posthog-ruby-2.11.0/lib/posthog/field_parser.rb:33-39

### `.compact` removes nil only — an empty `$set` hash for `upgraded_plan` stays in the payload

`d15-empty-set-hash-survives-compact`

An earlier round's remedy — merge the `$set` into `posthog_properties` before its existing `.compact` so `upgraded_plan`'s absence is free — holds only when the merged value is `nil`. `Hash#compact` drops nil values, not empty hashes: `{a: 1, :"$set" => {}}.compact` returns `{:a=>1, :$set=>{}}` (verified on the repo's Ruby 3.1.6). If the `case` initialises the `$set` local to `{}` and `upgraded_plan`'s branch leaves it alone — the natural reading of D15's `none` cell — the capture carries `"$set": {}`, contradicting D13's "carries no `$set` at all." The value passes through untouched: `posthog_properties` -> `PosthogTrackJob#perform` `deep_symbolize_keys` -> `Posthog::Track#track` `default_properties.merge(@properties)` -> `FieldParser.parse_for_capture` (`isoify_dates!` leaves a Hash value alone via the `else` in `datetime_in_iso8601`). Right answer: the `$set` local is `nil` for `upgraded_plan`, not `{}`.

**Evidence:** /Users/jessica/wrk/wrk-corp/inflow-ats/app/models/subscription_event.rb:63-85 (`.compact` at :84); /Users/jessica/wrk/wrk-corp/inflow-ats/app/jobs/posthog_track_job.rb:10; /Users/jessica/wrk/wrk-corp/inflow-ats/app/services/posthog/track.rb:13-17; /Users/jessica/.rvm/gems/ruby-3.1.6/gems/posthog-ruby-2.11.0/lib/posthog/field_parser.rb:30,34-40; /Users/jessica/.rvm/gems/ruby-3.1.6/gems/posthog-ruby-2.11.0/lib/posthog/utils.rb:31-35,53-64

## D14

### D14's "convert to an integer first, then divide by 100.0" turns a nil `amount` into `0.0`, which D14's own nil rule forbids

`d14-nil-amount-to-i-yields-zero`

D14 says "A value that is not already a number is converted to an integer first, then divided by `100.0`" and, two sentences later, "A nil `amount` is sent as nil, not as zero. `canceled_subscription` rows carry no amount." `nil` is not a number, `nil.to_i` is `0`, and `0 / 100.0` is `0.0`. An implementer applying the first sentence literally sends `amount: 0.0` for every `canceled_subscription` row — which is exactly what the second sentence and core_critical_rules.md rule 10 (Never Fabricate Fallback Values) prohibit. The right answer is stated inside D14 itself: nil must be short-circuited before the `to_i`, so the conversion applies only to non-nil values. Related detail the implementer needs: `posthog_properties` ends in `.compact`, so a genuinely-nil `amount` is dropped from the payload entirely rather than sent as an explicit nil key — but a fabricated `0.0` survives `.compact` and is sent. Per D2's second table every `customer.subscription.deleted` row has `amount` nil, so this is the normal case on that path, not an edge case.

**Evidence:** app/models/subscription_event.rb:66 (`amount: amount,`), :84 (`}.compact`); SPEC.md D14 lines 218-231; cursor_rules/core_critical_rules.md:225-247 (rule 10); db/schema.rb:1194 (`t.integer "amount"`, nullable)

### `amount.to_i / 100.0` fabricates 0.0 for a nil amount; `.compact` at subscription_event.rb:84 is what makes nil absent, and must not be removed

`d14-nil-amount-to-i-fabricates-zero`

D14 says both "A value that is not already a number is converted to an integer first, then divided by `100.0`" and "A nil `amount` is sent as nil, not as zero." `nil` is not a number, so an agent applying the first sentence literally writes `amount.to_i / 100.0`, which yields `0.0` for the `canceled_subscription` rows D2 says carry no amount. `0.0` is not nil, so it survives the `.compact` on the last line of `posthog_properties` (subscription_event.rb:84) and lands in PostHog as a real $0.00 payment — a fabricated fallback, banned by cursor_rules/core_critical_rules.md rule 10.

The code determines the answer: `amount` is `t.integer "amount"` (db/schema.rb, inside `create_table "subscription_events"`), so the ActiveRecord reader returns Integer or nil and never a String — the "not already a number" clause can only ever be reached by nil. Nil must short-circuit before any `to_i`.

Second half: the existing `.compact` (subscription_event.rb:84) is the mechanism that already satisfies "sent as nil, not as zero" — a nil `amount` is dropped from the hash entirely rather than transmitted as JSON null. An agent trying to make nil literally "sent as nil" by deleting `.compact` would newly emit nil-valued keys for all fourteen attribution properties (subscription_event.rb:71-83) on every subscription event PostHog receives. `.compact` stays.

**Evidence:** app/models/subscription_event.rb:66, :84; db/schema.rb create_table "subscription_events" → `t.integer "amount"`; cursor_rules/core_critical_rules.md rule 10 (lines 225-247); app/models/board_wwr_listing.rb:101,103 (the cited float-divisor precedent)

### `posthog_properties` ends in `.compact`, so a nil `amount` is omitted from the payload rather than sent as nil

`d14-compact-drops-nil-amount`

D14 says "A nil `amount` is sent as nil, not as zero. `canceled_subscription` rows carry no amount." The existing hash literal in `posthog_properties` terminates with `.compact`, which strips every nil-valued key before the hash reaches `PosthogTrackJob`. So on a `canceled_subscription` row the `amount` key is absent from the capture, not present-with-nil. Same applies to a nil `from_plan` when D9's helper rescues or nothing qualifies, and to nil `to_plan` on `canceled_subscription`. The implementation-relevant point: D14's intent (never zero) is already satisfied, and the implementer must not remove `.compact` to make the key literally present, nor add any `|| 0` / `|| 'unknown'` substitution — core_critical_rules.md rule 10 and the spec's "Do not fabricate a `from_plan` value" both forbid the latter. The dollars conversion should therefore be written so it does not turn nil into 0 (e.g. guard on presence before `to_i` / `/ 100.0`).

**Evidence:** app/models/subscription_event.rb:63-85 (hash literal, `.compact` at :84); app/jobs/posthog_track_job.rb:10; app/services/posthog/track.rb:14-18; cursor_rules/core_critical_rules.md:225-247

## D14 / D9

### `posthog_properties` ends in `.compact`, so `nil.to_i / 100.0` would send `amount: 0.0` on every `canceled_subscription` — exactly what D14 forbids

`posthog-properties-compact-drops-nils`

`posthog_properties` terminates with `.compact` (app/models/subscription_event.rb:84), which strips every nil-valued key from the payload. D14 contains two sentences that pull in opposite directions for the nil case: "A value that is not already a number is converted to an integer first, then divided by `100.0`" and "A nil `amount` is sent as nil, not as zero." Taken literally the first sentence yields `nil.to_i` → `0` → `0 / 100.0` → `0.0`, and `0.0` is not nil, so `.compact` keeps it and PostHog receives `amount: 0.0` on every `canceled_subscription` row (D2 states those rows carry a null amount). The code settles it: the nil test must come before the to_i/divide conversion, so the key is nil at `.compact` time and gets dropped — which is what "sent as nil" means given this hash's existing shape. The same `.compact` also means a nil `from_plan` (D9's rescue path, or nothing qualified) is absent from the payload rather than present-and-null; that is current behavior and needs no change, but the implementer should not add a substitute value to make it appear (the DON'T FUCK WITH THIS no-fabrication bullet).

**Evidence:** app/models/subscription_event.rb:63-85 (`.compact` at line 84, `amount: amount` at line 66); SPEC.md D14 lines 218-231; SPEC.md D2 lines 60-61

## D14 with D13

### "A nil amount is sent as nil" meets the existing `.compact` in posthog_properties — keep `.compact`, guard the division

`d14-nil-amount-vs-compact`

posthog_properties ends in `.compact` (subscription_event.rb:84), so a nil amount is dropped from the payload rather than transmitted as nil; D13 says nothing else about the payload changes, which settles it — do not delete `.compact` to make nil literally "sent" (that would start sending nils for every attribution key at :71-83, all currently compacted away). The trap D14 is guarding against survives compact: `amount.to_i / 100.0` yields 0.0 for a canceled_subscription row, which is a real value, passes compact, and contradicts D14's "not as zero." The conversion must be nil-guarded before dividing; amount is a nullable integer column (schema.rb:1194), so the only non-numeric case D14 mentions is nil.

**Evidence:** SPEC D13, D14; app/models/subscription_event.rb:63-85 (amount at :66, .compact at :84); db/schema.rb:1194

## D15

### `enqueue_posthog_track` takes no arguments and builds the payload itself behind the `organization&.owner` guard — the `$set` has to be threaded into it, not merged in the callback body

`d15-enqueue-posthog-track-arity`

D15 says the `case` supplies each event's `$set`, `posthog_properties` builds the shared hash, and one `enqueue_posthog_track` runs after the `case`. Today `enqueue_posthog_track` is zero-arity: it guards `return unless organization&.owner`, then calls `posthog_properties` itself inside `PosthogTrackJob.perform_later(...)`. An implementer who calls it unchanged after the `case` ships the whole feature with no `$set` reaching PostHog. Right answer: give it a parameter for the branch's `$set` hash and do the merge inside it, after the guard — `posthog_properties` assigns `owner = organization.owner` and then dereferences `owner.utm_source` with no nil check, so building the merged hash in the callback body moves that dereference ahead of the guard the current code deliberately puts in front of it (`organizations.owner_id` is a nullable integer in schema.rb). Two payload details the merge must respect: `posthog_properties` ends in `.compact`, which runs before any merge, so a merged `'$set'` survives regardless of content; and D15 gives `upgraded_plan` no `$set` at all, so that branch must merge nothing rather than merge `'$set' => nil`, which `.compact` will not strip. `Posthog::Track#track` does `default_properties.merge(@properties)`, so a `'$set'` key at the top level of the properties hash reaches `capture` intact.

**Evidence:** app/models/subscription_event.rb:57-61 (guard + zero-arity call), :63-85 (`owner.utm_source` at :71, `.compact` at :84), app/services/posthog/track.rb:13-17, db/schema.rb organizations `t.integer "owner_id"`

### `case event_type` must match String literals — symbol `when` clauses match nothing and drop every row into the bare-return `else`

`d15-case-compares-strings`

The Rails enum reader returns the String key (`"converted_to_paid"`), and the spec writes the event types unquoted in the D15 table. A `case event_type` written with `when :trial_started` matches no row, so every branch falls to the `else`, which D15 makes a bare return — that silently kills all PostHog and Discord dispatch, including the `trial_started` half that is live today. The `when` clauses take quoted strings (single quotes per the house Ruby style), or the existing predicate methods (`trial_started?` etc.) the current if/elsif chain uses.

**Evidence:** app/models/subscription_event.rb:18-29 (enum), :41-54 (current predicate dispatch); cursor_rules/core_critical_rules.md:423-426

### `case event_type` compares against Strings — symbol `when` clauses would fall through to the bare-return `else` and dispatch nothing at all

`d15-case-on-enum-reader-returns-string`

D15 replaces the current `if trial_started? / elsif ...` chain (subscription_event.rb:41-54) with `case event_type`. The Rails enum reader defined at subscription_event.rb:18-29 returns a String (`'trial_started'`), not a Symbol. A `case event_type` written with `when :trial_started` matches nothing, every row falls to the `else`, and D15's `else` is a bare return — so no `$set`, no PostHog capture, and no Discord job for any event type, silently. The `when` clauses take single-quoted string literals (cursor_rules/backend/_base.md rule 7), matching how the enum values are already compared as strings elsewhere on this branch (`subscription_event_type_for` returns `'trial_converted_to_paid'` / `'converted_to_paid'` / `'upgraded_plan'` as strings, stripe_webhook_handler_job.rb:428-444).

**Evidence:** app/models/subscription_event.rb:18-29, :41-54; app/jobs/stripe_webhook_handler_job.rb:428-444; cursor_rules/backend/_base.md rule 7

### D15's `case event_type` must match String literals — symbol `when` clauses fall silently to the bare-return `else` and dispatch nothing

`d15-case-must-match-strings`

`event_type` is a Rails 6.1 enum reader (app/models/subscription_event.rb:18-29) and returns the String key, which is why the existing code interpolates it directly (line 39) and passes it straight through as the PostHog event name (line 60). Every caller also supplies Strings: `'trial_started'` (organization.rb:1131), `'canceled_subscription'` (stripe_webhook_handler_job.rb:218), `'assigned_free_plan_on_creation'`/`'assigned_free_plan'` (organization.rb:1234). The current code uses predicate methods (`trial_started?`, `converted_to_paid?`), so there is no existing `case` in this file to copy the form from. If the implementer writes `when :trial_started` / `:converted_to_paid` etc., no branch ever matches, D15's `else` bare-return fires for every row, and the entire feature dispatches nothing to PostHog or Discord — silently, with no exception and no log. The `when` clauses must be `'trial_started'`, `'trial_converted_to_paid'`, `'converted_to_paid'`, `'canceled_subscription'`, `'upgraded_plan'` as strings.

**Evidence:** app/models/subscription_event.rb:18-29, 38-55, 60; app/models/organization.rb:1131, 1234; app/jobs/stripe_webhook_handler_job.rb:218; SPEC.md D15 lines 233-249

### `Discord::NotifySubscriptionDeletedJob#perform` takes two required positional arguments; the other two Discord jobs in D15's table take one

`d15-discord-deleted-job-arity`

D15's dispatch table names all three Discord jobs by class alone, and they do not share an arity. `Discord::NotifyFreeTrialStartedJob#perform(organization_id)` and `Discord::NotifyTrialConvertedToPaidJob#perform(organization_id)` take one argument. `Discord::NotifySubscriptionDeletedJob#perform(organization_id, ended_at)` takes two, both required, and immediately does `Time.at(ended_at)` — a nil second argument raises `TypeError`, and a missing one raises `ArgumentError` inside the worker after the job has already been enqueued.

The existing call is `Discord::NotifySubscriptionDeletedJob.perform_later(organization_id, organization.subscription_canceled_at.to_i)`. When the if/elsif chain is rewritten as D15's `case`, the `canceled_subscription` branch must carry BOTH the `organization.subscription_canceled_at.present?` guard D15 names and that second `organization.subscription_canceled_at.to_i` argument. Writing the branch from D15's table alone produces a one-argument call that enqueues successfully and then fails in the worker.

**Evidence:** app/jobs/discord/notify_subscription_deleted_job.rb:7 (`def perform(organization_id, ended_at)`) and :14 (`Time.at(ended_at)`); app/jobs/discord/notify_free_trial_started_job.rb:6; app/jobs/discord/notify_trial_converted_to_paid_job.rb:6; app/models/subscription_event.rb:51-53 (existing two-argument call site); SPEC.md D15 line 244

## D15 (with D12 and D13)

### The existing backfill data migration creates rows through the new after_commit, so the deploy that ships D15 fires one Discord "Trial Converted to Paid" ping and one PostHog capture per pre-existing paid organization

`d15-backfill-fires-new-dispatch-on-deploy`

`db/data/20260727185945_create_subscription_events_for_existing_paid_organizations.rb:37` calls `SubscriptionEvent.create` for every organization where `active_paid_plan?` (organization.rb:691-693) is true. On origin/develop `SubscriptionEvent` has no callbacks at all — the whole `after_commit :handle_after_commit_on_create` block is added by this branch — so the backfill is silent there. `bin/heroku-release:26` runs `bin/rails data:migrate` unconditionally on every release, right after `db:migrate`, so the backfill executes against this branch's model. Each created row therefore enters the D15 `case`: rows the migration builds as `trial_converted_to_paid` (chosen at lines 24-28 whenever `subscription.trial_end.present?`) enqueue `Discord::NotifyTrialConvertedToPaidJob`, which posts "🎉 Trial converted to paid - **<org name>**" to `Variables::DISCORD_SUBSCRIPTIONS_CHANNEL_ID` with `Converted at: <deploy time>` (notify_trial_converted_to_paid_job.rb:17-18, 39); rows built as `converted_to_paid` enqueue a PostHog capture. D15's `$set is_paying: true, is_trialing: false` rides on each. The migration's `created_at: converted_at` backdates the row but not the notification or the event timestamp. Note the backfill's `from_plan: 'unknown'` is non-nil, so D9's helper does NOT fire on these rows — the Stripe calls are not multiplied, only the Discord and PostHog dispatch. The blast radius is the paid-organization count.

**Evidence:** db/data/20260727185945_create_subscription_events_for_existing_paid_organizations.rb:7-45; app/models/subscription_event.rb:31 and 38-55; `git show origin/develop:app/models/subscription_event.rb` (no after_commit); bin/heroku-release:22-27; app/jobs/discord/notify_trial_converted_to_paid_job.rb:10-18,39; app/models/organization.rb:691-693

## D15 (with D13 and D12)

### The single shared enqueue after the `case` attaches a `$set` key to `upgraded_plan` unless the hash is built inside `posthog_properties`, before its existing `.compact`

`d15-set-key-placement`

D15 gives every `when` a `$set` hash except `upgraded_plan`, and D13 states `upgraded_plan` "carries no `$set` at all". With one `enqueue_posthog_track` after the `case`, the `$set` local is assigned in four branches and unassigned in the `upgraded_plan` branch, so it is `nil` there. The obvious implementation — `posthog_properties.merge('$set' => person_properties)` — cannot drop it: `posthog_properties` ends in `.compact` at subscription_event.rb:84, so the compaction has already run before the merge, and `Hash#merge` then adds `'$set' => nil` back. posthog-ruby passes unknown keys straight through (field_parser.rb:34-40), so PostHog receives `"$set": null` on every `upgraded_plan` event, contradicting D13. Defaulting the local to `{}` does not help either — `.compact` removes nil values only, so `"$set": {}` would ship instead.

The answer the code determines: thread the hash into `posthog_properties` as a parameter and place `'$set' => person_properties` inside the hash literal that ends in `.compact`, passing `nil` (not `{}`) from the `upgraded_plan` branch. The existing `.compact` then removes the key for `upgraded_plan` and keeps it for the other four — the inner `is_paying: false` / `is_trialing: false` values are unaffected because `Hash#compact` is not deep and only drops nil.

The same placement is what keeps the merge behind the guard. `posthog_properties` dereferences the owner without safe navigation — `owner = organization.owner` (subscription_event.rb:64) then `owner.utm_source` (line 71) — and today it is only ever reached after `return unless organization&.owner` in `enqueue_posthog_track` (line 58). Calling `posthog_properties` in the callback body to build the merged hash moves that dereference in front of the guard and raises `NoMethodError` on an ownerless organization.

**Evidence:** app/models/subscription_event.rb:57-61 (`enqueue_posthog_track` guard + no-arg signature), :63-85 (`posthog_properties`, `.compact` at :84, unguarded `owner.utm_source` at :64/:71); app/jobs/posthog_track_job.rb:10 (`deep_symbolize_keys`); app/services/posthog/track.rb:13-17 (`default_properties.merge(@properties)`); ~/.rvm/gems/ruby-3.1.6/gems/posthog-ruby-2.11.0/lib/posthog/field_parser.rb:34-40; SPEC.md D15 table row `upgraded_plan` / `$set` "none", D13 line 206-207

## D15 (with D13)

### If the `case` value is the `$set`, the Discord enqueue must not be the last expression in any `when` — D15's own sentence orders it the other way

`d15-case-value-vs-discord-enqueue-order`

D15 says "Each `when` supplies that event's `$set` hash and enqueues its Discord job" — hash first, enqueue second — and then "the `$set` merges in." An implementer who assigns the case (`posthog_set = case event_type ... end`) and follows that order gets the wrong value out of every branch that has a Discord job. `Discord::NotifyFreeTrialStartedJob.perform_later(organization_id)` returns the job instance, so `trial_started` and `trial_converted_to_paid` would yield a `Discord::Notify*Job` object as their `$set`. `canceled_subscription` is worse: its enqueue is already wrapped in `if organization.subscription_canceled_at.present?` (subscription_event.rb:51-53), so the branch evaluates to nil whenever that guard is false and to a job object when it is true. A job object reaching `PosthogTrackJob.perform_later` is fatal, not merely wrong: `ActiveJob::Arguments.serialize_argument` (activejob-6.1.7.7/lib/active_job/arguments.rb:99-101) permits only PERMITTED_TYPES / GlobalID / Array / Hash and raises `SerializationError` otherwise, the sidekiq adapter serializes eagerly at enqueue, and `Transaction#commit_records` (activerecord-6.1.7.7/lib/active_record/connection_adapters/abstract/transaction.rb:146-163) does not rescue — so the error propagates out of `subscription_event.save`, out of `CreateSubscriptionEvent#call` (Interactor's `run` rescues only `Interactor::Failure`), and on the `trial_started` path out of `organization.save` itself, because `CreateSubscriptionEvent.call` at organization.rb:1131 has no rescue (unlike both `StripeWebhookHandlerJob` call sites, which do — stripe_webhook_handler_job.rb:224 and :332). Right answer: assign the `$set` to a local inside each `when` before enqueuing Discord, or make the hash the branch's last expression. Related, same construction: D13 has `upgraded_plan` dispatch to PostHog with no `$set`, so it needs an explicit `when 'upgraded_plan'` whose body is empty — without one it falls into the bare-return `else` and never reaches the shared `enqueue_posthog_track`.

**Evidence:** app/models/subscription_event.rb:38-55 (existing branch bodies; :51-53 guarded Discord enqueue), app/models/organization.rb:1131 (unrescued CreateSubscriptionEvent.call on the trial_started path), app/jobs/stripe_webhook_handler_job.rb:224,332 (the two call sites that DO rescue), app/jobs/discord/notify_free_trial_started_job.rb:6, app/jobs/posthog_track_job.rb:6-11, activejob-6.1.7.7/lib/active_job/arguments.rb:99-101, activerecord-6.1.7.7/lib/active_record/connection_adapters/abstract/transaction.rb:146-163

### `when 'upgraded_plan'` is an empty branch whose only job is to escape the bare-return `else` — omitting it drops the event D13 adds

`d15-upgraded-plan-when-branch-is-load-bearing`

D15's table gives `upgraded_plan` `none` for `$set` and `none` for Discord, and D15's prose says "Each `when` supplies that event's `$set` hash and enqueues its Discord job." An implementer following that sentence has no reason to write a `when` for a row whose two cells are both `none` — and `upgraded_plan` then falls into the `else`, which D15 fixes as a bare `return`, so the shared `enqueue_posthog_track` after the `case` never runs. That silently deletes the one payload change D13 asks for: "`upgraded_plan` dispatches to PostHog, where today it dispatches nothing." Note that D15's own `else` sentence lists the five types that dispatch nothing (`assigned_free_plan_on_creation`, `assigned_free_plan`, `downgraded_plan`, `downgraded_to_free`, `pending`) and `upgraded_plan` is deliberately not among them. Right answer: `when 'upgraded_plan'` exists as a body-less branch; its sole purpose is to not be the `else`, so control reaches the shared enqueue. Today `handle_after_commit_on_create` has no `upgraded_plan` arm at all (subscription_event.rb:41-54), so there is nothing to copy from.

**Evidence:** /Users/jessica/wrk/wrk-corp/inflow-ats/app/models/subscription_event.rb:38-55 (current if/elsif chain, no upgraded_plan arm), :57-61 (`enqueue_posthog_track`); SPEC.md D15 table row `upgraded_plan | none | none`, D15 `else` list, D13 "`upgraded_plan` dispatches to PostHog"

## D16 (and the "DON'T FUCK WITH THIS" note on `downgrade_detected?`)

### A second plan-tier hierarchy keyed on plan names lives in `DisableAutomationsOnDowngrade#plan_downgraded?` and the spec never names it — it orders the three legacy-unlimited plans opposite to D16

`d16-second-plan-name-hierarchy-unnamed`

The spec protects `StripeWebhookHandlerJob#downgrade_detected?` and its `plan_tiers` array by name, but that array is keyed on LOOKUP KEYS. The only other plan-tier hierarchy in the codebase, and the only one keyed on PLAN NAMES — exactly what D16's class method consumes — is the local `plan_hierarchy` hash inside `DisableAutomationsOnDowngrade#plan_downgraded?`. It is the nearest non-AI analog an implementation agent will find when it goes looking for "how this codebase ranks plan names," and it disagrees with D16: it puts `plan_ats_tier_apollo`, `plan_simple_ats_paid` and `plan_simple_ats_per_job` at the TOP (level 4, tied with `plan_ats_tier_enterprise`, above `plan_ats_tier_scale` at 3), whereas D16's array puts them at indices 3, 1 and 2, below `starter`(4)/`growth`(5)/`scale`(6). It also omits every v2 plan, so all four v2 names fall through its `|| 0`. The implementer must not reuse it, import it, reconcile it with D16's array, or "fix" its missing v2 entries — none of that is in scope, and D16's ordering is closed. Note for the record that D16's array never regresses today's behavior: `downgrade_detected?` currently scores all three legacy-unlimited lookup keys at 0, so `plan_simple_ats_paid` → `plan_ats_tier_starter_v2` already records `upgraded_plan`, and D16 records the same. Enumeration result for the commissioned check: the authoritative plan-name vocabulary is the 14 keys of the `Organization` `plan` enum (`plan_no_plan`, `plan_simple_ats_free`, `plan_simple_ats_paid`, `plan_simple_ats_per_job`, `plan_ats_tier_apollo`, `plan_ats_tier_free`, `plan_ats_tier_starter`, `plan_ats_tier_growth`, `plan_ats_tier_scale`, `plan_ats_tier_free_v2`, `plan_ats_tier_starter_v2`, `plan_ats_tier_growth_v2`, `plan_ats_tier_scale_v2`, `plan_ats_tier_enterprise`), confirmed complete against `PlanFeatureGate#plan_rules`. D4's `include?('free')` catches `plan_simple_ats_free`, `plan_ats_tier_free`, `plan_ats_tier_free_v2` and all four of their lookup keys, and matches no paid plan or paid lookup key. D16's array indexes all 14 names and every lookup key (`plan_ats_tier_apollo_monthly/_yearly`, `plan_ats_tier_free_monthly_v1/_annual_v1`, `plan_ats_tier_free_v2_monthly/_yearly`, `starter/growth/scale` v1 and v2 variants, `plan_simple_ats_paid`, `plan_simple_ats_per_job`, `plan_simple_ats_per_job_tiered`, `enterprise`) with no name matching two entries and no name reaching the `|| 0` fallback except `plan_no_plan`, which is unreachable as a `from_plan` at D16 time. D18's claim holds: all ten `Variables::AI_CREDIT_ALLOCATIONS` keys — and therefore all `OrganizationAiCreditPurchase::AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` keys, which are derived from them — contain `credit`, and the six `plato_*` ones contain both.

**Evidence:** app/services/disable_automations_on_downgrade.rb:44-58 (`plan_hierarchy`); app/jobs/stripe_webhook_handler_job.rb:513-518 (`plan_tiers`, lookup-key keyed); app/models/organization.rb:94-117 (the 14-key `plan` enum); app/services/plan_feature_gate.rb:142-244 (`plan_rules`, same 14); app/services/stripe/subscription_status_checker.rb:16-47 (`PLAN_LOOKUP_MAPPING`); config/initializers/01_variables.rb:132-147 (`AI_CREDIT_ALLOCATIONS`); app/models/organization_ai_credit_purchase.rb:4-13 (`AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` derived from it); app/controllers/api/v1/billing_controller.rb:7-9 (`plan_simple_ats_per_job_tiered`, `plan_ats_tier_free_v2`, `plan_ats_tier_free`)

## D16 (with D4 and D19)

### D16's tier index must use `&.include?` — a nil `to_plan` reaches it and `nil.include?(tier)` raises

`d16-tier-index-nil-to-plan`

D16's class method is called from the interactor with the two plan NAMES. D4's guard order rules out a nil `from_plan` (rule 1: `converted_to_paid` when `from_plan` is nil or contains `free`) but never rules out a nil `to_plan`: D19 says a nil destination lookup key `is stored as nil and never passed to` `assign_plan_name_from_lookup_key`, and D4 rule 2 (`no row when the two plans are equal`) is false when `from_plan` is a paid plan name and `to_plan` is nil — so D16 is entered with `to_plan == nil`. Written literally from D16's prose as `plan_tiers.find_index { |tier| to_plan.include?(tier) } || 0`, that is a `NoMethodError`, swallowed by the call site's `rescue StandardError` at stripe_webhook_handler_job.rb:332 and logged as a bogus ledger error. The house form for exactly this operation is nil-safe: `downgrade_detected?` writes `current_lookup_key&.include?(tier)` / `next_lookup_key&.include?(tier)`. Reached when a `subscription_update` invoice's positive line has no `price.lookup_key` while its negative line does.

**Evidence:** /Users/jessica/wrk/wrk-corp/inflow-ats/app/jobs/stripe_webhook_handler_job.rb:508-519 (esp. 515-516) and :332; /Users/jessica/wrk/wrk-corp/inflow-ats/app/services/stripe/subscription_status_checker.rb:113-119; SPEC.md D4, D16, D19

## D17

### D17's cited precedent is the opposite of what it claims: `stripe_subscription_id` and `amount` are added BEFORE the duplicate check and ARE part of it

`d17-analog-sequence-is-backwards`

D17's rule is unambiguous — the parameter hash is built without `from_plan`, the check runs against it, `from_plan` is added afterwards for the build. But the justifying clause, "the same sequence the interactor already uses for `stripe_subscription_id` and `amount`," describes code that does not exist. In `CreateSubscriptionEvent#call` the order is: build `event_params` (lines 16-20), conditionally add `stripe_subscription_id` and `amount` (lines 22-23), THEN run the duplicate `where(event_params)` (lines 26-29), THEN `build(event_params)` (line 33). Those two keys are added before the check and are matched on — which is what D17's own first sentence requires of them. There is no existing key that is "added afterwards for the build." An implementer who follows the analog clause rather than the rule will place `from_plan` alongside lines 22-23 (or leave it at line 18 where it already sits) and it lands inside the duplicate check, which is the one thing D17 forbids. The sequence D17 actually requires has no precedent in this file and has to be written new: remove `from_plan:` from the line-16 hash, run the check, then `event_params[:from_plan] = context.from_plan` before line 33's `build`.

**Evidence:** SPEC.md:273-275 (D17 final paragraph); app/interactors/create_subscription_event.rb:16-20 (hash includes `from_plan`), :22-23 (`stripe_subscription_id`/`amount` added), :26-29 (`where(event_params)`), :33 (`build(event_params)`)

### D17's closing analogy describes a sequence the interactor does not have — following it puts `from_plan` back inside the duplicate check

`d17-param-hash-sequence-analogy`

D17's rule is unambiguous ("`from_plan` is always omitted from it"), but its last sentence — "the same sequence the interactor already uses for `stripe_subscription_id` and `amount`" — is not what the code does. In `CreateSubscriptionEvent#call`, `event_params[:stripe_subscription_id]` and `event_params[:amount]` are assigned at lines 22-23, BEFORE the `recent_duplicate` query at lines 26-30, and are therefore part of the duplicate check (D17's own first paragraph confirms they are supposed to be). Nothing in the interactor is "added afterwards for the build." An implementer who follows the analogy literally will write `event_params[:from_plan] = context.from_plan if context.from_plan.present?` alongside lines 22-23 and defeat D17 entirely: the check would then match on `from_plan`, and because D9's callback rewrites `from_plan` after creation, a genuine 24-hour duplicate whose `from_plan` differs would no longer be caught.

The right answer, derivable from the file: build `event_params` with `event_type`, `to_plan`, plus the existing conditional `stripe_subscription_id`/`amount` lines; run the `recent_duplicate` query and `context.fail!` against exactly that hash; THEN assign `event_params[:from_plan] = context.from_plan` on a new line after line 31 and before `organization.subscription_events.build(event_params)` at line 33. Do not copy the position of lines 22-23, and do not gate the `from_plan` assignment on `.present?` — D2/D19 require a nil `from_plan` to be built as nil on `subscription_create` rows so D9's callback can resolve it.

**Evidence:** app/interactors/create_subscription_event.rb:16-33 (event_params literal :16-20; conditional adds :22-23; duplicate query :26-30; context.fail! :31; build :33); SPEC.md D17 lines 268-276

## D17 (with D2)

### D17's cited precedent is inverted — the interactor adds stripe_subscription_id and amount BEFORE the duplicate check, so "the same sequence" puts from_plan inside the check D17 forbids

`d17-duplicate-check-precedent-inverted`

D17 states its rule ("`from_plan` is always omitted from it") and then justifies the sequence by analogy: "the same sequence the interactor already uses for `stripe_subscription_id` and `amount`." That analogy is backwards. In the current interactor those two keys are written into `event_params` at lines 22-23, and `.where(event_params)` runs at line 26 — they are added BEFORE the check and therefore participate in it, which is what D17's own first paragraph says they should do. Nothing in the interactor is "added afterwards for the build." An implementer who follows the cited precedent rather than the rule will put `from_plan` in the hash the duplicate check queries, silently defeating D17: two rows whose `from_plan` differs (the exact case D9's later `update_columns` write and the nil-from_plan subscription_create path make likely) would no longer be seen as duplicates. Correct sequence, which the code does not currently contain anywhere: build `event_params` with `event_type`, `to_plan`, and the two conditional keys; run `.where(event_params).where('created_at >= ?', 24.hours.ago).exists?`; then `event_params[:from_plan] = <resolved>` immediately before `organization.subscription_events.build(event_params)` at line 33.

**Evidence:** SPEC.md:270-275 (D17 rule + cited precedent); app/interactors/create_subscription_event.rb:16-20 (hash built), :22-23 (stripe_subscription_id/amount added), :26-29 (.where(event_params) duplicate check), :33 (.build)

## D18 (and D9's qualifying filter)

### The `credit`/`plato` substring guard must be nil-safe — house form is `.to_s` before `.include?`

`d18-nil-lookup-key-guard`

D18 says the interactor "bare-returns and creates no row when that key contains `credit` or `plato`" but does not say what happens when the destination lookup key is nil. Invoice lines can legitimately carry no lookup key: `charge_for_purchase` builds a top-up invoice from `Stripe::InvoiceItem.create(customer:, amount:, currency:, description:, metadata:)` with no `price:` at all, so `line.price&.lookup_key` is nil on that invoice — and D18 explicitly says the guard is supposed to cover top-ups that reach the interactor. A literal `lookup_key.include?('credit')` raises NoMethodError on nil (swallowed by the webhook's `rescue StandardError` at stripe_webhook_handler_job.rb:330, so the row silently never gets created). The right answer is derivable from the analog D9 names by method: `previous_main_plan_invoice` writes `lookup_key = listed_invoice.lines.data.first&.price&.lookup_key.to_s` and then `lookup_key.include?('credit') || lookup_key.include?('plato')`. Use the same `&.price&.lookup_key.to_s` form for D18's guard and for D9's relocated filter. Note this does not conflict with D19 — D19's "conversion is called only when the key is present" still governs the `assign_plan_name_from_lookup_key` call, which happens after the guard.

**Evidence:** app/jobs/stripe_webhook_handler_job.rb:389-397 (`previous_main_plan_invoice`, `.to_s` at :391); app/models/organization_ai_credit_purchase.rb:83-94 (`Stripe::InvoiceItem.create` with `amount:`, no `price:`); app/jobs/stripe_webhook_handler_job.rb:330 (the swallowing rescue)

## D19 (with D9, D16, D4)

### D9's relocated helper writes the literal `'canceled'` into `from_plan`, which is not a plan name — D19's vocabulary rule does not cover it and it must not be normalized

`d19-canceled-sentinel-not-a-plan-name`

D19 states `from_plan` and `to_plan` hold internal plan names. The helper D9 relocates does not always produce one: `previous_plan_name` returns the bare string `'canceled'` when the prior invoice belongs to a different subscription that Stripe reports as canceled (`return 'canceled' if previous_subscription.status == 'canceled'`, stripe_webhook_handler_job.rb:406), before any `assign_plan_name_from_lookup_key` call is reached. D9 explicitly requires that branch to move intact ("the `'canceled'` branch that retrieves the prior invoice's subscription"), so `'canceled'` will be persisted into `subscription_events.from_plan` — a plain `t.string` column with no validation (schema.rb:1189). An implementer holding D19's "plans are stored as plan names" alongside D9's "move the branch" has a visible conflict and may resolve it by mapping `'canceled'` through `assign_plan_name_from_lookup_key`, substituting a plan name, or dropping the branch. The right answer from the code: keep the literal `'canceled'` exactly as the current method emits it. It is safe because it never reaches the two substring classifiers — D4's `include?('free')` and D16's tier index both run inside `CreateSubscriptionEvent` before the row is saved, while D9's helper runs in the `after_commit` callback afterward, and D9 states it never changes `event_type`. Anyone verifying the value would find `'canceled'` contains no D16 tier substring (it would index to the `|| 0` fallback) and no 'free' — which is exactly why it must stay out of those paths, not why it needs converting. Note also that the existing enum comment already treats this as a first-class case: subscription_event.rb:11 documents `converted_to_paid` as "free → paid and canceled → paid". Second non-plan-name value already in the column, for the same reason: the backfill writes `from_plan: 'unknown'` (db/data/20260727185945_...rb:40), which the spec's DON'T FUCK WITH THIS section already calls a backfill artifact — and because `'unknown'` is not nil, those rows are correctly skipped by D9's "every row whose from_plan is nil" predicate.

**Evidence:** app/jobs/stripe_webhook_handler_job.rb:401-413 (`previous_plan_name`, `return 'canceled'` at :406); app/jobs/stripe_webhook_handler_job.rb:325 (the only current caller that can emit it); app/models/subscription_event.rb:11 (enum comment "canceled → paid"); db/schema.rb:1189 (`t.string "from_plan"`, unvalidated); app/services/stripe/subscription_status_checker.rb:113-119 (`assign_plan_from_lookup_key`, never reached on that branch); db/data/20260727185945_create_subscription_events_for_existing_paid_organizations.rb:40 (`from_plan: 'unknown'`)

## D2

### `OrganizationAiCreditPurchase#sync_grant` does not exist; the negative/positive line selection lives in `sync_subscription_invoice_grant`

`d2-sync-grant-does-not-exist`

D2 cites `OrganizationAiCreditPurchase#sync_grant` as the precedent for `lines.data.find { |line| line.amount.negative? }` / `.positive?`. There is no method named `sync_grant` anywhere in the repo — grepping it returns nothing. The real method is `OrganizationAiCreditPurchase#sync_subscription_invoice_grant(invoice:)`, and the selection sits inside its `when 'subscription_update'` branch. The identical expression also exists at `app/interactors/apply_ai_credit_upgrade.rb:41-42`. The expression the spec wants is quoted verbatim in D2's table, so nothing is blocked, but an implementer told to go read the precedent finds no such method.

**Evidence:** app/models/organization_ai_credit_purchase.rb:183 (`def sync_subscription_invoice_grant(invoice:)`), :206-208 (`when 'subscription_update'` / `old_line = invoice.lines.data.find { |line| line.amount.negative? }` / `new_line = invoice.lines.data.find { |line| line.amount.positive? }`); app/interactors/apply_ai_credit_upgrade.rb:41-42

### `OrganizationAiCreditPurchase#sync_grant` does not exist

`d2-sync-grant-misnamed`

D2 cites `OrganizationAiCreditPurchase#sync_grant` as the precedent for the negative/positive line selection. There is no method by that name. The `lines.data.find { |line| line.amount.negative? }` / `.positive?` pair lives in `OrganizationAiCreditPurchase#sync_subscription_invoice_grant(invoice:)` at lines 207-208, with an identical copy in `ApplyAiCreditUpgrade` at apply_ai_credit_upgrade.rb:41-42. Nothing changes in what gets written — D2 spells the selection out inline — but an implementer sent to read the named analog will not find it.

**Evidence:** app/models/organization_ai_credit_purchase.rb:183 (def sync_subscription_invoice_grant) and :207-208; app/interactors/apply_ai_credit_upgrade.rb:41-42

### `OrganizationAiCreditPurchase#sync_grant` does not exist — the negative/positive line analog is `#sync_subscription_invoice_grant`

`d2-sync-grant-method-name`

D2 cites "the one `OrganizationAiCreditPurchase#sync_grant` already uses for `subscription_update` invoices" as the source of the negative/positive line selection. There is no `sync_grant` method anywhere in the repo (grep for `sync_grant` returns nothing). The actual method is `OrganizationAiCreditPurchase#sync_subscription_invoice_grant`, and the line selection D2 means is in its `when 'subscription_update'` branch: `old_line = invoice.lines.data.find { |line| line.amount.negative? }` / `new_line = invoice.lines.data.find { |line| line.amount.positive? }`. Same file also confirms the D2 `subscription_create` contrast — its `when 'subscription_create', 'subscription_cycle'` branch uses `invoice.lines.data.first&.price&.lookup_key`. The behavior D2 specifies is unambiguous from D2's own table; only the pointer is wrong.

**Evidence:** app/models/organization_ai_credit_purchase.rb:183 (`def sync_subscription_invoice_grant(invoice:)`), :201 (`lines.data.first&.price&.lookup_key`), :206-216 (`when 'subscription_update'`, negative/positive `find`)

## D2 (both column-source tables), D5, D18

### Duck-typing the two Stripe object shapes raises NoMethodError — the only safe discriminator is `object.object` (or two distinct context keys)

`stripe-object-probe-raises`

D2 hands the interactor an invoice on `invoice.paid` and a subscription on `customer.subscription.deleted`, so the interactor must tell them apart before reading `billing_reason` / `lines` / `amount_paid`. The obvious probes do not return nil — they raise. `Stripe::StripeObject#method_missing` returns `@values[name]` only when the key is present in the API payload; otherwise it falls through to `super`, which raises `NoMethodError` (stripe_object.rb:373-413). A `Stripe::Subscription` payload has no `billing_reason`, `lines`, or `amount_paid` key, so `case stripe_object.billing_reason` written as the interactor's first branch raises on every cancellation. `respond_to?` IS safe (`respond_to_missing?` at :416-418 tests `@values.key?`), and the house discriminator already in this file is `object.object`, used at stripe_webhook_handler_job.rb:531 (`ap event.data.object.object`) — it is `'invoice'` vs `'subscription'`. Alternatively two distinct context keys sidestep the probe entirely: `Interactor::Context < OpenStruct` (context.rb:31), so an unset `context.invoice` / `context.subscription` returns nil, never raises, which is what makes the pre-classified entry shape from the two untouched `Organization` callers coexist with the Stripe-object entry shape.

**Evidence:** /Users/jessica/.rvm/gems/ruby-3.1.6/gems/stripe-9.4.0/lib/stripe/stripe_object.rb:373-413 and :416-418; /Users/jessica/wrk/wrk-corp/inflow-ats/app/jobs/stripe_webhook_handler_job.rb:531; /Users/jessica/.rvm/gems/ruby-3.1.6/gems/interactor-3.1.2/lib/interactor/context.rb:31

## D2 (with D11 and D5)

### D2's "a null `amount` therefore means the row came from `customer.subscription.deleted`" is contradicted by D11 — three other event types also produce null-amount rows, so it cannot be used to tell the interactor's input shapes apart

`d2-null-amount-discriminator-false`

D2 closes its column table with the inference: "A zero `amount_paid` creates no row, so `amount` is never persisted as zero from an invoice. A null `amount` therefore means the row came from `customer.subscription.deleted`." D11 keeps two callers untouched that both create rows with no `amount` at all: `Organization#handle_subscription_status_change_after_commit` (trial_started, organization.rb:1131 — passes to_plan and stripe_subscription_id only) and `Organization#log_assigned_free_plan_event` (assigned_free_plan_on_creation / assigned_free_plan, organization.rb:1236-1240 — passes neither amount nor stripe_subscription_id). So null `amount` covers four event types, not one. This matters at exactly the point the interactor has to disambiguate its three input modes (invoice object / subscription object / finished event_type with no object): `context.amount.blank?` and `amount.nil?` are not valid discriminators and would route trial_started and assigned_free_plan* calls into the `customer.subscription.deleted` branch, overwriting their event_type with `canceled_subscription` and their from_plan with `organization.plan`. The discriminator has to be the Stripe object itself — its presence, and for the invoice path `billing_reason`, which only an invoice carries (the analog `OrganizationAiCreditPurchase#sync_subscription_invoice_grant` branches on `invoice.billing_reason` at organization_ai_credit_purchase.rb:195-217).

**Evidence:** SPEC.md:60-61 (D2 inference); SPEC.md:175-178 (D11 untouched callers); app/models/organization.rb:1131, :1236-1240; app/interactors/create_subscription_event.rb:23 (amount omitted from event_params when absent); app/models/organization_ai_credit_purchase.rb:195-217

## D2 (with D4 and D18)

### D2's line-selection expressions chain `.price.lookup_key` off a `find` that returns nil on exactly the path D4 anticipates — and the analog D2 cites guards the line object, it does not safe-navigate

`d2-line-find-returns-nil-object`

D2 writes the source as one chained expression: `plan name from the price lookup key of lines.data.find { |line| line.amount.negative? }`. `Array#find` returns nil when no line matches, and `nil.price` raises NoMethodError. This is not a hypothetical path: D4's first rule is `converted_to_paid` when `from_plan` is nil, and the way a `subscription_update` invoice produces a nil `from_plan` is having no negative-amount line — a $0 free plan being upgraded mid-cycle yields a proration credit line of amount 0, and `0.negative?` is false. So the free-to-paid conversion, the feature's primary case, is precisely where the chain raises. The raise is swallowed by the `rescue StandardError` at stripe_webhook_handler_job.rb:332, so no row is created and nothing surfaces beyond a log line. The same applies to the positive line (`to_plan` on `subscription_update`) and to `lines.data.first` (`to_plan` on `subscription_create`). Note this is a nil LINE OBJECT, distinct from the already-reported nil LOOKUP-KEY string in D18's `credit`/`plato` guard — `.to_s` before `.include?` does not help here because the raise happens one step earlier. Right answer from the code, and the two forms differ: every `.first` site in the repo safe-navigates (`lines.data.first&.price&.lookup_key` — stripe_webhook_handler_job.rb:391, :409, :434, :587; organization_ai_credit_purchase.rb:201; apply_ai_credit_subscription.rb:51), while every `find { amount.negative?/positive? }` site assigns the line to a variable and guards the object (`old_line = ...; new_line = ...; if old_line && new_line` — organization_ai_credit_purchase.rb:207-209, apply_ai_credit_upgrade.rb:41-42). An implementer copying `sync_subscription_invoice_grant`, which D2 names as the analog, gets `old_line.price.lookup_key` with no safe navigation (organization_ai_credit_purchase.rb:210) because that analog's guard lives in the enclosing `if`, which D2's one-line phrasing drops.

**Evidence:** SPEC.md:43-44 (D2 table), SPEC.md:71 (D4 nil rule); app/models/organization_ai_credit_purchase.rb:207-211 (find → `if old_line && new_line` → `old_line.price.lookup_key`); app/interactors/apply_ai_credit_upgrade.rb:41-42; app/jobs/stripe_webhook_handler_job.rb:391, 409, 434 (`&.price&.lookup_key` house form), :332 (the rescue that swallows it)

## D2 / D17 / D1 (and the round-1 entry-shape BLOCKER)

### Classification must move above the duplicate check, and `context.event_type` is safe to read as the entry-shape discriminator

`d17-classify-before-duplicate-check`

Two things the signature work needs that the spec does not state, both with a code-determined answer.

(1) Discriminator: the round-1/2 resolution is that the interactor keeps its pre-classified entry shape alongside the new Stripe-object shape, but nothing says how it tells them apart or whether reading an absent key blows up. `Interactor::Context < OpenStruct` (interactor-3.1.2, context.rb:31), so `context.event_type` returns nil — not NoMethodError — on the two webhook calls that stop passing it, and the Stripe-object key returns nil on the two `Organization` calls D11 leaves untouched. `context.event_type.present?` is therefore a working outer discriminator and needs no extra argument.

(2) Ordering, which is the part that produces wrong rows: `event_type`, `to_plan` and `amount` are all now derived inside the interactor, and D17 puts all three inside the 24-hour duplicate check. The check today sits at create_subscription_event.rb:26-29, ABOVE where any derivation would naturally be appended. If the derivation is added below it, the check runs with `event_type: nil`; `event_type` is `null: false` (db/schema.rb:1188), so `where(event_type: nil)` matches no row, redelivered `invoice.paid` webhooks create duplicate rows, and `build(event_type: nil)` falls to the column default `0` — a `pending` row, which D1 declares a defect to investigate. The whole derive → D18 guard → D19 convert → D4/D16 classify sequence has to run before the `organization.subscription_events.where(event_params)` line, not after it.

**Evidence:** /Users/jessica/wrk/wrk-corp/inflow-ats/app/interactors/create_subscription_event.rb:16-33; /Users/jessica/wrk/wrk-corp/inflow-ats/db/schema.rb:1188; /Users/jessica/.rvm/gems/ruby-3.1.6/gems/interactor-3.1.2/lib/interactor/context.rb:31

## D2 with D3 and D6

### D2's three columns are `invoice.billing_reason` values, and the analog it cites is named sync_subscription_invoice_grant, not sync_grant

`d2-billing-reason-and-analog-name`

D2's column headers subscription_update / subscription_create / subscription_cycle are Stripe billing_reason values, but the spec never names invoice.billing_reason as the discriminator, and OrganizationAiCreditPurchase#sync_grant does not exist — the method holding the negative/positive line selection D2 points at is #sync_subscription_invoice_grant(invoice:) (organization_ai_credit_purchase.rb:183), whose `case billing_reason` at :199-217 is exactly the shape D2 describes: subscription_create/subscription_cycle read lines.data.first, subscription_update reads `lines.data.find { |line| line.amount.negative? }` and `.positive?` (:207-208). Second thing the case must settle: billing_reason values outside those three (manual, subscription_threshold) get no row under D2/D3, where today any invoice.paid with amount_paid > 0 produces one (stripe_webhook_handler_job.rb:317-330) — the else of that case is a bare return, same as D15's.

**Evidence:** SPEC D2, D3, D6; app/models/organization_ai_credit_purchase.rb:183, 199-217; app/interactors/apply_ai_credit_upgrade.rb:41-42; app/jobs/stripe_webhook_handler_job.rb:317-330

## D2, D5, D10, D11

### The context key for the Stripe object the interactor receives is never named, and D2 gives the interactor two different object shapes to tell apart

`d2-d10-stripe-object-context-key-unnamed`

D2 gives `CreateSubscriptionEvent` two source tables — one where the object is an invoice (`invoice.subscription`, `invoice.amount_paid`, `lines.data`) and one where the object is a subscription (`the subscription's id`, `organization.plan`) — and D10 says the interactor prints "the Stripe object it receives." D11 keeps two callers that pass no Stripe object at all and supply a finished `event_type` (organization.rb:1131 trial_started; organization.rb:1236 log_assigned_free_plan_event). So the interactor has three input modes and the spec names no context key for any of them, nor how it distinguishes an invoice from a subscription. Two things are derivable from the code and should be settled before implementation rather than invented: (1) the only non-AI precedent in the repo for identifying a Stripe object's type is the object's own `object` attribute — `ap event.data.object.object`; (2) the `invoice:` context-key form exists only in AI interactors (`context.invoice` in apply_ai_credit_upgrade.rb:27 and apply_ai_credit_subscription.rb:16), which are excluded as convention analogs, so there is no non-AI house form for a Stripe-object context key. Whichever is picked, the two replaced call sites (stripe_webhook_handler_job.rb:216 and :322) and the interactor must agree on it.

**Evidence:** app/interactors/create_subscription_event.rb:10-23 (current context reads: `context.organization`, `context.event_type`, `context.from_plan`, `context.to_plan`, `context.stripe_subscription_id`, `context.amount`); app/models/organization.rb:1131, :1236; app/jobs/stripe_webhook_handler_job.rb:216-222, :322-329, :531 (`ap event.data.object.object`); app/interactors/apply_ai_credit_upgrade.rb:27; app/interactors/apply_ai_credit_subscription.rb:16

## D3 / D2

### The `if object.amount_paid.to_i > 0` guard at stripe_webhook_handler_job.rb:317 is the only implementation of "a zero-amount invoice creates nothing" and must survive the call-site replacement

`d3-zero-amount-guard-placement`

Line 317 is the enclosing conditional of the call being replaced, so it is easy to delete along with lines 318-330. It invokes none of D11's five deletions, so it is not part of the required replacement and stays. If it goes and nothing replaces it, a trial's $0 `subscription_create` invoice reaches the interactor and produces a `converted_to_paid` row — and the amount would persist as 0, not nil, because the existing conditional is `event_params[:amount] = context.amount if context.amount.present?` and `0.present?` is true in ActiveSupport. That breaks D2's stated invariant that "a null `amount` therefore means the row came from `customer.subscription.deleted`" and fires a false `converted_to_paid` PostHog event with `$set is_paying: true` at trial start. Either keep line 317 or add the equivalent guard inside the interactor — exactly one, never zero.

**Evidence:** app/jobs/stripe_webhook_handler_job.rb:317, app/interactors/create_subscription_event.rb:23, SPEC.md D2 ("A zero `amount_paid` creates no row") and D3

## D6 / D2

### The subscription_cycle skip belongs in the interactor, and the billing_reason branch needs no dispatching default

`d6-subscription-cycle-skip-location`

D2's first table is the interactor's column-source table and it gives `subscription_cycle` its own column with `—` in every row, so the interactor is what knows about `subscription_cycle`; and "DON'T FUCK WITH THIS" limits job changes to the two call-site replacements plus the five D11 deletions, which rules out a job-side `billing_reason` guard. The skip is therefore a bare return inside the interactor (bare, per core_critical_rules.md rule 8). Separately, `invoice.billing_reason` takes values outside the table's three — `manual` and `subscription_threshold` both occur on subscription invoices and would reach the interactor. The `case invoice.billing_reason` must have no dispatching `else`: an unlisted billing_reason creates no row, per D3 and D1's rule that no row is ever deliberately saved as `pending`. The house precedent for branching on this field is the same-shaped `case billing_reason` in `OrganizationAiCreditPurchase#sync_subscription_invoice_grant`, which also falls through to no action for unlisted reasons.

**Evidence:** SPEC.md D2 table 1 and D6; app/jobs/stripe_webhook_handler_job.rb:594; app/models/organization_ai_credit_purchase.rb:199-217; cursor_rules/core_critical_rules.md rule 8

## D9

### The `from_plan` resolution also fires for `trial_started` and `assigned_free_plan*` rows — one has no `stripe_subscription_id`, and the customer may be nil, so the helper needs a nil-triggering-invoice bail-out and the house `stripe_customer_id.present?` guard

`d9-helper-runs-on-rows-with-no-stripe-context`

"Runs for every row whose `from_plan` is nil" is not limited to the `subscription_create` conversion. Two existing creation paths produce nil `from_plan` rows: `Organization#handle_subscription_status_change_after_commit` creates `trial_started` with only `to_plan` and `stripe_subscription_id` (organization.rb:1131), and `log_assigned_free_plan_event` creates `assigned_free_plan_on_creation`/`assigned_free_plan` with `from_plan: previous_plan`, which is nil for the nil branch of `assigned_free_plan?`, and never passes `stripe_subscription_id` at all (organization.rb:1223-1241). Consequences the implementer must handle: (1) D9's qualifying filter rejects invoices with no `subscription`, so no qualified invoice can equal a nil `stripe_subscription_id` — the triggering-invoice lookup returns nil and the helper must bare-return before anything dereferences `.created` on it, otherwise the method-level `rescue StandardError` absorbs a NoMethodError and logs `ap e` on a routine path. (2) `Stripe::Invoice.list(customer: <nil>, limit: 20)` is still a live API call: stripe-9.4.0 `Util.flatten_params` keeps the nil pair and `Util.url_encode` renders it `customer=`, so the customer filter is simply empty. The codebase's only other `Stripe::Invoice.list` sits behind `return unless stripe_customer_id.present?` (organization.rb:705-708) — the same guard belongs in front of this one, and `update_stripe_customer` (organization.rb:742) and `stripe_customer` (organization.rb:470-472) use the same form. (3) For `trial_started` the helper does find a triggering invoice and `update_columns(from_plan: ...)` writes a value onto a row that creation path has never written `from_plan` on; note `previous_plan_name`'s early branch can return the literal string `'canceled'` rather than a plan name.

**Evidence:** app/models/organization.rb:1131, :1223-1241, :703-708, :470-472, :742; app/jobs/stripe_webhook_handler_job.rb:389-395 (existing filter), :401-413; /Users/jessica/.rvm/gems/ruby-3.1.6/gems/stripe-9.4.0/lib/stripe/util.rb:206-238

### D9's `from_plan` helper fires two synchronous Stripe HTTP calls inside web requests, because two of the three SubscriptionEvent creation sites are not the webhook job

`d9-helper-runs-in-web-request`

D9 scopes the resolution to "every row whose `from_plan` is nil" and the spec discusses only the `invoice.paid` path. But `CreateSubscriptionEvent` has three callers, and two of them produce nil-`from_plan` rows outside `StripeWebhookHandlerJob`:

1. `Organization#handle_subscription_status_change_after_commit` calls `CreateSubscriptionEvent.call(organization: self, event_type: 'trial_started', to_plan: plan, stripe_subscription_id: stripe_subscription_id)` — it passes no `from_plan` at all, so every `trial_started` row has `from_plan` nil and will always enter D9's helper.
2. `Organization#log_assigned_free_plan_event` passes `from_plan: previous_plan`, and `assigned_free_plan?` explicitly admits nil (`['plan_no_plan', 'plan_simple_ats_free', nil].include?(previous_plan)`).

Both run from `handle_after_commit_on_update` (registered `after_commit :handle_after_commit_on_update, on: [:update]`), which `Organization#sync_with_stripe` triggers. `sync_with_stripe` is called synchronously from `Api::V1::BillingController` at four in-request sites (lines 171, 211, 260, 624), not only from the webhook job. So after this change a `POST` that creates or refreshes a subscription runs `Stripe::Invoice.list(customer: ..., limit: 20)` and possibly `Stripe::Subscription.retrieve` inside the HTTP request.

This is `cursor_rules/backend/background_jobs.md` §0b: "Always Use Background Jobs For: 1. External API calls - Any sync operation with 3rd party services" and "5. Long-running tasks - Operations taking >2 seconds".

Two things the implementer needs and the spec does not supply:
- The existing `previous_main_plan_invoice(invoice)` reads `invoice.customer`, which is guaranteed present. The relocated helper has no invoice and must read `organization.stripe_customer_id`, which is nullable (`db/schema.rb:1058`, no `null: false`). The house form for the missing precondition is a bare guard — `return unless organization.stripe_customer_id.present?` — per `_base.md` "Guard clauses for early exits" and core rule 8.
- As written, D9 also writes a resolved `from_plan` onto `trial_started` rows, which carry nil today. D11 says the `trial_started` caller is untouched, but the row it produces is not. Whether that is intended, and whether the helper should be gated by `event_type`, is Jessica's call — an implementer following D9 literally will ship the in-request Stripe calls.

**Evidence:** app/models/organization.rb:1131; app/models/organization.rb:1226; app/models/organization.rb:1236-1241; app/models/organization.rb:59; app/models/organization.rb:1023-1029; app/controllers/api/v1/billing_controller.rb:171,211,260,624; app/jobs/stripe_webhook_handler_job.rb:389-396; db/schema.rb:1058; cursor_rules/backend/background_jobs.md:43-51

### The "qualifying filter" D9 describes is not what `previous_main_plan_invoice` implements — two of its three rejections do not exist and must be written new

`d9-qualifying-filter-not-in-the-analog`

D9 names the filter as a thing being moved: "the qualifying filter that rejects invoices with no `subscription` and no line-item lookup key and rejects keys containing `credit` or `plato`." The real `previous_main_plan_invoice` reject block implements ONLY the credit/plato test: `lookup_key = listed_invoice.lines.data.first&.price&.lookup_key.to_s; lookup_key.include?('credit') || lookup_key.include?('plato')`. An invoice with no subscription, or with no line-item lookup key, yields `""` from the `.to_s` and is KEPT. An implementer who relocates the method verbatim (the natural reading of "move to the callback") gets one rejection, not three.

This is load-bearing for both halves of D9's recovery. WWR and WhatJobs job-listing invoices are created on `organization.stripe_customer_id` from a bare `Stripe::InvoiceItem` with an `amount` and no price (board_wwr_listing.rb:130-151, board_what_jobs_listing.rb:172-191), so they carry no subscription and no line-item lookup key, and they appear in the same `Stripe::Invoice.list(customer:)` page. Without the two missing rejections such an invoice can become "the most recent qualified invoice created before" the triggering one, and `previous_plan_name`'s `previous_invoice.subscription != invoice.subscription` guard is then satisfied by nil, reaching `Stripe::Subscription.retrieve(nil)`. stripe 9.4.0 raises `Stripe::InvalidRequestError` there (api_resource.rb:69-77, `unless (id = self["id"])`), which D9's method-level `rescue StandardError` swallows — so the failure mode is a silently nil `from_plan` on every organization that bought a job-listing more recently than its last plan invoice, not a visible error.

The right answer derivable from the code: the reject block needs `listed_invoice.subscription.blank?` and a blank-lookup-key rejection added alongside the existing credit/plato test (house nil-safety is the existing `.to_s` before `.include?`).

**Evidence:** app/jobs/stripe_webhook_handler_job.rb:389-396 (reject block, credit/plato only); app/jobs/stripe_webhook_handler_job.rb:401-407 (previous_plan_name's `previous_invoice.subscription != invoice.subscription` → `Stripe::Subscription.retrieve(previous_invoice.subscription)`); app/models/board_wwr_listing.rb:130-151; app/models/board_what_jobs_listing.rb:172-191; /Users/jessica/.rvm/gems/ruby-3.1.6/gems/stripe-9.4.0/lib/stripe/api_resource.rb:69-77; SPEC.md D9 lines 124-136

## D9 (with core_critical_rules.md rule 8)

### The trailing bare `return` in D9's rescue is load-bearing — `ap` returns its argument, so dropping it as "redundant nil" writes the exception object into `from_plan`

`d9-ap-returns-its-argument`

`Kernel#ap` in the installed awesome_print 1.9.2 is `def ap(object, options = {}); puts object.ai(options); object unless AwesomePrint.console?; end` — outside a console (i.e. in the Sidekiq worker and in web requests) it RETURNS the object it printed. `Rails.logger.error(e)` returns `true`. So a rescue body of `Rails.logger.error ...` + `ap e` in any order leaves the method returning a truthy value, not nil. D9's helper is the one method in this feature whose return value is consumed: the callback assigns it and, "when the returned value is present", runs `update_columns(from_plan: <resolved>)`. A `StandardError` instance answers `present?` with true (Object#blank? is `!self` for objects with no `empty?`), so the helper's rescue would write the exception into the `from_plan` string column — persisting e.g. `No such invoice: 'in_...'` and sending it to PostHog as `from_plan`, silently, on exactly the failure path D9 says must yield nil. D9 already specifies the correct code ("logs, `ap e`, then bare-returns"), but core_critical_rules.md rule 8 pushes an implementer to delete it: "Our code is optimized so that early returns are always the default `nil` that Ruby returns implicitly. We don't explicitly state it." Every house rescue block reinforces the deletion, because none of them ends in a bare `return` — their return values are discarded (stripe_webhook_handler_job.rb:224-227, :332-335, :337-346; organization_ai_credit_purchase.rb; posthog/track.rb:18-19; the background_jobs.md rescue examples). Right answer: the bare `return` must be the LAST statement of the helper's rescue body, and it is not a rule-8 violation to keep it — rule 8 governs guard clauses at the top of a method, not the terminal statement of a rescue whose return value is read by the caller.

**Evidence:** /Users/jessica/.rvm/gems/ruby-3.1.6/gems/awesome_print-1.9.2/lib/awesome_print/core_ext/kernel.rb:19-22; Gemfile.lock:104 (awesome_print 1.9.2); cursor_rules/core_critical_rules.md:154; SPEC.md D9 lines 152-163; app/jobs/stripe_webhook_handler_job.rb:224-227, 332-335; app/services/posthog/track.rb:18-19; cursor_rules/backend/background_jobs.md:185-191, 299-302

## D9 (with the "Do not unify the two line selections" bullet in DON'T FUCK WITH THIS)

### D9's relocated helper reads prior-invoice lookup keys from `lines.data.first` — the "do not unify" warning does not apply to it, and applying it there would break the relocation

`d9-helper-keeps-lines-data-first`

The code D9 relocates contains two `lines.data.first` reads, and BOTH must survive verbatim in the new `SubscriptionEvent` helper: the qualifying-filter read at stripe_webhook_handler_job.rb:391 (`listed_invoice.lines.data.first&.price&.lookup_key`, which decides whether a listed invoice is credit/plato) and the prior-plan read at :409 (`previous_invoice.lines.data.first&.price&.lookup_key`, which becomes the returned `from_plan`). An implementer who has just read the DON'T FUCK WITH THIS bullet — "Using `lines.data.first` on a `subscription_update` invoice fails silently, taking whichever line Stripe happened to return first" — will see that many prior invoices in the `Stripe::Invoice.list` result ARE `subscription_update` proration invoices, and is likely to "fix" the helper by applying D2's negative/positive line selection there too. That is wrong. D2's negative/positive selection is scoped exclusively to the TRIGGERING invoice inside `CreateSubscriptionEvent`; the DON'T FUCK WITH THIS bullet is scoped to that same pair of interactor reads (`subscription_update` vs `subscription_create`). D9 instead says the helper makes "the same `created` comparison `StripeWebhookHandlerJob#previous_main_plan_invoice` makes today," i.e. a verbatim relocation. Applying negative/positive selection in the helper would also change the filter's meaning: a prior invoice with no negative line would yield a nil key and, under D9's new "rejects invoices with … no line-item lookup key" rule, be dropped from the qualified list entirely — which would then also break D9's recovery of the triggering invoice, since the triggering invoice is itself found "within the qualified invoices." The cited analog agrees with the split: `OrganizationAiCreditPurchase#sync_subscription_invoice_grant` uses `invoice.lines.data.first&.price&.lookup_key` for `subscription_create`/`subscription_cycle` (organization_ai_credit_purchase.rb:200-201) and reserves negative/positive selection for `subscription_update`. Right answer: keep `lines.data.first&.price&.lookup_key` in both places inside D9's helper.

**Evidence:** app/jobs/stripe_webhook_handler_job.rb:389-396 (previous_main_plan_invoice, `.to_s` reject filter at :391), :401-413 (previous_plan_name, prior key at :409); app/models/organization_ai_credit_purchase.rb:199-201 (analog's `subscription_create`/`subscription_cycle` branch uses lines.data.first); SPEC.md D9 lines 129-136 and the "Do not unify the two line selections" bullet at SPEC.md lines 338-342

## D9 / D8 / D11 / D13

### Every `trial_started` row has a nil `from_plan`, so D9's Stripe helper fires on trial starts and can write a `from_plan` onto them

`d9-resolution-fires-on-trial-started-rows`

D9 scopes the resolution to "every row whose `from_plan` is nil," and the spec discusses only `subscription_create` conversions. But `Organization#handle_subscription_status_change_after_commit` passes NO `from_plan` argument at all — `CreateSubscriptionEvent.call(organization: self, event_type: 'trial_started', to_plan: plan, stripe_subscription_id: stripe_subscription_id)` — so a `trial_started` row's `from_plan` is nil 100% of the time, and its `stripe_subscription_id` IS set. That combination satisfies D9's triggering-invoice recovery: a trialing subscription's $0 Stripe invoice has a `subscription` and a non-credit/non-plato line-item lookup key, so it passes the qualifying filter and matches the row's `stripe_subscription_id`. Consequences the spec does not name: (a) every trial start now issues `Stripe::Invoice.list`, plus a conditional `Stripe::Subscription.retrieve` when the prior qualified invoice belongs to a different subscription — two new Stripe API calls on a path that made zero before; (b) if the org had any prior qualified invoice (a free-plan subscription invoice, or a canceled prior subscription), the helper resolves a value and the callback runs `update_columns(from_plan: <resolved>)` on a `trial_started` row, so `posthog_properties` now sends `from_plan` on the `trial_started` event where today it is absent — D13 says "Nothing else about the PostHog payload changes" and D11 declares the trial_started caller untouched. The implementer must decide this consciously rather than discover it. The other two nil-`from_plan` candidates are NOT live: `assigned_free_plan_on_creation`/`assigned_free_plan` pass `from_plan: previous_plan` where `previous_plan` is practically never nil (organizations.plan has DB default 101 = `plan_no_plan`, db/schema.rb:1055 + organization.rb:95), and if one ever were nil those rows carry no `stripe_subscription_id` (organization.rb:1236-1241) so D9's filter — which rejects invoices with no `subscription` — can never match, yielding nil and no write. Note also that stripe-9.4.0's `Util.flatten_params` does not drop nil values (util.rb:222-239), so `Stripe::Invoice.list(customer: nil)` would transmit `customer=` rather than omitting the filter; a `stripe_customer_id.present?` bail-out in the helper is the house guard-clause form and costs one line.

**Evidence:** app/models/organization.rb:1131 (no from_plan arg); app/models/organization.rb:1236-1241, 1222-1228; app/models/organization.rb:95; db/schema.rb:1055; app/models/subscription_event.rb:31, 60, 63-85; SPEC.md D9 lines 124-136; /Users/jessica/.rvm/gems/ruby-3.1.6@wrkhq-gemset-v2/gems/stripe-9.4.0/lib/stripe/util.rb:222-239

## D9 and D4 (code_style_and_structure.md "Method Return Patterns"; core_critical_rules.md rule 8)

### The three value-returning guard clauses this feature relocates are 3 of only 4 in all of `app/` — the new helper and the new event_type selection must use if/elsif/else, not `return '<value>' if`

`value-returning-guard-clauses`

cursor_rules/backend/code_style_and_structure.md "Method Return Patterns" says "Use guard clauses only for early exits without values. Never use guard clauses to return a value," and core_critical_rules.md rule 8 permits only bare `return` (its single exception is returning an error message). Counted across `app/models`, `app/services`, `app/jobs`, `app/interactors`: 409 bare `return if/unless` versus 4 value-returning guards — and three of those four are the exact lines this feature deletes and re-homes (`return 'canceled' if previous_subscription.status == 'canceled'` at stripe_webhook_handler_job.rb:406 inside `previous_plan_name`; `return 'trial_converted_to_paid' if trial_conversion?(...)` at :428 and `return 'converted_to_paid' unless PAID_PLANS.include?(previous_plan)` at :431 inside `subscription_event_type_for`; the fourth is subscription_status_checker.rb:114). D11 deletes all three methods, so the pattern's only real cluster in the codebase disappears — and an implementer transcribing them reintroduces it in two brand-new places: D9's public `from_plan` helper on `SubscriptionEvent` (the `'canceled'` branch) and D4's ordered `event_type` selection in `CreateSubscriptionEvent`. Right answer, and it is what the surviving analogs do: bare `return`/`return unless x` only for the bail-outs D9 and D4 actually specify (nothing qualified, no row when the plans are equal, no row otherwise), with the value selection expressed as one `if/elsif/else` whose value is the method's implicit return — the shape of `downgrade_detected?` (stripe_webhook_handler_job.rb:508-519, bare-value guards then a trailing expression) and of `subscription_event_type_for`'s own tail (:436-444). Note the interactor's D4 bail-outs are bare returns out of `call`, which is correct and unaffected.

**Evidence:** cursor_rules/backend/code_style_and_structure.md:49-54; cursor_rules/core_critical_rules.md:152-184 (rule 8, incl. the error-message exception at :178-183); app/jobs/stripe_webhook_handler_job.rb:401-413, 427-445, 508-519; app/services/stripe/subscription_status_checker.rb:113-119; SPEC.md D4 lines 67-79, D9 lines 128-136, D11 lines 179-181

## D9 vs D2 (subscription.deleted table), D5, D19

### D9's flat "`organization.plan` is not read at creation" contradicts D2, D5 and D19, which all require the interactor to read it on the `customer.subscription.deleted` path

`d9-vs-d2-d5-organization-plan-at-creation`

D9 states without qualification: "`organization.plan` is not read at creation." "At creation" is the interactor. But D2's `customer.subscription.deleted` table gives `from_plan` = `organization.plan`; D5 restates it standalone ("`canceled_subscription`, `from_plan` from `organization.plan`"); D19 cites `canceled_subscription` as one of the three sites that "already write" internal plan names, which is that same read. D9's supporting rationale is scoped to `invoice.paid` ordering against `customer.subscription.updated`, but the leading sentence is not scoped, and D9's next paragraph ("It runs before dispatch") keeps the reader inside the callback.

The right answer is derivable and is D2/D5/D19: on the `customer.subscription.deleted` path the interactor reads `organization.plan` for `from_plan`; D9's prohibition applies only to the `invoice.paid` path, where the racy write happens. The existing call site already does exactly this at stripe_webhook_handler_job.rb:219 (`from_plan: organization.plan`), and the comment above it (lines 214-215) states the reasoning: cancelling changes subscription status, not plan, so the column still holds the plan they are leaving.

If an implementer applies D9's sentence literally and drops `organization.plan` from the cancellation path, every `canceled_subscription` row is saved with `from_plan: nil`. That row then satisfies D9's own trigger ("runs for every row whose `from_plan` is nil"), so each cancellation additionally fires `Stripe::Invoice.list` plus a conditional `Stripe::Subscription.retrieve` from the after_commit callback and writes an invoice-derived `from_plan` via `update_columns` — a materially different implementation from the one D2's table specifies. Note the ordering that makes the correct read safe: `organization&.update_column(:subscription_canceled_at, ...)` at stripe_webhook_handler_job.rb:208 runs before the `CreateSubscriptionEvent.call` at line 216, and `sync_with_stripe` on that branch is gated at line 205 by `stripe_subscription_id == organization&.stripe_subscription_id`.

**Evidence:** SPEC.md:144-148 (D9 "`organization.plan` is not read at creation"); SPEC.md:50-58 (D2 subscription.deleted table, `from_plan` = `organization.plan`); SPEC.md:83 (D5); SPEC.md:299-302 (D19); app/jobs/stripe_webhook_handler_job.rb:213-222 (existing call site, `from_plan: organization.plan` at :219, comment at :214-215); app/jobs/stripe_webhook_handler_job.rb:205,208 (sync_with_stripe identity gate, subscription_canceled_at write ordering); app/models/organization.rb:574 (`attributes['plan'] = assign_plan_name_from_lookup_key(...)` — the racy write D9's rationale is actually about)

## D9 with D15 and D11

### D9's from_plan resolution runs before the case, so it also fires on the rows the two untouched Organization callers create

`d9-resolution-fires-on-untouched-rows`

D9 scopes the helper to "every row whose from_plan is nil" and D15 puts it before the case, so it runs for rows whose event_type lands in the bare-return else. Two live producers create nil-from_plan rows: the trial_started call passes no from_plan at all (organization.rb:1131), and log_assigned_free_plan_event passes previous_plan, which assigned_free_plan? explicitly allows to be nil (organization.rb:1222-1227, 1239). Consequences the code determines: assigned_free_plan_on_creation / assigned_free_plan rows carry no stripe_subscription_id, and D9's qualifying filter rejects invoices with no subscription, so no qualified invoice can ever match nil — the helper issues one Stripe::Invoice.list and returns nil with no write; when the organization has no stripe_customer_id (e.g. Cypress orgs created with plan_ats_tier_free_v2 at app/controllers/cypress/organizations_controller.rb:38) that request still goes out as `customer=`, because stripe-9.4.0 keeps nil values in flatten_params and url_encode(nil) is "" (util.rb:214-220, 222-239); the helper's rescue absorbs whatever Stripe answers. trial_started rows DO carry stripe_subscription_id, so the helper can resolve and update_columns a from_plan onto them, and posthog_properties then sends a from_plan on trial_started events that never carried one.

**Evidence:** SPEC D9, D11, D15; app/models/organization.rb:1131, 1222-1227, 1236-1241; app/models/subscription_event.rb:31-55, 63-85; app/jobs/stripe_webhook_handler_job.rb:389-396; app/controllers/cypress/organizations_controller.rb:38; stripe-9.4.0/lib/stripe/util.rb:214-239

