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
- **Tudo o que se pode testar com código testa-se com código**, para que uma
  feature nova que parta código antigo seja detetada logo. Só o gosto visual e
  o que exige a app a correr (áudio real, teclas multimédia, aparência) fica à
  verificação manual. Lógica nova vai para onde seja testável (ver
  [arquitetura](/docs/arquitetura.md#fronteira-núcleo-e-app)) e entra com
  testes; um defeito corrigido ganha primeiro um teste que o reproduz.
- Depois de alterar comportamento, estrutura ou estado guardado, atualiza os
  documentos afetados na mesma alteração e corre `bkf validate .`.
- Quando o utilizador menciona uma ideia sem data, regista-a em
  [ideas.md](/ideas.md) em vez de a implementar.
- Interface em inglês, documentos em português de Portugal.
