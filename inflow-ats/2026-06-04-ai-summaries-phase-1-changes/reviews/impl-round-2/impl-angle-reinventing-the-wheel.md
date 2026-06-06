# Implementation Angle: Reinventing the Wheel -- Round 2

## Checks

### Check 1: `apply_one_off_from_invoice` -- new or duplicate?
NEW AND JUSTIFIED -- This is a new code path for invoice-based one-off purchases. It cannot reuse `apply_one_off` because the data source is different (invoice metadata vs. checkout session line items). The structure is parallel but the extraction logic is distinct.

### Check 2: `notify_complete` and `notify_failure` -- reusing patterns?
PASS -- Both follow existing patterns: `GlobalChannel.broadcast_to` (matches `on_complete` broadcast pattern), `Mailer.method(...).deliver_later` (matches project convention).

### Check 3: `AccountPlatoAiContainer` -- analog followed?
PASS -- Directly modeled on `AccountIntegrationsContainer`. No reinvention.

## Verdict: PASS
