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
    TYPES ty_t_check TYPE STANDARD TABLE OF ty_s_check WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_addon,
        name      TYPE string,
        marker    TYPE string,
        " the marker's name before the addon renamed it - an install that
        " has not pulled the rename is still found by it
        marker_old TYPE string,
        kind      TYPE string,
        installed TYPE abap_bool,
        status    TYPE string,
        state     TYPE string,
        note      TYPE string,
        url       TYPE string,
      END OF ty_s_addon.
    TYPES ty_t_addon TYPE STANDARD TABLE OF ty_s_addon WITH DEFAULT KEY.

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

    "! The name of an abap2UI5 object in this installation: val behind the
    "! prefix the cockpit itself carries - Z2UI5_, or the name a namespace
    "! rename gave the installation (ZMYUI5_, /CA2UI5/). Every object the
    "! cockpit names in a literal goes through it: a rename rewrites
    "! references, never a literal.
    CLASS-METHODS obj_name
      IMPORTING
        val           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

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

    "! Whether a class or type exists and can be loaded. One that exists but
    "! cannot be loaded - an addon class with a syntax error raises in RTTI -
    "! counts as missing instead of raising.
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

    CLASS-DATA gv_prefix TYPE string.

    "! RTTI lookup of a class or type: found, or why it could not be loaded
    "! (error stays empty when it does not exist).
    CLASS-METHODS describe
      IMPORTING
        name  TYPE clike
      EXPORTING
        found TYPE abap_bool
        error TYPE string.

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
    DATA temp11 TYPE z2ui5_cl_cockpit_inst=>ty_s_install-platform.
        DATA ls_get TYPE z2ui5_if_ui5_exit=>ty_s_http_config.
        DATA ls_header LIKE LINE OF ls_get-t_security_header.
        DATA lx TYPE REF TO cx_root.

    result-version  = z2ui5_if_app=>version.

    IF check_cloud( ) = abap_true.
      temp11 = `ABAP Cloud`.
    ELSE.
      temp11 = `Standard ABAP`.
    ENDIF.
    result-platform = temp11.
    result-user_exit = get_user_exit_class( ).
    IF result-user_exit IS INITIAL.
      result-user_exit = `(none - framework defaults)`.
    ENDIF.
    result-draft_expiry = |{ get_config_post( )-draft_exp_time_in_hours } hours|.

    TRY.

        ls_get = get_config_get( ).
        result-check_config = abap_true.
        result-ui5_src   = ls_get-src.
        result-ui5_theme = ls_get-theme.
        result-csp       = ls_get-content_security_policy.

        LOOP AT ls_get-t_security_header INTO ls_header.
          result-headers = |{ result-headers }{ ls_header-n }: { ls_header-v }{ cl_abap_char_utilities=>newline }|.
        ENDLOOP.

      CATCH cx_root INTO lx.
        result-config_error = lx->get_text( ).
    ENDTRY.

  ENDMETHOD.

  METHOD get_checks.

    DATA ls_get TYPE z2ui5_if_ui5_exit=>ty_s_http_config.
        DATA lx TYPE REF TO cx_root.
    DATA lt_agent TYPE z2ui5_cl_cockpit_inst=>ty_t_check.
    FIELD-SYMBOLS <check> LIKE LINE OF result.
    TRY.
        ls_get = get_config_get( ).
        result = evaluate_config( is_get  = ls_get
                                  is_post = get_config_post( ) ).

      CATCH cx_root INTO lx.
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

    lt_agent = evaluate_agent( z2ui5_cl_cockpit_agent=>get_setup( ) ).
    APPEND LINES OF lt_agent TO result.


    LOOP AT result ASSIGNING <check>.
      <check>-icon = check_icon( <check>-status ).
    ENDLOOP.

  ENDMETHOD.

  METHOD check_icon.

    DATA temp12 TYPE string.
    CASE status.
      WHEN cs_status-ok.
        temp12 = `sap-icon://status-positive`.
      WHEN cs_status-warn.
        temp12 = `sap-icon://status-critical`.
      WHEN cs_status-error.
        temp12 = `sap-icon://status-negative`.
      WHEN OTHERS.
        temp12 = `sap-icon://hint`.
    ENDCASE.
    result = temp12.

  ENDMETHOD.

  METHOD evaluate_agent.
    FIELD-SYMBOLS <check> LIKE LINE OF result.

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


    LOOP AT result ASSIGNING <check>.
      <check>-icon = check_icon( <check>-status ).
    ENDLOOP.

  ENDMETHOD.

  METHOD evaluate_config.

    DATA lv_missing TYPE string.
    DATA ls_get LIKE is_get.
    DATA ls_post LIKE is_post.
    DATA temp13 TYPE string.
    DATA temp1 TYPE string.
    DATA temp14 TYPE string.
    DATA temp2 TYPE string.
    DATA temp15 TYPE string.
    DATA temp3 TYPE string.
    DATA lv_csp LIKE ls_get-content_security_policy.
    DATA lv_csp_header TYPE string.
      DATA lv_all TYPE string.
      DATA lv_script TYPE string.
      DATA temp16 TYPE string.
      DATA temp4 TYPE string.
      DATA temp17 TYPE string.
      DATA temp5 TYPE string.
      DATA lv_wild TYPE abap_bool.
      DATA temp11 TYPE xsdboolean.
      DATA temp18 TYPE string.
      DATA temp6 TYPE string.
    DATA temp19 TYPE z2ui5_cl_cockpit_setup=>ty_t_names.
    DATA lt_expected LIKE temp19.
    DATA lv_expected LIKE LINE OF lt_expected.
    DATA temp21 TYPE string.
    DATA temp7 TYPE string.
    DATA lv_hsts TYPE string.
    DATA temp22 TYPE string.
    DATA temp8 TYPE string.
    DATA lv_src TYPE string.
    DATA lv_cdn TYPE abap_bool.
    DATA temp12 TYPE xsdboolean.
    DATA temp23 TYPE string.
    DATA temp9 TYPE string.
    DATA temp10 TYPE string.
    DATA temp24 TYPE string.
    FIELD-SYMBOLS <check> LIKE LINE OF result.
    ls_get = is_get.

    ls_post = is_post.


    IF ls_post-check_csrf_active = abap_true.
      temp13 = cs_status-ok.
    ELSE.
      temp13 = cs_status-error.
    ENDIF.

    IF ls_post-check_csrf_active = abap_true.
      temp1 = `on`.
    ELSE.
      temp1 = `off`.
    ENDIF.
    add_check( EXPORTING id     = `CSRF`
                         status = temp13
                         title  = `CSRF origin check`
                         value  = temp1
                         text   = `A state-changing POST whose Origin/Referer names another site is rejected ` &&
                                  `with 403. On by default; an exit can switch it off for cross-origin callers.`
                         fix    = `Remove cs_config-check_csrf_active = abap_false from set_config_http_post ` &&
                                  `of your user exit, unless a cross-origin caller really needs it.`
               CHANGING  checks = result ).


    IF ls_post-check_trust_forwarded_host = abap_true.
      temp14 = cs_status-info.
    ELSE.
      temp14 = cs_status-ok.
    ENDIF.

    IF ls_post-check_trust_forwarded_host = abap_true.
      temp2 = `yes`.
    ELSE.
      temp2 = `no`.
    ENDIF.
    add_check( EXPORTING id     = `FORWARDED_HOST`
                         status = temp14
                         title  = `X-Forwarded-Host trusted by the CSRF check`
                         value  = temp2
                         text   = `Right behind a web dispatcher or reverse proxy that sets the header. ` &&
                                  `Without such a proxy the header is client-suppliable.`
                         fix    = `Not behind a proxy: set cs_config-check_trust_forwarded_host = abap_false ` &&
                                  `in set_config_http_post of your user exit.`
               CHANGING  checks = result ).


    IF ls_post-check_hide_error_details = abap_true.
      temp15 = cs_status-ok.
    ELSE.
      temp15 = cs_status-warn.
    ENDIF.

    IF ls_post-check_hide_error_details = abap_true.
      temp3 = `hidden`.
    ELSE.
      temp3 = `shown`.
    ENDIF.
    add_check( EXPORTING id     = `ERROR_DETAILS`
                         status = temp15
                         title  = `Error details hidden from the browser`
                         value  = temp3
                         text   = `Without it, framework errors answer with the raw exception chain - ` &&
                                  `class names, texts and positions reach the browser.`
                         fix    = `Production: set cs_config-check_hide_error_details = abap_true ` &&
                                  `in set_config_http_post of your user exit.`
               CHANGING  checks = result ).


    lv_csp = ls_get-content_security_policy.

    lv_csp_header = header_value( headers = ls_get-t_security_header
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

      lv_all = to_lower( |{ lv_csp } { lv_csp_header }| ).

      lv_script = csp_directive( csp       = lv_all
                                       directive = `script-src` ).
      IF lv_script IS INITIAL.
        lv_script = csp_directive( csp       = lv_all
                                   directive = `default-src` ).
      ENDIF.


      IF lv_script CS `'unsafe-eval'`.
        temp16 = cs_status-warn.
      ELSE.
        temp16 = cs_status-ok.
      ENDIF.

      IF lv_script CS `'unsafe-eval'`.
        temp4 = `contains 'unsafe-eval'`.
      ELSE.
        temp4 = `ok`.
      ENDIF.
      add_check( EXPORTING id     = `CSP_EVAL`
                           status = temp16
                           title  = `CSP without 'unsafe-eval'`
                           value  = temp4
                           text   = `'unsafe-eval' lets strings become code. Only UI5 1.71-1.82 popups with ` &&
                                    `unloaded binding types need it ('wasm-unsafe-eval' is fine).`
                           fix    = `Remove 'unsafe-eval' from script-src in set_config_http_get of your user exit, ` &&
                                    `or upgrade UI5 to 1.84+.`
                 CHANGING  checks = result ).


      IF lv_script CS `'unsafe-inline'`.
        temp17 = cs_status-error.
      ELSE.
        temp17 = cs_status-ok.
      ENDIF.

      IF lv_script CS `'unsafe-inline'`.
        temp5 = `contains 'unsafe-inline'`.
      ELSE.
        temp5 = `ok`.
      ENDIF.
      add_check( EXPORTING id     = `CSP_INLINE`
                           status = temp17
                           title  = `CSP without 'unsafe-inline' for scripts`
                           value  = temp5
                           text   = `With 'unsafe-inline' in script-src every injected inline script runs; ` &&
                                    `the framework then also stops adding the hash of its own inline script.`
                           fix    = `Remove 'unsafe-inline' from script-src in your user exit ` &&
                                    `(style-src may keep it - UI5 needs it there).`
                 CHANGING  checks = result ).



      temp11 = boolc( lv_script CS ` * ` OR lv_script CS ` https: ` OR lv_script CS ` http: ` OR lv_script CS `cdn.jsdelivr.net` OR lv_script CS `cdnjs.cloudflare.com` ).
      lv_wild = temp11.

      IF lv_wild = abap_true.
        temp18 = cs_status-warn.
      ELSE.
        temp18 = cs_status-ok.
      ENDIF.

      IF lv_wild = abap_true.
        temp6 = `wildcard or general-purpose CDN`.
      ELSE.
        temp6 = `ok`.
      ENDIF.
      add_check( EXPORTING id     = `CSP_HOSTS`
                           status = temp18
                           title  = `Script hosts limited`
                           value  = temp6
                           text   = `Every allowed script host is a host whose compromise is script execution ` &&
                                    `in an authenticated SAP session.`
                           fix    = `Allow only the UI5 hosts (or your own) in script-src.`
                 CHANGING  checks = result ).
    ENDIF.


    CLEAR temp19.
    INSERT `x-content-type-options` INTO TABLE temp19.
    INSERT `x-frame-options` INTO TABLE temp19.
    INSERT `referrer-policy` INTO TABLE temp19.
    INSERT `permissions-policy` INTO TABLE temp19.

    lt_expected = temp19.

    LOOP AT lt_expected INTO lv_expected.
      IF header_value( headers = ls_get-t_security_header
                       name    = lv_expected ) IS INITIAL.
        lv_missing = |{ lv_missing } { lv_expected }|.
      ENDIF.
    ENDLOOP.

    IF lv_missing IS INITIAL.
      temp21 = cs_status-ok.
    ELSE.
      temp21 = cs_status-warn.
    ENDIF.

    IF lv_missing IS INITIAL.
      temp7 = `set`.
    ELSE.
      temp7 = |missing:{ lv_missing }|.
    ENDIF.
    add_check( EXPORTING id     = `HEADERS`
                         status = temp21
                         title  = `Security headers`
                         value  = temp7
                         text   = `nosniff, frame protection, referrer and permissions policy are set by the ` &&
                                  `framework's defaults; an exit that replaces t_security_header can lose them.`
                         fix    = `APPEND to cs_config-t_security_header in your user exit instead of replacing it.`
               CHANGING  checks = result ).


    lv_hsts = header_value( headers = ls_get-t_security_header
                                  name    = `strict-transport-security` ).

    IF lv_hsts IS INITIAL.
      temp22 = cs_status-info.
    ELSE.
      temp22 = cs_status-ok.
    ENDIF.

    IF lv_hsts IS INITIAL.
      temp8 = `not set`.
    ELSE.
      temp8 = lv_hsts.
    ENDIF.
    add_check( EXPORTING id     = `HSTS`
                         status = temp22
                         title  = `Strict-Transport-Security`
                         value  = temp8
                         text   = `Not set by default on purpose: many on-premise systems serve plain HTTP. ` &&
                                  `Served over HTTPS, it belongs to the TLS terminator or the exit.`
                         fix    = `HTTPS only: APPEND VALUE #( n = 'Strict-Transport-Security' v = 'max-age=31536000' ) ` &&
                                  `TO cs_config-t_security_header.`
               CHANGING  checks = result ).


    lv_src = to_lower( ls_get-src ).


    temp12 = boolc( lv_src CS `openui5.org` OR lv_src CS `ui5.sap.com` OR lv_src CS `hana.ondemand.com` ).
    lv_cdn = temp12.

    IF lv_cdn = abap_true.
      temp23 = cs_status-info.
    ELSE.
      temp23 = cs_status-ok.
    ENDIF.

    IF lv_cdn = abap_true.
      temp9 = `UI5 loads from a public CDN: every browser needs internet access ` && `and the page trusts that host.`.
    ELSE.
      temp9 = `UI5 loads from a host of your own.`.
    ENDIF.

    IF lv_cdn = abap_true.
      temp10 = `Optional: serve UI5 from your system (/sap/public/bc/ui5_ui5/) and set ` && `cs_config-src in set_config_http_get.`.
    ELSE.
      CLEAR temp10.
    ENDIF.
    add_check( EXPORTING id     = `BOOTSTRAP`
                         status = temp23
                         title  = `UI5 bootstrap`
                         value  = ls_get-src
                         text   = temp9
                         fix    = temp10
               CHANGING  checks = result ).


    IF ls_post-draft_exp_time_in_hours > 24.
      temp24 = cs_status-warn.
    ELSE.
      temp24 = cs_status-ok.
    ENDIF.
    add_check( EXPORTING id     = `EXPIRY`
                         status = temp24
                         title  = `Draft expiry`
                         value  = |{ ls_post-draft_exp_time_in_hours } hours|
                         text   = `Drafts hold the serialized app state of every user. A long expiry keeps ` &&
                                  `business data in the draft table and lets it grow.`
                         fix    = `Set cs_config-draft_exp_time_in_hours in set_config_http_post (default 4).`
               CHANGING  checks = result ).


    LOOP AT result ASSIGNING <check>.
      <check>-icon = check_icon( <check>-status ).
    ENDLOOP.

  ENDMETHOD.

  METHOD checks_cockpit.

    DATA lv_dev TYPE string.
    DATA temp25 TYPE z2ui5_cl_cockpit_inst=>ty_t_addon.
    DATA ls_addon LIKE LINE OF temp25.
      DATA temp26 TYPE string.
    DATA temp27 TYPE string.
    DATA temp10 TYPE string.
    DATA lv_auth_mode TYPE string.
    DATA temp28 TYPE string.
    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA temp29 TYPE string.
    DATA lv_recorded TYPE i.
    DATA temp30 TYPE string.
    DATA temp11 TYPE string.
    temp25 = get_addons( ).

    LOOP AT temp25 INTO ls_addon WHERE installed = abap_true AND kind = `developer tool`. "#EC CI_SORTSEQ

      IF lv_dev IS NOT INITIAL.
        temp26 = `, `.
      ELSE.
        CLEAR temp26.
      ENDIF.
      lv_dev = |{ lv_dev }{ temp26 }{ ls_addon-name }|.
    ENDLOOP.

    IF lv_dev IS INITIAL.
      temp27 = cs_status-ok.
    ELSE.
      temp27 = cs_status-error.
    ENDIF.

    IF lv_dev IS INITIAL.
      temp10 = `none installed`.
    ELSE.
      temp10 = lv_dev.
    ENDIF.
    add_check( EXPORTING id     = `DEV_ADDONS`
                         status = temp27
                         title  = `Developer addons reachable`
                         value  = temp10
                         text   = `Any user who can reach the abap2UI5 ICF node can start any installed app class. ` &&
                                  `SQL consoles, table browsers and SE80-like tools read and change data.`
                         fix    = `Do not install them in production, or restrict them: an authorization check ` &&
                                  `in your user exit / ICF node (allowed apps per role).`
               CHANGING  checks = checks ).


    lv_auth_mode = z2ui5_cl_cockpit_auth=>get_mode( ).

    IF lv_auth_mode = z2ui5_cl_cockpit_auth=>cs_mode-claim.
      temp28 = cs_status-error.
    ELSE.
      temp28 = cs_status-ok.
    ENDIF.
    add_check( EXPORTING id     = `COCKPIT_AUTH`
                         status = temp28
                         title  = `Admin cockpit restricted`
                         value  = z2ui5_cl_cockpit_auth=>get_mode_text( )
                         text   = `The cockpit shows usage and configuration of the whole system. Without an ` &&
                                  `administrator it shows only the claim screen - to whoever opens it first.`
                         fix    = `Claim the administrator role right after the installation and maintain the ` &&
                                  `administrators on the Settings tab, or implement z2ui5_if_cockpit_auth.`
               CHANGING  checks = checks ).


    ls_set = z2ui5_cl_cockpit_setup=>get( ).

    IF ls_set-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-name.
      temp29 = cs_status-warn.
    ELSE.
      temp29 = cs_status-ok.
    ENDIF.
    add_check( EXPORTING id     = `PRIVACY`
                         status = temp29
                         title  = `Monitor privacy mode`
                         value  = ls_set-user_tracking
                         text   = `HASH counts users under a pseudonym that changes every day, NONE does not ` &&
                                  `count users, NAME stores user names (performance and behaviour monitoring ` &&
                                  `may require works council approval).`
                         fix    = `Settings tab: user tracking HASH or NONE.`
               CHANGING  checks = checks ).

    " the recorder keeps whole requests and responses - what users typed and saw

    lv_recorded = z2ui5_cl_cockpit_wire=>count_records( ).

    IF ls_set-wire_days > 7.
      temp30 = cs_status-warn.
    ELSEIF ls_set-wire_days > 0 AND lv_recorded = 0.
      temp30 = cs_status-info.
    ELSE.
      temp30 = cs_status-ok.
    ENDIF.

    IF ls_set-wire_days <= 0.
      temp11 = `off`.
    ELSEIF lv_recorded = 0.
      temp11 = |no recording today, kept { ls_set-wire_days } days|.
    ELSE.
      temp11 = |{ lv_recorded } today, kept { ls_set-wire_days } days|.
    ENDIF.
    add_check( EXPORTING id     = `RECORDER`
                         status = temp30
                         title  = `Recorder of requests and responses`
                         value  = temp11
                         text   = `Stores the complete request and response of each roundtrip - the values users ` &&
                                  `typed, the messages and screens they saw - for the screen playback, the process ` &&
                                  `variants and the messages users saw; the same line feeds the usage, error and ` &&
                                  `performance tabs on every abap2UI5 release. Records once your own HTTP handler ` &&
                                  `class calls the cockpit.`
                         fix    = `SICF, the service of your installation (e.g. /sap/bc/z2ui5), tab Handler List: ` &&
                                  `in that class, method if_http_extension~handle_request, replace ` &&
                                  `z2ui5_cl_ui5_http_handler=>run( server ) (older: z2ui5_cl_http_handler=>run) by ` &&
                                  `z2ui5_cl_cockpit_wire=>run( server ). ABAP Cloud: the handler class of your HTTP ` &&
                                  `service, if_http_service_extension~handle_request, run( req = request res = ` &&
                                  `response ). Only once the cockpit is active - the line runs in every app. Settings ` &&
                                  `tab: retention in days, 0 switches the recording of bodies off; keep it short.`
               CHANGING  checks = checks ).

  ENDMETHOD.

  METHOD get_addons.

    DATA lv_error TYPE string.

    DATA temp31 TYPE z2ui5_cl_cockpit_inst=>ty_t_addon.
    DATA temp32 LIKE LINE OF temp31.
    FIELD-SYMBOLS <addon> LIKE LINE OF result.
        DATA temp33 TYPE z2ui5_cl_cockpit_inst=>ty_s_addon-state.
    CLEAR temp31.

    CLEAR temp32.
    temp32-name = `popups`.
    temp32-marker = `CL_POPUP_CONTEXT`.
    temp32-kind = `library`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `layout-management`.
    temp32-marker = `CL_LAYO_MANAGER`.
    temp32-kind = `library`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `range-filter`.
    temp32-marker = `CL_SEL_MULTISEL`.
    temp32-kind = `library`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `abap-cloud-gui`.
    temp32-marker = `CL_CGUI_CONTEXT`.
    temp32-kind = `library`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `custom-controls`.
    temp32-marker = `CL_CCI`.
    temp32-kind = `library`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `custom-controls-customer`.
    temp32-marker = `CL_CCC`.
    temp32-kind = `library`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `lock-manager`.
    temp32-marker = `CL_LOCK_MANAGER`.
    temp32-kind = `library`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `config-management`.
    temp32-marker = `CL_CONFIG_SERVICE`.
    temp32-kind = `library`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `rap-ext`.
    temp32-marker = `CL_RAP_UTIL`.
    temp32-kind = `library`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `open-source-libs`.
    temp32-marker = `CL_OSL_VALIDATOR`.
    temp32-kind = `library`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `launchpad-kpi`.
    temp32-marker = `CL_LP_KPI_HELLO_WORLD`.
    temp32-kind = `library`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `headless-frontend`.
    temp32-marker = `CL_FRONTEND_SIM`.
    temp32-kind = `test tool`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `abap-agent-runtime`.
    temp32-marker = `CL_AGENT_SETTINGS`.
    temp32-kind = `agent endpoint`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `http-connector`.
    temp32-marker = `CL_HTTP_CON_HANDLER`.
    temp32-kind = `connector`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `rfc-connector`.
    temp32-marker = `CL_RFC_CONNECTOR_HANDLER`.
    temp32-kind = `connector`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `sql-console`.
    temp32-marker = `CL_SQL_APP_01`.
    temp32-kind = `developer tool`.
    temp32-marker_old = `SQL_CL_APP_01`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `se16n`.
    temp32-marker = `CL_SE16_CONTEXT`.
    temp32-kind = `developer tool`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `table-maintenance`.
    temp32-marker = `CL_TM_001`.
    temp32-kind = `developer tool`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `table-content-loader`.
    temp32-marker = `CL_TCL_CONTEXT`.
    temp32-kind = `developer tool`.
    INSERT temp32 INTO TABLE temp31.
    CLEAR temp32.
    temp32-name = `sapgui (SE80, SE38, SE16N, ...)`.
    temp32-marker = `ZCL_SAPGUI_A2UI5`.
    temp32-kind = `developer tool`.
    INSERT temp32 INTO TABLE temp31.
    result = temp31.


    LOOP AT result ASSIGNING <addon>.
      IF <addon>-marker CP `CL_*`.
        <addon>-marker = obj_name( <addon>-marker ).
      ENDIF.
      IF <addon>-marker_old IS NOT INITIAL.
        <addon>-marker_old = obj_name( <addon>-marker_old ).
      ENDIF.
      <addon>-url = |https://github.com/abap2UI5-addons/{ segment( val   = <addon>-name
                                                                    index = 1
                                                                    sep   = ` ` ) }|.
      describe( EXPORTING name  = <addon>-marker
                IMPORTING found = <addon>-installed
                          error = lv_error ).
      IF <addon>-installed = abap_false AND lv_error IS INITIAL AND <addon>-marker_old IS NOT INITIAL.
        describe( EXPORTING name  = <addon>-marker_old
                  IMPORTING found = <addon>-installed
                            error = lv_error ).
      ENDIF.
      IF <addon>-installed = abap_true.
        <addon>-status = `installed`.

        IF <addon>-kind = `developer tool`.
          temp33 = cs_status-error.
        ELSE.
          temp33 = cs_status-ok.
        ENDIF.
        <addon>-state = temp33.
        CASE <addon>-kind.
          WHEN `developer tool`.
            <addon>-note = `Reachable for every user of the ICF node unless restricted.`.
          WHEN `agent endpoint`.
            <addon>-note = `MCP endpoint for AI agents - see the Agents tab and the traffic light.`.
          WHEN `test tool`.
            <addon>-note = `Enables Reproduce on the Errors tab.`.
        ENDCASE.
      ELSEIF lv_error IS NOT INITIAL.
        <addon>-status = `installed, cannot be loaded`.
        <addon>-state = cs_status-error.
        <addon>-note = |{ <addon>-marker }: { lv_error } - check the addon's objects for syntax errors.|.
      ELSE.
        <addon>-status = `not installed`.
        <addon>-state = `None`.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_exit.

    " exactly what the framework does per request: one instance per roll
    " area, holding the defaults and the user exit it found
    DATA lv_class TYPE string.
    lv_class = obj_name( `CL_UI5_USER_EXIT` ).
    CALL METHOD (lv_class)=>(`GET_INSTANCE`)
      RECEIVING
        result = result.
    IF result IS NOT BOUND.
      RAISE EXCEPTION TYPE cx_sy_ref_is_initial.
    ENDIF.

  ENDMETHOD.

  METHOD get_config_get.

    DATA temp1 TYPE REF TO z2ui5_if_ui5_exit.
    temp1 = get_exit( ).
    temp1->set_config_http_get( CHANGING cs_config = result ).

  ENDMETHOD.

  METHOD get_config_post.
        DATA temp1 TYPE REF TO z2ui5_if_ui5_exit.

    TRY.

        temp1 = get_exit( ).
        temp1->set_config_http_post( CHANGING cs_config = result ).
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.

  METHOD get_user_exit_class.

    DATA lv_class TYPE string.
    lv_class = obj_name( `CL_UI5_USER_EXIT` ).
    TRY.
        CALL METHOD (lv_class)=>(`GET_USER_EXIT_CLASS`)
          RECEIVING
            result = result.
      CATCH cx_root.
        result = `(unknown - framework internals changed)`.
    ENDTRY.

  ENDMETHOD.

  METHOD check_cloud.

    " T100 is not released for ABAP Cloud - the same probe the framework uses
    DATA temp13 TYPE xsdboolean.
    temp13 = boolc( check_type_exists( `T100` ) = abap_false ).
    result = temp13.

  ENDMETHOD.

  METHOD check_class_exists.

    describe( EXPORTING name  = name
              IMPORTING found = result ).

  ENDMETHOD.

  METHOD describe.
        DATA temp14 TYPE xsdboolean.
        DATA lx TYPE REF TO cx_root.

    CLEAR: found,
           error.
    TRY.
        cl_abap_typedescr=>describe_by_name( EXPORTING  p_name         = name
                                             EXCEPTIONS type_not_found = 1
                                                        OTHERS         = 2 ).

        temp14 = boolc( sy-subrc = 0 ).
        found = temp14.

      CATCH cx_root INTO lx.
        " the class exists but cannot be loaded, e.g. a syntax error in an
        " installed addon - it must not take the whole tab down
        error = lx->get_text( ).
        IF error IS INITIAL.
          error = `cannot be loaded`.
        ENDIF.
    ENDTRY.

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
    TYPES temp1 TYPE STANDARD TABLE OF ty_s_class WITH DEFAULT KEY.
