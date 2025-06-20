require 'sinatra'
require 'sinatra/json'
require 'json'
require 'securerandom'
require 'rack/cors'
require_relative 'main'

# CORS configuration
use Rack::Cors do
  allow do
    origins 'http://localhost:3000'
    resource '*', 
             headers: :any, 
             methods: [:get, :post, :put, :patch, :delete, :options, :head],
             credentials: true
  end
end

set :port, 8000
set :bind, '0.0.0.0'

# =========================
# Models (simplified - using hashes instead of dry-struct for internal use)
# =========================

def create_message_response(content, agent)
  { content: content, agent: agent }
end

def create_agent_event(type, agent, content, metadata = {})
  {
    id: SecureRandom.hex,
    type: type,
    agent: agent,
    content: content,
    metadata: metadata,
    timestamp: Time.now.to_f * 1000
  }
end

def create_guardrail_check(name, input, reasoning, passed)
  {
    id: SecureRandom.hex,
    name: name,
    input: input,
    reasoning: reasoning,
    passed: passed,
    timestamp: Time.now.to_f * 1000
  }
end

# =========================
# In-memory store for conversation state
# =========================

class ConversationStore
  def initialize
    @conversations = {}
  end

  def get(conversation_id)
    @conversations[conversation_id]
  end

  def save(conversation_id, state)
    @conversations[conversation_id] = state
  end
end

$conversation_store = ConversationStore.new

# =========================
# Helpers
# =========================

def get_agent_by_name(name)
  agents = {
    $triage_agent.name => $triage_agent,
    $faq_agent.name => $faq_agent,
    $seat_booking_agent.name => $seat_booking_agent,
    $flight_status_agent.name => $flight_status_agent,
    $cancellation_agent.name => $cancellation_agent
  }
  agents[name] || $triage_agent
end

def get_guardrail_name(guardrail_symbol)
  case guardrail_symbol
  when :relevance_guardrail
    "Relevance Guardrail"
  when :jailbreak_guardrail
    "Jailbreak Guardrail"
  else
    guardrail_symbol.to_s.gsub('_', ' ').split.map(&:capitalize).join(' ')
  end
end

def build_agents_list
  agents = [$triage_agent, $faq_agent, $seat_booking_agent, $flight_status_agent, $cancellation_agent]
  
  agents.map do |agent|
    {
      name: agent.name,
      description: agent.handoff_description,
      handoffs: agent.handoffs.map(&:name),
      tools: agent.tools.map(&:to_s),
      input_guardrails: agent.input_guardrails.map { |g| get_guardrail_name(g) }
    }
  end
end

# Simplified agent runner for demo purposes
def run_agent(agent, input_items, context)
  messages = []
  events = []
  current_agent = agent
  new_context = context
  
  # Check guardrails
  last_user_message = input_items.reverse.find { |item| item[:role] == 'user' }
  if last_user_message
    agent.input_guardrails.each do |guardrail|
      case guardrail
      when :relevance_guardrail
        result = Guardrails.relevance_guardrail(last_user_message[:content])
        unless result.is_relevant
          raise GuardrailError.new("Relevance check failed", guardrail, result)
        end
      when :jailbreak_guardrail
        result = Guardrails.jailbreak_guardrail(last_user_message[:content])
        unless result.is_safe
          raise GuardrailError.new("Jailbreak check failed", guardrail, result)
        end
      end
    end
  end
  
  # Simulate agent processing based on the message content and agent type
  user_message = last_user_message[:content].downcase if last_user_message
  
  case agent.name
  when "Triage Agent"
    if user_message&.include?('seat') || user_message&.include?('booking')
      # Handoff to seat booking agent
      new_context = on_seat_booking_handoff(context)
      current_agent = $seat_booking_agent
      events << create_agent_event(
        "handoff",
        agent.name,
        "#{agent.name} -> #{current_agent.name}",
        { source_agent: agent.name, target_agent: current_agent.name }
      )
      messages << create_message_response(
        "I'll help you with seat booking. Let me transfer you to our seat booking specialist.",
        current_agent.name
      )
    elsif user_message&.include?('status') || user_message&.include?('flight')
      # Handoff to flight status agent
      current_agent = $flight_status_agent
      events << create_agent_event(
        "handoff",
        agent.name,
        "#{agent.name} -> #{current_agent.name}",
        { source_agent: agent.name, target_agent: current_agent.name }
      )
      messages << create_message_response(
        "I'll help you check your flight status. Let me get that information for you.",
        current_agent.name
      )
    elsif user_message&.include?('cancel')
      # Handoff to cancellation agent
      new_context = on_cancellation_handoff(context)
      current_agent = $cancellation_agent
      events << create_agent_event(
        "handoff",
        agent.name,
        "#{agent.name} -> #{current_agent.name}",
        { source_agent: agent.name, target_agent: current_agent.name }
      )
      messages << create_message_response(
        "I understand you want to cancel your flight. Let me help you with that.",
        current_agent.name
      )
    elsif user_message&.include?('bag') || user_message&.include?('wifi') || user_message&.include?('faq')
      # Handoff to FAQ agent
      current_agent = $faq_agent
      events << create_agent_event(
        "handoff",
        agent.name,
        "#{agent.name} -> #{current_agent.name}",
        { source_agent: agent.name, target_agent: current_agent.name }
      )
      answer = Tools.faq_lookup_tool(user_message)
      messages << create_message_response(answer, current_agent.name)
    else
      messages << create_message_response(
        "Hello! I'm here to help you with your airline needs. I can assist with flight status, seat booking, cancellations, and answer frequently asked questions. How can I help you today?",
        agent.name
      )
    end
    
  when "Seat Booking Agent"
    if user_message&.include?('seat map') || user_message&.include?('show seats')
      # Use display_seat_map tool
      events << create_agent_event("tool_call", agent.name, "display_seat_map")
      result = Tools.display_seat_map(context)
      messages << create_message_response(result, agent.name)
    elsif user_message&.match(/seat (\w+)/i)
      # Extract seat number and update
      seat_number = user_message.match(/seat (\w+)/i)[1].upcase
      confirmation = context.confirmation_number || "ABC123"
      
      events << create_agent_event(
        "tool_call",
        agent.name,
        "update_seat",
        { tool_args: { confirmation_number: confirmation, new_seat: seat_number } }
      )
      
      result, new_context = Tools.update_seat(context, confirmation, seat_number)
      messages << create_message_response(result, agent.name)
    else
      instructions = agent.get_instructions(context)
      messages << create_message_response(
        "I can help you select or change your seat. Would you like me to show you the seat map, or do you have a specific seat preference?",
        agent.name
      )
    end
    
  when "Flight Status Agent"
    flight_number = context.flight_number || "FLT-123"
    events << create_agent_event(
      "tool_call",
      agent.name,
      "flight_status_tool",
      { tool_args: { flight_number: flight_number } }
    )
    
    result = Tools.flight_status_tool(flight_number)
    messages << create_message_response(result, agent.name)
    
  when "Cancellation Agent"
    if user_message&.include?('yes') || user_message&.include?('confirm')
      events << create_agent_event("tool_call", agent.name, "cancel_flight")
      
      result = Tools.cancel_flight(context)
      messages << create_message_response(result, agent.name)
    else
      confirmation = context.confirmation_number
      flight = context.flight_number
      messages << create_message_response(
        "I can help you cancel your flight #{flight} with confirmation number #{confirmation}. Are you sure you want to proceed with the cancellation?",
        agent.name
      )
    end
    
  when "FAQ Agent"
    question = user_message || ""
    events << create_agent_event(
      "tool_call",
      agent.name,
      "faq_lookup_tool",
      { tool_args: { question: question } }
    )
    
    result = Tools.faq_lookup_tool(question)
    messages << create_message_response(result, agent.name)
  end
  
  {
    messages: messages,
    events: events,
    current_agent: current_agent,
    context: new_context
  }
