# 00 — MASTER MAP: Hiring-Stage-Move Webhooks

Synthesis of the five investigation docs. This is the skeleton-and-trigger reference for
adding three new outbound webhooks — **moved-to-in_process, moved-to-archived,
moved-to-hired** — on top of the existing `RegisteredWebhook` outbound system.

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.hiring-stage-move-webhooks`

**Source docs (read these for full code):**
- `01-outbound-webhook-infra.md` — the `RegisteredWebhook` skeleton (model/table/controller/policy/routes/frontend, delivery job, serializer, gaps).
- `02-new-job-application-webhook.md` — the candidate-create webhook analog + the **inbox-already-covered** linkage.
- `03-zapier-hired-endpoint.md` — the Zapier "hired" *poll* (current-state, NOT an event) + canonical `kind_hired` token.
- `04-hiring-stage-move-pipeline.md` — every move path funnels through `JobApplication#track_movement`; existing move side-effects.
- `05-hiring-stage-visit-and-data-models.md` — `HiringStageVisit` schema + last/new-stage derivation + payload model menu + PII notes.

---

## 1. EXECUTIVE MAP

### The existing skeleton (reuse wholesale)
There is ONE outbound-webhook subsystem: the `RegisteredWebhook` model. "Event types" are
NOT a registry — they are integer values of the `kind` enum on that one model. Two exist
today (`new_job_application: 0`, `new_published_job: 1`), each owned by an Organization
(`has_many :registered_webhooks, as: :owner`), one row per kind per org, holding only a
`url`. A subscriber is "registered" purely by an `Organization` having a
`registered_webhooks` row of that kind with a `url`.

Each event has its OWN delivery job (`RegisteredWebhooks::<Event>Job`) and its OWN slim
delivery serializer (`Api::V1::RegisteredWebhooks::<Event>Serializer` with a hardcoded
`event_type` string). The fire pattern is identical everywhere:

```ruby
webhook = org.registered_webhooks.find_by(kind: :<event>)
RegisteredWebhooks::<Event>Job.perform_later(record_id, webhook.id) if webhook.present?
```

Delivery is fire-and-forget: `Faraday.post(url, Serializer.new(record))`, an ownership
re-guard, two rescues logged via `ap`. **No signing, no secret, no retry, no timeout, no
response-status check, no Slack alert, no audit row, no event envelope.** (See §6 RISKS.)

### How the three new webhooks sit on top
The four `HiringStage#kind` values map one-to-one to candidate pipeline states:

| HiringStage kind | int | New webhook? | Why |
|---|---|---|---|
| `kind_inbox` | 0 | **NO — already covered** | A new application lands in inbox at create; that create already fires `new_job_application` (see §1 inbox linkage). |
| `kind_in_process` | 1 | **YES (new)** | move INTO an in-process stage |
| `kind_archived` | 2 | **YES (new)** | move INTO the archived stage |
| `kind_hired` | 3 | **YES (new)** | move INTO the hired stage |

So three new `kind` enum values (next integers `2, 3, 4`), three new delivery jobs, three
new delivery serializers, and ONE new trigger call site inside the existing move funnel
(`JobApplication#track_movement`) that dispatches on the destination stage's `kind`. Every
other piece (table, controller, policy, routes, management serializer, frontend config UI)
is generic and reused unchanged except for surfacing the three new kinds in the frontend
dropdown.

**Inbox-already-covered linkage (verbatim).** A brand-new `JobApplication` gets the inbox
stage before save:
```ruby
# job_application.rb
before_validation :set_initial_hiring_stage
def set_initial_hiring_stage
  self.hiring_stage_id = job.inbox_hiring_stage.id if hiring_stage_id.nil? && job.inbox_hiring_stage
end
# job.rb
def inbox_hiring_stage
  hiring_stages.find_by(kind: 'kind_inbox')
end
```
The create then fires `after_commit :enqueue_new_job_application, on: [:create]` →
`new_job_application` webhook. "Landing in inbox" IS a create, already emitted. The three
new webhooks fire only on **stage transitions of existing applications** (the
`on: [:update]` path), never on create.

---

## 2. STRUCTURAL MANIFEST (the skeleton the new webhooks must match)

