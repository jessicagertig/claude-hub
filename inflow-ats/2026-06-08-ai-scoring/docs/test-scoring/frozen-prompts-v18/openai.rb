# frozen_string_literal: true

module AiProviders
  class Openai
    API_URL = 'https://api.openai.com/v1/chat/completions'

    def chat(messages:, model:, response_format: nil)
      body = {
        model: model,
        messages: messages,
        temperature: 0
      }
      body[:response_format] = response_format if response_format

      response = client.post do |req|
        req.body = body.to_json
      end

      parsed = JSON.parse(response.body)

      if response.status != 200
        error_message = parsed.dig('error', 'message') || "OpenAI API error (#{response.status})"
        raise CustomErrorAiSummary, error_message
      end

      {
        content: parsed.dig('choices', 0, 'message', 'content'),
        input_tokens: parsed.dig('usage', 'prompt_tokens'),
        output_tokens: parsed.dig('usage', 'completion_tokens'),
        model: parsed['model']
      }
    rescue Faraday::Error => e
      Rails.logger.error e
      ap e
      raise CustomErrorAiSummary, "OpenAI connection error: #{e.message}"
    rescue JSON::ParserError => e
      Rails.logger.error e
      ap e
      raise CustomErrorAiSummary, "OpenAI response parse error: #{e.message}"
    end

    private

    def client
      @client ||= Faraday.new(url: API_URL) do |conn|
        conn.options.timeout = 120
        conn.options.open_timeout = 30
        conn.adapter Faraday.default_adapter
        conn.headers['Authorization'] = "Bearer #{Variables::OPENAI_API_KEY}"
        conn.headers['Content-Type'] = 'application/json'
      end
    end
  end
end
