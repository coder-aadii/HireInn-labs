require "json"
require "net/http"
require "active_support/all" # Ensure this is available in your rails env

api_key = ENV["OPEN_ROUTER_API"].to_s
primary_model = ENV["OPEN_ROUTER_AI_MODEL"].to_s

abort("OPEN_ROUTER_API is missing") if api_key.empty?
abort("OPEN_ROUTER_AI_MODEL is missing") if primary_model.empty?

ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"

JOB_DATA = {
  title: "Assistant Ruby on Rails Developer",
  company_name: "HireInn Labs",
  location: "Indore",
  employment_type: "Full-time",
  experience_min: 0 # Tester
}

def formatted_experience(val)
  return "Fresher / 0 years" if val.to_i == 0
  val < 1 ? "#{ (val * 12).to_i } months" : "#{val} years"
end

def system_prompt
  <<~PROMPT.squish
    You are an expert HR copywriter. Return only valid JSON with keys: description_markdown, 
    responsibilities, requirements, benefits, skills, role_overview. 
    No extra text, no markdown code blocks.
  PROMPT
end

def user_prompt(title, company, location, type, exp_min)
  <<~PROMPT
    Create a job description for #{title} at #{company}.
    Location: #{location}, Type: #{type}, Min Experience: #{formatted_experience(exp_min)}.
    Return valid JSON.
  PROMPT
end

def clean_json(text)
  cleaned = text.to_s.strip
  cleaned = cleaned.sub(/^```json/, "").sub(/```$/, "").strip
  start = cleaned.index("{")
  finish = cleaned.rindex("}")
  raise "No JSON found" unless start && finish
  cleaned[start..finish]
end

def make_request(payload, api_key)
  uri = URI(ENDPOINT)
  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "Bearer #{api_key}"
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(payload)
  
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    http.request(request)
  end
end

models = [primary_model, "openai/gpt-3.5-turbo"]

models.each do |model|
  puts "\n🚀 Trying model: #{model}"

  payload = {
    model: model,
    messages: [
      { role: "system", content: system_prompt },
      { role: "user", content: user_prompt(*JOB_DATA.values) }
    ]
  }

  response = make_request(payload, api_key)

  if response.code.to_i == 200
    content = JSON.parse(response.body).dig("choices", 0, "message", "content")
    data = JSON.parse(clean_json(content))
    puts "\n✅ SUCCESS:"
    puts JSON.pretty_generate(data)
    break
  else
    puts "❌ Failed (#{response.code}): #{response.body}"
  end
end