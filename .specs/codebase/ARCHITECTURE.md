# Architecture

**Pattern:** Orquestração serverless por workflows (n8n) — front desacoplado (HTML/JS) falando só com webhooks n8n + Supabase auth. Toda lógica de negócio vive no n8n. 5 camadas.

> Documento canônico detalhado (com diagramas C4/Mermaid) já existe em [`ARCHITECTURE.md`](../../ARCHITECTURE.md) na raiz. Este arquivo é o resumo de mapeamento para o fluxo spec-driven.

## High-Level Structure

```
Navegador (front-sameka.html)
   │  login/RPC ──► Supabase (GoTrue + Postgres + pgvector)
   │  POST msg  ──► n8n webhook sameka-AgentRag
                        │
                        ├─ RAG AI Agent (gpt-5.4-mini)
                        │     ├─ Postgres Chat Memory (sameka_chat_message)
                        │     ├─ search_knowledge_base (pgvector)
                        │     └─ tools → subflows
                        │           ├─ Consultar_Leads_Oporttuna → [Sameka] GET-Leads
                        │           ├─ Consultar_Clientes_... → [Sameka] GET-Clientes
                        │           ├─ Consultar_IBGE → [Sameka] Consulta IBGE
                        │           └─ Consultar_Planilha/Imagens → subflows Sheets
                        └─ Respond to Webhook → markdown + sameka-leads block
```

## Identified Patterns

### Agente orientado por system prompt (cascata PASSO 0→4)
**Location:** `workspaces/Sameka-Agent-IA-copy.json`, node `RAG AI Agent` → `parameters.options.systemMessage`
**Purpose:** Toda a lógica de roteiro (parse de território, validação de cidade, busca, dedup, ranking, formatação) é codificada em prompt, não em código.
**Implementation:** Seções IDENTIDADE → OBJETIVO → CONTEXTO → FERRAMENTAS → POLÍTICA → CASCATA (PASSO 0 parse / 0.5 valida cidade / 1 carteira / 2 oporttuna+escalonamento / 3 dedup+ranking / 4 response) → 12 REGRAS ABSOLUTAS.
**Example:** PASSO 2 "🔄 PEDIDO DE CONTINUAÇÃO" (mais opções) começa em `limite=jaMostradas+60`.

### Contrato de subflow `{ ok, fonte, total, ... }`
**Location:** subflows `[Sameka] GET-Leads.json`, `GET-Clientes.json`
**Purpose:** Envelope consistente; cada lead carrega o campo `fonte` (ground truth da classificação).
**Implementation:** `ok:false` → agente avisa em linguagem simples (Regra 9). `empresaCliente` (SIM/NAO) vem direto da API e nunca é re-rotulado.

### Entrega dupla do front (monolito ↔ split)
**Location:** `front-sameka.html` (fonte) ↔ `netlify/*` (fatiado) ↔ `Sameka-Front.json` (n8n-served)
**Purpose:** Mesma UI servível por Netlify estático ou pelo n8n. Edições sempre no monolito, sincronizadas idênticas.

### Metadata-first auth (sem tabela profiles)
**Location:** `migrations/`, `auth.users.raw_user_meta_data`
**Purpose:** Dados do usuário (full_name, role, company_name, estados, cidades) vivem no JSONB de `auth.users`. RPCs `SECURITY DEFINER` administram.

## Data Flow

### Fluxo de mensagem (roteiro)
1. Login Supabase → `user_metadata` (estados, cidades, role).
2. Front prefixa `[CONTEXTO DO USUÁRIO: ...]` na mensagem e injeta `<user_context>`.
3. POST `sameka-AgentRag` → `Edit Fields` normaliza `chatInput`/`sessionId`.
4. Agente: PASSO 0 lê território → 0.5 valida cidade (IBGE) → 1/2 busca → 3 dedup+ranking → 4 monta `sameka-leads`.
5. `Postgres Chat Memory` grava o turno; `Respond to Webhook` devolve.
6. Front `renderLeadCards()` → cards visuais; dedup cross-mensagem por `data-dedup-key`.

### Edição de mensagem (prune)
Webhook `sameka-prune-history` → `Delete Edited Message` (DELETE de `id >=` o editado) → `PruneResponse`.

## Code Organization

**Approach:** Por camada física (front / workflows / migrations / docs), não por feature.
**Module boundaries:** O front nunca chama APIs externas direto — só webhooks n8n e Supabase auth. Subflows isolam cada integração (leads, clientes, IBGE, planilhas).