end

class GuardrailError < StandardError
  attr_reader :guardrail, :output
  
  def initialize(message, guardrail, output)
    super(message)
    @guardrail = guardrail
    @output = output
  end
end

# =========================
# Routes
# =========================

before do
  content_type :json
end

post '/chat' do
  request_body = JSON.parse(request.body.read, symbolize_names: true)
  message = request_body[:message]
  conversation_id = request_body[:conversation_id]
  
  # Initialize or retrieve conversation state
  is_new = conversation_id.nil? || $conversation_store.get(conversation_id).nil?
  
  if is_new
    conversation_id = SecureRandom.hex
    context = create_initial_context
    current_agent_name = $triage_agent.name
    state = {
      input_items: [],
      context: context,
      current_agent: current_agent_name
    }
    
    if message.strip.empty?
      $conversation_store.save(conversation_id, state)
      return {
        conversation_id: conversation_id,
        current_agent: current_agent_name,
        messages: [],
        events: [],
        context: context.to_h,
        agents: build_agents_list,
        guardrails: []
      }.to_json
    end
  else
    state = $conversation_store.get(conversation_id)
    context = state[:context]
  end
  
  current_agent = get_agent_by_name(state[:current_agent])
  state[:input_items] << { content: message, role: "user" }
  old_context = context.to_h.dup
  guardrail_checks = []
  
  begin
    result = run_agent(current_agent, state[:input_items], context)
    
    messages = result[:messages]
    events = result[:events]
    current_agent = result[:current_agent]
    new_context = result[:context]
    
    # Check for context changes
    if new_context.to_h != old_context
      changes = new_context.to_h.select { |k, v| old_context[k] != v }
      unless changes.empty?
        events << create_agent_event(
          "context_update",
          current_agent.name,
          "",
          { changes: changes }
        )
      end
    end
    
    # Add assistant messages to input history
    messages.each do |msg|
      state[:input_items] << { role: "assistant", content: msg[:content] }
    end
    
    state[:current_agent] = current_agent.name
    state[:context] = new_context
    $conversation_store.save(conversation_id, state)
    
    # Build guardrail results - mark all as passed since we got here
    final_guardrails = current_agent.input_guardrails.map do |g|
      create_guardrail_check(get_guardrail_name(g), message, "", true)
    end
    
    {
      conversation_id: conversation_id,
      current_agent: current_agent.name,
      messages: messages,
      events: events,
      context: new_context.to_h,
      agents: build_agents_list,
      guardrails: final_guardrails
    }.to_json
    
  rescue GuardrailError => e
    failed_guardrail = e.guardrail
    gr_output = e.output
    gr_reasoning = gr_output.respond_to?(:reasoning) ? gr_output.reasoning : ""
    gr_timestamp = Time.now.to_f * 1000
    
    current_agent.input_guardrails.each do |g|
      passed = g != failed_guardrail
      reasoning = passed ? "" : gr_reasoning
      
      guardrail_checks << create_guardrail_check(get_guardrail_name(g), message, reasoning, passed)
    end
    
    refusal = "Sorry, I can only answer questions related to airline travel."
    state[:input_items] << { role: "assistant", content: refusal }
    $conversation_store.save(conversation_id, state)
    
    {
      conversation_id: conversation_id,
      current_agent: current_agent.name,
      messages: [{ content: refusal, agent: current_agent.name }],
      events: [],
      context: context.to_h,
      agents: build_agents_list,
      guardrails: guardrail_checks
    }.to_json
  end
end

get '/health' do
  { status: 'ok', timestamp: Time.now.to_f }.to_json
end
