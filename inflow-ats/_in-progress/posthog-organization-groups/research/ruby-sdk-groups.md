# posthog-ruby 2.11.0 — Group Support API Surface

**All source quotes below are from the gem installed on this machine** at `/Users/jessica/.rvm/gems/ruby-3.1.6/gems/posthog-ruby-2.11.0/`, cross-checked against the GitHub tag `2.11.0`. Behavioral claims marked "verified" were produced by actually running the installed gem in `test_mode: true` and dumping the queued message.

- Source tag: https://github.com/PostHog/posthog-ruby/tree/2.11.0
- `lib/posthog/client.rb`: https://github.com/PostHog/posthog-ruby/blob/2.11.0/lib/posthog/client.rb
- `lib/posthog/field_parser.rb`: https://github.com/PostHog/posthog-ruby/blob/2.11.0/lib/posthog/field_parser.rb
- RubyGems: https://rubygems.org/gems/posthog-ruby/versions/2.11.0 (released 2025-05-20; **last 2.x release** — 2.11.0 is the ceiling for the `posthog-ruby (~> 2.0)` constraint in `inflow-ats/Gemfile.lock:667`)
- Docs: https://posthog.com/docs/libraries/ruby (note: the live docs page now documents the **3.x** API — `evaluate_flags`, `PostHog.init` — which does **not** exist in 2.11.0; the "Group analytics" section is still accurate for 2.x)

---

## 1. Capturing an event with groups

### Exact signature

`PostHog::Client#capture` takes **one positional Hash**, not keyword arguments. `groups` is a **top-level key of that hash**, a sibling of `properties` — it is *not* nested under `properties`.

`lib/posthog/client.rb:104-114`:

```ruby
    def capture(attrs)
      symbolize_keys! attrs

      if attrs[:send_feature_flags]
        feature_variants = @feature_flags_poller.get_feature_variants(attrs[:distinct_id], attrs[:groups] || {})

        attrs[:feature_variants] = feature_variants
      end

      enqueue(FieldParser.parse_for_capture(attrs))
    end
```

Because `symbolize_keys!` runs first, `'groups' => {...}` (string key) works identically to `groups: {...}`.

The `groups` hash is moved into the event properties under the **string** key `'$groups'` — `lib/posthog/field_parser.rb:15-41`:

```ruby
      def parse_for_capture(fields)
        common = parse_common_fields(fields)

        event = fields[:event]
        properties = fields[:properties] || {}
        groups = fields[:groups]
        uuid = fields[:uuid]
        check_presence!(event, 'event')
        check_is_hash!(properties, 'properties')

        if groups
          check_is_hash!(groups, 'groups')
          properties['$groups'] = groups
        end

        isoify_dates! properties

        common['uuid'] = uuid if uuid? uuid

        common.merge(
          {
            type: 'capture',
            event: event.to_s,
            properties: properties.merge(common[:properties] || {})
          }
        )
      end
```

### Full working call

```ruby
posthog = PostHog::Client.new(
  api_key: 'phc_...',
  host: 'https://us.i.posthog.com',
  on_error: proc { |status, msg| Rails.logger.error("[posthog] #{status} #{msg}") }
)

posthog.capture(
  distinct_id: 'user_123',
  event: 'movie_played',
  properties: {
    'movie_id' => '123',
    'category' => 'romcom'
  },
  groups: {
    'organization' => '5',
    'instance' => 'app.polymer.co'
  }
)
```

### Exact queued message (verified by execution)

```json
{"timestamp":"2026-08-09T12:48:24.905-05:00","library":"posthog-ruby","library_version":"2.11.0",
 "messageId":"a2a399d3-91b7-4a4f-84e4-104669d897af","distinct_id":"u1",
 "properties":{"a":1,"$groups":{"company":"id:5","instance":"app.posthog.com"},
               "$lib":"posthog-ruby","$lib_version":"2.11.0"},
 "type":"capture","event":"evt"}
```

