---
layout: home

hero:
  name: "HTTP Connector"
  text: "Call abap2UI5 apps on another system via HTTP."
  image:
    src: /favicon.png
    alt: abap2UI5
  actions:
    - theme: brand
      text: Get started
      link: /guide
    - theme: alt
      text: GitHub
      link: https://github.com/abap2UI5-addons/http-connector
    - theme: alt
      text: All addons
      link: https://abap2ui5-addons.github.io/

features:
  - title: "Thin ICF handler Z2UI5_CL_HTTP_CON_HANDLER on the consumer system"
  - title: "Server endpoint Z2UI5_CL_HTTP_CON_SERVER on the source system"
  - title: "Forwards method, body, query string and HTTP status via SM59 destination"
  - title: "Apps run unchanged on the source system"
  - title: "Stateless apps only; headers and the consumer path are not forwarded"
---

## What it does

The browser talks to a consumer system, which forwards each abap2UI5 roundtrip through an SM59 destination to the source system where the abap2UI5 apps run. The apps stay where they are and run unchanged. It is for landscapes where users should reach the apps of another system through one entry point, and follows the same approach as the [rfc-connector](https://github.com/abap2UI5-addons/rfc-connector) with an HTTP connection instead of RFC.

## Requirements

- Standard ABAP 7.50 or higher on both systems; NetWeaver 7.02 - 7.40 through the downported branch 702
- abap2UI5 on both systems: consumer 1.147.0 or newer, source 1.143.0 or newer
- ABAP Cloud: only an unmaintained prototype branch cloud (consumer side, no CI)
- SM59 destination (type G or H) on the consumer system with path prefix /sap/bc/z2ui5_http_srv/ and login data

## Installation

With [abapGit](https://abapgit.org), from [the repository](https://github.com/abap2UI5-addons/http-connector):

- Install abap2UI5 on both systems, then this repository (branch standard) on both the consumer and the source system
- On the consumer system replace the destination NONE in Z2UI5_CL_HTTP_CON_HANDLER with your source system destination or maintain the URL constant
- Activate the ICF nodes in SICF: /sap/bc/z2ui5_http on the consumer system and /sap/bc/z2ui5_http_srv on the source system
- Open .../sap/bc/z2ui5_http of the consumer system in the browser

The [Guide](/guide) has every step.

## A first app

The [Guide](/guide) shows how it is used.

## Links

- [rfc-connector](https://github.com/abap2UI5-addons/rfc-connector) - the same approach over RFC
- [abap2UI5](https://github.com/abap2UI5/abap2UI5)
- [The repository](https://github.com/abap2UI5-addons/http-connector) - issues and pull requests welcome
