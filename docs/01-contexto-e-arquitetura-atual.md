# 01 — Contexto e Arquitetura Atual

## 1. Visão geral do agente

O agente principal (`workspaces/Sameka-Agent-IA-copy.json`, node **AI Agent**) monta roteiros de visita para representantes de calçado infantil (marca Meow). Ele combina várias ferramentas (subflows n8n) e classifica cada empresa em tiers (TOP 1 / TOP 20 / DEMAIS) antes de emitir o bloco `sameka-leads` consumido pelo front (`front-sameka.html` → `renderLeadCards`).

## 2. As 4 fontes de leads/clientes (estado atual)

Cada item retornado carrega um campo `fonte`, e o system prompt do agente tem regras rígidas de separação ("REGRA ABSOLUTA 4 — ANTI-ALUCINAÇÃO DE LEADS E SEPARAÇÃO DE FONTES").

| Tool (nome no agente) | Workflow JSON | Origem real | Ambiente | `fonte` | Papel hoje |
|---|---|---|---|---|---|
| `Consultar_Leads_Oporttuna` | `[Sameka] GET-Leads.json` | `GET /inteligencia-negocio/leads-por-cidade` (Receita Federal / Observatório) | **HMG** (`portal-api-hmg`) | `oporttuna` | Fonte primária de prospects |
| `Consultar_Clientes_Sameka_API_Oporttuna` | `[Sameka] GET-Clientes.json` | `GET /inteligencia-negocio/sameka/leads-por-cidade` (DW da empresa) | **PROD** (`portal-api`) | `carteira_sameka` | Clientes Sameka via API |
| `Consultar_Clientes_Sameka_Carteira` | `[Sameka] GET-Clientes-Carteira-RAG.json` | Google Sheets `clientesSameka` | Drive | `planilha_sameka` | **Fallback (histórico)** |
| RAG — `Query Document Rows` | `Sameka-RAG.json` | planilhas `consulta-empresas-<UF>.xlsx` indexadas | Supabase/pgvector | `rag_sameka` | **Fallback (histórico)** |

> **"Tabela de histórico de clientes"** mencionada pelo usuário = as duas últimas linhas: a planilha `clientesSameka` (`planilha_sameka`) e as planilhas de prospect no RAG (`rag_sameka`) quando usadas **como fonte de leads**.

### Cascata de fallback atual (system prompt)
1. `Consultar_Leads_Oporttuna` + `Consultar_Clientes_Sameka_API_Oporttuna` (em paralelo) — APIs.
2. Se ambas voltarem `total=0`/`ok=false` → `Consultar_Clientes_Sameka_Carteira` (planilha).
3. Se ainda vazio → `Query Document Rows` no RAG (`consulta-empresas-<UF>.xlsx`).

## 3. Como a API Oporttuna responde

Specs no repositório:
- `openapi-inteligencia-negocio.yaml` — contrato **completo** (PROD), inclui o filtro avançado.
- `oporttuna-inteligencia-comercial.yaml` — contrato simplificado (HMG) com exemplo de retorno real.

### 3.1 Autenticação
`POST /auth/login` com `{ email, senha }` → retorna `retorno.token` (JWT). O token vai no header `Authorization: Bearer <token>`. Todas as chamadas exigem também o header `x-empresa-id` (hoje fixo `sameka`).

### 3.2 Dois endpoints de consulta

**a) Leads por cidade (Observatório / Receita Federal)**
`GET /inteligencia-negocio/leads-por-cidade?cidade=&uf=&limite=`
- Fonte: base nacional da Receita (`observatorio_dw`). Traz **qualquer** empresa ativa da cidade — inclusive fora do perfil (calçado adulto, mercados, oficinas...).
- Enriquecimento digital e ICP só vêm quando solicitados via `filtro` e `x-perfil-icp-id`.

**b) Leads por cidade (base da empresa)**
`GET /inteligencia-negocio/{empresaId}/leads-por-cidade?cidade=&uf=&limite=`
- `empresaId` = `sameka`; consulta o DW do cliente (`op_sameka_dw`): apenas CNPJs já cadastrados como clientes Sameka.
- `empresaCliente` sempre `"SIM"`. Campos como `naturezaJuridica`, `porte`, `dataAbertura`, `atividadeEconomica` podem vir `null`.

