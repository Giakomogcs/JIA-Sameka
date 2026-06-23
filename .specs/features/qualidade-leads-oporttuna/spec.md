# Qualidade de Leads Oporttuna (Enriquecimento) — Specification

> Feature ativa do M2. Base: `docs/03-PRD-qualidade-filtros-oporttuna.md` e `docs/05-enriquecimento-dados-apis.md`.
> Subflows: `[Sameka] GET-Leads.json` / `GET-Clientes.json`. Specs API: `openapi-inteligencia-negocio.yaml`.

## Problem Statement

O roteiro do representante ainda pode trazer empresas com cadastro inativo (BAIXADA/INAPTA) e ignora campos de alto valor que a API Oporttuna já retorna. Hoje o GET-Leads mapeia parte dos campos, mas não descarta cadastros inválidos em todos os caminhos nem expõe `regimeTributario`, `simples/mei`, `tipoCNPJ`, `cep`, `idConsulta`.

## Goals

- [ ] Nenhum lead com `situacaoCadastral` inválida chega ao representante.
- [ ] Campos de alto valor mapeados e disponíveis para ranking/exibição.
- [ ] Sem regressão na classificação cliente×prospect (`empresaCliente`) nem no dedup.

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Header `x-perfil-icp-id` | Redundante — ICP aplicado automaticamente via token/tenant (RF-11..14) |
| Planilhas de histórico como fonte | Eliminado em AD-001 |
| Two-pass strict→relaxed (RF-16) | Deferido (STATE.md) — avaliar após enriquecimento |
| Mudança de front/UI | Esta feature é backend (subflows) |

---

## User Stories

### P1: Descartar cadastros inválidos ⭐ MVP

**User Story**: Como representante, quero que empresas com CNPJ baixado/inapto não apareçam no roteiro, para não perder visita.

**Why P1**: Lead morto = tempo perdido em campo.

**Acceptance Criteria**:
1. WHEN o GET-Leads recebe um lead com `situacaoCadastral` em (BAIXADA, INAPTA, SUSPENSA, NULA) THEN o subflow SHALL descartá-lo antes de devolver ao agente.
2. WHEN um lead tem `tipoCNPJ=CPF` THEN o subflow SHALL descartá-lo.
3. WHEN todos os leads de uma cidade são descartados THEN o agente SHALL responder honestamente que não há empresas qualificadas (sem bloco `sameka-leads` vazio).

**Independent Test**: Probe HTTP em cidade com cadastro inativo conhecido → conferir que o lead some do output do subflow.

---

### P2: Mapear campos de alto valor

**User Story**: Como agente, quero `regimeTributario`, `simples`, `mei`, `tipoCNPJ`, `cep`, `idConsulta` no lead, para qualificar melhor.

**Why P2**: Enriquece ranking e `dicaAbordagem` sem nova chamada.

**Acceptance Criteria**:
1. WHEN o subflow GET-Leads mapeia um lead THEN SHALL incluir os campos acima quando presentes na resposta da API.
2. WHEN um campo está ausente na API THEN o subflow SHALL omitir/`null` sem quebrar o schema.
3. WHEN o lead chega ao front THEN os campos novos SHALL ser preservados (não descartados em `_normalizeLead`).

**Independent Test**: Probe HTTP → inspecionar JSON do subflow contém os novos campos.

---

### P3: Sinalizar enriquecimento no resultado

**User Story**: Como representante, quero ver de leve quando o regime/porte favorece a abordagem.

**Why P3**: Nice-to-have; depende de P2.

**Acceptance Criteria**:
1. WHEN um lead tem `simples=true` ou `mei=true` THEN o agente PODE refletir isso na `dicaAbordagem`.

---

## Edge Cases

- WHEN a API Oporttuna retorna `ok:false` THEN o subflow SHALL propagar e o agente SHALL avisar em linguagem simples (Regra 9).
- WHEN `situacaoCadastral` vem ausente/desconhecida THEN o subflow SHALL manter o lead (não descartar por falta de dado).
- WHEN o descarte zera a lista mas a carteira tem clientes THEN o roteiro SHALL exibir só clientes (modo ambos).

---

## Requirement Traceability

| ID | Requisito | Origem | Story |
| -- | --------- | ------ | ----- |
| RF-20 | Descartar `situacaoCadastral` inválida | docs/03, docs/05 | P1 |
| RF-25 | Mapear `situacaoCadastral` no GET-Leads | docs/05 | P1 |
| RF-26 | Mapear `regimeTributario`/`simples`/`mei`/`tipoCNPJ`/`cep`/`idConsulta` | docs/05 | P2 |
| RF-17 | `apenasNovosProspects=NAO_CLIENTES` | docs/03 | ✅ já implementado |
| RF-18 | `removerContatosContabeis=true` (ambos) | docs/03 | ✅ já implementado |

## Status

IN PROGRESS — RF-17/RF-18 concluídos; RF-20/25/26 pendentes (ver STATE.md / CONCERNS C-PROD-1).
