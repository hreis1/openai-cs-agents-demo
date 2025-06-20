#!/usr/bin/env bash

# Exemplos de uso da API de Atendimento da Companhia Aérea - Ruby/Sinatra

echo "=== Testando aplicação Ruby/Sinatra ==="
echo ""

# Configurações
BASE_URL="http://localhost:8000"
HEADERS="Content-Type: application/json"

echo "1. Teste de Health Check"
echo "GET $BASE_URL/health"
curl -s -X GET "$BASE_URL/health" | python3 -m json.tool
echo ""
echo "---"
echo ""

echo "2. Primeira conversa - Triage para Flight Status"
echo "POST $BASE_URL/chat"
RESPONSE1=$(curl -s -X POST "$BASE_URL/chat" -H "$HEADERS" -d '{"message": "Hello, I need help with my flight"}')
CONVERSATION_ID1=$(echo "$RESPONSE1" | python3 -c "import sys, json; print(json.load(sys.stdin)['conversation_id'])")
echo "$RESPONSE1" | python3 -m json.tool
echo ""
echo "---"
echo ""

echo "3. Continuação da conversa - Verificar status do voo"
echo "POST $BASE_URL/chat (conversation_id: $CONVERSATION_ID1)"
curl -s -X POST "$BASE_URL/chat" -H "$HEADERS" -d "{\"conversation_id\": \"$CONVERSATION_ID1\", \"message\": \"What is the status?\"}" | python3 -m json.tool
echo ""
echo "---"
echo ""

echo "4. Nova conversa - FAQ sobre bagagem"
echo "POST $BASE_URL/chat"
curl -s -X POST "$BASE_URL/chat" -H "$HEADERS" -d '{"message": "I need help with baggage information"}' | python3 -m json.tool
echo ""
echo "---"
echo ""

echo "5. Nova conversa - Reserva de assento"
echo "POST $BASE_URL/chat"
RESPONSE2=$(curl -s -X POST "$BASE_URL/chat" -H "$HEADERS" -d '{"message": "I want to book seat 12A"}')
CONVERSATION_ID2=$(echo "$RESPONSE2" | python3 -c "import sys, json; print(json.load(sys.stdin)['conversation_id'])")
echo "$RESPONSE2" | python3 -m json.tool
echo ""
echo "---"
echo ""

echo "6. Continuação - Confirmar reserva do assento"
echo "POST $BASE_URL/chat (conversation_id: $CONVERSATION_ID2)"
curl -s -X POST "$BASE_URL/chat" -H "$HEADERS" -d "{\"conversation_id\": \"$CONVERSATION_ID2\", \"message\": \"I want seat 12A\"}" | python3 -m json.tool
echo ""
echo "---"
echo ""

echo "7. Teste de Guardrail - Mensagem irrelevante"
echo "POST $BASE_URL/chat"
curl -s -X POST "$BASE_URL/chat" -H "$HEADERS" -d '{"message": "What is the weather today?"}' | python3 -m json.tool
echo ""
echo "---"
echo ""

echo "8. Nova conversa - Cancelamento"
echo "POST $BASE_URL/chat"
RESPONSE3=$(curl -s -X POST "$BASE_URL/chat" -H "$HEADERS" -d '{"message": "I want to cancel my flight"}')
CONVERSATION_ID3=$(echo "$RESPONSE3" | python3 -c "import sys, json; print(json.load(sys.stdin)['conversation_id'])")
echo "$RESPONSE3" | python3 -m json.tool
echo ""
echo "---"
echo ""

echo "9. Confirmação do cancelamento"
echo "POST $BASE_URL/chat (conversation_id: $CONVERSATION_ID3)"
curl -s -X POST "$BASE_URL/chat" -H "$HEADERS" -d "{\"conversation_id\": \"$CONVERSATION_ID3\", \"message\": \"Yes, confirm cancellation\"}" | python3 -m json.tool
echo ""
echo "---"
echo ""

echo "=== Todos os testes concluídos ==="
