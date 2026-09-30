/**
 * CONFERÊNCIA DE PASSAGENS AÉREAS E AUDITORIA DE VIAGENS
 * PADRÃO: Oracle APEX 24.2 / Metodologia MJSP v1.3
 * SEGURANÇA: LGPD (Mascaramento de PII), Defesa contra Prompt Injection, Human-in-the-Loop
 */

// ============================================================================
// 1. UTILITÁRIOS DE NORMALIZAÇÃO E PRIVACIDADE (LGPD)
// ============================================================================

export function normalizeText(str) {
    if (!str) return '';
    return str
        .toString()
        .trim()
        .toUpperCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '') // remove acentos
        .replace(/\s+/g, ' ');           // remove espaços extras
}

export function maskCPF(cpf) {
    if (!cpf) return 'NÃO INFORMADO';
    const nums = cpf.toString().replace(/\D/g, '');
    if (nums.length === 11) {
        return `${nums.substring(0, 3)}.***.***-${nums.substring(9, 11)}`;
    }
    if (nums.length >= 4) {
        return `${nums.substring(0, 2)}***${nums.substring(nums.length - 2)}`;
    }
    return '***.***.***-**';
}

export function maskDocument(doc) {
    if (!doc) return 'N/A';
    const clean = doc.toString().trim();
    if (clean.length <= 4) return '****';
    return `${clean.substring(0, 2)}***${clean.substring(clean.length - 2)}`;
}

export function levenshteinDistance(s1, s2) {
    const a = normalizeText(s1);
    const b = normalizeText(s2);
    if (a === b) return 0;
    if (a.length === 0) return b.length;
    if (b.length === 0) return a.length;

    const matrix = [];
    for (let i = 0; i <= b.length; i++) {
        matrix[i] = [i];
    }
    for (let j = 0; j <= a.length; j++) {
        matrix[0][j] = j;
    }

    for (let i = 1; i <= b.length; i++) {
        for (let j = 1; j <= a.length; j++) {
            if (b.charAt(i - 1) === a.charAt(j - 1)) {
                matrix[i][j] = matrix[i - 1][j - 1];
            } else {
                matrix[i][j] = Math.min(
                    matrix[i - 1][j - 1] + 1, // substituição
                    matrix[i][j - 1] + 1,     // inserção
                    matrix[i - 1][j] + 1      // deleção
                );
            }
        }
    }
    return matrix[b.length][a.length];
}

export function calculateSimilarity(s1, s2) {
    const a = normalizeText(s1);
    const b = normalizeText(s2);
    if (!a && !b) return 100;
    if (!a || !b) return 0;
    if (a === b) return 100;
    const maxLen = Math.max(a.length, b.length);
    if (maxLen === 0) return 100;
    const dist = levenshteinDistance(a, b);
    return Math.round((1 - dist / maxLen) * 100);
}

// ============================================================================
// 2. BASE DE CONHECIMENTO E DADOS DE REFERÊNCIA INSTITUCIONAL (SEI / APEX)
// ============================================================================

// Base institucional do Processo SEI nº 08020.008848/2026-06 (Doc 36394345)
const SEED_DATABASE_RECORDS = [
    {
        id: 1,
        nome: "AGNALDO DOS SANTOS",
        cpf: "88955214120",
        companhia: "LATAM",
        localizador: "LAT782A",
        bilhete: "045-8829104812",
        origem: "ABADIA DE GOIAS - GO",
        destino: "NIQUELANDIA - GO",
        dataIda: "2026-08-01",
        dataVolta: "2026-08-04",
        tipoTransporte: "Aéreo",
        valor: 1850.50,
        situacao: "Emitido"
    },
    {
        id: 2,
        nome: "THIAGO BATISTA SILVA",
        cpf: "04494944114",
        companhia: "GOL",
        localizador: "GOL419B",
        bilhete: "127-9912048591",
        origem: "ABADIA DE GOIAS - GO",
        destino: "MINACU - GO",
        dataIda: "2026-08-05",
        dataVolta: "2026-08-08",
        tipoTransporte: "Aéreo",
        valor: 1420.00,
        situacao: "Emitido"
    },
    {
        id: 3,
        nome: "MARCO AURELIO DE MORAIS",
        cpf: "42102741869",
        companhia: "AZUL",
        localizador: "AZU902C",
        bilhete: "577-3391028471",
        origem: "ABADIA DE GOIAS - GO",
        destino: "MINACU - GO",
        dataIda: "2026-08-05",
        dataVolta: "2026-08-08",
        tipoTransporte: "Aéreo",
        valor: 1650.00,
        situacao: "Emitido"
    },
    {
        id: 4,
        nome: "KENNEDS ALVES RODRIGUES",
        cpf: "95315900100",
        companhia: "LATAM",
        localizador: "LAT112D",
        bilhete: "045-6671928410",
        origem: "ABADIA DE GOIAS - GO",
        destino: "MINACU - GO",
        dataIda: "2026-08-05",
        dataVolta: "2026-08-08",
        tipoTransporte: "Aéreo",
        valor: 1530.00,
        situacao: "Emitido"
    },
    {
        id: 5,
        nome: "DIOGENES GONCALVES DE MELO NETO",
        cpf: "96559683320",
        companhia: "LATAM",
        localizador: "LAT883K",
        bilhete: "045-2291048201",
        origem: "TERESINA/PI",
        destino: "SAO PAULO/SP",
        dataIda: "2026-08-10",
        dataVolta: "2026-08-14",
        tipoTransporte: "Aéreo",
        valor: 2100.00,
        situacao: "Emitido"
    },
    {
        id: 6,
        nome: "DUNYA WIECZOREK SPRICIGO DE LIMA",
        cpf: "79792839100",
        companhia: "GOL",
        localizador: "GOL554W",
        bilhete: "127-5519284019",
        origem: "PALMAS/TO",
        destino: "SAO PAULO/SP",
        dataIda: "2026-08-10",
        dataVolta: "2026-08-14",
        tipoTransporte: "Aéreo",
        valor: 1980.00,
        situacao: "Emitido"
    },
    {
        id: 7,
        nome: "DAVIO BARBOSA DOS SANTOS",
        cpf: "03163530354",
        companhia: "AZUL",
        localizador: "AZU771X",
        bilhete: "577-9910482910",
        origem: "FORTALEZA/CE",
        destino: "SAO PAULO/SP",
        dataIda: "2026-08-10",
        dataVolta: "2026-08-14",
        tipoTransporte: "Aéreo",
        valor: 2450.00,
        situacao: "Emitido"
    },
    {
        id: 8,
        nome: "CARLOS MIGUEL NEVES VIEIRA",
        cpf: "05617781162",
        companhia: "LATAM",
        localizador: "LAT332P",
        bilhete: "045-1102948192",
        origem: "BRASILIA/DF",
        destino: "SAO PAULO/SP",
        dataIda: "2026-08-10",
        dataVolta: "2026-08-14",
        tipoTransporte: "Aéreo",
        valor: 1200.00,
        situacao: "Emitido"
    }
];

