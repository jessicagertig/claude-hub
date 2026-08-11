# posthog-events-and-identity — Round 5

Full-spec re-read (§1.2, §4.8, §5.6–5.9, §10, §11 Risks 1/6/7). The §5.6 mechanism text, Risk 7 disclosure, and §10 scoping read coherently together: "fires only on the email_confirmed=true landing" (mechanism) + "that landing renders only for signed-out clicks" (Risk 7) + "coverage fix is a new decision" (§10). Effect-deps shape (`[emailConfirmed]` with stable `props.location` read inside) matches the file's existing lint posture (the current mount effect also omits `props.location`). No new observations.

## Findings

- None.

## Amendments Applied

- None.
