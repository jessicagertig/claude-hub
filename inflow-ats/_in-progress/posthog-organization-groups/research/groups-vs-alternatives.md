# PostHog Group Analytics vs. an `organization_id` Property — Research Report

All claims below are sourced. Where I could not find documentation, I say **undocumented**, not "doesn't work."

---

## 0. The mechanism, first (this explains everything else)

PostHog stores group membership **on the event at ingest time** and group properties **in a separate table joined at query time**.

- The events table carries materialized columns `$group_0` … `$group_4`:
  `$group_0 VARCHAR MATERIALIZED replaceRegexpAll(JSONExtractRaw(properties, '$group_0'), '^"|"$', '')` — [sharded_events schema handbook](https://posthog.com/handbook/engineering/clickhouse/schema/sharded-events)
- The `groups` table is a HogQL `LazyTable`, deduplicated by `argMax(updated_at)`, described in source as: *"Deduplicated groups (companies, organizations, etc.) in the project, with their latest properties. One row per (group type, group key). Join from events via `events.$group_N = groups.key`."* — [`posthog/hogql/database/schema/groups.py`](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/groups.py)
- The same file confirms PostHog generates **per-project group-type-name aliases on the events table** (comment: *"the per-project group-type-name aliases like `organization`"*), so HogQL can write `events.organization.properties.plan`.

Two consequences that decide the whole question:

1. **Group properties are current-value, retroactively, across all history.** Change an org's `plan` today and every historical event queried by that group property reflects the new value, because the join resolves to the latest `groups` row. An event property `organization_plan` is frozen at capture time forever.
2. **Group membership is NOT retroactive.** `$group_N` is written on the event at ingest. There is no way to attach a group to an already-ingested event (§4, §6).

---

## 1. What a real group type gives you that an event property cannot

### 1.1 `Unique groups` as a first-class aggregation in Trends

The Trends event-aggregation menu has a dedicated entry:

| Event aggregation | Description |
|---|---|
| `Unique groups` | "The total number of unique groups that performed these events within a period." |

— [trends/aggregations.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/trends/aggregations.mdx)

The group-analytics doc's instructions: *"Create an insight with your signup event. Expand the menu next to the event. Select **Unique** with your group type. This shows total individual groups that signed up instead of individual users."* — [group-analytics.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx)

An event property gives you a *breakdown* (300 series) or a SQL insight (`uniq(properties.organization_id)`), never this menu entry — so no group-level WAU/MAU rolling windows and no group-level dashboards built by non-SQL users.

### 1.2 Group-aggregated funnels with per-group drop-off

*"Track how individual groups organizations move through conversion steps by setting **Aggregating by** to your group type. This shows how many individual groups completed each step, the drop-off percentage, and which specific individual groups dropped off."* — [group-analytics.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx)

The "which specific organizations dropped off" list is not reproducible from a breakdown.

### 1.3 Group-cohort retention

Retention explicitly supports groups as the retained entity: *"Analyze retention for groups of users, such as all users in the same organization, company, or account. This is useful if your customers are companies with many users, but not all of them are active. This [requires group analytics](/docs/product-analytics/group-analytics)."* — [retention.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/retention.mdx)

Same doc: *"retention insights default to unique users, but they can also use groups"* (cohort-size column). Logo retention / account churn is exactly this insight, and there is no event-property equivalent in the UI.

### 1.4 `Group properties` as a breakdown dimension

Both Trends and Retention list it as its own row in the supported-breakdown table:

| Group properties | "Properties stored on a group (requires [group analytics](/docs/product-analytics/group-analytics))" |

— [trends/breakdowns.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/trends/breakdowns.mdx), [retention.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/retention.mdx)

Because of the query-time join (§0), "break down last quarter's retention by current plan tier" works. An event property can only break down by the plan tier *as it was at capture time*.

### 1.5 Feature flags: whole-organization consistency

This is the sharpest, least-substitutable capability.

*"Group targeting evaluates a flag based on a group key instead of a user's distinct ID. Everyone in the same group sees the same flag value because PostHog hashes the group key, not the individual user."*

*"For example, if you roll out a flag to 50% of organizations, PostHog hashes each organization's group key to decide whether it's in the rollout. All users in an included organization see the flag enabled, regardless of their own distinct ID."*

— [user-and-group-targeting.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/feature-flags/user-and-group-targeting.mdx)

The same doc states the hard boundary: *"You can't filter on person properties in a group-targeted condition, and you can't filter on group properties in a user-targeted condition. This isn't just a UI constraint — group-targeted conditions hash on the group key and only have access to group properties at evaluation time."*

Server-side evaluation signature:
```python
flags = posthog.evaluate_flags(
    "user_123",
    person_properties={"email": "jane@acme.com", "role": "admin"},
    groups={"company": "company_abc"},
    group_properties={"company": {"name": "Acme Inc", "plan": "enterprise", "industry": "tech"}},
)
```

Gotcha documented in the same file: *"If a group-targeted condition requires a group type that the SDK call didn't include, that condition is **silently skipped** and evaluation continues to the next condition set."*

**What a person property cannot do:** a 50% rollout targeting a person property hashes `distinct_id`, so it splits every organization roughly in half. For a B2B product where an org's users collaborate on the same records, that is a support incident, not a rollout. You can approximate whole-org rollout with an explicit allowlist person property, but you lose percentage rollout and you must rewrite the property on every member of the org whenever it changes.

### 1.6 Experiments with the group as the randomization unit

*"In the New Experiment screen, select the Participant type. By default, it will show `Persons` (i.e. a user-targeted experiment). Click on the drop-down and select your new group."* — [running-group-targeted-ab-tests.md](https://github.com/PostHog/posthog.com/blob/master/contents/product-engineers/running-group-targeted-ab-tests.md)

Not achievable with an event property at all — the randomization unit is a flag-evaluation concept.

### 1.7 The Groups tab, group profile pages, and Related groups

- Group list per group type lives at `https://app.posthog.com/groups/0` — [customer-profiles.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/customer-analytics/customer-profiles.mdx): *"Click any [person](https://app.posthog.com/persons) or [group](https://app.posthog.com/groups/0) from the lists to open their profile."*
- *"**Group profiles** show aggregated activity for an organization, company, or any other group type you've defined."* (same file)
- Group profiles carry usage metrics, a Customer journey node, and Zendesk tickets: *"For groups, all tickets from a given Zendesk organization are fetched. To correlate a PostHog group to a Zendesk organization, you need to set the organization `external_id` with the value of the `groupKey` used to create the group."* (same file)
- Person detail gets a **Related groups** tab: *"shows [groups](/docs/product-analytics/group-analytics) (e.g. organizations, projects, and instances) a person belongs to."* — [persons.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/data/persons.mdx)
- Group properties are editable in the UI; the display name comes from the `name` property: *"The PostHog UI identifies a group using the `name` property. If the `name` property is not found, it falls back to the group key."* — [setting-group-properties.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/_snippets/setting-group-properties.mdx)

### 1.8 Customer Analytics "B2B mode"

*"Customer analytics dashboard has a button to choose between B2C and B2B mode. B2B mode is only available for organizations with [group analytics](/manual/group-analytics) add-on… With the add-on enabled, you can see all insights in the dashboard with data from your selected group type."* — [b2b-mode.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/customer-analytics/b2b-mode.mdx)

This is PostHog's newest B2B surface and it is gated on the add-on outright.

### 1.9 Session replay

**Undocumented.** The replay filter docs enumerate *"date, active duration, activity counts, events, properties, console logs, feature flags, and more"* with no mention of group properties — [how-to-watch-recordings.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/session-replay/how-to-watch-recordings.mdx). The HogQL replay-filter rewrite issue lists *"Group properties?"* as an open question; the issue was opened 2024-05-02 and is now closed — [PostHog/posthog#22054](https://github.com/PostHog/posthog/issues/22054). Person profiles definitively have a **Recordings** tab ([persons.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/data/persons.mdx)); whether the group profile has an equivalent is not stated in current docs.

**Practical read:** do not buy groups for replay. Replay filtering by an `organization_id` **event property** demonstrably works today.

---

## 2. What an event property still does fine — the overlap

Everything that is *filtering, breaking down, or SQL* works with a plain event property:

- **Filtering any insight** (trends, funnels, retention, paths, lifecycle) by `properties.organization_id`.
- **Breaking down** trends/funnels/retention by `organization_id` — event properties are the first row of every supported-breakdown table ([breakdowns.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/trends/breakdowns.mdx)).
- **Counting distinct accounts in SQL:** `uniq(properties.organization_id)` in a SQL insight replicates "daily active organizations" without the add-on. SQL insights are also the documented escape hatch for breakdown limits: *"If you need more flexibility, you can use [SQL insights](/docs/sql) which don't have this limitation."* (same file)
- **Per-account dashboards** — a dashboard filtered to one `organization_id` value.
- **Session replay filtering** by event property (§1.9).
- **Cohorts** — and here the event property is actually *ahead*: groups are unsupported in cohorts entirely (§4).
- **Historical data** — the event property covers everything you have already captured; groups cover nothing before the day you deploy them.

So: reporting overlap is large. The non-overlap is *aggregation-as-entity* (unique groups, group funnels, group retention), *bucketing* (flags, experiments), and *the account-object UI* (group profiles, B2B mode).

---

## 3. Are person properties an acceptable substitute for group properties?

Partially, and the failure modes are specific.

**What works:** person properties feed filters, cohorts, feature flags, surveys, and breakdowns — [person-properties.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/person-properties.mdx). Cohorts are PostHog's own recommended cheap alternative: *"If your only goal is to create a **list of users** with something in common, we recommend cohorts instead of groups. Groups require additional code in your app to set up, while cohorts are created in PostHog and don't require additional code."* — [cohorts.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/data/cohorts.mdx)

**What breaks:**

1. **No single source of truth — N copies of every org attribute.** An org's `plan` lives on every member's person profile. Changing it requires writing to all of them, and any member who doesn't generate an event afterwards keeps the stale value indefinitely. With a group, `posthog.group_identify` writes one row and the query-time join updates all history at once (§0).
2. **Flag rollout splits organizations.** Percentage rollouts hash `distinct_id` for user-targeted conditions and the group key for group-targeted ones ([user-and-group-targeting.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/feature-flags/user-and-group-targeting.mdx)). There is no person-property construction that gives you "50% of organizations, consistently."
3. **No account object in the UI.** No group list page, no group profile, no Related-groups navigation, no B2B mode.
4. **Person-profile hygiene becomes load-bearing.** Duplicate person profiles from imperfect `identify` calls *"inflate counts that rely on person profiles, such as cohort sizes and feature flag targeting"* — [persons.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/data/persons.mdx). Org-level numbers derived from person properties inherit that error; group-key counts do not.
5. **Hard size ceiling:** *"Person properties have a size limit of **512KB** per person record."* (same file) — irrelevant for one `organization_id`, relevant if you mirror a large org record onto every member.
6. **Multi-org users.** A person profile is one record; a user in two orgs has one `organization_id` person property (last write wins). Groups model this correctly as long as each *event* carries one group per type.

---

## 4. Documented downsides of adopting groups

**Billing — the trap.** From [group-analytics.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx):

> *"Once you subscribe to group analytics, billing applies to **all identified events** in your project, not just events with group properties attached. This is because group analytics enables infrastructure that processes all identified events to support group-level analysis."*
> *"Billing starts when you enable group analytics from your billing page, not when you add group analytics code to your application."*
> *"Billing stops when you unsubscribe from the billing page. You don't need to remove group analytics code from your application to stop billing."*

Published add-on rates ([posthog.com/addons](https://posthog.com/addons)) — free tier **first 1,000,000 events/month**, then:

| Volume | Price/event |
|---|---|
| 1–2M | $0.0000710 |
| 2–15M | $0.0000300 |
| 15–50M | $0.0000189 |
| 50–100M | $0.0000105 |
| 100–250M | $0.0000040 |
| 250M+ | $0.0000029 |

**Not on the free plan.** The doc's frontmatter is `availability: free: none / selfServe: full / enterprise: full` — [group-analytics.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx).

**Hard limitations (verbatim list from the same doc):**
- Maximum of 5 group types per project
- You can delete group types, but not individual groups
- Multiple individual groups of the same group type can't be assigned to a single event
- Group types aren't supported for lifecycle insights or user paths
- Only individual groups with known properties appear in the people tab

**Cohorts are out:** *"**Can you use groups in cohorts?** Not yet, but we are working on rewriting cohort calculations in SQL which will unlock your ability to do this."* — [cohorts.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/data/cohorts.mdx)

**Deletion is quasi-irreversible for history:**
> *"Event data remains unchanged. Group data is filtered from queries based on a deletion timestamp. Deleted group types don't count toward your 5 group type limit. If new events arrive with the same group key, the group type reappears with a new creation timestamp. Historical events (before the new timestamp) won't appear for the recreated group type."* — [group-analytics.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx)

**Every capture call site must change (backend).** Backend SDKs are stateless: *"Every time you capture an event, you must add the group data to it."* Frontend is stateful but requires reset discipline: *"you need to call `posthog.reset()` when a user changes (logs out)… You could also call `posthog.resetGroup()` to only reset the group, not the user."* — [frontend-vs-backend-group-analytics.md](https://github.com/PostHog/posthog.com/blob/master/contents/tutorials/frontend-vs-backend-group-analytics.md)

**Identified events only.** *"Events must be identified to link to individual groups. If `$process_person_profile` is set to `false`, the event won't link to the group."* — [group-analytics.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx)

**PostHog's own CS handbook flags this as a common waste:** *"Customers who haven't done this may end up paying for Group Analytics but not able to use it"* — with a Vitally risk indicator for accounts on the add-on without implementation, and the remediation *"they can save by removing the Group Analytics add-on from the billing page"* — [handbook/cs-and-onboarding/health-checks](https://posthog.com/handbook/cs-and-onboarding/health-checks)

**Experiments at group level are statistically weaker** — PostHog's own warning: *"Since you treat a group of users as a single data point in group-targeted experiments, you have less statistical power – e.g. Slack has 20 million users, but only 600,000 companies using it. In practice, this means that you'll usually have to run group-targeted experiments longer."* Plus *"Higher randomization risk"* with fewer data points. — [running-group-targeted-ab-tests.md](https://github.com/PostHog/posthog.com/blob/master/contents/product-engineers/running-group-targeted-ab-tests.md)

---

## 5. Mixpanel and Amplitude — same model, same constraints

- **Mixpanel Group Analytics:** *"Mixpanel Group Analytics allows behavioral data analysis at a customized group level (such as account, device—or any other way you want to assess your business)."* Paid: *"Customers on an Enterprise or Growth plan can access Group Analytics as an add-on package."* — [docs.mixpanel.com/docs/data-structure/advanced/group-analytics](https://docs.mixpanel.com/docs/data-structure/advanced/group-analytics). Third-party pricing writeups put the uplift at roughly +40% on the base plan ([justpricing.com/mixpanel-pricing](https://justpricing.com/mixpanel-pricing)) — treat that as unofficial.
- **Amplitude Accounts add-on:** *"Account-level reporting analyzes product usage by group, such as a company, team, or account, instead of by individual user."* Same 5-type ceiling: *"With the Accounts add-on, you can instrument up to five group types per project."* And the retroactivity rule stated outright: **"Changes to account groups and group properties apply to new data and don't affect historical data."** — [amplitude.com/docs/analytics/account-level-reporting](https://amplitude.com/docs/analytics/account-level-reporting)

**What this clarifies about PostHog:** the group-type concept is not a PostHog quirk or an upsell invention — it is the industry-standard account-analytics model, and all three vendors (a) sell it as a paid add-on, (b) cap it at ~5 group types, and (c) require instrumentation at capture time with no backfill. Amplitude's non-retroactivity sentence is the clearest statement of the constraint PostHog implements identically via `$group_N` at ingest. So "wait and see" costs the same in every tool: the clock on usable group history starts the day you instrument.

---

## 6. Migration path from an existing `organization_id` event property

**There is no backfill. This is settled, not a gap in my research.**

[PostHog/posthog#11224](https://github.com/PostHog/posthog/issues/11224) — "Improve event updating to support retroactively identifying groups or updating group types", opened 2022-08-10, **closed as not planned**:

> *"It's not currently possible for users to update events to add properties, because it's expensive. However, a very common onboarding path is to set up tracking, collect data before identifying users or groups, and then have a bunch of unidentified data."*
> *"If a user sends a bunch of data with no groups, there's no way to retroactively add groups back to events."*

The only workaround the issue records, described by PostHog as *"Not ideal"*: *"users to start a new project, migrate all data using migrator, write a custom plugin to add logic to associate events with groups, and write all updated data using it to new project."*

### Recommended sequence

1. **Keep `organization_id` as an event property. Do not remove it.** It is your only handle on pre-adoption history, it works in cohorts (which groups do not), it survives the group-type delete/recreate timestamp trap, and it works in session replay filters. It costs nothing extra.

2. **Add the group call alongside.** Frontend, after `identify`:
   ```js
   posthog.identify('user_123', { email: 'jane@acme.com' })
   posthog.group('organization', String(organization.id), {
       name: organization.name,
       plan: organization.plan,
       date_joined: organization.created_at,
   })
   ```
   Use the DB primary key, not the name — *"Use unique IDs as keys for individual groups, not names because names can duplicate"* and *"Use singular names for group types - 'company' not 'companies'"* ([group-analytics.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx)).

   Backend (Ruby has no first-class snippet in the docs; the wire format is what matters) — the API-level shape is `properties.$groups`:
   ```json
   {"event": "user_signed_up", "distinct_id": "user_distinct_id",
    "properties": {"$groups": {"organization": "org_id_in_your_db"}}}
   ```
   *"The API level property is `$groups` and is within the `properties` object. Libraries transform `groups` to this for you."* — [frontend-vs-backend-group-analytics.md](https://github.com/PostHog/posthog.com/blob/master/contents/tutorials/frontend-vs-backend-group-analytics.md)

3. **Audit every capture call site.** Backend SDKs will not add `groups` for you. If your captures already funnel through a single wrapper, this is one edit; if not, this is the real cost of adoption.

4. **Call `group_identify` whenever org attributes change** (plan, name, seat count). One write updates all history via the query-time join.

5. **Add reset discipline in the frontend** — `posthog.reset()` on logout, `posthog.resetGroup()` on org switch. Without it, one user's events get attributed to the previous org.

6. **Set at least one group property**, or the org will not appear in the UI at all: *"You must include at least one group property for a group to be visible in the [People and groups tab]."* — [setting-group-properties.mdx](https://github.com/PostHog/posthog.com/blob/master/contents/docs/_snippets/setting-group-properties.mdx)

7. **Subscribe to the add-on LAST**, after the code is deployed and verified. Billing starts on subscribe, and it bills *all* identified events from that moment.

8. **Optional seeding of the group records** (not the events) via `POST /api/projects/:project_id/groups/` and `POST /api/projects/:project_id/groups/update_property/` — [posthog.com/docs/api/groups](https://posthog.com/docs/api/groups). This makes all 300 orgs and their properties exist immediately so group profiles and flag targeting work on day one, without waiting for organic traffic. It does **not** retroactively attach groups to past events. The docs still steer you to the capture endpoint as the normal path.

9. **Accept a split date.** Pre-adoption questions get answered with the event property + SQL insights; post-adoption questions get the group aggregations. Write the cutover date down somewhere permanent — every group-retention chart that spans it will be wrong on the left-hand side.

**Yes, keep both, permanently.** They are not redundant: the event property is the historical and cohort-compatible handle; the group is the aggregation, bucketing, and account-object handle.

---

## Bottom line for a ~300-account B2B SaaS

**Groups earn their keep only if you want organization-consistent feature flag rollouts, or you want the account-object UI (group profiles / Customer Analytics B2B mode) as a CS and account-health surface. For reporting alone, they do not.**

The reasoning:

- **Reporting is the weakest case.** At 300 accounts, "daily active organizations," "which orgs adopted feature X," and "org churn" are all reachable today with `uniq(properties.organization_id)` in a SQL insight, plus event-property breakdowns and filters. What you'd be buying is the point-and-click versions of those (`Unique groups`, funnel `Aggregating by`, group retention) — real convenience, and real access for non-SQL teammates, but not new answers.

- **Feature flags are the strongest case, and it is not substitutable.** Percentage rollout hashes `distinct_id` unless you have a group type; there is no person-property trick that yields "50% of organizations, all-or-nothing per org." For a product where an org's users share records, splitting an org across a flag boundary is a support incident. If you ship anything per-customer, this alone justifies adoption.

- **Experiments are the weakest case at your scale.** PostHog's own guidance: group-targeted tests have less statistical power and higher randomization risk, and need longer runtimes. 300 randomization units is thin. Their recommendation — run a user-level test first — applies directly.

- **Cost is probably small, but check one number before deciding.** The add-on's first 1,000,000 events/month are free; if your project is under that in **identified** events, groups are free. Above it, the add-on rate applies to your *entire* identified-event volume, not just grouped events — at 2M identified events/month that's roughly 1M × $0.0000710 ≈ $71/month on top of base. Get your actual identified-event volume from the billing page before committing.

- **The clock argument is the tiebreaker.** No backfill exists, in PostHog or in Amplitude or in Mixpanel. Group history starts the day you instrument. If there is a realistic chance you will want org-consistent rollouts or account-health views within a year, the cheap move is to add the `posthog.group()` / `groups:` calls now — the code is inert and unbilled until you subscribe — and turn on the add-on when you actually need it. That converts an irreversible timing decision into a reversible billing decision.

- **Do not adopt groups for:** session replay (undocumented, and event-property filtering works today), cohorts (explicitly unsupported), lifecycle insights, or user paths.

**Sources:**
- [Group analytics docs](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/group-analytics.mdx)
- [User and group targeting](https://github.com/PostHog/posthog.com/blob/master/contents/docs/feature-flags/user-and-group-targeting.mdx)
- [Cohorts docs](https://github.com/PostHog/posthog.com/blob/master/contents/docs/data/cohorts.mdx)
- [Retention docs](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/retention.mdx)
- [Trends aggregations](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/trends/aggregations.mdx) · [Trends breakdowns](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/trends/breakdowns.mdx)
- [Customer profiles](https://github.com/PostHog/posthog.com/blob/master/contents/docs/customer-analytics/customer-profiles.mdx) · [B2B mode](https://github.com/PostHog/posthog.com/blob/master/contents/docs/customer-analytics/b2b-mode.mdx)
- [People docs](https://github.com/PostHog/posthog.com/blob/master/contents/docs/data/persons.mdx) · [Person properties](https://github.com/PostHog/posthog.com/blob/master/contents/docs/product-analytics/person-properties.mdx)
- [Frontend vs backend group analytics](https://github.com/PostHog/posthog.com/blob/master/contents/tutorials/frontend-vs-backend-group-analytics.md) · [Group-targeted A/B tests](https://github.com/PostHog/posthog.com/blob/master/contents/product-engineers/running-group-targeted-ab-tests.md)
- [groups.py HogQL schema](https://github.com/PostHog/posthog/blob/master/posthog/hogql/database/schema/groups.py) · [sharded_events schema](https://posthog.com/handbook/engineering/clickhouse/schema/sharded-events)
- [Add-on pricing](https://posthog.com/addons) · [Groups API](https://posthog.com/docs/api/groups) · [CS health checks](https://posthog.com/handbook/cs-and-onboarding/health-checks)
- [PostHog#11224 (no group backfill)](https://github.com/PostHog/posthog/issues/11224) · [PostHog#22054 (replay filters)](https://github.com/PostHog/posthog/issues/22054)
- [Amplitude account-level reporting](https://amplitude.com/docs/analytics/account-level-reporting) · [Mixpanel Group Analytics](https://docs.mixpanel.com/docs/data-structure/advanced/group-analytics)