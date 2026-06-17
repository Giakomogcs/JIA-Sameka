# Correção: Sessões não aparecem no sidebar

## Problema

As sessões de chat não aparecem no sidebar porque as mensagens antigas não têm o campo `user_id` preenchido. A migration 007 adicionou a coluna e o trigger, mas não preencheu os dados retroativamente.

## Solução Rápida

### Passo 1: Acessar o Supabase Studio

1. Abra: https://longflatworm-supabase.cloudfy.live/project/_/sql/new
2. Faça login se necessário

### Passo 2: Executar a Migration 008

Copie e cole o seguinte SQL e clique em **Run**:

```sql
-- 008 — Backfill user_id for existing sameka_chat_message rows

DO $$
DECLARE
  _row RECORD;
  _content TEXT;
  _id_str TEXT;
  _uid UUID;
  _updated_count INT := 0;
BEGIN
  -- Process all human messages without user_id
  FOR _row IN
    SELECT id, session_id, message
    FROM sameka_chat_message
    WHERE user_id IS NULL
      AND message->>'type' = 'human'
  LOOP
    _content := _row.message->>'content';
    _id_str := substring(_content from 'ID="([0-9a-fA-F-]{36})"');

    IF _id_str IS NOT NULL THEN
      _uid := _id_str::UUID;

      -- Update this message
      UPDATE sameka_chat_message
      SET user_id = _uid
      WHERE id = _row.id;

      _updated_count := _updated_count + 1;

      -- Update all messages in the same session
      UPDATE sameka_chat_message
      SET user_id = _uid
      WHERE session_id = _row.session_id
        AND user_id IS NULL;
    END IF;
  END LOOP;

  RAISE NOTICE 'Backfill complete. Updated % human messages and propagated to their sessions.', _updated_count;
END $$;

-- Verify the results
SELECT
  COUNT(*) as total_messages,
  COUNT(user_id) as messages_with_user_id,
  COUNT(*) - COUNT(user_id) as messages_missing_user_id
FROM sameka_chat_message;

-- Notify PostgREST to refresh schema cache
NOTIFY pgrst, 'reload schema';
```

### Passo 3: Verificar

Após executar o SQL:

1. Recarregue a página do Sameka (F5)
2. Faça login novamente se necessário
3. As sessões devem aparecer no sidebar!

## O que a migration faz?

1. Encontra todas as mensagens humanas que não têm `user_id`
2. Extrai o UUID do contexto `[CONTEXTO DO USUÁRIO: ... ID="uuid"]`
3. Preenche o `user_id` na mensagem
4. Propaga o `user_id` para todas as outras mensagens da mesma sessão (IA, system, etc.)

## Verificação

Para confirmar que funcionou, execute no SQL Editor:

```sql
SELECT
  COUNT(*) as total_messages,
  COUNT(user_id) as messages_with_user_id,
  COUNT(*) - COUNT(user_id) as messages_missing_user_id
FROM sameka_chat_message;
```

Se `messages_missing_user_id` for 0, está tudo certo!
