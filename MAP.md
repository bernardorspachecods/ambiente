---
bkf_version: "0.1"
description: Routes the Ambiente repository, a personal macOS menu bar app that plays local music by folder and downloads audio from links; the code confirms behavior and each document in docs/ keeps its topic.
---

# Ambiente

A macOS menu bar app that plays local music organized in folders ("ambientes")
and downloads audio from YouTube links. Code in `Sources/`, build scripts in
`scripts/`, icons in `Resources/`.

## Task routes

| Task | Start here |
| --- | --- |
| Know what the app does today and what was left out | [product.md](/docs/product.md) |
| Add a feature or find where to change the code | [architecture.md](/docs/architecture.md#where-to-put-a-feature) |
| Change the popover, the menus or the icons | [ui.md](/docs/ui.md) |
| Build, install, test or verify a change | [development.md](/docs/development.md) |
| Record an idea for later | [ideas.md](/ideas.md) |

## Member inventory

<!-- BKF:GENERATED-MEMBER-INVENTORY:START -->
| What it is | Document |
| --- | --- |
| Defines the working rules specific to the Ambiente repository and points to the root BKF map; holds no product or build rules, which belong to the documents in docs/. | [AGENTS.md](/AGENTS.md) |
| Describes how Ambiente is built: modules and the boundary between the testable core and the app, the saved state and where it lives, how the external binaries are found, the download model and the build-environment pitfalls. Keeps the why and the boundaries, not what the code already says; product rules are in product.md. | [architecture.md](/docs/architecture.md) |
| How to build, test, run and install Ambiente without full Xcode, how to get the binaries and what to check by hand after a change. Does not define product behavior or the code structure. | [development.md](/docs/development.md) |
| Defines what Ambiente is and does: concept, playback behavior, the folder-based library, downloading from links, rename/delete rules, what is out of scope and the state of the acceptance criteria. Does not describe the code structure or the interface layout; architecture.md and ui.md own those. | [product.md](/docs/product.md) |
| Defines the structure and rules of Ambiente's interface (the menu bar popover, its pages, the rename/delete/context-menu patterns, language, icons). Does not describe each component, which the code shows; product behavior is in product.md. | [ui.md](/docs/ui.md) |
| Collects undated ideas for Ambiente as future possibilities, not instructions; what already exists is in docs/product.md. | [ideas.md](/ideas.md) |
<!-- BKF:GENERATED-MEMBER-INVENTORY:END -->
