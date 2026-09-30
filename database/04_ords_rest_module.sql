-- ============================================================================
-- ORDS REST MODULE: conferencia.viagens.v1
-- OBJETIVO: Endpoints REST para Integração do Chatbot e Conferência
-- AUTENTICAÇÃO: OAuth2 Client Credentials (Cliente registrado: bot-conferencia)
-- PADRÃO: Oracle REST Data Services (ORDS) / Oracle APEX 24.2
-- ============================================================================

-- Habilita o schema para ORDS caso ainda não esteja
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => USER,
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'conferencia',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/

-- Define o Módulo REST
BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'conferencia.viagens.v1',
        p_base_path      => 'conferencia/v1/',
        p_items_per_page => 50,
        p_status         => 'PUBLISHED',
        p_comments       => 'Serviços REST de Conferência de Diárias e Passagens Aéreas de Mobilizados'
    );

    -- ------------------------------------------------------------------------
    -- 1. Endpoint: GET /conferencias
    -- ------------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'conferencia.viagens.v1',
        p_pattern     => 'conferencias'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'conferencia.viagens.v1',
        p_pattern       => 'conferencias',
        p_method        => 'GET',
        p_source_type   => ORDS.SOURCE_TYPE_COLLECTION_FEED,
        p_source        => 'SELECT CO_CONFERENCIA, NO_CONFERENCIA, DS_PROCESSO_SEI, ST_CONFERENCIA, 
                                   QT_TOTAL_ITENS, QT_CONFERIDO_OK, QT_DIVERGENCIA, QT_REQUER_REVISAO, 
                                   DH_CRIACAO, NO_USUARIO_CRIACAO
                              FROM TB_CONFERENCIA_VIAGEM
                             ORDER BY CO_CONFERENCIA DESC'
    );

    -- ------------------------------------------------------------------------
    -- 2. Endpoint: POST /conferencias (Cria sessão de conferência)
    -- ------------------------------------------------------------------------
    ORDS.DEFINE_HANDLER(
        p_module_name   => 'conferencia.viagens.v1',
        p_pattern       => 'conferencias',
        p_method        => 'POST',
        p_source_type   => ORDS.SOURCE_TYPE_PLSQL,
        p_source        => 'DECLARE
                                v_id NUMBER;
                            BEGIN
                                PKG_CONFERENCIA_VIAGEM.SP_CRIAR_CONFERENCIA(
                                    p_no_conferencia  => :no_conferencia,
                                    p_ds_processo_sei => :ds_processo_sei,
                                    p_no_usuario      => NVL(:current_user, ''bot-conferencia''),
                                    p_ds_observacoes  => :ds_observacoes,
                                    p_co_conferencia  => v_id
                                );
                                :status_code := 201;
                                :co_conferencia := v_id;
                            END;'
    );

    -- ------------------------------------------------------------------------
    -- 3. Endpoint: GET /conferencias/:id/itens (Lista itens com filtros)
    -- ------------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'conferencia.viagens.v1',
        p_pattern     => 'conferencias/:id/itens'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'conferencia.viagens.v1',
        p_pattern       => 'conferencias/:id/itens',
        p_method        => 'GET',
        p_source_type   => ORDS.SOURCE_TYPE_COLLECTION_FEED,
        p_source        => 'SELECT CO_ITEM, NO_PASSAGEIRO_ORIG, NU_CPF_MASC, SG_COMPANHIA, CD_LOCALIZADOR,
                                   NU_BILHETE, DS_ORIGEM_IDA, DS_DESTINO_IDA, TO_CHAR(DT_IDA, ''DD/MM/YYYY'') AS DT_IDA_FMT,
                                   ST_CONFERENCIA_ITEM, PC_SIMILARIDADE_NOME, DS_MOTIVO_SITUACAO, 
                                   IC_REVISADO_HUMANO, ST_DECISAO_HUMANA, NO_USUARIO_REVISOR
                              FROM TB_CONFERENCIA_ITEM
                             WHERE CO_CONFERENCIA = :id
                               AND (:status IS NULL OR ST_CONFERENCIA_ITEM = :status)
                             ORDER BY CO_ITEM ASC'
    );

    -- ------------------------------------------------------------------------
    -- 4. Endpoint: GET /conferencias/:id/itens/:item_id/evidencias
    -- ------------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'conferencia.viagens.v1',
        p_pattern     => 'conferencias/:id/itens/:item_id/evidencias'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'conferencia.viagens.v1',
        p_pattern       => 'conferencias/:id/itens/:item_id/evidencias',
        p_method        => 'GET',
        p_source_type   => ORDS.SOURCE_TYPE_COLLECTION_FEED,
        p_source        => 'SELECT CO_EVIDENCIA, NM_CAMPO, VL_FONTE_BANCO, VL_FONTE_PLANILHA, VL_FONTE_PDF,
                                   DS_REF_PDF, NU_PAGINA_PDF, DS_TRECHO_PDF, IC_OCR, ST_DIVERGENCIA_CAMPO, DS_OBSERVACAO
                              FROM TB_CONFERENCIA_EVIDENCIA
                             WHERE CO_ITEM = :item_id
                             ORDER BY CO_EVIDENCIA ASC'
    );

    -- ------------------------------------------------------------------------
    -- 5. Endpoint: POST /conferencias/:id/chatbot (Consulta em Linguagem Natural)
    -- ------------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'conferencia.viagens.v1',
        p_pattern     => 'conferencias/:id/chatbot'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'conferencia.viagens.v1',
        p_pattern       => 'conferencias/:id/chatbot',
        p_method        => 'POST',
        p_source_type   => ORDS.SOURCE_TYPE_PLSQL,
        p_source        => 'DECLARE
                                v_resp VARCHAR2(4000);
                                v_json CLOB;
                                v_st VARCHAR2(50);
                            BEGIN
                                PKG_CHATBOT_CONFERENCIA.SP_PROCESSAR_PERGUNTA(
                                    p_co_conferencia   => :id,
                                    p_no_usuario       => NVL(:usuario, ''bot-conferencia''),
                                    p_mensagem_usuario => :mensagem,
                                    p_co_item_foco     => :co_item,
                                    p_resposta_chatbot => v_resp,
                                    p_json_evidencias  => v_json,
                                    p_st_processamento => v_st
                                );
                                :resposta := v_resp;
                                :status_processamento := v_st;
                                :status_code := CASE WHEN v_st = ''BLOQUEADO_SEGURANCA'' THEN 403 ELSE 200 END;
                            END;'
    );

    -- ------------------------------------------------------------------------
    -- 6. Endpoint: POST /conferencias/:id/itens/:item_id/revisar (Decisão Humana)
    -- ------------------------------------------------------------------------
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'conferencia.viagens.v1',
        p_pattern     => 'conferencias/:id/itens/:item_id/revisar'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'conferencia.viagens.v1',
        p_pattern       => 'conferencias/:id/itens/:item_id/revisar',
        p_method        => 'POST',
        p_source_type   => ORDS.SOURCE_TYPE_PLSQL,
        p_source        => 'BEGIN
                                PKG_CONFERENCIA_VIAGEM.SP_REGISTRAR_REVISAO_HUMANA(
                                    p_co_item            => :item_id,
                                    p_no_usuario_revisor => :usuario_revisor,
                                    p_st_decisao         => :decisao,
                                    p_ds_justificativa   => :justificativa,
                                    p_ds_ip_cliente      => OWA_UTIL.GET_CGI_ENV(''REMOTE_ADDR'')
                                );
                                :status_code := 200;
                                :mensagem := ''Revisão registrada com sucesso na trilha de auditoria.'';
                            EXCEPTION
                                WHEN OTHERS THEN
                                    :status_code := 400;
                                    :mensagem := SQLERRM;
                            END;'
    );

    COMMIT;
END;
/

