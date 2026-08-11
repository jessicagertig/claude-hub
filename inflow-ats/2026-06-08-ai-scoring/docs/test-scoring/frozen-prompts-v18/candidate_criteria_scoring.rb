# frozen_string_literal: true

module AiJobApplicationAction
  module Scoring
    module Prompts
      class CandidateCriteriaScoring
        SYSTEM_PROMPT = <<~PROMPT.freeze
          You are an expert recruiter assistant. You will receive a list of job criteria and a candidate's resume text.

          For each criterion, determine whether the candidate's resume provides evidence that they meet it.

          For each criterion, assign one of:
          - full_match: the resume demonstrates this criterion.
          - partial_match: the resume shows related but not direct evidence.
          - not_found: the resume contains no relevant evidence.

          When a criterion describes an ability, the candidate does not need to have done it in the exact same context. If they have the underlying technology, tooling, and methodology, that is a full_match.

          Being multilingual is not evidence of strong communication skills. Communication skills refer to the ability to convey ideas effectively in professional settings, not language fluency.

          When a criterion names a specific tool or technology without allowing alternatives (e.g., no "or similar", "such as", "like"), only score full_match or not_found. Do not score partial_match for a different tool.

          For criteria about years of experience in a specific domain:
          - full_match: the candidate has experience in that domain.
          - partial_match: the candidate has experience in a different domain but with a significant number of duties related to that domain.

          For each criterion, return:
          - criterion_text: the criterion text (copied from input)
          - tier: the criterion tier (copied from input)
          - score: full_match, partial_match, or not_found
          - reasoning: explain what evidence you found or did not find, citing specific examples from the resume.
        PROMPT

        JSON_SCHEMA = {
          type: 'json_schema',
          json_schema: {
            name: 'candidate_criteria_scoring',
            strict: true,
            schema: {
              type: 'object',
              properties: {
                scores: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      criterion_text: { type: 'string' },
                      tier: {
                        type: 'string',
                        enum: %w[tier_1 tier_2 tier_3]
                      },
                      score: {
                        type: 'string',
                        enum: %w[full_match partial_match not_found]
                      },
                      reasoning: { type: 'string' }
                    },
                    required: %w[criterion_text tier score reasoning],
                    additionalProperties: false
                  }
                }
              },
              required: %w[scores],
              additionalProperties: false
            }
          }
        }.freeze

        MODEL = 'gpt-4o-mini'

        def self.messages(criteria:, resume_text:)
          criteria_text = criteria.map.with_index do |c, i|
            "#{i + 1}. [#{c['tier']}] #{c['text']}"
          end.join("\n")

          user_content = "## Criteria\n\n#{criteria_text}\n\n## Resume\n\n#{resume_text}"

          [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: user_content }
          ]
        end

        def self.response_format
          JSON_SCHEMA
        end

        def self.model
          MODEL
        end
      end
    end
  end
end
