# Contact page design and ported ATS form primitives

## Outcome: built, tested against a running production build, committed and pushed on `contact-page` (`6868053`), added to PR #54.

Source spec: `/Users/jessica/Projects/genuine-article-images/design_handoff_contact_page`
Worktree: `/Users/jessica/wrk/wrk-corp/wrk-marketing.contact-page`

## What shipped

| File | Change |
|---|---|
| `web/components/formLabel.js` | new, ported |
| `web/components/formInput.js` | new, ported |
| `web/components/formTextarea.js` | new, ported |
| `web/components/formSelect.js` | new, written against react-select 5.10.2 |
| `web/components/contact/morePolymer.js` | new, the three card row |
| `web/pages/contact.js` | rebuilt to the design, submit path unchanged |
| `web/pages/api/contact.js` | two lines, carries the new `reason` field into the email |
| `web/styles/theme.js` | `rounded.xs` added |
| `web/components/button-new.js` | `font-family: inherit` and `border: none` in `baseStyles` |
| `web/package.json`, `web/package-lock.json` | `react-select@^5.10.2` |

## react-select

`react-select@5.10.2`, installed with a real `npm install` in the worktree's
own `web/node_modules` (412 packages plus 9 for react-select), not a symlink to
the main checkout. Peer range is `react ^16.8 || ^17 || ^18 || ^19`, so React
17.0.2 is inside it. The ATS's 2.4.1 declares `react ^15 || ^16` and would not
have installed.

The `styled(Select)` plus `classNamePrefix="form-select-ui"` pattern carries
over intact. The override block sits at specificity 0-2-0
(`.wrapper .form-select-ui__control`) against react-select's own single-class
emotion output, so it wins without `!important` or `unstyled`. Verified in the
browser: control and menu both take the marketing values.

| | input | select |
|---|---|---|
| height desktop | 32px | 32px |
| height mobile | 40px | 40px |
| radius | 5px | 5px |
| focus ring | `0 0 0 2px #D5D5D5` | `0 0 0 2px #D5D5D5` |
| focus border | `#A3A3A3` | `#A3A3A3` |

### ATS machinery dropped

- **`scope` / `props.scope.setState`** — the deprecated escape hatch that
  expects `this` from a parent class component. Every component here is a
  function component; only the `onChange` path remains.
- **`Creatable` and `isMulti`** — `Styled.Creatable` was a near-verbatim copy
  of `Styled.Select` differing in two disabled-state background values. One
  dropdown with five fixed options needs neither, and dropping them removes
  the whole first `return` and the `__multi-value` block.
- **`onInputChange` / `handleInputChange`** — only the Creatable path called it.
- **`errorTextViaYupOrRailsOrJoi`** from `@shared/lib/formHelpers` — it reads
  `errors[name]` and normalises three shapes: a Rails array of strings joined
  with `", "`, a Yup object read as `error.fieldError`, or null. The marketing
  site has no Rails, Yup or Joi; the contact form validates in the browser and
  produces plain strings, so `error` is a `PropTypes.string`.
- **`findSelectOptionByValue`** from `@ats/src/lib/lookups` — inlined as
  `options.find((option) => option.value === value) || null`.
- **`lodash/isArray`** — only reachable through `isMulti`; `Array.isArray`
  would have covered it and no lodash is needed.
- **`react-hotkeys-hook`** in FormInput — redundant with the component's own
  Escape `addEventListener`, and not a dependency of this repo.

## Decisions

- **Flat files, not `web/components/form/`.** Every existing subdirectory in
  `web/components/` is page scoped (`home/`, `jobBoard/`,
  `candidateManagement/`, `industries/`, `plato/`), while shared primitives
  used by many pages sit flat at the root (`button-new.js`, `icon.js`,
  `container.js`, `section.js`, `seo.js`). The form primitives are shared, so
  they are flat: `formLabel.js`, `formInput.js`, `formTextarea.js`,
  `formSelect.js`. The card row is page scoped, so it is
  `contact/morePolymer.js`.