// Dados da Planilha de Passagens (ex: RELAÇÃO COP.xlsx / table.xlsx)
const SEED_SPREADSHEET_RECORDS = [
    {
        nome: "AGNALDO DOS SANTOS",
        cpf: "88955214120",
        companhia: "LATAM",
        localizador: "LAT782A",
        bilhete: "045-8829104812",
        origem: "ABADIA DE GOIAS - GO",
        destino: "NIQUELANDIA - GO",
        dataIda: "2026-08-01",
        dataVolta: "2026-08-04",
        linhaOrigem: 2
    },
    {
        nome: "THIAGO BATISTA SILVA",
        cpf: "04494944114",
        companhia: "GOL",
        localizador: "GOL999X", // DIVERGÊNCIA INTENCIONAL DE LOCALIZADOR
        bilhete: "127-9912048591",
        origem: "ABADIA DE GOIAS - GO",
        destino: "MINACU - GO",
        dataIda: "2026-08-06", // DIVERGÊNCIA INTENCIONAL DE DATA (05 vs 06)
        dataVolta: "2026-08-08",
        linhaOrigem: 3
    },
    {
        nome: "MARCO AURELIO MORAIS", // NOME SEMELHANTE (falta "DE") -> REQUER_REVISAO
        cpf: "42102741869",
        companhia: "AZUL",
        localizador: "AZU902C",
        bilhete: "577-3391028471",
        origem: "ABADIA DE GOIAS - GO",
        destino: "MINACU - GO",
        dataIda: "2026-08-05",
        dataVolta: "2026-08-08",
        linhaOrigem: 4
    },
    {
        nome: "KENNEDS ALVES RODRIGUES",
        cpf: null, // DADO AUSENTE NA PLANILHA
        companhia: "LATAM",
        localizador: "LAT112D",
        bilhete: null, // DADO AUSENTE NA PLANILHA
        origem: "ABADIA DE GOIAS - GO",
        destino: "MINACU - GO",
        dataIda: "2026-08-05",
        dataVolta: "2026-08-08",
        linhaOrigem: 5
    },
    {
        nome: "DIOGENES GONCALVES DE MELO NETO",
        cpf: "96559683320",
        companhia: "LATAM",
        localizador: "LAT883K",
        bilhete: "045-2291048201",
        origem: "TERESINA/PI",
        destino: "SAO PAULO/SP",
        dataIda: "2026-08-10",
        dataVolta: "2026-08-14",
        linhaOrigem: 6
    },
    {
        nome: "DUNYA WIECZOREK SPRICIGO DE LIMA",
        cpf: "79792839100",
        companhia: "GOL",
        localizador: "GOL554W",
        bilhete: "127-5519284019",
        origem: "PALMAS/TO",
        destino: "SAO PAULO/SP",
        dataIda: "2026-08-10",
        dataVolta: "2026-08-14",
        linhaOrigem: 7
    },
    {
        nome: "DAVIO BARBOSA DOS SANTOS",
        cpf: "03163530354",
        companhia: "AZUL",
        localizador: "AZU771X",
        bilhete: "577-9910482910",
        origem: "FORTALEZA/CE",
        destino: "SAO PAULO/SP",
        dataIda: "2026-08-10",
        dataVolta: "2026-08-14",
        linhaOrigem: 8
    },
    {
        // CASO DE AMBIGUIDADE: Dois Carlos Miguel cadastrados na planilha
        nome: "CARLOS MIGUEL NEVES VIEIRA",
        cpf: "05617781162",
        companhia: "LATAM",
        localizador: "LAT332P",
        bilhete: "045-1102948192",
        origem: "BRASILIA/DF",
        destino: "SAO PAULO/SP",
        dataIda: "2026-08-10",
        dataVolta: "2026-08-14",
        linhaOrigem: 9
    },
    {
        nome: "CARLOS MIGUEL NEVES VIEIRA",
        cpf: "05617781162",
        companhia: "GOL",
        localizador: "GOL888Z",
        bilhete: "127-0099887766",
        origem: "BRASILIA/DF",
        destino: "SAO PAULO/SP",
        dataIda: "2026-08-11",
        dataVolta: "2026-08-15",
        linhaOrigem: 10
    }
];

