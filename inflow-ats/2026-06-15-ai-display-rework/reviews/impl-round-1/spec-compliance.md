# spec-compliance

## Checked against REWORK-SPEC.md

### Backend
- [x] Remove `aiJobApplicationSummary` from serializer -- done
- [x] Add `aiJobApplicationSummaryStatus` to serializer -- done
- [x] Switch `update_columns` to `update` in orchestrate.rb, score_job_application.rb, integrate_analysis.rb -- done (9 call sites total)
- [x] `before_update :broadcast_status_change` callback -- done (spec says `before_update`, implementation matches)
- [x] `BROADCAST_STATUSES` constant -- done, matches spec
- [x] Guard: `status_changed?` then `BROADCAST_STATUSES.include?(status)` -- done (spec says `saved_change_to_status?` but plan corrects to `status_changed?` for `before_update`)
- [x] Broadcast payload matches spec -- done
- [x] `ap` logging after guards -- done
- [x] `updated_at` added to status serializer -- done
- [x] `updated_at: Time.current` added to `update_summary_status_record` -- done

### Frontend
- [x] WebsocketJobChannelHandler: `ai_summary_status_change` case -- done
- [x] PlatoTab: switched data source -- done
- [x] PlatoLoadingState: new component, 4-step checklist -- done
- [x] PlatoOverviewCallout: four-state logic (current/regenerating -> null, ask, noResume) -- done
- [x] PlatoGeneratedReviewCallout: reads from status record (via parent props) -- done
- [x] PlatoTabEmptyState: all icons to "plato", DragAndDropResumeUploader removed -- done
- [x] JobApplicationActivity: switched data source -- done
- [x] Frontend types updated -- done
- [x] AiJobApplicationSummaryFeedItem deleted -- done

### Spec deviation check
1. Spec says guard uses `saved_change_to_status?` -- implementation uses `status_changed?`. This is CORRECT because the callback is `before_update` (changes not yet saved). The plan explicitly corrects this. NOT a deviation.
2. Spec section "PlatoOverviewCallout" says "Five states" in REVIEW-ANGLES.md but the spec body says "four states." The implementation has four states (ask, noResume + two null-returns). Correct per spec body.

## Findings

None.
