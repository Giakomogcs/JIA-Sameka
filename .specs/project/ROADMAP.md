# Roadmap

**Current Milestone:** M2 — Qualidade & Confiabilidade dos Leads
**Status:** In Progress

---

## M1 — Copiloto funcional (base)

**Goal:** Representante loga, conversa, recebe roteiro com cards e consulta catálogo.
**Target:** Concluído.

### Features

**Auth & Territórios** - COMPLETE
- Login Supabase (GoTrue), metadata-first (sem tabela profiles)
- RPCs admin (`sameka_admin_*`), roles, `company_name`, `estados`/`cidades`
- Trigger de `user_id` em `sameka_chat_message`

**Chat & Sessões** - COMPLETE
- Webhooks sessions/history/session/prune
- Memória de conversa (Postgres Chat Memory)
- Edição de mensagem (prune a partir de id)

**Pipeline de Leads (2 fontes Oporttuna)** - COMPLETE
- `Consultar_Leads_Oporttuna` + `Consultar_Clientes_Sameka_API_Oporttuna`
- Cascata PASSO 0→4 (parse, validação cidade IBGE, dedup, ranking, response)
- Cards `sameka-leads` + dedup cross-mensagem + limite 20/render
- Modo so_clientes / so_leads / ambos (50/50)

**Catálogo / RAG** - COMPLETE
- pgvector `sameka_documents` + `search_knowledge_base`
- Planilhas de produto/imagem; blocos `sameka-product-images`

**Front dual delivery** - COMPLETE
- Monolito `front-sameka.html` ↔ split `netlify/` ↔ `Sameka-Front.json`
- Quick actions (chips, "Minha região" via geolocalização)

---

## M2 — Qualidade & Confiabilidade dos Leads

**Goal:** Roteiros sem empresas mortas/fora de perfil; classificação cliente×prospect 100% correta; login novo nunca quebra.
**Target:** Critérios em `docs/03` e `docs/05`.

### Features

**Fix login GoTrue (migration 009)** - PLANNED
- Criar/rodar `migrations/009_fix_auth_null_tokens.sql` (ver C-SEC-1)

**Qualidade de leads Oporttuna (enriquecimento)** - IN PROGRESS
- Descartar `situacaoCadastral` inválida (BAIXADA/INAPTA/SUSPENSA/NULA) no GET-Leads (RF-20/25)
- Mapear campos de alto valor: `regimeTributario`, `simples`, `mei`, `tipoCNPJ`, `cep`, `idConsulta` (RF-26)
- Avaliar two-pass strict→relaxed (RF-16)

**Consolidação do filtro de perfil (front)** - PLANNED
- Definir estado canônico de `isMismatch` nos 3 arquivos; remover código morto (ver C-DEBT-4)

---

## M3 — Manutenibilidade

**Goal:** Reduzir fragilidade de edição e divergência front.

### Features

**Sync automatizado front** - PLANNED
- `scripts/_sync-front-workflow.ps1` (monolito → split → workflow), idempotente

**Limpeza do prompt do agente** - PLANNED
- Remover Sticky Note divergente; tratar systemMessage como artefato versionado

**Smoke tests mínimos** - PLANNED
- Node tests para helpers do front + probes HTTP das APIs

---

## Future Considerations

- CSP / sanitização de markdown do LLM (C-SEC-3)
- Cobertura de teste 5–10 cidades (validação de qualidade)
- Generalização do template "padrão Sameka" (AI Agent Architect)