- **Gradient frame: local styled div.** There is no reusable `ScreenFrame`.
  All eleven users of the gradient declare it inline in their own
  `Styled.*Frame` or `Styled.Box`, closest being `home/intro.js`
  `Styled.ImageFrame` and `start.js` `Styled.Box`. `Styled.FormColumn`
  follows that, with the frame's own 16px radius and 8px/12px padding.
- **`t.mq[30]` kept for the control size step**, as the handoff's ported files
  had it, so 40px/16px controls hold to 480px and 32px/14px take over above.
  The alternative the porting guide raised (`t.mq[40]`) was not taken.
- **`morePolymer.js` is a new component, `home/toolkit.js` is untouched.** It
  starts from toolkit's card, icon box and description styles and changes what
  this page needs: left-aligned heading at 26px stepping to `t.text.xxxl`, a
  `repeat(auto-fit, minmax(280px, 1fr))` grid rather than a flex row, no
  `min-height`, and an outbound third card. Homepage checked in the browser
  afterwards, unchanged.

## Two real defects found while testing

1. **Native constraint validation swallowed the submit.** `type="email"` with
   "not-an-email" in it makes the form invalid, so the browser refuses to fire
   `submit` and `handleSubmit` never runs: no errors appeared and no request
   went out. `noValidate` on the form gives the on-submit validation the spec
   asks for back. The no-JavaScript path is unaffected, the API route already
   validates server side and redirects to `/contact#invalid`.
2. **`ButtonNew`'s button variant rendered in Arial with a `2px outset`
   border.** `Styled.Button` is a `styled.span`, so nothing in it resets the
   user agent's button defaults, and `as="button"` exposes them. The contact
   page is the first caller of `type="button"` anywhere in the repo, so a
   `font-family: inherit` and `border: none` in `baseStyles` fixes it for
   every future caller and changes nothing that renders today.

## What was tested, against `next start` on a production build

- Empty submit: all four errors at once, red borders on all four fields
  including the select, error text right-aligned on each label row.
- Editing a field clears only that field's error.
- Invalid email: only the email and topic errors, name and message clean.
- The select: five options in spec order, `Get a demo` through
  `Something else`; picking one writes `demo` to the hidden `input[name=reason]`
  that react-select renders for form submission.
- Expand modal: opens, the 20-row textarea holds the same value, typing there
  reaches the inline field, Esc closes it, the value persists.
- Real submit: `POST /api/contact` with
  `name=Priya+Raman&email=priya%40cala.com&company=&reason=support&message=...&website=`,
  answered 500 because `POSTMARK_SERVER_TOKEN` is not in the local
  `.env.local`, and the failure banner rendered with the form values intact.
- Success screen: exercised by stubbing `window.fetch` for one call so no mail
  was sent. Tile, "Thanks — we've got it", the entered address echoed, and both
  buttons render; "Send another message" resets to empty.
- Non-JSON path with curl: valid body redirects 303 to `/contact#failed`,
  missing fields to `/contact#invalid`, honeypot answers `{"sent":true}`.
  `:target` confirmed in the browser at `/contact#failed`.
- Sizes: 375px gives 40px controls, 16px text, 24px "Send us a message", form
  first, routes two-up with the icon above the text. 1280px gives 32px
  controls, 14px text, 20px heading, 12px frame padding, 16px frame radius.
- Dev server run separately: no React warnings, no PropTypes warnings, and no
  styled-component props reaching the DOM.

Screenshots: `../screenshots/contact-page-design/`

## Open for Jessica

- **The h1.** The README specifies `Let's talk` for the page h1 and also
  `Let's talk` for the rail h2, so the page says it twice. The design
  reference has `Contact` in the h1. The README won because copy was declared
  final; it is a one-word change either way.
- **Routes layout at desktop.** The README's section-by-section text stacks
  the two contact routes vertically with a 28px gap, its responsive table says
  "side by side at every width". The reference resolves it: column above
  1024px, row below. Built that way, because at desktop the rail is about
  350px wide and two inline routes leave the description roughly 100px.
