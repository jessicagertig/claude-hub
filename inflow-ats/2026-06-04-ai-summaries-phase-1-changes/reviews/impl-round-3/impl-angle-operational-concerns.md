# Implementation Angle: Operational Concerns -- Round 3

## Reviewed for

- Error visibility (logging, Sentry)
- Graceful degradation
- Backward compatibility concerns

## Observations

### Error visibility
- `Sentry.capture_exception(e)` added to `create_ai_credit_state_if_needed` rescue -- improves visibility
- All new controller actions have Sentry capture in Stripe rescue blocks
- `checkout.session.completed` logs error when no purchase found for session
- `invoice.paid` top-up logs error when org or lookup_key missing
- `notify_failure` guards with `return unless payload` and `return unless user`

### Backward compatibility
- Route paths changed from `/ai_credit_subscriptions/subscribe` to `/ai_credit_purchases/checkout` -- frontend updated in sync
- Old routes removed (no redirect) -- acceptable since these are dev-only features
- `prompt_text` column removed from migration -- requires rollback/re-migrate on dev, documented in plan

### Graceful degradation
- `notify_failure` in `discard_on`/`retry_on` blocks: if notification fails, the job still completes its error handling (statuses updated to failed)
- `on_complete` wraps notification in rescue to prevent notification failure from crashing the completion callback
- `aiCreditPrices` returns empty array when no matching prices found -- UI gracefully shows no options

### Additional migration note
- `20260605035312` is an additional migration that handles the column rename at DB level. It is idempotent (checks `column_exists?` before acting). This supplements the in-place edit of the original migration. Both approaches work: the in-place edit handles fresh databases, the rename migration handles databases with the old column name. No operational concern.

## Findings

**No findings.**
