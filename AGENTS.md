---
bkf: document
description: "Define as regras de trabalho específicas do repositório Ambiente e encaminha para o mapa BKF da raiz; não guarda regras de produto nem de build, que pertencem aos documentos de docs/."
tags: [agents, repository]
---

# Regras

Mapa deste âmbito: [MAP.md](/MAP.md). Antes de uma feature, lê
[produto.md](/docs/produto.md) para saberes o que já existe e
[arquitetura.md](/docs/arquitetura.md) para saberes onde mexer.

- App pessoal: sem App Store, sem sandbox, sem preocupações de distribuição.
- Não há Xcode completo: compila-se e testa-se como diz
  [desenvolvimento.md](/docs/desenvolvimento.md).
- A confirmação estética é do utilizador: o agente não decide se algo está
  bonito.
- Depois de alterar comportamento, estrutura ou estado guardado, atualiza os
  documentos afetados na mesma alteração e corre `bkf validate .`.
- Quando o utilizador menciona uma ideia sem data, regista-a em
  [ideas.md](/ideas.md) em vez de a implementar.
- Interface em inglês, documentos em português de Portugal.
