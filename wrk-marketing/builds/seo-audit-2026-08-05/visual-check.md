# What to look at, by PR

Only things a build cannot prove. Where a change touches every page, one page is enough.

#56 and #57 are merged. Six PRs are open, all mergeable.

## Merge order

**#58 → #51 → #52 → #53 → #54 → #55**

#58 is one line and independent, so it can go any time. The rest are a chain: each branch still carries the ones below it, so their diffs collapse to their own work as the earlier ones land.

---

## #58 — restore the `/blog/page` redirect

- [ ] **`/blog/page`** should land on `/blog`, not 404.
- [ ] **`/blog/page/1`** should still land on `/blog`.
- [ ] **`/blog/page/7`** should still 404.

## #51 — images, links, headers

- [ ] **Homepage, click a brand logo.** They were rebuilt as a styled component and `passHref` is what carries the URL. Makelog should not be clickable. Every other one should be, including CALA, which redirects to Mercer.
- [ ] **Homepage, the Bodeswell quote.** Should no longer be a link.
- [ ] **Homepage hero.** A `sizes` attribute went onto five image call sites. A wrong value looks blurry rather than broken.

## #52

Nothing. It only removes a markdown file from the repo.

## #53 — FAQ

- [ ] **`/faq`.** New page.
- [ ] **`/blog/behavioral-interview-scoring-matrix`, download the scorecard.** It is a hosted file now, not a Google Sheets link. It 404s until this branch deploys.

## #54 — contact

- [ ] **`/contact`.** New page, and the whole design is new since you last looked.
- [ ] **Submit the form.** It will report a send failure until `POSTMARK_SERVER_TOKEN` is set in Vercel and `contact@polymer.co` is verified in Postmark.
- [ ] **Submit it empty.** Each bad field gets a red border and a message on its label row, right-aligned. Editing a field clears only that field's error.
- [ ] **The topic dropdown.** First use of react-select on the site. Five options, and the value reaches the email as a `Topic:` line.
- [ ] **The expand button on the message field.** Opens the message in a modal; typing there reaches the inline field; Esc closes it and keeps the value.
- [ ] **The two blocks in the left column**, at three widths: stacked under 640px, side by side 640 to 1023, stacked again from 1024 up.
- [ ] **The submit button.** First `<button>` on the site rather than a span or a link, so `button-new.js` gained `font-family: inherit` and `border: none`. Check every other button on the site still looks right, one page is enough.
- [ ] **`/pricing`, the enterprise "Contact Us" button.** Now goes to `/contact` instead of opening a mail client.

## #55 — small business

- [ ] **`/applicant-tracking-for-small-business`.** New page.
- [ ] **Footer.** New link under Industries.
