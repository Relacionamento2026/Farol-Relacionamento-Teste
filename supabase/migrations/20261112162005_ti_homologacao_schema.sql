-- ONLY Farol - TESTE (tfqttlkvkwbvjynyrvfd). Reviewed additive compatibility update.
BEGIN;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS perfil text DEFAULT 'colaborador',
 ADD COLUMN IF NOT EXISTS gestor_id uuid, ADD COLUMN IF NOT EXISTS name text,
 ADD COLUMN IF NOT EXISTS foto_url text, ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.faq ADD COLUMN IF NOT EXISTS categoria text DEFAULT 'Relacionamento (RCC)',
 ADD COLUMN IF NOT EXISTS atualizado_em timestamptz DEFAULT now();
ALTER TABLE public.consultas_realizadas ADD COLUMN IF NOT EXISTS resposta_gerada text,
 ADD COLUMN IF NOT EXISTS feedback text;
CREATE TABLE public.treinamentos_unic (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), titulo text NOT NULL,
 descricao text, categoria text, url_unic text NOT NULL, icone text DEFAULT 'fa-graduation-cap',
 cor text DEFAULT 'turquesa', ordem integer DEFAULT 0, ativo boolean DEFAULT true,
 criado_em timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.certificados (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 colaborador_id uuid REFERENCES public.profiles(id), trilha_id uuid,
 emitido_em timestamptz NOT NULL DEFAULT now(), codigo text
);
CREATE SCHEMA IF NOT EXISTS farol_private;
REVOKE ALL ON SCHEMA farol_private FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $fn$
 SELECT CASE WHEN p.role='admin' THEN 'admin' WHEN p.role='avaliador' THEN 'avaliador' ELSE 'user' END
 FROM public.profiles p WHERE p.id=auth.uid() AND p.ativo='ativo' LIMIT 1;
$fn$;
REVOKE ALL ON FUNCTION public.get_my_role() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;

-- Auth creates a pending, unprivileged profile. Never trust user-editable roles.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 INSERT INTO public.profiles(id,email,nome,role,ativo,must_change_password)
 VALUES(NEW.id,NEW.email,coalesce(NEW.raw_user_meta_data->>'nome','Novo usuário'),'user','pendente',true)
 ON CONFLICT(id) DO NOTHING;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION farol_private.proteger_perfil()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $fn$
BEGIN
 IF current_user IN ('anon','authenticated') AND coalesce(public.get_my_role(),'')<>'admin' THEN
  IF NEW.role IS DISTINCT FROM OLD.role OR NEW.perfil IS DISTINCT FROM OLD.perfil
    OR NEW.ativo IS DISTINCT FROM OLD.ativo OR NEW.id IS DISTINCT FROM OLD.id
    OR NEW.gestor_id IS DISTINCT FROM OLD.gestor_id OR NEW.gestor_email IS DISTINCT FROM OLD.gestor_email
    OR NEW.avaliado IS DISTINCT FROM OLD.avaliado OR NEW.departamento IS DISTINCT FROM OLD.departamento
    OR NEW.email IS DISTINCT FROM OLD.email THEN
   RAISE EXCEPTION 'Campos de acesso exigem administração.' USING ERRCODE='42501';
  END IF;
 END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER farol_protect_profile BEFORE UPDATE ON public.profiles
 FOR EACH ROW EXECUTE FUNCTION farol_private.proteger_perfil();
