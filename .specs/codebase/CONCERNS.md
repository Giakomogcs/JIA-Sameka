# Concerns

**Analyzed:** 2026-06-23
Concerns com evidência (paths/medições). Priorizados por risco.

## Segurança

### C-SEC-1 — Migration `009_fix_auth_null_tokens.sql` referenciada mas ausente (ALTA)
**Evidence:** `README.md` e `ARCHITECTURE.md` documentam `migrations/009_fix_auth_null_tokens.sql`; `migrations/` só tem `001`→`008`. Memória `sameka-auth-login.md` confirma o fix nunca foi aplicado (sem service role/senha PG).
**Impacto:** Login de usuário novo retorna **HTTP 500 corpo vazio** (front mostra `{}`) por colunas de token `NULL` em `auth.users` (bug GoTrue).
**Fix:** Criar `migrations/009_fix_auth_null_tokens.sql` (`UPDATE auth.users SET col=COALESCE(col,'') WHERE ...` para os 8 campos de token, idempotente) e rodar no Supabase Studio.

### C-SEC-2 — Anon key e endpoints embutidos no front (MÉDIA — esperado)
**Evidence:** `front-sameka.html` / `netlify/app.js` contêm `SUPABASE_ANON_KEY` e `API_BASE` em texto.
**Impacto:** Aceitável — só a **anon key** pode ficar no front. Risco é vazar `service_role`/senha PG. Hook `check-dangerous-patterns.json` bloqueia isso.
**Fix:** Manter regra: `service_role` e senha PG **só** nas credenciais n8n (`__FILL_ME__`). Não regredir.

### C-SEC-3 — Sem CSP / headers de segurança no front (BAIXA)
**Evidence:** `netlify.toml` desliga minificação; não há CSP/HSTS/X-Frame-Options. `geo` + `fetch` liberados (necessário p/ "Minha região").
**Impacto:** Exposição a XSS via markdown renderizado (marked.js) se entrada não sanitizada.
**Fix:** Avaliar CSP nonce-based e sanitização de HTML do LLM antes de `innerHTML`.

## Tech Debt / Fragilidade

### C-DEBT-1 — Lógica de negócio crítica em system prompt gigante (ALTA)
**Evidence:** `Sameka-Agent-IA-copy.json` node `RAG AI Agent` → `systemMessage` ~18k chars (cascata PASSO 0→4, dedup, ranking, escalonamento). Sticky Note tem uma **2ª cópia divergente e desatualizada** do prompt (menciona ferramentas/fontes antigas como `Consultar_Leads_Oporttuna` com regras legadas e `[CONTEXTO DO USUÁRIO]` em vez de `<user_context>`).
**Impacto:** Comportamento difícil de testar; deriva entre prompt ativo e a cópia da Sticky Note confunde manutenção.
**Fix:** Remover/atualizar a Sticky Note divergente; tratar o systemMessage como artefato versionado (já editado via Node, nunca `ConvertTo-Json`).

### C-DEBT-2 — Duplicação front monolito ↔ split (MÉDIA)
**Evidence:** `front-sameka.html`, `netlify/app.js`, `Sameka-Front.json` precisam ser mantidos idênticos (memória `sameka-mismatch-filter.md` lista os 3 como tendo o filtro `isMismatch`).
**Impacto:** Edição em um e esquecer os outros → divergência de comportamento (ex.: filtro de leads).
**Fix:** Script de sync idempotente (`scripts/` está vazio — reservado para `_sync-front-workflow.ps1`). Automatizar o split.

### C-DEBT-3 — Edição de workflow JSON frágil no PS5.1 (MÉDIA)
**Evidence:** Memória: `ConvertTo-Json -Depth` **trava** no PS5.1 com `[` no nome; systemMessage exige CRLF + BOM.
**Impacto:** Risco de corromper workflow ao editar pelo caminho errado.
**Fix:** Padronizar edição via Node (`JSON.parse`/`JSON.stringify`), documentado em CONVENTIONS.md.

### C-DEBT-4 — `isMismatch` definido mas reativado/desativado em ciclos (MÉDIA)
**Evidence:** `sameka-mismatch-filter.md` + `sameka-fontes-leads.md` (3ª rodada): filtro foi removido do fluxo, depois há regra de 2026-06-23 reativando. Funções `MISMATCH_KEYWORDS`/`VAREJO_INFANTIL_KEYWORDS` ficam definidas mas nem sempre chamadas.
**Impacto:** Ambiguidade sobre o comportamento atual de filtragem de leads no front.
**Fix:** Decidir estado canônico (filtrar só fontes não-curadas) e remover código morto se não usado.

## Cobertura de Testes

### C-TEST-1 — Zero testes automatizados (MÉDIA)
**Evidence:** Sem framework, sem diretório de testes (ver TESTING.md). Toda validação é manual.
**Impacto:** Regressões silenciosas no pipeline de leads/auth só aparecem em runtime.
**Fix:** Suíte mínima Node para os helpers do front (`_normalizeLead`, `renderLeadCards`, dedup) e smoke tests HTTP nas APIs.

## Pendências de produto (do plano docs/)

### C-PROD-1 — Enriquecimento de campos Oporttuna parcialmente feito (BAIXA)
**Evidence:** `sameka-fontes-leads.md` pendências: RF-20/25 (descartar `situacaoCadastral` inválida no GET-Leads), RF-26 (mapear `regimeTributario`, `simples`, `mei`, `tipoCNPJ`, `cep`, `idConsulta`), RF-16 (two-pass strict→relaxed). Specs em `docs/05-enriquecimento-dados-apis.md`.
**Impacto:** Leads podem incluir CNPJs baixados/inaptos em alguns caminhos; menos qualificação.
**Fix:** Ver feature `qualidade-leads-oporttuna` (roadmap).
