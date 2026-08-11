# Spec Compliance (always-on) — Round 3

Also carries the always-on check **Source accuracy** (folded here, as in rounds 1-2).

Rule 15 first: worktree CLEAN, HEAD `68e5e6a4e` — reviewed `git diff develop...HEAD` (32 files, +1649/−20) plus `git show 68e5e6a4e` for the merge resolution. The reviewed code is the committed code.

- **File inventory**: the 32 changed files match SPEC §13 exactly — every "new" file present, every "modified" file present, ZERO extra files (`JobCriteriaSection.tsx` is the inventory's conditional extraction, executed).
- **Section-by-section walk**: 4.1 gating (verbatim + flag-1 kwarg), 4.2 constants/predicate (three writers switched, nothing else), 4.3 predicate placement next to `latest_ai_job_criteria`, 5.1 route, 5.2 controller (byte-equivalent to the spec block), 5.3 serializer (byte-equivalent), 6.2 all four guard sites with the funnel ordering, 6.3 claim-row fix, 7 job signature + three broadcast sites + helper, 8.1-8.7 frontend (hook spec-verbatim; display table implemented; both modals; WS case spec-verbatim; payload type spec-verbatim + header comment), 9 authorization (no new policy methods), 10 constraints (decided-OUT absent; copy rules pass; any-job-state; loading states; pipeline rules 11/12/13/22/25/26), 12 test plan (all 3 new + 8 modified spec files present with the specced cases).
- **Flags 1-7**: all implemented exactly as adjudicated; none re-litigated. Standing adjudications honored: View-button-during-in-flight (round 1), funnel-guard stranding (SPEC 6.2.4 documented consequence — the funnel guard returns bare, no new state transitions added), display precedence (Jessica's final verdict).
- **Source accuracy**: load-bearing citations re-verified at HEAD where line numbers drifted (job.rb methods now at 692-747; funnel guard textract_result.rb:70; route routes.rb:266; queue guard :19; validators :30/:19; bulk fix :62-65). All claims held.
- **Merge resolution** (`git show 68e5e6a4e`): conflicted files are the bulk controller + 3 spec files only; resolution threads `job:` + `params:` together and updates spec expectations to the merged contract — consistent with round 2's three-way byte verification; no feature hunk lost (spot-verified the guard, claim-row fix, and broadcast sites all live at HEAD).

## Findings

No issues found.