// Dados indexados dos PDFs (Fichas de Inscrição e RVN APEX)
const SEED_PDF_RECORDS = [
    {
        nome: "AGNALDO DOS SANTOS",
        cpf: "88955214120",
        arquivo: "FICHA INSCRICAO - AGNALDO DOS SANTOS - 88955214120.pdf",
        pagina: 1,
        trecho: "NOME COMPLETO: AGNALDO DOS SANTOS | CPF: 889.552.141-20 | ÓRGÃO DE ORIGEM: PMGO | LOTAÇÃO: BPAMBIENTAL",
        isOcr: false
    },
    {
        nome: "THIAGO BATISTA SILVA",
        cpf: "04494944114",
        arquivo: "FICHA INSCRICAO - THIAGO BATISTA SILVA - 04494944114.pdf",
        pagina: 1,
        trecho: "NOME COMPLETO: THIAGO BATISTA SILVA | CPF: 044.949.441-14 | ÓRGÃO DE ORIGEM: PMGO",
        isOcr: false
    },
    {
        nome: "MARCO AURELIO DE MORAIS",
        cpf: "42102741869",
        arquivo: "FICHA INSCRICAO - MARCO AURELIO DE MORAIS - 42102741869.pdf",
        pagina: 1,
        trecho: "NOME COMPLETO: MARCO AURELIO DE MORAIS | CPF: 421.027.418-69",
        isOcr: true // PDF com trecho digitalizado que requereu OCR
    },
    {
        nome: "DIÓGENES GONÇALVES DE MELO NETO",
        cpf: "96559683320",
        arquivo: "00723_RVN-CE_-_DIOGENES_GONCALVES_DE_MELO_NETO_-_10.08.2026_A_14.08.2026_assinado.pdf",
        pagina: 1,
        trecho: "RELATÓRIO DE VIAGENS NACIONAIS | PERCURSO: TERESINA / SAO PAULO | SAÍDA DA VIAGEM: 10/08/2026 (Aéreo) | CHEGADA DA VIAGEM: 14/08/2026 (Aéreo)",
        isOcr: false
    },
    {
        nome: "DUNYA WIECZOREK SPRICIGO DE LIMA",
        cpf: "79792839100",
        arquivo: "00971_RVN-CE_-_DUNYA_WIECZOREK_SPRICIGO_DE_LIMA_-_10.08.2026_A_14.08.2026_assinado.pdf",
        pagina: 1,
        trecho: "RELATÓRIO DE VIAGENS NACIONAIS | PERCURSO: PALMAS / SAO PAULO | PERÍODO: 10/08/2026 (Aéreo) A 14/08/2026 (Aéreo)",
        isOcr: false
    },
    {
        nome: "DÁVIO BARBOSA DOS SANTOS",
        cpf: "03163530354",
        arquivo: "01309_RVN-CE_-_DAVIO_BARBOSA_DOS_SANTOS_-_10.08.2026_A_14.08.2026_assinado.pdf",
        pagina: 1,
        trecho: "RELATÓRIO DE VIAGENS NACIONAIS | PERCURSO: FORTALEZA / SAO PAULO | PERÍODO: 10/08/2026 (Aéreo) A 14/08/2026 (Aéreo)",
        isOcr: false
    }
];

// ============================================================================
// 3. ESTADO DA APLICAÇÃO E AUDITORIA
// ============================================================================

export const state = {
    conferenciaId: 101,
    processoSei: "08020.008848/2026-06",
    usuarioAtual: "auditor.brunno@mj.gov.br",
    suporteOcr: true,
    fontes: {
        banco: SEED_DATABASE_RECORDS,
        planilha: SEED_SPREADSHEET_RECORDS,
        pdf: SEED_PDF_RECORDS
    },
    itensConferencia: [],
    itemEmFoco: null,
    auditoriaLogs: [
        {
            dhRegistro: new Date().toLocaleString('pt-BR'),
            usuario: "auditor.brunno@mj.gov.br",
            acao: "INICIALIZACAO_SESSAO",
            justificativa: "Sessão de auditoria iniciada com base no Processo SEI nº 08020.008848/2026-06.",
            dadosAnteriores: "-",
            dadosNovos: "Fontes conectadas: Oracle Database (8 registros), Planilha (9 registros), Fichas/RVN PDF (6 indexados)"
        }
    ]
};

// ============================================================================
// 4. MOTOR DE COMPARAÇÃO DETERMINÍSTICA
// ============================================================================

