-- ============================================================================
-- PROJETO: CONFERÊNCIA DE DIÁRIA E PASSAGENS AÉREAS DE MOBILIZADOS
-- MÓDULO: SEGURANÇA E AUTENTICAÇÃO MULTI-USUÁRIO (ORACLE APEX 24.2+)
-- CORPO DO PACOTE: PKG_SEGURANCA_APEX
-- ============================================================================

CREATE OR REPLACE PACKAGE BODY PKG_SEGURANCA_APEX IS

    -- Função interna para cálculo do hash SHA-256 com salt
    FUNCTION calcular_hash_senha(
        p_senha IN VARCHAR2,
        p_salt  IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN LOWER(RAWTOHEX(STANDARD_HASH(p_senha || p_salt, 'SHA256')));
    END calcular_hash_senha;

    -- Função interna para gerar salt pseudo-aleatório
    FUNCTION gerar_salt RETURN VARCHAR2 IS
    BEGIN
        RETURN 'CONF_' || LOWER(RAWTOHEX(SYS_GUID())) || '_MJSP';
    END gerar_salt;

    -- ------------------------------------------------------------------------
    -- AUTENTICAR NO ORACLE APEX (CUSTOM AUTHENTICATION SCHEME)
    -- ------------------------------------------------------------------------
    FUNCTION autenticar_apex (
        p_username IN VARCHAR2,
        p_password IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_login         VARCHAR2(100) := LOWER(TRIM(p_username));
        v_senha_hash    VARCHAR2(128);
        v_salt          VARCHAR2(64);
        v_hash_calculado VARCHAR2(128);
        v_ativo         CHAR(1);
        v_bloqueado     CHAR(1);
        v_tentativas    NUMBER;
        v_co_usuario    NUMBER;
    BEGIN
        IF p_username IS NULL OR p_password IS NULL THEN
            RETURN FALSE;
        END IF;

        -- Busca usuário
        BEGIN
            SELECT CO_USUARIO, DS_SENHA_HASH, DS_SALT, IC_ATIVO, IC_BLOQUEADO, NU_TENTATIVAS_FALHAS
              INTO v_co_usuario, v_senha_hash, v_salt, v_ativo, v_bloqueado, v_tentativas
              FROM TB_USUARIO_SISTEMA
             WHERE NO_LOGIN = v_login;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Retorna falso sem dar pistas se o usuário existe ou não
                RETURN FALSE;
        END;

        -- Valida se o usuário está ativo e não bloqueado
        IF v_ativo <> 'S' OR v_bloqueado = 'S' THEN
            RETURN FALSE;
        END IF;

        -- Calcula o hash esperado
        v_hash_calculado := calcular_hash_senha(p_password, v_salt);

        IF v_hash_calculado = v_senha_hash THEN
            -- Sucesso: reseta tentativas e atualiza último acesso
            UPDATE TB_USUARIO_SISTEMA
               SET NU_TENTATIVAS_FALHAS = 0,
                   DH_ULTIMO_ACESSO = SYSTIMESTAMP
             WHERE CO_USUARIO = v_co_usuario;
            COMMIT;

            -- Grava trilha de auditoria
            INSERT INTO TB_AUDITORIA_CONFERENCIA (
                CO_AUDITORIA, CO_CONFERENCIA, DH_REGISTRO,
                NO_USUARIO, TP_ACAO, DS_JUSTIFICATIVA
            ) VALUES (
                SEQ_AUDITORIA_CONFERENCIA.NEXTVAL,
                NULL,
                SYSTIMESTAMP,
                v_login,
                'LOGIN_APEX_SUCESSO',
                'Autenticação efetuada com sucesso no Oracle APEX'
            );
            COMMIT;

            RETURN TRUE;
        ELSE
            -- Falha: incrementa contador de tentativas incorretas
            v_tentativas := v_tentativas + 1;
            IF v_tentativas >= 5 THEN
                UPDATE TB_USUARIO_SISTEMA
                   SET NU_TENTATIVAS_FALHAS = v_tentativas,
                       IC_BLOQUEADO = 'S'
                 WHERE CO_USUARIO = v_co_usuario;
            ELSE
                UPDATE TB_USUARIO_SISTEMA
                   SET NU_TENTATIVAS_FALHAS = v_tentativas
                 WHERE CO_USUARIO = v_co_usuario;
            END IF;
            COMMIT;

            -- Registra falha de segurança
            INSERT INTO TB_AUDITORIA_CONFERENCIA (
                CO_AUDITORIA, CO_CONFERENCIA, DH_REGISTRO,
                NO_USUARIO, TP_ACAO, DS_JUSTIFICATIVA
            ) VALUES (
                SEQ_AUDITORIA_CONFERENCIA.NEXTVAL,
                NULL,
                SYSTIMESTAMP,
                v_login,
                'LOGIN_APEX_FALHA',
                'Credencial incorreta informada para o usuário (tentativa ' || v_tentativas || ')'
            );
            COMMIT;

            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END autenticar_apex;

    -- ------------------------------------------------------------------------
    -- AUTENTICAR REST (RETORNA JSON COM TOKEN E DADOS DO USUÁRIO)
    -- ------------------------------------------------------------------------
    FUNCTION autenticar_rest (
        p_username    IN VARCHAR2,
        p_password    IN VARCHAR2,
        p_ip_cliente  IN VARCHAR2 DEFAULT NULL,
        p_user_agent  IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
        v_valido        BOOLEAN;
        v_login         VARCHAR2(100) := LOWER(TRIM(p_username));
        v_co_usuario    NUMBER;
        v_no_usuario    VARCHAR2(150);
        v_perfil        VARCHAR2(30);
        v_cargo         VARCHAR2(100);
        v_lotacao       VARCHAR2(100);
        v_token         VARCHAR2(128);
        v_json          VARCHAR2(4000);
    BEGIN
        v_valido := autenticar_apex(p_username, p_password);

        IF NOT v_valido THEN
            RETURN '{"status":"ERRO","mensagem":"Credenciais de acesso inválidas ou usuário bloqueado/inativo."}';
        END IF;

        -- Obtém dados do usuário autenticado
        SELECT CO_USUARIO, NO_USUARIO, TP_PERFIL, DS_CARGO, DS_LOTACAO
          INTO v_co_usuario, v_no_usuario, v_perfil, v_cargo, v_lotacao
          FROM TB_USUARIO_SISTEMA
         WHERE NO_LOGIN = v_login;

        -- Gera token de sessão seguro (UUID duplo)
        v_token := 'sess_tk_' || LOWER(RAWTOHEX(SYS_GUID())) || LOWER(RAWTOHEX(SYS_GUID()));

        -- Cria sessão válida por 8 horas
        INSERT INTO TB_SESSAO_USUARIO (
            CO_SESSAO, CO_USUARIO, DS_TOKEN_SESSAO,
            DH_INICIO, DH_EXPIRACAO, DS_IP_CLIENTE,
            DS_USER_AGENT, ST_SESSAO
        ) VALUES (
            SEQ_SESSAO_USUARIO.NEXTVAL,
            v_co_usuario,
            v_token,
            SYSTIMESTAMP,
            SYSTIMESTAMP + INTERVAL '8' HOUR,
            p_ip_cliente,
            SUBSTR(p_user_agent, 1, 500),
            'ATIVA'
        );
        COMMIT;

        -- Monta resposta JSON
        v_json := '{' ||
            '"status":"SUCESSO",' ||
            '"token":"' || v_token || '",' ||
            '"usuario":{' ||
                '"co_usuario":' || v_co_usuario || ',' ||
                '"login":"' || v_login || '",' ||
                '"nome":"' || v_no_usuario || '",' ||
                '"perfil":"' || v_perfil || '",' ||
                '"cargo":"' || NVL(v_cargo, '') || '",' ||
                '"lotacao":"' || NVL(v_lotacao, '') || '"' ||
            '},' ||
            '"permissoes":{' ||
                '"pode_homologar":' || CASE WHEN v_perfil IN ('ADMINISTRADOR', 'AUDITOR_SENIOR') THEN 'true' ELSE 'false' END || ',' ||
                '"pode_editar_extracao":' || CASE WHEN v_perfil IN ('ADMINISTRADOR', 'AUDITOR_SENIOR', 'OPERADOR_CONFERENCIA') THEN 'true' ELSE 'false' END || ',' ||
                '"pode_gerenciar_usuarios":' || CASE WHEN v_perfil = 'ADMINISTRADOR' THEN 'true' ELSE 'false' END ||
            '}' ||
        '}';

        RETURN v_json;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '{"status":"ERRO","mensagem":"Falha interna durante autenticação: ' || SQLERRM || '"}';
    END autenticar_rest;

    -- ------------------------------------------------------------------------
    -- VALIDAR TOKEN DE SESSÃO
    -- ------------------------------------------------------------------------
    FUNCTION validar_token_sessao (
        p_token_sessao IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_login      VARCHAR2(100);
        v_nome       VARCHAR2(150);
        v_perfil     VARCHAR2(30);
        v_expiracao  TIMESTAMP;
        v_status     VARCHAR2(20);
        v_co_usuario NUMBER;
    BEGIN
        IF p_token_sessao IS NULL THEN
            RETURN '{"status":"INVALIDO"}';
        END IF;

        SELECT s.CO_USUARIO, u.NO_LOGIN, u.NO_USUARIO, u.TP_PERFIL, s.DH_EXPIRACAO, s.ST_SESSAO
          INTO v_co_usuario, v_login, v_nome, v_perfil, v_expiracao, v_status
          FROM TB_SESSAO_USUARIO s
          JOIN TB_USUARIO_SISTEMA u ON u.CO_USUARIO = s.CO_USUARIO
         WHERE s.DS_TOKEN_SESSAO = p_token_sessao;

        IF v_status <> 'ATIVA' OR v_expiracao < SYSTIMESTAMP THEN
            UPDATE TB_SESSAO_USUARIO
               SET ST_SESSAO = 'EXPIRADA'
             WHERE DS_TOKEN_SESSAO = p_token_sessao;
            COMMIT;
            RETURN '{"status":"EXPIRADO"}';
        END IF;

        RETURN '{' ||
            '"status":"VALIDO",' ||
            '"usuario":{' ||
                '"co_usuario":' || v_co_usuario || ',' ||
                '"login":"' || v_login || '",' ||
                '"nome":"' || v_nome || '",' ||
                '"perfil":"' || v_perfil || '"' ||
            '}' ||
        '}';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN '{"status":"INVALIDO"}';
    END validar_token_sessao;

    -- ------------------------------------------------------------------------
    -- ENCERRAMENTO DE SESSÃO (LOGOUT)
    -- ------------------------------------------------------------------------
    PROCEDURE encerrar_sessao (
        p_token_sessao IN VARCHAR2
    ) IS
    BEGIN
        UPDATE TB_SESSAO_USUARIO
           SET ST_SESSAO = 'ENCERRADA',
               DH_LOGOUT = SYSTIMESTAMP
         WHERE DS_TOKEN_SESSAO = p_token_sessao;
        COMMIT;
    END encerrar_sessao;

    -- ------------------------------------------------------------------------
    -- VERIFICAÇÃO DE PERFIL / AUTORIZAÇÃO APEX
    -- ------------------------------------------------------------------------
    FUNCTION verificar_perfil (
        p_username         IN VARCHAR2,
        p_perfil_requerido IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_perfil VARCHAR2(30);
    BEGIN
        SELECT TP_PERFIL
          INTO v_perfil
          FROM TB_USUARIO_SISTEMA
         WHERE NO_LOGIN = LOWER(TRIM(p_username))
           AND IC_ATIVO = 'S'
           AND IC_BLOQUEADO = 'N';

        -- Regra hierárquica: ADMINISTRADOR atende a qualquer perfil
        IF v_perfil = 'ADMINISTRADOR' THEN
            RETURN TRUE;
        END IF;

        -- Regra hierárquica: AUDITOR_SENIOR atende OPERADOR e CONSULTA
        IF v_perfil = 'AUDITOR_SENIOR' AND p_perfil_requerido IN ('AUDITOR_SENIOR', 'OPERADOR_CONFERENCIA', 'CONSULTA') THEN
            RETURN TRUE;
        END IF;

        -- Regra: OPERADOR_CONFERENCIA atende CONSULTA
        IF v_perfil = 'OPERADOR_CONFERENCIA' AND p_perfil_requerido IN ('OPERADOR_CONFERENCIA', 'CONSULTA') THEN
            RETURN TRUE;
        END IF;

        RETURN (v_perfil = p_perfil_requerido);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END verificar_perfil;

    -- ------------------------------------------------------------------------
    -- CRIAR USUÁRIO
    -- ------------------------------------------------------------------------
    PROCEDURE criar_usuario (
        p_login            IN VARCHAR2,
        p_nome             IN VARCHAR2,
        p_senha            IN VARCHAR2,
        p_perfil           IN VARCHAR2,
        p_cargo            IN VARCHAR2 DEFAULT NULL,
        p_lotacao          IN VARCHAR2 DEFAULT NULL,
        p_usuario_criacao  IN VARCHAR2 DEFAULT 'ADMINISTRADOR'
    ) IS
        v_salt VARCHAR2(64);
        v_hash VARCHAR2(128);
    BEGIN
        v_salt := gerar_salt();
        v_hash := calcular_hash_senha(p_senha, v_salt);

        INSERT INTO TB_USUARIO_SISTEMA (
            CO_USUARIO, NO_LOGIN, NO_USUARIO, DS_EMAIL,
            DS_SENHA_HASH, DS_SALT, TP_PERFIL, IC_ATIVO,
            DS_CARGO, DS_LOTACAO, DH_CRIACAO, NO_USUARIO_CRIACAO
        ) VALUES (
            SEQ_USUARIO_SISTEMA.NEXTVAL,
            LOWER(TRIM(p_login)),
            TRIM(p_nome),
            LOWER(TRIM(p_login)),
            v_hash,
            v_salt,
            p_perfil,
            'S',
            p_cargo,
            p_lotacao,
            SYSTIMESTAMP,
            p_usuario_criacao
        );
        COMMIT;
    END criar_usuario;

    -- ------------------------------------------------------------------------
    -- ALTERAR SENHA
    -- ------------------------------------------------------------------------
    PROCEDURE alterar_senha (
        p_login            IN VARCHAR2,
        p_senha_atual      IN VARCHAR2,
        p_nova_senha       IN VARCHAR2
    ) IS
        v_valido BOOLEAN;
        v_salt   VARCHAR2(64);
        v_hash   VARCHAR2(128);
    BEGIN
        v_valido := autenticar_apex(p_login, p_senha_atual);
        IF NOT v_valido THEN
            RAISE EXC_CREDENCIAL_INVALIDA;
        END IF;

        v_salt := gerar_salt();
        v_hash := calcular_hash_senha(p_nova_senha, v_salt);

        UPDATE TB_USUARIO_SISTEMA
           SET DS_SENHA_HASH = v_hash,
               DS_SALT = v_salt,
               DH_EXPIRACAO_SENHA = (SYSDATE + 90),
               NU_TENTATIVAS_FALHAS = 0
         WHERE NO_LOGIN = LOWER(TRIM(p_login));
        COMMIT;
    END alterar_senha;

    -- ------------------------------------------------------------------------
    -- ALTERAR STATUS (ATIVO / BLOQUEADO)
    -- ------------------------------------------------------------------------
    PROCEDURE alterar_status_usuario (
        p_login            IN VARCHAR2,
        p_ativo            IN CHAR,
        p_bloqueado        IN CHAR
    ) IS
    BEGIN
        UPDATE TB_USUARIO_SISTEMA
           SET IC_ATIVO = p_ativo,
               IC_BLOQUEADO = p_bloqueado,
               NU_TENTATIVAS_FALHAS = CASE WHEN p_bloqueado = 'N' THEN 0 ELSE NU_TENTATIVAS_FALHAS END
         WHERE NO_LOGIN = LOWER(TRIM(p_login));
        COMMIT;
    END alterar_status_usuario;

    -- ------------------------------------------------------------------------
    -- LISTAGEM DE USUÁRIOS (JSON)
    -- ------------------------------------------------------------------------
    FUNCTION listar_usuarios_json RETURN VARCHAR2 IS
        v_json CLOB := '[';
        v_primeiro BOOLEAN := TRUE;
    BEGIN
        FOR r IN (
            SELECT CO_USUARIO, NO_LOGIN, NO_USUARIO, DS_EMAIL,
                   TP_PERFIL, IC_ATIVO, IC_BLOQUEADO, DS_CARGO, DS_LOTACAO,
                   TO_CHAR(DH_ULTIMO_ACESSO, 'DD/MM/YYYY HH24:MI:SS') AS DT_ACESSO
              FROM TB_USUARIO_SISTEMA
             ORDER BY NO_USUARIO
        ) LOOP
            IF NOT v_primeiro THEN
                v_json := v_json || ',';
            END IF;
            v_primeiro := FALSE;

            v_json := v_json || '{' ||
                '"co_usuario":' || r.CO_USUARIO || ',' ||
                '"login":"' || r.NO_LOGIN || '",' ||
                '"nome":"' || r.NO_USUARIO || '",' ||
                '"email":"' || r.DS_EMAIL || '",' ||
                '"perfil":"' || r.TP_PERFIL || '",' ||
                '"ativo":"' || r.IC_ATIVO || '",' ||
                '"bloqueado":"' || r.IC_BLOQUEADO || '",' ||
                '"cargo":"' || NVL(r.DS_CARGO, '') || '",' ||
                '"lotacao":"' || NVL(r.DS_LOTACAO, '') || '",' ||
                '"ultimo_acesso":"' || NVL(r.DT_ACESSO, 'Nunca acessou') || '"' ||
            '}';
        END LOOP;
        v_json := v_json || ']';

        RETURN v_json;
    END listar_usuarios_json;

END PKG_SEGURANCA_APEX;
/
