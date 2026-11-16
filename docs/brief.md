---
bkf: document
description: "Product brief of Ambiente, a personal macOS menu bar app that plays local background music by folder (\"ambiente\") and downloads audio from YouTube links with yt-dlp. Owns the concept, behavior, stack, v1 scope and acceptance criteria; it does not describe the code layout or how to build."
tags: [product, brief]
---

# Ambiente — app de música de fundo para macOS

## Porquê
Ao ouvir música de fundo no YouTube acabo sempre distraído por outros vídeos e a procurar os mesmos vídeos de sempre. Quero uma app só para ouvir música de ambiente, sem distrações, com um ícone dedicado na menu bar para controlar tudo de forma rápida.

## Conceito
App só de menu bar (sem janela principal, sem ícone no Dock). Cada subpasta de uma pasta raiz é um "ambiente" (clássico, lowfi, instrumental, sad, etc.). Escolho o ambiente, carrego em play e a música toca.

As músicas ficam guardadas localmente no Mac (nada de wrapper do YouTube).

## Estrutura de pastas
```
~/Music/Ambiente/
  Clássico/
  Lowfi/
  Instrumental/
  Sad/
```
- Para adicionar um ambiente basta criar uma pasta nova. Sem configuração nem base de dados.
- A app lê as pastas ao abrir e sempre que o menu é aberto.

## UI (o mais nativa possível)
- `MenuBarExtra` com estilo `.window`: popover nativo com o material translúcido do sistema.
- Ícone na menu bar com um SF Symbol (`music.note` ou `waveform`) que muda com o estado (a tocar / pausado).
- Popover com:
  - Nome da faixa atual e o ambiente ativo.
  - Controlos: anterior, play/pause, seguinte (SF Symbols).
  - Slider de volume.
  - Lista dos ambientes, com o ativo marcado.
- Apenas controlos e estilos padrão do SwiftUI: sem cores nem fontes customizadas. Dark mode automático.

## Comportamento
- Ao escolher um ambiente, toca as faixas dessa pasta em shuffle e em loop infinito.
- Retoma o último ambiente e volume ao abrir (`@AppStorage`).
- Integração com as teclas multimédia e Now Playing do macOS via `MPRemoteCommandCenter`.
- Opcional: atalho global para seguinte/pausa e "abrir no arranque" (`SMAppService`).

## Stack
- Swift + SwiftUI, macOS 14 ou superior.
- `AVFoundation` (`AVPlayer`) para reprodução e `AVAsset` para ler título/artista.
- `LSUIElement = true` para não aparecer no Dock.
- Sem sandbox, ou pasta fixa, para evitar a complexidade dos security-scoped bookmarks.

## Adicionar música por link (YouTube)
Para juntar música nova sem sair da app: colar um link, escolher o ambiente (pasta) e a faixa fica descarregada para essa pasta.

**Fluxo**
1. No popover, campo "Colar link" + seletor de ambiente.
2. A app corre o `yt-dlp` como processo externo com extração de áudio, por exemplo:
   `yt-dlp -x --audio-format m4a --audio-quality 0 --embed-thumbnail --embed-metadata -o "<pasta do ambiente>/%(title)s.%(ext)s" <URL>`
3. Quando acaba, a pasta é relida e a faixa aparece no ambiente.

**Decisões**
- Formato **m4a** (ou opus) em vez de mp3: o YouTube não serve mp3, converter obriga a recodificar áudio já comprimido e perde qualidade.
- O `yt-dlp` precisa do **ffmpeg** para extrair áudio. Incluir ambos os binários dentro do bundle da app (a falta de ffmpeg é a causa mais comum de falhas).
- O YouTube muda com frequência e o yt-dlp quebra de vez em quando. Incluir um **atualizador do yt-dlp** que grava o novo binário em `~/Library/Application Support/<App>/` (sem mexer na app assinada).
- Mostrar progresso simples (barra ou texto) e erros legíveis no popover.
- Só vídeos individuais no v1 (sem playlists, para não precisar de fila nem tratamento de falhas parciais).
- Nota legal: descarregar do YouTube vai contra os termos de uso do serviço. Uso pessoal por decisão do utilizador.

**Repos de referência (Swift + yt-dlp)**
- https://github.com/denbeke/youtube-downloader-for-macos (app de menu bar, a mais parecida)
- https://github.com/zabrodsk/pulltube (SwiftUI, yt-dlp + ffmpeg dentro do bundle)
- https://github.com/downIoads/swiftui-ytdl (GUI para yt-dlp + ffmpeg)
- https://github.com/yt-dlp/yt-dlp (ferramenta oficial)

## Fora do v1
Pesquisa, playlists manuais, download de playlists do YouTube, letras e crossfade (o crossfade é o primeiro a acrescentar se o v1 ficar bom).

## Critérios de aceitação
- [ ] A app aparece só na menu bar, sem ícone no Dock.
- [ ] Deteta automaticamente as subpastas de `~/Music/Ambiente/` como ambientes.
- [ ] Escolher um ambiente toca as suas faixas em shuffle e loop.
- [ ] Play/pause, anterior, seguinte e volume funcionam no popover.
- [ ] As teclas multimédia do Mac controlam a reprodução.
- [ ] Ao reabrir, retoma o último ambiente e volume.
- [ ] A UI usa apenas componentes e estilos nativos do sistema.
- [ ] Colar um link do YouTube e escolher um ambiente descarrega o áudio (m4a) para a pasta certa.
- [ ] A faixa descarregada aparece no ambiente sem reiniciar a app.
- [ ] O yt-dlp e o ffmpeg vão dentro da app, e o yt-dlp pode ser atualizado sem reinstalar.
