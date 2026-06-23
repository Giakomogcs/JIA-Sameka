# Sameka — Copiloto Estratégico de Vendas

**Vision:** Copiloto de IA (chat) que ajuda representantes comerciais B2B a montar roteiros de vendas com leads qualificados e consultar o catálogo de produtos.
**For:** Representantes comerciais de campo da Sameka (calçados de couro premium para bebê) e admins que gerenciam usuários/territórios/RAG.
**Solves:** Roteiros de prospecção física trazem empresas desatualizadas, fora de perfil ou sem presença digital; o representante perde tempo. O copiloto entrega leads vivos (Oporttuna), valida geografia (IBGE) e enriquece com catálogo real.

## Goals

- Entregar roteiros com leads **vivos e qualificados** (carteira ativa + prospects novos), priorizando perfil infantil + presença digital, sem repetir na mesma conversa.
- Classificação **correta** cliente×prospect (campo `empresaCliente` da API como ground truth), com texto que nunca contradiz os cards.
- Consultar catálogo/preço/política via RAG sem inventar dados.
- Servir de **template de referência** ("padrão Sameka") para clonar agentes semelhantes.

## Tech Stack

**Core:**
- Orquestração: n8n (LangChain Agent node)
- LLM: Azure OpenAI `gpt-5.4-mini` + embeddings `text-embedding-3-small`
- Banco/Auth/Vector: Supabase (Postgres + GoTrue + pgvector)
- Front: HTML + JS vanilla (Netlify ou n8n-served)

**Key dependencies:** API Oporttuna (leads/carteira), API IBGE (cidades), Google Drive/Sheets (catálogo), supabase-js, marked.js.

## Scope

**v1 includes:**
- Chat com login Supabase, sessões e histórico (CRUD).
- Roteiro de leads por cidade/UF: território autorizado, validação de cidade (IBGE), dedup, ranking, cards.
- 2 fontes de leads 100% Oporttuna: `carteira_sameka` + `oporttuna`.
- Catálogo via RAG (PDFs) + planilhas de produto/imagem.
- Admin: gestão de usuários/territórios e base RAG.

**Explicitly out of scope:**
- Comunicação com consumidor final (só uso interno do representante).
- Planilhas de histórico (`clientesSameka`, `consulta-empresas-<UF>.xlsx`) como fonte de leads.
- Suíte de testes automatizada (não existe hoje).
- E-commerce / marketing digital.

## Constraints

- Técnico: front só fala com webhooks n8n + Supabase auth; toda lógica de negócio no n8n. `service_role`/senha PG nunca no front.
- Técnico: edição de workflow JSON via Node (PS5.1 trava com `[` no nome); systemMessage com CRLF + BOM.
- Recursos: sem acesso a service role / senha PG no ambiente de dev (migrations rodam manual no Studio).
