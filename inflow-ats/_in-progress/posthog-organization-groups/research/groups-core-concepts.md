# PostHog Group Analytics — Core Concepts

Sources are cited inline. Every code block is quoted verbatim from the cited file/page.

---

## 1. Group type vs. group key vs. group properties

Exact terminology from the docs source ([`contents/docs/product-analytics/group-analytics.mdx`](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx), rendered at <https://posthog.com/docs/product-analytics/group-analytics>):

> **Group types** are categories you define - like "company" or "project". You can create up to 5 group types per project.
>
> **Groups** are the individual entities within each type. For example, if your group type is "company," each group would be a specific company like "Acme Corp" or "Tech Solutions Inc." You can have unlimited groups within each group type.

> ### How it works
> 1. Define group types - like "company" or "channel"
> 2. Assign group keys (unique identifiers) to each group
> 3. Link events to groups in your code
> 4. Analyze data by group instead of by user

Docs tips callout, verbatim:

> - Use singular names for group types - "company" not "companies"
> - Use unique IDs as keys for individual groups, not names because names can duplicate
> - Each project can have up to 5 group types
> - You can have unlimited individual groups within each type

**Group properties**: from [`contents/docs/_snippets/setting-group-properties.mdx`](https://github.com/PostHog/posthog.com/blob/master/contents/docs/_snippets/setting-group-properties.mdx):

> In the same way that every person can have properties associated with them, every group can have properties associated with it.
>
> **Note:** You must include at least one group property for a group to be visible in the People and groups tab.
>
> **Note:** The PostHog UI identifies a group using the `name` property. If the `name` property is not found, it falls back to the group key.

**Storage-level identifiers** ([`posthog/models/group_type_mapping.py`](https://github.com/PostHog/posthog/blob/master/posthog/models/group_type_mapping.py)):

| Concept | Postgres | ClickHouse / query layer |
|---|---|---|
| group type | `posthog_grouptypemapping.group_type` (`CharField(max_length=400)`) | — |
| group type index | `posthog_grouptypemapping.group_type_index` (`IntegerField`) | `events.$group_0` … `events.$group_4` columns |
| group key | `posthog_group.group_key` | `groups.group_key` |
| group properties | `posthog_group.group_properties` (jsonb) | `groups.group_properties` |
| display names | `name_singular`, `name_plural` on `GroupTypeMapping` | — |

HogQL field descriptions ([`posthog/hogql/database/schema/groups.py`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/groups.py)):

```python
"index": IntegerDatabaseField(
    name="group_type_index", nullable=False,
    description="Group type index (0-4); identifies which group type this row belongs to, matching `events.$group_N`.",
),
"key": StringDatabaseField(
    name="group_key", nullable=False,
    description="Unique key for the group within its group type; join target for `events.$group_N`.",
),
"properties": StringJSONDatabaseField(
    name="group_properties", nullable=False,
    description="JSON map of group properties (latest known values). Access keys with `properties.name` etc.",
),
```

Length limits, from <https://posthog.com/docs/api/capture> ("Group identify" section):

> - `$group_type` must be at most 400 characters long
> - `$group_key` must be at most 400 characters long

---

## 2. Group type limit, overflow behavior, deletion, renaming, index assignment

### Limit: 5 per project

Docs "Limitations" section, verbatim:

> - Maximum of 5 group types per project
> - You can delete group types, but not individual groups
> - Multiple individual groups of the same group type can't be assigned to a single event
> - Group types aren't supported for lifecycle insights or user paths
> - Only individual groups with known properties appear in the [people tab](https://app.posthog.com/persons)

Enforced in code at [`nodejs/src/common/groups/group-type-manager.ts`](https://github.com/PostHog/posthog/blob/master/nodejs/src/common/groups/group-type-manager.ts):

```ts
/** How many unique group types to allow per team */
export const MAX_GROUP_TYPES_PER_TEAM = 5
```

Also duplicated as a module constant in [`nodejs/src/common/groups/repositories/postgres-group-repository.ts`](https://github.com/PostHog/posthog/blob/master/nodejs/src/common/groups/repositories/postgres-group-repository.ts):

```ts
const MAX_GROUP_TYPES_PER_TEAM = 5
```

And as a Postgres check constraint on the model ([`posthog/models/group_type_mapping.py`](https://github.com/PostHog/posthog/blob/master/posthog/models/group_type_mapping.py)):

```python
models.UniqueConstraint(fields=("project", "group_type"), name="unique group types for project"),
models.UniqueConstraint(fields=("project", "group_type_index"), name="unique event column indexes for project"),
models.CheckConstraint(
    condition=models.Q(group_type_index__lte=5),
    name="group_type_index is less than or equal 5",
),
```

Note the constraint is `<= 5` (looser than the real limit); the ingestion code is what enforces indices 0–4. Read paths hard-fail outside that range:

```ts
if (row.group_type_index < 0 || row.group_type_index > 4) {
    throw new Error(
        `Invalid group_type_index ${row.group_type_index} for team ${row.team_id}. Must be between 0 and 4.`
    )
}
```

### What happens when you exceed the limit

The docs do **not** state this. The source does — the 6th group type is **silently ignored**. `fetchGroupTypeIndex` returns `null`:

```ts
public async fetchGroupTypeIndex(
    teamId: TeamId, projectId: ProjectId, groupType: string, eventTimestamp: DateTime
): Promise<GroupTypeIndex | null> {
    const existingIndex = await this.lookupGroupTypeIndex(projectId, groupType)
    if (existingIndex !== null) {
        return existingIndex
    }

    const groupTypes = await this.fetchGroupTypes(projectId)

    const usedIndexes = new Set(Object.values(groupTypes))
    if (usedIndexes.size >= MAX_GROUP_TYPES_PER_TEAM) {
        return null
    }
    ...
}
```

Consequences of that `null`, traced through the pipeline:

- In [`groups.ts`](https://github.com/PostHog/posthog/blob/master/nodejs/src/ingestion/common/steps/event-processing/groups.ts) `addGroupProperties`, the type is skipped, so **no `$group_N` property is written to the event**. The `$groups` map still rides along in the raw event `properties`, but it is not queryable as a group.
- In [`process-groups-step.ts`](https://github.com/PostHog/posthog/blob/master/nodejs/src/ingestion/common/steps/event-processing/process-groups-step.ts) `upsertGroup`, `if (groupTypeIndex !== null)` gates the write, so **no `posthog_group` row is created**.

There is no ingestion warning and no error response — the capture endpoint returns 200 regardless (<https://posthog.com/docs/api/capture> "Invalid events": "you still receive a `200: OK` response").

A defensive second gate exists in `insertGroupType`:

```ts
async insertGroupType(teamId, projectId, groupType, index, createdAt, tx?): Promise<[GroupTypeIndex | null, boolean]> {
    if (index < 0 || index >= MAX_GROUP_TYPES_PER_TEAM) {
        return [null, false]
    }
    ...
```

### Deletion — yes, supported, and it frees the index

Docs, verbatim:

> ### Delete group types
> To delete a group type:
> 1. Go to [Settings > Customer Analytics](https://app.posthog.com/settings/project-customer-analytics#group-analytics) in the PostHog app.
> 2. Under **Group analytics**, click **Delete** next to the group type you want to remove.
>
> **What happens when you delete a group type**
> - Event data remains unchanged. Group data is filtered from queries based on a deletion timestamp.
> - Deleted group types don't count toward your 5 group type limit.
> - If new events arrive with the same group key, the group type reappears with a new creation timestamp. Historical events (before the new timestamp) won't appear for the recreated group type.

Implementation: `delete_group_type_mapping()` in `posthog/models/group_type_mapping.py` issues a `DeleteGroupTypeMappingRequest(project_id, group_type_index)` — the mapping row goes away, which is what frees the index for reuse by `fetchGroupTypeIndex`'s "lowest unused index" logic.

### Renaming — display name only, not the underlying `group_type` string

Docs, verbatim:

> ### Rename group types
> Change how group types display in PostHog in [Settings > Customer Analytics](https://app.posthog.com/settings/project-customer-analytics#group-analytics).

What that edits is `name_singular` / `name_plural` on `GroupTypeMapping` — `update_group_type_mapping_fields()` takes `{"name_singular": ..., "name_plural": ...}`. The `group_type` string itself (the key you send in `$groups` / `$group_type`) is **not** renameable; renaming it would require rewriting every event row. PostHog states this explicitly in [issue #11224](https://github.com/PostHog/posthog/issues/11224):

> As an aside, this type of operation could also unblock the ability to rename group types (though we probably want to be careful with exposing that because it seems trivial to the end user but could be really expensive depending on rows affected)

That issue is **closed as `not_planned`** (closed 2024-07-08).

### Index assignment: lowest available index, not strictly order of first appearance

The common case is order of first appearance, but the actual rule is **lowest unused index**, which differs after a delete:

```ts
const usedIndexes = new Set(Object.values(groupTypes))
if (usedIndexes.size >= MAX_GROUP_TYPES_PER_TEAM) {
    return null
}

let nextAvailableIndex = 0
while (usedIndexes.has(nextAvailableIndex as GroupTypeIndex)) {
    nextAvailableIndex++
}
```

The insert is idempotent under races and self-retries at the next index on unique-constraint collision:

```sql
WITH insert_result AS (
    INSERT INTO posthog_grouptypemapping (team_id, project_id, group_type, group_type_index, created_at)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT DO NOTHING
    RETURNING group_type_index
)
SELECT group_type_index, 1 AS is_insert FROM insert_result
UNION
SELECT group_type_index, 0 AS is_insert FROM posthog_grouptypemapping WHERE project_id = $2 AND group_type = $3;
```

```ts
if (insertGroupTypeResult.rows.length == 0) {
    return await this.insertGroupType(teamId, projectId, groupType, index + 1, createdAt, tx)
}
```

**Is assignment irreversible?** For a live group type, yes — there is no reassign/remap operation anywhere in the codebase; the index is the physical ClickHouse column (`$group_0`…`$group_4`) already baked into every historical event row. The only way an index changes hands is delete-then-recreate, and the docs' own caveat says historical events do not follow.

`created_at` is stamped from the triggering **event's** timestamp, not wall clock:

```ts
// Use the triggering event's timestamp as the mapping's created_at, so historical imports
// register the group type as of the event rather than wall-clock now (which would mask them).
```

---

## 3. Wire format: an ordinary event associated with a group

The association lives in `properties.$groups`, a `{group_type: group_key}` map. From <https://posthog.com/docs/api/capture> ("Groups" section), verbatim:

```json
{
  "api_key": "<ph_project_token>",
  "event": "event name",
  "distinct_id": "user distinct id",
  "properties": {
    "$groups": {"company": "<company_name>"}
  }
}
```

POSTed to `<ph_client_api_host>/i/v0/e/`. Full multi-type example from the group-analytics docs snippet:

```json
{
  "api_key": "<ph_project_token>",
  "event": "user_signed_up",
  "distinct_id": "user_distinct_id",
  "properties": {
    "account_type": "pro",
    "$groups": {
      "company": "company_id_in_your_db",
      "channel": "channel_id_in_your_db"
    }
  },
  "timestamp": "2026-08-09T12:00:00.000Z"
}
```

Docs note on this event shape, verbatim:

> **Note:** This event will **not** create a new group if a new key being used. To create a group, see the [group identify](#group-identify) event.

**What ingestion does to it.** `$groups` is resolved into the flat `$group_N` columns ([`groups.ts`](https://github.com/PostHog/posthog/blob/master/nodejs/src/ingestion/common/steps/event-processing/groups.ts)):

```ts
export function enrichPropertiesWithGroupTypes(
    properties: Properties,
    groupTypesToColumnIndex: GroupTypeToColumnIndex
): Properties {
    const groups = properties.$groups
    if (typeof groups !== 'object' || groups === null || Array.isArray(groups)) {
        return properties
    }
    for (const [groupType, groupIdentifier] of Object.entries(groups)) {
        if (groupType in groupTypesToColumnIndex) {
            // :TODO: Update event column instead
            const groupIndex = groupTypesToColumnIndex[groupType]
            properties[`$group_${groupIndex}`] = groupIdentifier
        }
    }
    return properties
}
```

So the persisted event carries **both** `$groups` (the original map) and `$group_0`…`$group_4` (the resolved columns). Queries read `$group_N`; the LazyJoin in [`posthog/hogql/database/schema/events.py`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/events.py) joins `events.$group_N = groups.key`.

**Hard precondition:** the event must be an identified event. Docs, verbatim:

> Events must be [identified](/docs/data/anonymous-vs-identified-events) to link to individual groups. If `$process_person_profile` is set to `false`, the event won't link to the group.

In code this is the `if (processPerson)` gate wrapping `addGroupProperties` and `upsertGroup` in [`process-groups-step.ts`](https://github.com/PostHog/posthog/blob/master/nodejs/src/ingestion/common/steps/event-processing/process-groups-step.ts).

**One group per group type, per event.** Docs, verbatim: "You can't assign one event to multiple individual groups of the same group type, but you can assign it to individual groups of different group types." (`$groups` is a JSON object, so a duplicate key is structurally impossible anyway.)

---

## 4. Wire format: `$groupidentify`

From <https://posthog.com/docs/api/capture> ("Group identify"), verbatim (note the missing comma after `"premium"` is in PostHog's docs as written):

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
      "subscription": "premium"
      "date_joined": "[optional timestamp in ISO 8601 format]"
    }
  }
}
```

Minimal form (create the group type / group with no properties), from [`contents/docs/_snippets/capture-group-event-code.mdx`](https://github.com/PostHog/posthog.com/blob/master/contents/docs/_snippets/capture-group-event-code.mdx):

```bash
# Call $groupidentify to create or update a group.
# It will also create the group type if it doesn't exist.
curl -v -L --header "Content-Type: application/json" -d '{
    "api_key": "<ph_project_token>",
    "event": "$groupidentify",
    "distinct_id": "static_string_used_for_all_group_events",
    "properties": {
        "$group_type": "company",
        "$group_key": "company_id_in_your_db"
    }
}' <ph_client_api_host>/i/v0/e/
```

Variant in [`setting-group-properties.mdx`](https://github.com/PostHog/posthog.com/blob/master/contents/docs/_snippets/setting-group-properties.mdx) puts `distinct_id` **inside** `properties` — both placements are accepted (the batch API docs note "the required `distinct_id` value can also be passed in `properties`"):

```bash
curl -v -L --header "Content-Type: application/json" -d '{
    "api_key": "<ph_project_token>",
    "event": "$groupidentify",
    "properties": {
        "distinct_id": "company_id_in_your_db",
        "$group_type": "company",
        "$group_key": "company_id_in_your_db",
        "$group_set": {
            "name": "PostHog",
            "subscription": "premium",
            "date_joined": "2020-01-23"
        }
    }
}' <ph_client_api_host>/i/v0/e/
```

### SDK-side construction

**posthog-js** ([`packages/browser/src/posthog-core.ts`](https://github.com/PostHog/posthog-js/blob/main/packages/browser/src/posthog-core.ts), `group()`):

```ts
group(groupType: string, groupKey: string, groupPropertiesToSet?: Properties): void {
    if (!groupType || !groupKey) {
        logger.error('posthog.group requires a group type and group key')
        return
    }

    const existingGroups = this.getGroups()
    const isNewGroup = existingGroups[groupType] !== groupKey

    // if group key changes, remove stored group properties
    if (isNewGroup) {
        this.resetGroupPropertiesForFlags(groupType)
    }

    this.register({ $groups: { ...existingGroups, [groupType]: groupKey } })

    // Send $groupidentify when the group is new/changed OR when properties
    // are provided. Skip only when the group already exists with the same
    // key and no new properties are being set.
    if (isNewGroup || groupPropertiesToSet) {
        const groupIdentifyProperties: Properties = {
            $group_type: groupType,
            $group_key: groupKey,
        }
        if (groupPropertiesToSet) {
            groupIdentifyProperties.$group_set = groupPropertiesToSet
        }
        this.capture(EVENT_GROUPIDENTIFY, groupIdentifyProperties)
    }

    if (groupPropertiesToSet) {
        this.setGroupPropertiesForFlags({ [groupType]: groupPropertiesToSet })
    }

    // If groups change and no properties change, reload feature flags.
    // The property change reload case is handled in setGroupPropertiesForFlags.
    if (isNewGroup && !groupPropertiesToSet) {
        this.reloadFeatureFlags()
    }
}
```

Note `$group_set` is **omitted entirely** (not sent as `{}`) when no properties are passed. The `$groups` super-property is registered in persistence, which is what makes all subsequent events in the session carry it. Reset:

```ts
resetGroups(): void {
    this.register({ $groups: {} })
    this.resetGroupPropertiesForFlags()

    // If groups changed, reload feature flags.
    this.reloadFeatureFlags()
}
```

**posthog-node** ([`packages/node/src/client.ts`](https://github.com/PostHog/posthog-js/blob/main/packages/node/src/client.ts)) — note the synthesized default `distinctId` and that `$group_set` **always** goes out, as `{}` when absent:

```ts
groupIdentify({ groupType, groupKey, properties, distinctId, disableGeoip }: GroupIdentifyMessage): void {
  this._sendPreparedEvent(
    'capture',
    {
      distinctId: distinctId || `$${groupType}_${groupKey}`,
      event: '$groupidentify',
      properties: {
        $group_type: groupType,
        $group_key: groupKey,
        $group_set: properties || {},
      },
      disableGeoip,
    },
    false,
    { includeContextProperties: false }
  )
}
```

**posthog-python** ([`posthog/client.py`](https://github.com/PostHog/posthog-python/blob/master/posthog/client.py)):

```python
properties = properties or {}
distinct_id = get_identity_state(distinct_id)[0]
msg: Dict[str, Any] = {
    "event": "$groupidentify",
    "properties": {
        "$group_type": group_type,
        "$group_key": group_key,
        "$group_set": properties,
    },
    "distinct_id": distinct_id,
    "timestamp": timestamp,
    "uuid": uuid,
}
```

### Server-side handling of `$groupidentify`

[`process-groups-step.ts`](https://github.com/PostHog/posthog/blob/master/nodejs/src/ingestion/common/steps/event-processing/process-groups-step.ts):

```ts
async function upsertGroup(
    groupTypeManager, groupStore, teamId, projectId, properties, timestamp
): Promise<void> {
    if (!properties['$group_type'] || !properties['$group_key']) {
        return
    }

    const { $group_type: groupType, $group_key: groupKey, $group_set: groupPropertiesToSet } = properties
    const groupTypeIndex = await groupTypeManager.fetchGroupTypeIndex(teamId, projectId, groupType, timestamp)
    if (groupTypeIndex !== null) {
        await groupStore.upsertGroup(
            teamId, projectId, groupTypeIndex,
            sanitizeString(groupKey.toString()),
            groupPropertiesToSet || {},
            timestamp
        )
    }
}
```

Validation: a non-object `$group_set` **drops the event** with an `invalid_group_set` ingestion warning:

```ts
// Group properties must be a plain JSON object — anything else (string, number,
// array, ...) would reach Postgres as an invalid jsonb parameter and poison the
// whole write batch.
```

```ts
if (preparedEvent.event === '$groupidentify') {
    const invalidGroupSetWarning = validateGroupSet(preparedEvent)
    if (invalidGroupSetWarning) {
        return drop('invalid_group_set', [], [invalidGroupSetWarning])
    }
    await upsertGroup(...)
}
```

Note also that a `$groupidentify` **also carries `$groups`** if the SDK has one registered — so it is itself group-associated like any other event.

---

## 5. How group properties are set, updated, overwritten — merge vs. replace, and `$group_set_once`

### `$group_set` is a MERGE (shallow, key-level), not a replace

Two independent confirmations.

**In-memory delta computation** ([`nodejs/src/ingestion/common/groups/group-update.ts`](https://github.com/PostHog/posthog/blob/master/nodejs/src/ingestion/common/groups/group-update.ts)):

```ts
export function calculateUpdate(currentProperties: Properties, properties: Properties): PropertiesUpdate {
    const result: PropertiesUpdate = {
        updated: false,
        properties: { ...currentProperties },
        changedProperties: {},
    }

    // Ideally we'd keep track of event timestamps, for when properties were updated
    // and only update the values if a newer timestamped event set them.
    // However to do that we would need to keep track of previous set timestamps,
    // which means that even if the property value didn't change
    // we would need to trigger an update to update the timestamps.
    // This can kill Postgres if someone sends us lots of groupidentify events.
    // So instead we just process properties updates based on ingestion time,
    // i.e. always update if value has changed.
    Object.entries(properties).forEach(([key, value]) => {
        // Deep equality, not reference equality: object/array values arrive as fresh
        // JSON parses on every event, so a reference compare would mark every group
        // with a nested property as changed on every event, causing constant no-op
        // writes, version bumps, and cross-pod update conflicts.
        if (!(key in result.properties) || !equal(value, result.properties[key])) {
            result.updated = true
            result.properties[key] = value
            result.changedProperties[key] = value
        }
    })
    return result
}
```

**Server-side write** ([`postgres-group-repository.ts`](https://github.com/PostHog/posthog/blob/master/nodejs/src/common/groups/repositories/postgres-group-repository.ts)), using Postgres jsonb `||`:

```sql
UPDATE posthog_group AS g SET
    group_properties = COALESCE(g.group_properties, '{}'::jsonb) || batch.new_properties::jsonb,
    created_at = LEAST(g.created_at, batch.new_created_at::timestamp with time zone),
    version = COALESCE(g.version, 0)::numeric + 1
FROM UNNEST(...) AS batch(...)
WHERE g.team_id = batch.batch_team_id
  AND g.group_type_index = batch.batch_group_type_index
  AND g.group_key = batch.batch_group_key
RETURNING g.*
```

with the code comment:

```ts
// Merge semantics (jsonb ||) applied server-side: concurrent writers
// can only race on the same key, never clobber each other's other
// keys, so no version assertion (and no conflict retry) is needed.
```

Insert path merges identically on conflict:

```sql
ON CONFLICT (team_id, group_key, group_type_index) DO UPDATE SET
    group_properties = COALESCE(g.group_properties, '{}'::jsonb) || EXCLUDED.group_properties,
    created_at = LEAST(g.created_at, EXCLUDED.created_at),
    version = COALESCE(g.version, 0)::numeric + 1
```

Semantics summary:
- **Top-level keys present in `$group_set` overwrite** the stored value (last write wins by ingestion order, not event timestamp — see the `calculateUpdate` comment).
- **Top-level keys absent from `$group_set` are preserved.** Sending `$group_set: {"plan": "pro"}` does not remove `name`.
- **The merge is shallow.** A nested object value replaces the whole nested object; `||` is not recursive.
- **`created_at` is `LEAST(existing, incoming)`** — a group's `created_at` only ever moves earlier.

### `$group_set_once` — does not exist

There is **no** `$group_set_once`. Ingestion destructures exactly three properties from a `$groupidentify` event (`$group_type`, `$group_key`, `$group_set`) in both `updateGroupsAndFirstEvent` and `upsertGroup`; nothing else is read. No PostHog SDK exposes a set-once group API, and `$set_once` is documented only for **person** properties (<https://posthog.com/docs/product-analytics/person-properties>).

posthog-js goes out of its way to note that person-level `$set_once` is not processed on `$groupidentify`:

```ts
// $groupidentify doesn't process person $set_once on the server, so don't mark
// initial person props as sent. This ensures they're included with subsequent
// $identify calls.
const markSetOnceAsSent = event_name !== EVENT_GROUPIDENTIFY
```

### Deleting a single group property

Via the REST API only: `POST /api/projects/:project_id/groups/delete_property/` and `POST /api/projects/:project_id/groups/update_property/` (<https://posthog.com/docs/api/groups>).

---

## 6. Are past events retroactively associated with a group? **No.**

Three citations, most direct first.

**PostHog issue [#31718](https://github.com/PostHog/posthog/issues/31718)** ("Feature Request: Associate past events in the session after calling group()", open, labels `feature/group-analytics`, `team/customer-analytics`), verbatim:

> Currently, only events sent after calling `group()` are associated with the group. This makes it hard to analyze data for groups if some events, like autocapture, happen before calling `group()`

Note this is not even about historical data — it is about events **earlier in the same page session**. Even those are not retro-associated.

**PostHog issue [#11224](https://github.com/PostHog/posthog/issues/11224)** ("Improve event updating to support retroactively identifying groups or updating group types", **closed as `not_planned`** 2024-07-08), verbatim:

> It's not currently possible for users to update events to add properties, because it's expensive. […] There is no equivalent for groups, though. If a user sends a bunch of data with no groups, there's no way to retroactively add groups back to events.
>
> **Describe alternatives you've considered**
> Do nothing and tell users they cannot update or retroactively identify groups
>
> Alternative path for users is to start a new project, migrate all data using migrator, write a custom plugin to add logic to associate events with groups, and write all updated data using it to new project. Not ideal,

**Group-analytics docs**, delete/recreate callout, verbatim:

> If new events arrive with the same group key, the group type reappears with a new creation timestamp. Historical events (before the new timestamp) won't appear for the recreated group type.

### The enforcing mechanism (undocumented in prose, explicit in code)

`$group_N` is not read raw at query time — HogQL rewrites it into a timestamp-gated `if()` against `GroupTypeMapping.created_at`, in [`posthog/hogql/database/database.py`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/database.py):

```python
def _setup_group_key_fields(database: Database, group_types: list[dict[str, Any]]) -> None:
    """
    Set up group key fields as ExpressionFields that handle filtering based on GroupTypeMapping.created_at.
    For $group_N fields, this returns:
    - Empty string if no GroupTypeMapping exists for that index
    - if(timestamp < mapping.created_at, '', $group_N) if GroupTypeMapping exists
    """
```

```python
table.fields[field_name] = ExpressionField(
    name=field_name,
    expr=ast.Call(
        name="if",
        args=[
            ast.CompareOperation(
                left=ast.Field(chain=["timestamp"]),
                op=ast.CompareOperationOp.Lt,
                right=ast.Constant(value=created_at),
            ),
            ast.Constant(value=""),
            ast.Field(chain=[raw_field_name]),
        ],
    ),
    isolate_scope=True,
)
```

Two consequences worth knowing:

1. Even if you *did* backfill events carrying `$groups` with timestamps older than the group type mapping's `created_at`, queries would still read those `$group_N` values as `''`.
2. That is why the ingestion path stamps `created_at` from the **event's** timestamp rather than wall clock ([`group-type-manager.ts`](https://github.com/PostHog/posthog/blob/master/nodejs/src/common/groups/group-type-manager.ts)): "so historical imports register the group type as of the event rather than wall-clock now (which would mask them)." A historical migration that sends its **oldest** event first therefore gets a usable `created_at`; one that sends recent events first permanently masks the older ones.

Group **properties**, by contrast, are read at query time from the current `groups` row (`argmax` over `_timestamp`), so a property update *does* change how past events filter/display. Only the event↔group *association* is non-retroactive.

---

## 7. What group analytics unlocks in the UI

Docs cross-product table, verbatim:

| Product | Functionality | Example |
|---------|---------------|---------|
| Product analytics | Aggregate trends, funnels, retention, and stickiness by group | Track how many companies completed onboarding |
| Feature flags | Configure release conditions based on groups | Ensure all users of a company see the same feature flag variant |
| Experiments | Evaluate experiment results based on group aggregations | Run an A/B test to improve activation rate for new companies |
| Data warehouse | Join tables or enrich queries with groups data | Write SQL queries that calculate usage across different company sizes |

### Supported

- **Trends — "Unique groups" math.** From <https://posthog.com/docs/product-analytics/trends/aggregations>: *"The total number of unique groups that performed these events within a period."* The aggregation option is rendered as `Unique ${aggregationLabel(groupType.group_type_index).plural}` with value `$group_${group_type_index}` ([`frontend/src/scenes/insights/filters/AggregationSelect.tsx`](https://github.com/PostHog/posthog/blob/master/frontend/src/scenes/insights/filters/AggregationSelect.tsx)).
- **Funnels.** Docs: *"Track how individual groups organizations move through conversion steps by setting **Aggregating by** to your group type. This shows how many individual groups completed each step, the drop-off percentage, and which specific individual groups dropped off."* Query field: `aggregation_group_type_index` on `FunnelsQuery`.
- **Retention.** `aggregation_group_type_index` on `RetentionQuery`.
- **Stickiness.** Named in the docs cross-product table.
- **Group property filtering on any insight.** From <https://posthog.com/docs/product-analytics/trends/filters>: filter properties can be *"Properties on groups that this event is a member of."*
- **Feature flags.** Docs: *"[Create a feature flag](/docs/feature-flags/creating-feature-flags) and use the **Target by** selector on a condition set to choose your group type."* Requires passing `groups` on the flag-evaluation call server-side.
- **Experiments.** Group aggregation for experiment metrics.
- **SQL / data warehouse.** HogQL exposes `groups` (deduplicated, latest properties) and `raw_groups`, joinable from `events.$group_N = groups.key`, plus per-project alias fields named after the group type (e.g. `events.organization.properties.name`), installed in `database.py`.
- **People and groups tab.** `https://app.posthog.com/persons`, group types listed under **Groups**. Caveat, verbatim: *"Only individual groups with known properties appear in the people tab."*
- **Groups REST API**: `GET/POST /api/projects/:project_id/groups/`, `/activity/`, `/delete_property/`, `/find/`, `/property_values/`, `/related/`, `/update_property/` (<https://posthog.com/docs/api/groups>). List response fields: `group_type_index`, `group_key`, `group_properties`, `created_at`; query params `cursor`, `group_key`, `group_type_index`, `search`.

### NOT supported

- **Lifecycle insights** — docs Limitations, verbatim: *"Group types aren't supported for lifecycle insights or user paths."*
- **User paths** — same line.
- **Cohorts** — cohorts are a person construct. <https://posthog.com/docs/data/cohorts>: *"Cohorts represent a specific set of users – e.g., a list of users whose email contains a certain string (like a company's domain). Groups aggregate events based on entities, such as organizations or companies, but do not necessarily connect to a user."*
- **Session replay** — group filtering is **not listed** among replay filters (<https://posthog.com/docs/session-replay/how-to-watch-recordings> lists date range, active duration, activity counts, events and actions, properties, console logs, feature flags, visited page URL), and session replay does not appear in the group-analytics cross-product table. Treat this as *not documented as supported* rather than positively confirmed absent.
- **Anonymous events** — <https://posthog.com/docs/data/anonymous-vs-identified-events> lists "Use group analytics" under what you **cannot** do with anonymous events.

One code-level nuance worth flagging against the docs: `AggregationSelect.tsx` does contain an `isLifecycleQuery(querySource)` branch that writes `aggregation_group_type_index`. The docs statement ("aren't supported for lifecycle insights") is the authoritative product statement; the presence of that branch is not evidence of support.

---

## 8. Is Group Analytics a paid add-on?

**Yes.** Docs availability frontmatter on the group-analytics page:

```yaml
availability:
  free: none
  selfServe: full
  enterprise: full
```

`free: none` — group analytics is unavailable on the free plan. It is gated in-app behind `AvailableFeature.GROUP_ANALYTICS` ([`frontend/src/lib/introductions/groupsAccessLogic.ts`](https://github.com/PostHog/posthog/blob/master/frontend/src/lib/introductions/groupsAccessLogic.ts)); users without it see `needsUpgradeForGroups` and a `GroupIntroductionFooter` upgrade prompt in place of the group aggregation options.

Docs Billing section, verbatim:

> Group analytics is a paid add-on. Here's how billing works:
>
> **All identified events count toward billing**
> Once you subscribe to group analytics, billing applies to **all identified events** in your project, not just events with group properties attached. This is because group analytics enables infrastructure that processes all identified events to support group-level analysis.
>
> - Billing starts when you enable group analytics from your [billing page](https://app.posthog.com/organization/billing), not when you add group analytics code to your application.
> - Usage is based on captured [identified events](/docs/product-analytics/identify), even if they don't include group properties.
> - Billing stops when you unsubscribe from the billing page. You don't need to remove group analytics code from your application to stop billing.

**Price**, from <https://posthog.com/addons>:

> **Group analytics**
> Associate events with a group or entity - such as a company, community, or project. Analyze these events as if they were sent by that entity itself.
> Starting price: **$0.000071 per event**
> Free tier: First **1,000,000** events/month

Billing model summary:
- **Per identified event**, not per group and not per group-associated event.
- Volume-tiered ("starting price" = the highest tier rate), with a 1M events/month free allowance on the add-on line item.
- Surcharge, not replacement: it is charged **on top of** base Product Analytics event pricing ($0.0000500/event at the 1–2M tier, down to $0.0000090/event above 250M) and on top of the Identified events add-on ($0.000198/event starting, same 1M free tier).
- Subscription-state gated, not code gated — turning it on/off is a billing-page action, independent of whether your app sends `$groups`.

Self-hosted: `selfServe: full` / `enterprise: full`; the feature is behind the EE license `AvailableFeature.GROUP_ANALYTICS`, and instances with `preflight.instance_preferences.disable_paid_fs` hide it entirely (`GroupsAccessStatus.Hidden`).

---

## 9. Does `$groupidentify` consume event quota / billable events?

**Yes — it is an ordinary captured event on the same ingestion path.** It is POSTed to `/i/v0/e/` (or `/batch/`) exactly like any other event, is stored in the `events` table, and is counted the same way. PostHog documents no exemption list for `$groupidentify` anywhere in the pricing or billing docs. Base pricing statement (<https://posthog.com/docs/product-analytics/pricing>): *"Product Analytics is billed by the number of events captured."*

Beyond the quota question, there are three further billing consequences worth stating precisely, because they are the ones that surprise people:

1. **`$groupidentify` is an identified event.** Events sent via the API are identified by default (<https://posthog.com/docs/api/capture>: *"By default, events captured via the API are identified events"*), and the group-analytics docs require identification for group linkage. Identified events are the more expensive class — *"anonymous events can be up to 4x cheaper than identified ones"* ([`identified-vs-anonymous-intro.mdx`](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/_snippets/identified-vs-anonymous-intro.mdx)).

2. **Calling `posthog.group()` in the browser flips *every subsequent event* to identified**, even under `person_profiles: 'identified_only'`. From [`posthog-core.ts`](https://github.com/PostHog/posthog-js/blob/main/packages/browser/src/posthog-core.ts):

   ```ts
   _hasPersonProcessing(): boolean {
       return !(
           this.config.person_profiles === 'never' ||
           (this.config.person_profiles === PERSON_PROFILES_IDENTIFIED_ONLY &&
               !this._isIdentified() &&
               isEmptyObject(this.getGroups()) &&
               !this.persistence?.props?.[ALIAS_ID_KEY] &&
               !this.persistence?.props?.[ENABLE_PERSON_PROCESSING])
       )
   }
   ```

   A non-empty `$groups` map makes `_hasPersonProcessing()` true, which sets `properties['$process_person_profile'] = true` on every event, and (via `_requirePersonProcessing`) latches that on for all future events. So the cost of group analytics on a web SDK is not the `$groupidentify` events — it is the whole session becoming identified.

3. **Once the add-on is subscribed, the group-analytics surcharge applies to all identified events in the project**, per the docs callout quoted in §8 — including identified events with no `$groups` at all.

`posthog-js` does throttle redundant `$groupidentify` sends: it fires only when the group is new/changed, or when properties are supplied (`if (isNewGroup || groupPropertiesToSet)`). The backend SDKs (`group_identify` / `groupIdentify` / `GroupIdentify{}`) have no such dedupe — every call is an event.

---

## Source index

| Claim area | URL |
|---|---|
| Main docs page | <https://posthog.com/docs/product-analytics/group-analytics> |
| Docs source (verbatim) | <https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx> |
| Code snippet source | <https://github.com/PostHog/posthog.com/blob/master/contents/docs/_snippets/capture-group-event-code.mdx> |
| Group properties snippet | <https://github.com/PostHog/posthog.com/blob/master/contents/docs/_snippets/setting-group-properties.mdx> |
| Capture/batch API wire format | <https://posthog.com/docs/api/capture> |
| Groups REST API | <https://posthog.com/docs/api/groups> |
| Anonymous vs identified | <https://posthog.com/docs/data/anonymous-vs-identified-events> |
| Trends aggregations ("Unique groups") | <https://posthog.com/docs/product-analytics/trends/aggregations> |
| Trends filters (group property filters) | <https://posthog.com/docs/product-analytics/trends/filters> |
| Cohorts vs groups | <https://posthog.com/docs/data/cohorts> |
| Add-on pricing | <https://posthog.com/addons> |
| Base event pricing | <https://posthog.com/pricing>, <https://posthog.com/docs/product-analytics/pricing> |
| Frontend vs backend tutorial | <https://posthog.com/tutorials/frontend-vs-backend-group-analytics> |
| Retroactivity (session-scope) | <https://github.com/PostHog/posthog/issues/31718> |
| Retroactivity (historical), rename cost | <https://github.com/PostHog/posthog/issues/11224> |
| `GroupTypeMapping` model, constraints | <https://github.com/PostHog/posthog/blob/master/posthog/models/group_type_mapping.py> |
| `MAX_GROUP_TYPES_PER_TEAM`, index assignment | <https://github.com/PostHog/posthog/blob/master/nodejs/src/common/groups/group-type-manager.ts> |
| jsonb `\|\|` merge, `insertGroupType` SQL | <https://github.com/PostHog/posthog/blob/master/nodejs/src/common/groups/repositories/postgres-group-repository.ts> |
| `$group_set` merge delta | <https://github.com/PostHog/posthog/blob/master/nodejs/src/ingestion/common/groups/group-update.ts> |
| `$groupidentify` handling, `upsertGroup`, `invalid_group_set` | <https://github.com/PostHog/posthog/blob/master/nodejs/src/ingestion/common/steps/event-processing/process-groups-step.ts> |
| `$groups` → `$group_N` enrichment | <https://github.com/PostHog/posthog/blob/master/nodejs/src/ingestion/common/steps/event-processing/groups.ts> |
| `$group_N` timestamp masking | <https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/database.py> (`_setup_group_key_fields`) |
| HogQL groups/events schema | <https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/groups.py>, <https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/events.py> |
| Plan gating | <https://github.com/PostHog/posthog/blob/master/frontend/src/lib/introductions/groupsAccessLogic.ts> |
| Aggregation selector UI | <https://github.com/PostHog/posthog/blob/master/frontend/src/scenes/insights/filters/AggregationSelect.tsx> |
| posthog-js `group()` / `resetGroups()` / person processing | <https://github.com/PostHog/posthog-js/blob/main/packages/browser/src/posthog-core.ts> |
| posthog-node `groupIdentify` | <https://github.com/PostHog/posthog-js/blob/main/packages/node/src/client.ts> |
| posthog-python `group_identify` | <https://github.com/PostHog/posthog-python/blob/master/posthog/client.py> |

**Two things I could not confirm positively:** (a) whether session replay supports any group-based filter — no PostHog doc lists one, which is *undocumented*, not proof of absence; (b) the exact volume tiers for the group analytics add-on above its "starting price" of $0.000071/event — the tier table is rendered by the pricing calculator and was not retrievable as static text.