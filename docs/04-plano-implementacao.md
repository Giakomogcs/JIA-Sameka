# 04 — Plano de Implementação

Plano dividido em fases. Cada fase é independente e reversível. **Nada é implementado antes da confirmação das decisões em aberto** (docs 02 §6 e 03 §7).

> Constraints do repositório respeitadas em todas as fases: sem `DROP CASCADE`, sem `files.delete` no Drive, sem remover linhas do vector store, sem segredos no front, rename exaustivo ao tocar identificadores, placeholders `__FILL_ME__` para valores desconhecidos.

---

## Fase 0 — Pré-requisitos e validação (sem código)

| # | Tarefa | Entregável |
|---|--------|-----------|
| 0.1 | Confirmar decisões em aberto (ambiente HMG→PROD, desativar planilha, ICP id, CNAEs, two-pass) | Respostas registradas |
| 0.2 | Levantar `x-perfil-icp-id` e (se for usar) os `atividadeEconomicaSk` infantis junto à Oporttuna | Valores ou `__FILL_ME__` || 0.3 | Medir cobertura Oporttuna: rodar 5–10 cidades reais e contar `total` por endpoint | Planilha de cobertura |
| 0.4 | Backup dos workflows que serão tocados (`GET-Leads`, `GET-Clientes`, `Sameka-Agent-IA-copy`) | Cópias `.bak` |

**Gate:** só seguir se a cobertura Oporttuna (0.3) for aceitável; senão, manter fallback até ampliar a base.

---

## Fase 1 — Parte 1: Oporttuna como fonte única (PRD 02)

| # | Tarefa | Arquivo |
|---|--------|---------|
| 1.1 | Migrar `Consultar_Leads_Oporttuna` de `portal-api-hmg` para `portal-api` (PROD) — URLs de login e de consulta | `[Sameka] GET-Leads.json` |
| 1.2 | Remover `Consultar_Clientes_Sameka_Carteira` da cascata (decisão 02§6.2: manter subflow, tirar do prompt) | `Sameka-Agent-IA-copy.json` |
| 1.3 | No system prompt: reescrever "REGRA ABSOLUTA 4/5" para 2 fontes válidas (`oporttuna`, `carteira_sameka`); remover `planilha_sameka`/`rag_sameka` como leads | `Sameka-Agent-IA-copy.json` |
| 1.4 | No system prompt: ajustar a cascata — sem fallback de planilha/RAG; emitir mensagem "ampliando base" quando Oporttuna voltar vazio | `Sameka-Agent-IA-copy.json` |
| 1.5 | Garantir no prompt que RAG/planilhas/produtos continuam para catálogo/preço/imagem (INTENT ROUTING) | `Sameka-Agent-IA-copy.json` |
| 1.6 | (Decisão 02§6.4) mover login Oporttuna hardcoded para credencial/variável com `__FILL_ME__` | `GET-Leads.json`, `GET-Clientes.json` |

**Teste de aceite Fase 1:** docs/02 §7.

**Rollback:** restaurar `.bak`; reinserir a tool de planilha na cascata do prompt.

---

## Fase 2 — Parte 2 Camada A: filtro na origem (PRD 03)

| # | Tarefa | Arquivo |
|---|--------|---------|
| 2.1 | Adicionar node **"Montar Filtro"** (Code) que constrói o JSON `FiltrosExportarEmpresa` parametrizado (palavras-chave qualificação/desqualificação + `visibilidadeComercial`) | `GET-Leads.json`, `GET-Clientes.json` |
| 2.2 | Passar `filtro` (URL-encoded) como query param na chamada HTTP | `GET-Leads.json`, `GET-Clientes.json` |
| 2.3 | Adicionar header `x-perfil-icp-id` quando o id existir (`__FILL_ME__OPORTTUNA_PERFIL_ICP_ID__`) | `GET-Leads.json`, `GET-Clientes.json` |
| 2.4 | Implementar **two-pass** (RF-16): 1ª chamada estrita; se `total` < limiar, 2ª chamada relaxada; sinalizar `passe: "estrito"\|"relaxado"` no envelope | `GET-Leads.json`, `GET-Clientes.json` |
| 2.5 | (Opcional, fase 2b) incluir `ramoAtividade` por CNAE (`__FILL_ME__OPORTTUNA_CNAE_SK_INFANTIL__`) | `GET-Leads.json` |
| 2.6 | Incluir `apenasNovosProspects: "NAO_CLIENTES"` no `filtro` do GET-Leads (RF-17) | `GET-Leads.json` |
| 2.7 | Incluir `removerContatosContabeis: true` em ambas as chamadas (RF-18) | `GET-Leads.json`, `GET-Clientes.json` |
| 2.8 | (Fase 2b) avaliar `filtro.porte` p/ cortar redes (`__FILL_ME__OPORTTUNA_PORTE_SK__`, RF-19) | `GET-Leads.json` |