DO $fn$
DECLARE tab text; pol record;
BEGIN
 FOR pol IN SELECT * FROM pg_policies WHERE schemaname='public' AND tablename IN ('profiles','avaliacoes_mensais') LOOP
  EXECUTE format('DROP POLICY %I ON public.%I',pol.policyname,pol.tablename);
 END LOOP;
 FOREACH tab IN ARRAY ARRAY['profiles','administradoras','avisos','progresso_modulos','consultas_realizadas',
 'avaliacoes_mensais','celebracoes_vistas','central_conhecimento','faq','materiais','treinamentos_unic','certificados'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',tab);
  EXECUTE format('CREATE POLICY farol_active_gate ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (public.get_my_role() IS NOT NULL) WITH CHECK (public.get_my_role() IS NOT NULL)',tab);
  EXECUTE format('CREATE POLICY farol_admin_all ON public.%I FOR ALL TO authenticated USING (public.get_my_role() = ''admin'') WITH CHECK (public.get_my_role() = ''admin'')',tab);
 END LOOP;
END $fn$;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.treinamentos_unic,public.certificados TO authenticated;
CREATE POLICY farol_training_read ON public.treinamentos_unic FOR SELECT TO authenticated USING (true);
CREATE POLICY farol_certificates_own ON public.certificados FOR SELECT TO authenticated USING (colaborador_id=auth.uid());
CREATE POLICY farol_profiles_read ON public.profiles FOR SELECT TO authenticated
 USING(id=auth.uid() OR (public.get_my_role()='avaliador' AND avaliado AND ativo='ativo'));
CREATE POLICY farol_profiles_edit_own ON public.profiles FOR UPDATE TO authenticated USING(id=auth.uid()) WITH CHECK(id=auth.uid());
CREATE POLICY farol_notes_own ON public.avaliacoes_mensais FOR SELECT TO authenticated USING(colaborador_id=auth.uid());
CREATE POLICY farol_monitor_read ON public.avaliacoes_mensais FOR SELECT TO authenticated
 USING(public.get_my_role()='avaliador' AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=colaborador_id AND p.avaliado AND p.ativo='ativo'));
CREATE POLICY farol_monitor_insert ON public.avaliacoes_mensais FOR INSERT TO authenticated
 WITH CHECK(public.get_my_role()='avaliador' AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=colaborador_id AND p.avaliado AND p.ativo='ativo'));
CREATE POLICY farol_monitor_update ON public.avaliacoes_mensais FOR UPDATE TO authenticated
 USING(public.get_my_role()='avaliador' AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=colaborador_id AND p.avaliado AND p.ativo='ativo'))
 WITH CHECK(public.get_my_role()='avaliador' AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=colaborador_id AND p.avaliado AND p.ativo='ativo'));
CREATE OR REPLACE FUNCTION public.listar_colaboradores_avaliados()
RETURNS TABLE(id uuid,email text,nome text,role text) LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $fn$
 SELECT p.id,p.email,p.nome,p.role FROM public.profiles p
 WHERE public.get_my_role() IN ('admin','avaliador') AND p.avaliado AND p.ativo='ativo' ORDER BY p.nome;
$fn$;
REVOKE ALL ON FUNCTION public.listar_colaboradores_avaliados() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.listar_colaboradores_avaliados() TO authenticated;
CREATE POLICY farol_storage_active ON storage.objects AS RESTRICTIVE FOR ALL TO authenticated
 USING(public.get_my_role() IS NOT NULL) WITH CHECK(public.get_my_role() IS NOT NULL);
CREATE POLICY farol_materials_admin ON storage.objects FOR ALL TO authenticated
 USING(bucket_id IN ('materiais','UPLOADS') AND public.get_my_role()='admin')
 WITH CHECK(bucket_id IN ('materiais','UPLOADS') AND public.get_my_role()='admin');
CREATE POLICY farol_private_files_read ON storage.objects FOR SELECT TO authenticated
 USING(bucket_id IN ('materiais','UPLOADS') AND public.get_my_role() IS NOT NULL
 AND (name NOT LIKE 'avatars/%' OR name='avatars/'||auth.uid()::text||'/avatar' OR public.get_my_role()='admin'));
CREATE POLICY farol_avatar_insert ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id='materiais' AND name='avatars/'||auth.uid()::text||'/avatar' AND public.get_my_role() IS NOT NULL);
CREATE POLICY farol_avatar_update ON storage.objects FOR UPDATE TO authenticated
 USING(bucket_id='materiais' AND name='avatars/'||auth.uid()::text||'/avatar' AND public.get_my_role() IS NOT NULL)
 WITH CHECK(bucket_id='materiais' AND name='avatars/'||auth.uid()::text||'/avatar' AND public.get_my_role() IS NOT NULL);
COMMIT;