Analog = the `new_job_application` + `new_published_job` webhooks. `S` = SHARED
infrastructure (reuse as-is). `P` = PER-EVENT (must create one per new webhook). `X` =
EXTEND a shared file (add a row/value, do not recreate).

| # | Artifact | File / location | Reads / writes | S / P / X | New-webhook action |
|---|---|---|---|---|---|
| 1 | Subscription model | `app/models/registered_webhook.rb` | `kind`, `url`, `owner_id`, `owner_type` | **X** | Add 3 enum values (`2,3,4`). No new model. |
| 2 | Subscription table | `registered_webhooks` (`db/schema.rb:1138`) | same cols | **S** | **No migration** — `kind` is already int; no new column needed (no secret/active/event-id). |
| 3 | Owner association | `organization.rb:23` `has_many :registered_webhooks, as: :owner` | — | **S** | none |
| 4 | Registration controller | `app/controllers/api/v1/registered_webhooks_controller.rb` (`index/create/update/destroy/all`) | upserts by `find_or_initialize_by(kind:)` | **S** | none — `all` handles any kind; `params.permit(:url, :kind)`. |
| 5 | Policy | `app/policies/registered_webhook_policy.rb` (org-admin gated) | — | **S** | none |
| 6 | Routes | `config/routes.rb:328` `resources :registered_webhooks … collection { put :all }` | — | **S** | none |
| 7 | Management serializer | `app/serializers/api/v1/registered_webhook_serializer.rb` (`:id, :url, :kind`) | — | **S** | none |
| 8 | Frontend type/hook/UI | `shared/types/registeredWebhooks.ts`, `useRegisteredWebhooks.ts`, `AccountIntegrationsPolymerWebhooks.tsx` | — | **X** | Add the 3 new kinds to the dropdown/list so orgs can register URLs. |
| 9 | Base job class | `app/jobs/application_job.rb` (bare `ActiveJob::Base`, no retry) | — | **S** | none (inherits the no-retry baseline). |
| 10 | **Trigger callback** | `JobApplication#track_movement` (`after_commit :track_movement, on: [:update]`) | reads `saved_change_to_hiring_stage_id?`, `hiring_stage_id_before_last_save`, dest `hiring_stage.kind` | **P (single new site, dispatches 3 ways)** | Add fire block after `create_hiring_stage_visit`, branch on destination kind. |
| 11 | **Delivery job** | `app/jobs/registered_webhooks/<event>_job.rb` | `perform(job_application_id, registered_webhook_id)`; ownership guard `job_application.job.organization_id == webhook.owner_id`; `Faraday.post(url, Serializer.new(ja))`; 2 rescues `ap` | **P** | Create 1 per event (or 1 parametrized — see §6 Q). |
| 12 | **Delivery serializer** | `app/serializers/api/v1/registered_webhooks/<event>_serializer.rb` | `< ActiveModel::Serializer`, `event_type` hardcoded string first | **P** | Create 1 per event. |
| 13 | Nested candidate serializer | `app/serializers/api/v1/zapier_integrations/candidate_serializer.rb` | name/email/phone/location/`*_pretty` social | **S** | Reuse for the candidate block. |
| 14 | Nested question serializer | `app/serializers/api/v1/zapier_integrations/question_response_serializer.rb` | `body`, `question_text` | **S** | Reuse if responses wanted. |
| 15 | HiringStageVisit (move record) | `app/models/hiring_stage_visit.rb` + `hiring_stage_visits` table | provides last/new stage (§5) | **S** | Read-only source for stage data. NO schema change required (see §5). |

### Delivery lifecycle & order (verbatim, single in-app move)
1. `JobApplicationsController#update` sets `last_updated_by_organization_user_id`, virtual
   `skip_hiring_stage_message_automation`, then `job_application.update(hiring_stage_id:)`.
2. DB UPDATE commits.
3. `after_commit :track_movement, on: [:update]` fires:
   ```ruby
   def track_movement
     if saved_change_to_job_id?
       previous_stage_id = hiring_stage_id_before_last_save
       track_move_to_job(hiring_stage_id, previous_job_id)
       create_hiring_stage_visit(previous_stage_id)
     elsif saved_change_to_hiring_stage_id?
       previous_stage_id = hiring_stage_id_before_last_save
       track_move_to_hiring_stage(hiring_stage_id)
       create_hiring_stage_visit(previous_stage_id)   # <-- visit row written here
       # <-- PROPOSED webhook fire site, AFTER the visit exists
     end
   end
   ```
