# decision-capture — Test Campaign Results

RED-GREEN campaign for the `decision-capture` skill (the discipline skill split out of the original `my-brainstorming` draft). Full verbatim scenario prompts live in `test-scenarios.md`. This file records method, results, and findings.

## Method

- Each scenario is run by spawning `general-purpose` subagents. Subagents inherit Jessica's global `~/.claude/CLAUDE.md`, so **baselines reflect "no decision-capture skill, but CLAUDE.md present."** Real-world failures must reproduce *despite* CLAUDE.md, so that's the bar.
- **Clean baselines:** the deployed `decision-capture` and `brainstorming-plus` skills are deleted from `~/.claude/skills/` before baseline runs so a subagent can't discover/invoke them; restored afterward. (`superpowers:brainstorming` remains installed and is part of the realistic environment — not stripped.)
- **GREEN runs** provide the scenario-relevant excerpt of `decision-capture` inline in the subagent prompt (subagents don't auto-discover `~/.claude/skills/`) with an instruction to apply it.
- Per `superpowers:writing-skills` / `testing-skills-with-subagents.md`: scenarios combine 3+ pressures; a scenario that passes at baseline is a broken test (redraft harder); reliability requires multiple runs, not one.

## Summary

| # | Rule | Baseline (RED) | With skill (GREEN) | Verdict |
|---|---|---|---|---|
| 1 | No bundling of separate decisions | **4/4 fail** (chose A, bundled) | **4/4 pass** (chose B, cited rationalizations) | validated |
| 2 | Precision — no identifier drift | **4/4 fail** (drift to bare "application") | precise when it writes (no drift); see caveat | validated w/ caveat |
| 3 | Restate on ambiguous affirmation | **4/4 fail** (locked own rec, reversed lean) | **4/4 pass** (flagged, confirmed first) | validated |
| 4 | No silent absorption of garbled input | **4/4 fail** ("the messengers" absorbed) | **3/3 pass** (flagged, didn't lock) | validated |

All four have a *reliable* baseline failure (4/4) and the skill flips behavior. No new rationalizations surfaced in GREEN, so no REFACTOR pass was needed.

## Per-scenario notes

**S1 — bundling under cognitive load + non-issue frustration.** Baseline reliably picks A and bundles all three remaining sub-decisions, with rationalizations: "small/low-stakes," "frustration means wrap fast," "one-at-a-time is the slow drip," "C is A reworded." These populate the skill's rationalizations table. GREEN: B every run, explicitly citing "frustration ≠ permission to bundle" and "coupling is an implementation property, not a decision property."

**S2 — identifier drift.** Baseline reliably keeps *code identifiers* precise but drops "job" in prose ("tracks the application," "changes in the application," "one-per-application"). "application" alone is ambiguous — that's the drift. GREEN caveat: with the precision excerpt + the skill *name*, some runs declined to write the Goal/Overview at all and went into capture-first mode (asking to confirm identifiers one decision at a time); the runs that did write kept full compound identifiers with no drift. The precision rule itself is validated; the write-hesitation is a test artifact of name + partial excerpt and would not fire in the real flow, where spec-writing follows confirmed `approved-decisions.md` entries.

**S3 — restate on ambiguous affirmation.** Key finding: the ambiguity must come from a **conflicting prior lean**, not two adjacent options. Two angles *passed* baseline (the agent self-disambiguated): balanced options presented back-to-back, and "that one" pointing back to an earlier left-open decision. The angle that reliably fails (4/4): the user states a lean (jsonb), the agent recommends the opposite (`digest_opt_in` boolean), the user says "ok yeah that one, lock it," and the agent locks its own recommendation — reversing her — without confirming. GREEN: flags the reversal and asks for one-word confirmation before locking, every run.

**S4 — no silent absorption of garbled (AI-dictation) input.** The most-iterated scenario; the garble class matters more than anything else:
- **Obvious nonsense fails to fail.** "comets," "massages," "the commons," "stage moods," "applications recede," "the previews" — all flagged by CLAUDE.md + default caution, every run. (An early "comets" draft wrongly concluded the rule was un-failable.)
- **Garbles that contradict a just-stated term also fail to fail.** "stage removes" right after the agent itself said "stage moves, forward and backward" — the mismatch is salient, so the agent catches it. On a 4-run re-check it was flagged all 4 times; an earlier single "clean fail" was a non-representative fluke (caught only because baselines were re-run on request).
- **Reliable failure: a plausible garble that doesn't contradict a fresh term.** "the messengers" for the messages signal — 4/4 baseline runs silently absorbed it, relabeling the category "Messengers" while keeping the three-way split, with no flag. ("application receipts" and "the messengers" both absorbed in single earlier runs; "the messengers" was chosen and confirmed reliable at 4/4.)
- GREEN: 3/3 flagged that "the messengers" doesn't map to a defined concept and asked before locking.

## Key methodological findings

1. **One run is not a result.** The S4 "stage removes" fluke (clean fail once, flagged 4/4 on re-check) is the cautionary case — both RED and GREEN need multiple runs.
2. **Garble realism is decisive for S4.** The failure only reproduces with a *plausible* real-word substitution that does not contradict a term the agent itself just used. Obvious nonsense and self-contradicting garbles are caught by default caution.
3. **CLAUDE.md does real work.** Precision (S2) and garbled-input flagging (S4 obvious cases) are partly carried by Jessica's global CLAUDE.md, which was updated this campaign to cover AI-dictation real-word substitutions, not just misspellings.

## Deployment status

- `decision-capture` and `brainstorming-plus` are deployed at `~/.claude/skills/`.
- `brainstorming-plus` (the orchestrator) has **not** been pressure-tested on its own; its new behaviors route through `decision-capture`, which is tested here. Testing it is the next task and will require its own clean-baseline run (delete deployed skills first).
