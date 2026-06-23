# State

**Last Updated:** 2026-06-23T00:00:00Z
**Current Work:** Setup spec-driven (mapeamento brownfield + projeto) — concluído

---

## Recent Decisions (Last 60 days)

### AD-001: Leads 100% Oporttuna (2 fontes) (2026-06-17)

**Decision:** Fonte de leads/clientes = exclusivamente APIs Oporttuna (`carteira_sameka` + `oporttuna`). Planilhas de histórico (`clientesSameka`, `consulta-empresas-<UF>.xlsx`) eliminadas como fonte de leads.
**Reason:** Histórico trazia empresas antigas, calçado adulto, sem presença digital.
**Trade-off:** Dependência total da disponibilidade da API Oporttuna.
**Impact:** Nó `Consultar_Clientes_Sameka_Carteira` removido; RAG/planilhas só para catálogo.

### AD-002: Classificação cliente×prospect via `empresaCliente` (2026-06-19)

**Decision:** Ground truth = campo `empresaCliente` (SIM/NAO) por registro da API, não o campo `fonte` rotulado pelo LLM.
**Reason:** LLM re-rotulava prospects como clientes; texto contradizia os cards.
**Trade-off:** Front precisa derivar badge de `empresaCliente`.
**Impact:** `_isCliente` e `syncLeadBreakdown` no front; PASSO 4 conta X/Y por `empresaCliente`.

### AD-003: Validação de cidade via IBGE antes da API de leads (2026-06-17)

**Decision:** Resolver nome de cidade pela API IBGE (fold de acento + fuzzy/Levenshtein) antes de chamar Oporttuna.
**Reason:** Endpoint de leads é acento-sensível (`Balneario` → HTTP 400).
**Trade-off:** Chamada extra ao IBGE.
**Impact:** `Normalizar Input` nos subflows GET-Leads/GET-Clientes; PASSO 0.5 no prompt.

---

## Active Blockers

### B-001: Migration 009 não aplicável no dev

**Discovered:** 2026-06-17
**Impact:** Login de usuário novo pode dar HTTP 500 (`{}`) por tokens NULL no GoTrue.
**Workaround:** Diagnóstico via REST `/auth/v1/token`; documentado.
**Resolution:** Criar `migrations/009_fix_auth_null_tokens.sql` e rodar no Supabase Studio (precisa service role/senha PG — indisponível no dev).

---

## Lessons Learned

### L-001: Não editar workflow JSON com ConvertTo-Json no PS5.1

**Context:** Workflows com `[` no nome.
**Problem:** `ConvertTo-Json -Depth` trava/pendura.
**Solution:** Editar via Node (`JSON.parse`/`JSON.stringify(null,2)`), stripar BOM, preservar CRLF no systemMessage.
**Prevents:** Corrupção de workflow e travamento de terminal.

### L-002: `String.replace` com grupos precisa de função

**Context:** `syncLeadBreakdown` no front.
**Problem:** `String(n)+"$2"` vira `$20` (grupo 20) e quebra o texto.
**Solution:** Usar callback `(m,g1,g2)=>`.
**Prevents:** Texto de resumo corrompido.

### L-003: "Sem presença digital" e "0 clientes" são dados reais

**Context:** Cidades pequenas (Balneário Camboriú, Blumenau).
**Problem:** Pareciam bugs.
**Solution:** Provado ao vivo na API HMG — varia por cidade; DW de carteira pode ter 0.
**Prevents:** Caça a bug inexistente.

---

## Quick Tasks Completed

| #   | Description | Date | Commit | Status |
| --- | ----------- | ---- | ------ | ------ |
| —   | (nenhuma registrada via quick mode ainda) | — | — | — |

---

## Deferred Ideas

- [ ] Two-pass strict→relaxed (RF-16) — Captured during: qualidade-leads-oporttuna
- [ ] CSP nonce-based + sanitização de markdown do LLM — Captured during: brownfield mapping
- [ ] Cobertura de teste 5–10 cidades — Captured during: pipeline de leads

---

## Todos

- [ ] Criar e rodar `migrations/009_fix_auth_null_tokens.sql` (B-001 / C-SEC-1)
- [ ] Atualizar/remover Sticky Note divergente no `Sameka-Agent-IA-copy.json` (C-DEBT-1)
- [ ] Criar `scripts/_sync-front-workflow.ps1` (C-DEBT-2)
- [ ] Decidir estado canônico do `isMismatch` (C-DEBT-4)

---

## Preferences

**Model Guidance Shown:** never
