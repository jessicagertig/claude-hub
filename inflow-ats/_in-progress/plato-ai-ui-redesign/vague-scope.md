# Plato AI UI Redesign — Vague Scope (non-authoritative reference)

Two specs produced from one brainstorm session, implemented separately.

## Spec 1: Admin Settings Page

Redesign the admin settings area at `/hire/settings/plato-ai/`. Two opposite approaches to explore: (A) 3 distinct tabs with better naming and content that justifies each tab's existence, (B) one combined page with everything organized into sections. Both approaches address: AI settings (auto-generate toggle, notification preferences), billing (subscription, top-up, balance display), and usage. Additionally, split the single `hiringTeamAiCreditsControlEnabled` boolean into 3 granular permission controls. Also fix the ugly billing→AI link in `AccountBilling.tsx`. Scope excludes the candidate view AI Summary tab — that's spec 2.

## Spec 2: Candidate AI Summary Tab

Move AI summary out of the Overview activity feed into a dedicated tab in column 3 of the candidate view. Replace the current summary display in the Overview tab with a CTA linking to the new tab. The summary has rich structured data that's currently underutilized — a dedicated tab gives space to display it properly and make it valuable. Design an attractive presentation that earns the tab. Tab naming is open (brainstorm needed). Handle all status states (processing, generating, failed, succeeded, stale). Include CTAs in various places beyond just Overview. Include non-admin credit balance visibility (design TBD). Stay within Polymer's existing styling patterns.
