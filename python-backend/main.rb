require 'dry-struct'
require 'dry-types'
require 'securerandom'

module Types
  include Dry.Types()
end

# =========================
# CONTEXT
# =========================

class AirlineAgentContext < Dry::Struct
  attribute :passenger_name, Types::String.optional.default(nil)
  attribute :confirmation_number, Types::String.optional.default(nil)
  attribute :seat_number, Types::String.optional.default(nil)
  attribute :flight_number, Types::String.optional.default(nil)
  attribute :account_number, Types::String.optional.default(nil)

  def self.create_initial
    # Generate a fake account number for demo purposes
    account_number = rand(10000000..99999999).to_s
    new(account_number: account_number)
  end
end

def create_initial_context
  AirlineAgentContext.create_initial
end

# =========================
# TOOLS
# =========================

class Tools
  def self.faq_lookup_tool(question)
    q = question.downcase
    if q.include?('bag') || q.include?('baggage')
      return "You are allowed to bring one bag on the plane. " \
             "It must be under 50 pounds and 22 inches x 14 inches x 9 inches."
    elsif q.include?('seats') || q.include?('plane')
      return "There are 120 seats on the plane. " \
             "There are 22 business class seats and 98 economy seats. " \
             "Exit rows are rows 4 and 16. " \
             "Rows 5-8 are Economy Plus, with extra legroom."
    elsif q.include?('wifi')
      return "We have free wifi on the plane, join Airline-Wifi"
    end
    "I'm sorry, I don't know the answer to that question."
  end

  def self.update_seat(context, confirmation_number, new_seat)
    context = context.new(
      confirmation_number: confirmation_number,
      seat_number: new_seat,
      passenger_name: context.passenger_name,
      flight_number: context.flight_number,
      account_number: context.account_number
    )
    raise "Flight number is required" if context.flight_number.nil?
    ["Updated seat to #{new_seat} for confirmation number #{confirmation_number}", context]
  end

  def self.flight_status_tool(flight_number)
    "Flight #{flight_number} is on time and scheduled to depart at gate A10."
  end

  def self.baggage_tool(query)
    q = query.downcase
    if q.include?('fee')
      return "Overweight bag fee is $75."
    elsif q.include?('allowance')
      return "One carry-on and one checked bag (up to 50 lbs) are included."
    end
    "Please provide details about your baggage inquiry."
  end

  def self.display_seat_map(context)
    "DISPLAY_SEAT_MAP"
  end

  def self.cancel_flight(context)
    fn = context.flight_number
    raise "Flight number is required" if fn.nil?
    "Flight #{fn} successfully cancelled"
  end
end

# =========================
# HOOKS
# =========================

def on_seat_booking_handoff(context)
  context.new(
    passenger_name: context.passenger_name,
    confirmation_number: generate_confirmation_number,
    seat_number: context.seat_number,
    flight_number: "FLT-#{rand(100..999)}",
    account_number: context.account_number
  )
end

def on_cancellation_handoff(context)
  confirmation = context.confirmation_number || generate_confirmation_number
  flight = context.flight_number || "FLT-#{rand(100..999)}"
  
  context.new(
    passenger_name: context.passenger_name,
    confirmation_number: confirmation,
    seat_number: context.seat_number,
    flight_number: flight,
    account_number: context.account_number
  )
end

def generate_confirmation_number
  chars = ('A'..'Z').to_a + ('0'..'9').to_a
  (0...6).map { chars[rand(chars.length)] }.join
end

# =========================
# GUARDRAILS
# =========================

class RelevanceOutput < Dry::Struct
  attribute :reasoning, Types::String
  attribute :is_relevant, Types::Bool
end

class JailbreakOutput < Dry::Struct
  attribute :reasoning, Types::String
  attribute :is_safe, Types::Bool
end

class Guardrails
  RECOMMENDED_PROMPT_PREFIX = "You are a helpful AI assistant for an airline customer service system."

  def self.relevance_guardrail(input_text)
    # Simulação da análise de relevância
    # Em produção, isso seria uma chamada para o modelo de IA
    
    # Verificar se é relacionado a viagem aérea
    airline_keywords = ['flight', 'baggage', 'seat', 'booking', 'cancel', 'status', 'check-in', 'wifi', 'plane']
    conversational_keywords = ['hi', 'hello', 'ok', 'yes', 'no', 'thanks', 'thank you']
    
    text_lower = input_text.downcase
    
    # Permitir mensagens conversacionais
    if conversational_keywords.any? { |keyword| text_lower.include?(keyword) }
      return RelevanceOutput.new(
        reasoning: "Conversational message is acceptable",
        is_relevant: true
      )
    end
    
    # Verificar palavras-chave relacionadas a companhias aéreas
    is_relevant = airline_keywords.any? { |keyword| text_lower.include?(keyword) }
    
    RelevanceOutput.new(
      reasoning: is_relevant ? "Message is related to airline travel" : "Message is not related to airline travel",
      is_relevant: is_relevant
    )
  end

  def self.jailbreak_guardrail(input_text)
    # Simulação da análise de jailbreak
    # Em produção, isso seria uma chamada para o modelo de IA
    
    jailbreak_patterns = [
      'system prompt', 'ignore instructions', 'drop table', 'sql injection',
      'reveal prompt', 'what is your prompt', 'bypass', 'override'
    ]
    
    text_lower = input_text.downcase
    is_safe = !jailbreak_patterns.any? { |pattern| text_lower.include?(pattern) }
    
    JailbreakOutput.new(
      reasoning: is_safe ? "Input appears safe" : "Potential jailbreak attempt detected",
      is_safe: is_safe
    )
  end
