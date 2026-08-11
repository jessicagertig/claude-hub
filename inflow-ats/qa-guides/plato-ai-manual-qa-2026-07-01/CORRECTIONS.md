# Owner-confirmed ground truth (Jessica, built the feature)

Corrections to feed any review pass. The Opus verify loop got these WRONG.

## Generate/Run control labels — 3 distinct controls, 2 surfaces

**Plato tab (per-candidate):**
- **"Generate review"** — empty state when NO review is queued for that candidate → starts a review.
- **"Generate review now"** — empty state when the candidate is ALREADY QUEUED for review → pushes them forward / jumps the queue (expedite).

**Sidebar (whole-job):**
- **"Run Plato"** — lives in the sidebar; gates and launches an entire-job BULK run.

### Verify-loop error
Findings claimed the manual single-candidate button is "not labeled Run Plato" and treated "Run Plato" as a Plato-tab control. FALSE POSITIVE / conflation: "Run Plato" is the sidebar whole-job bulk control; the Plato-tab per-candidate buttons are "Generate review" / "Generate review now" and differ by queue state. All three are real and correct on their own surfaces.
