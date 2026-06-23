# Tech Stack

**Analyzed:** 2026-06-23

## Core

- Orquestração: **n8n** (self-hosted, Cloudfy) — node LangChain Agent (`@n8n/n8n-nodes-langchain.agent` v1.6)
- Linguagem (front): JavaScript vanilla (ES2017+) embutido em HTML
- Linguagem (banco): SQL (PostgreSQL / Supabase)
- Scripts de setup: PowerShell 5.1 (`.ps1`)
- Runtime n8n: Node.js (gerenciado pela instância n8n)

## Frontend

- UI Framework: **nenhum** — HTML + JS vanilla (`front-sameka.html`, monolito source-of-truth)
- Render Markdown: `marked.js`
- Syntax highlight: `highlight.js`
- Ícones: `lucide`
- Auth client: `@supabase/supabase-js` (UMD via CDN)
- Estado: variáveis de módulo no `<script>` (sem store/framework)

## Backend / Orquestração

- API Style: **Webhooks n8n** (REST sobre HTTP POST/GET) — não há servidor app dedicado
- Agente: LangChain Agent node (Azure OpenAI tool-calling)
- Memória de conversa: `@n8n/n8n-nodes-langchain.memoryPostgresChat` → tabela `sameka_chat_message`
- Banco: PostgreSQL (Supabase) acessado via `n8n-nodes-base.postgres` / `postgresTool`
- Autenticação: Supabase GoTrue (`signInWithPassword`) + RPCs `SECURITY DEFINER`

## LLM / IA

- Chat model: **Azure OpenAI `gpt-5.4-mini`** (`@n8n/n8n-nodes-langchain.lmChatAzureOpenAi`)
- Embeddings: **Azure OpenAI `text-embedding-3-small`**
- Vector store: **Supabase pgvector** — tabela `sameka_documents`, função `sameka_match_documents`

## Testing

- Unit: **nenhum framework** (sem suíte automatizada)
- Integration: **nenhum** — validação manual via probes HTTP / preview do front
- E2E: **nenhum** — verificação manual no navegador (Live Server / preview)

## External Services

- Leads/Clientes: **API Oporttuna** (PROD + HMG) — `inteligencia-negocio/leads-por-cidade`
- Geografia: **API IBGE** — `localidades/estados/{UF}/municipios`
- Catálogo: **Google Drive / Google Sheets** (PDFs + planilhas de produto/imagem)
- LLM/Embeddings: **Azure OpenAI**
- Auth/DB/Vector: **Supabase** (GoTrue + Postgres + pgvector)
- Hosting front: **Netlify** (estático) ou n8n servindo o HTML

## Development Tools

- Editor/preview: VS Code + Live Server (`http://127.0.0.1:5501/front-sameka.html`)
- Sync scripts (PowerShell): `004_seed.ps1`, `005_run_migration_008.ps1` (referência a `_sync-*.ps1` no padrão)
- Specs de API externas: `openapi-inteligencia-negocio.yaml`, `oporttuna-inteligencia-comercial.yaml`
