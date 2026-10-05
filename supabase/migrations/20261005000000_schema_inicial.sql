-- =============================================================================
-- Blitz v2 — schema inicial no Supabase (PostgreSQL)
-- Origem: S3_Estrutura-Banco-de-Dados_Script-PostgreSQL.sql (v2.0, set/2026), adaptado ao Supabase Auth.
--
-- Única mudança de modelagem (decidida em 05/10/2026):
--   usuario.id passa a ser o UUID de auth.users. Saem usuario.email e usuario.senha_hash:
--   o Supabase Auth guarda o e-mail e o hash da senha (RNF-LGPD05) e não mantemos cópia (minimização, LGPD art. 6º III).
-- As decisões da seção 3 do CLAUDE.md seguem iguais (SET NULL, RESTRICT, consentimento só INSERT, PK=FK, ck_tarefa_conclusao, HAVING >= 5).
--
-- Segurança: RLS ligada em todas as tabelas. Cada usuário só enxerga as próprias linhas (RN01).
-- =============================================================================

CREATE TYPE prioridade_tarefa AS ENUM ('BAIXA', 'MEDIA', 'ALTA');
CREATE TYPE status_tarefa     AS ENUM ('BACKLOG', 'EM_ANDAMENTO', 'CONCLUIDA');
CREATE TYPE papel_usuario     AS ENUM ('USUARIO', 'GESTOR', 'ADMINISTRADOR');
CREATE TYPE tema_visual       AS ENUM ('CLARO', 'ESCURO', 'ALTO_CONTRASTE');
CREATE TYPE tamanho_fonte     AS ENUM ('PEQUENO', 'MEDIO', 'GRANDE');

-- ----------------------------------------------------------------------------
CREATE TABLE organizacao (
    id               BIGSERIAL    PRIMARY KEY,
    nome             VARCHAR(180) NOT NULL,
    licencas_totais  INTEGER      NOT NULL DEFAULT 0,
    criado_em        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_organizacao_licencas CHECK (licencas_totais >= 0)
);

CREATE TABLE usuario (
    id              UUID           PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    organizacao_id  BIGINT         NULL REFERENCES organizacao (id) ON DELETE SET NULL,
    nome            VARCHAR(180)   NOT NULL,
    papel           papel_usuario  NOT NULL DEFAULT 'USUARIO',
    ativo           BOOLEAN        NOT NULL DEFAULT TRUE,
    anonimizado_em  TIMESTAMPTZ    NULL,
    criado_em       TIMESTAMPTZ    NOT NULL DEFAULT now(),
    atualizado_em   TIMESTAMPTZ    NOT NULL DEFAULT now()
);
COMMENT ON COLUMN usuario.anonimizado_em IS 'Data da anonimizacao apos pedido de exclusao de conta (RF-LGPD04).';

CREATE TABLE consentimento (
    id                BIGSERIAL    PRIMARY KEY,
    usuario_id        UUID         NOT NULL REFERENCES usuario (id) ON DELETE CASCADE,
    versao_politica   VARCHAR(20)  NOT NULL,
    aceito_em         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    canal             VARCHAR(40)  NOT NULL DEFAULT 'WEB',
    finalidade        TEXT         NOT NULL,
    CONSTRAINT uq_consentimento_usuario_versao UNIQUE (usuario_id, versao_politica)
);
COMMENT ON TABLE consentimento IS 'Registro de consentimento exigido pelo art. 8 da LGPD. Insercao apenas, sem atualizacao.';

CREATE TABLE preferencia_acessibilidade (
    usuario_id         UUID           PRIMARY KEY REFERENCES usuario (id) ON DELETE CASCADE,
    tema               tema_visual    NOT NULL DEFAULT 'CLARO',
    tamanho_fonte      tamanho_fonte  NOT NULL DEFAULT 'MEDIO',
    reduzir_animacoes  BOOLEAN        NOT NULL DEFAULT FALSE,
    leitor_tela        BOOLEAN        NOT NULL DEFAULT FALSE,
    atualizado_em      TIMESTAMPTZ    NOT NULL DEFAULT now()
);
COMMENT ON TABLE preferencia_acessibilidade IS 'Atende UC12 e RN08. A chave primaria e a FK, garantindo cardinalidade 1:1.';

