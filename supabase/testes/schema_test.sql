-- Checagem do schema e da RLS num PostgreSQL puro (scripts/testar-schema.sh).
-- O bloco "imitação do Supabase" recria só o mínimo que a migração usa: papéis anon/authenticated,
-- auth.users, auth.uid() e os privilégios padrão que o Supabase concede no schema public.
\set ON_ERROR_STOP on
\set QUIET on

-- ---------- imitação do Supabase ----------
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY, raw_user_meta_data jsonb);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
  $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
GRANT USAGE ON SCHEMA public, auth TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated;

\i /migracoes/20261005000000_schema_inicial.sql

-- ---------- utilitários ----------
CREATE SCHEMA teste;
GRANT USAGE ON SCHEMA teste TO anon, authenticated;
CREATE FUNCTION teste.deve_falhar(comando text, motivo text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE comando;
  RAISE EXCEPTION 'FALHOU: % (o comando deveria ter sido recusado)', motivo USING ERRCODE = 'P0099';
EXCEPTION WHEN SQLSTATE 'P0099' THEN RAISE;
          WHEN OTHERS THEN NULL;
END $$;
CREATE FUNCTION teste.igual(obtido bigint, esperado bigint, motivo text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF obtido IS DISTINCT FROM esperado THEN RAISE EXCEPTION 'FALHOU: % (obtido %, esperado %)', motivo, obtido, esperado; END IF;
END $$;
CREATE FUNCTION teste.linhas(comando text) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE n bigint;
BEGIN EXECUTE comando; GET DIAGNOSTICS n = ROW_COUNT; RETURN n; END $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA teste TO anon, authenticated;

-- ---------- cadastro (UC01, RF-LGPD01, RNF-LGPD06) ----------
SELECT teste.deve_falhar($$INSERT INTO auth.users VALUES ('00000000-0000-0000-0000-0000000000ff', '{"nome":"Sem aceite"}')$$,
                         'cadastro sem aceite dos termos');
INSERT INTO auth.users VALUES ('00000000-0000-0000-0000-00000000000a', '{"nome":"Pessoa A","aceita_termos":true}'),
                              ('00000000-0000-0000-0000-00000000000b', '{"nome":"Pessoa B","aceita_termos":true}');
SELECT teste.igual((SELECT count(*) FROM consentimento WHERE versao_politica = '1.0'), 2, 'consentimento gravado com a versão do servidor');
SELECT teste.igual((SELECT count(*) FROM preferencia_acessibilidade), 2, 'preferências criadas no cadastro');
SELECT teste.igual((SELECT count(*) FROM lista), 2, 'lista padrão criada no cadastro');

-- modo pessoal de B e lista de B, para os testes de isolamento
INSERT INTO modo_concentracao (usuario_id, nome, ciclo_foco_min, ciclo_pausa_min)
VALUES ('00000000-0000-0000-0000-00000000000b', 'Modo de B', 30, 5);
SELECT set_config('teste.lista_b', (SELECT id::text FROM lista WHERE usuario_id = '00000000-0000-0000-0000-00000000000b'), false);
SELECT set_config('teste.modo_b',  (SELECT id::text FROM modo_concentracao WHERE nome = 'Modo de B'), false);

-- ---------- como a pessoa A ----------
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);

SELECT teste.igual((SELECT count(*) FROM usuario), 1, 'A só enxerga o próprio perfil');
SELECT teste.igual((SELECT count(*) FROM lista), 1, 'A só enxerga a própria lista');
SELECT teste.igual((SELECT count(*) FROM modo_concentracao), 3, 'A vê os 3 predefinidos e não o modo de B');

UPDATE usuario SET nome = 'Pessoa A corrigida' WHERE id = auth.uid();
SELECT teste.igual((SELECT count(*) FROM usuario WHERE nome = 'Pessoa A corrigida'), 1, 'A corrige o próprio nome (RF-LGPD03)');
SELECT teste.deve_falhar($$UPDATE usuario SET papel = 'ADMINISTRADOR' WHERE id = auth.uid()$$, 'A se promover a administrador');
SELECT teste.deve_falhar($$UPDATE usuario SET ativo = true WHERE id = auth.uid()$$, 'A alterar o próprio campo ativo');

UPDATE consentimento SET versao_politica = '9.9';
DELETE FROM consentimento;
SELECT teste.igual((SELECT count(*) FROM consentimento WHERE versao_politica = '1.0'), 1, 'consentimento não muda nem some');
SELECT teste.deve_falhar($$INSERT INTO consentimento (usuario_id, versao_politica, finalidade) VALUES (auth.uid(), '2.0', 'x')$$,
                         'navegador inserir consentimento');

SELECT teste.deve_falhar($$INSERT INTO conversa_ia (usuario_id, mensagem, tokens_usados) VALUES (auth.uid(), 'oi', 0)$$,
                         'navegador gravar conversa e burlar o limite (RNF09)');
SELECT teste.deve_falhar($$SELECT * FROM vw_metricas_organizacao$$, 'navegador ler a visão B2B');
SELECT teste.igual(teste.linhas($$UPDATE modo_concentracao SET ciclo_foco_min = 1 WHERE predefinido$$), 0,
                   'A alterar modo predefinido');

SELECT teste.deve_falhar($$INSERT INTO tarefa (lista_id, titulo) VALUES (current_setting('teste.lista_b')::bigint, 'invasão')$$,
                         'A criar tarefa na lista de B');

INSERT INTO tarefa (lista_id, titulo) SELECT id, 'Escrever o capítulo 3' FROM lista;
SELECT teste.deve_falhar($$UPDATE tarefa SET status = 'CONCLUIDA'$$, 'concluir sem concluida_em (ck_tarefa_conclusao)');
UPDATE tarefa SET status = 'CONCLUIDA', concluida_em = now();

SELECT teste.deve_falhar($$INSERT INTO sessao_foco (usuario_id, modo_id) VALUES (auth.uid(), current_setting('teste.modo_b')::bigint)$$,
                         'A usar o modo pessoal de B');
INSERT INTO sessao_foco (usuario_id, modo_id, tarefa_id, fim, duracao_segundos)
SELECT auth.uid(), (SELECT id FROM modo_concentracao WHERE nome = 'Pomodoro'), (SELECT id FROM tarefa), now(), 1500;
COMMIT;

-- ---------- decisões da seção 3 ----------
DELETE FROM tarefa;
SELECT teste.igual((SELECT count(*) FROM sessao_foco WHERE tarefa_id IS NULL AND duracao_segundos = 1500), 1,
                   'apagar a tarefa preserva o tempo trabalhado (SET NULL, RN03)');
SELECT teste.deve_falhar($$DELETE FROM modo_concentracao WHERE nome = 'Pomodoro'$$, 'apagar modo com histórico (RESTRICT)');

-- ---------- visitante sem login ----------
BEGIN;
SET LOCAL ROLE anon;
SELECT teste.igual((SELECT count(*) FROM usuario) + (SELECT count(*) FROM lista) + (SELECT count(*) FROM modo_concentracao), 0,
                   'visitante sem login não lê nada (RN01)');
COMMIT;

\echo 'OK: schema e RLS passaram em todas as checagens.'
