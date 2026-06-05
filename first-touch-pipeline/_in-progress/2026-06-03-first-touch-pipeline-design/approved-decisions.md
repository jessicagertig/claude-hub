# First-Touch Pipeline — Approved Decisions

Design brainstorm started 2026-06-03. This file is the authoritative record of confirmed decisions. The spec is assembled only from entries here.

## Reference-library record fields

Each extracted first-touch email becomes one record with exactly these ten fields:

- `recipient_email` — the To: address
- `recipient_name` — the name in the "Hello [Name]" greeting
- `company_name` — the recipient's company
- `company_domain` — the company's web domain
- `date_sent` — the date the email was sent
- `opener_variant` — the verbatim "Thanks for ___ Polymer!" sentence, including any time tag ("last week", "a couple weeks ago"). This is the only field reliably a single sentence.
- `compliment_text` — the company-specific researched sentence(s) about the recipient/company. Variable length; extracted semantically, never by sentence position or count.
- `closer` — the low-pressure "happy to help / answer questions" line. Variable length; extracted semantically. Distinct from any discount/promo "offer."
- `sign_off` — the valediction plus the signed name on the next line, as written ("Cheers,\nJessica", "Best,\nJessica @ Polymer", "Best regards,\nJessica Gertig"). The formal grayed signature block (when present) is NOT part of this field — it is not stored as a per-record field at all; it remains only in `full_body`.
- `full_body` — the complete email body, verbatim.

Extraction method: emails are located via Gmail search; an LLM segments each into the semantic fields above.

## Reference-library storage (format + location)

The reference library is stored as JSONL (one record per line) at `first-touch-pipeline/reference-files/first_touch_library.jsonl` in the new repo. Format chosen by the agent per Jessica's instruction to use "whatever is easiest for the AI to read."

## Reference-library build (executed 2026-06-03)

Built from the `jessica@polymer.co` Sent mailbox via the claude.ai Gmail connector, searching the Sent folder for the openers "thanks for trying out / checking out / signing up for / giving / your interest in Polymer." 93 records initially written, then narrowed to 88 (see below).

Excluded from the corpus:
- Self-test sends to `jessicamgertig@gmail.com` (e.g. the duplicate "We Academy" test)
- A duplicate bounced resend to `jonathan@galloxsemi.com` (the delivered `jon@galloxsemi.com` copy is kept)
- Two inbound-first support threads that are not first-touch outreach: the `jeff@heraldapi.com` "Welcome to Polymer" thread and the Benjamin Folks "Job Skills/Tags" thread

Five records were then removed as NOT first-touch — they had `compliment_text: null` because they were account/billing/setup check-ins, not cold first-touch outreach (`gunnar@pbonadworks.com`, `tyler@parkeps.com`, `u.solarz@hedral.co`, `carlo@createwithnova.com`, `bibamasri96@gmail.com`).

Final corpus: 88 records, every one with a non-null `compliment_text`. Distribution: opener "checking out" ×77, "trying out" ×11; sign-off valediction "Cheers," ×64, "Best regards," ×15, "Best," ×6, "Regards," ×3.

## Definition of a first-touch email

A first-touch email always contains a company/recipient-specific compliment. An initial email with no compliment (a pure account/billing/setup check-in) is NOT a first-touch email and does not belong in the reference library.

## Opener-variant semantics (prospect state)

The opener phrasing encodes the prospect's account state at send time:
- "Thanks for **trying out** Polymer" — used when the prospect is on a free trial.
- "Thanks for **checking out** Polymer" — used when the prospect has signed up but has not started a free trial.

In the automated first-touch flow, the email fires at signup time, when the Stripe subscription status is `nil` (no trial started yet). Therefore the automated flow uses "checking out Polymer" by default. "Trying out" reflected the manual habit of sometimes emailing later, once a trial was active, and does not normally apply to the automated send.

## Preferred valediction

"Cheers," is the preferred valediction for first-touch emails going forward. ("Sign-off" = the valediction; it is a different thing from the signature.)

## Canonical signature (go-forward)

The signature for first-touch emails going forward is, on two lines:

```
Jessica Gertig
Polymer | polymer.co
```

Full name, company, and URL — no job title. This is the signature most recently adopted (used on the May 2026 emails). It is distinct from the `sign_off` (which is the valediction + signed first name, e.g. "Cheers,\nJessica"). The signature is a property of the go-forward email template only; it is NOT stored as a per-record library field.

