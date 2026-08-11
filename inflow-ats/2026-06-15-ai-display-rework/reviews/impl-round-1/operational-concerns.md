# operational-concerns

## Checked

1. **Performance impact of `update` vs `update_columns`:** `update` triggers validations and callbacks. The only validation is `validates :status, presence: true` (trivial). The only new callback is `broadcast_status_change` which does a `JobChannel.broadcast_to` call. This adds a small overhead per status transition (typically 5-8 transitions per pipeline run). Acceptable.

2. **Broadcast volume:** For a single pipeline run, broadcasts fire for: `textract_processing`, `extracting`, `summarizing`, `scoring`, `integrating`, `succeeded` = 6 broadcasts. Plus `failed` if it fails. For bulk operations (e.g., 50 summaries), this means ~300 broadcasts. Each is a lightweight ActionCable message. Not a concern for current scale.

3. **Double invalidation on `succeeded`:** Both `JobChannel` and `GlobalChannel` broadcasts fire for `succeeded`. React Query deduplicates within the same tick. The `GlobalChannel` handler also shows a toast notification and invalidates `organizationAiCreditBalance`. No conflict.

4. **PlatoLoadingState monotonic state:** `Math.max(prev, target)` ensures the checklist never regresses. If a websocket message arrives out of order (e.g., `extracting` arrives after `scoring`), the active step stays at `scoring`. Correct behavior.

5. **Default active step = 1:** When no status maps, the checklist starts at step 1 ("Analyzing the candidate"). This means "Processing the resume" appears already done on initial render. Spec explicitly addresses this (risk #4 in the plan) -- `textract_processing` is often already complete when the user navigates to the Plato tab.

## Findings

None.
