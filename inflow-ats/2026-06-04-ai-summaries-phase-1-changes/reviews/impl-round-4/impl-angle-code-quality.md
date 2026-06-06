# Implementation Angle: Code Quality -- Round 4

## Fresh adversarial focus

1. **Dead `apply_subscription` method.** Same as Round 3 LOW finding. Still dead code. Not a regression.

2. **`self.class.send(:notify_complete, ...)` pattern.** Uses `send` to call private class methods from instance methods. This is a common Ruby pattern, not an anti-pattern. The alternative would be making the methods protected or non-private, but `private_class_method` ensures they can't be called externally. Acceptable.

3. **Error handling in `on_complete`.** The rescue block in `on_complete` catches `StandardError` after the notify calls. If `notify_complete` or `notify_failure` raises, the error is logged but the job completes. This prevents notification failures from causing the job to be retried. Good defensive pattern.

4. **`checkout` controller creates purchase with `amount_cents_paid: 0`.** The validation is skipped for pre-checkout subscriptions, so this is redundant but not harmful. It explicitly sets the field rather than leaving it nil. Acceptable.

5. **Consistent error message format.** All Stripe rescue blocks use the same pattern: `Rails.logger.error`, `ap e`, `Sentry.capture_exception`, `render_general_errors`. Consistent with existing code.

## Findings

- **LOW:** Dead `apply_subscription` method (carryover from Round 3, not new)