end

# =========================
# AGENTS
# =========================

class Agent
  attr_accessor :name, :model, :handoff_description, :instructions, :tools, :handoffs, :input_guardrails

  def initialize(name:, model: 'gpt-4.1', handoff_description: '', instructions: '', tools: [], handoffs: [], input_guardrails: [])
    @name = name
    @model = model
    @handoff_description = handoff_description
    @instructions = instructions
    @tools = tools
    @handoffs = handoffs
    @input_guardrails = input_guardrails
  end

  def get_instructions(context)
    if @instructions.is_a?(Proc)
      @instructions.call(context)
    else
      @instructions
    end
  end
end

# Agent definitions
def seat_booking_instructions(context)
  confirmation = context.confirmation_number || "[unknown]"
  "#{Guardrails::RECOMMENDED_PROMPT_PREFIX}\n" \
  "You are a seat booking agent. If you are speaking to a customer, you probably were transferred to from the triage agent.\n" \
  "Use the following routine to support the customer.\n" \
  "1. The customer's confirmation number is #{confirmation}." \
  "If this is not available, ask the customer for their confirmation number. If you have it, confirm that is the confirmation number they are referencing.\n" \
  "2. Ask the customer what their desired seat number is. You can also use the display_seat_map tool to show them an interactive seat map where they can click to select their preferred seat.\n" \
  "3. Use the update seat tool to update the seat on the flight.\n" \
  "If the customer asks a question that is not related to the routine, transfer back to the triage agent."
end

def flight_status_instructions(context)
  confirmation = context.confirmation_number || "[unknown]"
  flight = context.flight_number || "[unknown]"
  "#{Guardrails::RECOMMENDED_PROMPT_PREFIX}\n" \
  "You are a Flight Status Agent. Use the following routine to support the customer:\n" \
  "1. The customer's confirmation number is #{confirmation} and flight number is #{flight}.\n" \
  "   If either is not available, ask the customer for the missing information. If you have both, confirm with the customer that these are correct.\n" \
  "2. Use the flight_status_tool to report the status of the flight.\n" \
  "If the customer asks a question that is not related to flight status, transfer back to the triage agent."
end

def cancellation_instructions(context)
  confirmation = context.confirmation_number || "[unknown]"
  flight = context.flight_number || "[unknown]"
  "#{Guardrails::RECOMMENDED_PROMPT_PREFIX}\n" \
  "You are a Cancellation Agent. Use the following routine to support the customer:\n" \
  "1. The customer's confirmation number is #{confirmation} and flight number is #{flight}.\n" \
  "   If either is not available, ask the customer for the missing information. If you have both, confirm with the customer that these are correct.\n" \
  "2. If the customer confirms, use the cancel_flight tool to cancel their flight.\n" \
  "If the customer asks anything else, transfer back to the triage agent."
end

# Create agents
$seat_booking_agent = Agent.new(
  name: "Seat Booking Agent",
  handoff_description: "A helpful agent that can update a seat on a flight.",
  instructions: method(:seat_booking_instructions),
  tools: [:update_seat, :display_seat_map],
  input_guardrails: [:relevance_guardrail, :jailbreak_guardrail]
)

$flight_status_agent = Agent.new(
  name: "Flight Status Agent",
  handoff_description: "An agent to provide flight status information.",
  instructions: method(:flight_status_instructions),
  tools: [:flight_status_tool],
  input_guardrails: [:relevance_guardrail, :jailbreak_guardrail]
)

$cancellation_agent = Agent.new(
  name: "Cancellation Agent",
  handoff_description: "An agent to cancel flights.",
  instructions: method(:cancellation_instructions),
  tools: [:cancel_flight],
  input_guardrails: [:relevance_guardrail, :jailbreak_guardrail]
)

$faq_agent = Agent.new(
  name: "FAQ Agent",
  handoff_description: "A helpful agent that can answer questions about the airline.",
  instructions: "#{Guardrails::RECOMMENDED_PROMPT_PREFIX}\n" \
               "You are an FAQ agent. If you are speaking to a customer, you probably were transferred to from the triage agent.\n" \
               "Use the following routine to support the customer.\n" \
               "1. Identify the last question asked by the customer.\n" \
               "2. Use the faq lookup tool to get the answer. Do not rely on your own knowledge.\n" \
               "3. Respond to the customer with the answer",
  tools: [:faq_lookup_tool],
  input_guardrails: [:relevance_guardrail, :jailbreak_guardrail]
)

$triage_agent = Agent.new(
  name: "Triage Agent",
  handoff_description: "A triage agent that can delegate a customer's request to the appropriate agent.",
  instructions: "#{Guardrails::RECOMMENDED_PROMPT_PREFIX} " \
               "You are a helpful triaging agent. You can use your tools to delegate questions to other appropriate agents.",
  handoffs: [$flight_status_agent, $cancellation_agent, $faq_agent, $seat_booking_agent],
  input_guardrails: [:relevance_guardrail, :jailbreak_guardrail]
)

# Set up handoff relationships
$faq_agent.handoffs = [$triage_agent]
$seat_booking_agent.handoffs = [$triage_agent]
$flight_status_agent.handoffs = [$triage_agent]
$cancellation_agent.handoffs = [$triage_agent]
