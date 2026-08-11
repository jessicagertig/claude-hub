# frozen_string_literal: true

module AiJobApplicationAction
  module Scoring
    module Prompts
      class CriteriaDecompositionJudge
        SYSTEM_PROMPT = <<~PROMPT.freeze
          You are reviewing another model's work. It extracted a list of job criteria from a job description. Your job is to find compounds it missed.

          Before producing any output, go through the criteria one at a time and reason about whether each is a single requirement or a compound. Only after you have reasoned through all of them, produce the output.

          A criterion needs decomposition when it contains multiple distinct requirements that a candidate could meet independently. For example, a criterion about "Kubernetes and Terraform" contains two different technologies — a candidate might know one but not the other.

          Do NOT flag for decomposition:
          - "or" constructions — those are one criterion with alternatives
          - Parenthetical examples — "(Word, Excel, PowerPoint)" are examples of one suite
          - Tool lists after "such as" or "including" when they are examples of one category
          - Single concepts described in detail

          For each criterion, return:
          - original: the criterion exactly as received
          - needs_decomposition: true or false
          - reasoning: why you made this decision
        PROMPT

        JSON_SCHEMA = {
          type: 'json_schema',
          json_schema: {
            name: 'criteria_decomposition_judge',
            strict: true,
            schema: {
              type: 'object',
              properties: {
                criteria: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      original: {
                        type: 'object',
                        properties: {
                          text: { type: 'string' },
                          tier: { type: 'string', enum: %w[tier_1 tier_2 tier_3] },
                          tier_reasoning: { type: 'string' },
                          binary: { type: 'boolean' },
                          contains_title_technology: { type: 'boolean' },
                          source_text: { type: 'string' }
                        },
                        required: %w[text tier tier_reasoning binary contains_title_technology source_text],
                        additionalProperties: false
                      },
                      needs_decomposition: { type: 'boolean' },
                      reasoning: { type: 'string' }
                    },
                    required: %w[original needs_decomposition reasoning],
                    additionalProperties: false
                  }
                }
              },
              required: %w[criteria],
              additionalProperties: false
            }
          }
        }.freeze

        MODEL = 'gemini-3.1-flash-lite'

        def self.messages(criteria:)
          [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: "Review these criteria and decide which need decomposition:\n\n#{JSON.pretty_generate(criteria)}" }
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
