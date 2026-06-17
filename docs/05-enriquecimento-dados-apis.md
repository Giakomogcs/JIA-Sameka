# 05 — Enriquecimento de dados das APIs (parâmetros e campos de alto valor)

Este documento cataloga **capacidades da API Oporttuna que hoje NÃO são usadas** (ou campos retornados que são descartados antes de chegar ao agente) e que agregam robustez. Complementa o doc 03 (qualidade) e alimenta o plano (doc 04).

Base de verdade: `openapi-inteligencia-negocio.yaml` (contrato completo). Auditoria feita nos nodes `Filtrar Dados` de `[Sameka] GET-Leads.json` e `[Sameka] GET-Clientes.json`.

---

## 1. O que cada subflow já entrega hoje

| Campo | GET-Leads (`oporttuna`) | GET-Clientes (`carteira_sameka`) |
|---|:---:|:---:|
| `empresa`, `nomeFantasia`, `cnpj` | ✅ | ✅ |
| `endereco`, `bairro`, `cidade`, `uf`, `tipoLogradouro` | ✅ | ✅ |
| `cep` | ❌ | ✅ |
| `telefones`, `emails`, `sites`, `fotos`, `redesSociais` | ✅ | ✅ |
| `possuiPresencaDigital` | ✅ | ✅ |
| `atividadeEconomica`, `porte`, `dataAbertura`, `natureza` | ✅ | parcial |
| `faturamento`, `numeroFuncionarios` | ✅ | parcial |
| `empresaCliente`, `empresaProspect` | ✅ | ✅ (fixo SIM/NAO) |
| `score` (ICP: nota/classificacao/descricao) | ✅ | ✅ |
| `situacaoCadastral` | ❌ **lacuna** | ✅ |
| `tipoCNPJ` (MATRIZ/FILIAL/CPF) | ❌ | ✅ |
| `regimeTributario` | ❌ | ❌ |
| `simples`, `mei` | ❌ | ❌ |
| `atividadeEconomicaSk`, `municipioSk` | ❌ | ❌ |
| `idConsulta` (rastreio) | ❌ | ❌ |

---

## 2. Parâmetros de REQUEST não usados (alto valor)

### 2.1 `apenasNovosProspects` — separação prospect × cliente na origem ⭐ ALTO
`filtro.apenasNovosProspects ∈ {CLIENTES, NAO_CLIENTES}`.
- No endpoint **leads** (Observatório), `NAO_CLIENTES` faz a Oporttuna **excluir empresas que já são clientes Sameka**.
- **Valor:** `Consultar_Leads_Oporttuna` passa a trazer **só prospects novos**, e `Consultar_Clientes_Sameka_API_Oporttuna` traz os clientes. Isso elimina a duplicação cruzada (hoje resolvida na unha pelo `_leadDedupKey` no front e por regras de prompt) e impede apresentar um cliente ativo como "prospect frio".
- **Ação:** enviar `apenasNovosProspects: "NAO_CLIENTES"` no `filtro` do GET-Leads.

### 2.2 `removerContatosContabeis: true` — contato útil ⭐ MÉDIO
Oculta telefone/e-mail que são de contadores/contabilidade compartilhada (`f_contagem_dados_empresas`).
- **Valor:** o representante recebe o contato **da loja**, não do escritório contábil. Reduz ligação errada.

### 2.3 `porte` como filtro de origem ⭐ MÉDIO
`filtro.porte: [{PORTE_SK}]`.
- **Valor:** o próprio prompt manda "rede grande (>50 func) → REJEITAR". Filtrar por porte na origem evita gastar `limite` com redes. Requer os `PORTE_SK` da Oporttuna → `__FILL_ME__OPORTTUNA_PORTE_SK__`.
- **Cautela:** porte é heurístico; preferir rebaixar via `numeroFuncionarios`/`faturamento` a descartar cego. Tratar como **opcional / fase 2b**.

### 2.4 `ordenacao` — desempate alfabético ⭐ BAIXO
`filtro.ordenacao ∈ {NOME_FANTASIA, RAZAO_SOCIAL}`. Só afeta ordenação secundária (após ICP). Baixa prioridade.

> Já cobertos no doc 03: `visibilidadeComercial`, `possuiConsultaAvancada`, `palavrasChaveQualificacao/Desqualificacao`, `ramoAtividade` (CNAE), header `x-perfil-icp-id`.

---

## 3. Campos de RESPONSE descartados (alto valor)

