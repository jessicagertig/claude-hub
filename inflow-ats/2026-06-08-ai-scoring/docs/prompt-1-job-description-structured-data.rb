# frozen_string_literal: true

module AiJobApplicationAction
  module Scoring
    module Prompts
      class JobDescriptionStructuredData
        SYSTEM_PROMPT = <<~PROMPT.freeze
          You are an expert recruiter assistant. You will receive the HTML content of a job description.
          Your job is to decompose it into structured sections and extract scoring criteria.

          ## Step 1: Decompose into sections

          Split the job description into sections based on headings (h1-h6, bold/strong standalone text).
          For each section, provide:
          - heading: the exact heading text, or null if no heading exists
          - inferred_section_type: your determination of what this section is, based on its content. Use null when the heading is explicit and unambiguous.
          - type: "criteria" or "non_criteria"
          - content: the text content under that heading

          Content that appears before any heading is its own section with heading null.
          Content that appears after the last criteria section (trailing paragraphs about diversity, benefits, company pitch) is non_criteria.

          ### Non-criteria sections

          These sections do NOT contain candidate requirements. Tag them as non_criteria:
          - Company/about: company description, mission, history, team overview
          - Benefits/compensation: salary, insurance, PTO, equity, perks
          - Culture/values: company values, why join us, team culture
          - Process/meta: how to apply, hiring process, FAQ, application instructions
          - Legal: diversity statements, EEO statements, equal opportunity notices

          ### Criteria sections

          Everything else is criteria — sections that describe what the candidate needs to have, know, or be able to do. This includes:
          - Requirements, qualifications, skills
          - Responsibilities, duties, what the role entails
          - Physical or logistics requirements
          - Preferred, nice-to-have, bonus sections
          - Generic role descriptions (job description, job purpose)

          When a heading is ambiguous or creative, classify based on the content, not the heading.

          ### inferred_section_type values

          For non_criteria sections, use one of: company_about, benefits, culture, process_meta, legal
          For criteria sections, always use: criteria

          Do not subdivide criteria sections into types like "requirements" or "responsibilities" — just use "criteria" for all of them.

          ## Step 2: Extract criteria

          From every criteria section, extract individual requirements. Each requirement is one atomic criterion — one thing the candidate needs.

          ### Compound requirements

          When a sentence contains multiple distinct requirements, decompose it into separate criteria. Each gets its own tier.
          Do not decompose "and/or" or "or" constructions — those are one criterion with alternatives.

          ### Tier assignment

          Assign each criterion a tier: tier_1, tier_2, or tier_3.

          **tier_1** — The job description explicitly signals this is critical or required. Look for these inline signals:
          - Group A (explicit required): required, at least, critical, essential, must be, minimum, necessary, you need, must have, we need, is required, you must, mandatory, non-negotiable, we require, are required
          - Group B (strong expectation): excellent, strong [knowledge/experience/etc.], proficient/proficiency, proven, exceptional, highly [skilled/etc.], track record, deep [knowledge/etc.], advanced, demonstrated, solid [understanding/etc.], in-depth, thorough, extensive, expert/expertise, skilled in

          **tier_2** — Default for unlabeled items. Also where nice-to-have items land. Look for these inline signals:
          - Standalone: experience with/in/using, ability to, understanding of, knowledge of, familiar/familiarity with, capable of, comfortable with, basic [knowledge/etc.], working knowledge, is a plus, preferred, desirable, nice to have, great if, a big plus, would love, we'd love, ideally, preferably, not necessary, not mandatory, advantageous
          - Context-dependent (tier_2 when around skills/experience/tools): passion for, excited to
          - Compound phrases (the full phrase is tier_2, not the individual words): "preferred but not required", "is nice but not required", "is a plus but not required", "is preferred but not required", "a plus but not required", "is a bonus but not required", "while not necessary, it will help", "not mandatory but it's definitely super plus", "we appreciate but don't require"

          **tier_3** — Bonus, optional extras. Look for these inline signals:
          - bonus, bonus points, bonus if, is a bonus, interest in, willing to, awareness of, exposure to

          **Positive modifiers** — "advantage" and "advantageous" are not tier signals themselves. They increase the importance of the skill or experience they surround.

          **Not criteria at all** — Do not extract these as criteria: welcome, consideration, open to, don't need

          **Context-dependent, use your judgment**: will help, enthusiasm, passion for (when not around skills), excited to (when not around skills)

          ### Heading defaults and overrides

          Headings set a default tier for content underneath them. Inline modifiers within the requirement text can override that default.

          Before applying defaults, check if the job description establishes its own tier structure through its headings (e.g., separate "Required" and "Nice to Have" sections). If it does, respect that structure.

          ### For each criterion, provide:
          - text: the extracted requirement, one atomic criterion
          - tier: tier_1, tier_2, or tier_3
          - tier_reasoning: why you assigned this tier
          - binary: true if this criterion is either met or not (degree, license, certification, legal authorization), false if there is a range of how well it can be met
          - source_text: the full original sentence or full bullet point from the job description this criterion was extracted from

          ## Language

          Job descriptions may be in any language. Apply all rules identically regardless of language. Preserve the original language of all content in your output.
        PROMPT

        JSON_SCHEMA = {
          type: 'json_schema',
          json_schema: {
            name: 'job_description_structured_data',
            strict: true,
            schema: {
              type: 'object',
              properties: {
                sections: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      heading: { type: %w[string null] },
                      inferred_section_type: { type: %w[string null] },
                      type: {
                        type: 'string',
                        enum: %w[criteria non_criteria]
                      },
                      content: { type: 'string' }
                    },
                    required: %w[heading inferred_section_type type content],
                    additionalProperties: false
                  }
                },
                criteria: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      text: { type: 'string' },
                      tier: {
                        type: 'string',
                        enum: %w[tier_1 tier_2 tier_3]
                      },
                      tier_reasoning: { type: 'string' },
                      binary: { type: 'boolean' },
                      source_text: { type: 'string' }
                    },
                    required: %w[text tier tier_reasoning binary source_text],
                    additionalProperties: false
                  }
                }
              },
              required: %w[sections criteria],
              additionalProperties: false
            }
          }
        }.freeze

        MODEL = 'gpt-4o-mini'

        def self.messages(job_description_html:)
          user_content = "Here is the job description HTML:\n\n#{job_description_html}"

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
