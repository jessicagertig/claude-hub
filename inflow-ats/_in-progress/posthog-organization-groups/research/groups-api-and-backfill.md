# PostHog HTTP APIs for groups — backfill and read-back

Sources are split between **posthog.com docs** (the contract) and **PostHog/posthog `master` source** (the current implementation, more precise but not a stability guarantee). Every claim below is labelled with which one it came from.

Host rules ([API overview](https://posthog.com/docs/api)):

| Purpose | US Cloud | EU Cloud |
|---|---|---|
| Public POST-only (capture/batch) | `https://us.i.posthog.com` | `https://eu.i.posthog.com` |
| Private REST (personal API key) | `https://us.posthog.com` | `https://eu.posthog.com` |

> "On US Cloud, these are `https://us.i.posthog.com` for public endpoints and `https://us.posthog.com` for private ones."

---

## 1. `$groupidentify` over the raw capture endpoint

### Endpoint

The documented single-event path is **`/i/v0/e/`** ([capture docs](https://posthog.com/docs/api/capture)). The capture service also routes `/capture`, `/capture/`, `/e`, `/e/`, `/track`, `/track/`, `/engage`, `/engage/`, `/i/v0/e`, `/i/v0/e/` to the **same handler** `v0_endpoint::event` ([`rust/capture/src/router.rs:278-333`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/router.rs)). So `POST /capture/` works and is byte-identical in behavior to `/i/v0/e/`, but `/i/v0/e/` is the path the docs commit to.

### Auth: `api_key` in the **body**, never a header

There is no header auth on capture. From [`rust/common/types/src/event.rs:60-66`](https://github.com/PostHog/posthog/blob/master/rust/common/types/src/event.rs), the field is `token` with two accepted aliases:

```rust
pub struct RawEvent {
    #[serde(
        alias = "$token",
        alias = "api_key",
        skip_serializing_if = "Option::is_none"
    )]
    pub token: Option<String>,
```

So `api_key`, `token`, and `$token` are interchangeable at the top level of a single event. The value is the **project token** (`phc_…`), not a personal API key.

### Exact required fields

From [capture docs](https://posthog.com/docs/api/capture):

> "Every event request must contain an `api_key`, `distinct_id`, and `event` field with the name. Both the `properties` and `timestamp` fields are optional."

> "`distinct_id` is limited to 200 characters. Longer values are shortened to the first 200 characters and the event is still ingested, with an ingestion warning."

For `$groupidentify` specifically:

> - `$group_type` must be at most 400 characters long
> - `$group_key` must be at most 400 characters long

### Complete curl — verbatim from the docs

```bash
curl -v -L --header "Content-Type: application/json" -d '{
  "api_key": "<ph_project_token>",
  "event": "$groupidentify",
  "distinct_id": "groups_setup_id",
  "properties": {
    "$group_type": "<group_type>",
    "$group_key": "<company_name>",
    "$group_set": {
      "name": "<company_name>",
      "subscription": "premium"
      "date_joined": "[optional timestamp in ISO 8601 format]"
    }
  }
}' <ph_client_api_host>/i/v0/e/
```

(Note: the docs snippet at [contents/docs/api/capture.mdx:288-301](https://github.com/PostHog/posthog.com/blob/master/contents/docs/api/capture.mdx) is missing a comma after `"premium"` — it is not valid JSON as printed. Fix it in your copy.)

A concrete, valid version:

```bash
curl -sS -X POST https://us.i.posthog.com/i/v0/e/ \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "phc_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "event": "$groupidentify",
    "distinct_id": "groups_setup_id",
    "timestamp": "2026-08-09T12:00:00Z",
    "properties": {
      "$group_type": "organization",
      "$group_key": "org_12345",
      "$group_set": {
        "name": "Acme Corp",
        "plan": "premium",
        "seats": 42,
        "date_joined": "2020-01-23T00:00:00Z"
      }
    }
  }'
```

Response body (from [`rust/capture/src/api.rs:9-29`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/api.rs)):

```json
{"status": "Ok"}
```

and when the project is over its billing quota, the same `200` carries:

```json
{"status": "Ok", "quota_limited": ["events"]}
```

### Semantics worth knowing

- **`$groupidentify` creates the group type if it doesn't exist.** From [group analytics docs](https://posthog.com/docs/product-analytics/group-analytics): "Create group types before you associate events with them. Call the group identify method to create a group type and set properties." Max **5 group types per project**; unlimited groups within a type.
- **`distinct_id` for `$groupidentify` is a throwaway.** The docs use the literal `"groups_setup_id"`. PostHog's own internal caller uses the team UUID and sets `process_person_profile=False` ([`ee/clickhouse/views/groups.py:322-338`](https://github.com/PostHog/posthog/blob/master/ee/clickhouse/views/groups.py)):
  ```python
  properties = {
      "$group_type": group_type_mapping.group_type,
      "$group_key": group.group_key,
      "$group_set": group_properties or group.group_properties,
  }
  result = capture_internal(
      token=self.team.api_token,
      event_name="$groupidentify",
      ...
      process_person_profile=False,
  )
  ```
  Using a single static `distinct_id` for a large backfill is what the docs show, but see the per-distinct-ID ingestion protection in §5.
- **Linking a normal event to a group** uses `properties.$groups`, a map of `group_type → group_key`:
  ```bash
  curl -v -L --header "Content-Type: application/json" -d '{
      "api_key": "<ph_project_token>",
      "event": "group_event_name",
      "distinct_id": "static_string_for_group_events",
      "properties": {
          "$groups": {"company": "company_id_in_your_db"}
      }
  }' <ph_client_api_host>/i/v0/e/
  ```
  The docs are explicit: "This event will **not** create a new group if a new key being used. To create a group, see the group identify event."
- **`$process_person_profile: false` breaks group linkage.** "Events must be identified to link to individual groups. If `$process_person_profile` is set to `false`, the event won't link to the group." ([group analytics](https://posthog.com/docs/product-analytics/group-analytics))
- **Undocumented but real: `$delete_group_property`.** PostHog's own API emits it to remove a single group property ([`ee/clickhouse/views/groups.py:687-704`](https://github.com/PostHog/posthog/blob/master/ee/clickhouse/views/groups.py)):
  ```python
  event_name = "$delete_group_property"
  properties = {
      "$group_type": group_type_mapping.group_type,
      "$group_key": group.group_key,
      "$group_unset": [property_key],
  }
  ```
  This is not in the public capture docs. It works from the internal capture path; treat it as undocumented if you send it yourself.
- **Docs typo to ignore:** [contents/docs/migrate/index.mdx:57](https://github.com/PostHog/posthog.com/blob/master/contents/docs/migrate/index.mdx) says "the `$group_identify` event" (with an underscore). The real event name everywhere in code and in the capture docs is `$groupidentify`, no underscore.

---

## 2. `/batch/`

### Payload shape

From [capture docs](https://posthog.com/docs/api/capture), verbatim:

```bash
curl -v -L --header "Content-Type: application/json" -d '{
  "api_key": "<ph_project_token>",
  "historical_migration": false,
  "batch": [
    {
      "event": "batched_event_name_1",
      "properties": {
        "distinct_id": "user distinct id",
        "account_type": "pro"
      },
      "timestamp": "[optional timestamp in ISO 8601 format]"
    },
    {
      "event": "batched_event_name_2",
      "properties": {
        "distinct_id": "user distinct id",
        "account_type": "pro"
      }
    }
  ]
}' <ph_client_api_host>/batch/
```

The envelope struct ([`rust/capture/src/v0_request.rs:30-37`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/v0_request.rs)):

```rust
#[derive(Deserialize)]
pub struct BatchedRequest {
    #[serde(alias = "api_key")]
    pub token: String,
    pub historical_migration: Option<bool>,
    pub sent_at: Option<String>,
    pub batch: Vec<RawEvent>,
}
```

So the envelope keys are exactly `token` (alias `api_key`), `historical_migration`, `sent_at`, `batch`. Each element of `batch` is a `RawEvent`: `token` / `distinct_id` / `uuid` / `event` / `properties` / `timestamp` / `offset` / `$set` / `$set_once`. Note `distinct_id` may be given either at the event's top level or inside `properties` — the docs example uses `properties`.

**`uuid` is accepted per event.** That is your idempotency handle for a re-runnable backfill; it does not appear in the docs' examples but is a first-class `RawEvent` field.

### `historical_migration: true` — batch shape only

Critical and undocumented as such. From [`v0_request.rs:117-122`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/v0_request.rs):

```rust
pub fn historical_migration(&self) -> bool {
    match self {
        RawRequest::Batch(req) => req.historical_migration.unwrap_or_default(),
        _ => false,
    }
}
```

A single-event POST, or a bare JSON array of events, is **always** `historical_migration: false`. Backfills must use the `{api_key, historical_migration: true, batch: [...]}` envelope.

Docs on when to set it ([capture docs](https://posthog.com/docs/api/capture) and [migrations](https://posthog.com/docs/migrate)):

> "When running migrations, the `historical_migration` field must be set to `true`. This ensures that events are processed in order without triggering our spike detection systems."

> "Including the `timestamp` field… It needs to be in the ISO 8601 format and **dated at least 48 hours before the time of import**."

> "To capture events, you must use the PostHog Python SDK or the PostHog API `batch` endpoint with the `historical_migration` set to `true`. This ensures we handle this data correctly and you aren't charged standard ingestion fees for it."

The historical migration curl, verbatim ([contents/docs/migrate/_snippets/api-migration.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/migrate/_snippets/api-migration.mdx)):

```bash
curl -v -L --header "Content-Type: application/json" -d '{
  "api_key": "<ph_project_token>",
  "historical_migration": true,
  "batch": [
    {
      "event": "batched_event_name",
      "properties": {
        "distinct_id": "user_id"
      },
      "timestamp": "2024-04-03T12:00:00Z"
    },
    {
      "event": "batched_event_name",
      "properties": {
        "distinct_id": "user_id"
      },
      "timestamp": "2024-04-03T12:00:00Z"
    }
  ]
}' <ph_client_api_host>/batch/
```

For group backfill, the same envelope with `$groupidentify` events:

```bash
curl -sS -X POST https://us.i.posthog.com/batch/ \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "phc_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "historical_migration": true,
    "batch": [
      {
        "event": "$groupidentify",
        "distinct_id": "groups_setup_id",
        "timestamp": "2026-08-01T00:00:00Z",
        "properties": {
          "$group_type": "organization",
          "$group_key": "org_12345",
          "$group_set": {"name": "Acme Corp", "plan": "premium"}
        }
      },
      {
        "event": "$groupidentify",
        "distinct_id": "groups_setup_id",
        "timestamp": "2026-08-01T00:00:00Z",
        "properties": {
          "$group_type": "organization",
          "$group_key": "org_67890",
          "$group_set": {"name": "Globex", "plan": "free"}
        }
      }
    ]
  }'
```

### Size and count limits

| Limit | Value | Source |
|---|---|---|
| Events per batch | **No limit** | [capture docs](https://posthog.com/docs/api/capture): "There is no limit on the number of events you can send in a batch" |
| `/batch/` request body | **20 MB** | Docs: "the entire request body must be less than 20MB by default". Confirmed in code: `pub const BATCH_BODY_SIZE: usize = 20 * 1024 * 1024;` ([`router.rs:36`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/router.rs)) |
| Single-event endpoints (`/i/v0/e/`, `/capture/`, `/e/`, `/track/`, `/engage/`) request body | **2 MB** | `const EVENT_BODY_SIZE: usize = 2 * 1024 * 1024;` ([`router.rs:35`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/router.rs)). Not stated in the docs. |
| Per-event size after processing | **1 MB** — event is **discarded** | [Ingestion warnings](https://posthog.com/docs/data/ingestion-warnings#discarded-event-exceeding-1mb-limit): "PostHog discards events exceeding 1 megabyte in size after processing." |
| Django POST body ceiling | 20 MB (`settings.DATA_UPLOAD_MAX_MEMORY_SIZE`) | [API overview](https://posthog.com/docs/api) |

Gzip is accepted on the wire: the handler sniffs the first three bytes rather than trusting the `compression` query param ([`v0_request.rs:41-45`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/v0_request.rs)).

### Rate limits on `/batch/`

None at the request level. See §5.

### Silent-failure modes (returns 200 anyway)

From [capture docs](https://posthog.com/docs/api/capture):

> PostHog **does not return an error** to the client when the following happens:
> - An event does not have a name
> - An event does not have the `distinct_id` field set
> - The `distinct_id` field of an event has an empty value
>
> These three cases above cause the event to not be ingested, but you still receive a `200: OK` response from PostHog.

A backfill cannot rely on HTTP status for per-event success. Validate before sending, and verify afterwards with §6's HogQL queries.

---

## 3. Reading groups back — the private REST API

Yes. `GET /api/projects/:project_id/groups/` exists, plus several sub-actions. Everything below is from [`ee/clickhouse/views/groups.py`](https://github.com/PostHog/posthog/blob/master/ee/clickhouse/views/groups.py) and the route registration in [`posthog/api/rest_router.py:433-441`](https://github.com/PostHog/posthog/blob/master/posthog/api/rest_router.py); the public reference is [posthog.com/docs/api/groups](https://posthog.com/docs/api/groups).

```python
projects_router.register(r"groups", GroupsViewSet, "project_groups", ["team_id"])
group_types_router = projects_router.register(
    r"groups_types", GroupsTypesViewSet, "project_groups_types", ["project_id"]
)
group_types_router.register(
    r"metrics", GroupUsageMetricViewSet, "project_groups_metrics", ["project_id", "group_type_index"]
)
```

Auth on all of these: `Authorization: Bearer <personal API key>` (`phx_…`), against the **private** host (`https://us.posthog.com`).

### 3.1 `GET /api/projects/:project_id/groups/` — list

Scope: `group:read`. Docstring, verbatim:

> "List all groups of a specific group type. You must pass `?group_type_index=` in the URL. To get a list of valid group types, call `/api/:project_id/groups_types/`. Uses forward-only keyset pagination via the `cursor` parameter. The `previous` field in the response envelope is always null."

Query parameters (from the `@extend_schema` block):

| Param | Type | Required | Meaning |
|---|---|---|---|
| `group_type_index` | integer | **yes** | "Specify the group type to list". Missing → `400` with `{"group_type_index": ["You must pass ?group_type_index= in this URL. …"]}` |
| `search` | string | no | "Search the group name" |
| `cursor` | string | no | "Pagination cursor returned in the `next` URL of a previous response" |
| `group_key` | string | no | "Filter groups whose key contains this string (case-insensitive)" |

`search` semantics ([`posthog/models/group/util.py:224-272`](https://github.com/PostHog/posthog/blob/master/posthog/models/group/util.py)):

> "`search` matches a substring of the raw properties JSON **or** the group key exactly (case-insensitive)"

i.e. `toString(properties) ILIKE '%<search>%' OR lower(toString(key)) = lower(<search>)`. It is not a `name`-only search despite the parameter description.

Ordering and page size: `ORDER BY created_at DESC, key DESC`, `limit = 100` per page, keyset cursor on `(created_at, group_key)`. Served from ClickHouse, so **eventually consistent** — the docstring says so explicitly. A group you just created via `$groupidentify` will not be listable instantly.

Response envelope (`GroupSerializer`, fields `["group_type_index", "group_key", "group_properties", "created_at"]`):

```json
{
  "next": "https://us.posthog.com/api/projects/1234/groups/?group_type_index=0&cursor=eyJjIjoxNzU0NzAwMDAwMDAwMDAwLCJrIjoib3JnXzEyMzQ1In0=",
  "previous": null,
  "results": [
    {
      "group_type_index": 0,
      "group_key": "org_12345",
      "group_properties": {"name": "Acme Corp", "plan": "premium"},
      "created_at": "2026-08-01T00:00:00Z"
    }
  ]
}
```

```bash
curl -sS -G https://us.posthog.com/api/projects/:project_id/groups/ \
  -H "Authorization: Bearer $POSTHOG_PERSONAL_API_KEY" \
  --data-urlencode "group_type_index=0" \
  --data-urlencode "search=Acme"
```

### 3.2 `GET /api/projects/:project_id/groups/find/` — read one group

Scope: `group:read`. Parameters:

| Param | Type | Required | Meaning |
|---|---|---|---|
| `group_type_index` | integer | **yes** | "Specify the group type to find" |
| `group_key` | string | **yes** | "Specify the key of the group to find" |
| `skip_create_notebook` | boolean | no | "When true, do not lazily create the group's CRM notebook. Use for read-only lookups (e.g. resolving a group's display name) that should not have side effects." |

Returns `FindGroupSerializer`: the four `GroupSerializer` fields **plus** `notebook`. `404` if absent.

**Pass `skip_create_notebook=true` on any programmatic read.** Without it, `find` has a write side effect (it lazily creates a CRM notebook for the group when the `crm-iteration-one` flag is on).

```bash
curl -sS -G https://us.posthog.com/api/projects/:project_id/groups/find/ \
  -H "Authorization: Bearer $POSTHOG_PERSONAL_API_KEY" \
  --data-urlencode "group_type_index=0" \
  --data-urlencode "group_key=org_12345" \
  --data-urlencode "skip_create_notebook=true"
```

### 3.3 `GET /api/projects/:project_id/groups_types/` — list group types

Scope object `group`. Returns a plain list (no pagination, `pagination_class = None`), one entry per group type:

```json
[
  {
    "group_type": "organization",
    "group_type_index": 0,
    "name_singular": null,
    "name_plural": null,
    "detail_dashboard": null,
    "default_columns": null,
    "created_at": "2026-08-01T00:00:00Z"
  }
]
```

Fields come from `_group_type_row_to_response` in [`ee/clickhouse/views/groups.py:126-141`](https://github.com/PostHog/posthog/blob/master/ee/clickhouse/views/groups.py). This is the mapping you need to translate a `group_type` name ↔ `group_type_index` (0-4).

### 3.4 Other read endpoints on the groups viewset

| Method | Path | Scope | Params | Notes |
|---|---|---|---|---|
| `GET` | `/api/projects/:project_id/groups/related/` | `group:read` | `group_type_index` (int), `id` (string, required) | Related actors (persons/other groups) for the given actor |
| `GET` | `/api/projects/:project_id/groups/property_values/` | `group:read` | `group_type_index` (required), `key` (required), `value` (optional substring) | Top 20 values of a group property, `{"results": [{"name": …, "count": …}], "refreshing": false}` |
| `GET` | `/api/projects/:project_id/groups/activity/` | `activity_log:read` | `group_type_index`, `id`, `limit` (default 10), `page` (default 1) | Activity log for a group |
| `GET/POST/PATCH/DELETE` | `/api/projects/:project_id/groups_types/:group_type_index/metrics/` | `usage_metric:*` | — | Group usage metrics CRUD |

### 3.5 Writes

| Method | Path | Scope | Body |
|---|---|---|---|
| `POST` | `/api/projects/:project_id/groups/` | `group:write` | `{"group_type_index": int, "group_key": str, "group_properties": {…}}` |
| `POST` | `/api/projects/:project_id/groups/update_property/` | `group:write` | query: `group_type_index`, `group_key`; body: `{"key": …, "value": …}` |
| `POST` | `/api/projects/:project_id/groups/delete_property/` | `group:write` | query: `group_type_index`, `group_key`; body: `{"$unset": "<property name>"}` |
| `PATCH` | `/api/projects/:project_id/groups_types/update_metadata/` | — | list of `{group_type_index, name_singular, name_plural}` |

`POST /groups/` rejects duplicates with `400 {"detail": "A group with this key already exists"}`, and internally fires a `$groupidentify` capture event anyway. **For bulk backfill, `/batch/` with `$groupidentify` is the right path, not this endpoint** — it is rate-limited (§5), it is one-group-per-request, and it writes to Postgres, ClickHouse, PropertyDefinitions, the activity log, and capture on every call.

---

## 4. Deleting a group or its properties

### Individual groups: **no delete API exists**

`GroupsViewSet` is declared as:

```python
class GroupsViewSet(TeamAndOrgViewSetMixin, mixins.ListModelMixin, mixins.CreateModelMixin, viewsets.GenericViewSet):
```

No `DestroyModelMixin`, no `destroy` method. There is no `DELETE /api/projects/:id/groups/…` route.

Confirmed in the docs' [Limitations](https://posthog.com/docs/product-analytics/group-analytics) section, verbatim:

> - You can delete group types, but not individual groups

and earlier: "Individual groups cannot be deleted, only group types."

`DeletionType.Group = 2` does exist in [`posthog/models/async_deletion/async_deletion.py:4-9`](https://github.com/PostHog/posthog/blob/master/posthog/models/async_deletion/async_deletion.py), but it is internal machinery, not reachable from any public API.

### Group properties: yes, one at a time

`POST /api/projects/:project_id/groups/delete_property/` with `?group_type_index=&group_key=` and body:

```json
{"$unset": "plan"}
```

```bash
curl -sS -X POST \
  "https://us.posthog.com/api/projects/:project_id/groups/delete_property/?group_type_index=0&group_key=org_12345" \
  -H "Authorization: Bearer $POSTHOG_PERSONAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"$unset": "plan"}'
```

Validation ([`ee/clickhouse/views/groups.py:663-669`](https://github.com/PostHog/posthog/blob/master/ee/clickhouse/views/groups.py)): `$unset` must be a string, and the property must currently exist on the group, else `400`. It updates Postgres and ClickHouse and emits the `$delete_group_property` capture event with `$group_unset: [property_key]`.

### Group types: delete, with caveats

`DELETE /api/projects/:project_id/groups_types/:group_type_index/` → `204`. From the [group analytics docs](https://posthog.com/docs/product-analytics/group-analytics):

> - Event data remains unchanged. Group data is filtered from queries based on a deletion timestamp.
> - Deleted group types don't count toward your 5 group type limit.
> - If new events arrive with the same group key, the group type reappears with a new creation timestamp. Historical events (before the new timestamp) won't appear for the recreated group type.

### GDPR

The [data deletion](https://posthog.com/docs/privacy/data-deletion) page documents person deletion (`DELETE` on the persons API, which removes the person and their events) and project/organization deletion. It documents no group-level deletion mechanism. Also relevant, from [migrations](https://posthog.com/docs/migrate): "There is no way to selectively delete event data in PostHog, so getting this right is critical."

**Bottom line for GDPR/cleanup on groups: you can null out properties one key at a time via `delete_property`, or delete the whole group type. There is no per-group erasure.**

---

## 5. Rate limits and backfill throughput

### Capture / ingestion — no request-level limit

From [API overview](https://posthog.com/docs/api), verbatim:

> Public POST-only endpoints such as event capture (`/e`, `/i/v0/e`) and feature flag evaluation (`/flags`) have no request-level rate limits. Event capture still returns `200` when your project is over its billing quota, and names the limited resources in the `quota_limited` field of the response body. It also applies a per-distinct-ID ingestion protection: if a single distinct ID sends a high, sustained volume of events (roughly 5,000 per minute), those events are still accepted with a `200` response but are processed without strict ordering and without person profile updates for the duration of the spike. PostHog logs an ingestion warning when this happens.

**This matters directly for `$groupidentify` backfills**, because the docs tell you to use one static `distinct_id` (`"groups_setup_id"`) for every group. Backfilling >5,000 groups/minute through one `distinct_id` trips that protection.

The `historical_migration: true` path is exempt. From [`rust/capture/src/config.rs:33-42`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/config.rs):

```rust
/// Whether this mode subjects incoming events to the per-(token,
/// distinct_id) global rate limiter. `Import` opts out: historical
/// backfills are internal traffic that must not be throttled.
pub fn applies_global_rate_limit(&self) -> bool {
    !matches!(self, CaptureMode::Import)
}
```

### Private REST API

From [API overview](https://posthog.com/docs/api), verbatim:

- Analytics endpoints (insights, persons, session recordings): **`240/minute` and `1200/hour`**
- `events/values`: **`60/minute` and `300/hour`**
- `query` endpoint: **`2400/hour`**
- Feature flag local evaluation: **`600/minute`**
- "For the rest of the create, read, update, and delete endpoints, the rate limits are `480/minute` and `4800/hour`."
- "These limits apply to **the entire team** (i.e. all users within your PostHog organization)."

The groups REST endpoints fall in the last bucket: **480/min, 4800/hour, shared org-wide.**

`/query` additionally, from [API queries](https://posthog.com/docs/api/queries):

- 2400 requests per hour
- 240 requests per minute
- 3 queries running concurrently
- 60 threads per query
- 10 seconds of max execution time (query execution, not HTTP duration)
- "If the project's concurrency quota is exhausted, we put the query in queue and wait. The query may wait up to 30 seconds in a queue."
- Default 100 rows returned; up to 50k with an explicit `LIMIT`. `OFFSET` pagination returns HTTP 400 for personal API keys — use keyset pagination on `timestamp`.

### Recommended backfill throughput

PostHog does not publish a requests-per-second number. What it does publish:

- **1,000 events per batch.** PostHog's own migration tool hardcodes this ([`posthog-migration-tools/migrate.py:14-16`](https://github.com/PostHog/posthog-migration-tools/blob/main/migrate.py)): "We use the `batch` method to send events in batches of 1000, which is the maximum allowed by PostHog Cloud." Its `--batch-size` argparse default is also `1000`. (Read that "maximum" as the SDK's `batch` behavior, not an HTTP limit — the raw endpoint's only ceiling is the 20 MB body.)
- **Volume escalation threshold**, from [migration planning](https://posthog.com/docs/new-to-posthog/switch-guide/migration-planning): "If your historical data is above 100 GB or 200 million events, you should reach out to our sales team or open a support ticket so we can make sure everything imports smoothly."
- **Best practices**, from [migrations](https://posthog.com/docs/migrate), verbatim:
  > - We highly recommend testing at least a part of your migration on a test project before running it on your production project.
  > - Separate exporting your data from your service from importing it into PostHog. Store it in a storage service like S3 or GCS in between to ensure exported data is complete.
  > - Build resumability into your exports and imports, so you can just resume the process from the last successful point if any problems occur. For example, we use a cursor-based approach in our self-hosted migration tool.
  > - To batch user updates, use the same request but with the `$identify` event. Same for groups and the `$group_identify` event.

  (Last bullet's event name is the typo noted in §1 — it is `$groupidentify`.)

A defensible operating point for a group backfill: `historical_migration: true`, batches of ~1,000 `$groupidentify` events, request body kept well under 20 MB, `timestamp` ≥ 48 h in the past, a per-event `uuid` for idempotent replay, and a resumable cursor. Throughput above that is undocumented territory — measure and back off on non-200s rather than assuming a ceiling.

---

## 6. HogQL

### The `groups` table

Schema, verbatim from [`posthog/hogql/database/schema/groups.py:26-56`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/groups.py):

| HogQL field | ClickHouse column | Description (verbatim) |
|---|---|---|
| `index` | `group_type_index` | "Group type index (0-4); identifies which group type this row belongs to, matching `events.$group_N`." |
| `team_id` | `team_id` | — |
| `key` | `group_key` | "Unique key for the group within its group type; join target for `events.$group_N`." |
| `created_at` | `created_at` | "When the group was first created in PostHog." |
| `updated_at` | `_timestamp` | "When this group row was last written (ingestion timestamp); used to pick the latest version." |
| `properties` | `group_properties` | "JSON map of group properties (latest known values). Access keys with `properties.name` etc." |
| `revenue_analytics` | (lazy join) | — |

Two tables:

- `groups` — "Deduplicated groups (companies, organizations, etc.) in the project, with their latest properties. One row per (group type, group key). Join from events via `events.$group_N = groups.key`."
- `raw_groups` — "Raw, un-deduplicated groups rows (one per update). Query `groups` instead unless you need to resolve the latest version of each group's properties yourself."

### Events-side fields

From [`posthog/hogql/database/schema/events.py:135-183`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/events.py):

- `events.$group_0` … `events.$group_4` — the raw group key string on the event.
- `events.group_0` … `events.group_4` — lazy joins to the deduped `groups` table, so `events.group_0.properties.name` works.
- `events.goe_0` … `events.goe_4` — group-on-event snapshot subtables with `key`, `created_at`, `properties` (columns `$group_N`, `group{N}_created_at`, `group{N}_properties`). Marked "Should not be used directly."
- **Every group type also becomes an alias on `events` under its own name.** [`posthog/hogql/database/database.py:1738-1741`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/database.py):
  ```python
  for mapping in group_types:
      if events_table.fields.get(mapping["group_type"]) is None:
          events_table.fields[mapping["group_type"]] = FieldTraverser(
              chain=[f"group_{mapping['group_type_index']}"]
          )
  ```
  Verified by `test_database_group_type_mappings` ([`posthog/hogql/database/test/test_database.py:774-781`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/test/test_database.py)): a group type named `test` at index 0 produces `db.get_table("events").fields["test"] == FieldTraverser(chain=["group_0"])`. If a group type's name collides with an existing events field (e.g. `event`), the existing field wins.

The lazy join constraint, from [`groups.py:196-203`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/groups.py): `ON events.$group_N = <groups>.key`, `LEFT JOIN`.

### Working queries

These six are lifted verbatim from PostHog's own test suite, [`posthog/hogql/database/schema/test/test_groups.py`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/test/test_groups.py):

```sql
SELECT key, properties.name FROM groups LIMIT 10
SELECT count() FROM groups LIMIT 5
SELECT key FROM groups ORDER BY toInt(properties.rank) DESC LIMIT 5
SELECT key FROM groups WHERE properties.tag = 'needle' LIMIT 5
SELECT DISTINCT key FROM groups LIMIT 5
SELECT g.key FROM groups AS g LIMIT 10
```

Built from the schema above (not from tests — verify against your project):

```sql
-- Every group of type index 0, with its properties
SELECT key, created_at, properties
FROM groups
WHERE index = 0
ORDER BY created_at DESC
LIMIT 100
```

```sql
-- One group's properties by key
SELECT properties.name, properties.plan
FROM groups
WHERE index = 0 AND key = 'org_12345'
```

```sql
-- Events belonging to one group, by raw key
SELECT event, timestamp, distinct_id
FROM events
WHERE $group_0 = 'org_12345'
  AND timestamp > now() - INTERVAL 30 DAY
ORDER BY timestamp DESC
LIMIT 100
```

```sql
-- Events with the group's properties pulled in via the lazy join
SELECT
  timestamp,
  event,
  group_0.key         AS org_key,
  group_0.properties.name AS org_name,
  group_0.properties.plan AS org_plan
FROM events
WHERE timestamp > now() - INTERVAL 7 DAY
  AND group_0.properties.plan = 'premium'
ORDER BY timestamp DESC
LIMIT 100
```

```sql
-- Same, using the group type NAME alias (group type "organization")
SELECT
  timestamp,
  event,
  organization.properties.name AS org_name
FROM events
WHERE timestamp > now() - INTERVAL 7 DAY
LIMIT 100
```

```sql
-- Event volume per group, joined to group properties
SELECT
  g.key,
  g.properties.name AS name,
  count() AS events
FROM events AS e
LEFT JOIN groups AS g ON e.$group_0 = g.key AND g.index = 0
WHERE e.timestamp > now() - INTERVAL 30 DAY
GROUP BY g.key, name
ORDER BY events DESC
LIMIT 50
```

```sql
-- Backfill verification: did the $groupidentify land?
SELECT index, count() AS groups, max(created_at) AS newest
FROM groups
GROUP BY index
ORDER BY index
```

### Running HogQL over HTTP

`POST /api/projects/:project_id/query/` with `kind: "HogQLQuery"` ([API queries](https://posthog.com/docs/api/queries)):

```bash
curl -sS https://us.posthog.com/api/projects/:project_id/query/ \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $POSTHOG_PERSONAL_API_KEY" \
  -d '{
        "query": {
          "kind": "HogQLQuery",
          "query": "SELECT key, properties.name, created_at FROM groups WHERE index = 0 ORDER BY created_at DESC LIMIT 100"
        },
        "name": "list organization groups"
      }'
```

Requires a personal API key with **Query Read** permission. The docs are blunt that `/query` "is **not a supported export mechanism**" and that "Bulk or recurring exports of `events`, `persons`, or `query_log` are not supported over `/query`" — use it for verification and ad-hoc reads, not for pulling your whole group table on a schedule.

### Two HogQL gotchas that bite backfills

**1. `$group_N` is blanked for events older than the group type mapping.** [`posthog/hogql/database/database.py:2329-2372`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/database.py):

```python
def _setup_group_key_fields(database: Database, group_types: list[dict[str, Any]]) -> None:
    """
    Set up group key fields as ExpressionFields that handle filtering based on GroupTypeMapping.created_at.
    For $group_N fields, this returns:
    - Empty string if no GroupTypeMapping exists for that index
    - if(timestamp < mapping.created_at, '', $group_N) if GroupTypeMapping exists
    """
```

So if you backfill historical events carrying `$groups` but the group type mapping was created *today*, every HogQL query sees `$group_0 = ''` on those events. The raw column survives as the hidden `_$group_0_raw` field. **Create the group type (via a `$groupidentify`) before backfilling historical events that reference it, and be aware the mapping's `created_at` is stamped at creation time** (`GroupTypeMapping.save` replicates `auto_now_add`: "set created_at only on creation", [`posthog/models/group_type_mapping.py:165-167`](https://github.com/PostHog/posthog/blob/master/posthog/models/group_type_mapping.py)). This is the same mechanism behind the documented "Historical events (before the new timestamp) won't appear for the recreated group type."

**2. `SELECT * FROM groups` with a join is expensive.** The join implementation warns ([`groups.py:167-174`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/groups.py)): "Without this filter, the LEFT JOIN materializes a hash table containing every group of this type for the team, decompressing the (very wide) `group_properties` blob row by row — on high-volume teams that's enough to OOM the whole query." The optimizer only pushes the bounding filter down when the outer query's `WHERE` references `timestamp` on a plain unaliased `FROM events`. Always put a `timestamp` bound in the outer `WHERE` when joining events to groups.

---

## Quick reference: what to use for what

| Task | Mechanism |
|---|---|
| Create/update many groups | `POST /batch/`, `historical_migration: true`, `$groupidentify` events, ~1,000 per request, <20 MB |
| Create/update one group | `POST /i/v0/e/` with `$groupidentify` |
| Link an event to a group | `properties.$groups = {"<group_type>": "<group_key>"}` on a normal event (never creates the group) |
| List groups | `GET /api/projects/:id/groups/?group_type_index=N` (+ `search`, `group_key`, `cursor`) |
| Read one group | `GET /api/projects/:id/groups/find/?group_type_index=N&group_key=K&skip_create_notebook=true` |
| Map group type name ↔ index | `GET /api/projects/:id/groups_types/` |
| Delete a group | **Not possible** |
| Delete one group property | `POST /api/projects/:id/groups/delete_property/` with `{"$unset": "<key>"}` |
| Delete a group type | `DELETE /api/projects/:id/groups_types/:group_type_index/` |
| Verify a backfill / analytics | `POST /api/projects/:id/query/` with `kind: "HogQLQuery"` against `groups` / `events` |

Sources: [Capture and batch API endpoints](https://posthog.com/docs/api/capture) · [API overview](https://posthog.com/docs/api) · [Group analytics](https://posthog.com/docs/product-analytics/group-analytics) · [Groups API reference](https://posthog.com/docs/api/groups) · [API queries](https://posthog.com/docs/api/queries) · [Historical migrations](https://posthog.com/docs/migrate) · [Migration planning](https://posthog.com/docs/new-to-posthog/switch-guide/migration-planning) · [Ingestion warnings](https://posthog.com/docs/data/ingestion-warnings) · [Data deletion](https://posthog.com/docs/privacy/data-deletion) · [`ee/clickhouse/views/groups.py`](https://github.com/PostHog/posthog/blob/master/ee/clickhouse/views/groups.py) · [`posthog/api/rest_router.py`](https://github.com/PostHog/posthog/blob/master/posthog/api/rest_router.py) · [`posthog/models/group/util.py`](https://github.com/PostHog/posthog/blob/master/posthog/models/group/util.py) · [`posthog/models/group_type_mapping.py`](https://github.com/PostHog/posthog/blob/master/posthog/models/group_type_mapping.py) · [`posthog/hogql/database/schema/groups.py`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/groups.py) · [`posthog/hogql/database/schema/events.py`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/events.py) · [`posthog/hogql/database/database.py`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/database.py) · [`rust/capture/src/router.rs`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/router.rs) · [`rust/capture/src/v0_request.rs`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/v0_request.rs) · [`rust/capture/src/config.rs`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/config.rs) · [`rust/capture/src/api.rs`](https://github.com/PostHog/posthog/blob/master/rust/capture/src/api.rs) · [`rust/common/types/src/event.rs`](https://github.com/PostHog/posthog/blob/master/rust/common/types/src/event.rs) · [`posthog-migration-tools/migrate.py`](https://github.com/PostHog/posthog-migration-tools/blob/main/migrate.py)