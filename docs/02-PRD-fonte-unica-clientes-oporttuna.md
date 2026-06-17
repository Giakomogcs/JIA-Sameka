# 02 — PRD Parte 1: Fonte única de clientes/leads = Oporttuna

## 1. Objetivo

Tornar a **API Oporttuna** a **única fonte** de clientes e leads do roteiro, removendo a "tabela de histórico de clientes" (planilha `clientesSameka` e planilhas de prospect no RAG) como origem de empresas a visitar.

RAG, planilhas inteligentes e imagens de produto **permanecem ativos**, porém com escopo restrito a catálogo/preço/política/produto — nunca como fonte de leads.

## 2. Problema

> "Hoje vem muito dado de empresas antigas." 

As fontes de fallback (`planilha_sameka` via Google Sheets `clientesSameka` e `rag_sameka` via `consulta-empresas-<UF>.xlsx`) contêm cadastros desatualizados. Mesmo sendo "fallback", elas entram no roteiro sempre que a Oporttuna volta vazia para a cidade — e trazem empresas que podem nem existir mais.

## 3. Escopo

### 3.1 Dentro do escopo
- Remover `Consultar_Clientes_Sameka_Carteira` (planilha `clientesSameka`) como fonte de leads/clientes.
- Remover o uso de `Query Document Rows` sobre `consulta-empresas-<UF>.xlsx` como fonte de leads (`fonte="rag_sameka"`).
- Ajustar o system prompt do agente: cascata, separação de fontes e mensagens de "nenhum resultado".
- Manter as duas tools Oporttuna como únicas fontes:
  - `Consultar_Leads_Oporttuna` (prospects) — **migrar para PROD** (ver §6).
  - `Consultar_Clientes_Sameka_API_Oporttuna` (clientes).

### 3.2 Fora do escopo (mas preservado)
- RAG semântico para catálogo/preço/política (`documents`, `search_knowledge_base`) — continua.
- `Consultar_Planilha_Inteligente` / `Consultar_Imagens_Produtos` (produtos) — continuam.
- Consulta IBGE (lista de cidades por UF) — continua.
- Filtros de qualidade da chamada Oporttuna → tratados na **Parte 2** (doc 03).

## 4. Requisitos funcionais

| ID | Requisito |
|----|-----------|
| RF-01 | Clientes e leads exibidos no roteiro DEVEM ter `fonte ∈ {oporttuna, carteira_sameka}`. Nenhum item com `fonte ∈ {planilha_sameka, rag_sameka}` pode aparecer como empresa a visitar. |
| RF-02 | Quando as duas tools Oporttuna voltarem `total=0`/`ok=false` para a cidade, o agente DEVE emitir a mensagem honesta de "estamos ampliando a base nesta região" e **não** cair em planilha/RAG. |
| RF-03 | RAG e planilhas continuam disponíveis para enriquecer `dicaAbordagem`, catálogo, preço, política e imagens de produto. |
| RF-04 | A separação de fontes ("REGRA ABSOLUTA 4") deve ser simplificada para 2 fontes válidas (`oporttuna`, `carteira_sameka`); referências a `planilha_sameka`/`rag_sameka` como leads devem ser removidas. |
| RF-05 | A tool `Consultar_Clientes_Sameka_Carteira` é desativada como fonte de leads (ver §6 para a estratégia de desativação). |

## 5. Requisitos não-funcionais

| ID | Requisito |
|----|-----------|
| RNF-01 | Nenhuma migração destrói dados: a planilha `clientesSameka` e os datasets do RAG **não são apagados** (podem voltar a ser úteis; só deixam de alimentar leads). |
| RNF-02 | Sem `DROP CASCADE`, sem `files.delete` no Drive, sem remover linhas do vector store (respeita hooks/Constraints do repo). |
| RNF-03 | A mudança deve ser reversível em < 1 dia (reativar a tool e restaurar o trecho do prompt). |

## 6. Decisões em aberto (precisam de confirmação do usuário)

> Estas decisões mudam o desenho; preciso da sua escolha antes de implementar.

1. **Ambiente do `Consultar_Leads_Oporttuna`:** hoje aponta para **HMG** (`portal-api-hmg`), enquanto `Consultar_Clientes_Sameka_API_Oporttuna` aponta para **PROD** (`portal-api`). Para "100% Oporttuna confiável", o esperado é **migrar GET-Leads para PROD**. Confirma?
2. **Desativar a planilha `clientesSameka` (`Consultar_Clientes_Sameka_Carteira`):**
   - (a) **Remover a tool** do agente (mais limpo); ou
   - (b) **Manter o subflow** mas removê-lo da cascata do prompt (reversível em segundos). 
   - Recomendação: **(b)**.
3. **Prospect via RAG (`consulta-empresas-<UF>.xlsx`):** confirmar que essas planilhas deixam de virar leads (continuam indexadas para busca, mas o prompt proíbe usá-las como origem de empresa a visitar).
4. **Credenciais:** o login Oporttuna hoje está **hardcoded** nos workflows (`suporte.orion@sameka.com.br` / `123456`). Recomendo mover para credencial/variável (`__FILL_ME__OPORTTUNA_EMAIL__` / `__FILL_ME__OPORTTUNA_SENHA__`). Confirma que pode entrar no escopo?

## 7. Critérios de aceite

- [ ] Em uma cidade onde a Oporttuna retorna resultados, 100% dos cards têm `fonte ∈ {oporttuna, carteira_sameka}`.
- [ ] Em uma cidade onde a Oporttuna retorna vazio, o agente exibe a mensagem de "ampliando base" e **zero** cards de planilha/RAG.
- [ ] Perguntas de catálogo/preço/produto continuam respondidas pelo RAG/planilhas normalmente.
- [ ] A planilha `clientesSameka` e os datasets do RAG continuam existindo (nada apagado).

## 8. Riscos

| Risco | Mitigação |
|-------|-----------|
| Cidades sem cobertura Oporttuna ficam sem nenhum lead | Mensagem honesta (RF-02) + métrica de cobertura por UF antes de desligar o fallback em massa |
| Login hardcoded quebra se a senha mudar | Mover para credencial (decisão §6.4) |
| Prompt longo: edições podem introduzir inconsistência | Editar em trechos pequenos e revisar a "REGRA ABSOLUTA 4/5" inteira |
