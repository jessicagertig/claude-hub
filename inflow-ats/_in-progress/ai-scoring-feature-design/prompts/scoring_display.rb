# frozen_string_literal: true

module AiJobApplicationAction
  module Scoring
    module Prompts
      class ScoringDisplay
        SYSTEM_PROMPT = <<~PROMPT.freeze
          You will receive a list of job criteria with scoring results for a candidate. Each criterion has a score (full_match, partial_match, or not_found) and a reasoning explanation.

          For each criterion, generate:
          - summary: a single sentence that references what the criterion is about, then gives the evidence from the candidate's background. Write like a recruiter talking to a colleague. Vary the sentence structure. Do not use em dashes. Do not start every sentence the same way.

          Each summary must include both:
          1. A reference to what the criterion asks for
          2. The specific evidence from the candidate's background

          Examples:
          - "Evidence of strong Go experience shown through building high-performance backend systems at NTT Data and Citi Group over 7 years"
          - "Demonstrates strong understanding of Kubernetes based on five certifications including CKA and CKS, and hands-on management of multi-region clusters at Civo"
          - "While the candidate has no Terraform experience specifically, they have strong Ansible experience for infrastructure automation"
          - "No evidence of cross-functional work with product or UX teams found in the candidate's experience"
        PROMPT

        JSON_SCHEMA = {
          type: 'json_schema',
          json_schema: {
            name: 'scoring_display',
            strict: true,
            schema: {
              type: 'object',
              properties: {
                criteria: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      criterion_text: { type: 'string' },
                      score: {
                        type: 'string',
                        enum: %w[full_match partial_match not_found]
                      },
                      summary: { type: 'string' }
                    },
                    required: %w[criterion_text score summary],
                    additionalProperties: false
                  }
                }
              },
              required: %w[criteria],
              additionalProperties: false
            }
          }
        }.freeze

        def self.messages(scoring_results:)
          input = scoring_results.map do |s|
            "- [#{s['score']}] #{s['criterion_text']}\n  Reasoning: #{s['reasoning']}"
          end.join("\n\n")

          [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: "Generate user-facing labels and evidence for these scoring results:\n\n#{input}" }
          ]
        end

        def self.response_format
          JSON_SCHEMA
        end
      end
    end
  end
end
