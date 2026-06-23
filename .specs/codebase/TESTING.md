# Testing Infrastructure

## Test Frameworks

**Unit/Integration:** nenhum framework instalado.
**E2E:** nenhum.
**Coverage:** não medido.

> Projeto não tem suíte automatizada. Validação é **manual**: probes HTTP ao vivo nas APIs (Oporttuna/IBGE), preview do front no navegador (Live Server) e inspeção em runtime via console do navegador / Node one-liners.

## Test Organization

**Location:** n/a (sem diretório de testes).
**Naming:** n/a.
**Structure:** n/a.

## Testing Patterns

### Unit Tests
**Approach:** Inexistente. Lógica do front (`_normalizeLead`, `renderLeadCards`) é verificada com snippets Node ad-hoc (ex.: parse de objeto `{leads:[...]}` → checar telefone str→array, bool→SIM/NAO).

### Integration Tests
**Approach:** Probes HTTP manuais. Ex.: `POST /portal-api-hmg/auth/login` → pega token → `GET leads-por-cidade?cidade&uf&limite` para provar acento-sensibilidade. Login Supabase via `REST /auth/v1/token?grant_type=password` para diagnosticar 500.

### E2E Tests
**Approach:** Manual no navegador — Live Server em `http://127.0.0.1:5501/front-sameka.html`. Verifica chips de quick actions, render de cards, dedup cross-mensagem.

## Test Execution

**Commands:** não há comando de teste. Verificações usadas:
- Validar JSON do workflow: `node -e "JSON.parse(require('fs').readFileSync('<file>','utf8'))"` ou via PowerShell `ConvertFrom-Json`.
- Lint/erros front: `get_errors` do editor (HTML/JS).

**Configuration:** n/a.

## Coverage Targets

**Current:** 0% automatizado.
**Goals:** não documentado.
**Enforcement:** nenhum.

## Test Coverage Matrix

| Code Layer | Required Test Type | Location Pattern | Run Command |
| ---------- | ------------------ | ---------------- | ----------- |
| Front JS (`front-sameka.html`, `netlify/app.js`) | none (manual no browser) | n/a | Live Server preview |
| Workflows n8n (`workspaces/*.json`) | none (validação JSON + execução manual no n8n) | `workspaces/*.json` | parse JSON + "Execute Workflow" no n8n |
| Migrations SQL (`migrations/*.sql`) | none (rodar no Supabase Studio) | `migrations/*.sql` | SQL Editor (idempotente) |
| APIs externas (Oporttuna/IBGE) | none (probe HTTP manual) | n/a | `curl` / `Invoke-RestMethod` |

> Todas as camadas estão marcadas como **none** — ver gap de cobertura em CONCERNS.md.

## Parallelism Assessment

| Test Type | Parallel-Safe? | Isolation Model | Evidence |
| --------- | -------------- | --------------- | -------- |
| Manual browser | n/a | Sessão única do navegador | sem suíte |
| HTTP probe | Yes (read-only) | GET idempotente sem estado | leads/IBGE são leitura |

## Gate Check Commands

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | Após editar workflow JSON | `node -e "JSON.parse(require('fs').readFileSync('workspaces/<file>.json','utf8'))"` |
| Quick | Após editar front | `get_errors` no editor (HTML/JS) + preview Live Server |
| Full | Após mudar pipeline de leads | probe HTTP live na Oporttuna + render no front |
| Build | Antes de publicar front | conferir `netlify/*` idêntico ao monolito + `netlify.toml` (minificação OFF) |