DATA lt_classes TYPE temp1.

    DATA lv_class TYPE string.
    DATA ls_class LIKE LINE OF lt_classes.
    lv_class = obj_name( `CL_UI5_UTIL_CONTEXT` ).
    TRY.
        CALL METHOD (lv_class)=>(`RTTI_GET_CLASSES_IMPL_INTF`)
          EXPORTING
            val    = intf
          RECEIVING
            result = lt_classes.
      CATCH cx_root.
        RETURN.
    ENDTRY.


    LOOP AT lt_classes INTO ls_class.
      APPEND to_upper( ls_class-classname ) TO result.
    ENDLOOP.
    SORT result BY table_line.
    DELETE ADJACENT DUPLICATES FROM result COMPARING table_line.

  ENDMETHOD.

  METHOD csp_directive.

    DATA lv_off TYPE i.
    lv_off = find( val = csp
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

    DATA temp34 TYPE z2ui5_cl_cockpit_inst=>ty_s_check.
    CLEAR temp34.
    temp34-id = id.
    temp34-status = status.
    temp34-title = title.
    temp34-value = value.
    temp34-text = text.
    temp34-fix = fix.
    APPEND temp34 TO checks.

  ENDMETHOD.

  METHOD header_value.

    DATA ls_header LIKE LINE OF headers.
    LOOP AT headers INTO ls_header.
      IF to_lower( ls_header-n ) = name.
        result = ls_header-v.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD obj_name.

    DATA lr_self TYPE REF TO z2ui5_cl_cockpit_inst.
    DATA lo_ref TYPE REF TO cl_abap_refdescr.

    IF gv_prefix IS INITIAL.
      " this class's own name, which a rename carries along, minus the part
      " after the prefix
      lo_ref ?= cl_abap_typedescr=>describe_by_data( lr_self ).
      gv_prefix = lo_ref->get_referenced_type( )->get_relative_name( ).
      gv_prefix = substring( val = gv_prefix
                             len = strlen( gv_prefix ) - strlen( `CL_COCKPIT_INST` ) ).
    ENDIF.
    result = gv_prefix && to_upper( val ).

  ENDMETHOD.

ENDCLASS.
