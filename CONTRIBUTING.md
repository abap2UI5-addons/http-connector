# Contributing

Call abap2UI5 apps of another system via HTTP.

## Before you open a pull request

Run what CI runs:

```sh
npm ci
npm run check
npm run unit
```

`npm run check` runs lint, the abap2UI5-linter and the rename - the steps of
`abap-standard`, `check-abap2ui5` and `check-rename`. `npm test` is an alias
for it. `npm run unit` is the `abap-unit` workflow: it clones abap2UI5 into
`.unit/`, transpiles and runs the ABAP Unit tests, so it is slower and kept
out of `check`.

## What the gates are

| Gate | What it proves |
| --- | --- |
| `npm run lint` | abaplint: syntax, resolved against the abap2UI5 core |
| `npm run check:abap2ui5` | [abap2UI5-linter](https://github.com/abap2UI5/linter), source-side rules only (there is no view here): abapGit round trip, activation, and that the connector names no unreleased core object beyond the one it uses on purpose |
| `npm run rename` | the namespace rename still applies cleanly (`.github/scripts/rename.mjs`) |
| `npm run unit` | the ABAP Unit tests pass on abap2UI5's transpiled Node runtime (`.github/scripts/unit.mjs`) |

The abap2UI5-linter keeps a baseline in `abap2ui5lint-baseline.json`. Findings
recorded there are counted and never listed; a **new** finding fails the gate,
and an entry whose finding is gone is stale and fails too. So the file only ever
shrinks — fix something, then refresh it with:

```sh
npx abap2ui5lint --update-baseline
```

No gate can call a destination. Say in the pull request whether the change
was tried between two systems.

## Conventions

English for code, comments, commit messages and pull requests. Commit subjects
are written in the imperative and describe the outcome, not the mechanics. One
topic per pull request. The wider rules the whole ecosystem follows live in
[abap2UI5's CONVENTIONS.md](https://github.com/abap2UI5/abap2UI5/blob/main/.github/shared/CONVENTIONS.md).
