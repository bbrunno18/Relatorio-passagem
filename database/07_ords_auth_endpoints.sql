-- ============================================================================
-- PROJETO: TRVSEG - CONFERÊNCIA DE PASSAGENS E AUDITORIA DE VIAGENS
-- MÓDULO: SERVIÇOS ORDS REST DE AUTENTICAÇÃO E GESTÃO DE USUÁRIOS
-- COMPATIBILIDADE: Oracle REST Data Services (ORDS 23.x / 24.x)
-- ============================================================================

PROMPT ===================================================
PROMPT HABILITANDO ENDPOINTS REST DE AUTENTICAÇÃO NO ORDS
PROMPT ===================================================

BEGIN
    -- 1. Endpoint: POST /ords/trvseg/auth/login
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'trvseg.conferencia',
        p_pattern        => 'auth/login',
        p_priority       => 0,
        p_etag_type      => 'HASH',
        p_etag_query     => NULL,
        p_comments       => 'Endpoint para autenticação de usuários multi-perfil'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'trvseg.conferencia',
        p_pattern        => 'auth/login',
        p_method         => 'POST',
        p_source_type    => 'plsql/block',
        p_mimes_allowed  => 'application/json',
        p_comments       => 'Valida credenciais e gera token de sessão',
        p_source         => q'[
            DECLARE
                v_body       CLOB;
                v_username   VARCHAR2(100);
                v_password   VARCHAR2(100);
                v_resultado  VARCHAR2(4000);
            BEGIN
                v_body := :body_text;
                
                -- Extrai parâmetros do JSON de entrada
                APEX_JSON.PARSE(v_body);
                v_username := APEX_JSON.GET_VARCHAR2(p_path => 'username');
                v_password := APEX_JSON.GET_VARCHAR2(p_path => 'password');

                -- Executa autenticação segura
                v_resultado := PKG_SEGURANCA_APEX.autenticar_rest(
                    p_username   => v_username,
                    p_password   => v_password,
                    p_ip_cliente => OWA_UTIL.GET_CGI_ENV('REMOTE_ADDR'),
                    p_user_agent => OWA_UTIL.GET_CGI_ENV('HTTP_USER_AGENT')
                );

                -- Define resposta
                OWA_UTIL.MIME_HEADER('application/json', TRUE, 'UTF-8');
                HTP.P(v_resultado);
            EXCEPTION
                WHEN OTHERS THEN
                    OWA_UTIL.MIME_HEADER('application/json', TRUE, 'UTF-8');
                    HTP.P('{"status":"ERRO","mensagem":"Falha no processamento: ' || apex_escape.json(SQLERRM) || '"}');
            END;
        ]'
    );

    -- 2. Endpoint: POST /ords/trvseg/auth/logout
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'trvseg.conferencia',
        p_pattern        => 'auth/logout',
        p_priority       => 0,
        p_etag_type      => 'HASH',
        p_etag_query     => NULL,
        p_comments       => 'Endpoint para encerramento de sessão (Logout)'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'trvseg.conferencia',
        p_pattern        => 'auth/logout',
        p_method         => 'POST',
        p_source_type    => 'plsql/block',
        p_mimes_allowed  => 'application/json',
        p_comments       => 'Invalida o token de sessão',
        p_source         => q'[
            DECLARE
                v_body       CLOB;
                v_token      VARCHAR2(128);
            BEGIN
                v_body := :body_text;
                APEX_JSON.PARSE(v_body);
                v_token := APEX_JSON.GET_VARCHAR2(p_path => 'token');

                PKG_SEGURANCA_APEX.encerrar_sessao(v_token);

                OWA_UTIL.MIME_HEADER('application/json', TRUE, 'UTF-8');
                HTP.P('{"status":"SUCESSO","mensagem":"Sessão encerrada com sucesso."}');
            END;
        ]'
    );

    -- 3. Endpoint: GET /ords/trvseg/auth/me
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'trvseg.conferencia',
        p_pattern        => 'auth/me',
        p_priority       => 0,
        p_etag_type      => 'HASH',
        p_etag_query     => NULL,
        p_comments       => 'Consulta usuário da sessão'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'trvseg.conferencia',
        p_pattern        => 'auth/me',
        p_method         => 'GET',
        p_source_type    => 'plsql/block',
        p_comments       => 'Valida o token recebido no header Authorization ou query param',
        p_source         => q'[
            DECLARE
                v_token     VARCHAR2(128);
                v_resultado VARCHAR2(4000);
            BEGIN
                v_token := REPLACE(OWA_UTIL.GET_CGI_ENV('HTTP_AUTHORIZATION'), 'Bearer ', '');
                IF v_token IS NULL THEN
                    v_token := :token;
                END IF;

                v_resultado := PKG_SEGURANCA_APEX.validar_token_sessao(v_token);

                OWA_UTIL.MIME_HEADER('application/json', TRUE, 'UTF-8');
                HTP.P(v_resultado);
            END;
        ]'
    );

    -- 4. Endpoint: GET /ords/trvseg/usuarios
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'trvseg.conferencia',
        p_pattern        => 'usuarios',
        p_priority       => 0,
        p_etag_type      => 'HASH',
        p_etag_query     => NULL,
        p_comments       => 'Listagem de usuários do sistema'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'trvseg.conferencia',
        p_pattern        => 'usuarios',
        p_method         => 'GET',
        p_source_type    => 'plsql/block',
        p_comments       => 'Retorna usuários cadastrados em JSON',
        p_source         => q'[
            BEGIN
                OWA_UTIL.MIME_HEADER('application/json', TRUE, 'UTF-8');
                HTP.P(PKG_SEGURANCA_APEX.listar_usuarios_json());
            END;
        ]'
    );

    COMMIT;
END;
/