CREATE TABLE modo_concentracao (
    id                BIGSERIAL     PRIMARY KEY,
    usuario_id        UUID          NULL REFERENCES usuario (id) ON DELETE CASCADE,
    nome              VARCHAR(80)   NOT NULL,
    descricao         TEXT          NULL,
    ciclo_foco_min    SMALLINT      NOT NULL,
    ciclo_pausa_min   SMALLINT      NOT NULL,
    predefinido       BOOLEAN       NOT NULL DEFAULT FALSE,
    CONSTRAINT ck_modo_ciclo_foco  CHECK (ciclo_foco_min  BETWEEN 1 AND 240),
    CONSTRAINT ck_modo_ciclo_pausa CHECK (ciclo_pausa_min BETWEEN 0 AND 120),
    CONSTRAINT ck_modo_predefinido CHECK (
        (predefinido = TRUE AND usuario_id IS NULL)
        OR (predefinido = FALSE AND usuario_id IS NOT NULL)
    )
);

CREATE TABLE lista (
    id          BIGSERIAL    PRIMARY KEY,
    usuario_id  UUID         NOT NULL REFERENCES usuario (id) ON DELETE CASCADE,
    nome        VARCHAR(120) NOT NULL,
    posicao     INTEGER      NOT NULL DEFAULT 0,
    criado_em   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE sprint (
    id            BIGSERIAL    PRIMARY KEY,
    usuario_id    UUID         NOT NULL REFERENCES usuario (id) ON DELETE CASCADE,
    data_inicio   DATE         NOT NULL,
    data_fim      DATE         NOT NULL,
    gerada_por_ia BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT ck_sprint_periodo CHECK (data_fim >= data_inicio)
);

CREATE TABLE tarefa (
    id               BIGSERIAL          PRIMARY KEY,
    lista_id         BIGINT             NOT NULL REFERENCES lista (id)  ON DELETE CASCADE,
    sprint_id        BIGINT             NULL     REFERENCES sprint (id) ON DELETE SET NULL,
    titulo           VARCHAR(200)       NOT NULL,
    descricao        TEXT               NULL,
    prioridade       prioridade_tarefa  NOT NULL DEFAULT 'MEDIA',
    horas_estimadas  NUMERIC(5,2)       NULL,
    prazo            DATE               NULL,
    status           status_tarefa      NOT NULL DEFAULT 'BACKLOG',
    posicao          INTEGER            NOT NULL DEFAULT 0,
    concluida_em     TIMESTAMPTZ        NULL,
    criado_em        TIMESTAMPTZ        NOT NULL DEFAULT now(),
    atualizado_em    TIMESTAMPTZ        NOT NULL DEFAULT now(),
    CONSTRAINT ck_tarefa_horas CHECK (horas_estimadas IS NULL OR horas_estimadas > 0),
    CONSTRAINT ck_tarefa_conclusao CHECK (
        (status = 'CONCLUIDA' AND concluida_em IS NOT NULL)
        OR (status <> 'CONCLUIDA' AND concluida_em IS NULL)
    )
);

CREATE TABLE sessao_foco (
    id                BIGSERIAL    PRIMARY KEY,
    usuario_id        UUID         NOT NULL REFERENCES usuario (id)            ON DELETE CASCADE,
    tarefa_id         BIGINT       NULL     REFERENCES tarefa (id)             ON DELETE SET NULL,
    modo_id           BIGINT       NOT NULL REFERENCES modo_concentracao (id)  ON DELETE RESTRICT,
    inicio            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    fim               TIMESTAMPTZ  NULL,
    duracao_segundos  INTEGER      NULL,
    CONSTRAINT ck_sessao_periodo CHECK (fim IS NULL OR fim >= inicio),
    CONSTRAINT ck_sessao_duracao CHECK (duracao_segundos IS NULL OR duracao_segundos >= 0)
);
COMMENT ON TABLE sessao_foco IS 'Fonte das metricas de foco (RN03). Sessao em andamento tem fim e duracao nulos.';

CREATE TABLE conversa_ia (
    id            BIGSERIAL    PRIMARY KEY,
    usuario_id    UUID         NOT NULL REFERENCES usuario (id) ON DELETE CASCADE,
    mensagem      TEXT         NOT NULL,
    resposta      TEXT         NULL,
    tokens_usados INTEGER      NULL,
    data_hora     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_conversa_tokens CHECK (tokens_usados IS NULL OR tokens_usados >= 0)
);
COMMENT ON COLUMN conversa_ia.tokens_usados IS 'Base para o limite de uso por usuario exigido pelo RNF09.';

-- ----------------------------------------------------------------------------
-- Índices (os 9 do script original)
-- ----------------------------------------------------------------------------
CREATE INDEX idx_lista_usuario            ON lista (usuario_id, posicao);
CREATE INDEX idx_tarefa_lista             ON tarefa (lista_id, posicao);
CREATE INDEX idx_tarefa_sprint            ON tarefa (sprint_id);
CREATE INDEX idx_tarefa_prazo             ON tarefa (prazo) WHERE status <> 'CONCLUIDA';
CREATE INDEX idx_sessao_usuario_inicio    ON sessao_foco (usuario_id, inicio DESC);
CREATE INDEX idx_sessao_tarefa            ON sessao_foco (tarefa_id);
CREATE INDEX idx_conversa_usuario_data    ON conversa_ia (usuario_id, data_hora DESC);
CREATE INDEX idx_consentimento_usuario    ON consentimento (usuario_id, aceito_em DESC);
CREATE INDEX idx_usuario_organizacao      ON usuario (organizacao_id) WHERE organizacao_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- Visão agregada por organização (US-06). Equipes com menos de 5 pessoas não aparecem (reidentificação).
-- A view roda com os privilégios do dono e ignora a RLS, então fica fechada para o navegador:
-- só o painel administrativo, via Edge Function, lê esta visão.
-- ----------------------------------------------------------------------------
CREATE VIEW vw_metricas_organizacao AS
SELECT
    o.id                                          AS organizacao_id,
    o.nome                                        AS organizacao,
    COUNT(DISTINCT u.id)                          AS colaboradores,
    ROUND(AVG(s.duracao_segundos) / 60.0, 1)      AS media_minutos_por_sessao,
    COUNT(s.id)                                   AS total_sessoes
FROM organizacao o
JOIN usuario     u ON u.organizacao_id = o.id AND u.ativo = TRUE
LEFT JOIN sessao_foco s ON s.usuario_id = u.id AND s.fim IS NOT NULL
GROUP BY o.id, o.nome
HAVING COUNT(DISTINCT u.id) >= 5;
REVOKE ALL ON vw_metricas_organizacao FROM anon, authenticated;

-- ----------------------------------------------------------------------------
-- Modos predefinidos (UC05)
-- ----------------------------------------------------------------------------
INSERT INTO modo_concentracao (usuario_id, nome, descricao, ciclo_foco_min, ciclo_pausa_min, predefinido) VALUES
    (NULL, 'Pomodoro', 'Ciclos de 25 minutos de foco com 5 minutos de pausa.',     25,  5, TRUE),
    (NULL, 'Profundo', 'Bloco longo de concentração intensa, com pausa reduzida.', 50, 10, TRUE),
    (NULL, 'Relax',    'Ritmo mais leve, com pausas mais frequentes.',             20, 10, TRUE);

-- =============================================================================
-- Cadastro (UC01 + RF-LGPD01 + RNF-LGPD06)
-- Quando o Supabase Auth cria a conta, este gatilho cria o perfil, grava o consentimento e as preferências.
-- Sem aceite, o cadastro inteiro é recusado: a regra fica no banco, não só na tela.
-- A versão da política é do servidor, não do navegador, para o registro valer como prova do que foi aceito.
-- =============================================================================
CREATE FUNCTION public.registrar_novo_usuario() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    versao_vigente CONSTANT text := '1.0';   -- trocar junto com a Política de Privacidade
BEGIN
    IF coalesce((new.raw_user_meta_data ->> 'aceita_termos')::boolean, false) IS NOT TRUE THEN
        RAISE EXCEPTION 'É preciso aceitar os Termos de Uso e a Política de Privacidade.' USING ERRCODE = 'check_violation';
    END IF;

    INSERT INTO public.usuario (id, nome)
    VALUES (new.id, coalesce(nullif(trim(new.raw_user_meta_data ->> 'nome'), ''), 'Usuário'));

    INSERT INTO public.consentimento (usuario_id, versao_politica, finalidade)
    VALUES (new.id, versao_vigente,
            'Prestação do serviço Blitz: gestão de tarefas, sessões de foco e assistente de IA. '
            || 'Base legal: execução de contrato (art. 7º, V) e consentimento (art. 7º, I) da LGPD.');

    INSERT INTO public.preferencia_acessibilidade (usuario_id) VALUES (new.id);
    INSERT INTO public.lista (usuario_id, nome) VALUES (new.id, 'Minhas tarefas');
    RETURN new;
END $$;

CREATE TRIGGER trg_registrar_novo_usuario
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.registrar_novo_usuario();
REVOKE EXECUTE ON FUNCTION public.registrar_novo_usuario() FROM PUBLIC, anon, authenticated;

-- =============================================================================
-- RLS (RN01). Políticas só para "authenticated": visitante anônimo não lê nada.
-- =============================================================================
ALTER TABLE organizacao                ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuario                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE consentimento              ENABLE ROW LEVEL SECURITY;
ALTER TABLE preferencia_acessibilidade ENABLE ROW LEVEL SECURITY;
ALTER TABLE modo_concentracao          ENABLE ROW LEVEL SECURITY;
ALTER TABLE lista                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE sprint                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarefa                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessao_foco                ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversa_ia                ENABLE ROW LEVEL SECURITY;
-- organizacao: sem política => só o painel administrativo (Edge Function) acessa.

-- usuario: lê e corrige o próprio nome (RF-LGPD03). Papel, ativo e organização não são editáveis pelo navegador.
CREATE POLICY usuario_proprio_ler    ON usuario FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY usuario_proprio_editar ON usuario FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());
REVOKE UPDATE ON usuario FROM authenticated;
GRANT UPDATE (nome, atualizado_em) ON usuario TO authenticated;

