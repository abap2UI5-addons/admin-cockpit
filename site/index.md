---
layout: home

hero:
  name: "Admin Cockpit"
  text: "Usage, errors, performance and a security traffic light at a glance."
  image:
    src: /logo.svg
    alt: abap2UI5 addons
  actions:
    - theme: brand
      text: Get started
      link: /guide
    - theme: alt
      text: GitHub
      link: https://github.com/abap2UI5-addons/admin-cockpit
    - theme: alt
      text: All addons
      link: https://abap2ui5-addons.github.io/

features:
  - title: "Overview tiles: active users, roundtrips, p95 response time, error rate, alerts"
  - title: "Errors grouped by app, event and exception, with the user's steps and a replay"
  - title: "Slowest roundtrips with phase breakdown and runtime hints"
  - title: "Sessions step by step, find a value in all drafts, delete expired drafts"
  - title: "Security traffic light: CSRF origin check, CSP, security headers, developer addons"
  - title: "Recorder replays what the user saw and did, with story and process variants"
  - title: "Privacy by default: users counted under a daily SHA-256 pseudonym"
---

## What it does

An abap2UI5 app for administrators and IT leads that shows usage and errors per app, response times with their phases, the draft table and a security traffic light of the installation. The Installation &amp; Security and Drafts &amp; Housekeeping tabs need no logging at all; the usage, error and performance tabs fill once a one-line hook in your HTTP handler or the monitor hook of abap2UI5 records the roundtrips. It steps through what a user did session by session, replays failed events with the headless frontend, records requests and responses, raises alerts and purges its own tables. Privacy mode is on by default: no user names are stored.

## Requirements

- ABAP Cloud or Standard ABAP 7.50 or higher, released APIs only; the 7.02 downport is linted in CI
- UI5 1.71 or later (OpenUI5 and SAPUI5)
- abap2UI5 1.146.0 or later; branch main needs 1.147.0 or later (the monitor hook z2ui5_if_ui5_monitor), otherwise branch standalone
- Optional: abap2UI5-addons/abap-agent-runtime for the Agents tab
- Optional: abap2UI5/headless-frontend for Reproduce
- Optional: abap2UI5-addons/lock-manager for its monitor on the Live tab

## Installation

With [abapGit](https://abapgit.org), from [the repository](https://github.com/abap2UI5-addons/admin-cockpit):

- Install abap2UI5 first, then this repository with abapGit into a package of its own (for example Z2UI5_COCKPIT, folder logic PREFIX)
- Branch main for abap2UI5 1.147.0 or later (with z2ui5_if_ui5_monitor); branch standalone for abap2UI5 1.146.0, without the monitor hook
- Start ?app_start=z2ui5_cl_cockpit_app and claim the administrator role: the first user who presses the button becomes the administrator
- Hook the cockpit into your own HTTP handler: replace z2ui5_cl_ui5_http_handler=&gt;run( server ) with z2ui5_cl_cockpit_wire=&gt;run( server ) once every object is active
- Or switch the monitor hook on in your user exit: cs_config-check_monitor_active = abap_true in set_config_http_post
- Schedule z2ui5_cl_cockpit_job=&gt;run( ) every 15 minutes for housekeeping and alerts

The [Guide](/guide) has every step.

## A first app

```abap
METHOD if_http_extension~handle_request.
  z2ui5_cl_cockpit_wire=>run( server ).  " instead of z2ui5_cl_ui5_http_handler=>run( server )
ENDMETHOD.
```

## Links

- [abap2UI5-addons/abap-agent-runtime](https://github.com/abap2UI5-addons/abap-agent-runtime)
- [abap2UI5/headless-frontend](https://github.com/abap2UI5/headless-frontend)
- [abap2UI5-addons/lock-manager](https://github.com/abap2UI5-addons/lock-manager)
- [abap2UI5](https://github.com/abap2UI5/abap2UI5)
- [The repository](https://github.com/abap2UI5-addons/admin-cockpit) - issues and pull requests welcome