Go-forward closing assembly in the generated email body:

```
[closer]

Cheers,
Jessica


Jessica Gertig
Polymer | polymer.co
```

(One blank line before the sign-off; two blank lines between the signed name and the signature block, so Gmail grays the signature after send.)

## Email body formatting

In the generated email body there must be two full blank lines above the signature block, so that Gmail renders the signature grayed out after the message is sent.

## Phase 2 — research + drafting

Phase 2 (research a prospect → draft a first-touch email) is the current focus. Prospect input is supplied manually for now; the Stripe/Polymer data-source plumbing is explicitly out of scope for now.

### Research-step input (manual)
Per prospect, the starting data is:
- email address
- organization name (as the prospect typed it)
- the prospect's name (as the prospect typed it)
- careers-page slug — available immediately; used to check whether they have published jobs. Secondary signal, mostly relevant when actually drafting.

(Account state — on a free trial vs signed up but not trialing — determines the opener variant per the opener-variant semantics above, and is supplied with the input.)

### Research-step method
- Primary goal: find the prospect's company website, understand who they are and what they do, and identify something genuinely interesting or distinctive about the company. That distinctive detail is the basis for `compliment_text`.
- Do NOT build the compliment from a "something they posted on LinkedIn" hook — it is overdone by AI and hard to source reliably.
- News search is permitted as background context, but is not the usual basis for the compliment.
- Web search is permitted to find the website and understand the company.

### Phase 2 architecture (selected: B + adversarial reviewer)
Six steps, each implementable as an agent task or API call and runnable outside this session. The FACT side (steps 1–3) and the DRAFT side (steps 4–5) are checked separately — verify handles facts (truth + currency); the adversarial reviewer handles drafts (voice). They never merge into one gate.

1. **Research** — gather raw material on the prospect's company AND the individual recipient (who they are / role), starting from the email domain.
2. **Extract** — pull out the proposed interesting things (candidate facts/items worth complimenting). Verification can only run on named candidates.
3. **Verify loop** — for each candidate, confirm it is true AND current. First-party / company-published information is the best and primary source and is trusted as-is; the test is currency (is it still true now; ideally still reflected on the current site — ~2 years old with no current-site mention is the red flag, not the fact being self-published). If a candidate is outdated, do targeted re-research on that specific item to find its current state, then verify again. Iterate the research→verify loop PER ITEM; cap at 5 loops per item, after which that item is surfaced as an issue (escalation mechanism TBD). A stale fact does NOT block the email if other candidates verify — escalate/hold only when nothing usable verifies. (The verify step must read the LIVE company site; a 403/block means "not on the current site" cannot be trusted.)
4. **Draft** — produce THREE draft options per prospect, each carrying a source link for the fact(s) it uses. Depending on how much verified material exists, the three may be different takes on the same fact or built on different facts.
5. **Adversarial reviewer** — independent critic of the DRAFTS for voice/tells: parroting the company's own marketing copy, flowery/inflated language, verdict-clichés ("forward-looking move", "a thoughtful reimagining of what X can be"), complimenting the mundane core function ("congrats on existing"), and recipient-misfit (e.g., a founder's personal story sent to a non-founder).
6. **Human review** — Jessica picks from the three sourced options.

Rationale: separating "find the true, specific thing" from "write it in Jessica's voice," with an independent critic, isolates the failure point (the compliment) so it can be inspected and tuned without touching the writer.

### Default closer
`Happy to answer any questions you might have about Polymer.` is the default closer. (The 2026 phrasing "If you have any questions or need help getting set up, I'm here. Always happy to help!" was aimed at a specific setup-help situation and is NOT the default.)

### Draft-step grounding — the library IS the spec
The drafter is NOT governed by a hand-written rule list. The entire point of the reference library is that it gets used: on every run the drafter receives a MINIMUM of 20 real examples from the library as in-context few-shot material and learns voice, length, specificity, and restraint from Jessica's actual emails — not from invented constraints. Over-constraining the drafter with rules produces generic, worse output.

The adversarial reviewer stays an independent per-draft critic that flags weak / untrue / unsafe compliments. Its critiques drive case-by-case revision and the choice of which examples to feed; they are NOT distilled into static drafting rules that handcuff the writer.
