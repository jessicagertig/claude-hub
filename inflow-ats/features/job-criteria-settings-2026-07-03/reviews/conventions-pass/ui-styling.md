# Conventions review — ui_styling.md only

Scope: `git diff develop...HEAD -- app/javascript/ats/src/views/jobApplications/jobSetup` at HEAD 68e5e6a4e.
Rules file: `cursor_rules/frontend/ui_styling.md`. Theme facts verified against `app/javascript/ats/styles/theme.ts`, `app/javascript/shared/styles/lightTheme.ts`/`darkTheme.ts`, `app/javascript/shared/layouts/AppDefaultWrapper.tsx:74` (`poly:` theme wiring).

## Findings

- F1 [MED] app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx:99, :140; app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:200 / Theme Usage ("Use theme values" — `t.rounded.xs/sm/md` listed in Theme Verification) / Raw `border-radius` values that have EXACT theme-token equivalents / `border-radius: 5px;` (JobCriteriaViewModal.tsx:99) — `t.rounded.sm` is `border-radius: 0.3125rem` (= 5px, theme.ts:306-308); `border-radius: 7px;` (JobCriteriaViewModal.tsx:140, JobCriteriaSection.tsx:200) — `t.rounded.md` is `border-radius: 0.4375rem` (= 7px, theme.ts:309-311) / Fix: replace with `${t.rounded.sm};` and `${t.rounded.md};` standalone.

- F2 [MED] app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx:127, :163, :168; app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:175; app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx:149, :177 / Theme Verification (`t.text.xs/sm/base/lg`) + Theme Usage / Raw `font-size` values that have EXACT typeScale token equivalents / `font-size: 14px;` (JobCriteriaViewModal.tsx:127, JobCriteriaSection.tsx:175) = `t.text.sm` (0.875rem); `font-size: 12px;` (JobCriteriaViewModal.tsx:163, :168) = `t.text.xs` (0.75rem); `font-size: 1rem;` (JobSetupAiSettings.tsx:149) = `t.text.base`; `font-size: 0.875rem;` (JobSetupAiSettings.tsx:177) = `t.text.sm` / Fix: use the standalone utilities (`${t.text.sm};`, `${t.text.xs};`, `${t.text.base};`) — NOT inside a `font-size:` property.

- F3 [MED] app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:267 / Theme Usage / Raw `font-weight: 450;` on `.n` has an exact token equivalent / `t.text.medium` is `font-weight: 450` (theme.ts:254-256) / Fix: `${t.text.medium};`.

- F4 [MED] app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx:88-113 (CloseButton); app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:180-186 (SectionIntro `a`) / Rule 6 "Hover and Focus States — Always include hover and focus states" / Interactive elements styled with `&:hover` only, no `&:focus` / CloseButton (`styled.button`) has `&:hover { ... }` at :108-111 but no `&:focus`; SectionIntro's `a` has `&:hover { text-decoration: underline; }` at :184 but no `&:focus` / Fix: add `&:focus { outline: none; box-shadow: 0 0 0 2px ${t.dark ? t.color.gray[500] : t.color.gray[300]}; }` per the rule's example (or equivalent poly-token focus ring).

- F5 [LOW] app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx:75, :118, :126, :138, :150-151, :160, :178; app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:207, :257, :278-279; app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx:175 / Theme Verification (`t.px()/t.py()/t.p()/t.mx()/t.my()/t.m()`, `t.spacing[1-12]`) / Raw px spacing where the theme spacing scale covers the value / e.g. `padding: 16px 20px 12px;` (:75 — spacing 4/5/3 are exactly 1rem/1.25rem/0.75rem), `margin-top: 16px;` (:138 = `t.mt(4)`), `padding: 2px 20px 24px;` (:118 — 20px/24px = spacing 5/6), `gap: 8px;` (JobCriteriaSection.tsx:257 = `t.spacing[2]`) / Fix: use `t.p/px/py/mt` utilities or `${t.spacing[n]}` where an exact token exists; off-scale values (7px, 14px, 6px, 10px) need a deliberate decision, not silent raw px.

- F6 [LOW] app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx:80, :179; app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:215, :221, :251 / Theme Verification ("Always verify theme values exist") / Off-scale raw font sizes with no typeScale token: `font-size: 22px;` (:80 — scale has xl=20px, xxl=24px), `font-size: 13.5px;` (:179), `font-size: 15px;` (:215), `font-size: 12.5px;` (:221), `font-size: 13px;` (:251) / Fix: snap to the nearest typeScale token or justify the off-scale value; the rules file's own size-variant example uses rem, not fractional px.

- F7 [LOW] app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:180-186 / Rule 7 "Transitions — Include smooth transitions for interactive elements" / SectionIntro `a` has hover styling but no `transition` declaration (CloseButton in JobCriteriaViewModal.tsx:102 does this correctly) / Fix: add `transition: color 0.2s ease;` or equivalent.

- F8 [LOW] app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx:139, :154, :164; app/javascript/ats/src/views/jobApplications/jobSetup/RegenerateJobCriteriaConfirmModal.tsx:95, :105, :128 / Styling Pattern 1 "Styled Component Declaration" (`styled.div((props: any) => {`) / Callback param typed as bare `(props)` instead of the documented `(props: any)` / e.g. `Styled.Sidebar = styled.div((props) => {` (JobSetupAiSettings.tsx:139); JobCriteriaViewModal.tsx and JobCriteriaSection.tsx follow the documented `(props: any)` form / Fix: annotate `(props: any)` for consistency with the declared pattern.

## Checked and clean (no finding)

