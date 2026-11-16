---
bkf: document
description: "Defines the working rules specific to the Ambiente repository and points to the root BKF map; holds no product or build rules, which belong to the documents in docs/."
tags: [agents, repository]
---

# Rules

Map of this scope: [MAP.md](/MAP.md). Before a feature, read
[product.md](/docs/product.md) to know what already exists and
[architecture.md](/docs/architecture.md) to know where to change things.

- Personal app: no App Store, no sandbox, no distribution concerns.
- There is no full Xcode: build and test as [development.md](/docs/development.md) says.
- Aesthetic confirmation belongs to the user: the agent does not decide whether
  something looks good.
- **Everything that can be tested with code is tested with code**, so that a new
  feature that breaks old code is caught right away. Only visual taste and what
  needs the app running (real audio, media keys, appearance) is left to manual
  verification. New logic goes where it is testable (see
  [architecture](/docs/architecture.md#core-vs-app-boundary)) and comes with
  tests; a fixed defect first gets a test that reproduces it.
- After changing behavior, structure or saved state, update the affected
  documents in the same change and run `bkf validate .`.
- When the user mentions an undated idea, record it in [ideas.md](/ideas.md)
  instead of implementing it.
- The interface and the documents are in English.
