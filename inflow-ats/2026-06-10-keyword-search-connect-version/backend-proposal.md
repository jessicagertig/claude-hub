# Backend Proposal: Candidate-Aggregated Resume Keyword Search

## Current State (Spike)

The `poly-672-resume-keyword-search-connect` branch has a working pg_search + tsvector foundation:

- `TextractResult` model with `textsearch_vector` tsvector column, GIN index, and DB trigger that auto-populates from `textract_job_result_text` using the `simple` dictionary
- `search_resume_by_keyword` scope using pg_search with `ts_headline` highlights, prefix matching, ranked results
- Textract indexing pipeline: `SubmitResumeToTextractJob` -> AWS Textract -> `GetResumeTextFromTextractJob` -> extracts text -> DB trigger populates tsvector
- Backfill data migration for existing rows
- Access control scoping through `current_user.searchable_job_applications`
- `ResumeSearchResultSerializer` returning rank, highlighted snippet, candidate/job info

The spike returns **one result per job application** (per `TextractResult` row), capped at 15 rows with no pagination. The search fires per-keystroke with no debounce.

## Proposed Changes

### 1. Candidate-aggregated results

Group search results by candidate. Each candidate appears once, ranked by their best-matching application. Nested within each candidate: all matching applications with individual snippets and ranks, ordered by rank.

A candidate with one strong match outranks a candidate with multiple mediocre matches.

### 2. Submit-based search (not per-keystroke)

Search fires on form submit (enter key / search button), not on every keystroke. One query per search action. This makes the Ruby grouping approach viable without performance concerns.

### 3. Pagination via `render_paginated`

Use the existing `render_paginated` pattern (Kaminari) instead of a hardcoded limit of 15. Workflow:

1. Query `TextractResult` via `search_resume_by_keyword` (GIN-indexed, fast)
2. Group results by `candidate_id` in Ruby
3. Sort groups by best `pg_search_rank` DESC
4. Paginate with `Kaminari.paginate_array`
5. Render with `render_paginated` using a new serializer

Result set is bounded by the org's total resumes with Textract results that match the term. GIN scan is fast; Ruby grouping on that result set is cheap.

SQL-level grouping is a future optimization if performance becomes a problem in practice.

### 4. New serializer: `CandidateSearchResultSerializer`

Wraps one candidate with nested application matches.

**Top level (per candidate):**
- `id` (candidate_id)
- `full_name`
- `email`
- `job_applications_count`
- `best_rank`

**Nested `matches[]` (per application):**
- `job_application_id`
- `job_id`
- `job_title`
- `pg_search_rank`
- `pg_search_highlight`

### 5. Response shape

```json
{
  "items": [
    {
      "id": 42,
      "full_name": "Jane Smith",
      "email": "jane@example.com",
      "job_applications_count": 3,
      "best_rank": 0.85,
      "matches": [
        {
          "job_application_id": 123,
          "job_id": 456,
          "job_title": "Senior Engineer",
          "pg_search_rank": 0.85,
          "pg_search_highlight": "...worked with <span class=\"highlight\">Python</span>..."
        },
        {
          "job_application_id": 789,
          "job_id": 101,
          "job_title": "Tech Lead",
          "pg_search_rank": 0.62,
          "pg_search_highlight": "...experience in <span class=\"highlight\">Python</span> and Go..."
        }
      ]
    }
  ],
  "meta": {
    "total": 5,
    "is_last": false,
    "is_first": true,
    "page": 1,
    "next_page": 2,
    "count": 47
  }
}
```

## What stays the same

- `TextractResult` model, `search_resume_by_keyword` scope, pg_search config
- tsvector column, GIN index, DB trigger
- Textract indexing pipeline (jobs + services)
- Flipper gate on `TEXTRACT_RESUME_PROCESSING` for indexing
- Access control scoping via `current_user.searchable_job_applications`
- Route path: `POST /api/v1/resume_keyword_search`

## What changes

| File | Change |
|---|---|
| `ConnectMembersSearchController#resume_search` | Group by candidate, paginate with `Kaminari.paginate_array`, use `render_paginated` |
| `CandidateSearchResultSerializer` (new) | Wraps candidate with nested application matches |
| `ResumeSearchResultSerializer` | May keep for nested match serialization or inline into new serializer |

## No changes to

- Migrations
- Models
- Indexing pipeline
- Routes
