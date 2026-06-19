# Arquitetura — Sameka

Documento técnico detalhado de **como tudo funciona**: as 5 camadas, os fluxos de mensagem, o pipeline de leads, a auth, o RAG e o padrão de entrega dupla do front. Todos os diagramas são **Mermaid** (sem ASCII art).

Índice:

- [1. Visão geral (C4 — Contexto)](#1-visão-geral-c4--contexto)
- [2. Containers (C4 — Nível 2)](#2-containers-c4--nível-2)
- [3. Camada 1 — Banco / Auth (Supabase)](#3-camada-1--banco--auth-supabase)
- [4. Camada 2 — Orquestração + Agente (n8n)](#4-camada-2--orquestração--agente-n8n)
- [5. Fluxo de uma mensagem (sequência)](#5-fluxo-de-uma-mensagem-sequência)
- [6. Pipeline de leads (o coração do produto)](#6-pipeline-de-leads-o-coração-do-produto)
- [7. Camada RAG / Catálogo](#7-camada-rag--catálogo)
- [8. Camada Front (monolito + split)](#8-camada-front-monolito--split)
- [9. Autenticação e papéis](#9-autenticação-e-papéis)
- [10. Modelo de dados](#10-modelo-de-dados)
- [11. Endpoints (webhooks)](#11-endpoints-webhooks)
- [12. Decisões e regras invioláveis](#12-decisões-e-regras-invioláveis)

---

## 1. Visão geral (C4 — Contexto)

```mermaid
C4Context
  title Sameka — Diagrama de Contexto (Nível 1)

  Person(rep, "Representante", "Vendedor B2B da Sameka; usa o chat para montar roteiros")
  Person(admin, "Admin", "Gerencia usuários, territórios e base de conhecimento")

  System(sameka, "Sameka", "Copiloto de vendas: front de chat + agente LangChain no n8n")

  System_Ext(supabase, "Supabase", "Auth (GoTrue) + Postgres (histórico de chat) + pgvector")
  System_Ext(oporttuna, "API Oporttuna", "Leads (prospects) e carteira de clientes")
  System_Ext(ibge, "API IBGE", "Nomes oficiais de municípios por UF")
  System_Ext(google, "Google Drive / Sheets", "PDFs do catálogo + planilhas de produto/imagem")
  System_Ext(azure, "Azure OpenAI", "LLM gpt-5.4-mini + embeddings")

  Rel(rep, sameka, "Conversa, pede roteiros", "HTTPS")
  Rel(admin, sameka, "Administra", "HTTPS")
  Rel(sameka, supabase, "Login, histórico, busca semântica", "HTTPS/SQL")
  Rel(sameka, oporttuna, "Consulta leads/clientes", "HTTPS")
  Rel(sameka, ibge, "Valida cidades", "HTTPS")
  Rel(sameka, google, "Ingere docs / consulta planilhas", "HTTPS")
  Rel(sameka, azure, "Gera respostas / embeddings", "HTTPS")
```

---

## 2. Containers (C4 — Nível 2)

```mermaid
flowchart TB
  subgraph Browser["Navegador do representante"]
    FE["Front (chat)<br/>front-sameka.html / netlify split"]
  end

  subgraph n8n["n8n (orquestração)"]
    WAGENT["Webhook sameka-AgentRag<br/>+ RAG AI Agent (LangChain)"]
    WCHAT["Webhooks de chat<br/>sessions / history / session"]
    WRAG["Webhooks RAG<br/>rag-docs / rag-doc-delete / rag-purge-all"]
    WFRONT["Webhook sameka-chat<br/>serve o HTML"]
    SUBS["Subflows<br/>GET-Leads / GET-Clientes / IBGE / Planilhas"]
  end

  subgraph Supabase["Supabase"]
    AUTH["GoTrue (auth.users)"]
    PG[("Postgres<br/>sameka_chat_message")]
    VEC[("pgvector<br/>sameka_documents")]
  end

  OPO["API Oporttuna"]
  IBGE["API IBGE"]
  GOOG["Google Drive / Sheets"]
  AZ["Azure OpenAI"]

  FE -->|"login / RPC admin"| AUTH
  FE -->|"POST mensagem"| WAGENT
  FE -->|"sessões / histórico / apagar"| WCHAT
  FE -->|"admin docs"| WRAG

  WAGENT --> AZ
  WAGENT -->|"memória de chat"| PG
  WAGENT -->|"search_knowledge_base"| VEC
  WAGENT --> SUBS
  SUBS --> OPO
  SUBS --> IBGE
  SUBS --> GOOG
  WCHAT --> PG
  WRAG --> VEC
  WRAG --> GOOG
  WFRONT -->|"HTML"| FE
```

**Princípio:** o front **só** fala com webhooks do n8n e com o Supabase (auth). Toda a lógica de negócio (busca de leads, RAG, ranking) vive no n8n. As APIs externas (Oporttuna, IBGE, Google, Azure) são chamadas **somente** pelo n8n.

---

## 3. Camada 1 — Banco / Auth (Supabase)

Migrations em [`migrations/`](./migrations). Convenções: prefixo `sameka_`; toda RPC é `SECURITY DEFINER SET search_path = auth, public`; cada arquivo termina com `NOTIFY pgrst, 'reload schema'` (recarrega cache do PostgREST). **Não há tabela `profiles`** — os dados do usuário vivem em `auth.users.raw_user_meta_data` (JSONB): `full_name`, `role`, `company_name`, `estados`, `cidades`.

| Migration                      | O que faz                                                                                                                                                             |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `001_user_crud_functions.sql`  | RPCs base sobre `auth.users`: `sameka_admin_list_users()`, `sameka_admin_confirm_user(uuid)`, `sameka_admin_update_user(uuid,text)`, `sameka_admin_delete_user(uuid)` |
| `002_add_roles.sql`            | Adiciona `role` à listagem e parâmetro `p_role` ao update                                                                                                             |
| `003_admin_guards.sql`         | Cria `sameka_is_admin()` e adiciona guard `IF NOT sameka_is_admin() THEN RAISE` nas 4 RPCs                                                                            |
| `004_add_company_name.sql`     | Multi-tenant leve: filtra usuários por `company_name='sameka'`; `sameka_is_admin()` checa company                                                                     |
| `005_add_coverage_areas.sql`   | Territórios: colunas/params `estados` e `cidades` (JSONB); `sameka_admin_update_user(uuid,text,text,jsonb,jsonb)`                                                     |
| `006_prevent_self_delete.sql`  | Guard `IF p_user_id = auth.uid() THEN RAISE` no delete                                                                                                                |
| `007_add_user_to_chat.sql`     | Adiciona `user_id UUID` em `sameka_chat_message` + índice; trigger `trg_set_chat_user_id()` extrai o UUID do marcador `[CONTEXTO DO USUÁRIO: ID="..."]`               |
| `008_backfill_user_id.sql`     | Backfill único do `user_id` em linhas antigas                                                                                                                         |
| `009_fix_auth_null_tokens.sql` | Corrige colunas de token `NULL` em `auth.users` (bug do GoTrue que causa HTTP 500 no login)                                                                           |

Setup equivalente sem rodar SQL manual: o workflow [`Sameka-DB-Schema-Setup.json`](./workspaces/Sameka-DB-Schema-Setup.json) recria o schema de forma **idempotente** (`continueOnFail: true`), cobrindo o equivalente às migrations 001–007 (estratégia **Tier B** — setup pelo n8n, sem apagar dados).

---

## 4. Camada 2 — Orquestração + Agente (n8n)

O agente principal é o node **RAG AI Agent** (LangChain) em [`Sameka-Agent-IA-copy.json`](./workspaces/Sameka-Agent-IA-copy.json), exposto no webhook `sameka-AgentRag`. Ele recebe a mensagem (com o `[CONTEXTO DO USUÁRIO: ...]` prefixado pelo front), executa um `systemMessage` longo (protocolo PASSO 0 → 4) e escolhe ferramentas.

```mermaid
flowchart LR
  IN["Webhook<br/>sameka-AgentRag"] --> AG["RAG AI Agent<br/>(gpt-5.4-mini)"]
  AG --- MEM["Postgres Chat Memory<br/>sameka_chat_message"]
  AG --- EMB["Azure Embeddings"]

  AG -->|leads novos| T1["Consultar_Leads_Oporttuna<br/>→ [Sameka] GET-Leads"]
  AG -->|carteira| T2["Consultar_Clientes_...<br/>→ [Sameka] GET-Clientes"]
  AG -->|cidades| T3["Consultar_IBGE<br/>→ [Sameka]Consulta IBGE"]
  AG -->|planilha| T4["Consultar_Planilha_Inteligente"]
  AG -->|imagens| T5["Consultar_Imagens_Produtos"]
  AG -->|catálogo/preço| T6["search_knowledge_base<br/>(pgvector sameka_documents)"]
  AG -->|docs| T7["List/Get/Query Document<br/>(postgresTool)"]

  AG --> OUT["Resposta (markdown + lead-blocks)"]
```

**Ferramentas do agente** (cada uma é um subflow ou tool node):

| Tool                                                           | Destino                                                | Uso                                |
| -------------------------------------------------------------- | ------------------------------------------------------ | ---------------------------------- |
| `Consultar_Leads_Oporttuna`                                    | `[Sameka] GET-Leads`                                   | Prospects novos por cidade/UF      |
| `Consultar_Clientes_Sameka_API_Oporttuna`                      | `[Sameka] GET-Clientes`                                | Clientes ativos (carteira)         |
| `Consultar_IBGE`                                               | `[Sameka]Consulta IBGE`                                | Lista oficial de municípios por UF |
| `Consultar_Planilha_Inteligente`                               | subflow planilha                                       | Busca em planilha de produtos      |
| `Consultar_Imagens_Produtos`                                   | subflow imagens                                        | Imagens de produto                 |
| `search_knowledge_base`                                        | pgvector `sameka_documents` / `sameka_match_documents` | Busca semântica no catálogo        |
| `List Documents` / `Get File Contents` / `Query Document Rows` | postgresTool                                           | Metadados/linhas de docs indexados |

Workflows auxiliares de manutenção no mesmo JSON: **PruneWebhook** (`sameka-prune-history` → apaga mensagens a partir de um id, usado ao editar) e **Test Connection** (`sameka_health`).

---

## 5. Fluxo de uma mensagem (sequência)

```mermaid
sequenceDiagram
  autonumber
  actor Rep as Representante
  participant FE as Front
  participant SUP as Supabase
  participant N8N as n8n (Agente)
  participant OPO as Oporttuna
  participant IBGE as IBGE

  Rep->>FE: Login (email/senha)
  FE->>SUP: signInWithPassword
  SUP-->>FE: sessão + user_metadata (estados, cidades, role)

  Rep->>FE: "roteiro em Joinville"
  FE->>FE: prefixa [CONTEXTO DO USUÁRIO: Nome|Papel|Estados|Cidades|ID]
  FE->>N8N: POST sameka-AgentRag {mensagem, sessionId}

  Note over N8N: PASSO 0 — lê território autorizado<br/>PASSO 0.5 — valida cidade
  N8N->>IBGE: municípios de SC (se precisar corrigir nome)
  IBGE-->>N8N: ["Joinville", ...]

  Note over N8N: PASSO 1-2 — busca dados
  N8N->>OPO: GET-Clientes (carteira) + GET-Leads (prospects)
  OPO-->>N8N: empresas

  Note over N8N: PASSO 3 — classifica (cliente vs prospect),<br/>deduplica, ranqueia
  N8N->>SUP: grava turno em sameka_chat_message
  N8N-->>FE: resposta (markdown + <lead-block>)
  FE->>FE: renderLeadCards() → cards visuais
  FE-->>Rep: roteiro com cards
```

---

## 6. Pipeline de leads (o coração do produto)

O agente trata **duas fontes Oporttuna** e nunca inventa empresas:

- `GET-Clientes` → **carteira** (clientes já ativos da Sameka).
- `GET-Leads` → **prospects** (potenciais clientes novos).

```mermaid
flowchart TD
  A["Pedido: cidade/UF<br/>(ou 'minha região')"] --> B{Cidade no<br/>território autorizado?}
  B -- não --> B1["Recusa educadamente +<br/>oferece cidade vizinha autorizada"]
  B -- sim --> C["Normalizar Input<br/>(Levenshtein + acento)"]
  C --> D{Nome bate<br/>com IBGE?}
  D -- não --> D1["Corrige via [Sameka]Consulta IBGE"]
  D -- sim --> E["GET-Clientes (carteira)"]
  D1 --> E
  E --> F["GET-Leads (prospects)"]
  F --> G["Classifica: empresaCliente = true/false"]
  G --> H["Dedup por CNPJ → Razão Social → Nome Fantasia"]
  H --> I["Ranqueia: perfil infantil +<br/>presença digital primeiro"]
  I --> J["Monta cards (lead-block)"]
```

### Protocolo "mais opções" (continuação / escalonamento)

A API Oporttuna devolve sempre as **mesmas** empresas no topo (ranking ICP fixo). Sem cuidado, "mais opções" repetiria os mesmos cards e o front (que deduplica) mostraria **zero**. O protocolo no `systemMessage` resolve assim:

```mermaid
flowchart TD
  P["Pedido de continuação<br/>(jaMostradas = N)"] --> Q["Começa com limite = N + 60 (mín. 100)"]
  Q --> R["Dedup contra o que já foi mostrado"]
  R --> S{">= 20 novas?"}
  S -- sim --> T["Retorna as novas"]
  S -- não --> U["+100 no limite (até 300)"]
  U --> V{"2 tentativas seguidas<br/>sem nada novo?"}
  V -- não --> R
  V -- sim --> W["Cidade esgotada:<br/>NÃO retorna bloco vazio/repetido —<br/>responde honestamente e<br/>oferece cidade vizinha"]
```

---

## 7. Camada RAG / Catálogo

Ingestão de PDFs do Google Drive, vetorização no pgvector e consulta semântica. Workflow [`Sameka-RAG.json`](./workspaces/Sameka-RAG.json).

```mermaid
flowchart LR
  subgraph Ingestão
    D["Google Drive<br/>(pasta dedicada)"] --> DL["Download File"]
    DL --> EX["Extract PDF/Doc Text"]
    EX --> CH["Default Data Loader<br/>(chunking)"]
    CH --> EMB["Azure Embeddings"]
    EMB --> INS["Insere em<br/>sameka_documents (pgvector)"]
    INS --> META["sameka_document_metadata<br/>+ sameka_document_rows"]
  end

  subgraph Consulta
    Q["search_knowledge_base"] --> M["sameka_match_documents()"]
    M --> R["chunks relevantes → agente"]
  end
```

**Identidade estável:** cada documento mantém o `file_id` do Drive como chave; atualizar um doc usa `files.update` (mesmo `file_id`), nunca `files.delete`. Endpoints admin: `sameka-rag-docs` (listar), `sameka-rag-doc-delete` (remover), `sameka-rag-purge-all` (purgar). Planilhas de produto/imagem são consultadas por subflows separados (Google Sheets), não pelo vetor.

---

## 8. Camada Front (monolito + split)

A fonte única é o monolito [`front-sameka.html`](./front-sameka.html) (~7074 linhas). Para hosting estático, ele é **fatiado** em [`netlify/`](./netlify). Toda mudança precisa ficar **idêntica** nos dois lados.

```mermaid
flowchart LR
  MONO["front-sameka.html<br/>(fonte única)"]
  MONO -->|HTML + CSS| IDX["netlify/index.html"]
  MONO -->|JS| APP["netlify/app.js"]
  IDX --> POLY["polyfills.js<br/>(antes do Supabase SDK)"]
  IDX --> SDK["supabase-js"]
  IDX --> ASTORE["auth-storage.js"]
  IDX --> APP

  subgraph Servido por
    NET["Netlify (estático)<br/>minificação OFF"]
    NFRONT["Sameka-Front.json<br/>(webhook sameka-chat)"]
  end
  MONO --> NFRONT
  IDX --> NET
```

**Ordem de carregamento (crítica):** `polyfills.js` → `supabase-js` → `auth-storage.js` → `app.js`. Os polyfills preparam `localStorage`/`sessionStorage`/`navigator.locks` para funcionar dentro de iframe **antes** do SDK do Supabase carregar. O `auth-storage.js` implementa a cascata de persistência de sessão: **localStorage → cookie → memória**.

> O `netlify.toml` mantém **toda minificação/bundling desligada** (`skip_processing`), porque o minificador quebra o JS inline e o split.

Principais áreas de função no front: `buildAuthStorage()`, `sendMessage()/fetchHistory()/fetchSessions()`, `renderSessionList()`, `renderLeadCards()/processLeadBlocks()`, `processProductImageBlocks()`, `renderMessage()` (marked + highlight.js), quick-actions (`handleMinhaRegiao`, `generateRoteiroForCity`, `qaCheckCityAccess`), admin de usuários (`loadUsersPage/openEditUser/openDeleteUser` via RPC) e admin de docs RAG (`showRagDocsPage/uploadRagDoc/purgeAllRagDocs`).

---

## 9. Autenticação e papéis

```mermaid
sequenceDiagram
  autonumber
  actor U as Usuário
  participant FE as Front
  participant GT as GoTrue (auth)
  participant DB as Postgres (RPC)

  U->>FE: email + senha
  FE->>GT: signInWithPassword
  GT-->>FE: access_token + user_metadata
  Note over FE: role = user_metadata.role
  Note over FE: territorio = estados/cidades

  alt role = admin
    U->>FE: abre modal Usuarios
    FE->>DB: rpc sameka_admin_list_users()
    DB->>DB: checa sameka_is_admin()
    DB-->>FE: usuarios (company_name=sameka)
    U->>FE: editar territorio
    FE->>DB: rpc sameka_admin_update_user(id, role, estados, cidades)
  else role = representante
    Note over FE: modais de admin escondidos
    Note over FE: territorio limita as cidades consultaveis
  end
```

Pontos-chave:

- Sessão persiste mesmo em iframe via cascata `localStorage → cookie → memória` (`auth-storage.js`).
- RPCs admin são `SECURITY DEFINER` com guard `sameka_is_admin()` (defesa no servidor, não só na UI).
- Admin não pode se autodeletar (`006_prevent_self_delete.sql`).

---

## 10. Modelo de dados

```mermaid
erDiagram
  auth_users ||--o{ sameka_chat_message : "user_id"
  sameka_document_metadata ||--o{ sameka_document_rows : "dataset_id"
  sameka_document_metadata ||--o{ sameka_documents : "file_id"

  auth_users {
    uuid id PK
    text email
    jsonb raw_user_meta_data "full_name, role, company_name, estados, cidades"
  }
  sameka_chat_message {
    bigint id PK
    text session_id
    uuid user_id FK
    jsonb message "type + content"
    timestamptz created_at
  }
  sameka_documents {
    bigint id PK
    text file_id "id estável do Drive"
    text content
    vector embedding
    jsonb metadata
  }
  sameka_document_metadata {
    text file_id PK
    text title
    text url
  }
  sameka_document_rows {
    bigint id PK
    text dataset_id FK
    jsonb row_data
  }
```

> O `user_id` em `sameka_chat_message` é preenchido automaticamente pelo trigger `trg_set_chat_user_id()`, que extrai o UUID do marcador `[CONTEXTO DO USUÁRIO: ID="..."]` nas mensagens humanas e propaga para as respostas da IA na mesma sessão.

---

## 11. Endpoints (webhooks)

| Path (após `…/webhook/`) | Método   | Workflow                   | Função                                     |
| ------------------------ | -------- | -------------------------- | ------------------------------------------ |
| `sameka-AgentRag`        | POST     | Sameka-Agent-IA-copy       | Mensagem ao agente                         |
| `sameka-sessions`        | GET      | Sameka-Chat-GET-Sessions   | Lista sessões do usuário                   |
| `sameka-history`         | GET      | Sameka-Chat-GET-History    | Histórico de uma sessão                    |
| `sameka-session`         | DELETE   | Sameka-Chat-DELETE-Session | Apaga sessão                               |
| `sameka-prune-history`   | POST     | Sameka-Agent-IA-copy       | Apaga mensagens a partir de um id (editar) |
| `sameka-chat`            | GET      | Sameka-Front               | Serve o HTML do front                      |
| `sameka-rag-docs`        | GET/POST | Sameka-RAG                 | Lista docs do RAG                          |
| `sameka-rag-doc-delete`  | POST     | Sameka-RAG                 | Remove doc do RAG                          |
| `sameka-rag-purge-all`   | POST     | Sameka-RAG                 | Purga todo o RAG                           |
| `sameka-index-drive`     | POST     | Sameka-RAG                 | Indexa novo doc do Drive                   |
| `sameka_health`          | GET      | Sameka-Agent-IA-copy       | Healthcheck                                |

---

## 12. Decisões e regras invioláveis

| Decisão                                       | Razão                                                                |
| --------------------------------------------- | -------------------------------------------------------------------- |
| Toda lógica no n8n; front "burro"             | Trocar prompt/fonte sem redeploy do front; segredos longe do cliente |
| Metadata-first (sem `profiles`)               | Menos joins; território e role viajam no JWT                         |
| RPC `SECURITY DEFINER` + `sameka_is_admin()`  | Autorização no banco, não confiando só na UI                         |
| `file_id` do Drive como chave do RAG          | Atualizar doc sem perder vínculos (identidade estável)               |
| Monolito como fonte única + split idempotente | Edição em um lugar; hosting estático sem build                       |
| Minificação OFF no Netlify                    | Minificador quebra JS inline e a ordem de scripts                    |

**Proibições absolutas:**

- ❌ `DROP ... CASCADE` em migrations/workflows.
- ❌ `ON DELETE CASCADE` em FK para `auth.users`.
- ❌ `files.delete` do Google Drive (use `files.update`).
- ❌ `service_role` / senha do Postgres no front ou Netlify (somente anon key).
- ❌ Inventar empresas/cidades — leads só das APIs Oporttuna; cidades validadas pelo IBGE.
