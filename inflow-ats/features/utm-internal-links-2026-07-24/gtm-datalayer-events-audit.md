# GTM dataLayer events — inflow-ats

Source repo: `/Users/jessica/wrk/wrk-corp/inflow-ats`, branch `attribution-work-qa`. Verified 2026-07-24.

## Container

- **GTM ID:** `GTM-N6H844WJ`
- **Loaded at:** `app/views/layouts/application.html.erb:32-36`, wrapped in `<% unless Rails.env.test? %>`
- **noscript fallback:** `app/views/layouts/application.html.erb:120`
- `window.dataLayer = window.dataLayer || []` is initialized at `application.html.erb:28`, deliberately **outside** the test-env guard, so Cypress runs do not throw on pushes (comment at lines 25-26 states this)
- **Type declaration:** `app/javascript/global.d.ts:16` — `dataLayer: any[]`
- The ATS app is the only surface with a GTM container. The job board uses `gtag()` against GA properties instead (`app/views/layouts/job_board_application.html.erb:33-39` hardcoded `UA-129130323-4`; `app/views/job_board/jobs/index.html.erb:42-46` and `show.html.erb:53-57` per-org `settings["google_analytics_tracking_id"]`). Those are GA config calls, not custom events.

There are exactly **4** `window.dataLayer.push` calls in the codebase, carrying **3** distinct event names.

---

## 1. `hirePlanPurchase` — billing settings page

**Location:** `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBilling.tsx:81`

**Trigger:** mount-only `React.useEffect(..., [])`. **Not** a callback. It parses `props.location.search` with `queryString.parse` and fires if the URL carries the right params.

**Condition:** `checkout === "success" && session_id != undefined`

**Payload:**
```js
{
  event: "hirePlanPurchase",
  transactionId: Date.now().toString(),
  transactionValue: "119",
  userData: { email: currentUser.email },
}
```

**After the push:** `queryClient.invalidateQueries(["stripeCustomer"])` and `queryClient.invalidateQueries(["stripeCustomerSubscription"])`.

**How the user gets here:** Stripe redirects to `/hire/settings/billing`, which is the `successUrl` set at `AccountBillingPlansFreeTrial.tsx:127` and `AccountBillingPlansUnsubscribed.tsx:154`.

**Repeat firing:** yes. The gate is the URL, and the effect runs on every mount, so a refresh, a back-button return, or a bookmarked/shared URL re-fires the event. `transactionId` is a timestamp, so each re-fire looks like a distinct transaction to GTM.

---

## 2. `hirePlanPurchase` — job publish / free trial return

**Location:** `app/javascript/ats/src/views/jobApplications/JobStripeCheckoutRedirectHandler.tsx:42`

**Trigger:** mount-only `React.useEffect(..., [])` (lines 27-62). **Not** a callback. Same query-param gate as #1.

**Condition:** `checkout === "success" && session_id != undefined`

**Payload:** byte-identical to #1.
```js
{
  event: "hirePlanPurchase",
  transactionId: Date.now().toString(),
  transactionValue: "119",
  userData: { email: currentUser.email },
}
```

**Ordering:** the push is at line 42. `syncWithStripe` is not called until line 52, and the push is **not** inside its `onSuccess` (line 53) — that callback only sets the redirect URL and publishes the job. So the event fires before the app asks the server to confirm anything with Stripe.

**How the user gets here — the only live path:**
1. `JobSetupContainer.tsx:136` or `JobListItem.tsx:60` opens `StartFreeTrialModal`
2. `StartFreeTrialModal.tsx:61-66` sets `successUrl` and `cancelUrl` to `/jobs/${jobId}/stripe_checkout_redirect_handler` — **only when `jobId` is present**, otherwise `location.pathname`
3. `useBilling.ts:28` posts to the server
4. `app/controllers/api/v1/billing_controller.rb:75-76` builds the absolute Stripe URLs
5. Stripe returns the user to `/jobs/:jobId/stripe_checkout_redirect_handler`, routed at `JobContainer.tsx:341-347`

