# AGENTS.md

Single source of truth for agents working on **http-connector**.

Calls abap2UI5 apps of another system via HTTP: the browser talks to a consumer
system, which forwards every request through an SM59 destination to the source
system where the apps run.

## What this repository is

A **source** repository in the abap2UI5 ecosystem: humans and agents edit here,
and CI gates every change. It is installed with abapGit on both systems,
consumer and source, and depends on the
[abap2UI5](https://github.com/abap2UI5/abap2UI5) core at runtime.

The default branch is **`standard`**, not `main`. The `cloud` branch is an
unmaintained prototype from 2025-11: it has no CI; like `standard` it goes
through the core's `z2ui5_cl_ui5_util_http` (`factory_cloud`), nothing from
the core's frozen `src/99`.

## Layout

| Path | Contents |
| --- | --- |
| `src/01` | Consumer side: the ICF handler `z2ui5_cl_http_con_handler` and its SICF node `/sap/bc/z2ui5_http` |
| `src/02` | Source side: the ICF handler `z2ui5_cl_http_con_server` and its SICF node `/sap/bc/z2ui5_http_srv` — an ordinary abap2UI5 endpoint |

## What this depends on in the core

There is no version pin on the core — abaplint resolves it from its `main`
branch. That is why both workflows also run on a weekly schedule: a rename
upstream breaks this repository silently, and with no pull request open nothing
else would notice.

The connector calls:

| Member | Where in the core | Status |
| --- | --- | --- |
| `z2ui5_cl_ui5_http_handler=>run` | `src/02` | released; the source side is nothing more than this call |
| `z2ui5_cl_ui5_http_handler=>_check_csrf_rejected` | `src/02` | released |
| `z2ui5_cl_ui5_util_http=>factory`, `->get_req_info`, `=>client_call` | `src/00/03` | not released — used **on purpose**, see below. The `query` of both is newer than 1.146.0 |

The consumer needs an abap2UI5 release newer than 1.146.0 (the query of
`z2ui5_cl_ui5_util_http`), the source 1.143.0 or newer (the first release with
`z2ui5_cl_ui5_http_handler`).

### z2ui5_cl_ui5_util_http stays

Going through the core's own HTTP utility instead of `if_http_server` /
`cl_http_client` directly is a deliberate maintainer decision: the connector
handles the request exactly the way the framework does. Do not rewrite it to
the kernel APIs to satisfy the linter. When the connector needs something
the utility does not offer, extend `z2ui5_cl_ui5_util_http` in the core
(abap2UI5, `src/00/03`) and use that here — never work around it with direct
kernel calls in this repository. The finding is accepted in
`abap2ui5lint-baseline.json`; the price is that a rename of that class in the
core breaks this repository, which the weekly scheduled run exists to notice.
The core comments `client_call` as having no caller — this repository is the
caller, so a core change that drops it has to be answered here.

## Build and verify

```sh
npm ci
npm run check
```

`npm run check` runs exactly what CI runs: abaplint (`abap-standard.yaml`) and
the abap2UI5-linter (`check-abap2ui5.yaml`). This repository builds no view, so
the linter runs with `allClasses` and without the render gate; what it adds is
the released-API check.

Nothing offline can prove the outbound HTTP call, the SICF nodes or the round
trip through a real destination. State in the pull request what was and was
not verified in a system.

## Conventions

- ABAP object names start with `z2ui5_`; the connector's own objects carry
  `http_con`.
- Syntax level v750 with the `downport` rule, the same floor as the core.
- English for code, comments, commit messages, pull requests and issues.
- All text files are LF-only (`.gitattributes`).
- The ecosystem-wide rules — workflow and npm-script naming, toolchain versions,
  which documentation files exist, commit style — live in
  [CONVENTIONS.md](https://github.com/abap2UI5/abap2UI5/blob/main/.github/shared/CONVENTIONS.md)
  and bind this repository too.

## Namespace rename

`npm run rename` (CI: `check-rename`) and the manual `build-rename` workflow
are abap2UI5's namespace rename for this addon - `.github/scripts/rename.mjs`,
the same file in every addon that has one. Every `z2ui5_` object becomes
`<name>_...`, for a customer name such as `ZMYUI5` or a registered namespace
such as `/CA2UI5/` (at most 6 characters), and so does every reference to
abap2UI5 and to the addons this one builds on: the branch `rename_<name>` runs
on an abap2UI5 renamed with the same name by its own `build-rename`. What
follows from it:

- Every object name has at most 25 characters (a transparent table
  11, an ICF node 10) - 30 minus what the longest new name adds.
- No literal names a `z2ui5_` object: the rename rewrites references, never a
  literal. Derive the name - from a typed reference, or behind the prefix of
  the class's own name.
- A change that spans several repositories: `RENAME_DEPS_FROM=<dir> npm run
  rename` takes the dependencies from the clones in `<dir>`.
- The source side's ICF node `z2ui5_http_srv` has 14 characters, and an ICF
  node at most 15 - so this addon allows names of at most 6 characters
  (`config.renameMaxLength` in `package.json`): `ZMYUI5` fits, `/CA2UI5/`
  does not. Shortening the node would move the URL every consumer system has
  configured.

## Unit tests

CI `abap-unit` runs the ABAP Unit tests on abap2UI5's transpiled Node runtime, the way abap2UI5 tests itself: `npm run unit` (`.github/scripts/unit.mjs`) copies the packages into a checkout of abap2UI5's `main`, downports, transpiles and runs the tests of this repository's classes
