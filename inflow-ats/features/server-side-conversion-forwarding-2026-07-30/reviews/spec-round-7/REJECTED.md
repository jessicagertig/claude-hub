# Spec review round 7 — rejected findings

## R1 (HIGH, conventions angle) — "the retry must not use a `begin` block; `request` needs a `while` loop and a private single-attempt method"

**Claim.** The named analog's retry is a `begin … rescue … retry … end` block
(`app/services/what_jobs_api.rb` lines 37–63), which "`cursor_rules/backend/_base.md` rule 1 and
`core_critical_rules.md` rule 1 forbid", so the spec must direct a `while` loop bounded by `max_retries`
calling a private single-attempt method whose own method-level rescue returns the exception in place of a
response.

**Refuted.** `cursor_rules/backend/_base.md` line 34, the closing line of rule 1 itself:

> Only use `begin ... rescue ... end` for nested logic within a method where you need to rescue a specific
> subset of operations.

A retry loop inside `request` rescues exactly one operation — the `post` — while the rest of the method
inspects `response.status`, logs, and raises `ApiError`. That is the stated exception, not a violation.
`core_critical_rules.md` rule 1 is titled "Controllers: NO BEGIN BLOCKS" and its example is a controller
`create` action; these are service objects.

The proposed fix would also add a private single-attempt method to each of the three clients — three methods
no round of this spec has specified — and a paragraph of control-flow prose, to replace a form the analog
already uses and the rules already permit.

## R2 (MED, spec-form angle) — "the AdRoll Server Access Token has not been issued yet, so the AdRoll path stays inert"

**Claim.** ADROLL-S2S-CREDENTIALS.md says the SAT is obtained by contacting the AdRoll account manager through
a one-shot 1Password share, so it does not exist yet, and SPEC §AdRoll Credentials must declare the pending
state as §GA4 and §Google Ads do.

**Refuted.** HANDOFF.md line 12:

> AdRoll has issued Jessica only a single key, which is the same one production uses, so testing is
> constrained and she needs to work out that setup before the phase starts.

The token exists. The reference document describes how a SAT is obtained, not the state of ours. Writing "has
not been issued yet" into SPEC.md would have been a false statement about a live credential.

The naming half of the same finding was applied — SPEC §AdRoll Credentials now names
`Variables::ADROLL_S2S_API_KEY`, `Variables::ADROLL_ADVERTISABLE_EID` and `Variables::ADROLL_PIXEL_EID`, and
the two EID payload source cells name their constants.

## R3 (HIGH, no-abstraction angle) — "`Ga4MeasurementProtocol::Client` must write the exhaustion `Rails.logger.error` on the transport path"

**Not refuted, escalated.** The contradiction the finding identifies is real and was fixed: SPEC said all
three clients write the same final-failure line and, twenty-seven lines later, that GA4 writes none. It is
resolved toward the spec's existing decision — the sentence now exempts `Ga4MeasurementProtocol::Client` by
name.

The finding's alternative resolution changes behavior rather than removing an inconsistency, so it is not
applied here. Its premise is also narrower than stated: on transport exhaustion `SendGa4EventJob`'s
method-level rescue writes `Rails.logger.error e`, an `ap` label naming the destination and the user id, and
`ap e`, so the destination and the user id are recorded and only the attempt count is not. Carried to
REVIEW-FINDINGS.md as Q7 for Jessica's ruling.
