# Airline Customer Service - Ruby/Sinatra Version

Esta aplicação foi convertida do Python/FastAPI para Ruby/Sinatra, mantendo toda a funcionalidade original.

## Estrutura da Aplicação

- `main.rb` - Lógica principal dos agentes, ferramentas e contexto
- `app.rb` - API Sinatra com endpoints e lógica de conversação
- `config.ru` - Configuração do Rack
- `Gemfile` - Dependências Ruby
- `start.sh` - Script para iniciar a aplicação

## Funcionalidades Mantidas

### Agentes
- **Triage Agent**: Agente principal que direciona para outros agentes
- **Seat Booking Agent**: Gerencia reservas e mudanças de assento
- **Flight Status Agent**: Fornece status de voos
- **Cancellation Agent**: Processa cancelamentos de voos
- **FAQ Agent**: Responde perguntas frequentes

### Ferramentas
- `faq_lookup_tool`: Busca respostas para perguntas frequentes
- `update_seat`: Atualiza assento do passageiro
- `flight_status_tool`: Consulta status do voo
- `baggage_tool`: Informações sobre bagagem
- `display_seat_map`: Exibe mapa de assentos interativo
- `cancel_flight`: Cancela voo

### Guardrails
- **Relevance Guardrail**: Verifica se a mensagem é relevante para atendimento de companhia aérea
- **Jailbreak Guardrail**: Detecta tentativas de bypass das instruções do sistema

### Contexto
- Mantém informações do passageiro durante a conversa
- Gera números de confirmação e voo automaticamente
- Persiste estado da conversa em memória

## Instalação e Execução

### Pré-requisitos
- Ruby 3.0 ou superior
- Bundler

### Instalação
```bash
bundle install
```

### Execução
```bash
# Usando o script de inicialização
./start.sh

# Ou manualmente
bundle exec puma -p 8000 -e development

# Para desenvolvimento com auto-reload
bundle exec rerun -- puma -p 8000 -e development
```

## API Endpoints

### POST /chat
Endpoint principal para interação com os agentes.

**Request:**
```json
{
  "conversation_id": "optional-conversation-id",
  "message": "Hello, I need help with my flight"
}
```

**Response:**
```json
{
  "conversation_id": "unique-conversation-id",
  "current_agent": "Triage Agent",
  "messages": [
    {
      "content": "Hello! I'm here to help...",
      "agent": "Triage Agent"
    }
  ],
  "events": [
    {
      "id": "event-id",
      "type": "message",
      "agent": "Triage Agent",
      "content": "Hello! I'm here to help...",
      "timestamp": 1234567890
    }
  ],
  "context": {
    "passenger_name": null,
    "confirmation_number": null,
    "seat_number": null,
    "flight_number": null,
    "account_number": "12345678"
  },
  "agents": [...],
  "guardrails": [...]
}
```

### GET /health
Endpoint de saúde da aplicação.

**Response:**
```json
{
  "status": "ok",
  "timestamp": 1234567890.123
}
```

## Diferenças da Versão Python

### Estrutura de Código
- Convertido de classes Python para classes Ruby usando `dry-struct`
- Implementação simplificada do runner de agentes
- Uso de símbolos Ruby para identificadores de ferramentas

### Dependências
- `sinatra` - Framework web
- `dry-struct` e `dry-types` - Estruturas de dados tipadas
- `rack-cors` - Suporte a CORS
- `puma` - Servidor web

### Simplificações
- Runner de agentes simplificado (em produção, seria integrado com biblioteca completa de agentes)
- Guardrails implementados com lógica básica (em produção, integrariam com modelos de IA)
- Armazenamento em memória para estado das conversas

## Desenvolvimento

Para desenvolvimento com auto-reload:
```bash
bundle exec rerun -- puma -p 8000 -e development
```

## Produção

Para ambiente de produção, considere:
- Usar um servidor web robusto (nginx + puma)
- Implementar armazenamento persistente para conversas
- Integrar com modelos de IA reais para guardrails
- Adicionar logging e monitoramento
- Configurar variáveis de ambiente para configurações sensíveis

## Testes

A aplicação mantém a mesma funcionalidade da versão Python:
- Teste o endpoint `/chat` com diferentes tipos de mensagens
- Verifique o funcionamento dos guardrails com mensagens irrelevantes
- Teste os handoffs entre agentes
- Verifique a persistência do contexto entre mensagens
