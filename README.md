<div align="center">

# ✈️ Conferência de Diárias e Passagens Aéreas

### Auditoria assistida por IA, com a decisão final sempre nas mãos de uma pessoa

![Oracle APEX](https://img.shields.io/badge/Oracle_APEX-F80000?style=for-the-badge&logo=oracle&logoColor=white)
![PL/SQL](https://img.shields.io/badge/PL%2FSQL-F80000?style=for-the-badge&logo=oracle&logoColor=white)
![ORDS](https://img.shields.io/badge/ORDS-312D2A?style=for-the-badge&logo=oracle&logoColor=white)

</div>

## 🎯 O que é

Um sistema de **conferência automatizada de passagens aéreas e dados de viajantes**. Ele cruza três fontes independentes e mostra, campo a campo, o que confere e o que diverge:

1. **Banco de dados Oracle**, acessado pelo Oracle APEX;
2. **Planilhas** (CSV e XLSX) de agências de viagem e escalas;
3. **Documentos em PDF**, como fichas de inscrição, canhotos de embarque e relatórios de viagem.

## ✨ Diferenciais

- 🧑‍⚖️ **A pessoa decide.** O assistente de IA só faz triagem, localiza evidências e apoia a decisão. Ele é impedido por arquitetura de alterar, confirmar ou aprovar qualquer registro.
- 🔬 **Comparação determinística.** Normalização de texto e distância de Levenshtein para achar nomes parecidos, com estados padronizados como `CONFERIDO_SEM_DIVERGENCIA` e `DIVERGENCIA`.
- 🧾 **Evidência campo a campo:** nome, CPF, companhia, localizador, datas e trecho.
- 🛡️ **Trilha de auditoria imutável** de todas as ações e decisões humanas.
- 🧱 **Chatbot ancorado nos dados**, com bloqueio de alterações e filtro contra *prompt injection*.

## 🧱 Tecnologia

Oracle Database, Oracle APEX 24.2+, ORDS (REST), pacotes PL/SQL (`PKG_*`) e uma interface web de apoio na pasta `web/`.

## 🗂️ Estrutura

```text
apex/       aplicação Oracle APEX
database/   tabelas, sequences, triggers e pacotes PL/SQL
web/        interface web de apoio
tests/      testes
docs/       arquitetura detalhada
```

## 📚 Documentação

A arquitetura completa, com tabelas, pacotes e estados, está em [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md).

---

## 🤝 Quer um sistema assim para o seu negócio?

Este projeto faz parte do portfólio da **BR Intelligence**: sistemas sob medida, agentes de IA que atendem no WhatsApp e sites feitos para vender. O foco são empresas e clínicas que querem atender melhor, perder menos clientes e ganhar tempo.

- 🌐 **Site:** https://br-intelligence.vercel.app
- 💼 **Mais projetos:** https://github.com/bbrunno18
- 📍 **Brasília/DF**, com atendimento para todo o Brasil

> Tem uma ideia, um processo manual que cansa ou um atendimento que perde cliente? Chame a gente e vamos transformar isso em sistema.

<sub>Criado por **Brunno Almeida** · BR Intelligence</sub>
