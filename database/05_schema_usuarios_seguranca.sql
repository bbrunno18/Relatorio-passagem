-- ============================================================================
-- PROJETO: CONFERÊNCIA DE DIÁRIA E PASSAGENS AÉREAS DE MOBILIZADOS
-- MÓDULO: SEGURANÇA E AUTENTICAÇÃO MULTI-USUÁRIO (ORACLE DATABASE & APEX 24.2+)
-- PADRÃO: Metodologia de Padrões e Nomenclaturas de Banco de Dados MJSP v1.3
-- ============================================================================

PROMPT ===================================================
PROMPT CRIANDO SEQUENCES DE USUÁRIOS E SESSÕES (SEQ_<TABELA>)
PROMPT ===================================================

CREATE SEQUENCE SEQ_USUARIO_SISTEMA START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_SESSAO_USUARIO START WITH 1 INCREMENT BY 1 NOCACHE;

PROMPT ===================================================
PROMPT CRIANDO TABELA DE USUÁRIOS DO SISTEMA (TB_USUARIO_SISTEMA)
PROMPT ===================================================

CREATE TABLE TB_USUARIO_SISTEMA (
    CO_USUARIO              NUMBER(10)          NOT NULL,
    NO_LOGIN                VARCHAR2(100)       NOT NULL,
    NO_USUARIO              VARCHAR2(150)       NOT NULL,
    DS_EMAIL                VARCHAR2(150)       NOT NULL,
    DS_SENHA_HASH           VARCHAR2(128)       NOT NULL,
    DS_SALT                 VARCHAR2(64)        NOT NULL,
    TP_PERFIL               VARCHAR2(30)        DEFAULT 'OPERADOR_CONFERENCIA' NOT NULL,
    IC_ATIVO                CHAR(1)             DEFAULT 'S' NOT NULL,
    IC_BLOQUEADO            CHAR(1)             DEFAULT 'N' NOT NULL,
    NU_TENTATIVAS_FALHAS    NUMBER(2)           DEFAULT 0 NOT NULL,
    DS_CARGO                VARCHAR2(100),
    DS_LOTACAO              VARCHAR2(100),
    DH_ULTIMO_ACESSO        TIMESTAMP,
    DH_EXPIRACAO_SENHA      DATE                DEFAULT (SYSDATE + 90),
    DH_CRIACAO              TIMESTAMP           DEFAULT SYSTIMESTAMP NOT NULL,
    NO_USUARIO_CRIACAO      VARCHAR2(100)       DEFAULT 'SISTEMA' NOT NULL,
    CONSTRAINT PK_USUARIO_SISTEMA_CO PRIMARY KEY (CO_USUARIO),
    CONSTRAINT UK_USUARIO_LOGIN UNIQUE (NO_LOGIN),
    CONSTRAINT UK_USUARIO_EMAIL UNIQUE (DS_EMAIL),
    CONSTRAINT CK_USUARIO_ATIVO CHECK (IC_ATIVO IN ('S', 'N')),
    CONSTRAINT CK_USUARIO_BLOQUEADO CHECK (IC_BLOQUEADO IN ('S', 'N')),
    CONSTRAINT CK_USUARIO_PERFIL CHECK (TP_PERFIL IN (
        'ADMINISTRADOR', 
        'AUDITOR_SENIOR', 
        'OPERADOR_CONFERENCIA', 
        'CONSULTA'
    ))
);

COMMENT ON TABLE TB_USUARIO_SISTEMA IS 'Usuários autorizados para acesso ao sistema e Oracle APEX';
COMMENT ON COLUMN TB_USUARIO_SISTEMA.CO_USUARIO IS 'Identificador sequencial único do usuário';
COMMENT ON COLUMN TB_USUARIO_SISTEMA.NO_LOGIN IS 'Login corporativo do usuário (geralmente e-mail institucional @mj.gov.br)';
COMMENT ON COLUMN TB_USUARIO_SISTEMA.NO_USUARIO IS 'Nome completo do usuário';
COMMENT ON COLUMN TB_USUARIO_SISTEMA.DS_SENHA_HASH IS 'Hash criptográfico SHA-256 da senha combinada com salt';
COMMENT ON COLUMN TB_USUARIO_SISTEMA.DS_SALT IS 'Salt criptográfico hexadecimal aleatório único por usuário';
COMMENT ON COLUMN TB_USUARIO_SISTEMA.TP_PERFIL IS 'Papel do usuário: ADMINISTRADOR, AUDITOR_SENIOR, OPERADOR_CONFERENCIA, CONSULTA';
COMMENT ON COLUMN TB_USUARIO_SISTEMA.IC_ATIVO IS 'Situação do usuário: S (Ativo), N (Inativo)';
COMMENT ON COLUMN TB_USUARIO_SISTEMA.IC_BLOQUEADO IS 'Bloqueio por excesso de tentativas incorretas: S, N';

