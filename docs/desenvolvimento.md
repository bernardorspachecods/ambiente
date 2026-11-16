---
bkf: document
description: "Como compilar, testar, correr e instalar o Ambiente sem Xcode completo, como obter os binários e o que verificar à mão depois de uma alteração. Não define comportamento de produto nem a estrutura do código."
tags: [desenvolvimento, build]
---

# Ambiente — desenvolvimento

Sem Xcode completo: tudo com as Command Line Tools e Swift Package Manager.

## Navigation map

| Se precisas de... | Ver |
| --- | --- |
| Compilar e instalar a app | [Compilar](#compilar) |
| Correr os testes | [Testar](#testar) |
| Confirmar uma alteração na app | [Verificação manual](#verificação-manual) |

## Compilar

```sh
scripts/fetch-binaries.sh        # uma vez: yt-dlp e ffmpeg estático para vendor/
scripts/build-app.sh             # build/Ambiente.app, assinada ad-hoc
scripts/build-app.sh --install   # e copia para ~/Applications
open build/Ambiente.app
```

`vendor/` e `build/` não são versionados. O ícone da app (`Resources/AppIcon.icns`) gera-se a partir do blob com `scripts/make-icon.sh`. "Open at login" só é fiável com a app
instalada (`--install`): registada a partir de `build/`, o caminho pode deixar de
existir. Para ver uma alteração é preciso
fechar a app (Quit) e voltar a abrir: o build não a reinicia.

## Testar

As Command Line Tools trazem o Swift Testing sem o overlay de Foundation, por
isso passam-se as flags de framework, e um ficheiro de teste **não pode importar
`Foundation` e `Testing` ao mesmo tempo** (o código com Foundation fica em
`Fixtures.swift`):

```sh
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
swift test -Xswiftc -F -Xswiftc $F -Xlinker -F -Xlinker $F -Xlinker -rpath -Xlinker $F
```

Só o núcleo tem testes automáticos; o que fica de fora é o que exige a app a
correr (ver [arquitetura](/docs/arquitetura.md#fronteira-núcleo-e-app)). Um
defeito corrigido ganha primeiro um teste que o reproduz. Em `#expect`, não chamar métodos `mutating` diretamente:
guardar o resultado numa variável antes.

## Verificação manual

A app não tem testes automáticos, por isso depois de uma alteração, conforme o
que tocou:

- Reprodução: escolher ambiente, tocar uma faixa específica, saltar na linha de
  tempo, shuffle/repeat, teclas multimédia.
- Retoma: tocar, fechar, reabrir (tem de voltar à faixa e posição, em pausa).
- Descarregar: um link; vários de uma vez; cancelar; novo ambiente; fechar a
  app a meio (não pode ficar nada na pasta do ambiente).
- Renomear/apagar a faixa a tocar e o ambiente a tocar.
- Abrir o menu: sem contorno de foco em nenhum botão.
- `bkf validate .` e `bkf inventory . --check` se mexeste em documentos.

Para um descarregamento de teste sem a app, usar os binários do bundle com os
mesmos argumentos que o núcleo gera.
