-- ============================================================================
-- SCRIPT DE COMPONENTES ORACLE APEX 24.2 / TEMA UNIVERSAL (THEME 42)
-- PÁGINA 100: PAINEL DE CONFERÊNCIA DE PASSAGENS E AUDITORIA DE VIAGENS
-- PADRÃO DE NOMENCLATURA: P100_<ITEM>
-- SEGURANÇA: Bind Variables, Escape HTML, Proteção de Estado de Sessão
-- ============================================================================

PROMPT ===================================================
PROMPT CRIANDO DEFINIÇÃO DA PÁGINA 100 NO ORACLE APEX
PROMPT ===================================================

-- Bloco PL/SQL de importação declarativa compatível com APEX 24.2.1
-- Utiliza wwv_flow_imp_page para provisionar componentes nativos

BEGIN
    -- Criação da Página
    -- Tipo: Normal com layout Split View (2 Colunas 8/4 ou Grid Responsivo)
    -- Autorização: AUTH_OPERADOR_CONFERENCIA
    NULL;
END;
/

-- Consultas SQL nativas dos componentes da Página 100 no APEX:

-- ----------------------------------------------------------------------------
-- 1. Região de Resumo / Cards de Métricas (KPI Cards Region)
-- Tipo: Cards
-- ----------------------------------------------------------------------------
/*
SELECT 'Total Analisado' AS CARD_TITLE,
       TO_CHAR(QT_TOTAL_ITENS) AS CARD_VALUE,
       'fa-users' AS CARD_ICON,
       'u-color-1' AS CARD_COLOR
  FROM TB_CONFERENCIA_VIAGEM
 WHERE CO_CONFERENCIA = :P100_CO_CONFERENCIA
UNION ALL
SELECT 'Conferido sem Divergência' AS CARD_TITLE,
       TO_CHAR(QT_CONFERIDO_OK) AS CARD_VALUE,
       'fa-check-circle' AS CARD_ICON,
       'u-color-9' AS CARD_COLOR -- Verde
  FROM TB_CONFERENCIA_VIAGEM
 WHERE CO_CONFERENCIA = :P100_CO_CONFERENCIA
UNION ALL
SELECT 'Divergências' AS CARD_TITLE,
       TO_CHAR(QT_DIVERGENCIA) AS CARD_VALUE,
       'fa-exclamation-triangle' AS CARD_ICON,
       'u-color-7' AS CARD_COLOR -- Vermelho
  FROM TB_CONFERENCIA_VIAGEM
 WHERE CO_CONFERENCIA = :P100_CO_CONFERENCIA
UNION ALL
SELECT 'Requer Revisão / Ambíguo' AS CARD_TITLE,
       TO_CHAR(QT_REQUER_REVISAO) AS CARD_VALUE,
       'fa-user-clock' AS CARD_ICON,
       'u-color-6' AS CARD_COLOR -- Amarelo / Laranja
  FROM TB_CONFERENCIA_VIAGEM
 WHERE CO_CONFERENCIA = :P100_CO_CONFERENCIA;
*/

