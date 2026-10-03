"! <p class="shorttext synchronized">admin cockpit - installation and security</p>
"!
"! What is installed and how it is configured - works without any logging.
"!
"! The configuration is read the way the framework computes it: the
"! framework's exit instance (its defaults plus the installation's user
"! exit) fills the released z2ui5_if_ui5_exit structures, read-only. The
"! exit class is a framework internal and is therefore only named in a
"! literal (dynamic call) - a renamed internal costs this tab its numbers,
"! never the activation of the cockpit.
CLASS z2ui5_cl_cockpit_inst DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF cs_status,
        ok    TYPE string VALUE `Success`,
        warn  TYPE string VALUE `Warning`,
        error TYPE string VALUE `Error`,
        info  TYPE string VALUE `Information`,
      END OF cs_status.

    TYPES:
      BEGIN OF ty_s_check,
        id     TYPE string,
        status TYPE string,
        icon   TYPE string,
        title  TYPE string,
        value  TYPE string,
        text   TYPE string,
        fix    TYPE string,
      END OF ty_s_check.
    TYPES ty_t_check TYPE STANDARD TABLE OF ty_s_check WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_addon,
        name      TYPE string,
        marker    TYPE string,
        kind      TYPE string,
        installed TYPE abap_bool,
        status    TYPE string,
        state     TYPE string,
        note      TYPE string,
        url       TYPE string,
      END OF ty_s_addon.
    TYPES ty_t_addon TYPE STANDARD TABLE OF ty_s_addon WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_install,
        version       TYPE string,
        platform      TYPE string,
        user_exit     TYPE string,
        ui5_src       TYPE string,
        ui5_theme     TYPE string,
        csp           TYPE string,
        headers       TYPE string,
        draft_expiry  TYPE string,
        check_config  TYPE abap_bool,
        config_error  TYPE string,
      END OF ty_s_install.

    CLASS-METHODS get_install
      RETURNING
        VALUE(result) TYPE ty_s_install.

    "! The security traffic light: every check with status, explanation and
    "! how to fix it.
    CLASS-METHODS get_checks
      RETURNING
        VALUE(result) TYPE ty_t_check.

    "! The configuration checks of the traffic light for a given page and
    "! roundtrip configuration - what get_checks( ) shows, without reading
    "! the framework.
    CLASS-METHODS evaluate_config
      IMPORTING
        is_get        TYPE z2ui5_if_ui5_exit=>ty_s_http_config
        is_post       TYPE z2ui5_if_ui5_exit=>ty_s_http_config_post
      RETURNING
        VALUE(result) TYPE ty_t_check.

    "! The traffic-light check of the agent endpoint (agent addon) for the
    "! given figures - empty when the addon is not installed.
    CLASS-METHODS evaluate_agent
      IMPORTING
        is_agent      TYPE z2ui5_cl_cockpit_agent=>ty_s_setup
      RETURNING
        VALUE(result) TYPE ty_t_check.

    "! The known addons of abap2UI5-addons and whether they are installed,
    "! detected by the existence of a marker class.
    CLASS-METHODS get_addons
      RETURNING
        VALUE(result) TYPE ty_t_addon.

    "! The page configuration the framework computes (defaults + user exit).
    "! Raises when the framework's exit cannot be reached.
    CLASS-METHODS get_config_get
      RETURNING
        VALUE(result) TYPE z2ui5_if_ui5_exit=>ty_s_http_config
      RAISING
        cx_static_check.

    "! The roundtrip configuration the framework computes. Initial when the
    "! framework's exit cannot be reached.
    CLASS-METHODS get_config_post
      RETURNING
        VALUE(result) TYPE z2ui5_if_ui5_exit=>ty_s_http_config_post.

    "! The user exit class the framework found, empty when none.
    CLASS-METHODS get_user_exit_class
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS check_cloud
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS check_class_exists
      IMPORTING
        name          TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS check_type_exists
      IMPORTING
        name          TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! The classes implementing an interface, via the framework's own
    "! repository lookup (standard and cloud); empty when unavailable.
    CLASS-METHODS get_implementers
      IMPORTING
        intf          TYPE clike
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cockpit_setup=>ty_t_names.

    "! The script-src directive of a CSP meta tag or header value.
    CLASS-METHODS csp_directive
      IMPORTING
        csp           TYPE string
        directive     TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.

  PRIVATE SECTION.

    CLASS-METHODS get_exit
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_if_ui5_exit
      RAISING
        cx_static_check.

    CLASS-METHODS add_check
      IMPORTING
        id     TYPE string
        status TYPE string
        title  TYPE string
        value  TYPE string OPTIONAL
        text   TYPE string
        fix    TYPE string OPTIONAL
      CHANGING
        checks TYPE ty_t_check.

    CLASS-METHODS header_value
      IMPORTING
        headers       TYPE z2ui5_if_client=>ty_t_name_value
        name          TYPE string
      RETURNING
        VALUE(result) TYPE string.


    CLASS-METHODS checks_cockpit
      CHANGING
        checks TYPE ty_t_check.

    CLASS-METHODS check_icon
      IMPORTING
        status        TYPE string
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS z2ui5_cl_cockpit_inst IMPLEMENTATION.

  METHOD get_install.

    result-version  = z2ui5_if_app=>version.
    result-platform = COND #( WHEN check_cloud( ) = abap_true
                              THEN `ABAP Cloud`
                              ELSE `Standard ABAP` ).
    result-user_exit = get_user_exit_class( ).
    IF result-user_exit IS INITIAL.
      result-user_exit = `(none - framework defaults)`.
    ENDIF.
    result-draft_expiry = |{ get_config_post( )-draft_exp_time_in_hours } hours|.

    TRY.
        DATA(ls_get) = get_config_get( ).
        result-check_config = abap_true.
        result-ui5_src   = ls_get-src.
        result-ui5_theme = ls_get-theme.
        result-csp       = ls_get-content_security_policy.
        LOOP AT ls_get-t_security_header INTO DATA(ls_header).
          result-headers = |{ result-headers }{ ls_header-n }: { ls_header-v }{ cl_abap_char_utilities=>newline }|.
        ENDLOOP.
      CATCH cx_root INTO DATA(lx).
        result-config_error = lx->get_text( ).
    ENDTRY.

  ENDMETHOD.

  METHOD get_checks.

    DATA ls_get TYPE z2ui5_if_ui5_exit=>ty_s_http_config.
    TRY.
        ls_get = get_config_get( ).
        result = evaluate_config( is_get  = ls_get
                                  is_post = get_config_post( ) ).
      CATCH cx_root INTO DATA(lx).
        add_check( EXPORTING id     = `CONFIG`
                             status = cs_status-error
                             title  = `Framework configuration readable`
                             value  = lx->get_text( )
                             text   = `The cockpit could not call the framework's exit instance. ` &&
                                      `The configuration checks need it.`
                             fix    = `Update the admin cockpit to a version matching your abap2UI5 release.`
                   CHANGING  checks = result ).
    ENDTRY.
    checks_cockpit( CHANGING checks = result ).
    DATA(lt_agent) = evaluate_agent( z2ui5_cl_cockpit_agent=>get_setup( ) ).
    APPEND LINES OF lt_agent TO result.

    LOOP AT result ASSIGNING FIELD-SYMBOL(<check>).
      <check>-icon = check_icon( <check>-status ).
    ENDLOOP.

  ENDMETHOD.

  METHOD check_icon.

    result = SWITCH #( status
                       WHEN cs_status-ok    THEN `sap-icon://status-positive`
                       WHEN cs_status-warn  THEN `sap-icon://status-critical`
                       WHEN cs_status-error THEN `sap-icon://status-negative`
                       ELSE `sap-icon://hint` ).

  ENDMETHOD.

  METHOD evaluate_agent.

    IF is_agent-installed = abap_false.
      RETURN.
    ENDIF.

    IF is_agent-readable = abap_false.
      add_check( EXPORTING id     = `AGENT`
                           status = cs_status-warn
                           title  = `Agent endpoint (agent addon)`
                           value  = `settings not readable`
                           text   = `The agent addon is installed, but its settings could not be read - ` &&
                                    `the cockpit cannot tell whether AI agents can operate apps.`
                           fix    = `Check the agent addon's settings app z2ui5_cl_agent_app_admin.`
                 CHANGING  checks = result ).
    ELSEIF is_agent-enabled = abap_false.
      add_check( EXPORTING id     = `AGENT`
                           status = cs_status-ok
                           title  = `Agent endpoint (agent addon)`
                           value  = `disabled`
                           text   = `AI agents cannot operate apps - the endpoint refuses every tool call.`
                 CHANGING  checks = result ).
    ELSEIF is_agent-admins = 0.
      add_check( EXPORTING id     = `AGENT`
                           status = cs_status-error
                           title  = `Agent endpoint (agent addon)`
                           value  = `enabled, no administrator`
                           text   = `AI agents can operate the opted-in apps as the calling user, but nobody may ` &&
                                    `change the agent settings or review the audit log of all users.`
                           fix    = `Run z2ui5_cl_agent_settings=>admin_add( ) for a responsible user, ` &&
                                    `or switch the endpoint off.`
                 CHANGING  checks = result ).
    ELSEIF is_agent-allow_all = abap_true.
      add_check( EXPORTING id     = `AGENT`
                           status = cs_status-warn
                           title  = `Agent endpoint (agent addon)`
                           value  = `enabled for every app`
                           text   = `An APP rule allows the pattern * - agents can start every app class, ` &&
                                    `not only the ones that opted in by implementing z2ui5_if_agent_app.`
                           fix    = `Agent settings app: replace the * rule by the apps agents really need.`
                 CHANGING  checks = result ).
    ELSEIF is_agent-app_rules = 0 AND is_agent-opted_in = 0.
      add_check( EXPORTING id     = `AGENT`
                           status = cs_status-warn
                           title  = `Agent endpoint (agent addon)`
                           value  = `enabled, no app reachable`
                           text   = `The endpoint answers tool calls, but no app opted in and no APP rule exists - ` &&
                                    `switched on without a purpose.`
                           fix    = `Switch the endpoint off until an app is meant to be operated by agents.`
                 CHANGING  checks = result ).
    ELSE.
      add_check( EXPORTING id     = `AGENT`
                           status = cs_status-info
                           title  = `Agent endpoint (agent addon)`
                           value  = |enabled - { is_agent-opted_in } opted-in app(s), { is_agent-app_rules } app rule(s), | &&
                                    |{ is_agent-admins } administrator(s)|
                           text   = `AI agents can operate the reachable apps as the calling user; every call is ` &&
                                    `audited (Agents tab).`
                 CHANGING  checks = result ).
    ENDIF.

    LOOP AT result ASSIGNING FIELD-SYMBOL(<check>).
      <check>-icon = check_icon( <check>-status ).
    ENDLOOP.

  ENDMETHOD.

  METHOD evaluate_config.

    DATA lv_missing TYPE string.
    DATA(ls_get) = is_get.
    DATA(ls_post) = is_post.

    add_check( EXPORTING id     = `CSRF`
                         status = COND #( WHEN ls_post-check_csrf_active = abap_true
                                          THEN cs_status-ok ELSE cs_status-error )
                         title  = `CSRF origin check`
                         value  = COND #( WHEN ls_post-check_csrf_active = abap_true THEN `on` ELSE `off` )
                         text   = `A state-changing POST whose Origin/Referer names another site is rejected ` &&
                                  `with 403. On by default; an exit can switch it off for cross-origin callers.`
                         fix    = `Remove cs_config-check_csrf_active = abap_false from set_config_http_post ` &&
                                  `of your user exit, unless a cross-origin caller really needs it.`
               CHANGING  checks = result ).

    add_check( EXPORTING id     = `FORWARDED_HOST`
                         status = COND #( WHEN ls_post-check_trust_forwarded_host = abap_true
                                          THEN cs_status-info ELSE cs_status-ok )
                         title  = `X-Forwarded-Host trusted by the CSRF check`
                         value  = COND #( WHEN ls_post-check_trust_forwarded_host = abap_true THEN `yes` ELSE `no` )
                         text   = `Right behind a web dispatcher or reverse proxy that sets the header. ` &&
                                  `Without such a proxy the header is client-suppliable.`
                         fix    = `Not behind a proxy: set cs_config-check_trust_forwarded_host = abap_false ` &&
                                  `in set_config_http_post of your user exit.`
               CHANGING  checks = result ).

    add_check( EXPORTING id     = `ERROR_DETAILS`
                         status = COND #( WHEN ls_post-check_hide_error_details = abap_true
                                          THEN cs_status-ok ELSE cs_status-warn )
                         title  = `Error details hidden from the browser`
                         value  = COND #( WHEN ls_post-check_hide_error_details = abap_true THEN `hidden` ELSE `shown` )
                         text   = `Without it, framework errors answer with the raw exception chain - ` &&
                                  `class names, texts and positions reach the browser.`
                         fix    = `Production: set cs_config-check_hide_error_details = abap_true ` &&
                                  `in set_config_http_post of your user exit.`
               CHANGING  checks = result ).

    DATA(lv_csp) = ls_get-content_security_policy.
    DATA(lv_csp_header) = header_value( headers = ls_get-t_security_header
                                        name    = `content-security-policy` ).
    IF lv_csp IS INITIAL AND lv_csp_header IS INITIAL.
      add_check( EXPORTING id     = `CSP`
                           status = cs_status-error
                           title  = `Content Security Policy`
                           value  = `none`
                           text   = `The page carries no CSP - any injected script would run.`
                           fix    = `Do not clear cs_config-content_security_policy in your user exit; ` &&
                                    `extend the default instead.`
                 CHANGING  checks = result ).
    ELSE.
      DATA(lv_all) = to_lower( |{ lv_csp } { lv_csp_header }| ).
      DATA(lv_script) = csp_directive( csp       = lv_all
                                       directive = `script-src` ).
      IF lv_script IS INITIAL.
        lv_script = csp_directive( csp       = lv_all
                                   directive = `default-src` ).
      ENDIF.

      add_check( EXPORTING id     = `CSP_EVAL`
                           status = COND #( WHEN lv_script CS `'unsafe-eval'` THEN cs_status-warn ELSE cs_status-ok )
                           title  = `CSP without 'unsafe-eval'`
                           value  = COND #( WHEN lv_script CS `'unsafe-eval'` THEN `contains 'unsafe-eval'` ELSE `ok` )
                           text   = `'unsafe-eval' lets strings become code. Only UI5 1.71-1.82 popups with ` &&
                                    `unloaded binding types need it ('wasm-unsafe-eval' is fine).`
                           fix    = `Remove 'unsafe-eval' from script-src in set_config_http_get of your user exit, ` &&
                                    `or upgrade UI5 to 1.84+.`
                 CHANGING  checks = result ).

      add_check( EXPORTING id     = `CSP_INLINE`
                           status = COND #( WHEN lv_script CS `'unsafe-inline'` THEN cs_status-error ELSE cs_status-ok )
                           title  = `CSP without 'unsafe-inline' for scripts`
                           value  = COND #( WHEN lv_script CS `'unsafe-inline'` THEN `contains 'unsafe-inline'` ELSE `ok` )
                           text   = `With 'unsafe-inline' in script-src every injected inline script runs; ` &&
                                    `the framework then also stops adding the hash of its own inline script.`
                           fix    = `Remove 'unsafe-inline' from script-src in your user exit ` &&
                                    `(style-src may keep it - UI5 needs it there).`
                 CHANGING  checks = result ).

      DATA(lv_wild) = xsdbool( lv_script CS ` * ` OR lv_script CS ` https: ` OR lv_script CS ` http: `
                               OR lv_script CS `cdn.jsdelivr.net` OR lv_script CS `cdnjs.cloudflare.com` ).
      add_check( EXPORTING id     = `CSP_HOSTS`
                           status = COND #( WHEN lv_wild = abap_true THEN cs_status-warn ELSE cs_status-ok )
                           title  = `Script hosts limited`
                           value  = COND #( WHEN lv_wild = abap_true THEN `wildcard or general-purpose CDN` ELSE `ok` )
                           text   = `Every allowed script host is a host whose compromise is script execution ` &&
                                    `in an authenticated SAP session.`
                           fix    = `Allow only the UI5 hosts (or your own) in script-src.`
                 CHANGING  checks = result ).
    ENDIF.

    DATA(lt_expected) = VALUE z2ui5_cl_cockpit_setup=>ty_t_names( ( `x-content-type-options` )
                                                                  ( `x-frame-options` )
                                                                  ( `referrer-policy` )
                                                                  ( `permissions-policy` ) ).
    LOOP AT lt_expected INTO DATA(lv_expected).
      IF header_value( headers = ls_get-t_security_header
                       name    = lv_expected ) IS INITIAL.
        lv_missing = |{ lv_missing } { lv_expected }|.
      ENDIF.
    ENDLOOP.
    add_check( EXPORTING id     = `HEADERS`
                         status = COND #( WHEN lv_missing IS INITIAL THEN cs_status-ok ELSE cs_status-warn )
                         title  = `Security headers`
                         value  = COND #( WHEN lv_missing IS INITIAL THEN `set` ELSE |missing:{ lv_missing }| )
                         text   = `nosniff, frame protection, referrer and permissions policy are set by the ` &&
                                  `framework's defaults; an exit that replaces t_security_header can lose them.`
                         fix    = `APPEND to cs_config-t_security_header in your user exit instead of replacing it.`
               CHANGING  checks = result ).

    DATA(lv_hsts) = header_value( headers = ls_get-t_security_header
                                  name    = `strict-transport-security` ).
    add_check( EXPORTING id     = `HSTS`
                         status = COND #( WHEN lv_hsts IS INITIAL THEN cs_status-info ELSE cs_status-ok )
                         title  = `Strict-Transport-Security`
                         value  = COND #( WHEN lv_hsts IS INITIAL THEN `not set` ELSE lv_hsts )
                         text   = `Not set by default on purpose: many on-premise systems serve plain HTTP. ` &&
                                  `Served over HTTPS, it belongs to the TLS terminator or the exit.`
                         fix    = `HTTPS only: APPEND VALUE #( n = 'Strict-Transport-Security' v = 'max-age=31536000' ) ` &&
                                  `TO cs_config-t_security_header.`
               CHANGING  checks = result ).

    DATA(lv_src) = to_lower( ls_get-src ).
    DATA(lv_cdn) = xsdbool( lv_src CS `openui5.org` OR lv_src CS `ui5.sap.com` OR lv_src CS `hana.ondemand.com` ).
    add_check( EXPORTING id     = `BOOTSTRAP`
                         status = COND #( WHEN lv_cdn = abap_true THEN cs_status-info ELSE cs_status-ok )
                         title  = `UI5 bootstrap`
                         value  = ls_get-src
                         text   = COND #( WHEN lv_cdn = abap_true
                                          THEN `UI5 loads from a public CDN: every browser needs internet access ` &&
                                               `and the page trusts that host.`
                                          ELSE `UI5 loads from a host of your own.` )
                         fix    = COND #( WHEN lv_cdn = abap_true
                                          THEN `Optional: serve UI5 from your system (/sap/public/bc/ui5_ui5/) and set ` &&
                                               `cs_config-src in set_config_http_get.` )
               CHANGING  checks = result ).

    add_check( EXPORTING id     = `EXPIRY`
                         status = COND #( WHEN ls_post-draft_exp_time_in_hours > 24
                                          THEN cs_status-warn ELSE cs_status-ok )
                         title  = `Draft expiry`
                         value  = |{ ls_post-draft_exp_time_in_hours } hours|
                         text   = `Drafts hold the serialized app state of every user. A long expiry keeps ` &&
                                  `business data in the draft table and lets it grow.`
                         fix    = `Set cs_config-draft_exp_time_in_hours in set_config_http_post (default 4).`
               CHANGING  checks = result ).

    LOOP AT result ASSIGNING FIELD-SYMBOL(<check>).
      <check>-icon = check_icon( <check>-status ).
    ENDLOOP.

  ENDMETHOD.

  METHOD checks_cockpit.

    DATA lv_dev TYPE string.
    LOOP AT get_addons( ) INTO DATA(ls_addon) WHERE installed = abap_true AND kind = `developer tool`. "#EC CI_SORTSEQ
      lv_dev = |{ lv_dev }{ COND #( WHEN lv_dev IS NOT INITIAL THEN `, ` ) }{ ls_addon-name }|.
    ENDLOOP.
    add_check( EXPORTING id     = `DEV_ADDONS`
                         status = COND #( WHEN lv_dev IS INITIAL THEN cs_status-ok ELSE cs_status-error )
                         title  = `Developer addons reachable`
                         value  = COND #( WHEN lv_dev IS INITIAL THEN `none installed` ELSE lv_dev )
                         text   = `Any user who can reach the abap2UI5 ICF node can start any installed app class. ` &&
                                  `SQL consoles, table browsers and SE80-like tools read and change data.`
                         fix    = `Do not install them in production, or restrict them: an authorization check ` &&
                                  `in your user exit / ICF node (allowed apps per role).`
               CHANGING  checks = checks ).

    DATA(lv_auth_mode) = z2ui5_cl_cockpit_auth=>get_mode( ).
    add_check( EXPORTING id     = `COCKPIT_AUTH`
                         status = COND #( WHEN lv_auth_mode = z2ui5_cl_cockpit_auth=>cs_mode-claim
                                          THEN cs_status-error ELSE cs_status-ok )
                         title  = `Admin cockpit restricted`
                         value  = z2ui5_cl_cockpit_auth=>get_mode_text( )
                         text   = `The cockpit shows usage and configuration of the whole system. Without an ` &&
                                  `administrator it shows only the claim screen - to whoever opens it first.`
                         fix    = `Claim the administrator role right after the installation and maintain the ` &&
                                  `administrators on the Settings tab, or implement z2ui5_if_cockpit_auth.`
               CHANGING  checks = checks ).

    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get( ).
    add_check( EXPORTING id     = `PRIVACY`
                         status = COND #( WHEN ls_set-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-name
                                          THEN cs_status-warn ELSE cs_status-ok )
                         title  = `Monitor privacy mode`
                         value  = ls_set-user_tracking
                         text   = `HASH counts users under a pseudonym that changes every day, NONE does not ` &&
                                  `count users, NAME stores user names (performance and behaviour monitoring ` &&
                                  `may require works council approval).`
                         fix    = `Settings tab: user tracking HASH or NONE.`
               CHANGING  checks = checks ).

  ENDMETHOD.

  METHOD get_addons.

    result = VALUE #(
      ( name = `popups`                   marker = `Z2UI5_CL_POPUP_CONTEXT`         kind = `library` )
      ( name = `layout-management`        marker = `Z2UI5_CL_LAYO_MANAGER`          kind = `library` )
      ( name = `selection-screen`         marker = `Z2UI5_CL_SEL_SCREEN`            kind = `library` )
      ( name = `abap-cloud-gui`           marker = `Z2UI5_CL_CGUI_CONTEXT`          kind = `library` )
      ( name = `custom-controls`          marker = `Z2UI5_CL_CCI`                   kind = `library` )
      ( name = `custom-controls-customer` marker = `Z2UI5_CL_CCC`                   kind = `library` )
      ( name = `lock-manager`             marker = `Z2UI5_CL_LOCK_MANAGER`          kind = `library` )
      ( name = `config-management`        marker = `Z2UI5_CL_CONFIG_SERVICE`        kind = `library` )
      ( name = `rap-ext`                  marker = `Z2UI5_CL_RAP_UTIL`              kind = `library` )
      ( name = `open-source-libs`         marker = `Z2UI5_CL_OSL_VALIDATOR`         kind = `library` )
      ( name = `launchpad-kpi`            marker = `Z2UI5_CL_LP_KPI_HELLO_WORLD`    kind = `library` )
      ( name = `headless-frontend`        marker = `Z2UI5_CL_FRONTEND_SIMULATOR`    kind = `test tool` )
      ( name = `agent`                    marker = `Z2UI5_CL_AGENT_SETTINGS`        kind = `agent endpoint` )
      ( name = `http-connector`           marker = `Z2UI5_CL_HTTP_CON_HANDLER`      kind = `connector` )
      ( name = `rfc-connector`            marker = `Z2UI5_CL_RFC_CONNECTOR_HANDLER` kind = `connector` )
      ( name = `sql-console`              marker = `Z2UI5_SQL_CL_APP_01`            kind = `developer tool` )
      ( name = `se16n`                    marker = `Z2UI5_CL_SE16_CONTEXT`          kind = `developer tool` )
      ( name = `table-maintenance`        marker = `Z2UI5_CL_TM_001`                kind = `developer tool` )
      ( name = `table-content-loader`     marker = `Z2UI5_CL_TCL_CONTEXT`           kind = `developer tool` )
      ( name = `sapgui (SE80, SE38, SE16N, ...)` marker = `ZCL_SAPGUI_A2UI5`        kind = `developer tool` ) ).

    LOOP AT result ASSIGNING FIELD-SYMBOL(<addon>).
      <addon>-url = |https://github.com/abap2UI5-addons/{ segment( val   = <addon>-name
                                                                    index = 1
                                                                    sep   = ` ` ) }|.
      <addon>-installed = check_class_exists( <addon>-marker ).
      IF <addon>-installed = abap_true.
        <addon>-status = `installed`.
        <addon>-state = COND #( WHEN <addon>-kind = `developer tool`
                                THEN cs_status-error ELSE cs_status-ok ).
        CASE <addon>-kind.
          WHEN `developer tool`.
            <addon>-note = `Reachable for every user of the ICF node unless restricted.`.
          WHEN `agent endpoint`.
            <addon>-note = `MCP endpoint for AI agents - see the Agents tab and the traffic light.`.
          WHEN `test tool`.
            <addon>-note = `Enables Reproduce on the Errors tab.`.
        ENDCASE.
      ELSE.
        <addon>-status = `not installed`.
        <addon>-state = `None`.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_exit.

    " exactly what the framework does per request: one instance per roll
    " area, holding the defaults and the user exit it found
    CALL METHOD (`Z2UI5_CL_UI5_USER_EXIT`)=>(`GET_INSTANCE`)
      RECEIVING
        result = result.
    IF result IS NOT BOUND.
      RAISE EXCEPTION TYPE cx_sy_ref_is_initial.
    ENDIF.

  ENDMETHOD.

  METHOD get_config_get.

    get_exit( )->set_config_http_get( CHANGING cs_config = result ).

  ENDMETHOD.

  METHOD get_config_post.

    TRY.
        get_exit( )->set_config_http_post( CHANGING cs_config = result ).
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.

  METHOD get_user_exit_class.

    TRY.
        CALL METHOD (`Z2UI5_CL_UI5_USER_EXIT`)=>(`GET_USER_EXIT_CLASS`)
          RECEIVING
            result = result.
      CATCH cx_root.
        result = `(unknown - framework internals changed)`.
    ENDTRY.

  ENDMETHOD.

  METHOD check_cloud.

    " T100 is not released for ABAP Cloud - the same probe the framework uses
    result = xsdbool( check_type_exists( `T100` ) = abap_false ).

  ENDMETHOD.

  METHOD check_class_exists.

    cl_abap_typedescr=>describe_by_name( EXPORTING  p_name         = name
                                         EXCEPTIONS type_not_found = 1
                                                    OTHERS         = 2 ).
    result = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.

  METHOD check_type_exists.

    TRY.
        result = check_class_exists( name ).
      CATCH cx_root.
        result = abap_false.
    ENDTRY.

  ENDMETHOD.

  METHOD get_implementers.

    TYPES:
      BEGIN OF ty_s_class,
        classname   TYPE string,
        description TYPE string,
      END OF ty_s_class.
    DATA lt_classes TYPE STANDARD TABLE OF ty_s_class WITH EMPTY KEY.

    TRY.
        CALL METHOD (`Z2UI5_CL_UI5_UTIL_CONTEXT`)=>(`RTTI_GET_CLASSES_IMPL_INTF`)
          EXPORTING
            val    = intf
          RECEIVING
            result = lt_classes.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    LOOP AT lt_classes INTO DATA(ls_class).
      APPEND to_upper( ls_class-classname ) TO result.
    ENDLOOP.
    SORT result.
    DELETE ADJACENT DUPLICATES FROM result.

  ENDMETHOD.

  METHOD csp_directive.

    DATA(lv_off) = find( val = csp
                         sub = directive ).
    IF lv_off < 0.
      RETURN.
    ENDIF.
    result = substring( val = csp
                        off = lv_off ).
    IF result CS `;`.
      result = substring_before( val = result
                                 sub = `;` ).
    ENDIF.
    IF result CS `"`.
      result = substring_before( val = result
                                 sub = `"` ).
    ENDIF.
    result = | { result } |.

  ENDMETHOD.

  METHOD add_check.

    APPEND VALUE #( id     = id
                    status = status
                    title  = title
                    value  = value
                    text   = text
                    fix    = fix ) TO checks.

  ENDMETHOD.

  METHOD header_value.

    LOOP AT headers INTO DATA(ls_header).
      IF to_lower( ls_header-n ) = name.
        result = ls_header-v.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