- Label convention: all 17 styled components in the diff carry `label: ComponentName_ElementName;` in the correct format.
- Namespacing / placement: `let Styled: any; Styled = {};` namespace used; styles grouped at the bottom after the component in all 4 files.
- Theme destructuring: `const t: any = props.theme;` used wherever the theme is read.
- Text utilities as standalone declarations: no `font-size: ${t.text.*}` misuse anywhere in the diff; `${t.text.sm}` / `${[t.text.sm, t.mt(2)]}` used correctly (JobSetupAiSettings.tsx, RegenerateJobCriteriaConfirmModal.tsx).
- Dark mode: every color is either a `t.poly.color.*` semantic token (dark-aware via `AppDefaultWrapper.tsx:74` `poly: isDarkMode ? darkTheme : lightTheme`) or a `t.dark ? ... : ...` ternary; no hard-coded color literals without variants.
- Theme value existence: `t.poly.color.canvas/border/loudText/primaryText/secondaryText/subtleHover/cardCanvas/cardBorder` all exist (lightTheme.ts:4-34, darkTheme.ts:4-34); `t.text.bold`/`t.text.semibold` exist (theme.ts:257-262); `t.spacing[4]` exists; `t.rounded.md` exists.
- Array syntax for theme utilities: `${[t.mt(4), t.p(3), t.rounded.md]}` etc. used per the rule where utilities are composed.

## Re-verification (post 9ed954142)

Scope: shipped TSX at HEAD 9ed954142 in `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings`; fix commit hunks re-checked against `cursor_rules/frontend/ui_styling.md` only. Theme facts re-confirmed: `typeScale.xs/sm/base` emit ONLY `font-size` (theme.ts:90-112), `t.text.medium` emits ONLY `font-weight: 450` (theme.ts:254-256), `t.rounded.sm/md` emit ONLY `border-radius` (theme.ts:300-311) — so the inserted utilities cannot collide with adjacent `line-height`/`font-weight` declarations.

### MED resolution status

- F1 [MED] — RESOLVED. All three raw border-radius values replaced with standalone utilities: JobCriteriaViewModal.tsx:95 `${t.rounded.sm};`, :140 `${t.rounded.md};`; JobCriteriaSection.tsx:212 `${t.rounded.md};`. Zero raw `border-radius:` declarations remain in the four diff files.
- F2 [MED] — RESOLVED. All six cited raw font-sizes replaced with standalone utilities (never inside a `font-size:` property): JobCriteriaViewModal.tsx:127 `${t.text.sm};`, :163/:168 `${t.text.xs};`; JobCriteriaSection.tsx:183 `${t.text.sm};`; JobSetupAiSettings.tsx:129 `${t.text.base};`, :157 `${t.text.sm};`. Remaining raw font-sizes (22px, 13.5px, 15px, 12.5px, 13px) are exactly the F6 LOW off-scale set — out of F2 scope, unchanged as expected.
- F3 [MED] — RESOLVED. JobCriteriaSection.tsx:279 `.n` now uses standalone `${t.text.medium};`; no `font-weight: 450` remains anywhere in the diff files.
- F4 [MED] — RESOLVED. Both interactive elements gained `&:focus { outline: none; box-shadow: 0 0 0 2px ${t.dark ? t.color.gray[500] : t.color.gray[300]}; }` matching the rule 6 example verbatim: JobCriteriaViewModal.tsx:108-111 (CloseButton), JobCriteriaSection.tsx:195-198 (SectionIntro `a`).

### Fix-hunk re-check against ui_styling.md (new findings)

- R1 [LOW] app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx:98 vs :108-111 / Rule 7 "Transitions" (example: `transition: background-color 0.2s ease, box-shadow 0.2s ease;`) / The F4 fix added a `box-shadow` focus ring to `Styled.CloseButton`, but the pre-existing `transition: background 0.2s ease, color 0.2s ease;` was not extended with `box-shadow` — the new focus ring snaps in/out instead of transitioning, while the rules file's own example transitions `box-shadow` alongside background / Fix: `transition: background 0.2s ease, color 0.2s ease, box-shadow 0.2s ease;`. (SectionIntro `a` has no transition at all, but that is pre-existing F7 [LOW], not introduced by the fix.)

Checked and clean in the fix hunks:
- Standalone usage: all six inserted utilities (`${t.rounded.sm/md}`, `${t.text.xs/sm/base/medium}`) are standalone declarations — none inside a CSS property (pipeline rule 1).
- No adjacent-declaration conflicts: `${t.text.sm};` + `font-weight: 400; line-height: 1.6;` (JobCriteriaViewModal.tsx:127-129, JobCriteriaSection.tsx:183-185), `${t.text.xs};` + `font-weight: 600;` (JobCriteriaViewModal.tsx:163-164), `${[t.mt(1), t.text.bold]};` + `${t.text.base};` (JobSetupAiSettings.tsx:127-129), `${t.text.medium};` + `font-variant-numeric` (JobCriteriaSection.tsx:279-280) — each utility emits a disjoint property set from its neighbors, no duplicate or overridden declarations introduced.
- The JOB_CRITERIA_TIERS extraction (new jobCriteriaTiers.ts, JSX map hunks in JobSetupAiSettings.tsx/JobCriteriaSection.tsx/JobCriteriaViewModal.tsx) and the `isError` EmptyState hunk contain no styled-component code — nothing for ui_styling.md to evaluate.
- Labels, namespacing, `const t: any = props.theme;` destructuring, and dark-aware colors unchanged and intact in every touched styled component. (`(props)` without `: any` in JobSetupAiSettings.tsx is pre-existing F8 [LOW], untouched by the fix hunks.)