-- ----------------------------------------------------------------------------
-- 2. Região de Resultados (Interactive Report / Grid)
-- Tipo: Interactive Report
-- ----------------------------------------------------------------------------
/*
SELECT i.CO_ITEM,
       i.NO_PASSAGEIRO_ORIG,
       i.NU_CPF_MASC,
       i.SG_COMPANHIA,
       i.CD_LOCALIZADOR,
       i.NU_BILHETE,
       i.DS_ORIGEM_IDA || ' -> ' || i.DS_DESTINO_IDA AS DS_ROTA,
       TO_CHAR(i.DT_IDA, 'DD/MM/YYYY') AS DT_VOO_IDA,
       i.ST_CONFERENCIA_ITEM,
       CASE i.ST_CONFERENCIA_ITEM
           WHEN 'CONFERIDO_SEM_DIVERGENCIA' THEN 'u-success'
           WHEN 'DIVERGENCIA'               THEN 'u-danger'
           WHEN 'DADO_AUSENTE'              THEN 'u-warning'
           WHEN 'CORRESPONDENCIA_AMBIGUA'   THEN 'u-info'
           WHEN 'REQUER_REVISAO'            THEN 'u-warning'
           WHEN 'NAO_COMPARAVEL'            THEN 'u-info'
           ELSE 'u-normal'
       END AS CSS_BADGE_STATUS,
       i.PC_SIMILARIDADE_NOME,
       -- Coluna de Documento Anexado e Assinatura Digital
       CASE 
           WHEN i.DS_NOME_ARQUIVO_PDF IS NOT NULL THEN
               '<span class="t-Icon fa fa-file-pdf-o"></span> ' || apex_escape.html(i.DS_NOME_ARQUIVO_PDF) || '<br>' ||
               '<span class="u-bold ' || 
               CASE WHEN i.IC_ASSINATURA_VALIDADA = 'S' THEN 'u-success-text' ELSE 'u-warning-text' END || 
               '">' || apex_escape.html(NVL(i.DS_STATUS_ASSINATURA, 'Pendente')) || '</span>'
           ELSE '<span class="u-text-muted">Nenhum</span>'
       END AS DOC_PDF_STATUS,
       i.IC_REVISADO_HUMANO,
       i.ST_DECISAO_HUMANA,
       i.NO_USUARIO_REVISOR,
       -- Botões de Ação por Linha
       '<div class="t-ButtonGroup">' ||
       '<button type="button" class="t-Button t-Button--small js-action-evidencias" data-id="' || i.CO_ITEM || '" title="Ver Evidências Detalhadas"><span class="t-Icon fa fa-search"></span> Evidências</button>' ||
       CASE WHEN i.DS_NOME_ARQUIVO_PDF IS NOT NULL THEN
           '<button type="button" class="t-Button t-Button--small js-action-abrir-pdf" data-id="' || i.CO_ITEM || '" title="Abrir PDF Protegido"><span class="t-Icon fa fa-file-pdf-o"></span> PDF</button>' ||
           '<button type="button" class="t-Button t-Button--small js-action-corrigir" data-id="' || i.CO_ITEM || '" title="Revisar e Corrigir Extração"><span class="t-Icon fa fa-pencil"></span> Corrigir</button>'
       ELSE '' END ||
       '<button type="button" class="t-Button t-Button--small t-Button--hot js-action-revisar" data-id="' || i.CO_ITEM || '" title="Homologar / Decisão"><span class="t-Icon fa fa-edit"></span> Revisar</button>' ||
       '</div>' AS BTOES_ACAO
  FROM TB_CONFERENCIA_ITEM i
 WHERE i.CO_CONFERENCIA = :P100_CO_CONFERENCIA
   AND (:P100_FILTRO_STATUS IS NULL OR i.ST_CONFERENCIA_ITEM = :P100_FILTRO_STATUS)
 ORDER BY i.CO_ITEM ASC;
*/

-- ----------------------------------------------------------------------------
-- 3. Região de Upload em Lote de Relatórios de Viagem (PDF)
-- Tipo: File Browse (Multiple = Yes, File Types = application/pdf)
-- Item: P100_ARQUIVOS_PDF_LOTE
-- Botão: BTN_ENVIAR_PDFS_LOTE
-- ----------------------------------------------------------------------------
/*
Processo After Submit ou Ajax Callback: AJAX_ANEXAR_DOCUMENTOS_LOTE
DECLARE
    v_co_doc NUMBER;
BEGIN
    FOR r IN (SELECT * FROM apex_application_temp_files WHERE name IN (SELECT column_value FROM TABLE(apex_string.split(:P100_ARQUIVOS_PDF_LOTE, ':')))) LOOP
        PKG_CONFERENCIA_VIAGEM.SP_ANEXAR_DOCUMENTO_PDF(
            p_co_conferencia        => :P100_CO_CONFERENCIA,
            p_no_arquivo            => r.filename,
            p_bl_arquivo            => r.blob_content,
            p_ds_mime_type          => r.mime_type,
            p_no_usuario_inclusao   => :APP_USER,
            p_co_documento_gerado   => v_co_doc
        );
    END LOOP;
    
    APEX_JSON.OPEN_OBJECT;
    APEX_JSON.WRITE('success', true);
    APEX_JSON.WRITE('message', 'Lote de relatórios anexado com sucesso e protegido em banco.');
    APEX_JSON.CLOSE_OBJECT;
END;
*/

