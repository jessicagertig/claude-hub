# frozen_string_literal: true

module AiProviders
  class Anthropic
    API_URL = 'https://api.anthropic.com/v1/messages'

    def chat(messages:, model:, response_format: nil)
      system_message = messages.find { |m| m[:role] == 'system' || m['role'] == 'system' }
      non_system_messages = messages.reject { |m| m[:role] == 'system' || m['role'] == 'system' }

      system_text = system_message[:content] || system_message['content'] if system_message
      system_text = "#{system_text}\n\nIMPORTANT: Return ONLY valid JSON. No markdown fences, no explanation, no other text." if response_format && system_text

      body = {
        model: model,
        max_tokens: 4096,
        messages: non_system_messages
      }
      body[:system] = system_text if system_text

      response = client.post do |req|
        req.body = body.to_json
      end

      parsed = JSON.parse(response.body)

      if response.status != 200
        error_message = parsed.dig('error', 'message') || "Anthropic API error (#{response.status})"
        raise CustomErrorAiSummary, error_message
      end

      {
        content: parsed.dig('content', 0, 'text'),
        input_tokens: parsed.dig('usage', 'input_tokens'),
        output_tokens: parsed.dig('usage', 'output_tokens'),
        model: parsed['model']
      }
    rescue Faraday::Error => e
      Rails.logger.error e
      ap e
      raise CustomErrorAiSummary, "Anthropic connection error: #{e.message}"
    rescue JSON::ParserError => e
      Rails.logger.error e
      ap e
      raise CustomErrorAiSummary, "Anthropic response parse error: #{e.message}"
    end

    private

    def client
      @client ||= Faraday.new(url: API_URL) do |conn|
        conn.adapter Faraday.default_adapter
        conn.headers['x-api-key'] = Variables::ANTHROPIC_API_KEY.to_s
        conn.headers['anthropic-version'] = '2023-06-01'
        conn.headers['Content-Type'] = 'application/json'
      end
    end
  end
end