4. `create_hiring_stage_visit` → `CreateHiringStageVisit` builds + saves the
   `HiringStageVisit` (source + destination + name snapshot + actor).
5. `HiringStageVisit after_commit :enqueue_automation_handler, on: :create` may enqueue
   `HiringStageMessageAutomationJob`.

Existing committed side-effects on a move (the parallels the webhook joins): (1)
PublicActivity feed row, (2) the `HiringStageVisit` row, (3) the templated message
automation. **No webhook fires on a move today** — this is net-new at the trigger surface.

### What does NOT exist (net-new design if wanted — flag, do not assume)
No HMAC/signing/secret column, no `active` flag, no retry/exhaustion block, no Faraday
timeout, no response-status handling, no Slack failure alert, no delivery/audit table, no
custom headers, no event envelope (`delivery_id`/`timestamp`). Both existing webhook jobs
predate inflow-ats Failure-Pattern #14 (analog retry) and have NO exhaustion block.

---

## 3. TRIGGER POINT

**Recommended fire site: inside `JobApplication#track_movement`, in the
`elsif saved_change_to_hiring_stage_id?` branch, immediately AFTER
`create_hiring_stage_visit(previous_stage_id)`** (mirrors how `send_notifications` is the
create-path site for `new_job_application`). At that point the JA update is committed AND
the new `HiringStageVisit` row exists, so last/new stage data (§5) is available.

The destination kind selects which of the three webhooks fires:
```ruby
# PROPOSAL — inside the saved_change_to_hiring_stage_id? branch, after create_hiring_stage_visit
destination_stage = hiring_stage            # belongs_to :hiring_stage (the new current stage)
event_kind = {
  'kind_in_process' => :candidate_moved_to_in_process,
  'kind_archived'   => :candidate_moved_to_archived,
  'kind_hired'      => :candidate_moved_to_hired
}[destination_stage.kind]
if event_kind
  webhook = job.organization.registered_webhooks.find_by(kind: event_kind)
  RegisteredWebhooks::HiringStageMoveJob.perform_later(id, webhook.id) if webhook.present?
end
# kind_inbox falls through (no event) — inbox is covered by new_job_application
```

**Parallels these existing move side-effects** (doc 04 §6): the PublicActivity
`job_application.moved_stage[.customer_api]` entry, the `HiringStageVisit` row, and the
`HiringStageMessageAutomationJob`. The webhook is a fourth move side-effect alongside them.

**Funnel facts the spec MUST decide on:**
- **`if/elsif` precedence:** a move that ALSO changes `job_id` runs only the
  `saved_change_to_job_id?` branch — the stage-move branch (and thus the webhook) does NOT
  fire. Decide whether a cross-job move that also lands in hired/archived/in_process should
  emit a webhook.
- **Bulk move fan-out:** `BulkMoveJobApplicationsToStageController` uses
  `Relation#update` (NOT `update_all`), so `track_movement` — and therefore the webhook —
  fires **once per job application**. A 500-candidate bulk move = 500 webhook POSTs. Decide
  if that fan-out is desired/throttled.
- **All paths covered:** in-app update, customer public-API `move_stage`/`archive`,
  `move_to_job_at_hiring_stage`, and bulk move ALL funnel through `track_movement` — one
  fire site covers every move path.
- **Alternative site:** `HiringStageVisit#after_commit :enqueue_automation_handler` (the
  message-automation site) is the other structural candidate; the visit row carries
  source/destination/actor/timestamp directly. Trade-off in §6.

---

## 4. PROPOSED EVENT + PAYLOAD  ⚠️ PROPOSAL — for Jessica's spec review, NOT decided

### 4a. Event naming (pick ONE shape)
- **Option A — three kinds, one per destination** (matches "three webhooks"):
  `candidate_moved_to_in_process: 2`, `candidate_moved_to_archived: 3`,
  `candidate_moved_to_hired: 4`. Each registers its own URL; subscriber picks which
  transitions it cares about. Closest to the existing one-kind-per-event convention.
- **Option B — one kind `hiring_stage_moved: 2`**, payload carries destination `kind`;
  subscriber filters. Fewer files, but diverges from "three webhooks" framing and from the
  one-kind-per-event convention.

