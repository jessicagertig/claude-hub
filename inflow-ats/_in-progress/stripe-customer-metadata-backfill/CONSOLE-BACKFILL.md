# Stripe Customer metadata backfill — Rails console

**Scope:** customer metadata only. Not subscription metadata.
**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Run from:** a Rails console. Not a rake task, not a job, not a migration.

---

## The snippet

```ruby
def backfill_stripe_customer_metadata(organizations)
  updated_organization_ids = []
  failed_organization_ids = []

  organizations.find_each do |organization|
    metadata = { organization_id: organization.id, organization_name: organization.name }
    metadata[:careers_page_url] = organization.careers_page_url if organization.careers_page_url.present?
    metadata[:organization_created_via] = organization.created_via if organization.created_via.present?

    Stripe::Customer.update(organization.stripe_customer_id, { metadata: metadata })
    updated_organization_ids << organization.id
    ap "#{organization.id} #{organization.stripe_customer_id} #{organization.name} - #{metadata.keys.join(', ')}"
    sleep(0.2)
  rescue StandardError => e
    failed_organization_ids << organization.id
    ap "FAILED #{organization.id} - #{e.class}: #{e.message}", color: { string: :red }
  end

  ap "Updated: #{updated_organization_ids.count}"
  ap "Failed: #{failed_organization_ids.count}"
  ap failed_organization_ids
end
```

Five first, then the full run:

```ruby
backfill_stripe_customer_metadata(Organization.where.not(stripe_customer_id: nil).limit(5))
backfill_stripe_customer_metadata(Organization.where.not(stripe_customer_id: nil))
```

Re-run failures safely:

```ruby
backfill_stripe_customer_metadata(Organization.where(id: failed_organization_ids))
```

---

## Why it's shaped this way

**Stripe merges metadata, it does not replace.** From [docs.stripe.com/metadata](https://docs.stripe.com/metadata):

> "This parameter uses a merge mechanism, which allows you to add new key-value pairs to an object in an update call without affecting any existing metadata."

So sending four keys cannot destroy keys set by anything else, and a second pass is a no-op.

**Nil values DELETE keys.** stripe-ruby 9.4.0 encodes Ruby `nil` as an empty string (`util.rb:214-239`), and an empty value is Stripe's documented "remove this key" form. That is why `careers_page_url` and `organization_created_via` are added conditionally instead of always being present. Also: `metadata: ""` or `metadata: nil` would clear *everything* — `metadata: {}` is harmless.

**Not `Organization#update_stripe_customer`**, for three reasons in order of weight:

1. It omits `organization_created_via` — the key this backfill exists to write. Because Stripe merges, running it would leave that key still missing. It cannot do the job.
2. Its `rescue StandardError` logs to `Rails.logger` and Sentry. `Rails.logger` doesn't write to the terminal, so a run where every call failed looks identical to a clean one.
3. It also rewrites `email`, `name` and `description` — top-level customer fields, outside the scope of a metadata backfill. For an org whose owner changed since the customer was created, that silently rewrites the billing contact.

It also calls `owner.email` and `owner.full_name` unguarded while `owner_id` is nullable. The snippet above never touches `owner`, so nil-owner organizations need no skip.

**Scope is `where.not(stripe_customer_id: nil)`.** That column is written only by `create_stripe_customer` and cleared only by `stripe_delete_customer`, so its presence exactly means "a Stripe Customer record exists." The alternatives are all proxies: `claimed` is a business flag, `customers` excludes free-plan orgs that still have a customer, `subscribers` keys on the subscription.

**No database writes.** Nothing calls `save` or `update`, so no `Organization` validation runs — which matters because `belongs_to :owner` is required and would fail for legacy nil-owner rows.

---

## Rate limits and timing

Live mode allows 100 req/s globally and 25 req/s per endpoint ([docs.stripe.com/rate-limits](https://docs.stripe.com/rate-limits)). A serial console loop runs one request at a time, so it's bounded by round-trip latency at roughly 3-5 req/s — an order of magnitude under the limit even without the sleep. The `sleep(0.2)` matches the house pattern in `lib/tasks/one_off_tasks.rake` and leaves headroom for concurrent production traffic.

**~2-4 minutes for 300 organizations.**

No read-first pass. It would double the requests to ~600 and put the extra 300 on the *read* side, which is the allocation-limited kind — Stripe's write requests have no allocation limit, reads are capped at an average of 500 per transaction. Merge semantics make a blind write safe anyway.

**The SDK does not auto-retry.** `config/initializers/stripe.rb` sets only `api_key` and `api_version`, so `Stripe.max_network_retries` is the gem default `0`. And even when enabled, `StripeClient.should_retry?` deliberately does not retry 429s. A `Stripe::RateLimitError` would land in `failed_organization_ids` for a manual re-run. Do not set `max_network_retries` from the console — it is process-global.

---

## Conventions

Follows `cursor_rules/console_commands.md`: `ap` for output, `ap "...", color: { string: :red }` for emphasis, no code comments, and the method ends with a print statement immediately before `end` so it prints rather than returning an object.

Loop-shape analogs: `lib/tasks/housekeeping_tasks.rake:16-28`, `Organization.process_ai_credit_resets` (`organization.rb:960-977`), and the commented-out Stripe backfills at `lib/tasks/one_off_tasks.rake:478-497` which use the same per-iteration `sleep`.