-- consentimento: histórico. O navegador só lê; quem grava é o gatilho do cadastro. Sem UPDATE nem DELETE.
-- ponytail: novo aceite após mudança de política (UC11) entra como função no servidor quando a versão 1.1 existir.
CREATE POLICY consentimento_ler ON consentimento FOR SELECT TO authenticated USING (usuario_id = auth.uid());

CREATE POLICY preferencia_propria ON preferencia_acessibilidade FOR ALL TO authenticated
    USING (usuario_id = auth.uid()) WITH CHECK (usuario_id = auth.uid());

-- modos: predefinidos são de leitura para todos; personalizados pertencem ao dono.
CREATE POLICY modo_ler ON modo_concentracao FOR SELECT TO authenticated
    USING (predefinido OR usuario_id = auth.uid());
CREATE POLICY modo_proprio_inserir ON modo_concentracao FOR INSERT TO authenticated
    WITH CHECK (NOT predefinido AND usuario_id = auth.uid());
CREATE POLICY modo_proprio_editar ON modo_concentracao FOR UPDATE TO authenticated
    USING (NOT predefinido AND usuario_id = auth.uid()) WITH CHECK (NOT predefinido AND usuario_id = auth.uid());
CREATE POLICY modo_proprio_excluir ON modo_concentracao FOR DELETE TO authenticated
    USING (NOT predefinido AND usuario_id = auth.uid());