**Validação:** conferir o `filtro` montado contra `openapi-inteligencia-negocio.yaml`; testar em 3 cidades (grande, média, pequena).

**Rollback:** remover o param `filtro`/header — a chamada volta ao comportamento `cidade/uf/limite`.

---

## Fase 3 — Parte 2 Camada B: pós-processamento determinístico (PRD 03)

| # | Tarefa | Arquivo |
|---|--------|---------|
| 3.1 | No node `Filtrar Dados`: descartar `situacaoCadastral ∈ {BAIXADA,INAPTA,SUSPENSA,NULA}` (RF-20) | `GET-Leads.json`, `GET-Clientes.json` |
| 3.2 | Calcular `perfilInfantil` e `temPresencaDigital` por item (RF-21/22) com listas únicas | `GET-Leads.json`, `GET-Clientes.json` |
| 3.3 | Ordenar saída por perfil+digital sem apagar os "demais" (RF-23) | `GET-Leads.json`, `GET-Clientes.json` |
| 3.4 | Manter envelope `{ok, fonte, total, clientes/leads, error, passe}` consistente entre os subflows | ambos |

### Fase 3b — enriquecimento de campos (PRD 03 §4.1.1/4.2 + doc 05)

| # | Tarefa | Arquivo |
|---|--------|---------|
| 3b.1 | Mapear `situacaoCadastral` no GET-Leads e aplicar descarte de encerrados nos prospects (RF-25) | `GET-Leads.json` |
| 3b.2 | Mapear `regimeTributario`, `simples`, `mei` em ambos; `tipoCNPJ` e `cep` no GET-Leads (RF-26) | `GET-Leads.json`, `GET-Clientes.json` |
| 3b.3 | (Opcional) descartar prospects `tipoCNPJ == "CPF"` (RF-27) | `GET-Leads.json` |
| 3b.4 | Incluir `idConsulta` no envelope como metadado de rastreio (RF-28) | `GET-Leads.json`, `GET-Clientes.json` |
| 3b.5 | (Habilitador) mapear `atividadeEconomicaSk`/`municipioSk` p/ futuro filtro CNAE | ambos |

**Rollback:** reverter o `Filtrar Dados` ao `.bak`.

---

## Fase 4 — Camada C + limpeza do front (PRD 03)

| # | Tarefa | Arquivo |
|---|--------|---------|
| 4.1 | Ajustar system prompt: confiar na pré-filtragem; manter Regra 6 (ranking) e teto sem-digital | `Sameka-Agent-IA-copy.json` |
| 4.2 | Alinhar `MISMATCH_KEYWORDS`/`VAREJO_INFANTIL_KEYWORDS` do front com as listas da Camada B | `front-sameka.html` |
| 4.3 | Re-sincronizar front se editado: `_sync-netlify.ps1` e `_sync-front-workflow.ps1` | scripts |

> ⚠️ Se `front-sameka.html` for editado, rodar os dois scripts de sync (Netlify split + injeção no `Sameka-Front.json`) — ver skill `n8n-front-injection`.

---

## Fase 5 — Validação end-to-end e métricas

| # | Tarefa |
|---|--------|
| 5.1 | Rodar a bateria de cidades da Fase 0.3 e comparar antes/depois (% adulto, % sem digital, % baixada) |
| 5.2 | Confirmar todos os critérios de aceite de docs/02 §7 e docs/03 §6 |
| 5.3 | Validar que catálogo/preço/produto seguem funcionando (não-regressão do RAG/planilhas) |
| 5.4 | Atualizar memória do repo (`/memories/repo/`) com o desenho final |

---

## Resumo de arquivos impactados

| Arquivo | Fases |
|---------|-------|
| `workspaces/[Sameka] GET-Leads.json` | 1, 2, 3 |
| `workspaces/[Sameka] GET-Clientes.json` | 1, 2, 3 |
| `workspaces/Sameka-Agent-IA-copy.json` (system prompt) | 1, 4 |
| `front-sameka.html` (+ scripts de sync) | 4 |
| `workspaces/[Sameka] GET-Clientes-Carteira-RAG.json` | desativado na cascata (não apagado) |

## Ordem recomendada de entrega

1. **Fase 1** (impacto imediato no problema "empresas antigas") → entregar e validar isolado.
2. **Fase 2 + 3** (qualidade Oporttuna: adulto / sem digital) → entregar juntas.
3. **Fase 4 + 5** (ajuste fino + métricas).

Cada bloco é deployável de forma independente, permitindo medir o efeito de cada mudança.
