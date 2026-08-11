# Rough Outline (non-authoritative reference)

1. **Job criteria extraction** — Call 1 (gpt-4.1-mini sections) + Call 2 (gpt-4o criteria) + code heading override. Stored per job.
2. **Candidate scoring** — Gemini flash scores resume against stored criteria. Possibly 5-run median.
3. **Display sentence generation** — Gemini flash generates natural language per criterion.
4. **Summary integration** — scoring results feed into summary comparison call.
5. **Data model** — where criteria and scores are stored.
6. **Serialization** — scoring data exposed to frontend via API.
7. **Job lifecycle triggering** — when criteria extraction fires, diff check on updates, published state.
8. **Candidate lifecycle triggering** — when scoring fires relative to summary generation, orchestration between scoring and summary calls.
