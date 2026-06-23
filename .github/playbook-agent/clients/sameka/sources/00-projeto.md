# Evidências — Projeto Sameka (levantamento inicial)

> Fonte: leitura read-only do repositório. Valores sensíveis sanitizados (placeholders) antes de irem ao `content.json`.

## 5 fatos que personalizam o playbook

| Fato | Valor (real, repo) | Onde foi achado | Vai sanitizado? |
|---|---|---|---|
| Nome + propósito da app | **Sameka — Copiloto Estratégico de Vendas** (copiloto B2B de vendas para calçados infantis em couro) | `front-sameka.html` `<title>` (linha 6) + `README.md` | Não (nome público) |
| `COMPANY_NAME` (multitenant key) | `sameka` (lowercase) | `front-sameka.html` linha 7018 → `company_name: "sameka"` | Não (chave do produto) |
| E-mail do primeiro admin | `admin@sameka.com.br` | `004_seed.ps1` `$EMAIL` | Não (convenção bootstrap) |
| Senha inicial do admin | `@Admin123` | `004_seed.ps1` `$PASSWORD` | Não (default documentado) |
| Telas principais | `loginOverlay`, `sidebar`/`sessionList`, `chatArea` (wizard de roteiro embutido) | `front-sameka.html` (IDs) | — |

## Valores que DEVEM ser sanitizados no content.json

| Real (não publicar) | Placeholder |
|---|---|
| `https://longflatworm-supabase.cloudfy.live` | `https://<SUA-INSTANCIA>-supabase.cloudfy.live` |
| `eyJhbG...` (ANON_KEY JWT real em `004_seed.ps1`) | `<SUPABASE_ANON_KEY>` |
| Subdomínio `longflatworm*` | `<SUA-INSTANCIA>` |

## Serviços externos realmente usados (detecção heurística nos workflows)

Comando: varredura de `workspaces/*.json`.

| Serviço | Usado? | Política no playbook |
|---|---|---|
| Azure OpenAI (chat `gpt-5.4-mini` + embeddings `text-embedding-3-small`) | ✅ | Reference image (não logar no Azure real) |
| OpenAI / OpenRouter / Google Gemini (modelos alternativos) | ✅ | Reference image |
| Google Drive + Google Sheets (catálogo/imagens) | ✅ | Reference image (OAuth) |
| Postgres / Supabase (auth + chat + pgvector RAG) | ✅ | Interativo (Supabase Studio) |
| n8n (LangChain Agent) | ✅ | Interativo |
| **Redis** | ❌ | NÃO documentar — nenhum nó consome |
| **MongoDB** | ❌ | NÃO documentar |
| **Microsoft Outlook** | ❌ | NÃO documentar |

## Telas do usuário (front-sameka.html)

| ID | Função | Capítulo do playbook |
|---|---|---|
| `loginOverlay` | Tela de login Supabase (e-mail + senha) | 02, 05 |
| `sidebar` / `sessionList` | Lista de conversas salvas (histórico Postgres) | 05 |
| `chatArea` | Chat com o copiloto + wizard de roteiro de visita | 05 |
| Painel admin (CRUD usuários) | Gestão de usuários por `company_name` | 02 |