The gem's own test asserts the same shape (`spec/posthog/client_spec.rb:416-429`, tag 2.11.0):

```ruby
      it 'captures groups' do
        client.capture(
          {
            distinct_id: 'distinct_id',
            event: 'test_event',
            groups: {
              'company' => 'id:5',
              'instance' => 'app.posthog.com'
            }
          }
        )
        properties = client.dequeue_last_message[:properties]
        expect(properties['$groups']).to eq({ 'company' => 'id:5', 'instance' => 'app.posthog.com' })
      end
```

**Note the key type asymmetry for test assertions:** in the queued Ruby hash, `$groups` is a **String** key (`properties['$groups']`), while `$group_type` / `$group_key` / `$group_set` on `group_identify` messages are **Symbol** keys (`properties[:$group_type]`). This is only visible pre-JSON — over the wire both are JSON strings.

### Side effect: `capture` mutates the caller's `properties` hash

`properties['$groups'] = groups` writes into the same object the caller passed (`properties = fields[:properties] || {}` is a reference, not a copy). Verified: after `capture(properties: props, groups: {'company' => '5'})`, the caller's `props` is `{"x":1,"$groups":{"company":"5"}}`. Do not reuse a properties hash across two `capture` calls with different groups.

---

## 2. Identifying / updating a group

### Exact method

`PostHog::Client#group_identify`, again a **single positional Hash** — `lib/posthog/client.rb:127-139`:

```ruby
    # Identifies a group
    #
    # @param [Hash] attrs
    #
    # @option attrs [String] :group_type Group type
    # @option attrs [String] :group_key Group key
    # @option attrs [Hash] :properties Group properties (optional)
    # @option attrs [String] :distinct_id Distinct ID (optional)
    # @macro common_attrs
    def group_identify(attrs)
      symbolize_keys! attrs
      enqueue(FieldParser.parse_for_group_identify(attrs))
    end
```

Hash keys: `group_type:` (**required**), `group_key:` (**required**), `properties:` (optional), `distinct_id:` (optional, added in 2.5.1), plus the common `timestamp:` / `message_id:`.

### The synthesized distinct_id

`distinct_id` is **not** required. When omitted, `lib/posthog/field_parser.rb:73` synthesizes it:

```ruby
        fields[:distinct_id] ||= "$#{group_type}_#{group_key}"
```

So `group_type: 'organization', group_key: 'id:5'` → `distinct_id` = `"$organization_id:5"` (verified). Note the separator is a single underscore and the `$` prefix is literal.

