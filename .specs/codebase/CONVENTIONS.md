# Code Conventions

## Naming Conventions

**SQL identifiers:** prefixo `sameka_` em tudo (tabelas, funções, RPCs).
Examples: `sameka_chat_message`, `sameka_documents`, `sameka_admin_list_users()`, `sameka_is_admin()`, `sameka_match_documents`

**Workflows n8n (arquivos):** `[Sameka] <Nome>.json` (subflows) ou `Sameka-<Área>.json` (fluxos principais).
Examples: `[Sameka] GET-Leads.json`, `Sameka-Agent-IA-copy.json`, `Sameka-Chat-GET-History.json`

**Nodes n8n:** nome legível em PT/EN; tools com nome `Verbo_Substantivo` (snake/Pascal misto).
Examples: `RAG AI Agent`, `Consultar_Leads_Oporttuna`, `Consultar_IBGE`, `Edit Fields`, `Delete Edited Message`

**Webhooks (paths):** kebab-case com prefixo `sameka-`.
Examples: `sameka-AgentRag`, `sameka-prune-history`, `sameka-sessions`, `sameka_health`

**Front (JS):** camelCase para funções/variáveis; prefixo `_` para helpers internos.
Examples: `renderLeadCards`, `processLeadBlocks`, `handleSendMessage`, `_normalizeLead`, `_isCliente`, `_isEncerrado`

**Front (CSS / IDs):** kebab-case.
Examples: `#quickActions`, `.qa-chip`, `#qaCityPanel`, `.lead-card`, `.fonte-carteira`

**Constantes de config (front):** UPPER_SNAKE_CASE no topo do `<script>`.
Examples: `API_BASE`, `CHAT_URL`, `SUPABASE_URL`, `MAX_LEADS_PER_RENDER`

## Code Organization

**Migrations:** numeradas `NNN_descricao.sql`, rodadas em ordem, **idempotentes**, terminando com `NOTIFY pgrst, 'reload schema';`.

**RPCs:** sempre `SECURITY DEFINER SET search_path = auth, public`; guards de admin via `IF NOT sameka_is_admin() THEN RAISE`.

**Front ↔ split:** `front-sameka.html` é a fonte; `netlify/app.js` deve ser idêntico em lógica. Toda edição de front é aplicada nos dois (e em `Sameka-Front.json` quando afeta o filtro de leads).

## Type Safety / Documentation

**Approach:** Sem tipos estáticos (JS vanilla, SQL). O "contrato" é o envelope `{ ok, fonte, total, leads:[...] }` dos subflows e o schema de lead no systemMessage do agente.

## Error Handling

**Pattern (agente):** tool retorna `ok:false` → mensagem amigável ao usuário, nunca o erro técnico (Regra 9). Não interrompe o roteiro se a carteira falhar.
**Pattern (front):** respostas 500 sem corpo aparecem como `{}` — tratar como falha de auth/API, não bug de front.
**Pattern (n8n setup):** `Sameka-DB-Schema-Setup.json` usa `continueOnFail: true` (idempotência Tier B).

## Comments / Documentation

**Style:** Comentários explicam decisões de negócio e armadilhas (ex.: acento-sensibilidade da API, edição de JSON via Node). Diagramas sempre Mermaid (sem ASCII art) — convenção do `ARCHITECTURE.md`.

## Armadilhas conhecidas (edição de workflows)

- Editar JSON de workflow com `[` no nome via `ConvertTo-Json -Depth` no **PS5.1 trava**. Usar Node (`JSON.parse`/`JSON.stringify(null,2)`), stripar BOM `^\uFEFF`, preservar.
- `systemMessage` usa finais de linha **CRLF (`\r\n`)** e **BOM**.
- Em `String.replace` com grupos, usar **função** `(m,g1,g2)=>` — `String(n)+"$2"` vira `$20` (grupo 20) e quebra.
