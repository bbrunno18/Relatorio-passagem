-- ============================================================================
-- PACOTE: PKG_CONFERENCIA_VIAGEM (CORPO)
-- OBJETIVO: Implementação do Motor de Comparação, Auditoria e Validação
-- PADRÃO: Metodologia MJSP v1.3 / Oracle APEX 24.2
-- ============================================================================

CREATE OR REPLACE PACKAGE BODY PKG_CONFERENCIA_VIAGEM AS

    -- ------------------------------------------------------------------------
    -- Normalização determinística de texto
    -- ------------------------------------------------------------------------
    FUNCTION FN_NORMALIZA_TEXTO(
        p_texto IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_limpo VARCHAR2(4000);
    BEGIN
        IF p_texto IS NULL THEN
            RETURN NULL;
        END IF;

        -- 1. Converte para maiúsculas e remove espaços das pontas
        v_limpo := UPPER(TRIM(p_texto));

        -- 2. Remove acentos e caracteres diacríticos
        v_limpo := TRANSLATE(
            v_limpo,
            'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑÝ',
            'AAAAAEEEEIIIIOOOOOUUUUCNY'
        );

        -- 3. Substitui múltiplos espaços por um único espaço
        v_limpo := REGEXP_REPLACE(v_limpo, '\s+', ' ');

        RETURN v_limpo;
    END FN_NORMALIZA_TEXTO;

    -- ------------------------------------------------------------------------
    -- Mascaramento de CPF para conformidade com a LGPD (ex: 889.***.***-20)
    -- ------------------------------------------------------------------------
    FUNCTION FN_MASCARAR_CPF(
        p_cpf IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_nums VARCHAR2(30);
    BEGIN
        IF p_cpf IS NULL THEN
            RETURN NULL;
        END IF;

        -- Extrai apenas dígitos
        v_nums := REGEXP_REPLACE(p_cpf, '[^0-9]', '');

        IF LENGTH(v_nums) = 11 THEN
            RETURN SUBSTR(v_nums, 1, 3) || '.***.***-' || SUBSTR(v_nums, 10, 2);
        ELSE
            -- Se não tiver 11 dígitos, mascara a porção central
            IF LENGTH(v_nums) >= 4 THEN
                RETURN SUBSTR(v_nums, 1, 2) || LPAD('*', LENGTH(v_nums) - 4, '*') || SUBSTR(v_nums, -2);
            ELSE
                RETURN '***';
            END IF;
        END IF;
    END FN_MASCARAR_CPF;

    -- ------------------------------------------------------------------------
    -- Mascaramento de documento genérico (RG, Passaporte, etc.)
    -- ------------------------------------------------------------------------
    FUNCTION FN_MASCARAR_DOCUMENTO(
        p_documento IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_limpo VARCHAR2(100);
        v_len   NUMBER;
    BEGIN
        IF p_documento IS NULL THEN
            RETURN NULL;
        END IF;

        v_limpo := TRIM(p_documento);
        v_len   := LENGTH(v_limpo);

        IF v_len <= 4 THEN
            RETURN '****';
        ELSE
            RETURN SUBSTR(v_limpo, 1, 2) || LPAD('*', v_len - 4, '*') || SUBSTR(v_limpo, -2);
        END IF;
    END FN_MASCARAR_DOCUMENTO;

    -- ------------------------------------------------------------------------
    -- Algoritmo de Distância de Levenshtein e Similaridade Percentual
    -- ------------------------------------------------------------------------
    FUNCTION FN_CALCULA_SIMILARIDADE(
        p_str1 IN VARCHAR2,
        p_str2 IN VARCHAR2
    ) RETURN NUMBER IS
        s1 VARCHAR2(4000) := FN_NORMALIZA_TEXTO(p_str1);
        s2 VARCHAR2(4000) := FN_NORMALIZA_TEXTO(p_str2);
        l1 NUMBER := LENGTH(s1);
        l2 NUMBER := LENGTH(s2);
        
        TYPE t_matriz IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
        TYPE t_grid   IS TABLE OF t_matriz INDEX BY BINARY_INTEGER;
        m t_grid;
        
        c NUMBER;
        dist NUMBER;
        max_len NUMBER;
    BEGIN
        IF s1 IS NULL AND s2 IS NULL THEN
            RETURN 100.00;
        END IF;
        IF s1 IS NULL OR s2 IS NULL THEN
            RETURN 0.00;
        END IF;
        IF s1 = s2 THEN
            RETURN 100.00;
        END IF;

        max_len := GREATEST(l1, l2);
        IF max_len = 0 THEN
            RETURN 100.00;
        END IF;

        FOR i IN 0..l1 LOOP
            m(i)(0) := i;
        END LOOP;
        FOR j IN 0..l2 LOOP
            m(0)(j) := j;
        END LOOP;

        FOR i IN 1..l1 LOOP
            FOR j IN 1..l2 LOOP
                IF SUBSTR(s1, i, 1) = SUBSTR(s2, j, 1) THEN
                    c := 0;
                ELSE
                    c := 1;
                END IF;

                m(i)(j) := LEAST(
                    m(i - 1)(j) + 1,       -- deleção
                    m(i)(j - 1) + 1,       -- inserção
                    m(i - 1)(j - 1) + c    -- substituição
                );
            END LOOP;
        END LOOP;

        dist := m(l1)(l2);
        RETURN ROUND((1 - (dist / max_len)) * 100, 2);
    END FN_CALCULA_SIMILARIDADE;

    -- ------------------------------------------------------------------------
    -- Criação de Sessão de Conferência
    -- ------------------------------------------------------------------------
    PROCEDURE SP_CRIAR_CONFERENCIA(
        p_no_conferencia    IN  VARCHAR2,
        p_ds_processo_sei   IN  VARCHAR2,
        p_no_usuario        IN  VARCHAR2,
        p_ds_observacoes    IN  VARCHAR2,
        p_co_conferencia    OUT NUMBER
    ) IS
    BEGIN
        IF p_no_conferencia IS NULL OR p_no_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'Nome da conferência e usuário responsável são obrigatórios.');
        END IF;

        INSERT INTO TB_CONFERENCIA_VIAGEM (
            NO_CONFERENCIA,
            DS_PROCESSO_SEI,
            NO_USUARIO_CRIACAO,
            DS_OBSERVACOES,
            ST_CONFERENCIA
        ) VALUES (
            p_no_conferencia,
            p_ds_processo_sei,
            p_no_usuario,
            p_ds_observacoes,
            'EM_ANDAMENTO'
        ) RETURNING CO_CONFERENCIA INTO p_co_conferencia;

        -- Auditoria inicial
        INSERT INTO TB_AUDITORIA_CONFERENCIA (
            CO_CONFERENCIA,
            NO_USUARIO,
            TP_ACAO,
            DS_JUSTIFICATIVA,
            DS_DADOS_NOVOS
        ) VALUES (
            p_co_conferencia,
            p_no_usuario,
            'CRIACAO_CONFERENCIA',
            'Sessão de conferência iniciada pelo operador responsável.',
            'Conferência: ' || p_no_conferencia || ' | Processo SEI: ' || NVL(p_ds_processo_sei, 'N/A')
        );
    END SP_CRIAR_CONFERENCIA;

    -- ------------------------------------------------------------------------
    -- Registro e Validação de Fonte Documental
    -- ------------------------------------------------------------------------
    PROCEDURE SP_REGISTRAR_FONTE(
        p_co_conferencia    IN  NUMBER,
        p_tp_fonte          IN  VARCHAR2,
        p_no_arquivo        IN  VARCHAR2,
        p_nu_tamanho_bytes  IN  NUMBER,
        p_ds_mime_type      IN  VARCHAR2,
        p_no_usuario        IN  VARCHAR2,
        p_co_fonte          OUT NUMBER
    ) IS
        v_ext VARCHAR2(10);
    BEGIN
        -- Validação de tipo de arquivo e tamanho (máx 15MB)
        IF p_nu_tamanho_bytes > 15728640 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Arquivo excede o limite máximo permitido de 15 MB.');
        END IF;

        v_ext := LOWER(SUBSTR(p_no_arquivo, INSTR(p_no_arquivo, '.', -1) + 1));
        IF p_tp_fonte = 'PLANILHA' AND v_ext NOT IN ('csv', 'xlsx', 'xls') THEN
            RAISE_APPLICATION_ERROR(-20003, 'Extensão de planilha inválida (' || v_ext || '). Permitidos: CSV, XLSX.');
        ELSIF p_tp_fonte = 'PDF' AND v_ext != 'pdf' THEN
            RAISE_APPLICATION_ERROR(-20004, 'Extensão inválida para documento PDF: ' || v_ext);
        END IF;

        INSERT INTO TB_CONFERENCIA_FONTE (
            CO_CONFERENCIA,
            TP_FONTE,
            NO_ARQUIVO,
            NU_TAMANHO_BYTES,
            DS_MIME_TYPE,
            NO_USUARIO_CARGA,
            ST_PROCESSAMENTO
        ) VALUES (
            p_co_conferencia,
            p_tp_fonte,
            p_no_arquivo,
            p_nu_tamanho_bytes,
            p_ds_mime_type,
            p_no_usuario,
            'PROCESSADO'
        ) RETURNING CO_FONTE INTO p_co_fonte;

        INSERT INTO TB_AUDITORIA_CONFERENCIA (
            CO_CONFERENCIA,
            NO_USUARIO,
            TP_ACAO,
            DS_JUSTIFICATIVA,
            DS_DADOS_NOVOS
        ) VALUES (
            p_co_conferencia,
            p_no_usuario,
            'CARGA_FONTE_DOCUMENTAL',
            'Arquivo carregado para análise de conferência.',
            'Arquivo: ' || p_no_arquivo || ' | Tipo: ' || p_tp_fonte || ' | Bytes: ' || p_nu_tamanho_bytes
        );
    END SP_REGISTRAR_FONTE;

    -- ------------------------------------------------------------------------
    -- Processamento comparativo entre fontes e gravação de evidências
    -- ------------------------------------------------------------------------
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
    ) IS
        v_nome_ref          VARCHAR2(150);
        v_nome_norm         VARCHAR2(150);
        v_cpf_ref           VARCHAR2(20);
        v_cpf_masc          VARCHAR2(20);
        v_simil_nome        NUMBER(5,2) := 100.00;
        v_motivo            VARCHAR2(4000) := '';
        v_divergencia_detectada BOOLEAN := FALSE;
        v_dado_ausente_detectado BOOLEAN := FALSE;
    BEGIN
        -- Determina referências principais para exibição
        v_nome_ref := COALESCE(p_no_passageiro_banco, p_no_passageiro_plan, p_no_passageiro_pdf, 'NÃO INFORMADO');
        v_nome_norm := FN_NORMALIZA_TEXTO(v_nome_ref);
        v_cpf_ref := COALESCE(p_nu_cpf_banco, p_nu_cpf_plan, p_nu_cpf_pdf);
        v_cpf_masc := FN_MASCARAR_CPF(v_cpf_ref);

        -- Caso 1: Ambiguidade explícita (múltiplos candidatos)
        IF p_ic_ambiguo = 'S' THEN
            p_st_resultado := 'CORRESPONDENCIA_AMBIGUA';
            v_motivo := 'Foram localizados múltiplos registros com características coincidentes nas fontes. Requer desambiguação manual pelo operador.';
        
        -- Caso 2: Avaliação de Nomes (Levenshtein e normalização)
        ELSE
            -- Compara Banco x Planilha se ambos existirem
            IF p_no_passageiro_banco IS NOT NULL AND p_no_passageiro_plan IS NOT NULL THEN
                IF FN_NORMALIZA_TEXTO(p_no_passageiro_banco) != FN_NORMALIZA_TEXTO(p_no_passageiro_plan) THEN
                    v_simil_nome := FN_CALCULA_SIMILARIDADE(p_no_passageiro_banco, p_no_passageiro_plan);
                    IF v_simil_nome >= 75.00 THEN
                        v_motivo := v_motivo || '[NOME_SEMELHANTE: ' || v_simil_nome || '% similaridade entre Banco e Planilha. Sugestão apresentada, confirmação automática vedada] ';
                    ELSE
                        v_divergencia_detectada := TRUE;
                        v_motivo := v_motivo || '[NOME_DIVERGENTE: Banco="' || p_no_passageiro_banco || '" x Planilha="' || p_no_passageiro_plan || '"] ';
                    END IF;
                END IF;
            END IF;

            -- Compara Banco x PDF se ambos existirem
            IF p_no_passageiro_banco IS NOT NULL AND p_no_passageiro_pdf IS NOT NULL THEN
                IF FN_NORMALIZA_TEXTO(p_no_passageiro_banco) != FN_NORMALIZA_TEXTO(p_no_passageiro_pdf) THEN
                    v_simil_nome := LEAST(v_simil_nome, FN_CALCULA_SIMILARIDADE(p_no_passageiro_banco, p_no_passageiro_pdf));
                    IF v_simil_nome >= 75.00 THEN
                        v_motivo := v_motivo || '[NOME_SEMELHANTE: ' || v_simil_nome || '% similaridade entre Banco e PDF. Requer validação] ';
                    ELSE
                        v_divergencia_detectada := TRUE;
                        v_motivo := v_motivo || '[NOME_DIVERGENTE: Banco="' || p_no_passageiro_banco || '" x PDF="' || p_no_passageiro_pdf || '"] ';
                    END IF;
                END IF;
            END IF;

            -- Caso 3: Comparação rigorosa de CPF
            IF p_nu_cpf_banco IS NOT NULL AND p_nu_cpf_plan IS NOT NULL THEN
                IF REGEXP_REPLACE(p_nu_cpf_banco, '[^0-9]', '') != REGEXP_REPLACE(p_nu_cpf_plan, '[^0-9]', '') THEN
                    v_divergencia_detectada := TRUE;
                    v_motivo := v_motivo || '[CPF_DIVERGENTE: Banco x Planilha] ';
                END IF;
            END IF;
            IF p_nu_cpf_banco IS NOT NULL AND p_nu_cpf_pdf IS NOT NULL THEN
                IF REGEXP_REPLACE(p_nu_cpf_banco, '[^0-9]', '') != REGEXP_REPLACE(p_nu_cpf_pdf, '[^0-9]', '') THEN
                    v_divergencia_detectada := TRUE;
                    v_motivo := v_motivo || '[CPF_DIVERGENTE: Banco x PDF] ';
                END IF;
            END IF;

            -- Caso 4: Comparação rigorosa de Localizador e Bilhete
            IF p_cd_localizador_banco IS NOT NULL AND p_cd_localizador_plan IS NOT NULL THEN
                IF FN_NORMALIZA_TEXTO(p_cd_localizador_banco) != FN_NORMALIZA_TEXTO(p_cd_localizador_plan) THEN
                    v_divergencia_detectada := TRUE;
                    v_motivo := v_motivo || '[LOCALIZADOR_DIVERGENTE: ' || p_cd_localizador_banco || ' x ' || p_cd_localizador_plan || '] ';
                END IF;
            END IF;

            IF p_nu_bilhete_banco IS NOT NULL AND p_nu_bilhete_plan IS NOT NULL THEN
                IF FN_NORMALIZA_TEXTO(p_nu_bilhete_banco) != FN_NORMALIZA_TEXTO(p_nu_bilhete_plan) THEN
                    v_divergencia_detectada := TRUE;
                    v_motivo := v_motivo || '[BILHETE_DIVERGENTE: ' || p_nu_bilhete_banco || ' x ' || p_nu_bilhete_plan || '] ';
                END IF;
            END IF;

            -- Caso 5: Comparação de Datas
            IF p_dt_ida_banco IS NOT NULL AND p_dt_ida_plan IS NOT NULL THEN
                IF TRUNC(p_dt_ida_banco) != TRUNC(p_dt_ida_plan) THEN
                    v_divergencia_detectada := TRUE;
                    v_motivo := v_motivo || '[DATA_IDA_DIVERGENTE: ' || TO_CHAR(p_dt_ida_banco, 'DD/MM/YYYY') || ' x ' || TO_CHAR(p_dt_ida_plan, 'DD/MM/YYYY') || '] ';
                END IF;
            END IF;

            -- Caso 6: Campos Ausentes
            IF (p_nu_cpf_banco IS NULL AND p_nu_cpf_plan IS NOT NULL) OR
               (p_cd_localizador_banco IS NULL AND p_cd_localizador_plan IS NOT NULL) OR
               (p_nu_bilhete_banco IS NULL AND p_nu_bilhete_plan IS NOT NULL) OR
               (p_dt_ida_banco IS NULL AND p_dt_ida_plan IS NOT NULL) THEN
                v_dado_ausente_detectado := TRUE;
                v_motivo := v_motivo || '[DADO_AUSENTE: Campos cadastrais não preenchidos na fonte Banco] ';
            END IF;

            -- Caso 7: Flag de OCR em PDF
            IF p_ic_ocr = 'S' THEN
                v_motivo := v_motivo || '[EXTRAÇÃO_POR_OCR: Dados de PDF extraídos via reconhecimento óptico; confiabilidade reduzida, necessária revisão visual.] ';
            END IF;

            -- Definição do status determinístico final
            IF v_divergencia_detectada THEN
                p_st_resultado := 'DIVERGENCIA';
            ELSIF p_ic_ocr = 'S' OR v_simil_nome < 100.00 THEN
                p_st_resultado := 'REQUER_REVISAO';
            ELSIF v_dado_ausente_detectado THEN
                p_st_resultado := 'DADO_AUSENTE';
            ELSE
                p_st_resultado := 'CONFERIDO_SEM_DIVERGENCIA';
                v_motivo := 'Registros correspondentes entre as fontes analisadas. Nenhuma discrepância identificada.';
            END IF;
        END IF;

        -- Grava o Item de Conferência
        INSERT INTO TB_CONFERENCIA_ITEM (
            CO_CONFERENCIA,
            NO_PASSAGEIRO_ORIG,
            NO_PASSAGEIRO_NORM,
            NU_CPF_ORIG,
            NU_CPF_MASC,
            SG_COMPANHIA,
            CD_LOCALIZADOR,
            NU_BILHETE,
            DS_ORIGEM_IDA,
            DS_DESTINO_IDA,
            DT_IDA,
            VL_TOTAL,
            ST_CONFERENCIA_ITEM,
            PC_SIMILARIDADE_NOME,
            DS_MOTIVO_SITUACAO,
            IC_REVISADO_HUMANO
        ) VALUES (
            p_co_conferencia,
            v_nome_ref,
            v_nome_norm,
            v_cpf_ref,
            v_cpf_masc,
            p_sg_companhia,
            COALESCE(p_cd_localizador_banco, p_cd_localizador_plan, p_cd_localizador_pdf),
            COALESCE(p_nu_bilhete_banco, p_nu_bilhete_plan, p_nu_bilhete_pdf),
            p_ds_origem_ida,
            p_ds_destino_ida,
            COALESCE(p_dt_ida_banco, p_dt_ida_plan, p_dt_ida_pdf),
            p_vl_total,
            p_st_resultado,
            v_simil_nome,
            v_motivo,
            'N'
        ) RETURNING CO_ITEM INTO p_co_item;

        -- Grava Evidências Detalhadas
        -- Evidência: Nome
        INSERT INTO TB_CONFERENCIA_EVIDENCIA (
            CO_ITEM,
            NM_CAMPO,
            VL_FONTE_BANCO,
            VL_FONTE_PLANILHA,
            VL_FONTE_PDF,
            DS_REF_PDF,
            NU_PAGINA_PDF,
            DS_TRECHO_PDF,
            IC_OCR,
            ST_DIVERGENCIA_CAMPO,
            DS_OBSERVACAO
        ) VALUES (
            p_co_item,
            'NOME_PASSAGEIRO',
            p_no_passageiro_banco,
            p_no_passageiro_plan,
            p_no_passageiro_pdf,
            p_ref_doc_pdf,
            p_nu_pagina_pdf,
            p_ds_trecho_pdf,
            p_ic_ocr,
            CASE WHEN v_simil_nome = 100 THEN 'CONFORME' ELSE 'DIVERGENCIA' END,
            'Similaridade calculada: ' || v_simil_nome || '%'
        );

        -- Evidência: CPF
        INSERT INTO TB_CONFERENCIA_EVIDENCIA (
            CO_ITEM,
            NM_CAMPO,
            VL_FONTE_BANCO,
            VL_FONTE_PLANILHA,
            VL_FONTE_PDF,
            DS_REF_PDF,
            NU_PAGINA_PDF,
            DS_TRECHO_PDF,
            IC_OCR,
            ST_DIVERGENCIA_CAMPO,
            DS_OBSERVACAO
        ) VALUES (
            p_co_item,
            'CPF_PASSAGEIRO',
            FN_MASCARAR_CPF(p_nu_cpf_banco),
            FN_MASCARAR_CPF(p_nu_cpf_plan),
            FN_MASCARAR_CPF(p_nu_cpf_pdf),
            p_ref_doc_pdf,
            p_nu_pagina_pdf,
            p_ds_trecho_pdf,
            p_ic_ocr,
            CASE WHEN NVL(REGEXP_REPLACE(p_nu_cpf_banco,'[^0-9]',''), 'A') = NVL(REGEXP_REPLACE(p_nu_cpf_plan,'[^0-9]',''), 'A') THEN 'CONFORME' ELSE 'DIVERGENCIA' END,
            'Documento mascarado conforme diretrizes de privacidade LGPD.'
        );

        -- Atualiza contadores
        SP_ATUALIZAR_TOTAIS_CONF(p_co_conferencia);
    END SP_PROCESSAR_COMPARACAO_ITEM;

    -- ------------------------------------------------------------------------
    -- Registro formal de revisão humana com justificativa e auditoria
    -- ------------------------------------------------------------------------
    PROCEDURE SP_REGISTRAR_REVISAO_HUMANA(
        p_co_item               IN NUMBER,
        p_no_usuario_revisor    IN VARCHAR2,
        p_st_decisao            IN VARCHAR2,
        p_ds_justificativa      IN VARCHAR2,
        p_ds_ip_cliente         IN VARCHAR2 DEFAULT NULL
    ) IS
        v_co_conferencia NUMBER;
        v_status_antigo VARCHAR2(35);
        v_nome_pass VARCHAR2(150);
    BEGIN
        IF p_no_usuario_revisor IS NULL THEN
            RAISE_APPLICATION_ERROR(-20010, 'Identificação do usuário revisor é obrigatória.');
        END IF;

        IF p_st_decisao NOT IN ('APROVADO_REVISOR', 'REJEITADO_REVISOR', 'SOLICITADA_COMPLEMENTACAO') THEN
            RAISE_APPLICATION_ERROR(-20011, 'Decisão inválida. Permitidos: APROVADO_REVISOR, REJEITADO_REVISOR, SOLICITADA_COMPLEMENTACAO.');
        END IF;

        IF p_ds_justificativa IS NULL OR LENGTH(TRIM(p_ds_justificativa)) < 10 THEN
            RAISE_APPLICATION_ERROR(-20012, 'Justificativa de revisão obrigatória (mínimo de 10 caracteres).');
        END IF;

        -- Localiza item
        SELECT CO_CONFERENCIA, ST_CONFERENCIA_ITEM, NO_PASSAGEIRO_ORIG
          INTO v_co_conferencia, v_status_antigo, v_nome_pass
          FROM TB_CONFERENCIA_ITEM
         WHERE CO_ITEM = p_co_item;

        -- Atualiza item
        UPDATE TB_CONFERENCIA_ITEM
           SET IC_REVISADO_HUMANO       = 'S',
               NO_USUARIO_REVISOR       = p_no_usuario_revisor,
               DH_REVISAO_HUMANA        = SYSTIMESTAMP,
               ST_DECISAO_HUMANA        = p_st_decisao,
               DS_JUSTIFICATIVA_REVISAO = p_ds_justificativa
         WHERE CO_ITEM = p_co_item;

        -- Grava auditoria imutável
        INSERT INTO TB_AUDITORIA_CONFERENCIA (
            CO_CONFERENCIA,
            CO_ITEM,
            NO_USUARIO,
            TP_ACAO,
            DS_JUSTIFICATIVA,
            DS_DADOS_ANTERIORES,
            DS_DADOS_NOVOS,
            DS_IP_CLIENTE
        ) VALUES (
            v_co_conferencia,
            p_co_item,
            p_no_usuario_revisor,
            'REVISAO_HUMANA_ITEM',
            p_ds_justificativa,
            'Status: ' || v_status_antigo || ' | Passageiro: ' || v_nome_pass || ' | Revisado: N',
            'Decisão: ' || p_st_decisao || ' | Revisado: S | Revisor: ' || p_no_usuario_revisor,
            p_ds_ip_cliente
        );

        SP_ATUALIZAR_TOTAIS_CONF(v_co_conferencia);
    END SP_REGISTRAR_REVISAO_HUMANA;

    -- ------------------------------------------------------------------------
    -- Atualização dos contadores da conferência
    -- ------------------------------------------------------------------------
    PROCEDURE SP_ATUALIZAR_TOTAIS_CONF(
        p_co_conferencia IN NUMBER
    ) IS
    BEGIN
        UPDATE TB_CONFERENCIA_VIAGEM c
           SET QT_TOTAL_ITENS    = (SELECT COUNT(*) FROM TB_CONFERENCIA_ITEM WHERE CO_CONFERENCIA = p_co_conferencia),
               QT_CONFERIDO_OK   = (SELECT COUNT(*) FROM TB_CONFERENCIA_ITEM WHERE CO_CONFERENCIA = p_co_conferencia AND ST_CONFERENCIA_ITEM = 'CONFERIDO_SEM_DIVERGENCIA'),
               QT_DIVERGENCIA    = (SELECT COUNT(*) FROM TB_CONFERENCIA_ITEM WHERE CO_CONFERENCIA = p_co_conferencia AND ST_CONFERENCIA_ITEM = 'DIVERGENCIA'),
               QT_REQUER_REVISAO = (SELECT COUNT(*) FROM TB_CONFERENCIA_ITEM WHERE CO_CONFERENCIA = p_co_conferencia AND ST_CONFERENCIA_ITEM IN ('REQUER_REVISAO', 'CORRESPONDENCIA_AMBIGUA', 'DADO_AUSENTE'))
         WHERE c.CO_CONFERENCIA = p_co_conferencia;
    END SP_ATUALIZAR_TOTAIS_CONF;

END PKG_CONFERENCIA_VIAGEM;
/

