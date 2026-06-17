# Documentação — Clientes 100% Oporttuna

Conjunto de documentos para a mudança: **fonte de clientes/leads passa a ser exclusivamente a API Oporttuna**, eliminando a "tabela de histórico de clientes" (planilha `clientesSameka` e planilhas de prospect no RAG) como fonte de leads, e **melhorando a qualidade** do retorno (eliminar empresas antigas, calçado adulto e lojas sem presença digital).

> RAG, planilhas inteligentes e imagens de produtos **continuam** sendo usados — porém apenas para catálogo/preço/política/produto, **nunca** como fonte de leads ou clientes.

## Ordem de leitura

| # | Documento | Conteúdo |
|---|-----------|----------|
| 01 | [01-contexto-e-arquitetura-atual.md](01-contexto-e-arquitetura-atual.md) | Como funciona hoje: 4 fontes de leads, fluxo do agente, como a API Oporttuna responde |
| 02 | [02-PRD-fonte-unica-clientes-oporttuna.md](02-PRD-fonte-unica-clientes-oporttuna.md) | **PRD Parte 1** — tornar Oporttuna a única fonte de clientes/leads |
| 03 | [03-PRD-qualidade-filtros-oporttuna.md](03-PRD-qualidade-filtros-oporttuna.md) | **PRD Parte 2** — filtros de qualidade (presença digital, varejo infantil, ICP) |
| 05 | [05-enriquecimento-dados-apis.md](05-enriquecimento-dados-apis.md) | **PRD Parte 3** — parâmetros/campos da API de alto valor ainda não usados |
| 04 | [04-plano-implementacao.md](04-plano-implementacao.md) | Plano de implementação em fases, com checklist e rollback |

## Resumo executivo

**Problema:** o roteiro do representante traz empresas antigas, calçados adultos e lojas sem presença digital.

**Causas-raiz (duas):**
1. **Fontes de histórico** (planilha `clientesSameka` + planilhas `consulta-empresas-<UF>.xlsx` no RAG) são usadas como fonte de leads/clientes e contêm dados desatualizados.
2. **A chamada à Oporttuna é "crua"**: hoje envia apenas `cidade`, `uf` e `limite`. Não usa o parâmetro `filtro` (presença digital, CNAE, palavras-chave de qualificação/desqualificação) nem o header `x-perfil-icp-id` de ranking ICP.

**Solução:**
- **Parte 1:** desligar as fontes de histórico como origem de leads/clientes; clientes/leads = 100% Oporttuna (endpoints PROD).
- **Parte 2:** enriquecer a chamada Oporttuna com filtros de qualidade e ranking ICP, e endurecer os filtros pós-processamento.
- **Parte 3 (robustez):** aproveitar parâmetros/campos da API hoje ignorados — `apenasNovosProspects` (separa prospect novo × cliente), `situacaoCadastral` nos prospects, `regimeTributario`, `simples/mei`, `tipoCNPJ`, `idConsulta` — ver doc 05.