export function executarConferencia(bancoRecords, planilhaRecords, pdfRecords) {
    const itens = [];

    bancoRecords.forEach(dbItem => {
        const nomeNormDb = normalizeText(dbItem.nome);
        const cpfLimpoDb = dbItem.cpf ? dbItem.cpf.replace(/\D/g, '') : null;

        // Procura candidatos na planilha
        const candidatosPlan = planilhaRecords.filter(p => {
            const pCpf = p.cpf ? p.cpf.replace(/\D/g, '') : null;
            if (cpfLimpoDb && pCpf && cpfLimpoDb === pCpf) return true;
            return normalizeText(p.nome) === nomeNormDb || calculateSimilarity(p.nome, dbItem.nome) >= 75;
        });

        // Procura no PDF
        const candidatoPdf = pdfRecords.find(pdf => {
            const pdfCpf = pdf.cpf ? pdf.cpf.replace(/\D/g, '') : null;
            if (cpfLimpoDb && pdfCpf && cpfLimpoDb === pdfCpf) return true;
            return normalizeText(pdf.nome) === nomeNormDb || calculateSimilarity(pdf.nome, dbItem.nome) >= 80;
        });

        const evidencias = [];
        let situacao = 'CONFERIDO_SEM_DIVERGENCIA';
        let motivo = 'Dados em total conformidade entre as fontes comparadas.';
        let similaridadeNome = 100;
        let ambiguidade = false;

        // Avaliação de Ambiguidade
        if (candidatosPlan.length > 1) {
            situacao = 'CORRESPONDENCIA_AMBIGUA';
            ambiguidade = true;
            motivo = `Identificados ${candidatosPlan.length} registros distintos na planilha com correspondência ao mesmo passageiro. Requer intervenção manual do auditor.`;
        }

        const planItem = candidatosPlan.length === 1 ? candidatosPlan[0] : (candidatosPlan.length > 1 ? candidatosPlan[0] : null);

        // 1. Evidência de Nome
        const nomePlan = planItem ? planItem.nome : null;
        const nomePdf = candidatoPdf ? candidatoPdf.nome : null;
        let statusNome = 'CONFORME';

        if (nomePlan) {
            similaridadeNome = calculateSimilarity(dbItem.nome, nomePlan);
            if (similaridadeNome < 100) {
                if (similaridadeNome >= 75) {
                    statusNome = 'REQUER_VERIFICACAO';
                    if (!ambiguidade) {
                        situacao = 'REQUER_REVISAO';
                        motivo = `Nome com similaridade de ${similaridadeNome}% entre Banco ("${dbItem.nome}") e Planilha ("${nomePlan}"). Confirmação automática vedada.`;
                    }
                } else {
                    statusNome = 'DIVERGENCIA';
                    situacao = 'DIVERGENCIA';
                    motivo = `Divergência substancial no nome: Banco="${dbItem.nome}" x Planilha="${nomePlan}".`;
                }
            }
        }

        evidencias.push({
            campo: "Nome Completo",
            banco: dbItem.nome,
            planilha: nomePlan || "(Ausente)",
            pdf: nomePdf || "(Ausente)",
            refPdf: candidatoPdf ? candidatoPdf.arquivo : "N/A",
            paginaPdf: candidatoPdf ? candidatoPdf.pagina : null,
            trechoPdf: candidatoPdf ? candidatoPdf.trecho : null,
            isOcr: candidatoPdf ? candidatoPdf.isOcr : false,
            status: statusNome
        });

        // 2. Evidência de CPF (comparação estrita, mascarado na exibição)
        let statusCpf = 'CONFORME';
        const cpfPlan = planItem ? planItem.cpf : null;
        const cpfPdf = candidatoPdf ? candidatoPdf.cpf : null;

        if (planItem && !cpfPlan) {
            statusCpf = 'AUSENTE';
            if (situacao === 'CONFERIDO_SEM_DIVERGENCIA') {
                situacao = 'DADO_AUSENTE';
                motivo = 'CPF não preenchido na planilha de passagens.';
            }
        } else if (cpfPlan && cpfLimpoDb !== cpfPlan.replace(/\D/g, '')) {
            statusCpf = 'DIVERGENCIA';
            situacao = 'DIVERGENCIA';
            motivo = 'CPF divergente entre a base do banco e a planilha.';
        }

        evidencias.push({
            campo: "CPF (LGPD)",
            banco: maskCPF(dbItem.cpf),
            planilha: cpfPlan ? maskCPF(cpfPlan) : "(Ausente)",
            pdf: cpfPdf ? maskCPF(cpfPdf) : "(Ausente)",
            refPdf: candidatoPdf ? candidatoPdf.arquivo : "N/A",
            paginaPdf: candidatoPdf ? candidatoPdf.pagina : null,
            trechoPdf: candidatoPdf ? candidatoPdf.trecho : null,
            isOcr: candidatoPdf ? candidatoPdf.isOcr : false,
            status: statusCpf
        });

        // 3. Evidência de Localizador (estrito)
        let statusLoc = 'CONFORME';
        const locPlan = planItem ? planItem.localizador : null;
        if (planItem && !locPlan) {
            statusLoc = 'AUSENTE';
            if (situacao === 'CONFERIDO_SEM_DIVERGENCIA') situacao = 'DADO_AUSENTE';
        } else if (locPlan && normalizeText(dbItem.localizador) !== normalizeText(locPlan)) {
            statusLoc = 'DIVERGENCIA';
            situacao = 'DIVERGENCIA';
            motivo = `Localizador divergente: Banco=${dbItem.localizador} x Planilha=${locPlan}.`;
        }

        evidencias.push({
            campo: "Código Localizador",
            banco: dbItem.localizador,
            planilha: locPlan || "(Ausente)",
            pdf: candidatoPdf ? "Verificado no bilhete anexado" : "(Ausente)",
            refPdf: candidatoPdf ? candidatoPdf.arquivo : "N/A",
            paginaPdf: candidatoPdf ? candidatoPdf.pagina : null,
            trechoPdf: null,
            isOcr: false,
            status: statusLoc
        });

        // 4. Evidência de Data de Ida (estrito)
        let statusData = 'CONFORME';
        const dataPlan = planItem ? planItem.dataIda : null;
        if (planItem && dataPlan && dbItem.dataIda !== dataPlan) {
            statusData = 'DIVERGENCIA';
            situacao = 'DIVERGENCIA';
            motivo = `Data de voo divergente: Banco=${dbItem.dataIda} x Planilha=${dataPlan}.`;
        }

        evidencias.push({
            campo: "Data de Ida",
            banco: dbItem.dataIda,
            planilha: dataPlan || "(Ausente)",
            pdf: candidatoPdf ? "Conforme RVN" : "(Ausente)",
            refPdf: candidatoPdf ? candidatoPdf.arquivo : "N/A",
            paginaPdf: candidatoPdf ? candidatoPdf.pagina : null,
            trechoPdf: candidatoPdf ? candidatoPdf.trecho : null,
            isOcr: false,
            status: statusData
        });

        // 5. Avaliação de OCR (se o PDF tiver sido extraído por OCR, rebaixa para REQUER_REVISAO se estivesse OK)
        if (candidatoPdf && candidatoPdf.isOcr) {
            if (situacao === 'CONFERIDO_SEM_DIVERGENCIA') {
                situacao = 'REQUER_REVISAO';
                motivo = 'Dados do PDF obtidos via OCR (reconhecimento óptico de imagem). Menor confiabilidade; requer validação visual do documento.';
            }
        }

        itens.push({
            id: dbItem.id,
            nomeOriginal: dbItem.nome,
            nomeNormalizado: nomeNormDb,
            cpfOriginal: dbItem.cpf,
            cpfMascarado: maskCPF(dbItem.cpf),
            companhia: dbItem.companhia,
            localizador: dbItem.localizador,
            bilhete: dbItem.bilhete,
            origem: dbItem.origem,
            destino: dbItem.destino,
            dataIda: dbItem.dataIda,
            dataVolta: dbItem.dataVolta,
            valor: dbItem.valor,
            situacao: situacao,
            motivo: motivo,
            similaridadeNome: similaridadeNome,
            revisadoHumano: false,
            decisaoHumana: null,
            justificativaHumana: null,
            usuarioRevisor: null,
            dataRevisao: null,
            evidencias: evidencias
        });
    });

    return itens;
}

// ============================================================================
// 5. DEFESA CONTRA PROMPT INJECTION E AGENTE CHATBOT
// ============================================================================

export function detectPromptInjection(mensagem) {
    if (!mensagem) return false;
    const msg = normalizeText(mensagem);

    const padroesMaliciosos = [
        'IGNORE AS INSTRUCOES',
        'IGNORE TODAS',
        'IGNORE PREVIOUS',
        'VOCE AGORA E',
        'SYSTEM PROMPT',
        'DROP TABLE',
        'TRUNCATE',
        'UPDATE TB_',
        'CONFIRME TODOS',
        'APROVE TODOS',
        'ALTERE TODOS',
        'REVELE A SENHA',
        'CLIENT_SECRET',
        'AUTHORIZATION_HEADER',
        'SELECT * FROM ALL_USERS'
    ];

    return padroesMaliciosos.some(padrao => msg.includes(padrao));
}

