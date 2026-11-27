# http-connector

[![abap2UI5-addons](https://img.shields.io/badge/abap2UI5--addons-connector-1873b4)](https://github.com/abap2UI5-addons)
[![ABAP](https://img.shields.io/badge/ABAP-Standard%20%E2%89%A5%207.50-blue)](#installation)
[![abap2UI5](https://img.shields.io/badge/requires-abap2UI5-blue)](https://github.com/abap2UI5/abap2UI5)
[![License](https://img.shields.io/github/license/abap2UI5-addons/http-connector)](LICENSE)
<br>
[![CI](https://img.shields.io/github/actions/workflow/status/abap2UI5-addons/http-connector/ci.yaml?branch=standard&label=CI)](https://github.com/abap2UI5-addons/http-connector/actions/workflows/ci.yaml)
[![ABAP 7.02](https://img.shields.io/github/actions/workflow/status/abap2UI5-addons/http-connector/ci-702.yaml?branch=standard&label=ABAP%207.02)](https://github.com/abap2UI5-addons/http-connector/actions/workflows/ci-702.yaml)

**Remotely call abap2UI5 apps via HTTP.** The browser talks to a consumer
system, which forwards every request through an SM59 destination to the
source system where the abap2UI5 apps run. For landscapes where users should
reach the apps of another system through one entry point.

> Part of [abap2UI5-addons](https://github.com/abap2UI5-addons) - addons and apps for [abap2UI5](https://github.com/abap2UI5/abap2UI5), installed with [abapGit](https://abapgit.org). Documentation: [abap2ui5-addons.github.io/http-connector](https://abap2ui5-addons.github.io/http-connector/).

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
- NetWeaver 7.02 - 7.40: the branch `702`, downported automatically from
  `standard` on every push - pull abap2UI5 from its `702` branch as well
- [abap2UI5](https://github.com/abap2UI5/abap2UI5) on both systems:
  - **consumer system:** **1.149.0 or newer** - the connector forwards the
    query string and sends the request body as UTF-8 JSON through
    `z2ui5_cl_ui5_util_http=>client_request`, which that release added
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

### Parallel installation (namespace rename)

To run a second copy next to the original in the same system, rename it the
way abap2UI5 itself is renamed: run the workflow **build-rename** (Actions →
build-rename → Run workflow) with the name your abap2UI5 installation was
renamed to - e.g. `ZMYUI5` (at most 6 characters here - the ICF node `z2ui5_http_srv` has to stay within 15). It pushes the branch `rename_<name>`, in
which every object and every reference to abap2UI5 and to the addons this one
needs carries that name; pull it with abapGit. Rename abap2UI5 and every addon
of the installation with the same name.

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
* **Response headers are the consumer's own.** Only body and status come back from the source system, so the consumer sets the response headers the way abap2UI5 does by default: the content type (page, bundle, JSON roundtrip, plain-text error), the cache policy (the page and the bundles revalidated, everything else `no-store`) and the default security headers (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, `Cross-Origin-Resource-Policy`). Security headers a user exit adds on the source system do not reach the browser - change them in `Z2UI5_CL_HTTP_CON_HANDLER` (`get_security_headers`) as well - and the page and the bundles have no ETag, so a reload fetches them again instead of getting a 304.

### Troubleshooting

`HTTP_CONNECTOR_ERROR - the source system could not be reached` (status 502)
means the forwarded call failed before the source system answered:
destination missing or not authorized, host unreachable, timeout. The text
names no destination, host or user on purpose - every user can see it. Test
the destination in SM59 (Connection Test) and look into the ICM trace (SMICM)
of the consumer system for the reason.

## Development

```sh
npm ci
npm run check
```

`npm run check` runs abaplint, the abap2UI5-linter and the namespace rename;
`npm run unit` runs the ABAP Unit tests on abap2UI5's transpiled Node
runtime - each a job of the `ci` workflow (`ci.yaml`, from the shared CI
template of abap2UI5-addons).

## Contributing

Issues and pull requests are welcome - see [CONTRIBUTING.md](CONTRIBUTING.md) for what CI checks. Whether you're fixing bugs, adding new functionality, or improving documentation, your contributions are highly appreciated.

## License

MIT - see [LICENSE](LICENSE).
