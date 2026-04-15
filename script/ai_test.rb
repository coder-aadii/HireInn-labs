require "json"
require "net/http"

api_key = ENV["OPEN_ROUTER_API"].to_s
primary_model = ENV["OPEN_ROUTER_AI_MODEL"].to_s

abort("OPEN_ROUTER_API is missing") if api_key.empty?
abort("OPEN_ROUTER_AI_MODEL is missing") if primary_model.empty?

# -----------------------------
# Config
# -----------------------------
ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"

def build_fallback_models(primary)
  [
    primary,
    "lynn/soliloquy-v3",
    "openai/gpt-oss-20b:free",
    "google/gemma-4-31b-it:free",
    "openrouter/free"
  ].compact.uniq
end

# -----------------------------
# Helpers
# -----------------------------
def clean_json(text)
  raise "Empty AI response" if text.nil? || text.strip.empty?

  cleaned = text.strip

  # Remove ``` blocks
  if cleaned.start_with?("```")
    cleaned = cleaned.lines[1..-2].join
  end

  # Extract JSON object
  start  = cleaned.index("{")
  finish = cleaned.rindex("}")

  raise "No JSON found in AI response" unless start && finish && finish > start

  cleaned[start..finish]
end

def make_request(payload, api_key)
  uri = URI(ENDPOINT)

  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "Bearer #{api_key}"
  request["Content-Type"]  = "application/json"
  request["HTTP-Referer"]  = "http://localhost"
  request["X-Title"]       = "HireInn Labs"
  request.body = JSON.generate(payload)

  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    http.open_timeout = 10
    http.read_timeout = 60
    http.request(request)
  end
end

# -----------------------------
# Main Execution
# -----------------------------
models = build_fallback_models(primary_model)

models.each do |model|
  puts "\n🚀 Trying model: #{model}"

  payload = {
    model: model,
    temperature: 0.7,
    messages: [
      {
        role: "system",
        content: <<~PROMPT
          You are a strict JSON generator.

          Return ONLY valid JSON.
          Do NOT include:
          - markdown
          - code blocks
          - explanations

          Format:
          {
            "hello": "string"
          }
        PROMPT
      },
      {
        role: "user",
        content: "Say 'hi' in json"
      }
    ]
  }

  retries = 3

  begin
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    response = make_request(payload, api_key)

    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(2)

    puts "Status: #{response.code} (#{elapsed}s)"

    case response.code.to_i

    when 200
      parsed  = JSON.parse(response.body)
      content = parsed.dig("choices", 0, "message", "content")

      puts "\n=== RAW AI CONTENT ==="
      puts content.inspect

      cleaned = clean_json(content)
      data    = JSON.parse(cleaned)

      puts "\n✅ SUCCESS (model: #{model})"
      puts JSON.pretty_generate(data)

      break # success → stop trying models

    when 429
      raise "Rate limited"

    when 402
      puts "❌ 402: No credits. Free models require minimal credits on OpenRouter."
      break

    else
      puts "❌ Failed (#{response.code}): #{response.body[0..200]}"
      break
    end

  rescue => e
    retries -= 1

    if retries > 0
      puts "⚠️ Retry (#{retries} left) due to: #{e.message}"
      sleep(2 ** (3 - retries)) # exponential backoff
      retry
    else
      puts "❌ Final failure for #{model}: #{e.message}"
    end
  end
end