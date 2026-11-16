---
bkf_version: "0.1"
description: Encaminha o repositório do Ambiente, uma app pessoal de macOS para a menu bar que toca música local por pastas e descarrega áudio de links; o código confirma o comportamento e cada documento de docs/ guarda o seu tema.
---

# Ambiente

App de menu bar para macOS que toca música local organizada em pastas
("ambientes") e descarrega áudio de links do YouTube. Código em `Sources/`,
scripts de build em `scripts/`, ícone em `Resources/MenuIcon/`.

## Task routes

| Task | Start here |
| --- | --- |
| Saber o que a app faz hoje e o que ficou de fora | [produto.md](/docs/produto.md) |
| Acrescentar uma feature ou perceber onde mexer no código | [arquitetura.md](/docs/arquitetura.md#onde-pôr-uma-feature) |
| Mexer no popover, nos menus ou no ícone | [ui.md](/docs/ui.md) |
| Compilar, instalar, testar ou verificar uma alteração | [desenvolvimento.md](/docs/desenvolvimento.md) |
| Registar uma ideia para mais tarde | [ideas.md](/ideas.md) |

## Member inventory

<!-- BKF:GENERATED-MEMBER-INVENTORY:START -->
| What it is | Document |
| --- | --- |
| Define as regras de trabalho específicas do repositório Ambiente e encaminha para o mapa BKF da raiz; não guarda regras de produto nem de build, que pertencem aos documentos de docs/. | [AGENTS.md](/AGENTS.md) |
| Descreve como o Ambiente está construído: módulos e a fronteira entre núcleo testável e app, o estado guardado e onde, a procura dos binários externos, o modelo de descarregamento e as armadilhas do ambiente de build. Guarda o porquê e as fronteiras, não o que o código já diz; as regras de produto estão em produto.md. | [arquitetura.md](/docs/arquitetura.md) |
| Como compilar, testar, correr e instalar o Ambiente sem Xcode completo, como obter os binários e o que verificar à mão depois de uma alteração. Não define comportamento de produto nem a estrutura do código. | [desenvolvimento.md](/docs/desenvolvimento.md) |
| Define o que o Ambiente é e faz: conceito, comportamento de reprodução, biblioteca em pastas, descarregamento por link, regras de nome/apagar, o que ficou fora e o estado dos critérios de aceitação. Não descreve a estrutura do código nem o desenho da interface; arquitetura.md e ui.md têm esses temas. | [produto.md](/docs/produto.md) |
| Define a estrutura e as regras da interface do Ambiente (popover da menu bar, páginas, padrões de renomear/apagar/menus de contexto, idioma, ícone). Não descreve cada componente, que o código mostra; o comportamento de produto está em produto.md. | [ui.md](/docs/ui.md) |
| Recolhe ideias sem data para o Ambiente, como possibilidades futuras e não como instruções; o que já existe está em docs/produto.md. | [ideas.md](/ideas.md) |
<!-- BKF:GENERATED-MEMBER-INVENTORY:END -->