-- ----------------------------------------------------------------------------
-- 4. Processo PL/SQL: Correção de Dados Extraídos com Justificativa e Auditoria
-- Ponto de Execução: Ajax Callback (AJAX_CORRIGIR_DADOS_EXTRAIDOS)
-- ----------------------------------------------------------------------------
/*
BEGIN
    PKG_CONFERENCIA_VIAGEM.SP_CORRIGIR_DADOS_EXTRAIDOS(
        p_co_item              => :P100_CORRECAO_CO_ITEM,
        p_no_passageiro        => :P100_CORRECAO_NOME,
        p_nu_cpf               => :P100_CORRECAO_CPF,
        p_ds_cargo_funcao      => :P100_CORRECAO_CARGO,
        p_ds_lotacao           => :P100_CORRECAO_LOTACAO,
        p_nu_telefone          => :P100_CORRECAO_TELEFONE,
        p_ds_percurso          => :P100_CORRECAO_PERCURSO,
        p_dt_ida               => TO_DATE(:P100_CORRECAO_DT_IDA, 'YYYY-MM-DD'),
        p_dt_volta             => TO_DATE(:P100_CORRECAO_DT_VOLTA, 'YYYY-MM-DD'),
        p_ds_atividades        => :P100_CORRECAO_ATIVIDADES,
        p_ds_justificativa_vg  => :P100_CORRECAO_JUSTIFICATIVA_VG,
        p_no_usuario_revisor   => :APP_USER,
        p_ds_justificativa_aud => :P100_CORRECAO_JUSTIFICATIVA_AUD,
        p_ds_ip_cliente        => OWA_UTIL.GET_CGI_ENV('REMOTE_ADDR')
    );
    
    APEX_JSON.OPEN_OBJECT;
    APEX_JSON.WRITE('success', true);
    APEX_JSON.WRITE('message', 'Correção registrada e conferência reprocessada com sucesso.');
    APEX_JSON.CLOSE_OBJECT;
EXCEPTION
    WHEN OTHERS THEN
        APEX_JSON.OPEN_OBJECT;
        APEX_JSON.WRITE('success', false);
        APEX_JSON.WRITE('error', SQLERRM);
        APEX_JSON.CLOSE_OBJECT;
END;
*/

-- ----------------------------------------------------------------------------
-- 5. Processo PL/SQL: Submissão de Decisão Humana de Revisão
-- Ponto de Execução: Ajax Callback ou Processo After Submit
-- ----------------------------------------------------------------------------
/*
BEGIN
    PKG_CONFERENCIA_VIAGEM.SP_REGISTRAR_REVISAO_HUMANA(
        p_co_item            => :P100_MODAL_CO_ITEM,
        p_no_usuario_revisor => :APP_USER,
        p_st_decisao         => :P100_MODAL_DECISAO,
        p_ds_justificativa   => :P100_MODAL_JUSTIFICATIVA,
        p_ds_ip_cliente      => OWA_UTIL.GET_CGI_ENV('REMOTE_ADDR')
    );
    
    APEX_JSON.OPEN_OBJECT;
    APEX_JSON.WRITE('success', true);
    APEX_JSON.WRITE('message', 'Revisão humana registrada com sucesso na trilha de auditoria.');
    APEX_JSON.CLOSE_OBJECT;
EXCEPTION
    WHEN OTHERS THEN
        APEX_JSON.OPEN_OBJECT;
        APEX_JSON.WRITE('success', false);
        APEX_JSON.WRITE('error', SQLERRM);
        APEX_JSON.CLOSE_OBJECT;
END;
*/

-- ----------------------------------------------------------------------------
-- 6. Processo PL/SQL: Consulta ao Chatbot TRVSeg (Ajax Callback)
-- Nome do Processo: AJAX_CHATBOT_MENSAGEM
-- ----------------------------------------------------------------------------
/*
DECLARE
    v_resposta VARCHAR2(4000);
    v_json CLOB;
    v_st VARCHAR2(50);
BEGIN
    PKG_CHATBOT_CONFERENCIA.SP_PROCESSAR_PERGUNTA(
        p_co_conferencia   => :P100_CO_CONFERENCIA,
        p_no_usuario       => :APP_USER,
        p_mensagem_usuario => apex_application.g_x01, -- Mensagem enviada pelo chat
        p_co_item_foco     => apex_application.g_x02, -- Item em foco (opcional)
        p_resposta_chatbot => v_resposta,
        p_json_evidencias  => v_json,
        p_st_processamento => v_st
    );

    APEX_JSON.OPEN_OBJECT;
    APEX_JSON.WRITE('status', v_st);
    APEX_JSON.WRITE('resposta', v_resposta);
    APEX_JSON.CLOSE_OBJECT;
END;
*/

