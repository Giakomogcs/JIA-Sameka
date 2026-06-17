# 03 — PRD Parte 2: Qualidade dos leads Oporttuna (filtros, presença digital e ICP)

## 1. Objetivo

Fazer com que a Oporttuna devolva **menos lixo na origem**: priorizar varejo infantil, exigir/priorizar presença digital, empurrar calçado adulto para o fim e usar o ranking ICP — em vez de delegar toda a limpeza ao prompt do agente e à heurística do front.

## 2. Problema

> "Vem dado de empresas de calçado de adulto ou sem presença digital."

Hoje as chamadas `GET-Leads`/`GET-Clientes` mandam apenas `cidade/uf/limite`. A Oporttuna então devolve **a cidade inteira** (qualquer CNAE, com ou sem digital), e o filtro de perfil acontece tarde demais (prompt do agente + `isMismatch` no front), de forma frágil e inconsistente.

## 3. Estratégia em 3 camadas

| Camada | Onde | O que faz |
|--------|------|-----------|
| **A. Filtro na origem** | ✅ **AUTOMÁTICO** — API Oporttuna já aplica perfil ICP de varejo infantil Sameka, filtrando e ordenando por nota. Opcionalmente: query params `apenasNovosProspects`, `removerContatosContabeis`, `visibilidadeComercial` (two-pass). | Leads já vêm pré-qualificados (varejo infantil, ordenados por ICP maior → menor). |
| **B. Pós-processamento determinístico** | node `Filtrar Dados` (Code) dos subflows | Descarta `situacaoCadastral` inválida, calcula `perfilInfantil`/`temPresencaDigital`, rebaixa por presença digital, mapeia novos campos (`regimeTributario`, `simples`, `mei`, `tipoCNPJ`, `cep`, `idConsulta`). |
| **C. Heurística do agente/front** | system prompt + `isMismatch` | Rede de segurança final (Regra 6: tier A/B/C por sinais cruzados). |

## 4. Requisitos funcionais

### 4.1 Camada A — filtro na origem (Oporttuna)

| ID | Requisito |
|----|-----------|
| RF-10 | (OPCIONAL) As chamadas podem enviar `filtro` (JSON URL-encoded) com `visibilidadeComercial` incluindo presença digital (ex.: `["REDES_SOCIAIS","SITES","TELEFONES","PRESENCA_DIGITAL"]`) para afinar ainda mais. |
| RF-11 | ~~As chamadas devem enviar `palavrasChaveQualificacao` de varejo infantil~~ **REDUNDANTE** — a API Oporttuna já aplica automaticamente o perfil ICP de varejo infantil cadastrado para a Sameka, filtrando e ordenando por nota ICP (maior → menor). Não requer header `x-perfil-icp-id` explícito. |
| RF-12 | ~~`palavrasChaveDesqualificacao`~~ **REDUNDANTE** pelo mesmo motivo. |
| RF-13 | ~~enviar header `x-perfil-icp-id`~~ **NÃO NECESSÁRIO** — o perfil ICP é reconhecido automaticamente via token/tenant da Sameka. O retorno já vem filtrado e ordenado por ICP. |
| RF-14 | ~~`ramoAtividade` (CNAE)~~ **REDUNDANTE** — coberto pelo perfil ICP automático. |
| RF-15 | O `filtro` deve ser **parametrizável** (um único node "Montar Filtro" que constrói o JSON), não espalhado/hardcoded. |

> ⚠️ **`possuiConsultaAvancada: "SIM"` e `visibilidadeComercial` excluem empresas sem enriquecimento.** Em cidades pequenas isso pode zerar o retorno. Por isso a Camada A deve ser **estratégia de 2 passes** (RF-16).

| ID | Requisito |
|----|-----------|
| RF-16 | **Two-pass:** 1º passe com filtro estrito (digital + perfil infantil). Se `total` < limiar (ex.: 3), 2º passe relaxado (sem `visibilidadeComercial`/`possuiConsultaAvancada`, mantendo palavras-chave) para não deixar a cidade vazia. O agente sinaliza quando usou o passe relaxado. |

### 4.1.1 Parâmetros/campos de alto valor (ver doc 05 — Parte 3)

| ID | Requisito |
|----|-----------|
| RF-17 | Enviar `apenasNovosProspects: "NAO_CLIENTES"` no `filtro` do GET-Leads, para que `Consultar_Leads_Oporttuna` traga **apenas prospects que ainda não são clientes** (elimina duplicação com a carteira). |
| RF-18 | Enviar `removerContatosContabeis: true` em ambas as chamadas, para o contato vir da loja e não da contabilidade. |
| RF-19 | (Fase 2b) avaliar `filtro.porte` para descartar redes grandes na origem (requer `__FILL_ME__OPORTTUNA_PORTE_SK__`). |

### 4.2 Camada B — pós-processamento determinístico (`Filtrar Dados`)