### 3.3 Parâmetros de qualidade hoje **NÃO usados**

Ambos os endpoints aceitam um query param `filtro` (JSON serializado de `FiltrosExportarEmpresa`) e o header `x-perfil-icp-id`. **Nenhum dos dois é enviado hoje** — as chamadas mandam só `cidade/uf/limite`.

Campos do `filtro` relevantes para o problema:

| Campo do `filtro` | Efeito | Uso pretendido |
|---|---|---|
| `visibilidadeComercial: [SITES, REDES_SOCIAIS, TELEFONES, EMAILS, PRESENCA_DIGITAL, IMAGENS]` | Exige presença digital em `f_dados_enriquecidos` (OR entre itens) | **Eliminar lojas sem presença digital** |
| `possuiConsultaAvancada: "SIM"` | Só empresas com enriquecimento digital | Reforça filtro digital |
| `palavrasChaveQualificacao: ["infantil","bebê","kids",...]` | Sobe no ranking quem casa no nome/razão | Priorizar varejo infantil |
| `palavrasChaveDesqualificacao: ["adulto","masculino",...]` | Rebaixa quem casa | **Empurrar calçado adulto para o fim** |
| `ramoAtividade: [{atividadeEconomicaSk}]` | Filtra por CNAE | Restringir a CNAEs de varejo de vestuário/calçado infantil |
| `removerContatosContabeis: true` | Oculta contatos contábeis compartilhados | Contato mais útil |
| `apenasNovosProspects` / `apenasProspectsIntegrados` | Recorta clientes vs. não-clientes / prospects | Segmentação |

Header `x-perfil-icp-id`: ativa o ICP (`f_analise_icp`), preenchendo `notaICP` / `classificacaoICP` / `descricaoClassificacaoICP` e ordenando por nota ICP. Hoje o agente depende da própria heurística porque o ICP raramente vem preenchido.

### 3.4 Schema de retorno (`LeadPorCidade`) — campos-chave usados a jusante
`cnpjCompleto`, `razaoSocial`, `nomeFantasia`, `situacaoCadastral`, `naturezaJuridica`, `porte`, `dataAbertura`, `atividadeEconomica`, `enderecoCompleto`, `bairro`, `cidade`, `uf`, `cep`, `telefones[]`, `emails[]`, `sites[]`, `fotos[]`, `redesSociais[]`, `possuiPresencaDigital` (`SIM`/`NAO`), `empresaCliente`, `empresaProspect`, `notaICP`, `classificacaoICP`, `descricaoClassificacaoICP`, `atividadeEconomicaSk`, `municipioSk`.

## 4. Onde a qualidade já é tratada hoje (e por que não basta)

- **`GET-Leads.json` / `GET-Clientes.json`** (node `Filtrar Dados`): só fazem `fixEncoding` e remapeiam campos. **Não filtram** perfil nem presença digital.
- **System prompt do agente** (`REGRA ABSOLUTA 4/6`): descarta `BAIXADA/INAPTA/SUSPENSA/NULA`, rebaixa sem-digital, aplica heurística de varejo infantil. Funciona, mas:
  - Depende do modelo "obedecer" o prompt → inconsistente.
  - Recebe lixo já misturado das fontes de histórico.
  - Recebe da Oporttuna o universo inteiro da cidade (sem pré-filtro digital/CNAE), então gasta contexto filtrando.
- **Front `front-sameka.html`** (`isMismatch`, `MISMATCH_KEYWORDS`, `VAREJO_INFANTIL_KEYWORDS`, `_isEncerrado`): última rede de segurança por palavra-chave. Heurística frágil e duplicada da lógica do prompt.

## 5. Conclusão do diagnóstico

Os dados ruins entram por **dois canais**:
1. **Fontes de histórico** (`planilha_sameka`, `rag_sameka`) — desatualizadas.
2. **Chamada Oporttuna sem filtros** — devolve a cidade inteira (calçado adulto, sem digital, etc.) e delega 100% da limpeza ao prompt/front.

As duas partes do PRD atacam cada canal: **Parte 1** remove o histórico como fonte; **Parte 2** transforma a Oporttuna numa fonte já filtrada e ranqueada.
