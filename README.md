[![ABAP_STANDARD](https://github.com/abap2UI5-addons/http-connector/actions/workflows/ABAP_STANDARD.yaml/badge.svg)](https://github.com/abap2UI5-addons/http-connector/actions/workflows/ABAP_STANDARD.yaml)

## HTTP Connector

Remotely Call abap2UI5 Apps via HTTP.

Same approach as the [rfc-connector](https://github.com/abap2UI5-addons/rfc-connector), just with an HTTP connection instead of RFC:

#### Approach

```
Browser ── GET/POST ──> Consumer System                    Source System
                        /sap/bc/z2ui5_http                 /sap/bc/z2ui5_http_srv
                        Z2UI5_CL_HTTP_CON_HANDLER          Z2UI5_CL_HTTP_CON_SERVER
                          │                                  │
                          └── HTTP (SM59 destination) ──────>└──> z2ui5_cl_http_handler
```

The consumer system receives the browser request, forwards method and body via HTTP to the source system and returns the response. All abap2UI5 apps run on the source system.

#### Installation

_Prerequisite: Set up a destination in SM59 (type G or H) on the consumer system pointing to the source system with path prefix `/sap/bc/z2ui5_http_srv/` and login data maintained. abap2UI5 needs to be installed in both systems._

Steps:
1. Install this repository on both systems.
2. Replace in the HTTP handler `Z2UI5_CL_HTTP_CON_HANDLER` the destination `NONE` with your Source System Destination (or maintain the URL constant instead).
3. Activate the ICF nodes `/sap/bc/z2ui5_http` (consumer system) and `/sap/bc/z2ui5_http_srv` (source system) in transaction SICF.
4. Call in your browser the endpoint `.../sap/bc/z2ui5_http`

#### Contribution & Support
Pull requests are welcome! Whether you're fixing bugs, adding new functionality, or improving documentation, your contributions are highly appreciated. If you encounter any issues, feel free to open an issue.