| ID | Requisito |
|----|-----------|
| RF-20 | Descartar empresas com `situacaoCadastral ∈ {BAIXADA, INAPTA, SUSPENSA, NULA}`. |
| RF-21 | Classificar `perfilInfantil` (boolean) por nome/CNAE usando listas de qualificação/desqualificação; calçado adulto explícito → `perfilInfantil=false`. |
| RF-22 | Marcar `temPresencaDigital` = `possuiPresencaDigital === "SIM" || redesSociais.length || sites.length`. |
| RF-23 | Ordenar a saída: (1) perfil infantil + digital, (2) perfil infantil sem digital, (3) demais. Nunca **apagar** silenciosamente os "demais" — apenas rebaixar e anotar o motivo, deixando o teto final para o agente/Regra 6. |
| RF-25 | **Mapear `situacaoCadastral` também no GET-Leads** (hoje só o GET-Clientes mapeia) e aplicar o descarte de RF-20 aos prospects da Oporttuna (ver doc 05 §3.1). |
| RF-26 | Passar adiante os campos de qualificação hoje descartados: `regimeTributario`, `simples`, `mei`, `tipoCNPJ` (GET-Leads), `cep` (GET-Leads). Passe literal, sem inventar valores (ver doc 05 §3). |
| RF-27 | (Opcional, descarte) remover prospects com `tipoCNPJ == "CPF"` (pessoa física, sem loja formal) — confirmar com o usuário. |
| RF-28 | Incluir `idConsulta` da resposta da API no envelope `{ok,...}` como metadado de rastreabilidade (ver doc 05 §3.5). |
| RF-24 | A normalização de empresas "antigas" (campo `dataAbertura` muito antigo) **não** deve descartar por idade — loja antiga pode ser ótimo cliente. "Empresas antigas" do chamado se refere a **cadastro desatualizado** (resolvido na Parte 1), não a data de fundação. (Validar com o usuário — ver §7.) |

### 4.3 Camada C — agente/front (ajuste leve)

| ID | Requisito |
|----|-----------|
| RF-30 | O system prompt passa a confiar que a Oporttuna já vem pré-filtrada; mantém a Regra 6 (ranking TOP 1 / TOP 20) e o teto de "sem digital". |
| RF-31 | `MISMATCH_KEYWORDS`/`VAREJO_INFANTIL_KEYWORDS` no `front-sameka.html` permanecem como rede de segurança; nenhuma keyword nova obrigatória, mas alinhar com as listas da Camada B para evitar divergência. |

## 5. Requisitos não-funcionais

| ID | Requisito |
|----|-----------|
| RNF-10 | Toda sintaxe nova da API Oporttuna (formato exato do `filtro`, enums de `visibilidadeComercial`) deve seguir `openapi-inteligencia-negocio.yaml`. Se algum SK/valor não estiver documentado, usar `__FILL_ME__`. |
| RNF-11 | As listas de palavras-chave ficam num único ponto (node "Montar Filtro" + listas no `Filtrar Dados`), versionadas, para fácil ajuste comercial. |
| RNF-12 | A chamada deve degradar com elegância (two-pass) — nunca derrubar o roteiro por excesso de filtro. |

## 6. Critérios de aceite

- [ ] Numa cidade média, o roteiro não traz nenhuma loja de calçado **adulto** explícita no topo (tier A/B). ✅ **GARANTIDO** pelo perfil ICP automático da Oporttuna.
- [ ] ≥ 2/3 dos cards do tier A/B têm presença digital (`redesSociais`/`sites`/`possuiPresencaDigital=SIM`). ← Requer Camada B (cálculo `temPresencaDigital` + rebaixamento).
- [ ] Prospects (fonte=`oporttuna`) não incluem clientes ativos. ← Requer RF-17 (`apenasNovosProspects=NAO_CLIENTES` no GET-Leads).
- [ ] Nenhum lead com `situacaoCadastral ∈ {BAIXADA,INAPTA,SUSPENSA,NULA}`. ← Requer RF-25 (mapear `situacaoCadastral` no GET-Leads + descarte).
- [ ] Empresas `BAIXADA/INAPTA/SUSPENSA` não aparecem.
- [ ] Em cidade pequena/sem digital, o roteiro ainda retorna algo (two-pass), com aviso de que a maioria não tem digital mapeada.
- [ ] `notaICP`/`classificacaoICP` chegam preenchidas quando o `x-perfil-icp-id` é enviado (se a Oporttuna fornecer o ICP).

## 7. Decisões em aberto (confirmar com o usuário)

1. **`x-perfil-icp-id`:** existe um perfil ICP de varejo infantil cadastrado na Oporttuna? Se sim, qual o ID? (sem ele, ficamos só com a heurística do agente).
2. **CNAEs (RF-14):** vale a pena restringir por CNAE? Precisamos dos `atividadeEconomicaSk` da Oporttuna. Pode ser fase 2.
3. **"Empresas antigas" (RF-24):** confirma que o incômodo é **cadastro desatualizado** (Parte 1) e **não** filtrar por data de fundação? Ou você também quer descartar empresas fundadas há mais de X anos?
4. **Limiar do two-pass (RF-16):** qual o mínimo de leads aceitável antes de relaxar o filtro? (sugestão: 3).
5. **Listas de qualificação/desqualificação:** validar as palavras-chave iniciais com o time comercial.

## 8. Riscos

| Risco | Mitigação |
|-------|-----------|
| Filtro estrito zera cidades pequenas | Two-pass (RF-16) |
| `filtro` mal-formado → API ignora ou dá 400 | Validar contra `openapi-inteligencia-negocio.yaml`; testar em 3 cidades antes de ativar |
| Palavras-chave de qualificação cortam nichos válidos (ex.: "boutique") | Lista revisável (RNF-11); começar permissivo e apertar |
| ICP indisponível | Cair na heurística atual do agente (sem regressão) |
