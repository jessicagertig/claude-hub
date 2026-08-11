# frozen_string_literal: true

module AiJobApplicationAction
  module Scoring
    module Prompts
      class JobDescriptionStructuredData
        SYSTEM_PROMPT = <<~PROMPT.freeze
          You are an expert recruiter assistant. You will receive the HTML content of a job description.
          Your job is to decompose it into structured sections.

          Split the job description into sections based on headings. Headings are typically h1-h6 tags, but equally could be short text that is the sole content of a block-level element (p, div, or li) and introduces a new topic — even if it lacks heading markup.

          It is essential that you correctly identify sub-headings. This is the foundation for a scoring system. Without correct sub-headings, the entire system breaks.

          When a section has sub-headings (short text that is the sole content of a block-level element within a section), split into separate sections. Use the sub-heading as the heading — discard the parent heading (e.g., if the parent is "About This Role" and the sub-headings are "Qualifications" and "Bonus Skills", the sections get headings "Qualifications" and "Bonus Skills"). A sub-heading can appear immediately after a section heading with no content between them. The parent heading may have no content of its own.

          Here are examples of common heading text found in job descriptions. This is not an exhaustive list. Use your judgment to identify similar headings:
          Required, Must Have, Must-Have's, Need to Have, Need-to-Have's, Minimum Qualifications, Essential, Required Experience, Required Skills, Required Experience and Skills, Preferred, Nice to Have, Nice-to-Have's, Preferred Qualifications, Desired, Bonus, Bonus Points, Plusses, Extra Credit, Optional, Qualifications, Requirements, Responsibilities, What You'll Do, What We're Looking For

          If the input starts with an h1-h6 tag, always extract its text into the heading field of the first section, even if the heading text is a greeting or welcome message.

          For each section, provide:
          - heading: the exact heading text, or null if no heading exists. When an HTML heading tag (h1-h6) contains text, always extract that text into the heading field. Do not merge heading text into the content field.
          - inferred_section_type: your determination of what this section is. Must be one of: company_about, benefits, compensation, culture, process_meta, legal, criteria. Never use "non_criteria" or any value not in this list.
          - type: "criteria" or "non_criteria"
          - content: the text content under that heading

          Content that appears before any heading is its own section with heading null.
          Content that appears after the last criteria section (trailing paragraphs about diversity, benefits, company pitch) is non_criteria.

          IMPORTANT: Every sentence AND every heading from the input must appear in the output. Do not drop, summarize, or omit any content. If you merge sections, the heading text of the absorbed section must appear either as the merged section's heading or within its content. If you are unsure where content belongs, include it in the nearest section.

          IMPORTANT: heading and inferred_section_type must never both be null. When there is no heading, you must infer the section type from its content.

          Example — content before any heading:
          heading: null
          inferred_section_type: "company_about"  <-- REQUIRED when heading is null

          Decode all HTML entities to their character equivalents in the output (e.g., &#39; becomes ', &amp; becomes &, &lt; becomes <). Do not pass HTML entities through literally.

          When a value should be null, output JSON null (without quotes), not the string "null".

          Format list items as one item per line, separated by newline characters. Do not join list items into a single sentence with period separators.

          ## Non-criteria sections

          These sections do NOT contain candidate requirements. Tag them as non_criteria:
          - Company/about: company description, mission, history, team overview
          - Benefits/compensation: salary, insurance, PTO, equity, perks, pay rates, schedule details
          - Culture/values: company values, why join us, team culture
          - Process/meta: how to apply, hiring process, FAQ, application instructions
          - Legal: diversity statements, EEO statements, equal opportunity notices

          ## Criteria sections

          Everything else is criteria — sections that describe what the candidate needs to have, know, or be able to do. This includes:
          - Requirements, qualifications, skills
          - Responsibilities, duties, what the role entails
          - Physical or logistics requirements
          - Preferred, nice-to-have, bonus sections
          - Generic role descriptions (job description, job purpose)

          A narrative paragraph describing what the role does and what skills the person needs is criteria, even if it reads like a "job overview" rather than a bullet-point requirements list. Classify based on whether the content could be used to evaluate a candidate.

          Example: if a section describes the role's required disciplines in prose form (e.g., "As a writer/producer, cinematographer, editor, sound designer, and animator, he/she will be responsible for creating incredible video content"), classify it as criteria. Role description prose that names specific skills the candidate must have IS criteria.

          When a heading is ambiguous or creative, classify based on the content, not the heading.

          ## Mixed sections

          If a section contains both criteria and non_criteria content (e.g., a "Pay & Schedule" section that includes compensation details AND a mandatory scheduling requirement), tag the section based on its dominant content.

          ## inferred_section_type values

          inferred_section_type must be one of these values only:
          - company_about
          - benefits
          - compensation
          - culture
          - process_meta
          - legal
          - criteria

          For non_criteria sections, always provide one of: company_about, benefits, compensation, culture, process_meta, legal — even when the heading is explicit.
          For criteria sections, always use: criteria

          Do not subdivide criteria sections into types like "requirements" or "responsibilities" — just use "criteria" for all of them.

          ## Language

          Job descriptions may be in any language. Apply all rules identically regardless of language. Preserve the original language of all content in your output.

          ## Title technology

          If the job title contains a specific programming language, framework, or platform (e.g., Python, React, Salesforce, Kubernetes), return it as title_technology. Exclude generic terms like backend, frontend, full stack, senior, junior, lead, manager, engineer, developer, analyst. Return null if no specific technology is named in the title.

          ## Before returning, verify:
          - Every sentence from the input appears in exactly one section
          - No section has both heading and inferred_section_type as null
          - Every non_criteria section has an inferred_section_type value from the list above (not "non_criteria")
          - inferred_section_type for criteria sections is always "criteria"
          - Every sub-heading inside a section has been split into its own section with a joined heading
        PROMPT

        JSON_SCHEMA = {
          type: 'json_schema',
          json_schema: {
            name: 'job_description_structured_data',
            strict: true,
            schema: {
              type: 'object',
              properties: {
                title_technology: { type: %w[string null] },
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
                }
              },
              required: %w[sections title_technology],
              additionalProperties: false
            }
          }
        }.freeze

        MODEL = 'gpt-4.1-mini'

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