### 3.1 `situacaoCadastral` no GET-Leads ⭐ ALTO (correção)
Hoje só o GET-Clientes mapeia `situacaoCadastral`. O endpoint de **leads** também devolve esse campo, mas o `Filtrar Dados` do GET-Leads **não o repassa** — então a regra do prompt "descarte BAIXADA/INAPTA/SUSPENSA/NULA" **não consegue agir em prospects** (o agente nunca recebe o campo).
- **Valor:** descartar CNPJ encerrado também entre os prospects da Oporttuna, na origem.
- **Ação:** mapear `situacaoCadastral` no GET-Leads e aplicar o descarte determinístico (RF-20 do doc 03) também aqui.

### 3.2 `regimeTributario` ⭐ MÉDIO
Ex.: `SIMPLES NACIONAL`, `LUCRO PRESUMIDO`, `LUCRO REAL`.
- **Valor:** sinal de porte/maturidade. `SIMPLES NACIONAL` combina com boutique/varejo pequeno (bom fit); `LUCRO REAL` tende a rede grande. Enriquece `dicaAbordagem` e o score.
- **Ação:** mapear `regimeTributario` em ambos os subflows (passe literal, sem inventar).

### 3.3 `simples` / `mei` ⭐ MÉDIO
Flags `SIM/NÃO`.
- **Valor:** ajuda a distinguir "MEI fantasma sem fachada" (o prompt já quer rejeitar) de loja estabelecida. Hoje o agente infere por faturamento; ter o flag direto é mais confiável.
- **Ação:** mapear `simples` e `mei`.

### 3.4 `tipoCNPJ` no GET-Leads ⭐ MÉDIO
`MATRIZ` / `FILIAL` / `CPF`.
- **Valor:** permite (opcionalmente) descartar registros `CPF` (pessoa física, sem loja formal) e tratar `FILIAL` de forma consciente. GET-Clientes já traz; GET-Leads não.
- **Ação:** mapear `tipoCNPJ` no GET-Leads.

### 3.5 `idConsulta` (envelope) ⭐ MÉDIO (observabilidade)
A resposta da API traz `idConsulta` (id do registro da consulta).
- **Valor:** rastreabilidade — logar `idConsulta` no envelope `{ok,...}` ajuda a depurar "de onde veio esse lead" e a abrir chamado com a Oporttuna. Alinhado ao contrato de tool (`n8n-tool-contract`).
- **Ação:** incluir `idConsulta` no envelope de saída (campo de metadado, não vai para o card).

### 3.6 `cep` no GET-Leads ⭐ BAIXO
GET-Clientes já traz; GET-Leads não. Útil para roteiro/geocoding futuro. Mapear por consistência.

### 3.7 `atividadeEconomicaSk` / `municipioSk` ⭐ BAIXO (habilitador)
Não têm valor direto no card, mas são **pré-requisito** para o filtro por CNAE (`ramoAtividade`, RF-14 do doc 03). Mapear agora evita retrabalho.

---

## 4. Resumo priorizado (o que vale a pena)

| # | Item | Tipo | Prioridade | Onde |
|---|------|------|:---:|------|
| 1 | `apenasNovosProspects: NAO_CLIENTES` | request | ⭐⭐⭐ | GET-Leads |
| 2 | Mapear + descartar por `situacaoCadastral` | response | ⭐⭐⭐ | GET-Leads |
| 3 | `removerContatosContabeis: true` | request | ⭐⭐ | ambos |
| 4 | Mapear `regimeTributario` | response | ⭐⭐ | ambos |
| 5 | Mapear `simples` / `mei` | response | ⭐⭐ | ambos |
| 6 | Mapear `tipoCNPJ` (GET-Leads) | response | ⭐⭐ | GET-Leads |
| 7 | `idConsulta` no envelope | response | ⭐⭐ | ambos |
| 8 | `cep` (GET-Leads) | response | ⭐ | GET-Leads |
| 9 | `atividadeEconomicaSk`/`municipioSk` | response | ⭐ | ambos |
| 10 | `porte` como filtro de origem | request | ⭐ (fase 2b) | GET-Leads |
| 11 | `ordenacao` | request | ⭐ | ambos |

## 5. Decisões em aberto (confirmar)

1. **`apenasNovosProspects: NAO_CLIENTES`** no GET-Leads: confirma que `Consultar_Leads_Oporttuna` deve trazer **somente prospects que ainda não são clientes**? (recomendado — limpa a duplicação).
2. **`tipoCNPJ = CPF`**: descartar registros de pessoa física dos prospects? (recomendado descartar).
3. **`removerContatosContabeis`**: ligar por padrão? (recomendado `true`).
4. **`porte`/CNAE por SK**: depende de obter os `PORTE_SK` / `atividadeEconomicaSk` da Oporttuna → fase 2b com `__FILL_ME__`.