PROMPT ===================================================
PROMPT CRIANDO TABELA DE SESSÕES DE USUÁRIOS (TB_SESSAO_USUARIO)
PROMPT ===================================================

CREATE TABLE TB_SESSAO_USUARIO (
    CO_SESSAO               NUMBER(10)          NOT NULL,
    CO_USUARIO              NUMBER(10)          NOT NULL,
    DS_TOKEN_SESSAO         VARCHAR2(128)       NOT NULL,
    DH_INICIO               TIMESTAMP           DEFAULT SYSTIMESTAMP NOT NULL,
    DH_EXPIRACAO            TIMESTAMP           NOT NULL,
    DH_LOGOUT               TIMESTAMP,
    DS_IP_CLIENTE           VARCHAR2(50),
    DS_USER_AGENT           VARCHAR2(500),
    ST_SESSAO               VARCHAR2(20)        DEFAULT 'ATIVA' NOT NULL,
    CONSTRAINT PK_SESSAO_USUARIO_CO PRIMARY KEY (CO_SESSAO),
    CONSTRAINT UK_SESSAO_TOKEN UNIQUE (DS_TOKEN_SESSAO),
    CONSTRAINT FK_SESSAO_USUARIO FOREIGN KEY (CO_USUARIO) 
        REFERENCES TB_USUARIO_SISTEMA (CO_USUARIO) ON DELETE CASCADE,
    CONSTRAINT CK_SESSAO_STATUS CHECK (ST_SESSAO IN ('ATIVA', 'EXPIRADA', 'ENCERRADA'))
);

COMMENT ON TABLE TB_SESSAO_USUARIO IS 'Sessões autenticadas de usuários no sistema / APEX';

PROMPT ===================================================
PROMPT CRIANDO TRIGGERS DE PRIMARY KEY
PROMPT ===================================================

CREATE OR REPLACE TRIGGER TG_USUARIO_SISTEMA_I
BEFORE INSERT ON TB_USUARIO_SISTEMA
FOR EACH ROW
BEGIN
    IF :NEW.CO_USUARIO IS NULL THEN
        :NEW.CO_USUARIO := SEQ_USUARIO_SISTEMA.NEXTVAL;
    END IF;
    :NEW.NO_LOGIN := LOWER(TRIM(:NEW.NO_LOGIN));
    :NEW.DS_EMAIL := LOWER(TRIM(:NEW.DS_EMAIL));
END;
/

CREATE OR REPLACE TRIGGER TG_SESSAO_USUARIO_I
BEFORE INSERT ON TB_SESSAO_USUARIO
FOR EACH ROW
BEGIN
    IF :NEW.CO_SESSAO IS NULL THEN
        :NEW.CO_SESSAO := SEQ_SESSAO_USUARIO.NEXTVAL;
    END IF;
END;
/

PROMPT ===================================================
PROMPT CARGA INICIAL DE USUÁRIOS (SEED COM HASHES SEGUROS)
PROMPT ===================================================
-- Senhas iniciais configuradas:
-- 1. admin@mj.gov.br            -> Admin@MJ2026
-- 2. auditor.brunno@mj.gov.br   -> Auditor@MJ2026
-- 3. operador.maria@mj.gov.br   -> Operador@MJ2026
-- 4. consulta.fiscal@mj.gov.br  -> Consulta@MJ2026

