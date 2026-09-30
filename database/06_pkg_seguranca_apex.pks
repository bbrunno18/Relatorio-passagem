-- ============================================================================
-- PROJETO: CONFERÊNCIA DE DIÁRIA E PASSAGENS AÉREAS DE MOBILIZADOS
-- MÓDULO: SEGURANÇA E AUTENTICAÇÃO MULTI-USUÁRIO (ORACLE APEX 24.2+)
-- ESPECIFICAÇÃO DO PACOTE: PKG_SEGURANCA_APEX
-- ============================================================================

CREATE OR REPLACE PACKAGE PKG_SEGURANCA_APEX IS

    -- Exceções de Segurança
    EXC_USUARIO_BLOQUEADO     EXCEPTION;
    EXC_USUARIO_INATIVO       EXCEPTION;
    EXC_CREDENCIAL_INVALIDA   EXCEPTION;
    EXC_SENHA_EXPIRADA        EXCEPTION;

    -- Função principal de autenticação do Oracle APEX (Custom Authentication Scheme)
    -- Retorna TRUE se as credenciais forem válidas e o usuário estiver ativo
    FUNCTION autenticar_apex (
        p_username IN VARCHAR2,
        p_password IN VARCHAR2
    ) RETURN BOOLEAN;

    -- Função de autenticação REST para clientes Web / SPAs
    -- Retorna JSON contendo token de sessão, dados do usuário e perfil
    FUNCTION autenticar_rest (
        p_username    IN VARCHAR2,
        p_password    IN VARCHAR2,
        p_ip_cliente  IN VARCHAR2 DEFAULT NULL,
        p_user_agent  IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

    -- Validação de Token de Sessão (retorna JSON do usuário ou status INVALIDO)
    FUNCTION validar_token_sessao (
        p_token_sessao IN VARCHAR2
    ) RETURN VARCHAR2;

    -- Encerramento de Sessão (Logout)
    PROCEDURE encerrar_sessao (
        p_token_sessao IN VARCHAR2
    );

    -- Função de Autorização do Oracle APEX (Authorization Scheme)
    -- Verifica se o usuário autenticado possui o perfil requerido
    FUNCTION verificar_perfil (
        p_username         IN VARCHAR2,
        p_perfil_requerido IN VARCHAR2
    ) RETURN BOOLEAN;

    -- Criação de Novo Usuário com Hashing SHA-256 e Salt
    PROCEDURE criar_usuario (
        p_login            IN VARCHAR2,
        p_nome             IN VARCHAR2,
        p_senha            IN VARCHAR2,
        p_perfil           IN VARCHAR2,
        p_cargo            IN VARCHAR2 DEFAULT NULL,
        p_lotacao          IN VARCHAR2 DEFAULT NULL,
        p_usuario_criacao  IN VARCHAR2 DEFAULT 'ADMINISTRADOR'
    );

    -- Alteração de Senha Segura
    PROCEDURE alterar_senha (
        p_login            IN VARCHAR2,
        p_senha_atual      IN VARCHAR2,
        p_nova_senha       IN VARCHAR2
    );

    -- Bloqueio / Desbloqueio de Usuário
    PROCEDURE alterar_status_usuario (
        p_login            IN VARCHAR2,
        p_ativo            IN CHAR,
        p_bloqueado        IN CHAR
    );

    -- Listagem de Usuários em formato JSON
    FUNCTION listar_usuarios_json RETURN VARCHAR2;

END PKG_SEGURANCA_APEX;
/
