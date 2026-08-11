# Round 1 — Angle 5: Frontend display-state derivation, loading states, payload contract

## Verified against source

**Six-state table vs serializer contract (row for row against Angle 4's verified contract):**
- never-ran (all null) / first-run in-flight / succeeded / regenerating-over-success / zero-failed / other-failed — all derivable from `{criteria, extractedAt, status, zeroCriteriaFailure}` ✓ after this round's two amendments (see Findings).
- Precedence order (isLoading → in-flight → failed+zero → failed-other → card → never-ran) is internally consistent; flag 5 (failed latest hides older succeeded card) RULED — verified the spec implements it (rows 2/3 win over row 4) and the "Plato won't review candidates" copy is literally true in that state because of the Section 6 guard ✓.

**Loading states (DECISIONS named failure mode):**
- Initial fetch: `LoadingIndicator label="Loading..."` — analog verified at OrganizationAiUsage.tsx:29-31 ✓.
- Button loading driven by BACKEND status (payload `pending`/`in_progress`/`retrying`), survives reload ✓; `isInFlight` also covers the just-POSTed-and-refetching window (payload in-flight OR post-POST refetch) — specified ✓.

**Casing:** `status`/`tier` values stay snake_case (core rule 7 Ruby-enum exception, verified in core_critical_rules.md:147-149); keys camelCase via api.ts transform ✓. `AiJobCriterion.sourceHeading` matches the stored `source_heading` key (writer verified: extraction prompt schema requires `source_heading`, job_description_criteria_extraction.rb:246-249; heading-override writes `criterion['tier'] = 'tier_1'`/`'tier_3'`, extract_criteria.rb:110-113 — confirming `tier_1`-form stored values, NOT the design bundle's `tier1` keys) ✓.

**No fabricated fallbacks:** spec'd hook/serializer code contains no `|| 0`/`|| ""`/`|| []`; section 8.3 explicitly prohibits `criteria || []`; `enabled: jobId != undefined` matches the analog form exactly (useAiJobApplicationSummary.ts:45) ✓. No `??` anywhere in spec'd code (frontend/_base.md §1 verified: "Do Not Use Nullish Coalescing Operator") ✓.

**Component/prop verification:**
- `EmptyState.tsx:7-13` — props are `title`/`message`/`icon`/`borderless`/`roomy` ONLY. NO action/button prop. **Phase-1 trace note 1 ADJUDICATED as a spec gap** (see F2).
- `PlatoChip` (PlatoMark.tsx:60-66): `size`, `radius` props; gradient + inset ring built into `Styled.Chip` (:96-109) — spec's "do not re-style" guidance correct ✓.
- `distanceInWords` (time.ts:89-91): `formatDistanceToNow(new Date(date), { addSuffix })`, addSuffix default true → "ago" ✓; accepts an ISO string ✓.
- `FormSection` `intro` prop: destructured index.js:11, rendered :36, propTypes element-or-string :47 ✓ (spec citation corrected — see F3).
- Description link route `/jobs/${id}/setup/description` verified against RunPlatoAddDescriptionModal.tsx:32 AND the actual Route at JobSetupContainer.tsx (`${match.path}/description`) ✓; `props.history.push` available — JobSetupAiSettings receives Route renderProps (JobSetupContainer `render={(renderProps) => <JobSetupAiSettings {...props} {...renderProps} ...>}`) ✓.
- Sidebar: `SettingsContainer` `sidebar` prop (:10, rendered :72); `display: none` below lg (:196-208); adding it switches Content to the 50vw hasSidebar layout (:116-126) — layout impact on the existing Plato-reviews form is an impl/QA verification item (angles file carries it); no spec change needed. AccountTeam register verified (:441-477) ✓.
- Section intro copy accuracy re-verified against `handle_criteria_extraction_after_commit` (job.rb:746-752): extracts on publish and on meaningful description change while published — the drafted copy states exactly this ✓ (DECISIONS lifecycle-explanation requirement honored).
- Component size: `jobSetup/components/` dir exists ✓; conditional extraction target valid.
- Existing behavior preserved: spec keeps lines 15-80 of JobSetupAiSettings.tsx untouched (file verified — 83 lines, dirty tracking + Save flow at those lines) ✓.

## Taken on trust from the spec
Visual-spec pixel values (560px card, 186px rail, 12.5px meta, etc.) — taken from DECISIONS (binding) rather than re-derived from design HTML; they match DECISIONS' "Visual specs" section verbatim.

## Findings

- F1 [MED] SPEC 8.2 row 1 said "Underlying content per rows 3-5 using the rest of the payload". Rows 2-3 are UNREACHABLE underneath an in-flight latest row: `status` is the in-flight value (not "failed") and `zeroCriteriaFailure` is false because `Job#zero_criteria_extraction_failure?` reads the latest row. The only derivable underlying content is row 4's card (criteria present) or row 5's never-extracted EmptyState (criteria null). As written, an implementer could burn time trying to derive a failure state that the payload cannot express, or invent client-side state to remember the prior failure. Fix: row 1 rewritten to name rows 4-5 with the reachability explanation.
- F2 [MED] SPEC 8.2 listed per-state "action rows" but never said WHERE they render; `EmptyState` has no action/button prop (EmptyState.tsx:7-13) and its `message` prop (string | object) would accept smuggled JSX buttons — the wrong implementation is available and undetectable from the spec text. Fix: explicit placement sentence added (action row is a section-level element outside EmptyState).
- F3 [LOW] Citation drift: `RunPlatoAddDescriptionModal.tsx:33` → actual :32; `FormSection/index.js:10,37` → actual :11,36; `OrganizationAiUsage.tsx:18-20` → actual :17-19. Fixed to prevent stale-citation churn in later rounds.

## Amendments Applied

1. SPEC 8.2 row 1 rewritten: underlying content = row 4 card or row 5 EmptyState; rows 2-3 unreachable rationale inline (F1).
2. SPEC 8.2 "Action-row placement" paragraph added after the button-label paragraph (F2).
3. SPEC 8.3 citations corrected (F3).

All patched sections re-read and verified.
