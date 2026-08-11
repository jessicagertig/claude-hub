# Handoff: cross-subdomain user cookie

**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.cross-subdomain-user-cookie`
**Branch:** `cross-subdomain-user-cookie` (base `develop`, created via `wt switch --create`)

## Goal

Set a cookie on signed-in users that is readable from both `app.polymer.co` and `www.polymer.co`, containing the user ID, so the marketing site can identify existing customers and exclude them from retargeting.

Scope is setting the cookie only, plus verifying where it does and doesn't travel. No marketing-site code.

## Decisions already made — do not relitigate

- **Set it on authenticated app load, not on sign-in.** Remember-me tokens last two years, so a user may not sign in again for two years. Hooking sign-in would leave most existing users without the cookie for that long. Setting it per authenticated request also makes it self-healing if someone clears cookies or the name/domain later changes.
- **Do not clear it on sign-out.** Shared machines are rare and almost always mean two people at the same company, who should both be excluded anyway — so a stale ID still produces the correct outcome. Clearing it would create the worse failure: paying to retarget an existing customer who happened to sign out.
- **The population is hire users.** Ignore connect entirely — no connect users exist, and that app direction was abandoned. Account exists so it can serve both, and does, but it is not the focus here.

## Local facts you cannot derive from the code alone

- PostHog's `distinct_id` in this app is `user.id.to_s`. Both `Posthog::Track` and `Posthog::Identify` set it that way. That is why the user ID is the correct cookie value — it already matches every person record PostHog holds, so nothing else needs to be carried.
- **There is no cookie-setting precedent in this codebase.** The entire app writes exactly two cookies: `cookies[:account_referrer]` at `app/controllers/account/pages_controller.rb:5` and `cookies[:connect_referrer]` at `app/controllers/connect/pages_controller.rb:7`. Both are bare — no domain, no expiry, no flags. Do not pattern-match off them; there is no house form for this.
- **There is no cookie-domain configuration anywhere to inherit** — nothing in a session store initializer or the environment files. Development runs on `lvh.me:5007`, so whatever derives the domain has to produce `.lvh.me` locally and `.polymer.co` in production, and all of it is new code.
- **`httponly: false` is required.** The cookie exists to be read by JavaScript on the marketing domain. Defaulting to httpOnly, which is the safe habit elsewhere, makes it invisible to the only thing that needs it.

## Verification

A cookie is only ever sent to hosts matching its domain attribute, so leakage to unrelated sites is impossible by construction. The two real failure directions are both inside `polymer.co`: setting it without the leading dot so it never reaches `www`, or setting it correctly and forgetting what else runs under `*.polymer.co` and will therefore also receive it.

- Confirm it appears on `app.polymer.co`
- Confirm it appears on `www.polymer.co`
- Confirm the `Domain` attribute reads `.polymer.co` in devtools
- Enumerate the other hosts under that domain
