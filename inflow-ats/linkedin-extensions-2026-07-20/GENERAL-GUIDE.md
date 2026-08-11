# Polymer LinkedIn Extension — General Plan

## Goal
A browser extension that lets a logged-in Polymer user add a candidate to Polymer directly from a LinkedIn profile page, using the profile itself as the candidate record.

## Data acquisition
The extension runs as a content script on LinkedIn profile pages. The user, while viewing a candidate's profile, triggers the action from the extension. The extension obtains the profile as a PDF by using LinkedIn's own Save-to-PDF export rather than parsing page HTML. This keeps the extension off brittle DOM scraping and produces a stable file. Action is always user-initiated, one profile at a time, only for the profile currently being viewed. No background iteration over URLs, since the customer's own LinkedIn account is the one at risk if this behaves like a bot.

## Ingestion
The profile PDF is sent to the existing in-app endpoint that manually adds a candidate, not the public apply endpoint. The PDF occupies the same slot a resume would. No new candidate concept or schema is needed. Once ingested, the existing Textract plus structured-extraction pipeline processes it the same way it processes any resume. The coding agent should locate the real manual-add endpoint and confirm the file-handling contract rather than assume its shape.

## Authentication
Do not use an org API key. It is over-scoped, wrong on identity, and cannot be safely shipped inside an extension. Do not use a hidden service user. Do not rely on sending the Devise session cookie from the extension on cross-origin requests, since SameSite behavior makes that unreliable.

Instead, the app mints a short-lived, user-scoped token. Devise continues to authenticate the human on the Polymer domain as it already does. A content script on an actual Polymer app page reads that established session and requests a token from the backend. The token is sent as a Bearer header on the extension's requests to the candidate endpoint. On the server, the token is verified, the user is resolved from it, and existing authorization applies from that point. The coding agent should confirm how the Devise session is currently exposed to a same-origin page, and choose a token mechanism already available in the stack rather than adding new dependencies.

## Onboarding and connect flow
On install, the extension opens a Polymer app tab. The user is already logged in there or logs in normally. The content script on that page reads the session, obtains a token, and stores it in the extension. From then on the token refreshes silently in the background when it expires, with no repeated logins. The only visible UI after setup is a fallback for the logged-out case, shown inside the extension's own panel, that opens login in a normal tab.

## Guardrails
User-initiated only. One profile per action. No automated crawling. Token is short-lived and scoped so a leak is low-impact and self-expiring. Nothing org-wide or long-lived ever leaves the server.

## For the coding agent to investigate, not invent
Confirm the actual manual-add endpoint and its file input. Confirm how the current session is readable from a same-origin app page. Confirm what token or signing utilities already exist in the codebase before introducing anything. Confirm the CORS configuration needed to accept an Authorization header on that endpoint.
