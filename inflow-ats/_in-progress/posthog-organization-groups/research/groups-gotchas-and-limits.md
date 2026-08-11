I have enough verified material across all ten questions. Writing the report.

# PostHog Group Analytics — Practical Gotchas, Limits, and Failure Modes

Sources are cited inline. Where something is genuinely undocumented I say so rather than guessing; where I read PostHog's own source I quote it.

---

## 1. Hard limits

### Group types: 5 per project

> "**Group types** are categories you define - like "company" or "project". You can create up to 5 group types per project."
> "**Groups** are the individual entities within each type... You can have unlimited groups within each type."

Source: [group-analytics.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx)

The listed limitations section states verbatim:

- `Maximum of 5 group types per project`
- `You can delete group types, but not individual groups`
- `Multiple individual groups of the same group type can't be assigned to a single event`
- `Group types aren't supported for lifecycle insights or user paths`
- `Only individual groups with known properties appear in the people tab`

**What happens at the limit is NOT publicly documented.** No ingestion warning covers it (see the full warning list below), and I could not locate the enforcement point in the ingestion path — group-type creation has moved out of `plugin-server` into Rust/`personhog` and I could not retrieve the file. Treat "the 6th group type is silently dropped" as **unverified**. What is verifiable:

**Source-level constraint** (`posthog/models/group_type_mapping.py`):

```python
models.CheckConstraint(
    condition=models.Q(group_type_index__lte=5),
    name="group_type_index is less than or equal 5",
),
```

Note the discrepancy worth flagging: the DB check is `<= 5`, which permits indices 0–5 (six values), while the product limit is 5 group types and HogQL only exposes `$group_0`..`$group_4`. The HogQL schema is explicit — `"Group type index (0-4)"`. So the DB constraint is looser than the usable range.

### Group key length: 400 characters

From `posthog/models/group/group.py`:

```python
group_key = models.CharField(max_length=400, null=False, blank=False)
group_type_index = models.IntegerField(null=False, blank=False)
group_properties = models.JSONField(default=dict)
```

And `group_type` is likewise `models.CharField(max_length=400)`.

This is a **different limit from `distinct_id`**, which is 200 chars and is truncated rather than rejected:

> "`distinct_id` is limited to 200 characters. Longer values are shortened to the first 200 characters and the event is still ingested." — [capture API](https://posthog.com/docs/api/capture)

There is a corresponding ingestion warning, `Ingested event after shortening its distinct ID to the 200 character limit`. **There is no equivalent documented warning for an over-length group key** — do not assume it truncates gracefully.

Uniqueness constraint:

```python
models.UniqueConstraint(
    fields=["team_id", "group_key", "group_type_index"],
    name="unique team_id/group_key/group_type_index combo",
)
```

### Event/property size: 1MB, discarded not truncated

> "Discarded event exceeding 1MB limit — PostHog discards events exceeding 1 megabyte in size after processing."

Source: [Ingestion warnings](https://posthog.com/docs/data/ingestion-warnings)

This matters for `$group_set` with large property blobs. Related open issues on the same 1MB ceiling: [posthog-js#2134](https://github.com/PostHog/posthog-js/issues/2134), [posthog#7068](https://github.com/PostHog/posthog/issues/7068).

### The one group-specific ingestion warning

> "**Discarded `$groupidentify` event with invalid `$group_set`** — `$group_set` property must be a plain object" containing valid data types.

Source: [Ingestion warnings](https://posthog.com/docs/data/ingestion-warnings). This is the failure mode to monitor: a non-object `$group_set` (array, string, null) causes the **whole `$groupidentify` event to be discarded**, silently, and your group properties never appear.

### Cardinality: no documented limit, but a real OOM failure mode

There is no documented cap on groups per type ("unlimited"). But PostHog's own HogQL source documents a query-level blowup (`posthog/hogql/database/schema/groups.py`):

> "Without this filter, the LEFT JOIN materializes a hash table containing every group of this type for the team, decompressing the (very wide) `group_properties` blob row by row — on high-volume teams that's enough to OOM the whole query even when only a handful of events are actually being selected."

The mitigation is a prefilter that only kicks in when your `WHERE` clause **references `timestamp`** and your `FROM` is a **plain unaliased `events`**. Aliasing your events table (`FROM events AS e`) or omitting a date bound disables the optimization. This is the single most practically important undocumented gotcha I found.

---

## 2. What breaks when a group key changes

**There is no merge, rename, or alias operation for groups.** Persons have `alias()` and merge semantics; groups have nothing equivalent.

The Groups API surface is exactly ([Groups API](https://posthog.com/docs/api/groups)):

- `GET /api/projects/:project_id/groups/`
- `POST /api/projects/:project_id/groups/`
- `GET /api/projects/:project_id/groups/activity/`
- `POST /api/projects/:project_id/groups/delete_property/`
- `GET /api/projects/:project_id/groups/find/`
- `GET /api/projects/:project_id/groups/property_values/`
- `GET /api/projects/:project_id/groups/related/`
- `POST /api/projects/:project_id/groups/update_property/`

No merge endpoint. No key-rewrite endpoint. Scopes are `group:read` / `group:write`.

Consequences of changing an org's group key (numeric ID → UUID, or ID reassignment):

1. **You get two groups.** Historical events keep the old `$group_0` value; new events carry the new one. Every group-aggregated insight double-counts the account as two entities.
2. **No backfill path for existing events.** `$group_N` is written onto the event row at ingestion. There is no documented way to rewrite it after the fact.
3. **Funnels and retention break across the boundary** — a funnel aggregated by group will never see a company complete steps that straddle the key change.
4. **Feature flag bucketing changes.** Flags hash the group key: "everyone in the same group sees the same flag value because PostHog hashes the group key, not the individual user" ([user and group targeting](https://posthog.com/docs/feature-flags/user-and-group-targeting)). A new key rehashes into a different bucket, so a percentage rollout can flip a customer's flag state.
5. **You cannot delete the orphan.** "You can delete group types, but not individual groups."

What *is* renameable is only the **display label** of the group type, in Settings → Customer Analytics. The underlying `group_type` string and all `$group_key` values are untouched.

Deleting a group type has a documented, surprising resurrection behavior:

> - Event data remains unchanged. Group data is filtered from queries based on a deletion timestamp.
> - Deleted group types don't count toward your 5 group type limit.
> - **If new events arrive with the same group key, the group type reappears with a new creation timestamp. Historical events (before the new timestamp) won't appear for the recreated group type.**

So delete-then-recreate is a **data-losing** operation for historical analysis, implemented as a timestamp filter rather than a real delete — a design chosen because "deletions [are] expensive in clickhouse" ([issue #10953](https://github.com/PostHog/posthog/issues/10953)).

---

## 3. Recommended group key

PostHog's docs say, verbatim:

> - Use singular names for group types - "company" not "companies"
> - **Use unique IDs as keys for individual groups, not names because names can duplicate**
> - Each project can have up to 5 group types
> - You can have unlimited individual groups within each type

The code samples consistently use `'company_id_in_your_db'` as the placeholder, and the doc prose says "we set the group key like an ID or domain."

**So: your internal DB primary key is the documented recommendation.** The stated reason is uniqueness/stability, not opacity. The docs do *not* express a preference between integer PK and UUID.

Given §2, the practical criterion is **immutability**, not format. Pick whichever identifier in your system is guaranteed never to be reassigned or reformatted. A numeric PK is fine if it's never recycled. A domain/slug is the weakest choice — those get changed by customers (rebrand, domain migration), and each change orphans the group.

The UI display name is separate from the key: set a `name` property in `$group_set`, and PostHog falls back to the key when `name` is absent. Note also: **"Only individual groups with known properties appear in the people tab"** — a group with zero properties is invisible in the UI even though its events are attributed correctly.

---

## 4. Cost and quota

This is the biggest reported gotcha, and PostHog flags it themselves in a callout box:

> **All identified events count toward billing**
> "Once you subscribe to group analytics, billing applies to **all identified events** in your project, not just events with group properties attached. This is because group analytics enables infrastructure that processes all identified events to support group-level analysis."

Plus:

> - "Billing starts when you enable group analytics from your billing page, **not when you add group analytics code** to your application."
> - "Usage is based on captured identified events, **even if they don't include group properties**."
> - "Billing stops when you unsubscribe from the billing page. You don't need to remove group analytics code from your application to stop billing."

**Pricing** ([posthog.com/addons](https://posthog.com/addons)): starts at **$0.000071/event**, with **first 1,000,000 events/mo free**, tiering down to $0.0000029/event at 250M+.

So on quota: yes, there is a 1M/month free allowance on the group analytics add-on line itself. But the metric is *identified events project-wide*, not group-tagged events — which is why a project with 50M identified events and 100k group-tagged events is billed on 50M.

Does `$groupidentify` inflate event count? Yes — it is an ordinary event and is captured, ingested, and counted. More significantly, **calling `group()` makes the event identified**, and identified events are the expensive tier. PostHog is explicit that this pricing is a known adoption problem, from their own mega-issue ([#64893](https://github.com/PostHog/posthog/issues/64893)):

> "**Pricing doesn't align with value** — We currently charge based on identified events, not group-tagged events. This confuses customers and discourages adoption when only a small share of their events are group-tagged."

And their planned fix, sub-issue 3: "**Pricing metric change** — Base group pricing on group events, not identified events."

The single most-cited real failure, from PostHog's **own sales handbook** ([health checks](https://posthog.com/handbook/growth/sales/health-checks)):

> "They do however need to implement group tracking in their PostHog SDK. Customers who haven't done this may end up **paying for Group Analytics but not able to use it**."

Quantified in [#64893](https://github.com/PostHog/posthog/issues/64893): "**20% of organizations paying for group analytics aren't collecting any group events.**"

---

## 5. Backfill

### The hard constraint: there is no historical tagging

PostHog states this repeatedly. From [#64893](https://github.com/PostHog/posthog/issues/64893):

> "Because **there's no historical tagging**, adopting it late permanently loses data."
> "Group analytics is most impactful when it's instrumented from day one, **since there's no historical tagging**."

So "backfill" splits into two very different problems:

**(a) Backfilling group *properties* — easy.** Just send `$groupidentify` for each account. Group properties are latest-value, stored on the group row, not on events. A loop over your accounts table calling `group_identify` brings every group current. Python signature (from `posthog/__init__.py` in [posthog-python](https://github.com/PostHog/posthog-python)):

```python
def group_identify(
    group_type: str,
    group_key: str,
    properties: Optional[Dict[str, Any]] = None,
    timestamp: Optional[datetime.datetime] = None,
    uuid: Optional[str] = None,
    disable_geoip: Optional[bool] = None,
    distinct_id: Optional[ID_TYPES] = None,
) -> Optional[str]:
```

Both `group_type` and `group_key` are "Required - **the call is dropped with a warning** if it is missing or empty." That silent-drop-with-warning is a backfill footgun: an account row with a null ID produces no error you'll notice.

Raw API shape ([capture API](https://posthog.com/docs/api/capture)):

```json
{
  "api_key": "<ph_project_token>",
  "event": "$groupidentify",
  "distinct_id": "groups_setup_id",
  "properties": {
    "$group_type": "<group_type>",
    "$group_key": "<company_name>",
    "$group_set": {
      "name": "<company_name>",
      "subscription": "premium",
      "date_joined": "[optional timestamp in ISO 8601 format]"
    }
  }
}
```

Note the static `distinct_id` (`"groups_setup_id"`) — that is the documented pattern for group events with no associated user.

**(b) Backfilling `$group_N` onto *existing* events — not supported.** No API rewrites `$group_0` on ingested events. Your options are re-importing the events (a historical migration, which duplicates unless you first delete) or accepting the gap.

### Batch API and limits

> "You can capture multiple events in one request with the `/batch` API route. **There is no limit on the number of events you can send in a batch, but the entire request body must be less than 20MB by default.**"

> "When running migrations, the `historical_migration` field **must be set to `true`**. This ensures that events are processed in order without triggering our spike detection systems."

Sources: [capture API](https://posthog.com/docs/api/capture), [historical migrations](https://posthog.com/docs/migrate)

Rate limiting: imported events run on a separate historical ingestion pipeline and are **not** subject to the per-`distinct_id` ingestion rate limit that applies to live capture. Practical batch size is 1000 (the cited PostHog Cloud maximum). Over 100 GB / 200M events, PostHog asks you to contact them.

Historical migration events are **free** ("historic imports are free but this unlocks the necessary features"), though a paid plan is required. Timestamps must be ISO 8601 and **at least 48 hours in the past**.

### The documented backfill script pattern

PostHog's own [posthog-migration-tools/migrate.py](https://github.com/PostHog/posthog-migration-tools/blob/main/migrate.py) is the reference pattern — and it is very plain:

```python
Posthog(api_key=api_token, host=url, debug=debug, historical_migration=True)
```

with `--batch-size` defaulting to `100`, per-event `posthog_client.capture()`, and `posthog_client.flush()` every `batch_size` events. **There is no retry or backoff logic in the script** — it delegates entirely to the SDK. If you build a large backfill, add your own.

### The backfill trap that actually bites

[Issue #39989](https://github.com/posthog/posthog/issues/39989) — **"Event metadata group filters don't work for historical migration events"** (open):

> "historical events imported from Amplitude are not included in results, even though: 1. The events have `$group_0` correctly set in their properties JSON 2. The same events ARE visible when viewing them on the group detail page."

Root cause: the materialized `$group_0` column is not populated for imports. Insight filters read the **materialized column** (empty); group detail pages read `properties.$group_0` (populated). Verification query in the issue shows `from_properties` populated while `from_column` is empty.

So a group backfill via historical migration can look correct on the group page and silently return nothing in insights. Budget verification time for exactly this.

---

## 6. Session replay + groups

**Group property filters on recordings do work** — but this is not documented anywhere I could find, and the docs actively suggest otherwise. I verified it in source.

[how-to-watch-recordings.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/session-replay/how-to-watch-recordings.mdx) lists filters as "date, active duration, activity counts, events, properties, console logs, feature flags, and more" — **groups are not mentioned**. Neither the [session replay troubleshooting](https://posthog.com/docs/session-replay/troubleshooting) page nor the group analytics limitations list mentions replay.

Source says otherwise. In `posthog/session_recordings/queries/sub_queries/events_subquery.py`:

```python
@property
def group_properties(self):
    return [g for g in (self._query.properties or []) if is_group_property(g)]
```

and in `_get_queries_for_matching`:

```python
for p in self.group_properties:
    if skip_negative_properties and is_negative_prop(p):
        continue
    gathered_exprs.append(property_to_expr(p, team=self._team))
```

Group filters are resolved as an **events subquery matching `session_id`**, then joined into the outer recording query via `GlobalIn`. Negative operators (`is_not`, `not_icontains`, …) route through `_negative_blocklist_query()` instead.

Implications and limits:

1. **A recording only matches if the session produced at least one analytics event carrying `$group_N`.** Replay-only sessions (recording captured, no product-analytics events) are invisible to group filters. This is the same class of caveat PostHog documents generally: "Some filtering options in session replays depend on Product Analytics events... capture at least one event per session."
2. The events subquery is capped: `limit_expr=ast.Constant(value=1000000)`.
3. The date window is padded ±1 day around the recording range, because "you can start sending us events before the session starts."
4. In `session_recording_list_from_query.py`, group properties are removed from the outer query by `_strip_person_and_event_and_cohort_properties` (which despite its name also strips group, session, and recording properties). Anything left over triggers `capture_exception(UnexpectedQueryProperties(...))` — so an unhandled filter type fails to a silently-ignored filter, not an error surfaced to you.
5. Note the inconsistency: group properties are converted with `property_to_expr(p, team=self._team)` with **no `scope` argument**, unlike person (`scope="event"`) and event (`scope="replay"`) filters.

---

## 7. Cohorts + groups

**You cannot build a cohort of groups, and you cannot build a cohort of people using group properties.** Cohorts are person-only.

[Cohorts docs](https://posthog.com/docs/data/cohorts) distinguish them:

> "Groups aggregate events based on entities, such as organizations or companies, but do not necessarily connect to a user."

and the group analytics doc:

> - "**Groups** aggregate events and don't have to be connected to users. They require code in your app to set up."
> - "**Cohorts** represent specific sets of users with something in common. They're created in PostHog without additional code."

There is also a narrower restriction: **"Cohorts used in CDP destination filters must contain exclusively person property filters."**

[Issue #62986](https://github.com/PostHog/posthog/issues/62986), "Allow cohorts to be created using group properties" (open), states the gap precisely:

> "Cohorts are person-property-based, so there's no way to define a cohort like 'users belonging to clinics in country X' or 'users at a specific named clinic'."

The workarounds enumerated in that issue, with the reporter's own assessment:

1. Target group properties directly in surveys — manual per survey, no central maintenance
2. Feature flags with group conditions — "doesn't work with analytics"
3. Copy group data onto person properties — works, but "defeats the purpose of having group analytics"
4. Behavioural cohorts on `$groupidentify` events — ineffective for surveys and feature flags

Option 3 is what most teams end up doing. PostHog acknowledges the whole area in [#64893](https://github.com/PostHog/posthog/issues/64893): "**Doesn't play well with cohorts** — A known issue: groups can't be used as filters or as properties to build cohorts." Their planned fix is person-level group tagging ([#65190](https://github.com/PostHog/posthog/issues/65190)), which would make group→person cohorts possible. Also open: [#10847](https://github.com/PostHog/posthog/issues/10847), "Cohort: Ability to require current relationship to specific group type" (open since **2022**).

Behavioural cohorts *on groups* (e.g. "companies that did X 3 times last week") do not exist. Group-level behaviour is expressed through insights with `Aggregating by` set to the group type, not through cohorts.

---

## 8. Feature flags targeted at groups

### How it works

Release conditions get a **Target by** dropdown selecting a group type; you then filter on group properties and set a rollout percentage. Crucially:

> "everyone in the same group sees the same flag value because PostHog hashes the group key, not the individual user"

Each condition set within one flag can target a different entity ([user and group targeting](https://posthog.com/docs/feature-flags/user-and-group-targeting)).

### Exact signatures

Every flag method in [posthog-python](https://github.com/PostHog/posthog-python) takes the same pair:

```python
def get_feature_flag(
    key: str,
    distinct_id: ID_TYPES,
    groups: Optional[Mapping[str, Union[str, int]]] = None,
    person_properties: Optional[Dict[str, Any]] = None,
    group_properties: Optional[Dict[str, Dict[str, Any]]] = None,
    only_evaluate_locally: bool = False,
    send_feature_flag_events: bool = True,
    disable_geoip: Optional[bool] = None,
    device_id: Optional[str] = None,
) -> Optional[FlagValue]:
```

With the shapes documented in the docstring:

> "`groups` are a mapping from group type to group key. So, if you have a group type of "organization" and a group key of "5", you would pass `groups={"organization": "5"}`. `group_properties` take the format: `{ group_type_name: { group_properties } }`. So, for example... `group_properties={"organization": {"name": "PostHog", "employees": 11}}`."

Same parameters on `feature_enabled`, `get_all_flags`, `get_feature_flag_result`, `get_feature_flag_payload`, `get_all_flags_and_payloads`, and the newer `evaluate_flags`. Current documented style is the consolidated call:

```python
flags = posthog.evaluate_flags(
    "user_distinct_id",
    groups={"company": "company_id_in_your_db"},
)
if flags.is_enabled("new-groups-feature"):
```

```javascript
const flags = await posthog.evaluateFlags('user_distinct_id', {
    groups: { company: 'company_id_in_your_db' },
})
```

On the JS web SDK you call `posthog.group()` once and the session carries it.

### Caveats

**You must supply the properties yourself.** From [local evaluation](https://posthog.com/docs/feature-flags/local-evaluation):

> "You are responsible for providing every property the flag's release conditions depend on. If you forget to pass a property, the SDK can't evaluate the flag locally and will either fall back to a remote request or return `undefined`."

There is no server-side lookup of a group's stored properties during local evaluation. `$groupidentify` properties are **not** available to the local evaluator — passing `groups=` without `group_properties=` will not evaluate a property-filtered group condition locally.

**Polling.** Flag definitions refresh every **30 seconds** by default (`poll_interval = 30` in posthog-python; Go SDK defaults to 5 minutes), tunable via `featureFlagsPollingInterval` in ms. This is the *definition* cache, not a group-property cache.

**Group type mapping cache.** From `posthog/models/group_type_mapping.py`:

```python
GROUP_TYPES_CACHE_TTL = 60 * 5              # 5 minutes
GROUP_TYPES_STALE_CACHE_TTL = 60 * 60 * 24  # 24 hours — last-known-good fallback during outages
GROUP_TYPES_NEGATIVE_CACHE_TTL = 30         # seconds
```

A brand-new group type can take up to 5 minutes to become visible to flag evaluation. The code comments explain why they fail closed: "an empty mapping makes every group-aggregated flag for the team evaluate to false."

**An open correctness bug — negative operators fail open.** [Issue #79209](https://github.com/PostHog/posthog/issues/79209) (open, filed 2026-08-07): "Feature flags: group property filters have no fetched-vs-missing distinction, so negative operators fail open on fetch misses."

> When evaluating a condition like `organization.tier is_not "enterprise"`, the system matches groups whose tier property was never fetched — **even if that group actually has tier set to "enterprise."**

`get_group_properties_from_evaluation_state` returns an empty map on cache misses, conflating "never fetched" with "genuinely absent." The equivalent bug was fixed for *person* properties (via `PersonPropertyState` distinguishing `Pending` from `Fetched`, PR #75929), and that fix **explicitly excludes group filters**. If you are gating anything sensitive on a negated group property, this is live.

**Local evaluation in serverless.** "in edge/lambda environments and stateless PHP applications, local evaluation with the default in-memory cache causes performance issues and inflated costs due to per-request initialization."

**Related open work:** [#46288](https://github.com/PostHog/posthog/issues/46288) Mixed User + Group Targeting mega-issue, [#46298](https://github.com/PostHog/posthog/issues/46298)/[#46299](https://github.com/PostHog/posthog/issues/46299)/[#46300](https://github.com/PostHog/posthog/issues/46300) per-condition-set aggregation (model, Rust evaluator, UI), [#52024](https://github.com/PostHog/posthog/issues/52024) frontend null checks for `aggregation_group_type_index`. Per-condition-set group aggregation is **not shipped**.

---

## 9. Data warehouse / SQL access (HogQL)

### The `groups` table

From `posthog/hogql/database/schema/groups.py`, `GROUPS_TABLE_FIELDS` — HogQL name → ClickHouse column:

| HogQL field | ClickHouse column | Description (verbatim from source) |
|---|---|---|
| `index` | `group_type_index` | "Group type index (0-4); identifies which group type this row belongs to, matching `events.$group_N`." |
| `team_id` | `team_id` | — |
| `key` | `group_key` | "Unique key for the group within its group type; join target for `events.$group_N`." |
| `created_at` | `created_at` | "When the group was first created in PostHog." |
| `updated_at` | `_timestamp` | "When this group row was last written (ingestion timestamp); used to pick the latest version." |
| `properties` | `group_properties` | "JSON map of group properties (latest known values). Access keys with `properties.name` etc." |
| `revenue_analytics` | (lazy join) | joins `GroupsRevenueAnalyticsTable` |

Two tables, and the difference matters:

- **`groups`** — `GroupsTable(LazyTable)`: "Deduplicated groups (companies, organizations, etc.) in the project, with their latest properties. **One row per (group type, group key).** Join from events via `events.$group_N = groups.key`."
- **`raw_groups`** — `RawGroupsTable(Table)`: "Raw, un-deduplicated groups rows (**one per update**). Query `groups` instead unless you need to resolve the latest version of each group's properties yourself."

Deduplication is `argmax_select(..., group_fields=["index", "key"], argmax_field="updated_at")`. Querying `raw_groups` naively gives you one row per `$groupidentify` you ever sent.

### Event-side fields

Events carry `$group_0` … `$group_4`. HogQL also exposes lazy-join aliases on the events table, listed in source as `EVENTS_LAZY_JOIN_ALIASES`:

```python
"group_0", "group_1", "group_2", "group_3", "group_4",
"goe_0", "goe_1", "goe_2", "goe_3", "goe_4",
```

plus **per-project group-type-name aliases** — if your group type is `organization`, `events.organization.properties.name` resolves through the lazy join. This is the ergonomic path and is barely documented; the source comment calls them "the per-project group-type-name aliases (e.g. `organization`)."

### Querying

Join explicitly:

```sql
SELECT groups.properties.name, count()
FROM events
LEFT JOIN groups ON events.$group_0 = groups.key AND groups.index = 0
WHERE timestamp > now() - INTERVAL 7 DAY
GROUP BY groups.properties.name
```

or let the lazy join do it (`events.organization.properties.name`). The [data warehouse source docs](https://posthog.com/docs/data-warehouse/sources/posthog) confirm the public schema: `index` ("zero-based, so the first group type listed is `0`"), `key`, `created_at`, `updated_at`, `properties`.

### Performance gotchas

1. **The OOM risk in §1.** The prefilter that bounds the join hash table requires your `WHERE` to reference `timestamp` and your `FROM` to be a plain unaliased `events`. `FROM events AS e`, a JOIN on the outer query, or a subquery all disable it.
2. **`groups` is `Distributed(rand())`.** Source: "GLOBAL IN, not IN: groups is Distributed(rand()); a plain IN dedups per-shard over a subset of versions." Hand-written cross-shard subqueries need `GLOBAL IN`.
3. **Filtering on group properties has been historically slow** — [issue #21320](https://github.com/PostHog/posthog/issues/21320), "HogQL: Filter groups through subquery instead of join" (open since 2024).
4. **Dashboard filter bug:** [#56231](https://github.com/PostHog/posthog/issues/56231) — "retention insights on dashboards error out when a group property filter is applied to the dashboard" (open).

---

## 10. Real-world reports of things going wrong

Ranked by how likely they are to bite you.

**Paying and not collecting.** PostHog's own numbers, [#64893](https://github.com/PostHog/posthog/issues/64893): "20% of organizations paying for group analytics aren't collecting any group events." "Only 8.5% of users are tagging events with groups." Their sales handbook warns reps that customers "may end up paying for Group Analytics but not able to use it." Billing is a toggle; instrumentation is separate; nothing connects them.

**Group properties invisible in filters.** [Issue #42520](https://github.com/PostHog/posthog/issues/42520) (closed) — "Group properties created by groupidentify events are not persisted by propdefs service." Property *values* appeared in the product while property *definition* filters stayed empty, because `property-defs-rs` wasn't processing `$groupidentify`. PR #42062 was a "temporary spot fix." Related and still open: [#64253](https://github.com/PostHog/posthog/issues/64253) — "property-defs-rs: batch write to posthog_propertydefinition fails entirely on duplicate keys within same batch," which is exactly the shape a bulk backfill produces.

**Historical imports invisible to insight filters.** [Issue #39989](https://github.com/posthog/posthog/issues/39989), detailed in §5. Materialized column vs JSON property divergence. Open.

**Negative group property operators fail open in flags.** [Issue #79209](https://github.com/PostHog/posthog/issues/79209), detailed in §8. Open.

**Events silently not linked to groups.** The most common self-inflicted one, documented: "Events must be identified to link to individual groups. **If `$process_person_profile` is set to `false`, the event won't link to the group.**" So anonymous-event cost optimization silently destroys group attribution. Tracked as [#49905](https://github.com/PostHog/posthog/issues/49905), "Allow for person-less events."

**Frontend: stale group after logout.** From [frontend vs backend group analytics](https://posthog.com/tutorials/frontend-vs-backend-group-analytics): "**Critical gotcha**: You must call `posthog.reset()` when users log out to prevent events from being incorrectly associated with previous user/group combinations." The JS SDK is stateful and persists the group across the session; backend SDKs are stateless and require `groups=` on every single `capture()`.

**Silent property loss on backend.** Also from that tutorial: backends cannot update group properties through `capture()` — a separate `group_identify()` is required, deliberately "preventing accidental data loss from omitted properties on subsequent captures."

**Duplicate group type keys in one call.** The docs show the trap explicitly — `groups={'company': 'a', 'company': 'b'}` in Python is not an error, it's a dict literal that silently keeps the last value. Same in PHP.

**Structural mismatch with how teams think.** [#64893](https://github.com/PostHog/posthog/issues/64893): "An estimated 80%+ of customers use groups for accounts, organizations, teams, or businesses. They expect users to belong to groups, but we instrument groups at the event level." This is the root of the cohort, survey, and experiment friction.

**Where PostHog is heading.** [#64893](https://github.com/PostHog/posthog/issues/64893) proposes: group analytics in the free tier; a UI toggle instead of a billing toggle; pricing on group events not identified events; person-less events; **person-level group tagging** ([#65190](https://github.com/PostHog/posthog/issues/65190)) so tagging on `identify` propagates to every subsequent event; and groups usable in cohorts/surveys/experiments ([#62986](https://github.com/PostHog/posthog/issues/62986)). A "Customer Analytics" preview and a [B2B mode](https://posthog.com/docs/customer-analytics/b2b-mode.md) (beta, free, but "only available for organizations with group analytics add-on") are the visible front end of this. If you're designing now, expect the ergonomics to shift.

---

## Sources

- [Group analytics docs (raw mdx)](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx) · [rendered](https://posthog.com/docs/product-analytics/group-analytics.md)
- [User and group targeting](https://posthog.com/docs/feature-flags/user-and-group-targeting)
- [Local evaluation](https://posthog.com/docs/feature-flags/local-evaluation)
- [Capture and batch API](https://posthog.com/docs/api/capture)
- [Groups API](https://posthog.com/docs/api/groups) · [Group types API](https://posthog.com/docs/api/groups-types)
- [Ingestion warnings](https://posthog.com/docs/data/ingestion-warnings)
- [Cohorts](https://posthog.com/docs/data/cohorts)
- [Historical migrations](https://posthog.com/docs/migrate) · [posthog-migration-tools/migrate.py](https://github.com/PostHog/posthog-migration-tools/blob/main/migrate.py)
- [Data warehouse: PostHog source schema](https://posthog.com/docs/data-warehouse/sources/posthog)
- [Frontend vs backend group analytics](https://posthog.com/tutorials/frontend-vs-backend-group-analytics)
- [Add-on pricing](https://posthog.com/addons)
- [Sales handbook health checks](https://posthog.com/handbook/growth/sales/health-checks)
- [B2B mode](https://posthog.com/docs/customer-analytics/b2b-mode.md)
- Source files: `posthog/models/group/group.py`, `posthog/models/group_type_mapping.py`, `posthog/hogql/database/schema/groups.py`, `posthog/session_recordings/queries/session_recording_list_from_query.py`, `posthog/session_recordings/queries/utils.py`, `posthog/session_recordings/queries/sub_queries/events_subquery.py` (PostHog/posthog @ `29880c9`); `posthog/__init__.py` (PostHog/posthog-python @ `6e5389a`)
- Issues: [#64893](https://github.com/PostHog/posthog/issues/64893) · [#79209](https://github.com/PostHog/posthog/issues/79209) · [#42520](https://github.com/PostHog/posthog/issues/42520) · [#39989](https://github.com/posthog/posthog/issues/39989) · [#62986](https://github.com/PostHog/posthog/issues/62986) · [#10953](https://github.com/PostHog/posthog/issues/10953) · [#21320](https://github.com/PostHog/posthog/issues/21320) · [#10847](https://github.com/PostHog/posthog/issues/10847) · [#46288](https://github.com/PostHog/posthog/issues/46288) · [#65190](https://github.com/PostHog/posthog/issues/65190) · [#49905](https://github.com/PostHog/posthog/issues/49905) · [#56231](https://github.com/PostHog/posthog/issues/56231) · [#64253](https://github.com/PostHog/posthog/issues/64253) · [#21664](https://github.com/PostHog/posthog/issues/21664)

**Two things I could not verify** and deliberately did not assert: the exact behavior when a 6th group type is sent (enforcement point is in Rust/`personhog`, which I could not retrieve; the DB check constraint is `group_type_index <= 5` while the usable range is 0–4), and whether an over-length group key truncates or is rejected (no ingestion warning documents it, unlike the 200-char `distinct_id` case).