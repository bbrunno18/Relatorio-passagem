-- ============================================================================
-- PACOTE: PKG_CHATBOT_CONFERENCIA (ESPECIFICAÇÃO)
-- OBJETIVO: Chatbot Especialista em Auditoria e Conferência de Viagens
-- SEGURANÇA: Respostas estritamente ancoradas, defesa contra Prompt Injection,
--            sem permissão de escrita/alteração automática de dados.
-- PADRÃO: Metodologia MJSP v1.3 / Oracle APEX 24.2
-- ============================================================================

CREATE OR REPLACE PACKAGE PKG_CHATBOT_CONFERENCIA AS

    -- Detecção e neutralização de tentativas de Prompt Injection
    FUNCTION FN_VERIFICAR_PROMPT_INJECTION(
        p_mensagem IN VARCHAR2
    ) RETURN BOOLEAN;

    -- Processamento da mensagem do usuário e geração de resposta fundamentada
    PROCEDURE SP_PROCESSAR_PERGUNTA(
        p_co_conferencia        IN  NUMBER,
        p_no_usuario            IN  VARCHAR2,
        p_mensagem_usuario      IN  VARCHAR2,
        p_co_item_foco          IN  NUMBER DEFAULT NULL,
        p_resposta_chatbot      OUT VARCHAR2,
        p_json_evidencias       OUT CLOB,
        p_st_processamento      OUT VARCHAR2
    );

    -- Explicação técnica de divergência para um viajante específico
    FUNCTION FN_EXPLICAR_DIVERGENCIA(
        p_co_item IN NUMBER
    ) RETURN VARCHAR2;

END PKG_CHATBOT_CONFERENCIA;
/

