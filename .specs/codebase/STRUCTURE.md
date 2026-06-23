# Project Structure

**Root:** `c:\Users\Administrador\Downloads\sameka`

## Directory Tree

```text
sameka/
├── front-sameka.html          # Monolito front (source-of-truth): chat, login, sidebar, admin
├── deployed.html              # Snapshot publicado do front
├── ARCHITECTURE.md            # Arquitetura técnica (C4 + Mermaid)
├── README.md                  # Visão geral, setup, endpoints
├── netlify.toml               # Config Netlify (minificação DESLIGADA)
├── 004_seed.ps1               # Cria admin inicial via GoTrue
├── 005_run_migration_008.ps1  # Roda backfill 008
├── openapi-inteligencia-negocio.yaml      # Spec API Oporttuna
├── oporttuna-inteligencia-comercial.yaml  # Spec API Oporttuna (comercial)
├── docs/                      # PRDs + plano (mudança "clientes 100% Oporttuna")
│   ├── 01-contexto-e-arquitetura-atual.md
│   ├── 02-PRD-fonte-unica-clientes-oporttuna.md
│   ├── 03-PRD-qualidade-filtros-oporttuna.md
│   ├── 04-plano-implementacao.md
│   ├── 05-enriquecimento-dados-apis.md
│   └── README.md
├── migrations/                # SQL Supabase (idempotente, ordem 001→008)
│   ├── 001..008_*.sql
│   ├── 008_LEIA-ME.md
│   └── RUN_ALL_user_rpcs.sql
├── netlify/                   # Front fatiado (split estático)
│   ├── index.html
│   ├── app.js
│   ├── auth-storage.js
│   └── polyfills.js
├── scripts/                   # (vazio — reservado para _sync-*.ps1)
└── workspaces/                # Workflows n8n (JSON exportado)
    ├── Sameka-Agent-IA-copy.json     # FLUXO PRINCIPAL (RAG AI Agent)
    ├── Sameka-Front.json             # n8n serve o HTML
    ├── Sameka-RAG.json               # Ingestão/consulta RAG
    ├── Sameka-DB-Schema-Setup.json   # Setup idempotente do schema (Tier B)
    ├── Sameka-Chat-*.json            # CRUD de sessões/histórico
    └── [Sameka] GET-*.json / Sub-fluxo_*.json  # Subflows (leads, IBGE, planilhas)
```

## Module Organization

### Banco / Auth
**Purpose:** Schema de chat, RPCs admin, roles, territórios.
**Location:** `migrations/`
**Key files:** `001_user_crud_functions.sql`, `005_add_coverage_areas.sql`, `007_add_user_to_chat.sql`

### Orquestração + Agente
**Purpose:** Agente LangChain, ferramentas, CRUD de chat, RAG.
**Location:** `workspaces/`
**Key files:** `Sameka-Agent-IA-copy.json` (node `RAG AI Agent`), subflows `[Sameka] GET-Leads.json` / `GET-Clientes.json`

### Front (monolito)
**Purpose:** Chat, login, sessões, modais admin, render de lead cards.
**Location:** `front-sameka.html`
**Key files:** `front-sameka.html`

### Front (split estático)
**Purpose:** Versão fatiada para hosting Netlify.
**Location:** `netlify/`
**Key files:** `index.html`, `app.js`, `auth-storage.js`, `polyfills.js`

### RAG / Catálogo
**Purpose:** Ingestão de PDFs, vetorização, planilhas de produto.
**Location:** `workspaces/Sameka-RAG.json` + subflows de planilha + Google Drive
**Key files:** `Sameka-RAG.json`, `[Sameka] Sub-fluxo_ Consultar Planilha Inteligente.json`

## Where Things Live

**Pipeline de leads:**
- UI/Interface: `front-sameka.html` (`renderLeadCards`, `processLeadBlocks`)
- Business Logic: `workspaces/Sameka-Agent-IA-copy.json` (systemMessage PASSO 0→4) + `[Sameka] GET-Leads.json` / `GET-Clientes.json`
- Data Access: APIs Oporttuna (via subflows)
- Configuration: constantes no topo do `<script>` em `front-sameka.html`

**Catálogo / RAG:**
- UI/Interface: front (blocos `sameka-product-images`)
- Business Logic: `Sameka-Agent-IA-copy.json` (tools `search_knowledge_base`, `Consultar_Planilha_Inteligente`)
- Data Access: pgvector `sameka_documents` + Google Sheets

**Auth / territórios:**
- UI/Interface: modais admin no front + login
- Business Logic: RPCs `sameka_admin_*` (migrations)
- Data Access: `auth.users.raw_user_meta_data` (JSONB) — **não há tabela `profiles`**

## Special Directories

**`workspaces/`** — Workflows n8n exportados em JSON. Editados via `JSON.parse`/`JSON.stringify` (Node), **nunca** com `ConvertTo-Json` no PS5.1 quando o nome tem `[` (trava). systemMessage usa CRLF e BOM.

**`netlify/`** — Espelho fatiado do monolito. Edições de front vão **sempre** no monolito e são sincronizadas para cá (devem permanecer idênticas).