- **SEO block untouched.** The README asks for the page title `Contact`; the
  existing `pageTitle="Contact Polymer - Talk to Sales and Support"` and its
  meta description from PR #54 are kept.
- **The em-dashes in `Thanks — we've got it` and the modal helper line** are
  the spec's final copy, kept verbatim.

---

# Review round 1 — findings worked

Commit `18d9c69` on `contact-page`, pushed. Build clean on Node 16.20.2
(only pre-existing warning: `no-css-tags` at `_document.js:124`). Form
re-tested end to end at 375 / 896 / 1024 / 1150 / 1280.

Four reviewers filed 23 findings across four lenses. 17 fixed, 6 rejected
with evidence.

## Fixed

**Two columns wrapped rail-first between 1024px and 1180px (HIGH).**
`Styled.Body` carried `flex-wrap: wrap` inside `${t.mq[64]}` while the
children kept `flex: 1 1 340px` and `flex: 1 1 640px` plus a 72px gap, so
1052px of basis never fitted a `vw - 128` content box below 1180px, and
`order: -1` on the rail then put the rail on the first line. Removed
`flex-wrap: wrap`; both columns now shrink instead. Measured at 1024: rail
left 64 width 285, form left 421 width 539, tops 13px apart. At 1150: rail
329, form 621. At 896 and below it still stacks form-first (form top 314,
rail top 1131).

**Body copy rendered #555555 instead of #4D4D4D (MED).** The rail
description, both route descriptions, the trial tile paragraph and the
success paragraph used `t.color.gray[600]`. The README's per-section text
gives `#4D4D4D` in all four places (lines 94, 106, 120, 350) and its token
table contradicts itself at line 408. The design reference settles it: those
five paragraphs plus the page header use `var(--text-body)` while the
reply-promise row alone uses `var(--text-muted)`, which is the one place the
README writes `#555555` explicitly (line 96). Changed the four to the literal
`#4D4D4D`, which is how `header.js:78` and `toolkit.js:199` already write it;
left the reply-promise row, the expand button and the modal helper on
`gray[600]`. Measured: rail, route, trial, success, header and card
descriptions all `rgb(77, 77, 77)`; reply promise `rgb(85, 85, 85)`.

**maxLength was dropped from every field (MED).** The form before PR #54's
redesign had `maxLength={200}` on name/email/company and `maxLength={5000}`
on the message, and the ported primitives carried no such prop, so
`api/contact.js:20`'s `.slice(0, 5000)` silently truncated and still reported
success. Added a `maxLength` pass-through to `FormInput` and `FormTextarea`
and set it at the call sites to the server's own limits. Measured: name,
email, company 200; message 5000, both inline and expanded.

**No client-side validation without JavaScript (LOW).** `noValidate` sat on
the JSX and no field carried `required`, so a no-JS visitor's empty submit
did a full page navigation to `/contact#invalid` and lost everything typed.
`noValidate` now moves to a hydration effect keyed on `status`, so the
server-rendered HTML has native validation and the scripted path still shows
every field error at once. Added a `required` pass-through and set it on
name, email and message. Verified: the served HTML has `required=""` three
times and no `noValidate`; after hydration `form.noValidate === true`, and it
re-applies when "Send another message" remounts the form. Deliberately not
passed to `FormSelect`: react-select's `required` renders a hidden
`RequiredInput` that a no-JS visitor cannot fill, which would break the
fallback rather than improve it.

**Two elements shared `id="message"` while the modal was open (LOW, filed
twice).** Root cause was the shared id generator, so it was fixed there:
`inputId` in all three primitives is now just `name`. That also kills
`inputWhatcanwehelpwith?` and `inputCompany(optional)` — ids that were legal
HTML but threw in `document.querySelector` and would not resolve as URL
fragments. The modal textarea then takes `name="messageExpanded"` with
`onChange={(fieldName, fieldValue) => setField("message", fieldValue)}`; it
sits outside `<form>` so the name is never serialised. Measured with the
modal open: ids `message` and `messageExpanded`, no duplicates on the page,
`label[for="message"]` resolving to the 9-row inline field, and the value
syncing both directions.