`event_type` string in each serializer is hardcoded and matches the enum key by convention
(no programmatic link), exactly like `'new_job_application'`.

### 4b. Proposed payload field list
Grounded in fields the existing slim serializers already expose. Envelope follows the
existing flat shape (`event_type` first, no wrapper) unless the spec adds one.

| Payload group | Field | Serializer source today | Status |
|---|---|---|---|
| event | `event_type` | hardcoded method (analog) | ✅ pattern exists |
| candidate moved | `first_name,last_name,full_name,email,phone,location` + `*_pretty` socials | `ZapierIntegrations::CandidateSerializer` | ✅ reuse as-is |
| the job application | `id` | `RegisteredWebhooks::JobApplicationSerializer` attr | ✅ |
| | `url` (permalink) | `object.permalink_url` | ✅ |
| | `source`, `created_via`, `resume_url` | existing attrs | ✅ |
| | `job_title` | `object.job.title` | ✅ |
| the job | `job_id` | NOT in any slim serializer | ⚠️ NEW exposure (trivial: `object.job_id`) |
| | `title`, `status`, `job_post_url` | only in heavy `Api::V1::JobSerializer` | ⚠️ NEW slim exposure |
| the organization | `organization_id`/`name`/`careers_page_url`/`website_url` | **NO slim org serializer exists**; heavy `OrganizationSerializer` leaks Stripe IDs | ⚠️ NEW slim org block — must NOT reuse heavy serializer |
| candidate's own applications | list of `{job_title, hiring_stage, url}` via `candidate.job_applications` | reachable; no slim multi-app serializer today | ⚠️ NEW exposure (decide shape; watch N+1 / PII) |
| hiring-stage data | `new_stage` = `{id, name, kind}` from destination | NOT exposed by ANY webhook/Zapier serializer | ⚠️ NEW exposure (see §5) |
| | `last_stage` = `{id, name, kind}` from `source_hiring_stage_id` | NOT exposed | ⚠️ NEW exposure (see §5) |
| | `moved_at`, `moved_by_organization_user_id` | on `HiringStageVisit` | ⚠️ NEW exposure |
| | `time_in_previous_stage` (optional) | derivable (§5) | ⚠️ NEW + design decision |

**Fields that already have a serializer source:** all candidate contact fields, JA
`id/url/source/created_via/resume_url/job_title`. **Fields needing NEW exposure:** `job_id`
+ slim job fields, ALL organization fields (no slim org serializer exists), the candidate's
own-applications list, and ALL hiring-stage fields (no webhook/Zapier serializer exposes
stage id/name/kind today — confirmed in docs 02 & 03).

### 4c. PII guardrails (carry into the serializer design)
- `Candidate#privacy_status` enum (`public/needs_anonymization/anonymized`) is **NOT**
  respected by the existing webhook serializer. A move webhook emitting candidate
  name/email must decide how to treat non-public candidates.
- Heavy `OrganizationSerializer` exposes `stripe_*` IDs and billing status — **must not**
  leak. Build a slim org block (or use `mini_`/`shallow_organization_serializer.rb`, not yet
  read).
- Webhook delivery job passes **no `scope`**, so any Pundit/scope-gated attribute
  (`private_note`, `desired_compensation`) would mis-evaluate. Follow the slim-serializer
  precedent: emit only non-gated fields.

---

## 5. HiringStageVisit FACTS (facts only — no design)

**Schema (verbatim, `db/schema.rb:623`):**
```ruby
create_table "hiring_stage_visits", force: :cascade do |t|
  t.bigint "job_application_id", null: false
  t.bigint "current_hiring_stage_id", null: false
  t.bigint "source_hiring_stage_id"
  t.string "current_stage_name_at_move", null: false
  t.bigint "moved_by_organization_user_id"
  t.datetime "created_at", precision: 6, null: false
  t.datetime "updated_at", precision: 6, null: false
end
```
- Model has `belongs_to :current_hiring_stage, class_name: 'HiringStage'`. The
  **`source_hiring_stage` association is COMMENTED OUT** — column exists, association does
  not. Reading the source stage today requires `HiringStage.find(visit.source_hiring_stage_id)`
  (or un-commenting the association).
- Only callback: `after_commit :enqueue_automation_handler, on: :create`. No validations,
  scopes, enums. `current_stage_name_at_move` snapshots the **destination** stage name.
