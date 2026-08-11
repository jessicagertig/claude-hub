# PostHog identify — current callsites and gaps

## Where identify fires

- **Client:** `identifyUser` at `AppAuthRouter.tsx:168` — `useEffect` on authenticated `currentUser` load; keys on `user.id`; merges the anonymous browser history (incl. marketing-site pageviews via shared `*.polymer.co` cookie) into the person.
- **Server:** `PosthogIdentifyJob` (→ `Posthog::Identify`, `distinct_id = user.id`) at:
  - `registrations#create`
  - `registrations#magic_create` (new-user branch, at User row creation, pre-confirmation)
  - `sessions_controller#create`
  - `magic_links_controller#validate`
  - `auth/invites_controller` (two sites)
  - `omniauth_callbacks#google_oauth2`

## Gaps (auth/verification moments with no identify)

1. `Hire::ConfirmationsController#show` — email-confirmation click for hire signups (magic-link and `/register` password signups both land here). Success branch: `OrgOwnerUpdateJob`, redirect `/auth?email_confirmed=true`. No identify, no track event.
2. `registrations#magic_create` existing-but-unconfirmed-user branch — resends confirmation, signs in (blocked by confirmation). No identify in branch; soft gap (person already identified at row creation).

## Related facts

- No verification-success event exists anywhere in the event inventory (server `PosthogTrackJob` + frontend `trackEvent`). Closest: `user_signed_up` (fires at account creation, pre-verification), `user_logged_in`.
- Jessica's stated lean: identify at verified email, not at email entry (at `magicLink` submit the address is saved but unconfirmed).
- Marketing site (`wrk-marketing/web/lib/posthog.js`): same PostHog project, `cross_subdomain_cookie: true`; comment warns never to `identify()` by email (forks unmergeable identity). Marketing install is fresh and UNTESTED — treat cross-site merging as unverified.

## Open decision topics (queued)

- Decision 11: identify placement (no identify at email entry; whether to add `PosthogIdentifyJob` to `Hire::ConfirmationsController#show` success branch)
- Verification-success event (name, placement)
- Marketing site: utm/`internal_ref` forwarding via `appendReferral`/localStorage; CTA-click event capture
- Spec-time checklist: serializer exposure of new columns; parallel-field layer trace (rule 2)
