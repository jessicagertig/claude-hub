# frozen_string_literal: true

module AiJobApplicationAction
  module Scoring
    module Prompts
      class CriteriaDecomposer
        SYSTEM_PROMPT = <<~PROMPT.freeze
          You will receive job criteria that have been flagged as compounds needing decomposition. For each one, break it into separate atomic criteria.

          Each decomposed criterion must stand alone — a reader should understand what is being asked without referring back to the original. Carry context from the original into each decomposed part. When decomposing responsibilities, reframe them as abilities (e.g., "Develop X" becomes "Ability to develop X").

          Split on skills, not on verbs. "Design, build, and maintain X" is one skill, not three. "X including A, B, and C" where A, B, C are different skill areas should split into X and then A, B, C separately.

          Do NOT decompose "or" constructions — those are one criterion with alternatives.

          Examples:

          SOURCE: "Excellent written and oral communication skills in English, proficiency with word processing software such as Google Docs or Microsoft Office, and an ability to independently conceptualise and write comprehensive reports on the state of ongoing work whenever requested"
          DECOMPOSE INTO:
          1. "Excellent written and oral communication skills in English"
          2. "Proficiency with word processing software such as Google Docs or Microsoft Office"
          3. "Ability to independently conceptualise and write comprehensive reports on the state of ongoing work whenever requested"

          SOURCE: "Strong proficiency in TypeScript and Node.js; experience with Next.js and React a plus"
          DECOMPOSE INTO:
          1. "Strong proficiency in TypeScript and Node.js"
          2. "Experience with Next.js and React a plus"

          SOURCE: "Must have excellent communication skills and a good understanding of the software service solutions"
          DECOMPOSE INTO:
          1. "Must have excellent communication skills"
          2. "A good understanding of the software service solutions"

          SOURCE: "8+ years of solution-based Enterprise level selling required (Hosted Solutions, Contact Center, UCaaS, SaaS highly preferred"
          DECOMPOSE INTO:
          1. "8+ years of solution-based Enterprise level selling required"
          2. "Solution-based Enterprise level selling in Hosted Solutions, Contact Center, UCaaS, or SaaS highly preferred"

          SOURCE: "You have at least 3 years JavaScript experience, ideally with a focus on Vue/Nuxt."
          DECOMPOSE INTO:
          1. "At least 3 years JavaScript experience"
          2. "Ideally experience with Vue or Nuxt"

          SOURCE: "Lead, mentor, and coach a team of software engineers, fostering a collaborative and high-performance culture."
          DECOMPOSE INTO:
          1. "Lead, mentor, and coach a team of software engineers"
          2. "Experience fostering a collaborative and high-performance culture"

          SOURCE: "Experience with setting up and operating HPLC, GC, and LC-MS equipment, as well as analysing results from a wide variety of analytical procedures and machines"
          DECOMPOSE INTO:
          1. "Experience with setting up and operating HPLC, GC, and LC-MS equipment"
          2. "Experience analysing results from a wide variety of analytical procedures and machines"

          SOURCE: "Bachelor's degree (or equivalent) or at least five years of relevant work experience"
          DECOMPOSE INTO:
          1. "Bachelor's degree (or equivalent)"
          2. "At least five years of relevant work experience"

          SOURCE: "Develop detailed flow schematics (PFD and P&IDs), build-out safety management tools, and create start-up procedures for membrane pilot and system deployment."
          DECOMPOSE INTO:
          1. "Ability to develop detailed flow schematics (PFD and P&IDs)"
          2. "Ability to build-out safety management tools"
          3. "Ability to create start-up procedures for membrane pilot and system deployment"

          SOURCE: "Conduct regular one-on-one meetings, performance reviews, and career development sessions to support growth in technical skills such as system architecture, API development, and UI/UX design."
          DECOMPOSE INTO:
          1. "Ability to conduct regular one-on-one meetings, performance reviews, and career development sessions"
          2. "Ability to support team members' growth in technical skills such as system architecture, API development, and UI/UX design"

          SOURCE: "Familiarity with LLM-enabled tooling, including frameworks (LangChain, LlamaIndex), vector databases, caching solutions (Redis), and monitoring tools."
          DECOMPOSE INTO:
          1. "Familiarity with LLM frameworks such as LangChain or LlamaIndex"
          2. "Familiarity with vector databases for LLM tooling"
          3. "Familiarity with caching solutions for LLM tooling such as Redis"
          4. "Familiarity with monitoring tools for LLM tooling"

          Do NOT decompose:
          - "Strong knowledge of TypeScript and/or JavaScript" — one criterion with alternatives
          - "Experience with Svelte, React or Vue" — one criterion listing acceptable options
          - "Proficient in Google Workspace (Google Sheets, Google Docs, Google Slides)" — components of one suite, not separate requirements
          - "Comfortable using basic database and productivity tools including Google Suite, Office 365, Salesforce, and Monday.com (or similar project management software)" — tools listed are examples of one category, not separate requirements

          Do not split any single criterion into more than 3 parts.

          Each decomposed criterion inherits the tier, tier_reasoning, binary, contains_title_technology, and source_text from the original.
        PROMPT

        JSON_SCHEMA = {
          type: 'json_schema',
          json_schema: {
            name: 'criteria_decomposer',
            strict: true,
            schema: {
              type: 'object',
              properties: {
                results: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      original_text: { type: 'string' },
                      decomposed: {
                        type: 'array',
                        items: {
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
                        }
                      }
                    },
                    required: %w[original_text decomposed],
                    additionalProperties: false
                  }
                }
              },
              required: %w[results],
              additionalProperties: false
            }
          }
        }.freeze

        MODEL = 'gpt-4o-mini'

        def self.messages(criteria:)
          [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: "Decompose each of these criteria:\n\n#{JSON.pretty_generate(criteria)}" }
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
