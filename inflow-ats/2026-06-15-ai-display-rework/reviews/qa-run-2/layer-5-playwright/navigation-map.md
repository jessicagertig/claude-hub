# Navigation Map for AI Display Rework

## Login
1. Navigate to http://app.lvh.me:5007/auth
2. Fill email input with rezu.may@wrkhq.com
3. Click "Continue with email"
4. Wait for dev workaround div with magic link
5. Extract and navigate to the magic link href
6. Wait for redirect to /jobs (jobs list)

## Feature paths

### Path 1: Candidate overview tab (shows PlatoOverviewCallout or PlatoGeneratedReviewCallout)
1. From jobs list, click a job title
2. Job page opens with candidates view (Inbox stage selected by default)
3. First candidate auto-selects
4. Overview tab is the default — column 4 shows the overview feed
5. Look for the Plato callout in the activities section (inside FeatureFlipper for AI_APPLICANT_SUMMARY)

### Path 2: Plato tab (shows PlatoTab with PlatoLoadingState, PlatoTabEmptyState, or PlatoSummary)
1. Follow Path 1 to reach a candidate
2. Click "AI" or "Plato" tab in the candidate header tabs (column 3)
3. The Plato tab content renders in column 4

### Path 3: Candidate without resume (noResume state)
1. From jobs list, click a job
2. Select a candidate who has no resume
3. Click the Plato/AI tab
4. Should show "Plato needs a resume" with "Go to resume tab" CTA

### Path 4: Generate a review (if credits available)
1. Follow Path 2 to reach the Plato tab for a candidate with a resume
2. If the "Generate" or "ready" state is shown, click the generate button
3. Should trigger summary generation and show PlatoLoadingState