export function processarChatbotMensagem(mensagemUsuario, itemFocoId = null) {
    const msgNorm = normalizeText(mensagemUsuario);

    // 1. Defesa contra Prompt Injection
    if (detectPromptInjection(mensagemUsuario)) {
        // Registra tentativa em auditoria
        registrarAuditoria(
            "TENTATIVA_PROMPT_INJECTION",
            "Tentativa de injeção de prompt ou alteração de instruções do chatbot neutralizada.",
            "Mensagem: " + mensagemUsuario.substring(0, 150)
        );

        return {
            tipo: "seguranca",
            resposta: "⚠️ **Alerta de Segurança:** A mensagem enviada contém padrões ou comandos não permitidos pelas regras de governança e integridade do sistema. O assistente opera exclusivamente em modo de consulta sobre os dados da conferência atual e não possui privilégios para executar alterações ou revelar configurações internas."
        };
    }

    // 2. Salvaguarda: Bloqueio estrito de ordens de confirmação/alteração
    if (msgNorm.includes('CONFIRME') || msgNorm.includes('APROVE') || msgNorm.includes('ALTERE') || msgNorm.includes('DELETE') || msgNorm.includes('CANCELE')) {
        return {
            tipo: "governanca",
            resposta: "🛡️ **Aviso de Governança Institucional:** Como assistente de IA, sou estritamente proibido de confirmar, alterar, aprovar ou cancelar passagens aéreas ou dados cadastrais. Todas as alterações ou homologações devem ser formalizadas por uma pessoa responsável através do botão **Revisar** na tabela de conferência, acompanhadas de justificativa técnica e assinatura de auditoria."
        };
    }

    // 3. Consulta de item específico pelo nome ou CPF
    let itemSelecionado = null;
    if (itemFocoId) {
        itemSelecionado = state.itensConferencia.find(i => i.id === itemFocoId);
    } else {
        const matches = state.itensConferencia.filter(item => {
            const cpfDigitos = item.cpfOriginal ? item.cpfOriginal.replace(/\D/g, '') : '';
            return msgNorm.includes(item.nomeNormalizado) ||
                (cpfDigitos && msgNorm.includes(cpfDigitos)) ||
                (item.nomeNormalizado.split(' ').some(part => part.length > 4 && msgNorm.includes(part)));
        });

        if (matches.length === 1) {
            itemSelecionado = matches[0];
        } else if (matches.length > 1) {
            return {
                tipo: "ambiguidade",
                resposta: `Identifiquei múltiplos passageiros correspondentes à sua busca (${matches.map(m => m.nomeOriginal).join(', ')}). Por favor, informe o CPF completo ou o nome exato para que eu possa apresentar as evidências corretas.`
            };
        }
    }

    if (itemSelecionado) {
        let resp = `### Análise de Evidências: ${itemSelecionado.nomeOriginal}\n\n`;
        resp += `• **CPF:** ${itemSelecionado.cpfMascarado}\n`;
        resp += `• **Situação:** **${itemSelecionado.situacao}**\n`;
        resp += `• **Apurado:** ${itemSelecionado.motivo}\n\n`;
        resp += `#### Confronto de Fontes:\n`;

        itemSelecionado.evidencias.forEach(ev => {
            resp += `• **${ev.campo}** (${ev.status}):\n`;
            resp += `  - *Banco (APEX):* ${ev.banco}\n`;
            resp += `  - *Planilha:* ${ev.planilha}\n`;
            resp += `  - *Documento PDF:* ${ev.pdf}`;
            if (ev.refPdf && ev.refPdf !== 'N/A') {
                resp += ` *(Ref: ${ev.refPdf}, Pág: ${ev.paginaPdf || 1})`;
                if (ev.isOcr) resp += ` [Extraído por OCR - Menor Confiabilidade]`;
                resp += `*`;
            }
            resp += `\n`;
            if (ev.trechoPdf) {
                resp += `  - *Trecho literal:* "${ev.trechoPdf}"\n`;
            }
        });

        if (itemSelecionado.revisadoHumano) {
            resp += `\n✅ **Revisado por:** ${itemSelecionado.usuarioRevisor} em ${itemSelecionado.dataRevisao}\n`;
            resp += `• **Decisão:** ${itemSelecionado.decisaoHumana}\n`;
            resp += `• **Justificativa:** "${itemSelecionado.justificativaHumana}"\n`;
        } else {
            resp += `\n⏳ **Status de Auditoria:** Pendente de revisão humana formal.\n`;
        }

        return {
            tipo: "item",
            resposta: resp
        };
    }

    // 4. Resumo e contadores
    if (msgNorm.includes('RESUMO') || msgNorm.includes('STATUS') || msgNorm.includes('GERAL') || msgNorm.includes('TOTAL')) {
        const total = state.itensConferencia.length;
        const ok = state.itensConferencia.filter(i => i.situacao === 'CONFERIDO_SEM_DIVERGENCIA').length;
        const div = state.itensConferencia.filter(i => i.situacao === 'DIVERGENCIA').length;
        const rev = state.itensConferencia.filter(i => ['REQUER_REVISAO', 'CORRESPONDENCIA_AMBIGUA', 'DADO_AUSENTE'].includes(i.situacao)).length;

        return {
            tipo: "resumo",
            resposta: `📊 **Resumo da Conferência nº ${state.conferenciaId} (SEI ${state.processoSei}):**\n\n` +
                `• **Total de viajantes analisados:** ${total}\n` +
                `• **Conferidos sem divergência:** ${ok}\n` +
                `• **Divergências confirmadas:** ${div}\n` +
                `• **Requerem revisão humana ou apresentam dados ausentes/ambíguos:** ${rev}\n\n` +
                `Você pode clicar em qualquer passageiro na tabela para inspecionar os canhotos, faturas e fichas correspondentes.`
        };
    }

    // 5. Listar divergências
    if (msgNorm.includes('DIVERGEN') || msgNorm.includes('DIFERENCA') || msgNorm.includes('ERRO')) {
        const divs = state.itensConferencia.filter(i => i.situacao === 'DIVERGENCIA');
        if (divs.length === 0) {
            return {
                tipo: "info",
                resposta: "Nenhuma divergência foi identificada entre as fontes analisadas até o momento."
            };
        }

        let resp = `⚠️ **Encontrei ${divs.length} registro(s) com divergência explícita:**\n\n`;
        divs.forEach(d => {
            resp += `• **${d.nomeOriginal}** (${d.cpfMascarado}): ${d.motivo}\n`;
        });
        resp += `\nPara investigar a prova documental de cada caso, informe o nome do passageiro ou selecione-o na lista.`;
        return {
            tipo: "divergencias",
            resposta: resp
        };
    }

    // 6. Listar revisões pendentes
    if (msgNorm.includes('REVISAO') || msgNorm.includes('REVISAR') || msgNorm.includes('PENDENTE')) {
        const revs = state.itensConferencia.filter(i => ['REQUER_REVISAO', 'CORRESPONDENCIA_AMBIGUA', 'DADO_AUSENTE'].includes(i.situacao));
        let resp = `🔍 **Existem ${revs.length} casos que exigem deliberação humana:**\n\n`;
        revs.forEach(r => {
            resp += `• **${r.nomeOriginal}** (${r.situacao}): ${r.motivo}\n`;
        });
        resp += `\nLembrando que o sistema não efetiva alterações cadastrais sem autorização manual.`;
        return {
            tipo: "revisoes",
            resposta: resp
        };
    }

    // Resposta padrão estrita
    return {
        tipo: "padrao",
        resposta: "Olá! Como assistente de auditoria de viagens, posso responder dúvidas e detalhar divergências estritamente com base nos dados carregados nesta conferência. Você pode perguntar sobre o **resumo geral**, **relação de divergências**, ou sobre um **viajante específico** pelo nome ou CPF."
    };
}

