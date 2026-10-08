# http-connector

[![abap2UI5-addons](https://img.shields.io/badge/abap2UI5--addons-connector-1873b4)](https://github.com/abap2UI5-addons)
[![ABAP](https://img.shields.io/badge/ABAP-Standard%20%E2%89%A5%207.50-blue)](#installation)
[![abap2UI5](https://img.shields.io/badge/requires-abap2UI5-blue)](https://github.com/abap2UI5/abap2UI5)
[![License](https://img.shields.io/github/license/abap2UI5-addons/http-connector)](LICENSE)
<br>
[![ABAP Standard](https://img.shields.io/github/actions/workflow/status/abap2UI5-addons/http-connector/abap-standard.yaml?branch=standard&label=ABAP%20Standard)](https://github.com/abap2UI5-addons/http-connector/actions/workflows/abap-standard.yaml)
[![check-abap2UI5](https://img.shields.io/github/actions/workflow/status/abap2UI5-addons/http-connector/check-abap2ui5.yaml?branch=standard&label=check-abap2UI5)](https://github.com/abap2UI5-addons/http-connector/actions/workflows/check-abap2ui5.yaml)

**Remotely call abap2UI5 apps via HTTP.** The browser talks to a consumer
system, which forwards every request through an SM59 destination to the
source system where the abap2UI5 apps run. For landscapes where users should
reach the apps of another system through one entry point.

> Part of [abap2UI5-addons](https://github.com/abap2UI5-addons) - addons and apps for [abap2UI5](https://github.com/abap2UI5/abap2UI5), installed with [abapGit](https://abapgit.org).

```
Browser ── GET/POST ──> Consumer System                    Source System
                        /sap/bc/z2ui5_http                 /sap/bc/z2ui5_http_srv
                        Z2UI5_CL_HTTP_CON_HANDLER          Z2UI5_CL_HTTP_CON_SERVER
                          │                                  │
                          └── HTTP (SM59 destination) ──────>└──> z2ui5_cl_ui5_http_handler
```

## Why

The abap2UI5 apps live on one system, but the browser should call another one.
The http-connector puts a thin ICF handler on the consumer system that passes
each roundtrip on to the source system - the apps themselves stay where they
are and run unchanged.

Same approach as the [rfc-connector](https://github.com/abap2UI5-addons/rfc-connector),
just with an HTTP connection instead of RFC.

## Installation

The connector is installed on **two systems**: the **consumer system** the
browser talks to and the **source system** the apps run on.

**Requirements**

- Standard ABAP 7.50 or higher on both systems
- [abap2UI5](https://github.com/abap2UI5/abap2UI5) on both systems:
  - **consumer system:** a release **newer than 1.146.0** - the connector
    forwards the query string through `z2ui5_cl_ui5_util_http`, which learned
    it after that release
  - **source system:** **1.143.0 or newer** - the first release with
    `z2ui5_cl_ui5_http_handler`
- On the consumer system: a destination in SM59 (type G or H) pointing to the
  source system with path prefix `/sap/bc/z2ui5_http_srv/` and login data
  maintained

**Steps** - with [abapGit](https://abapgit.org):

| System | Branch to pull |
|---|---|
| Standard ABAP (consumer and source) | `standard` |
| ABAP Cloud | `cloud` - an unmaintained prototype from 2025-11 (consumer side only, no CI) |

1. Install [abap2UI5](https://github.com/abap2UI5/abap2UI5) on both systems.
2. Install this repository (branch `standard`) on **both** systems.
3. On the **consumer system**, replace in the HTTP handler
   `Z2UI5_CL_HTTP_CON_HANDLER` the destination `NONE` with your source system
   destination (or maintain the URL constant instead).
4. Activate the ICF nodes in transaction SICF:
   - `/sap/bc/z2ui5_http` on the **consumer system**
   - `/sap/bc/z2ui5_http_srv` on the **source system**

**Start** - call the endpoint `.../sap/bc/z2ui5_http` of the **consumer
system** in your browser.

## Usage

### Approach

The consumer system receives the browser request, forwards method, body and
query string via HTTP to the source system and returns body and HTTP status of
the response. All abap2UI5 apps run on the source system.

| System | ICF node | Handler |
|---|---|---|
| Consumer | `/sap/bc/z2ui5_http` | `Z2UI5_CL_HTTP_CON_HANDLER` |
| Source | `/sap/bc/z2ui5_http_srv` | `Z2UI5_CL_HTTP_CON_SERVER` - an ordinary abap2UI5 endpoint calling `z2ui5_cl_ui5_http_handler` |

### Limitations

* **Stateless apps only.** A stateful app (`client->set_session_stateful( )`) needs the ICF session of the system the app runs on; the consumer opens a new HTTP connection per request and does not forward the `sap-contextid` header the frontend uses to address that session. Apps keeping their state in the draft table — the abap2UI5 default — work unchanged.
* **The consumer forwards method, body, query string and status — not headers, and not its path.** Everything abap2UI5 needs for a roundtrip travels in the body and the query; a request header an app reads through the user exit on the source system does not, and the exit sees the path of the source node `/sap/bc/z2ui5_http_srv`.

## Development

```sh
npm ci
npm run check
```

`npm run check` runs exactly what CI runs: abaplint (`abap-standard.yaml`) and
the abap2UI5-linter (`check-abap2ui5.yaml`).

## Contributing

Issues and pull requests are welcome - see [CONTRIBUTING.md](CONTRIBUTING.md) for what CI checks. Whether you're fixing bugs, adding new functionality, or improving documentation, your contributions are highly appreciated.

## License

MIT - see [LICENSE](LICENSE).