-- Hash SHA-256 gerado com salt fixo de inicialização 'CONF_SALT_2026_MJSP':
-- SHA-256("Admin@MJ2026" || "CONF_SALT_2026_MJSP")    = 1be025747813a869f485760c001dc63c28f76e257dcb2140c89f74536ba90e54
-- SHA-256("Auditor@MJ2026" || "CONF_SALT_2026_MJSP")  = 792cb272932cee478781c8defe1144da1d9f0e575d544b3efa60657c2e52cc85
-- SHA-256("Operador@MJ2026" || "CONF_SALT_2026_MJSP") = da6e6236578173c06560f9b6cd8b1703101006de322b1a066f5132ebede52b3f
-- SHA-256("Consulta@MJ2026" || "CONF_SALT_2026_MJSP") = 0a039ce8468c61f996e6382c8efbb95874cd884ff54362a46b2fadb1617eaadd

INSERT INTO TB_USUARIO_SISTEMA (
    CO_USUARIO, NO_LOGIN, NO_USUARIO, DS_EMAIL, 
    DS_SENHA_HASH, DS_SALT, TP_PERFIL, IC_ATIVO, 
    DS_CARGO, DS_LOTACAO, DH_CRIACAO
) VALUES (
    SEQ_USUARIO_SISTEMA.NEXTVAL,
    'admin@mj.gov.br',
    'Administrador do Sistema',
    'admin@mj.gov.br',
    '1be025747813a869f485760c001dc63c28f76e257dcb2140c89f74536ba90e54',
    'CONF_SALT_2026_MJSP',
    'ADMINISTRADOR',
    'S',
    'Gestor de Tecnologia e Segurança',
    'DGI / SENASP / MJSP',
    SYSTIMESTAMP
);

INSERT INTO TB_USUARIO_SISTEMA (
    CO_USUARIO, NO_LOGIN, NO_USUARIO, DS_EMAIL, 
    DS_SENHA_HASH, DS_SALT, TP_PERFIL, IC_ATIVO, 
    DS_CARGO, DS_LOTACAO, DH_CRIACAO
) VALUES (
    SEQ_USUARIO_SISTEMA.NEXTVAL,
    'auditor.brunno@mj.gov.br',
    'Brunno José Rodrigues de Almeida',
    'auditor.brunno@mj.gov.br',
    '792cb272932cee478781c8defe1144da1d9f0e575d544b3efa60657c2e52cc85',
    'CONF_SALT_2026_MJSP',
    'AUDITOR_SENIOR',
    'S',
    'Auditor de Conformidade e Controle',
    'Coordenação de Prestação de Contas / MJSP',
    SYSTIMESTAMP
);

INSERT INTO TB_USUARIO_SISTEMA (
    CO_USUARIO, NO_LOGIN, NO_USUARIO, DS_EMAIL, 
    DS_SENHA_HASH, DS_SALT, TP_PERFIL, IC_ATIVO, 
    DS_CARGO, DS_LOTACAO, DH_CRIACAO
) VALUES (
    SEQ_USUARIO_SISTEMA.NEXTVAL,
    'operador.maria@mj.gov.br',
    'Maria Eduarda Vasconcelos',
    'operador.maria@mj.gov.br',
    'da6e6236578173c06560f9b6cd8b1703101006de322b1a066f5132ebede52b3f',
    'CONF_SALT_2026_MJSP',
    'OPERADOR_CONFERENCIA',
    'S',
    'Agente de Carga e Conferência',
    'Divisão de Diárias e Passagens / SENASP',
    SYSTIMESTAMP
);

INSERT INTO TB_USUARIO_SISTEMA (
    CO_USUARIO, NO_LOGIN, NO_USUARIO, DS_EMAIL, 
    DS_SENHA_HASH, DS_SALT, TP_PERFIL, IC_ATIVO, 
    DS_CARGO, DS_LOTACAO, DH_CRIACAO
) VALUES (
    SEQ_USUARIO_SISTEMA.NEXTVAL,
    'consulta.fiscal@mj.gov.br',
    'Fiscal de Controle Externo',
    'consulta.fiscal@mj.gov.br',
    '0a039ce8468c61f996e6382c8efbb95874cd884ff54362a46b2fadb1617eaadd',
    'CONF_SALT_2026_MJSP',
    'CONSULTA',
    'S',
    'Auditor Fiscal Convidado',
    'Órgão de Controle Externo',
    SYSTIMESTAMP
);

COMMIT;