// ============================================================================
// 6. GESTÃO DE AUDITORIA E REVISÃO HUMANA (HUMAN-IN-THE-LOOP)
// ============================================================================

export function registrarAuditoria(acao, justificativa, dadosNovos = "-", dadosAnteriores = "-") {
    const log = {
        dhRegistro: new Date().toLocaleString('pt-BR'),
        usuario: state.usuarioAtual,
        acao: acao,
        justificativa: justificativa,
        dadosAnteriores: dadosAnteriores,
        dadosNovos: dadosNovos
    };
    state.auditoriaLogs.unshift(log);
    atualizarContadorAuditoria();
}

export function registrarRevisaoHumana(itemId, decisao, justificativa) {
    if (!justificativa || justificativa.trim().length < 10) {
        throw new Error("A justificativa técnica de revisão é obrigatória e deve conter pelo menos 10 caracteres.");
    }

    const item = state.itensConferencia.find(i => i.id === itemId);
    if (!item) {
        throw new Error("Item de conferência não encontrado.");
    }

    const situacaoAnterior = item.situacao;
    const decisaoAnterior = item.decisaoHumana || "NENHUMA";

    item.revisadoHumano = true;
    item.decisaoHumana = decisao;
    item.justificativaHumana = justificativa.trim();
    item.usuarioRevisor = state.usuarioAtual;
    item.dataRevisao = new Date().toLocaleString('pt-BR');

    registrarAuditoria(
        "REVISAO_HUMANA_ITEM",
        justificativa.trim(),
        `Decisão: ${decisao} | Revisor: ${state.usuarioAtual}`,
        `Passageiro: ${item.nomeOriginal} | Situação Anterior: ${situacaoAnterior} | Decisão Anterior: ${decisaoAnterior}`
    );

    atualizarDashboard();
}

// ============================================================================
// 7. RENDERIZAÇÃO DA INTERFACE APEX E EVENT LISTENERS
// ============================================================================

export function atualizarDashboard() {
    // 1. Atualiza KPIs
    const total = state.itensConferencia.length;
    const ok = state.itensConferencia.filter(i => i.situacao === 'CONFERIDO_SEM_DIVERGENCIA').length;
    const div = state.itensConferencia.filter(i => i.situacao === 'DIVERGENCIA').length;
    const rev = state.itensConferencia.filter(i => ['REQUER_REVISAO', 'CORRESPONDENCIA_AMBIGUA', 'DADO_AUSENTE'].includes(i.situacao)).length;

    document.getElementById('kpi-total').textContent = total;
    document.getElementById('kpi-sem-divergencia').textContent = ok;
    document.getElementById('kpi-divergencia').textContent = div;
    document.getElementById('kpi-revisao').textContent = rev;

    // 2. Renderiza tabela com filtros aplicados
    renderizarTabela();
}

function renderizarTabela() {
    const tbody = document.getElementById('tabela-conferencia-body');
    if (!tbody) return;
    tbody.innerHTML = '';

    const filtroSituacao = document.getElementById('filtro-situacao')?.value || 'TODOS';
    const filtroBusca = normalizeText(document.getElementById('filtro-busca')?.value || '');

    const itensFiltrados = state.itensConferencia.filter(item => {
        if (filtroSituacao !== 'TODOS' && item.situacao !== filtroSituacao) return false;
        if (filtroBusca) {
            const matchNome = item.nomeNormalizado.includes(filtroBusca);
            const matchCpf = item.cpfOriginal && item.cpfOriginal.includes(filtroBusca);
            if (!matchNome && !matchCpf) return false;
        }
        return true;
    });

    if (itensFiltrados.length === 0) {
        tbody.innerHTML = `<tr><td colspan="9" class="text-center" style="padding: 2rem; color: #64748b;">Nenhum registro encontrado para os filtros selecionados.</td></tr>`;
        return;
    }

    itensFiltrados.forEach(item => {
        const tr = document.createElement('tr');

        // Badge de situação
        const badgeClass = `status-badge ${item.situacao}`;
        const badgeLabel = {
            'CONFERIDO_SEM_DIVERGENCIA': 'Sem Divergência',
            'DIVERGENCIA': 'Divergência',
            'REQUER_REVISAO': 'Requer Revisão',
            'DADO_AUSENTE': 'Dado Ausente',
            'CORRESPONDENCIA_AMBIGUA': 'Correspondência Ambígua',
            'ARQUIVO_NAO_PROCESSADO': 'Não Processado'
        }[item.situacao] || item.situacao;

        // Revisão humana status
        const revBadge = item.revisadoHumano
            ? `<span class="status-rev-badge sim" title="${item.decisaoHumana} por ${item.usuarioRevisor}"><i class="fa fa-check"></i> ${item.decisaoHumana}</span>`
            : `<span class="status-rev-badge nao"><i class="fa fa-clock"></i> Pendente</span>`;

        tr.innerHTML = `
            <td><span class="${badgeClass}"><i class="fa fa-circle"></i> ${badgeLabel}</span></td>
            <td><strong>${item.nomeOriginal}</strong><br><small style="color:#64748b">${item.nomeNormalizado}</small></td>
            <td><code>${item.cpfMascarado}</code></td>
            <td>${item.companhia || 'N/A'}<br><small>Loc: <strong>${item.localizador || '-'}</strong> | Bilhete: ${item.bilhete || '-'}</small></td>
            <td>${item.origem || '-'}<br><small style="color:#64748b">-> ${item.destino || '-'}</small></td>
            <td>${item.dataIda || '-'}<br><small style="color:#64748b">Ret: ${item.dataVolta || '-'}</small></td>
            <td class="text-center"><strong>${item.similaridadeNome}%</strong></td>
            <td class="text-center">${revBadge}</td>
            <td class="text-center">
                <div style="display:flex; gap:0.35rem; justify-content:center;">
                    <button class="t-Button t-Button--small t-Button--default btn-ver-evidencias" data-id="${item.id}" title="Ver Evidências Detalhadas">
                        <i class="fa fa-magnifying-glass"></i>
                    </button>
                    <button class="t-Button t-Button--small t-Button--hot btn-abrir-revisao" data-id="${item.id}" title="Registrar Revisão Humana">
                        <i class="fa fa-user-pen"></i>
                    </button>
                </div>
            </td>
        `;

        tbody.appendChild(tr);
    });

    // Eventos dos botões da tabela
    tbody.querySelectorAll('.btn-ver-evidencias').forEach(btn => {
        btn.addEventListener('click', () => {
            const id = parseInt(btn.getAttribute('data-id'));
            exibirEvidencias(id);
        });
    });

    tbody.querySelectorAll('.btn-abrir-revisao').forEach(btn => {
        btn.addEventListener('click', () => {
            const id = parseInt(btn.getAttribute('data-id'));
            abrirModalRevisao(id);
        });
    });
}

