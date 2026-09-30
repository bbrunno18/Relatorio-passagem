-- ============================================================================
-- PACOTE: PKG_CHATBOT_CONFERENCIA (CORPO)
-- OBJETIVO: Respostas em PT-BR, Rastreabilidade de Evidências e Defesa Prompt Injection
-- PADRÃO: Metodologia MJSP v1.3 / Oracle APEX 24.2
-- ============================================================================

CREATE OR REPLACE PACKAGE BODY PKG_CHATBOT_CONFERENCIA AS

    -- ------------------------------------------------------------------------
    -- Heurística de proteção contra Prompt Injection e manipulação não autorizada
    -- ------------------------------------------------------------------------
    FUNCTION FN_VERIFICAR_PROMPT_INJECTION(
        p_mensagem IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_msg VARCHAR2(4000);
    BEGIN
        IF p_mensagem IS NULL THEN
            RETURN FALSE;
        END IF;

        v_msg := PKG_CONFERENCIA_VIAGEM.FN_NORMALIZA_TEXTO(p_mensagem);

        IF v_msg LIKE '%IGNORE AS INSTRUCOES%' OR
           v_msg LIKE '%IGNORE TODAS%' OR
           v_msg LIKE '%IGNORE PREVIOUS%' OR
           v_msg LIKE '%VOCE AGORA E%' OR
           v_msg LIKE '%SYSTEM PROMPT%' OR
           v_msg LIKE '%DROP TABLE%' OR
           v_msg LIKE '%TRUNCATE%' OR
           v_msg LIKE '%ALTERE TODOS%' OR
           v_msg LIKE '%APROVE TODOS%' OR
           v_msg LIKE '%CONFIRME TODOS%' OR
           v_msg LIKE '%REVELE SUA INSTRUCAO%' OR
           v_msg LIKE '%REVELE A SENHA%' OR
           v_msg LIKE '%CLIENT_SECRET%' OR
           v_msg LIKE '%BASIC AUTH%' THEN
            RETURN TRUE;
        END IF;

        RETURN FALSE;
    END FN_VERIFICAR_PROMPT_INJECTION;

    -- ------------------------------------------------------------------------
    -- Explicação técnica detalhada de divergências de um item
    -- ------------------------------------------------------------------------
    FUNCTION FN_EXPLICAR_DIVERGENCIA(
        p_co_item IN NUMBER
    ) RETURN VARCHAR2 IS
        v_item TB_CONFERENCIA_ITEM%ROWTYPE;
        v_explicacao VARCHAR2(4000) := '';
        v_count_evid NUMBER := 0;
    BEGIN
        SELECT * INTO v_item FROM TB_CONFERENCIA_ITEM WHERE CO_ITEM = p_co_item;

        v_explicacao := 'Passageiro: ' || v_item.NO_PASSAGEIRO_ORIG || 
                        ' | CPF: ' || NVL(v_item.NU_CPF_MASC, 'Não informado') || 
                        ' | Situação: ' || v_item.ST_CONFERENCIA_ITEM || CHR(10) ||
                        'Motivo apurado: ' || v_item.DS_MOTIVO_SITUACAO || CHR(10) || CHR(10) ||
                        'Evidências confrontadas por campo:' || CHR(10);

        FOR r IN (
            SELECT NM_CAMPO, VL_FONTE_BANCO, VL_FONTE_PLANILHA, VL_FONTE_PDF, 
                   DS_REF_PDF, NU_PAGINA_PDF, DS_TRECHO_PDF, IC_OCR, ST_DIVERGENCIA_CAMPO, DS_OBSERVACAO
              FROM TB_CONFERENCIA_EVIDENCIA
             WHERE CO_ITEM = p_co_item
             ORDER BY CO_EVIDENCIA
        ) LOOP
            v_count_evid := v_count_evid + 1;
            v_explicacao := v_explicacao || '• Campo [' || r.NM_CAMPO || ']: Status = ' || r.ST_DIVERGENCIA_CAMPO || CHR(10);
            v_explicacao := v_explicacao || '   - Banco: ' || NVL(r.VL_FONTE_BANCO, '(ausente)') || CHR(10);
            v_explicacao := v_explicacao || '   - Planilha: ' || NVL(r.VL_FONTE_PLANILHA, '(ausente)') || CHR(10);
            v_explicacao := v_explicacao || '   - Documento PDF: ' || NVL(r.VL_FONTE_PDF, '(ausente)');
            IF r.DS_REF_PDF IS NOT NULL THEN
                v_explicacao := v_explicacao || ' (Ref: ' || r.DS_REF_PDF;
                IF r.NU_PAGINA_PDF IS NOT NULL THEN
                    v_explicacao := v_explicacao || ', Pág: ' || r.NU_PAGINA_PDF;
                END IF;
                IF r.IC_OCR = 'S' THEN
                    v_explicacao := v_explicacao || ' [Extração via OCR - menor confiabilidade]';
                END IF;
                v_explicacao := v_explicacao || ')';
            END IF;
            v_explicacao := v_explicacao || CHR(10);
            IF r.DS_TRECHO_PDF IS NOT NULL THEN
                v_explicacao := v_explicacao || '   - Trecho comprobatório: "' || SUBSTR(r.DS_TRECHO_PDF, 1, 150) || '..."' || CHR(10);
            END IF;
        END LOOP;

        IF v_count_evid = 0 THEN
            v_explicacao := v_explicacao || 'Não foram localizadas evidências adicionais registradas para este item.';
        END IF;

        IF v_item.IC_REVISADO_HUMANO = 'S' THEN
            v_explicacao := v_explicacao || CHR(10) || 'Decisão humana registrada por ' || v_item.NO_USUARIO_REVISOR || 
                            ' em ' || TO_CHAR(v_item.DH_REVISAO_HUMANA, 'DD/MM/YYYY HH24:MI') || 
                            ': ' || v_item.ST_DECISAO_HUMANA || ' - "' || v_item.DS_JUSTIFICATIVA_REVISAO || '"';
        ELSE
            v_explicacao := v_explicacao || CHR(10) || 'Atenção: Item pendente de revisão e autorização humana.';
        END IF;

        RETURN v_explicacao;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'Item de conferência #' || p_co_item || ' não localizado.';
    END FN_EXPLICAR_DIVERGENCIA;

    -- ------------------------------------------------------------------------
    -- Processamento de Pergunta com Resposta em Linguagem Natural
    -- ------------------------------------------------------------------------
    PROCEDURE SP_PROCESSAR_PERGUNTA(
        p_co_conferencia        IN  NUMBER,
        p_no_usuario            IN  VARCHAR2,
        p_mensagem_usuario      IN  VARCHAR2,
        p_co_item_foco          IN  NUMBER DEFAULT NULL,
        p_resposta_chatbot      OUT VARCHAR2,
        p_json_evidencias       OUT CLOB,
        p_st_processamento      OUT VARCHAR2
    ) IS
        v_msg_norm VARCHAR2(4000);
        v_total NUMBER;
        v_ok NUMBER;
        v_div NUMBER;
        v_rev NUMBER;
        v_item_id NUMBER := p_co_item_foco;
        v_match_count NUMBER := 0;
        v_nome_candidato VARCHAR2(150);
    BEGIN
        p_st_processamento := 'SUCESSO';
        p_json_evidencias := '[]';

        -- 1. Proteção de Segurança: Detecção de Prompt Injection
        IF FN_VERIFICAR_PROMPT_INJECTION(p_mensagem_usuario) THEN
            p_st_processamento := 'BLOQUEADO_SEGURANCA';
            p_resposta_chatbot := 'Alerta de Segurança: A mensagem enviada contém padrões ou instruções não permitidas pelas regras de governança e integridade do sistema. ' ||
                                  'Este assistente atua exclusivamente na elucidação dos dados carregados nesta conferência e não possui autorização para modificar parâmetros, ignorar regras de auditoria ou alterar dados de viagem.';
            
            -- Registra em auditoria
            INSERT INTO TB_AUDITORIA_CONFERENCIA (
                CO_CONFERENCIA,
                NO_USUARIO,
                TP_ACAO,
                DS_JUSTIFICATIVA,
                DS_DADOS_NOVOS
            ) VALUES (
                p_co_conferencia,
                p_no_usuario,
                'BLOQUEIO_PROMPT_INJECTION',
                'Tentativa de injeção de instruções ou comando não autorizado barrada pelo assistente.',
                'Trecho mensagem: ' || SUBSTR(p_mensagem_usuario, 1, 200)
            );
            RETURN;
        END IF;

        v_msg_norm := PKG_CONFERENCIA_VIAGEM.FN_NORMALIZA_TEXTO(p_mensagem_usuario);

        -- 2. Salvaguarda: Bloqueio de qualquer solicitação de confirmação/alteração automática
        IF v_msg_norm LIKE '%CONFIRME%' OR 
           v_msg_norm LIKE '%APROVE%' OR 
           v_msg_norm LIKE '%ALTERE%' OR 
           v_msg_norm LIKE '%MUDA%' OR 
           v_msg_norm LIKE '%ATUALIZE%' OR 
           v_msg_norm LIKE '%EXCLUA%' OR 
           v_msg_norm LIKE '%CANCELE%' THEN
            p_resposta_chatbot := 'Esclarecimento de Governança: Como agente assistente de IA, sou estritamente proibido de confirmar, alterar, aprovar ou cancelar bilhetes ou dados de viagem por iniciativa própria. ' ||
                                  'Para homologar ou ajustar uma situação, a pessoa responsável deve utilizar o botão "Registrar Revisão Humana" na tela de conferência, fornecendo justificativa formal e autenticação.';
            RETURN;
        END IF;

        -- 3. Identifica se a pergunta busca um passageiro específico por nome ou CPF
        IF v_item_id IS NULL THEN
            FOR r IN (
                SELECT CO_ITEM, NO_PASSAGEIRO_ORIG, NO_PASSAGEIRO_NORM, NU_CPF_ORIG
                  FROM TB_CONFERENCIA_ITEM
                 WHERE CO_CONFERENCIA = p_co_conferencia
            ) LOOP
                -- Verifica se parte do nome ou CPF consta na pergunta
                IF INSTR(v_msg_norm, r.NO_PASSAGEIRO_NORM) > 0 OR 
                   (r.NU_CPF_ORIG IS NOT NULL AND INSTR(v_msg_norm, REGEXP_REPLACE(r.NU_CPF_ORIG, '[^0-9]', '')) > 0) THEN
                    v_match_count := v_match_count + 1;
                    v_item_id := r.CO_ITEM;
                    v_nome_candidato := r.NO_PASSAGEIRO_ORIG;
                END IF;
            END LOOP;

            -- Caso encontre múltiplos passageiros coincidentes: ambiguidade!
            IF v_match_count > 1 THEN
                p_resposta_chatbot := 'Identifiquei mais de um passageiro correspondente aos termos da sua pergunta na conferência atual. ' ||
                                      'Por favor, informe o CPF completo ou o nome exato para que eu possa apresentar as evidências específicas sem ambiguidade.';
                RETURN;
            END IF;
        END IF;

        -- 4. Se tiver foco em um item específico, responde com evidências dele
        IF v_item_id IS NOT NULL THEN
            p_resposta_chatbot := FN_EXPLICAR_DIVERGENCIA(v_item_id);
            RETURN;
        END IF;

        -- 5. Consultas agregadas (resumo, divergências, pendências)
        SELECT QT_TOTAL_ITENS, QT_CONFERIDO_OK, QT_DIVERGENCIA, QT_REQUER_REVISAO
          INTO v_total, v_ok, v_div, v_rev
          FROM TB_CONFERENCIA_VIAGEM
         WHERE CO_CONFERENCIA = p_co_conferencia;

        IF v_msg_norm LIKE '%RESUMO%' OR v_msg_norm LIKE '%STATUS%' OR v_msg_norm LIKE '%GERAL%' OR v_msg_norm LIKE '%TOTAL%' THEN
            p_resposta_chatbot := 'Resumo da Conferência #' || p_co_conferencia || ':' || CHR(10) ||
                                  '• Total de viajantes/passagens analisados: ' || v_total || CHR(10) ||
                                  '• Conferidos sem divergência: ' || v_ok || CHR(10) ||
                                  '• Divergências identificadas: ' || v_div || CHR(10) ||
                                  '• Requerem revisão humana ou apresentam dados ausentes/ambíguos: ' || v_rev || CHR(10) || CHR(10) ||
                                  'Você pode perguntar sobre o histórico de qualquer passageiro pelo nome ou selecionar um registro na tabela para ver as evidências detalhadas.';
            RETURN;
        END IF;

        IF v_msg_norm LIKE '%DIVERGEN%' OR v_msg_norm LIKE '%DIFERENCA%' OR v_msg_norm LIKE '%ERRO%' THEN
            p_resposta_chatbot := 'Foram identificadas ' || v_div || ' ocorrência(s) com divergência explícita nesta conferência:' || CHR(10);
            FOR d IN (
                SELECT NO_PASSAGEIRO_ORIG, NU_CPF_MASC, DS_MOTIVO_SITUACAO
                  FROM TB_CONFERENCIA_ITEM
                 WHERE CO_CONFERENCIA = p_co_conferencia
                   AND ST_CONFERENCIA_ITEM = 'DIVERGENCIA'
                   AND ROWNUM <= 5
            ) LOOP
                p_resposta_chatbot := p_resposta_chatbot || '• ' || d.NO_PASSAGEIRO_ORIG || ' (' || NVL(d.NU_CPF_MASC, 'S/ CPF') || '): ' || d.DS_MOTIVO_SITUACAO || CHR(10);
            END LOOP;
            IF v_div > 5 THEN
                p_resposta_chatbot := p_resposta_chatbot || '... (e mais ' || (v_div - 5) || ' registros. Filtre na tabela de resultados para ver a lista completa).' || CHR(10);
            END IF;
            p_resposta_chatbot := p_resposta_chatbot || CHR(10) || 'Deseja detalhes sobre as fontes e trechos comprobatórios de algum desses viajantes?';
            RETURN;
        END IF;

        -- 6. Resposta padrão orientativa ancorada nas fontes
        p_resposta_chatbot := 'Olá! Sou o Assistente de Conferência de Diárias e Passagens Aéreas de Mobilizados. ' ||
                              'Estou configurado para analisar exclusivamente os dados desta conferência (Banco de Dados, Planilhas e PDFs carregados). ' ||
                              'Como posso ajudar? Você pode solicitar:' || CHR(10) ||
                              '1. Resumo geral da conferência;' || CHR(10) ||
                              '2. Relação de passageiros com divergência;' || CHR(10) ||
                              '3. Explicação detalhada com evidências e números de página sobre um viajante específico; ou' || CHR(10) ||
                              '4. Critérios adotados para marcação de dados ausentes ou sugestões de nomes semelhantes.';
    END SP_PROCESSAR_PERGUNTA;

END PKG_CHATBOT_CONFERENCIA;
/