- `moved_by_organization_user_id` is a plain bigint (no FK, no index), set from
  `job_application.last_updated_by_organization_user_id`.

**Deriving new-stage / last-stage** (only ordering signal is `created_at`):
```ruby
current_visit  = job_application.hiring_stage_visits.order(created_at: :desc).first
# new stage  => current_visit.current_hiring_stage_id (+ current_stage_name_at_move)
# last stage => current_visit.source_hiring_stage_id  (nil for the first-ever visit)
```
In `track_movement`'s own context the destination is simply `hiring_stage` and the source
is `hiring_stage_id_before_last_save`, so the webhook can read both without re-querying.

**Time-in-previous-stage:** NO `entered_at`/`left_at`/`duration`/`time_in_stage` column
exists; no duration method exists. It IS derivable as
`current_visit.created_at - previous_visit.created_at` (previous_visit = second-newest
visit, whose `current_hiring_stage_id == current_visit.source_hiring_stage_id`). A persisted
column would be needed ONLY to freeze the value (immune to visit deletion) or to index/query
it — not for availability. Edge cases: first-ever visit has nil source/no prior visit;
cross-job moves put the source stage on a different job; same-second ties mitigated by
`precision: 6`. (Designing this column is out of scope — facts only.)

---

## 6. OPEN QUESTIONS / RISKS for the spec phase

1. **Event shape** — three kinds (Option A) vs one `hiring_stage_moved` kind (Option B)? (§4a)
2. **One job vs three** — one parametrized `RegisteredWebhooks::HiringStageMoveJob(ja_id,
   webhook_id)` whose serializer reads the destination kind, vs three event-specific jobs.
   The analog uses one job per kind; a single parametrized job is a minor, defensible
   deviation (surface it — see Failure-Pattern: analog deviations).
3. **Cross-job move** — `track_movement`'s `if/elsif` skips the stage branch when `job_id`
   also changes. Should a move-to-job that lands in hired/archived fire a webhook?
4. **Bulk-move fan-out** — once-per-JA POSTs (could be hundreds). Throttle? Batch? Accept?
5. **Trigger site** — `track_movement` (has direct dest stage + prev stage id) vs
   `HiringStageVisit#after_commit` (canonical move record, carries actor/snapshot, but the
   `if/elsif` job-precedence and bulk semantics differ). Pick one and document why.
6. **No slim Organization serializer exists** — must build one (or vet
   `mini_`/`shallow_organization_serializer.rb`) to avoid leaking Stripe IDs.
7. **Candidate PII** — `privacy_status` is not respected by existing webhook serializers;
   decide policy for `needs_anonymization`/`anonymized` candidates.
8. **Delivery hardening** — existing webhooks have NO signing/retry/timeout/response-check/
   audit. Decide whether the new webhooks adopt the bare baseline or add hardening (any
   hardening is net-new design, not "matching the analog").
9. **Candidate's own applications** — shape + N+1 risk of embedding
   `candidate.job_applications` in every move payload.
10. **Frontend** — the three new kinds must be surfaced in
    `AccountIntegrationsPolymerWebhooks.tsx` / `registeredWebhooks.ts` for orgs to register
    URLs; otherwise the trigger always no-ops (`find_by(kind:)` returns nil).
11. **No uniqueness constraint** — `validates :kind, uniqueness:` is commented out; multiple
    rows of a kind are technically possible though the `all` controller path assumes one.

### INDEX
- `01-outbound-webhook-infra.md` — RegisteredWebhook skeleton, controller/policy/routes/
  frontend, delivery job + serializer, complete gap list.
- `02-new-job-application-webhook.md` — create-path analog, full trigger chain, payload,
  structural diff vs publish, inbox-already-covered.
- `03-zapier-hired-endpoint.md` — Zapier hired *poll* (current-state, not event), the
  canonical `kind_hired` token, why it is NOT the public API.
- `04-hiring-stage-move-pipeline.md` — every move path → `track_movement`; bulk semantics;
  existing move side-effects; the webhook analog to copy.
- `05-hiring-stage-visit-and-data-models.md` — HiringStageVisit schema + last/new derivation
  + time-in-stage derivability; payload model menu (Candidate/JA/Org/Job) + PII notes.