The docs warn about this (https://posthog.com/docs/libraries/ruby, "Group analytics"):

> If the optional `distinct_id` is not provided in the group identify call, it defaults to `$#{group_type}_#{group_key}` (e.g., `$company_company_id_in_your_db` in the example above). This default behavior will result in each group appearing as a separate person in PostHog. To avoid this, it's often more practical to use a consistent `distinct_id`, such as `group_identifier`.

### Full working call

```ruby
posthog.group_identify(
  group_type: 'organization',
  group_key: '5',
  properties: {
    'name' => 'Acme Inc.',
    'employees' => 11
  },
  distinct_id: 'user_123'   # optional; omit to get "$organization_5"
)
```

`name` is the special property PostHog uses as the group's display name; without it the UI shows the group key (https://posthog.com/docs/libraries/ruby).

### Exact parser and queued message

`lib/posthog/field_parser.rb:64-88`:

```ruby
      def parse_for_group_identify(fields)
        properties = fields[:properties] || {}
        group_type = fields[:group_type]
        group_key = fields[:group_key]

        check_presence!(group_type, 'group type')
        check_presence!(group_key, 'group_key')
        check_is_hash!(properties, 'properties')

        fields[:distinct_id] ||= "$#{group_type}_#{group_key}"
        common = parse_common_fields(fields)

        isoify_dates! properties

        common.merge(
          {
            event: '$groupidentify',
            properties: {
              :'$group_type' => group_type,
              :'$group_key' => group_key,
              :'$group_set' => properties.merge(common[:properties] || {})
            }
          }
        )
      end
```

Verified output, no `distinct_id` given:

```json
{"timestamp":"2026-08-09T12:48:24.906-05:00","library":"posthog-ruby","library_version":"2.11.0",
 "messageId":"37df1f35-c83a-439f-af08-a0dc2f00e62a","distinct_id":"$organization_id:5",
 "properties":{"$group_type":"organization","$group_key":"id:5",
               "$group_set":{"name":"Acme","employees":11,"$lib":"posthog-ruby","$lib_version":"2.11.0"}},
 "event":"$groupidentify"}
```

Two structural facts about this message, both real in 2.11.0:

**(a) `$lib` and `$lib_version` land inside `$group_set` — i.e. they are written as GROUP PROPERTIES.** `common[:properties]` is `{'$lib' => 'posthog-ruby', '$lib_version' => '2.11.0'}` (`field_parser.rb:137-140`) and line 84 merges it *into* `$group_set` rather than alongside it. Every `group_identify` call therefore sets two junk properties on the group in PostHog, and the event itself carries no `$lib` at the top level. Fixed only in **posthog-ruby 3.10.0**, commit [`fccb4af`](https://github.com/PostHog/posthog-ruby/commit/fccb4afa) — the fix inverts the merge:

```ruby
-            properties: {
+            properties: (common[:properties] || {}).merge(
               '$group_type': group_type,
               '$group_key': group_key,
-              '$group_set': properties.merge(common[:properties] || {})
-            }
+              '$group_set': properties
+            )
```

**(b) `$groupidentify` messages carry no `type` key.** `capture` emits `type: 'capture'`, `identify` emits `type: 'identify'`, `alias` emits `type: 'alias'`; `parse_for_group_identify` merges only `event:` and `properties:`. This is unchanged in 3.x, so it is deliberate, not a regression — the `/batch/` endpoint keys off the `event` name `$groupidentify`.

### Validation on group_identify (verified)

| Input | Result |
|---|---|
| `group_type` missing/nil/`''` | `ArgumentError: group type must be given` |
| `group_key` missing/nil/`''` | `ArgumentError: group_key must be given` |
| `properties: nil` | accepted, `$group_set` = `{"$lib":..., "$lib_version":...}` only |
| `properties:` non-Hash | `ArgumentError: properties must be a Hash` |
| `group_type: :organization, group_key: 7` | accepted, no coercion of `group_key`: `"$group_key":7` (integer in JSON), `distinct_id` = `"$organization_7"` |

`check_presence!` only rejects `nil` and empty **String** (`field_parser.rb:165-169`) — `group_key: 0` or `group_key: false`… note `false` passes presence but serializes as `false`.

Gem's own tests, `spec/posthog/client_spec.rb:602-643` at tag 2.11.0, confirm `$organization_id:5`, `msg[:event] == '$groupidentify'`, `msg[:properties][:$group_type]`, `msg[:properties][:$group_set][:trait]`, and the optional-`distinct_id` override.

---

## 3. Validation of the `groups` argument on `capture`

There is **one** check and no key/value type validation. `field_parser.rb:25-28` + `171-173`:

```ruby
        if groups
          check_is_hash!(groups, 'groups')
          properties['$groups'] = groups
        end
```
```ruby
      def check_is_hash!(obj, name)
        raise ArgumentError, "#{name} must be a Hash" unless obj.is_a? Hash
      end
```

Verified behavior:

| `groups:` value | Behavior |
|---|---|
| omitted | no `$groups` property at all |
| `nil` | falsey → the whole block is skipped; **no `$groups` property**, no error |
| `{}` | truthy in Ruby → passes `check_is_hash!` → **`"$groups":{}` IS sent** (empty object on the wire) |
| `[['company','5']]` (Array) | `ArgumentError: groups must be a Hash` |
| `'company:5'` (String) | `ArgumentError: groups must be a Hash` |
| `{ organization: 5 }` (Symbol key, Integer value) | **accepted, no coercion** → `"$groups":{"organization":5}` |

So: **no validation that group type names are strings, that group keys are strings, or that the hash is non-empty.** Symbol keys become JSON strings automatically; an integer group key stays an integer in the JSON body. PostHog's own docs use string group keys throughout; the gem will not stop you sending `5` instead of `"5"`, and mixing the two across call sites is how you end up with two distinct group rows.

`groups` values are **not** passed through `isoify_dates!` — only top-level `properties` values are (`field_parser.rb:30`), and that helper is shallow, so nested `Time` objects anywhere (including inside `$group_set`) are serialized by `to_json`, not ISO-8601-formatted by the gem.

---

## 4. Feature flags: passing groups and group properties

Unlike `capture`, the flag methods take **positional `flag_key` + `distinct_id`, then true Ruby keyword arguments.** The keyword names are exactly `groups:`, `person_properties:`, `group_properties:`.

`lib/posthog/client.rb:163-184` and `213-254`:

```ruby
    def is_feature_enabled( # rubocop:disable Naming/PredicateName
      flag_key,
      distinct_id,
      groups: {},
      person_properties: {},
      group_properties: {},
      only_evaluate_locally: false,
      send_feature_flag_events: true
    )
```
```ruby
    def get_feature_flag(
      key,
      distinct_id,
      groups: {},
      person_properties: {},
      group_properties: {},
      only_evaluate_locally: false,
      send_feature_flag_events: true
    )
```

Same keyword set on `get_all_flags` (`client.rb:264-270`), `get_all_flags_and_payloads` (`client.rb:314-320`), and `get_feature_flag_payload` (`client.rb:287-295`, which additionally takes `match_value:`).

The gem's own docstring (`client.rb:204-212`) states the shapes:

```ruby
    # `groups` are a mapping from group type to group key. So, if you have a group type of "organization"
    # and a group key of "5",
    # you would pass groups={"organization": "5"}.
    # `group_properties` take the format: { group_type_name: { group_properties } }
    # So, for example, if you have the group type "organization" and the group key "5", with the properties name,
    # and employee count, you'll send these as:
    # ```ruby
    #     group_properties: {"organization": {"name": "PostHog", "employees": 11}}
    # ```
```

### Full working call

```ruby
enabled = posthog.is_feature_enabled(
  'beta-feature',
  'user_123',
  groups: { 'organization' => '5' },
  person_properties: { 'email' => 'a@b.com' },
  group_properties: {
    'organization' => { 'name' => 'Acme Inc.', 'employees' => 11 }
  }
)

variant = posthog.get_feature_flag(
  'multivariate-flag',
  'user_123',
  groups: { 'organization' => '5' },
  group_properties: { 'organization' => { 'plan' => 'enterprise' } },
  only_evaluate_locally: false,
  send_feature_flag_events: true
)
```

`example.rb` at tag 2.11.0 shows the short form: `posthog.is_feature_enabled('beta-feature', 'distinct_id', groups: { 'company' => 'id:5' })` (https://github.com/PostHog/posthog-ruby/blob/2.11.0/example.rb).

### What the gem does with those arguments

`client.rb:416-441` — `add_local_person_and_group_properties` symbolizes everything and injects two things:

```ruby
    def add_local_person_and_group_properties(distinct_id, groups, person_properties, group_properties)
      groups ||= {}
      person_properties ||= {}
      group_properties ||= {}

      symbolize_keys! groups
      symbolize_keys! person_properties
      symbolize_keys! group_properties

      group_properties.each_value do |value|
        symbolize_keys! value
      end

      all_person_properties = { distinct_id: distinct_id }.merge(person_properties)

      all_group_properties = {}
      if groups
        groups.each do |group_name, group_key|
          all_group_properties[group_name] = {
            :'$group_key' => group_key
          }.merge((group_properties && group_properties[group_name]) || {})
        end
      end

      [all_person_properties, all_group_properties]
    end
```

So `distinct_id` is injected into `person_properties` and `$group_key` into each group's properties (this is the 2.4.1 changelog entry, "Add default properties for feature flags local evaluation, to target flags by distinct id & group keys"). The `distinct_id` duplication was only removed in **3.15.3** ("Stop duplicating `distinct_id` inside `/flags` person properties").

Remote evaluation POSTs to `/flags/?v=2` (switched from `/decide` in 2.9.0) — `lib/posthog/feature_flags.rb:105-113` and `631-639`:

```ruby
    def get_flags(distinct_id, groups = {}, person_properties = {}, group_properties = {})
      request_data = {
        distinct_id: distinct_id,
        groups: groups,
        person_properties: person_properties,
        group_properties: group_properties
      }
```
```ruby
    def _request_feature_flag_evaluation(data = {})
      uri = URI("#{@host}/flags/?v=2")
      req = Net::HTTP::Post.new(uri)
      req['Content-Type'] = 'application/json'
      data['token'] = @project_api_key
      req.body = data.to_json
```

Request body shape: `{"distinct_id":"user_123","groups":{"organization":"5"},"person_properties":{"distinct_id":"user_123",...},"group_properties":{"organization":{"$group_key":"5","name":"Acme"}},"token":"phc_..."}`.

### Three group-specific gotchas in flag evaluation

**(a) `groups: nil` raises `NoMethodError`, it is not treated as `{}`.** `add_local_person_and_group_properties` does `groups ||= {}` on its *local* binding only; the caller's `nil` is then passed straight through to the poller, which calls `symbolize_keys! groups`. Verified:

```
12 get_feature_flag groups nil: NoMethodError: undefined method `each_with_object' for nil:NilClass
```

Never pass a possibly-nil variable as `groups:`; use `groups: (x || {})`.

**(b) Local evaluation of a group-scoped flag returns `false` — not a server fallback — when `groups` is omitted.** `lib/posthog/feature_flags.rb:469-477`:

```ruby
      unless groups.key?(group_name_symbol)
        # Group flags are never enabled if appropriate `groups` aren't passed in
        # don't failover to `/flags/`, since response will be the same
        logger.warn "[FEATURE FLAGS] Can't compute group feature flag: #{flag[:key]} without group names passed in"
        return false
      end
```

The lookup uses the **symbolized** group name, and the group name must appear in `@group_type_mapping`, which comes from `GET /api/feature_flag/local_evaluation` and therefore requires `personal_api_key`. An unknown `aggregation_group_type_index` raises `InconclusiveMatchError, 'Flag has unknown group type index'` and falls back to `/flags/` (`feature_flags.rb:457-465`).

**(c) `$feature_flag_called` is deduped WITHOUT group context in 2.x.** `client.rb:237-252`:

```ruby
      feature_flag_reported_key = "#{key}_#{feature_flag_response}"
      if !@distinct_id_has_sent_flag_calls[distinct_id].include?(feature_flag_reported_key) && send_feature_flag_events
        capture(
          {
            distinct_id: distinct_id,
            event: '$feature_flag_called',
            properties: { ... },
            groups: groups
          }
        )
```

The dedupe key is `"<flag>_<response>"` per `distinct_id`. Evaluating the same flag for the same user under a *second* group emits no `$feature_flag_called` event, so PostHog sees only the first group context. Fixed in **posthog-ruby 3.9.2** only: "Include group context in the `$feature_flag_called` dedupe key so group-scoped flags fire a separate event for each group a user is evaluated under, instead of being dedup-ed against the first group context the same `(distinct_id, flag, response)` was seen under" (https://github.com/PostHog/posthog-ruby/blob/main/posthog-ruby/CHANGELOG.md).

The dedupe cache is a `SizeLimitedHash` capped at `Defaults::MAX_HASH_SIZE = 50_000` distinct_ids which **`clear`s entirely** when full (`lib/posthog/utils.rb:113-123`).

### `capture(send_feature_flags: true)` + groups

`client.rb:107-111` uses your `groups` for the flag fetch: `@feature_flags_poller.get_feature_variants(attrs[:distinct_id], attrs[:groups] || {})`. Here `nil` **is** normalized to `{}`, unlike the flag methods. This makes `capture` **synchronously block on an HTTP POST to `/flags/?v=2`** before enqueuing. On failure it does not raise — the error goes to `on_error` and the event is queued with `"$active_feature_flags":[]` (verified against an unreachable host).

---

## 5. Version-specific caveats across 2.x, from the CHANGELOG

Source: https://github.com/PostHog/posthog-ruby/blob/2.11.0/CHANGELOG.md

| Version | Group-relevant change |
|---|---|
| **2.0.0** (2022-08-12) | Breaking. `api_host` → `host`, must be fully qualified. Flag failures return `nil` instead of a default. Local evaluation with `groups`/`person_properties` on `is_feature_enabled` / `get_feature_flag` introduced. |
| **2.4.1** (2024-01-09) | "Add default properties for feature flags local evaluation, to target flags by distinct id & group keys" — this is the `$group_key` injection in `add_local_person_and_group_properties`. |
| **2.5.1** (2024-12-19) | "Adds a new, optional `distinct_id` parameter to group identify calls" — commit [`5145657`](https://github.com/PostHog/posthog-ruby/commit/51456570). **Before 2.5.1 `group_identify` had no `distinct_id` option at all.** |
| **2.9.0** (2025-04-30) | Flag evaluation moved from `/decide` to the `/flags` service. Group payload shape is unchanged. |
| **2.11.0** (2025-05-20) | Adds `before_send`. No group changes. |

Bugs present in 2.11.0, fixed only after the 2.x line ended:

1. **`$lib` / `$lib_version` written as group properties** on every `group_identify` (§2a above). Fixed in 3.10.0, commit [`fccb4af`](https://github.com/PostHog/posthog-ruby/commit/fccb4afa).
2. **`$feature_flag_called` dedupe ignores group context** (§4c above). Fixed in 3.9.2.
3. **Spurious `WARN` on every `capture` that omits `uuid:`.** `field_parser.rb:32` calls `uuid? uuid` unconditionally and `uuid?` logs when the value is nil (`field_parser.rb:175-180`). Verified — every capture, group-tagged or not, logs `WARN -- PostHog: [posthog-ruby] UUID is not valid: . Ignoring it.` `group_identify` does **not** log this, since `parse_for_group_identify` never calls `uuid?`. Fixed by commit [`2a0485e`](https://github.com/PostHog/posthog-ruby/commit/2a0485e5) ("fix: was warning on absent UUID when capturing", #67), merged 2025-05-20 **19:38 UTC — five hours after 2.11.0 was cut at 14:10 UTC**, so it is not in any 2.x release.
4. **`distinct_id` duplicated inside `/flags` `person_properties`** — fixed in 3.15.3.

No CHANGELOG entry in the entire 2.x line describes a group data-loss or wire-format bug. Groups support has been structurally stable since [`a4b6bf6`](https://github.com/PostHog/posthog-ruby/commit/a4b6bf66) "Basic groups support (#18)", 2022-07-29.

---

## 6. Async / batching — and does `group_identify` share the queue?

**Yes to both. `capture`, `identify`, `group_identify`, and `alias` all funnel through the identical `enqueue` path.** `client.rb:113`, `124`, `138`, `149` each end in `enqueue(FieldParser.parse_for_*(attrs))`.

`client.rb:375-395`:

```ruby
    def enqueue(action)
      action = process_before_send(action)
      return false if action.nil? || action.empty?

      # add our request id for tracing purposes
      action[:messageId] ||= uid

      if @queue.length < @max_queue_size
        @queue << action
        ensure_worker_running

        true
      else
        logger.warn(
          'Queue is full, dropping events. The :max_queue_size ' \
          'configuration parameter can be increased to prevent this from ' \
          'happening.'
        )
        false
      end
    end
```

Mechanics:

- `@queue` is a plain Ruby `Queue` (`client.rb:36`), capped at `Defaults::Queue::MAX_SIZE = 10_000`. Over the cap, **events are silently dropped** with a `WARN` — `enqueue` returns `false` and `group_identify` discards that return value.
- A single background `Thread` runs `SendWorker#run` (`client.rb:402-414`), started lazily on the first enqueue.
- `SendWorker#run` (`send_worker.rb:36-51`) drains into a `MessageBatch` until `@batch.full? || @queue.empty?`, then POSTs. **There is no time-based flush interval in 2.11.0** — a configurable flush interval only arrives in 3.14.0. The worker `return`s when the queue is empty and is respawned by the next `enqueue`.
- Batch limits (`defaults.rb:26-33`): `Message::MAX_BYTES = 32_768` (single messages over 32 KB are dropped with `logger.error('a message exceeded the maximum allowed size')`, `message_batch.rb:28-33`), `MessageBatch::MAX_BYTES = 512_000`, `MessageBatch::MAX_SIZE = 100`.
- Transport POSTs to `Defaults::Request::PATH = '/batch/'` with body `JSON.generate(api_key: api_key, batch: batch)` (`transport.rb:118`), `RETRIES = 10` with exponential backoff, retrying on 5xx and 429 only (`transport.rb:75-86`).
- `before_send` (new in 2.11.0) runs on **every** action including `$groupidentify` — `enqueue` calls `process_before_send` first, and a `nil` return drops the message.
- Ordering: because a `$groupidentify` and a subsequent `capture` land in the same FIFO queue and the same batch, group properties and group-tagged events arrive together in one request. There is no separate group endpoint.
- `posthog.flush` blocks until the queue drains (`client.rb:72-77`); `posthog.shutdown` stops the flag poller then flushes (`client.rb:342-345`). In a Rails process, call `shutdown` at exit or queued group_identify calls die with the process.
- `test_mode: true` swaps in `NoopWorker`, so nothing is sent and `dequeue_last_message` / `queued_messages` / `clear` let you assert the exact hash (`client.rb:40-44`, `152-160`).

---

## Quick reference

```ruby
# 1. Event tagged with groups — `groups:` is a top-level key, sibling of `properties:`
posthog.capture(distinct_id: 'user_123', event: 'x',
                properties: {}, groups: { 'organization' => '5' })
#    → properties['$groups'] = {'organization' => '5'}

# 2. Create/update the group itself
posthog.group_identify(group_type: 'organization', group_key: '5',
                       properties: { 'name' => 'Acme' },
                       distinct_id: 'user_123')   # optional; else "$organization_5"
#    → event '$groupidentify', properties[:$group_type]/[:$group_key]/[:$group_set]

# 3. Flags — positional key + distinct_id, then keywords
posthog.get_feature_flag('flag-key', 'user_123',
                         groups: { 'organization' => '5' },
                         group_properties: { 'organization' => { 'plan' => 'pro' } })
```

Landmines, in order of likelihood of biting: `groups: nil` raises on the flag methods but is fine on `capture`; `groups: {}` still emits `"$groups":{}`; group keys are never coerced to strings; `capture` mutates the `properties` hash you hand it; `$lib`/`$lib_version` get written onto the group as properties; and every `capture` logs a bogus UUID warning.