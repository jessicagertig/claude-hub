# frozen_string_literal: true

class AiClient
  PROVIDERS = {
    'openai' => 'AiProviders::Openai',
    'deepseek' => 'AiProviders::Deepseek',
    'mistral' => 'AiProviders::Mistral',
    'gemini' => 'AiProviders::Gemini',
    'anthropic' => 'AiProviders::Anthropic'
  }.freeze

  # Cost per 1M tokens [input, output]
  PRICING = {
    'gpt-4o' => { input: 2.50, output: 10.00 },
    'gpt-4o-mini' => { input: 0.15, output: 0.60 },
    'gpt-4.1-mini' => { input: 0.40, output: 1.60 },
    'gemini-3.1-flash-lite' => { input: 0.25, output: 1.50 },
    'gemini-3.5-flash' => { input: 1.50, output: 9.00 },
    'deepseek-chat' => { input: 0.27, output: 1.10 },
    'mistral-large-latest' => { input: 2.00, output: 6.00 },
    'gemini-2.5-flash' => { input: 0.15, output: 0.60 },
    'claude-haiku-4-5-20251001' => { input: 0.80, output: 4.00 },
    'claude-sonnet-4-20250514' => { input: 3.00, output: 15.00 }
  }.freeze

  def initialize(provider: 'openai')
    @provider = provider
    @client = PROVIDERS.fetch(provider).constantize.new
  end

  def chat(messages:, model:, response_format: nil)
    @client.chat(messages: messages, model: model, response_format: response_format)
  end

  def self.calculate_cost(model:, input_tokens:, output_tokens:)
    pricing = PRICING[model]
    return unless pricing

    (input_tokens.to_f * pricing[:input] / 1_000_000) +
      (output_tokens.to_f * pricing[:output] / 1_000_000)
  end
end