CREATE POLICY lista_propria  ON lista  FOR ALL TO authenticated USING (usuario_id = auth.uid()) WITH CHECK (usuario_id = auth.uid());
CREATE POLICY sprint_propria ON sprint FOR ALL TO authenticated USING (usuario_id = auth.uid()) WITH CHECK (usuario_id = auth.uid());

-- tarefa: dona é quem é dono da lista (e da sprint, se houver).
CREATE POLICY tarefa_propria ON tarefa FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM lista l WHERE l.id = tarefa.lista_id AND l.usuario_id = auth.uid()))
    WITH CHECK (
        EXISTS (SELECT 1 FROM lista l WHERE l.id = tarefa.lista_id AND l.usuario_id = auth.uid())
        AND (sprint_id IS NULL OR EXISTS (SELECT 1 FROM sprint s WHERE s.id = tarefa.sprint_id AND s.usuario_id = auth.uid()))
    );

CREATE POLICY sessao_propria ON sessao_foco FOR ALL TO authenticated
    USING (usuario_id = auth.uid())
    WITH CHECK (
        usuario_id = auth.uid()
        -- modo de outra pessoa não: com ON DELETE RESTRICT, isso impediria o dono de excluir o próprio modo
        AND EXISTS (SELECT 1 FROM modo_concentracao m WHERE m.id = sessao_foco.modo_id AND (m.predefinido OR m.usuario_id = auth.uid()))
        AND (tarefa_id IS NULL OR EXISTS (SELECT 1 FROM tarefa t JOIN lista l ON l.id = t.lista_id
                                          WHERE t.id = sessao_foco.tarefa_id AND l.usuario_id = auth.uid()))
    );

-- conversa_ia: o navegador só lê. Quem grava é a Edge Function, depois de checar o limite (RNF09);
-- se o navegador pudesse inserir, poderia gravar tokens_usados = 0 e burlar o limite.
CREATE POLICY conversa_ler ON conversa_ia FOR SELECT TO authenticated USING (usuario_id = auth.uid());
