---
bkf: document
description: "Define a estrutura e as regras da interface do Ambiente (popover da menu bar, páginas, padrões de renomear/apagar/menus de contexto, idioma, ícone). Não descreve cada componente, que o código mostra; o comportamento de produto está em produto.md."
tags: [ui, produto]
---

# Ambiente — interface

## Regras

- **Só componentes e estilos nativos do SwiftUI**, sem cores nem fontes
  próprias; modo escuro automático. A confirmação estética é do utilizador.
- **Interface toda em inglês**, incluindo mensagens de erro vindas do núcleo.
  Os documentos estão em português.
- Janela do tipo `MenuBarExtra(.window)` com 300 pt de largura; sem janela
  principal nem Dock.
- Nenhum controlo aceita foco de teclado, salvo os campos de texto (razão em
  [arquitetura](/docs/arquitetura.md#decisões-e-armadilhas)). Um controlo novo
  tem de ser marcado `focusable(false)`.
- Ao abrir o menu: volta à página principal, "Add by link" recolhido (salvo se
  houver descarregamentos em curso), o ambiente ativo aberto, e os
  descarregamentos concluídos desaparecem; os falhados ficam até serem
  dispensados.

## Estrutura

**Página principal**, de cima para baixo: imagem, título, artista e ambiente
da faixa; linha de tempo; shuffle, anterior, play/pause, seguinte, repeat;
volume; lista de ambientes (cada um expansível para as faixas); "Add by link";
aviso de atualização do `yt-dlp` (só quando há versão nova); engrenagem e Quit.

**Definições**, página dentro do popover, por funções: General (abrir no
arranque), Library (caminho e abrir no Finder), Downloads (versão e atualização
do `yt-dlp`). Novas opções entram na secção da sua função.

## Padrões

- **Linha de ambiente:** o nome abre/fecha a lista; um botão play toca o
  ambiente; um botão de pasta abre-o no Finder. O mesmo chevron e espaçamento
  valem para qualquer grupo expansível.
- **Faixa:** clicar toca; o altifalante azul marca a faixa atual.
- **Menu de contexto** (botão direito) em faixas e ambientes: Rename…,
  Show in Finder, Move to Trash…. Ações novas sobre itens da biblioteca vão
  para este menu, não para botões permanentes.
- **Renomear** é inline na linha (Return grava, Esc cancela); erros aparecem
  acima da lista. **Apagar** pede confirmação inline antes de mover para o Lixo.

## Ícone da menu bar

Um blobatar azul ([blobatar.dev](https://blobatar.dev), MIT) para o nome
"Simpilco": cara `happy` a tocar e `sleepy` esbatida em pausa. O blob não tem
boca em nenhuma expressão. Os SVG em `Resources/MenuIcon/` são a fonte; os PNG
são renders de 72 px com a área cortada ao blob. Sem os PNG no bundle, a app
volta aos símbolos do sistema.

O ícone da app (`Resources/AppIcon.icns`, visível no Finder e nas definições de
arranque; a app não tem ícone no Dock) é o mesmo blob sobre um quadrado
arredondado claro, gerado por `scripts/make-icon.sh`.
