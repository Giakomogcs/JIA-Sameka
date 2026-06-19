-- =============================================================
-- Sameka — SETUP CONSOLIDADO (estado final das migrations 001–009)
-- Cole TUDO no Supabase Studio → SQL Editor → New query → Run.
-- Idempotente: pode rodar mais de uma vez sem perder dados.
-- Resolve o erro: 404 rpc/sameka_admin_list_users
-- =============================================================

-- -------------------------------------------------------------
-- 1) Helper: sameka_is_admin()  (admin + company_name='sameka')
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION sameka_is_admin()
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = auth, public
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (SELECT raw_user_meta_data->>'role' = 'admin'
            AND raw_user_meta_data->>'company_name' = 'sameka'
     FROM auth.users
     WHERE id = auth.uid()),
    false
  );
$$;

-- -------------------------------------------------------------
-- 2) list_users (estado final: role, company_name, estados, cidades)
-- -------------------------------------------------------------
DROP FUNCTION IF EXISTS sameka_admin_list_users();
CREATE OR REPLACE FUNCTION sameka_admin_list_users()
RETURNS TABLE(
  user_id      UUID,
  email        TEXT,
  full_name    TEXT,
  role         TEXT,
  company_name TEXT,
  estados      JSONB,
  cidades      JSONB,
  created_at   TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = auth, public
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  IF NOT sameka_is_admin() THEN
    RAISE EXCEPTION 'Acesso negado: apenas administradores.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
    SELECT
      u.id AS user_id,
      u.email::TEXT,
      COALESCE(u.raw_user_meta_data->>'full_name', '')::TEXT AS full_name,
      COALESCE(u.raw_user_meta_data->>'role', 'visualizador')::TEXT AS role,
      COALESCE(u.raw_user_meta_data->>'company_name', '')::TEXT AS company_name,
      COALESCE(u.raw_user_meta_data->'estados', '[]'::jsonb) AS estados,
      COALESCE(u.raw_user_meta_data->'cidades', '[]'::jsonb) AS cidades,
      u.created_at
    FROM auth.users u
    WHERE u.raw_user_meta_data->>'company_name' = 'sameka'
    ORDER BY u.created_at DESC;
END;
$$;

-- -------------------------------------------------------------
-- 3) confirm_user
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION sameka_admin_confirm_user(p_user_id UUID)
RETURNS VOID
SECURITY DEFINER
SET search_path = auth, public
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT sameka_is_admin() THEN
    RAISE EXCEPTION 'Acesso negado: apenas administradores.' USING ERRCODE = '42501';
  END IF;
  UPDATE auth.users
  SET email_confirmed_at = NOW(),
      updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

-- -------------------------------------------------------------
-- 4) update_user (estado final: role + estados/cidades JSONB)
-- -------------------------------------------------------------
DROP FUNCTION IF EXISTS sameka_admin_update_user(UUID, TEXT);
DROP FUNCTION IF EXISTS sameka_admin_update_user(UUID, TEXT, TEXT);
CREATE OR REPLACE FUNCTION sameka_admin_update_user(
  p_user_id   UUID,
  p_full_name TEXT,
  p_role      TEXT  DEFAULT NULL,
  p_estados   JSONB DEFAULT NULL,
  p_cidades   JSONB DEFAULT NULL
)
RETURNS VOID
SECURITY DEFINER
SET search_path = auth, public
LANGUAGE plpgsql
AS $$
DECLARE
  new_meta JSONB;
BEGIN
  IF NOT sameka_is_admin() THEN
    RAISE EXCEPTION 'Acesso negado: apenas administradores.' USING ERRCODE = '42501';
  END IF;
  new_meta := jsonb_build_object('full_name', p_full_name, 'company_name', 'sameka');
  IF p_role IS NOT NULL THEN
    new_meta := new_meta || jsonb_build_object('role', p_role);
  END IF;
  IF p_estados IS NOT NULL THEN
    new_meta := new_meta || jsonb_build_object('estados', p_estados);
  END IF;
  IF p_cidades IS NOT NULL THEN
    new_meta := new_meta || jsonb_build_object('cidades', p_cidades);
  END IF;
  UPDATE auth.users
  SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || new_meta,
      updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

-- -------------------------------------------------------------
-- 5) delete_user (com guard de auto-exclusão)
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION sameka_admin_delete_user(p_user_id UUID)
RETURNS VOID
SECURITY DEFINER
SET search_path = auth, public
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT sameka_is_admin() THEN
    RAISE EXCEPTION 'Acesso negado: apenas administradores.' USING ERRCODE = '42501';
  END IF;
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Você não pode excluir sua própria conta.' USING ERRCODE = '42501';
  END IF;
  DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;

-- -------------------------------------------------------------
-- 6) Backfill: carimba usuários existentes sem company_name
--    para 'sameka' (senão não aparecem no list_users).
--    ATENÇÃO: se houver usuários de OUTRO projeto no mesmo
--    Supabase, restrinja o WHERE antes de rodar.
-- -------------------------------------------------------------
UPDATE auth.users
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb)
                         || '{"company_name": "sameka"}'::jsonb,
    updated_at = NOW()
WHERE raw_user_meta_data->>'company_name' IS NULL
   OR raw_user_meta_data->>'company_name' = '';

-- -------------------------------------------------------------
-- 7) GRANTs (PostgREST só expõe o que 'authenticated' pode executar)
-- -------------------------------------------------------------
GRANT EXECUTE ON FUNCTION sameka_is_admin()                                   TO authenticated;
GRANT EXECUTE ON FUNCTION sameka_admin_list_users()                           TO authenticated;
GRANT EXECUTE ON FUNCTION sameka_admin_confirm_user(UUID)                     TO authenticated;
GRANT EXECUTE ON FUNCTION sameka_admin_update_user(UUID, TEXT, TEXT, JSONB, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION sameka_admin_delete_user(UUID)                      TO authenticated;

-- -------------------------------------------------------------
-- 8) IMPORTANTE — recarrega o cache de schema do PostgREST.
--    Sem isto, a RPC continua retornando 404 mesmo já existindo.
-- -------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
