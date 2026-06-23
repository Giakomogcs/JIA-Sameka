# External Integrations

## LLM / IA

**Service:** Azure OpenAI
**Purpose:** Chat (`gpt-5.4-mini`) + embeddings (`text-embedding-3-small`).
**Implementation:** Nodes `Azure OpenAI Chat Model` e `Embeddings Azure OpenAI` em `Sameka-Agent-IA-copy.json`.
**Configuration:** Credencial n8n `Azure Open AI account 3`.
**Authentication:** API key Azure (credencial n8n).

## Banco / Auth / Vector

**Service:** Supabase (GoTrue + Postgres + pgvector)
**Purpose:** Login, papéis/territórios, histórico de chat, busca semântica do catálogo.
**Implementation:** Front usa `@supabase/supabase-js` (auth + RPCs). n8n usa `postgres`/`postgresTool` + `vectorStoreSupabase`.
**Configuration:** `SUPABASE_URL=https://longflatworm-supabase.cloudfy.live`; anon key embutida no front; credenciais n8n `Supabase account` / `Supabase_database`.
**Authentication:** anon key (front) + service role / senha PG (somente n8n, marcadas `__FILL_ME__` no repo).

## API Integrations

### Oporttuna (leads / carteira)
**Purpose:** Prospects novos (`oporttuna`) e carteira de clientes ativos (`carteira_sameka`).
**Location:** subflows `[Sameka] GET-Leads.json` (HMG) e `[Sameka] GET-Clientes.json` (PROD), chamados pelas tools `Consultar_Leads_Oporttuna` / `Consultar_Clientes_Sameka_API_Oporttuna`.
**Authentication:** `POST /portal-api-hmg/auth/login {email,senha}` → token em `resp.retorno.token`; depois `Authorization: Bearer <token>` + `x-empresa-id: sameka`.
**Key endpoints:** `GET inteligencia-negocio/leads-por-cidade?cidade&uf&limite&apenasNovosProspects=NAO_CLIENTES&removerContatosContabeis=true` (prospects); `.../sameka/leads-por-cidade` (carteira/DW).
**Specs:** `openapi-inteligencia-negocio.yaml`, `oporttuna-inteligencia-comercial.yaml`.
**Notas críticas:**
- Endpoint de **leads é acento-sensível** (`Balneário Camboriú` 200; `Balneario Camboriu` 400). `Normalizar Input` resolve a cidade via IBGE antes de chamar.
- Ranking ICP de varejo infantil é aplicado **automaticamente** via token/tenant (header `x-perfil-icp-id` não é necessário).
- Cada lead traz `empresaCliente` (SIM/NAO) = ground truth cliente×prospect.

### IBGE (validação de cidades)
**Purpose:** Lista oficial de municípios por UF (nomes canônicos com acento) — valida/corrige cidade digitada.
**Location:** subflow `[Sameka]Consulta IBGE.json`, tool `Consultar_IBGE` (input `{uf}`).
**Authentication:** pública, sem chave.
**Key endpoints:** `GET localidades/estados/{UF}/municipios`.

### Google Drive / Sheets (catálogo)
**Purpose:** PDFs do catálogo (ingestão RAG) + planilhas de produto/imagem.
**Location:** `Sameka-RAG.json`, subflows `Consultar Planilha Inteligente`, `Consultar Planilha Imagens de Produtos`, `Drive Document Manager`.
**Authentication:** Google OAuth (credencial n8n).
**Notas:** RAG/planilhas usados **só** para catálogo/produto — nunca como fonte de leads.

## Webhooks

### Front → n8n
**Purpose:** Toda a comunicação do front.
**Location:** webhooks em `Sameka-Agent-IA-copy.json` e `Sameka-Chat-*.json`.
**Events/paths:** `sameka-AgentRag` (mensagem), `sameka-sessions`, `sameka-history`, `sameka-session` (delete), `sameka-prune-history` (editar), `sameka-index-drive` / `sameka-rag-docs` / `sameka-rag-doc-delete` / `sameka-rag-purge-all` (RAG admin), `sameka_health` (healthcheck), `sameka-chat` (serve HTML).

## Background Jobs

**Queue system:** nenhum.
**Location:** n/a — toda execução é síncrona por webhook (responseMode `responseNode`).
**Jobs:** n/a.
