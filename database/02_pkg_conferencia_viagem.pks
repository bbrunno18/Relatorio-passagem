-- ============================================================================
-- PACOTE: PKG_CONFERENCIA_VIAGEM (ESPECIFICAÇÃO)
-- OBJETIVO: Motor de Normalização, Comparação Determinística e Revisão Humana
-- PADRÃO: Metodologia MJSP v1.3 / Oracle APEX 24.2
-- ============================================================================

CREATE OR REPLACE PACKAGE PKG_CONFERENCIA_VIAGEM AS

    -- Normalização determinística de texto (remove acentos, caixa alta, espaços extras)
    FUNCTION FN_NORMALIZA_TEXTO(
        p_texto IN VARCHAR2
    ) RETURN VARCHAR2;

    -- Mascaramento de CPF em conformidade com a LGPD (ex: ***.552.141-**)
    FUNCTION FN_MASCARAR_CPF(
        p_cpf IN VARCHAR2
    ) RETURN VARCHAR2;

    -- Mascaramento de documento geral (RG, Passaporte, etc.)
    FUNCTION FN_MASCARAR_DOCUMENTO(
        p_documento IN VARCHAR2
    ) RETURN VARCHAR2;

    -- Cálculo de similaridade percentual de Levenshtein (0.00% a 100.00%)
    FUNCTION FN_CALCULA_SIMILARIDADE(
        p_str1 IN VARCHAR2,
        p_str2 IN VARCHAR2
    ) RETURN NUMBER;

    -- Iniciação de sessão de conferência
    PROCEDURE SP_CRIAR_CONFERENCIA(
        p_no_conferencia    IN  VARCHAR2,
        p_ds_processo_sei   IN  VARCHAR2,
        p_no_usuario        IN  VARCHAR2,
        p_ds_observacoes    IN  VARCHAR2,
        p_co_conferencia    OUT NUMBER
    );

    -- Registro e validação de fonte documental importada
    PROCEDURE SP_REGISTRAR_FONTE(
        p_co_conferencia    IN  NUMBER,
        p_tp_fonte          IN  VARCHAR2,
        p_no_arquivo        IN  VARCHAR2,
        p_nu_tamanho_bytes  IN  NUMBER,
        p_ds_mime_type      IN  VARCHAR2,
        p_no_usuario        IN  VARCHAR2,
        p_co_fonte          OUT NUMBER
    );

    -- Processamento comparativo entre fontes com extração de evidências
    PROCEDURE SP_PROCESSAR_COMPARACAO_ITEM(
        p_co_conferencia        IN  NUMBER,
        p_no_passageiro_banco   IN  VARCHAR2,
        p_no_passageiro_plan    IN  VARCHAR2,
        p_no_passageiro_pdf     IN  VARCHAR2,
        p_nu_cpf_banco          IN  VARCHAR2,
        p_nu_cpf_plan           IN  VARCHAR2,
        p_nu_cpf_pdf            IN  VARCHAR2,
        p_cd_localizador_banco  IN  VARCHAR2,
        p_cd_localizador_plan   IN  VARCHAR2,
        p_cd_localizador_pdf    IN  VARCHAR2,
        p_nu_bilhete_banco      IN  VARCHAR2,
        p_nu_bilhete_plan       IN  VARCHAR2,
        p_nu_bilhete_pdf        IN  VARCHAR2,
        p_dt_ida_banco          IN  DATE,
        p_dt_ida_plan           IN  DATE,
        p_dt_ida_pdf            IN  DATE,
        p_ds_origem_ida         IN  VARCHAR2,
        p_ds_destino_ida        IN  VARCHAR2,
        p_sg_companhia          IN  VARCHAR2,
        p_vl_total              IN  NUMBER,
        p_ref_doc_pdf           IN  VARCHAR2,
        p_nu_pagina_pdf         IN  NUMBER,
        p_ds_trecho_pdf         IN  VARCHAR2,
        p_ic_ocr                IN  CHAR DEFAULT 'N',
        p_ic_ambiguo            IN  CHAR DEFAULT 'N',
        p_co_item               OUT NUMBER,
        p_st_resultado          OUT VARCHAR2
    );

    -- Registro formal de revisão humana (NÃO permite confirmação automática)
    PROCEDURE SP_REGISTRAR_REVISAO_HUMANA(
        p_co_item               IN NUMBER,
        p_no_usuario_revisor    IN VARCHAR2,
        p_st_decisao            IN VARCHAR2,
        p_ds_justificativa      IN VARCHAR2,
        p_ds_ip_cliente         IN VARCHAR2 DEFAULT NULL
    );

    -- Atualização dos contadores da conferência
    PROCEDURE SP_ATUALIZAR_TOTAIS_CONF(
        p_co_conferencia IN NUMBER
    );

END PKG_CONFERENCIA_VIAGEM;
/

