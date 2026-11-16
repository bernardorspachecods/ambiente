---
bkf: document
description: "Define o que o Ambiente é e faz: conceito, comportamento de reprodução, biblioteca em pastas, descarregamento por link, regras de nome/apagar, o que ficou fora e o estado dos critérios de aceitação. Não descreve a estrutura do código nem o desenho da interface; arquitetura.md e ui.md têm esses temas."
tags: [produto, requisitos]
---

# Ambiente — produto

App pessoal de macOS, só na menu bar, para ouvir música de fundo sem as
distrações do YouTube. Uso pessoal: sem App Store, sem sandbox, sem
distribuição.

## Navigation map

| Se precisas de... | Ver |
| --- | --- |
| Perceber o conceito e porquê | [Conceito](#conceito) |
| Como a biblioteca é lida | [Biblioteca](#biblioteca) |
| Regras de reprodução, shuffle, repeat e retoma | [Reprodução](#reprodução) |
| Descarregar música de links | [Descarregar por link](#descarregar-por-link) |
| Renomear e apagar | [Gerir a biblioteca](#gerir-a-biblioteca) |
| O que não está feito | [Fora do âmbito](#fora-do-âmbito) |
| Saber se algo já está feito | [Critérios de aceitação](#critérios-de-aceitação) |

## Conceito

Ouvir música de fundo no YouTube leva a distrações e à procura dos mesmos
vídeos. O Ambiente toca só ficheiros locais, escolhidos por "ambiente"
(clássico, lowfi, instrumental...), com um ícone dedicado na menu bar. Não há
wrapper do YouTube: o YouTube só serve de fonte para descarregar áudio.

## Biblioteca

- A raiz é `~/Music/Ambiente/`, criada no arranque se faltar. Cada subpasta
  visível é um ambiente; cada ficheiro de áudio dentro dela é uma faixa. Não
  há configuração nem base de dados: as pastas são a verdade.
- Subpastas dentro de um ambiente não contam (um nível só).
- Formatos reconhecidos: m4a, mp3, aac, wav, aiff, flac, caf. Opus não toca em
  AVPlayer e por isso os downloads são sempre m4a.
- A lista é relida ao abrir o menu e depois de qualquer alteração feita pela app.
- O **título mostrado é o nome do ficheiro**, não o título dos metadados, para
  que renomear se veja. O artista e a imagem vêm dos metadados embutidos; sem
  imagem aparece um marcador.

## Reprodução

- Escolher um ambiente (botão play da linha) toca as suas faixas; clicar numa
  faixa toca essa faixa e as restantes seguem as regras abaixo.
- **Shuffle** (por defeito ligado): cada ronda toca todas as faixas uma vez, e
  uma nova ronda nunca começa pela faixa que acabou de tocar. Desligado, toca
  por ordem de nome. Ligar ou desligar não interrompe a faixa atual.
- **Repeat** (por defeito `all`): `off` pára no fim da ronda e volta à primeira
  faixa em pausa; `all` faz loop infinito; `one` repete a faixa. Seguinte e
  anterior manuais ignoram o repeat. Anterior passados 3 segundos recomeça a
  faixa.
- Teclas multimédia e Now Playing do macOS controlam a reprodução.
- **Retoma:** ao abrir, a app volta ao último ambiente, volume, faixa e
  posição, **em pausa** (não toca sozinha). Se a faixa guardada já não existir,
  fica só o ambiente.
- Adicionar ficheiros à pasta do ambiente ativo não interrompe a faixa atual;
  as novas faixas entram na ronda.

## Descarregar por link

- Cola-se um ou vários links (separados por linha, espaço ou vírgula), escolhe-se
  o ambiente — ou cria-se um novo ao escrever o nome — e a app descarrega o
  áudio em m4a (qualidade máxima, miniatura e metadados embutidos).
- Só vídeos individuais: links de playlist descarregam apenas o vídeo.
- Descarregam até 3 em paralelo; os restantes esperam. Cada link tem o seu
  progresso, estado, e pode ser cancelado.
- Uma faixa só entra no ambiente quando o descarregamento termina com sucesso;
  uma interrupção nunca deixa ficheiros parciais na biblioteca. Se já existir
  uma faixa com o nome, a nova fica com " (2)".
- O `yt-dlp` e o `ffmpeg` vão dentro da app. O `yt-dlp` pode ser atualizado
  sem reinstalar: a app avisa **só** quando há versão nova, e a atualização
  só substitui a versão em uso se a nova arrancar.
- Nota legal: descarregar do YouTube vai contra os termos do serviço. Uso
  pessoal por decisão do utilizador.

## Gerir a biblioteca

- **Renomear** faixas e ambientes na própria lista (menu de contexto). Nas
  faixas a extensão mantém-se; nomes que colidem com um existente são
  recusados. Renomear o que está a tocar não interrompe a reprodução.
- **Apagar** move para o Lixo (recuperável), com confirmação. Apagar o
  ambiente leva todas as faixas. Apagar a faixa a tocar passa a outra; apagar o
  ambiente a tocar pára a reprodução.

## Fora do âmbito

Pesquisa, playlists manuais, descarregar playlists do YouTube, letras,
crossfade, atalho global, navegação só por teclado, autoplay ao abrir. Ideias
sem data estão em [ideas.md](/ideas.md).

## Critérios de aceitação

Feitos e verificados na app, exceto onde indicado.

- [x] Só aparece na menu bar, sem ícone no Dock.
- [x] Deteta as subpastas de `~/Music/Ambiente/` como ambientes.
- [x] Escolher um ambiente toca em shuffle e loop (configuráveis).
- [x] Play/pause, anterior, seguinte, volume e linha de tempo no popover.
- [ ] Teclas multimédia controlam a reprodução — implementado, nunca confirmado à mão.
- [x] Ao reabrir retoma ambiente, volume, faixa e posição.
- [x] A interface usa componentes nativos do sistema.
- [x] Colar links descarrega m4a para a pasta certa; a faixa aparece sem reiniciar.
- [x] `yt-dlp` e `ffmpeg` vão dentro da app; o `yt-dlp` atualiza-se sem reinstalar.
- [ ] Descarregamentos em paralelo, cancelamento e atualização do `yt-dlp` pela interface — implementados, só testados na linha de comandos e pelo build.