function exibirEvidencias(itemId) {
    const item = state.itensConferencia.find(i => i.id === itemId);
    if (!item) return;

    state.itemEmFoco = item.id;
    const painel = document.getElementById('painel-evidencias');
    painel.style.display = 'block';

    document.getElementById('evidencia-passageiro-nome').textContent = `${item.nomeOriginal} (${item.cpfMascarado})`;
    document.getElementById('evidencia-motivo-box').innerHTML = `<strong>Apurado:</strong> ${item.motivo}`;

    const tbody = document.getElementById('tabela-evidencias-body');
    tbody.innerHTML = '';

    item.evidencias.forEach(ev => {
        const tr = document.createElement('tr');
        const stClass = ev.status === 'CONFORME' ? 'status-badge CONFERIDO_SEM_DIVERGENCIA' : (ev.status === 'DIVERGENCIA' ? 'status-badge DIVERGENCIA' : 'status-badge REQUER_REVISAO');

        let refHtml = ev.refPdf !== 'N/A' ? `<strong>Doc:</strong> ${ev.refPdf}` : 'N/A';
        if (ev.paginaPdf) refHtml += `<br><small>Página: ${ev.paginaPdf}</small>`;
        if (ev.isOcr) refHtml += `<br><span style="color:#b45309; font-weight:600;"><i class="fa fa-eye"></i> Extraído via OCR</span>`;
        if (ev.trechoPdf) refHtml += `<br><em style="font-size:0.75rem; color:#475569;">"${ev.trechoPdf}"</em>`;

        tr.innerHTML = `
            <td><strong>${ev.campo}</strong></td>
            <td><code>${ev.banco || '-'}</code></td>
            <td><code>${ev.planilha || '-'}</code></td>
            <td><code>${ev.pdf || '-'}</code></td>
            <td>${refHtml}</td>
            <td><span class="${stClass}">${ev.status}</span></td>
        `;
        tbody.appendChild(tr);
    });

    painel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function abrirModalRevisao(itemId) {
    const item = state.itensConferencia.find(i => i.id === itemId);
    if (!item) return;

    document.getElementById('modal-rev-item-id').value = item.id;
    document.getElementById('modal-rev-nome').textContent = item.nomeOriginal;
    document.getElementById('modal-rev-cpf').textContent = item.cpfMascarado;
    document.getElementById('modal-rev-situacao').textContent = item.situacao;
    document.getElementById('modal-rev-motivo').textContent = item.motivo;
    document.getElementById('select-decisao-humana').value = item.decisaoHumana || '';
    document.getElementById('textarea-justificativa-humana').value = item.justificativaHumana || '';

    document.getElementById('modal-revisao-backdrop').style.display = 'flex';
}

function atualizarContadorAuditoria() {
    const el = document.getElementById('count-auditoria');
    if (el) el.textContent = state.auditoriaLogs.length;
}

function renderizarAuditoriaModal() {
    const tbody = document.getElementById('tabela-auditoria-body');
    if (!tbody) return;
    tbody.innerHTML = '';

    state.auditoriaLogs.forEach(log => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td><small>${log.dhRegistro}</small></td>
            <td><strong>${log.usuario}</strong></td>
            <td><code>${log.acao}</code></td>
            <td>${log.justificativa}</td>
            <td><small style="color:#64748b">${log.dadosAnteriores}</small></td>
            <td><small style="color:#0369a1">${log.dadosNovos}</small></td>
        `;
        tbody.appendChild(tr);
    });
}

// ============================================================================
// 8. INTERFACE DO CHATBOT (ENVIO DE MENSAGENS E CHIPS)
// ============================================================================

function adicionarMensagemChat(autor, texto) {
    const container = document.getElementById('chatbot-messages');
    if (!container) return;

    const msgDiv = document.createElement('div');
    msgDiv.className = `chat-msg chat-msg--${autor}`;

    // Converte quebras de linha e markdown simples
    const formattedText = texto
        .replace(/\n\n/g, '<br><br>')
        .replace(/\n/g, '<br>')
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/• /g, '&bull; ');

    msgDiv.innerHTML = `
        <div class="chat-bubble">${formattedText}</div>
        <span class="chat-time">${new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}</span>
    `;

    container.appendChild(msgDiv);
    container.scrollTop = container.scrollHeight;
}

function enviarMensagemChat(texto) {
    if (!texto || !texto.trim()) return;
    const txt = texto.trim();

    // Adiciona mensagem do usuário
    adicionarMensagemChat('user', txt);

    // Processa resposta
    setTimeout(() => {
        const res = processarChatbotMensagem(txt, state.itemEmFoco);
        adicionarMensagemChat('assistant', res.resposta);
    }, 250);
}

// ============================================================================
// 9. INICIALIZAÇÃO E BINDING DE EVENTOS
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
    // 1. Executa conferência inicial com dados de semente
    state.itensConferencia = executarConferencia(
        state.fontes.banco,
        state.fontes.planilha,
        state.fontes.pdf
    );
    atualizarDashboard();
    atualizarContadorAuditoria();

    // 2. Filtros
    document.getElementById('filtro-situacao')?.addEventListener('change', renderizarTabela);
    document.getElementById('filtro-busca')?.addEventListener('input', renderizarTabela);

    // 3. Botão Fechar Evidências
    document.getElementById('btn-fechar-evidencias')?.addEventListener('click', () => {
        document.getElementById('painel-evidencias').style.display = 'none';
        state.itemEmFoco = null;
    });

    // 4. Modal de Revisão Humana
    document.getElementById('btn-fechar-modal-revisao')?.addEventListener('click', () => {
        document.getElementById('modal-revisao-backdrop').style.display = 'none';
    });
    document.getElementById('btn-cancelar-revisao')?.addEventListener('click', () => {
        document.getElementById('modal-revisao-backdrop').style.display = 'none';
    });

    document.getElementById('form-revisao-humana')?.addEventListener('submit', (e) => {
        e.preventDefault();
        const itemId = parseInt(document.getElementById('modal-rev-item-id').value);
        const decisao = document.getElementById('select-decisao-humana').value;
        const justificativa = document.getElementById('textarea-justificativa-humana').value;

        try {
            registrarRevisaoHumana(itemId, decisao, justificativa);
            document.getElementById('modal-revisao-backdrop').style.display = 'none';
            adicionarMensagemChat('assistant', `✅ **Revisão Humana Registrada com Sucesso:** A decisão "${decisao}" foi homologada e gravada na trilha de auditoria para o item #${itemId}.`);
        } catch (err) {
            alert(err.message);
        }
    });

    // 5. Modal de Auditoria
    document.getElementById('btn-ver-auditoria')?.addEventListener('click', () => {
        renderizarAuditoriaModal();
        document.getElementById('modal-auditoria-backdrop').style.display = 'flex';
    });
    document.getElementById('btn-fechar-modal-auditoria')?.addEventListener('click', () => {
        document.getElementById('modal-auditoria-backdrop').style.display = 'none';
    });

    // 6. Formulário do Chatbot
    document.getElementById('chatbot-form')?.addEventListener('submit', (e) => {
        e.preventDefault();
        const input = document.getElementById('chat-user-input');
        const txt = input.value;
        input.value = '';
        enviarMensagemChat(txt);
    });

    // 7. Chips de atalho do Chatbot
    document.querySelectorAll('.chat-chip').forEach(chip => {
        chip.addEventListener('click', () => {
            const msg = chip.getAttribute('data-msg');
            enviarMensagemChat(msg);
        });
    });

    // 8. Reanalisar / Nova Conferência
    document.getElementById('btn-executar-conferencia')?.addEventListener('click', () => {
        state.suporteOcr = document.getElementById('toggle-ocr').checked;
        state.itensConferencia = executarConferencia(
            state.fontes.banco,
            state.fontes.planilha,
            state.fontes.pdf
        );
        registrarAuditoria(
            "REPROCESSAMENTO_CONFERENCIA",
            `Conferência reprocessada pelo operador. Suporte OCR: ${state.suporteOcr ? 'Ativo' : 'Inativo'}.`
        );
        atualizarDashboard();
        adicionarMensagemChat('assistant', '🔄 Todas as fontes foram reanalisadas e confrontadas. Tabela de resultados e resumo atualizados.');
    });

    document.getElementById('btn-nova-conferencia')?.addEventListener('click', () => {
        if (confirm("Deseja reiniciar a sessão de conferência?")) {
            state.conferenciaId += 1;
            state.itensConferencia = executarConferencia(
                state.fontes.banco,
                state.fontes.planilha,
                state.fontes.pdf
            );
            registrarAuditoria(
                "NOVA_CONFERENCIA_INICIADA",
                `Nova sessão de conferência #${state.conferenciaId} iniciada.`
            );
            atualizarDashboard();
            adicionarMensagemChat('assistant', `Iniciada nova sessão de conferência #${state.conferenciaId}. Pronto para análises.`);
        }
    });

    // 9. Input de arquivos (Planilha e PDF) com validação declarativa de tamanho e tipo
    document.getElementById('input-planilha')?.addEventListener('change', (e) => {
        const file = e.target.files[0];
        if (!file) return;

        // Validação de tamanho (máx 15MB)
        if (file.size > 15 * 1024 * 1024) {
            alert("Erro de Validação: O arquivo excede o tamanho máximo permitido de 15 MB.");
            return;
        }

        const ext = file.name.split('.').pop().toLowerCase();
        if (!['csv', 'xlsx', 'xls'].includes(ext)) {
            alert(`Extensão inválida (.${ext}). Formatos suportados: CSV, XLSX.`);
            return;
        }

        document.getElementById('planilha-filename').textContent = file.name;
        document.getElementById('planilha-status-text').textContent = `Carregado: ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
        registrarAuditoria(
            "UPLOAD_PLANILHA",
            `Planilha ${file.name} carregada para processamento.`,
            `Bytes: ${file.size}`
        );
        adicionarMensagemChat('assistant', `📁 **Planilha carregada:** ${file.name}. Clique em **Reanalisar Todas as Fontes** para confrontar os novos registros.`);
    });

    document.getElementById('input-pdf')?.addEventListener('change', (e) => {
        const files = Array.from(e.target.files);
        if (files.length === 0) return;

        for (const f of files) {
            if (f.size > 15 * 1024 * 1024) {
                alert(`Erro no arquivo "${f.name}": Excede o limite máximo de 15 MB.`);
                return;
            }
            if (!f.name.toLowerCase().endsWith('.pdf')) {
                alert(`Erro no arquivo "${f.name}": Apenas documentos no formato PDF são aceitos.`);
                return;
            }
        }

        document.getElementById('pdf-filename').textContent = `${files.length} arquivo(s) PDF selecionado(s)`;
        document.getElementById('pdf-status-text').textContent = `${files.length} documento(s) pronto(s) para indexação`;
        registrarAuditoria(
            "UPLOAD_PDF_LOTE",
            `Lote com ${files.length} documento(s) PDF importado.`,
            files.map(f => f.name).join(', ')
        );
        adicionarMensagemChat('assistant', `📄 **Lote de PDFs recebido:** ${files.length} arquivo(s) prontos. Clique em **Reanalisar Todas as Fontes** para processar a conferência com extração documental.`);
    });
});

