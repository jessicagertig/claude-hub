# frozen_string_literal: true

module AiJobApplicationAction
  module Scoring
    module Prompts
      class CriteriaExpansion
        SYSTEM_PROMPT = <<~PROMPT.freeze
          You are an expert recruiter assistant. You will receive a list of job criteria extracted from a job description.

          For each criterion, brainstorm non-obvious equivalences that a scorer might miss.

          Focus ONLY on:
          1. Product equivalences — alternate names, rebrandings, newer versions. For example, "G Suite" became "Google Workspace," and "Adobe Creative Suite" became "Adobe Creative Cloud."
          2. Certifications and formal qualifications that prove proficiency (e.g., PRINCE2 proves project management, ECDL/ICDL certifies computer literacy including specific software).
          3. Domain-specific knowledge — which tools, platforms, or systems belong to which category.

          Do NOT include cross-domain examples. If the criterion is about customer service, do not list hospitality, retail sales, IT support, or project management as matches. Stay within the criterion's own domain.

          Do NOT list obvious matches. The purpose is to catch non-obvious equivalences that would otherwise be missed.

          These examples are illustrative, not exhaustive.

          For each criterion, return:
          - criterion_text: the criterion text (copied from input)
          - brainstorm_full_match: non-exhaustive examples of non-obvious things on a resume that would demonstrate this criterion is fully met.
          - brainstorm_partial_match: non-exhaustive examples of adjacent or transferable experience that a scorer might not connect to this criterion.
        PROMPT

        JSON_SCHEMA = {
          type: 'json_schema',
          json_schema: {
            name: 'criteria_expansion',
            strict: true,
            schema: {
              type: 'object',
              properties: {
                expansions: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      criterion_text: { type: 'string' },
                      brainstorm_full_match: {
                        type: 'array',
                        items: { type: 'string' }
                      },
                      brainstorm_partial_match: {
                        type: 'array',
                        items: { type: 'string' }
                      }
                    },
                    required: %w[criterion_text brainstorm_full_match brainstorm_partial_match],
                    additionalProperties: false
                  }
                }
              },
              required: %w[expansions],
              additionalProperties: false
            }
          }
        }.freeze

        MODEL = 'gemini-3.1-flash-lite'

        def self.messages(criteria:)
          criteria_text = criteria.map.with_index do |c, i|
            "#{i + 1}. #{c['text']}"
          end.join("\n")

          user_content = "## Criteria\n\n#{criteria_text}"

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