**react-select had no `instanceId` (LOW).** The prefix came from a
module-level counter in `Select-1b9abbe3.cjs.dev.js:1745`, correct today only
because `/contact` holds the site's only Select; a second prerendered
dropdown would give the client a different prefix than the static HTML.
Passed `instanceId={name}`. The served HTML now carries
`react-select-reason-placeholder` and `react-select-reason-live-region`.

**Error state was invisible to assistive tech (LOW).** `Styled.Error` had no
id and nothing referenced it. `FormLabel` now gives it
`id={`${htmlFor}-error`}`; the three field primitives set
`aria-invalid={Boolean(error)}`, with `aria-describedby` on the native
controls and `aria-errormessage` on the select, since react-select owns
`aria-describedby` for its own live region. Measured after an empty submit:
four errors visible at once, `aria-invalid="true"` on all four controls,
`name-error` / `email-error` / `message-error` via describedby and
`reason-error` via errormessage.

**`reason` was not checked against the published options (LOW).**
`api/contact.js` now accepts it only when it is one of `demo`, `presale`,
`support`, `press`, `other`, and sends `(not provided)` otherwise.

**ATS comment banner in the four ported files (MED, filed twice).** The
`/* Styled Components ... */` block came in from the handoff's own
`ported/FormLabel.js:45-46`. Removed from all four. A repo-wide grep for
"Styled Components" now returns nothing.

**Form primitives moved to `web/components/forms/` (LOW).**
PORTING-FORM-COMPONENTS states the target twice — its header line 4 and its
section 5 — so they now live at `web/components/forms/formLabel.js` and
siblings. Kept the repo's camelCase filenames rather than section 5's
PascalCase, because section 5's own stated rationale is "matching the
existing `web/components/` convention" and that convention is
`basicPage.js`, `blogIndex.js`, `checkmarkIcon.js`, `logoPartner.js`.

**Lowercase hex (LOW).** `#4d4d4d` in `morePolymer.js` and three
`linear-gradient(84.47deg, #fbd7ff 0%, #ffe4cc 100%)` declarations in
`contact.js` are now uppercase, matching the other fourteen declarations of
that gradient across the repo.

**One font size spelled two ways in `contact.js` (LOW).** Every size with an
exact theme token now uses the token: `t.text.base` for 16px, `t.text.sm` for
14px, `t.text.xxl` for 24px, `t.text.xl` for 20px, and `t.rounded.sm` for the
expand button's 5px. The three sizes with no token — 26px, 36px, 15px — stay
as literals.

**`morePolymer.js` drift from its analog (part of the HIGH).**
`line-height: 1.6` on the card title and description is now `160%`, which is
what `toolkit.js:186` and `:199` write.

**Rail icon shrank to 26px below 640px (LOW).** The design reference shrinks
only the tile at that width (`Contact.dc.html:63`) and holds the icon at
`size="32"` (line 89); the README says nothing. Dropped the svg media step.
Measured at 375: 44px tile, 32px icon.

## Rejected

- **"Reuse `toolkit.js`, don't rebuild it" for the More about Polymer
  section (HIGH).** The README says that at line 168, then specifies Section 3
  in terms that contradict `toolkit.js` at every measurement: `padding: 0 64px
  96px; max-width: 1214px` where toolkit wraps in `<Container>` and pads with
  `spacing[12]/[16]/[20]`; a left-aligned h2 at 26px stepping to `t.text.xxxl`
  where toolkit runs 1.75/2/2.25rem; `repeat(auto-fit, minmax(280px, 1fr))`
  where toolkit is flex-column to flex-row at `t.mq[56]`; and no description
  beneath. Reusing it means adding headline, cards, padding and heading-size
  props to a shipped homepage component so it can render values it currently
  contradicts. That is an edit to the homepage, and the reviewer named the
  same mitigation. The three divergences that were not README-mandated
  (`line-height`, hex case) are fixed above.