`AccountTeam.tsx:241,411` also opens `StartFreeTrialModal` but passes no `jobId`, so it returns to its own pathname and never reaches this handler. `SubscriptionRequiredModalNew.tsx:78` and `SubscriptionRequiredModalNewLegacy.tsx:76` set the same `successUrl` but both components are dead — neither is imported anywhere in `app/javascript`.

**So this event fires on a free-trial start, not a purchase.** No charge has occurred at this point; Stripe has a card on file and a trialing subscription. The event name and `transactionValue: "119"` both describe a completed purchase.

**Cancel is handled correctly.** `billing_controller.rb:75-76`:
```ruby
success_url: "...?checkout=success&session_id={CHECKOUT_SESSION_ID}..."
cancel_url:  "...?checkout=cancel..."
```
The cancel URL carries no `session_id`, so an abandoned checkout landing on the same route fails the gate and does not fire.

**Repeat firing:** yes, same reason as #1.

**Unused identifier:** Stripe substitutes the real checkout session id into `session_id`, and line 28 already parses it — but `transactionId` uses `Date.now().toString()` instead.

---

## 3. `newOrganization` — organization creation

**Location:** `app/javascript/ats/src/views/sessions/NewOrganization.tsx:33`

**Trigger:** a genuine server-success callback. Full chain:

`OrganizationForm.tsx:46` `handleSubmit`
→ `:49` `const [isValid, validationErrors] = await validateNewOrganization({ name })`
→ `:51` `if (isValid)`
→ `:71` `createOrganization(...)`
→ `:74` `onSuccess: (data) =>`
→ `:77` `onComplete(data)`
→ `NewOrganization.tsx:27` `onComplete` → `:33` the push

So it is past both client-side validation and a successful server response. The organization exists when this fires. On the `else` branch (`OrganizationForm.tsx:85`) it calls `setErrors(validationErrors)` and nothing is pushed.

**Payload:**
```js
{
  event: "newOrganization",
  transactionId: Date.now().toString(),
  transactionValue: "5",
  userData: { email: currentUser.email },
}
```

**After the push:** `queryClient.clear()`, then `props.history.push("/jobs")`.

**Repeat firing:** no. It requires a fresh successful mutation each time.

---

## 4. `ctaClick` — create new job button

**Location:** `app/javascript/ats/src/views/jobs/JobList.tsx:175`

**Trigger:** plain click handler `handleClickCreateNewJob` (line 174). Fires immediately on click, after `e.preventDefault()` / `e.stopPropagation()`.

**Condition:** none. Every click fires it.

**Payload:**
```js
{
  event: "ctaClick",
  ctaLocation: "Job List View",
  ctaLabel: "Create new job",
  transactionId: Date.now().toString(),
  transactionValue: "0",
  userData: { email: currentUser.email },
}
```

**After the push:** `trackEvent("create_new_job_clicked")` (PostHog), then `openModal(<NewJobCenterModal />)` at line 186.

No job exists at this point — it is an intent event, which matches the name. `transactionValue` is `"0"`.

---

## Summary table

| Event | File:line | Trigger | Gated on | Re-fires on reload |
|---|---|---|---|---|
| `hirePlanPurchase` | `AccountBilling.tsx:81` | mount `useEffect`, URL params | `checkout === "success" && session_id != undefined` | Yes |
| `hirePlanPurchase` | `JobStripeCheckoutRedirectHandler.tsx:42` | mount `useEffect`, URL params, before `syncWithStripe` | same | Yes |
| `newOrganization` | `NewOrganization.tsx:33` | mutation `onSuccess`, after validation | successful `createOrganization` | No |
| `ctaClick` | `JobList.tsx:175` | click handler, before modal opens | nothing | N/A |

Common to all four payloads: `transactionId` is `Date.now().toString()` rather than any real transaction or session identifier, and `userData.email` comes from `currentUser.email` via `useCurrentSession`.
