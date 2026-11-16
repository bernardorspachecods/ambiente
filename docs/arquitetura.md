---
bkf: document
description: "Descreve como o Ambiente está construído: módulos e a fronteira entre núcleo testável e app, o estado guardado e onde, a procura dos binários externos, o modelo de descarregamento e as armadilhas do ambiente de build. Guarda o porquê e as fronteiras, não o que o código já diz; as regras de produto estão em produto.md."
tags: [arquitetura, tecnico]
---

# Ambiente — arquitetura

## Navigation map

| Se precisas de... | Ver |
| --- | --- |
| Saber onde mexer para uma nova feature | [Onde pôr uma feature](#onde-pôr-uma-feature) |
| O que é testável e o que não é | [Fronteira núcleo e app](#fronteira-núcleo-e-app) |
| O que a app guarda entre aberturas | [Estado guardado](#estado-guardado) |
| Como o `yt-dlp` e o `ffmpeg` são encontrados | [Binários externos](#binários-externos) |
| Como funciona o descarregamento | [Descarregamento](#descarregamento) |
| Decisões que parecem estranhas | [Decisões e armadilhas](#decisões-e-armadilhas) |

## Fronteira núcleo e app

Swift Package com dois alvos, mais testes:

- `Sources/AmbienteCore/` — lógica pura, sem AppKit nem processos: ler a
  biblioteca, ordem de reprodução (shuffle/repeat), argumentos e leitura da
  saída do `yt-dlp`, validação de nomes. **Tudo o que for lógica nova e
  testável vai aqui, com testes.**
- `Sources/Ambiente/` — a app: reprodução (`PlayerModel`), descarregamentos e
  atualizador (`DownloadModel`), localização dos binários, o popover SwiftUI
  (`MenuView`) e o ícone. Não tem testes automáticos: verifica-se à mão
  ([desenvolvimento](/docs/desenvolvimento.md#verificação-manual)).
- `Tests/AmbienteCoreTests/` — só testa o núcleo.

Os dois modelos da app são `@MainActor @Observable`; a vista só lê o estado e
chama métodos, não tem lógica de reprodução nem de ficheiros.

## Onde pôr uma feature

| Feature de... | Mexe em |
| --- | --- |
| Regra de ordem, fila, nomes, links, parsing | `AmbienteCore` + teste |
| Reprodução, tempo, Now Playing, teclas multimédia, renomear/apagar | `PlayerModel` |
| Descarregar, fila de downloads, atualizar `yt-dlp` | `DownloadModel` |
| Layout, botões, páginas do popover | `MenuView` (ver [ui.md](/docs/ui.md)) |
| Ícone da menu bar | `MenuIcon` e `Resources/MenuIcon/` |
| Empacotamento, binários, assinatura | `scripts/` |

Depois de uma feature, atualizar [produto.md](/docs/produto.md) (regras e
critérios) e, se mudou estrutura ou estado guardado, este documento.

## Estado guardado

- **Preferências** em `UserDefaults` (domínio da app): último ambiente,
  volume, shuffle, repeat, faixa e posição. A posição grava-se a cada ~5 s a
  tocar, ao pausar, ao saltar e ao fechar. As chaves vivem em `PlayerModel`.
- **Biblioteca**: só o sistema de ficheiros, nada em base de dados.
- **Application Support/Ambiente/**: o `yt-dlp` atualizado e a pasta de
  trabalho dos descarregamentos (esvaziada no arranque).

## Binários externos

O `yt-dlp` procura-se primeiro em Application Support (versão atualizada) e
depois no bundle; o `ffmpeg` é sempre o do bundle. Ambos vêm de
`scripts/fetch-binaries.sh` para `vendor/` (não versionado) e são copiados para o
bundle por `scripts/build-app.sh`. O `ffmpeg` tem de ser **estático**: o do
Homebrew depende de bibliotecas fora do sistema e partia fora desta máquina. O
`yt-dlp` é o binário autónomo oficial, não o script Python.

## Descarregamento

Cada link é um trabalho com a sua pasta temporária. O `yt-dlp` escreve lá, e
só no fim com sucesso o `.m4a` é movido para o ambiente. Isto existe porque uma
interrupção a meio já deixou um `.m4a` truncado e restos `.webm`/`.webp` na
biblioteca. Há no máximo 3 processos em simultâneo; os restantes esperam.
Fechar a app termina os processos, e os restos de trabalhos interrompidos são
apagados no arranque.

## Decisões e armadilhas

- **Sem sandbox e sem pasta escolhida**: evita security-scoped bookmarks, que
  complicariam a pasta fixa em `~/Music`.
- **Sem Xcode completo**: compila-se com Swift Package Manager e o `.app` é
  montado e assinado ad-hoc por script. `LSUIElement` está no `Info.plist`.
- **Testes com Swift Testing das Command Line Tools** exigem flags de
  framework e a regra de não importar `Foundation` e `Testing` no mesmo
  ficheiro (detalhe em [desenvolvimento](/docs/desenvolvimento.md#testar)).
- **Foco de teclado desligado** nos controlos (`focusable(false)`): com a
  navegação por teclado do macOS ligada, o primeiro botão abria sempre com
  contorno. Consequência aceite: o popover não se navega só com Tab.
- **Imagem do Now Playing** criada fora do ator principal: o MediaPlayer chama
  o handler noutra fila e o isolamento do Swift 6 faria a app falhar.
- **Aviso de compilação conhecido** sobre isso mesmo em `PlayerModel`; é o
  ponto sensível a regressões ao mexer no Now Playing.