- **The gutter ramp reaching 64px at `t.mq[64]` rather than Container's
  `t.mq[72]` (LOW).** The README's body-section table gives `80px 64px 96px`
  at `t.mq[64]` outright, and its cards table gives `0 64px 96px` at the same
  step. The reviewer's own note calls it a design call rather than a defect.
  Changing it would contradict a table the handoff marks final.
- **Two em-dashes in the copy (LOW).** `Thanks — we've got it` and `Take all
  the room you need — this is the same field, just bigger.` are the README's
  final copy at its lines 347 and 360-361, and em-dashes already ship in the
  copy of `navigation.js`, `home/integrations.js` and `jobBoard/intro.js`. The
  reviewer recommended no change.
- **Contact routes stacking at `t.mq[64]` (MED).** The README's responsive
  section says "side by side at every width"; its section-by-section text says
  `gap: 28px` between them, which is the value only the stacked case uses. The
  design reference settles it: `#routes` is `flex-direction: column; gap: 28px`
  at desktop and flips to `row; gap: 32px` under `@media (max-width:1024px)`
  (`Contact.dc.html:104` and `:46-47`). Side by side at desktop puts each route
  in about 154px of a 340px rail, leaving the description ~94px — the exact
  failure the README describes at its line 282 for phones. Built to the
  reference; measured at 375, routes are row/20px with the icon above the text,
  and at 896 row/32px with the icon beside it.
- **h1 missing `letter-spacing: -0.01em` (LOW).** The README specifies it at
  line 62 and, at lines 220-223, mandates reusing `web/components/header.js`,
  whose h1 block never sets it. Adding it changes the h1 on every page of the
  site, which is outside this PR.
- **Field error text at 12px above 480px (LOW).** The README says `t.text.sm`
  at its line 327, but the handoff's own `ported/FormLabel.js:88-90` ships the
  `${t.mq[30]} { ${t.text.xs} }` step on the error, and
  PORTING-FORM-COMPONENTS gap 2 says of that pair "Both halves must ship. Do
  not flatten". The error sits on the label row; making it 14px while the
  label beside it is 12px would look wrong.
- **react-select inert without JavaScript (LOW).** Real, and unfixable within
  the spec: PORTING section 3 says "Do not rebuild the dropdown as a native
  `<select>`", and react-select renders an interactive control only after
  hydration. The no-JS submit still completes because `api/contact.js` treats
  `reason` as optional; the email reads `Topic: (not provided)`. Left as is.

## Form re-test

Served the built worktree on `localhost:3197`.

- Empty POST, form-encoded: 303 to `/contact#invalid`; the `:target` rule
  fires and only the `invalid` banner has `display: block`.
- Honeypot filled: 303 to `/contact#sent`, no send attempted.
- `Accept: application/json` with bad input: 400 `{"error":"invalid"}`.
- GET: 405 `{"error":"method_not_allowed"}`.
- Empty submit with JS: no navigation, four errors at once, select border
  `rgb(239, 68, 68)`.
- Expand modal: opens, syncs the value both ways, closes on Escape.
- Topic dropdown: five options at 32px / 14px, menu `1px solid rgb(163, 163,
  163)`, `z-index: 20`; selecting "Get support" serialises `reason=support`.
- Valid submit: posts
  `name=...&email=...&company=...&reason=support&message=...&website=` and the
  card is replaced by the success screen — 24px heading, `#4D4D4D` body with
  the address in black, "Get started free" and "Send another message". "Send
  another message" empties every field and restores the placeholder.
- Console clean apart from one expected 500 from `/api/contact`.

**`POSTMARK_SERVER_TOKEN` is not in `web/.env.local`.** A real submit reaches
`api/contact.js:33` and logs "POSTMARK_SERVER_TOKEN is not set; message not
sent", returning 500, and the page shows the "failed" banner with the typed
values intact — that branch is verified. The success screen was exercised by
stubbing the fetch response in the browser. No mail can be sent from this
machine until the token is added, and nothing about it was written to any
file.
