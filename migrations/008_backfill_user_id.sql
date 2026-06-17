-- 008 — Backfill user_id for existing sameka_chat_message rows
-- Run once against the Supabase DB (SQL Editor → New query → Run)

-- =============================================
-- 0. Ensure the user_id column + index exist (idempotent)
--    (in case migration 007 was never applied)
-- =============================================
ALTER TABLE sameka_chat_message
  ADD COLUMN IF NOT EXISTS user_id UUID;

CREATE INDEX IF NOT EXISTS idx_chat_message_user_id
  ON sameka_chat_message (user_id);

-- =============================================
-- Extract user_id from [CONTEXTO DO USUÁRIO: ... ID="uuid"]
-- for all existing human messages that don't have user_id set
-- =============================================
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
