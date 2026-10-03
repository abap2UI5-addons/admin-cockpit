"! The security traffic light, evaluated from given configuration
"! structures - the framework is not asked.
CLASS ltcl_checks DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    DATA ms_get TYPE z2ui5_if_ui5_exit=>ty_s_http_config.
    DATA ms_post TYPE z2ui5_if_ui5_exit=>ty_s_http_config_post.

    METHODS setup.

    METHODS secure_config_is_green FOR TESTING.
    METHODS csrf_off FOR TESTING.
    METHODS error_details_shown FOR TESTING.
    METHODS csp_unsafe_eval FOR TESTING.
    METHODS csp_unsafe_inline FOR TESTING.
    METHODS csp_missing FOR TESTING.
    METHODS csp_in_header_counts FOR TESTING.
    METHODS csp_wildcard_host FOR TESTING.
    METHODS headers_missing FOR TESTING.
    METHODS long_expiry FOR TESTING.
    METHODS agent_not_installed FOR TESTING.
    METHODS agent_disabled FOR TESTING.
    METHODS agent_without_admin FOR TESTING.
    METHODS agent_allows_all FOR TESTING.
    METHODS agent_without_apps FOR TESTING.
    METHODS agent_set_up FOR TESTING.

    METHODS check
      IMPORTING
        id            TYPE string
        it_check      TYPE z2ui5_cl_cockpit_inst=>ty_t_check OPTIONAL
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cockpit_inst=>ty_s_check.

ENDCLASS.


CLASS ltcl_checks IMPLEMENTATION.

  METHOD setup.

    " what the framework's defaults amount to, served from the own host
    ms_get-src = `/sap/public/bc/ui5_ui5/resources/sap-ui-core.js`.
    ms_get-content_security_policy = `<meta http-equiv="Content-Security-Policy" content="default-src 'self'; ` &&
                                     `script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'">`.
    ms_get-t_security_header = VALUE #( ( n = `X-Content-Type-Options`    v = `nosniff` )
                                        ( n = `X-Frame-Options`           v = `SAMEORIGIN` )
                                        ( n = `Referrer-Policy`           v = `strict-origin-when-cross-origin` )
                                        ( n = `Permissions-Policy`        v = `camera=()` )
                                        ( n = `Strict-Transport-Security` v = `max-age=31536000` ) ).
    ms_post-check_csrf_active          = abap_true.
    ms_post-check_hide_error_details   = abap_true.
    ms_post-check_trust_forwarded_host = abap_false.
    ms_post-draft_exp_time_in_hours    = 4.

  ENDMETHOD.

  METHOD check.

    DATA(lt_check) = it_check.
    IF lt_check IS INITIAL.
      lt_check = z2ui5_cl_cockpit_inst=>evaluate_config( is_get  = ms_get
                                                         is_post = ms_post ).
    ENDIF.
    result = VALUE #( lt_check[ id = id ] OPTIONAL ). "#EC CI_SORTSEQ

  ENDMETHOD.

  METHOD secure_config_is_green.

    DATA(lt_check) = z2ui5_cl_cockpit_inst=>evaluate_config( is_get  = ms_get
                                                             is_post = ms_post ).
    LOOP AT lt_check INTO DATA(ls_check).
      cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-ok
                                          act = ls_check-status
                                          msg = |{ ls_check-id }: { ls_check-value }| ).
      cl_abap_unit_assert=>assert_equals( exp = `sap-icon://status-positive`
                                          act = ls_check-icon ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( exp = 10
                                        act = lines( lt_check ) ).

  ENDMETHOD.

  METHOD csrf_off.

    ms_post-check_csrf_active = abap_false.
    DATA(ls_check) = check( `CSRF` ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-error
                                        act = ls_check-status ).
    cl_abap_unit_assert=>assert_equals( exp = `off`
                                        act = ls_check-value ).

  ENDMETHOD.

  METHOD error_details_shown.

    ms_post-check_hide_error_details = abap_false.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-warn
                                        act = check( `ERROR_DETAILS` )-status ).

  ENDMETHOD.

  METHOD csp_unsafe_eval.

    REPLACE `script-src 'self'` IN ms_get-content_security_policy WITH `script-src 'self' 'unsafe-eval'`.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-warn
                                        act = check( `CSP_EVAL` )-status ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-ok
                                        act = check( `CSP_INLINE` )-status ).

  ENDMETHOD.

  METHOD csp_unsafe_inline.

    " 'unsafe-inline' in style-src is fine, in script-src it is not
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-ok
                                        act = check( `CSP_INLINE` )-status ).
    REPLACE `script-src 'self'` IN ms_get-content_security_policy WITH `script-src 'self' 'unsafe-inline'`.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-error
                                        act = check( `CSP_INLINE` )-status ).

  ENDMETHOD.

  METHOD csp_missing.

    CLEAR ms_get-content_security_policy.
    DATA(lt_check) = z2ui5_cl_cockpit_inst=>evaluate_config( is_get  = ms_get
                                                             is_post = ms_post ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-error
                                        act = check( id       = `CSP`
                                                     it_check = lt_check )-status ).
    cl_abap_unit_assert=>assert_initial( check( id       = `CSP_EVAL`
                                                it_check = lt_check ) ).

  ENDMETHOD.

  METHOD csp_in_header_counts.

    CLEAR ms_get-content_security_policy.
    APPEND VALUE #( n = `Content-Security-Policy`
                    v = `default-src 'self'; script-src 'self' 'unsafe-eval'` ) TO ms_get-t_security_header.
    DATA(lt_check) = z2ui5_cl_cockpit_inst=>evaluate_config( is_get  = ms_get
                                                             is_post = ms_post ).
    cl_abap_unit_assert=>assert_initial( check( id       = `CSP`
                                                it_check = lt_check ) ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-warn
                                        act = check( id       = `CSP_EVAL`
                                                     it_check = lt_check )-status ).

  ENDMETHOD.

  METHOD csp_wildcard_host.

    REPLACE `script-src 'self'` IN ms_get-content_security_policy WITH `script-src 'self' https://cdn.jsdelivr.net`.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-warn
                                        act = check( `CSP_HOSTS` )-status ).

  ENDMETHOD.

  METHOD headers_missing.

    DELETE ms_get-t_security_header WHERE n = `X-Frame-Options`.
    DATA(ls_check) = check( `HEADERS` ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-warn
                                        act = ls_check-status ).
    cl_abap_unit_assert=>assert_equals( exp = `missing: x-frame-options`
                                        act = ls_check-value ).

  ENDMETHOD.

  METHOD long_expiry.

    ms_post-draft_exp_time_in_hours = 48.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-warn
                                        act = check( `EXPIRY` )-status ).

  ENDMETHOD.

  METHOD agent_not_installed.

    DATA ls_agent TYPE z2ui5_cl_cockpit_agent=>ty_s_setup.
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_inst=>evaluate_agent( ls_agent ) ).

  ENDMETHOD.

  METHOD agent_disabled.

    DATA(ls_agent) = VALUE z2ui5_cl_cockpit_agent=>ty_s_setup( installed = abap_true
                                                               readable  = abap_true ).
    DATA(lt_check) = z2ui5_cl_cockpit_inst=>evaluate_agent( ls_agent ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-ok
                                        act = check( id       = `AGENT`
                                                     it_check = lt_check )-status ).

  ENDMETHOD.

  METHOD agent_without_admin.

    DATA(ls_agent) = VALUE z2ui5_cl_cockpit_agent=>ty_s_setup( installed = abap_true
                                                               readable  = abap_true
                                                               enabled   = abap_true
                                                               opted_in  = 3 ).
    DATA(lt_check) = z2ui5_cl_cockpit_inst=>evaluate_agent( ls_agent ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-error
                                        act = check( id       = `AGENT`
                                                     it_check = lt_check )-status ).

  ENDMETHOD.

  METHOD agent_allows_all.

    DATA(ls_agent) = VALUE z2ui5_cl_cockpit_agent=>ty_s_setup( installed = abap_true
                                                               readable  = abap_true
                                                               enabled   = abap_true
                                                               admins    = 1
                                                               app_rules = 1
                                                               allow_all = abap_true ).
    DATA(lt_check) = z2ui5_cl_cockpit_inst=>evaluate_agent( ls_agent ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-warn
                                        act = check( id       = `AGENT`
                                                     it_check = lt_check )-status ).

  ENDMETHOD.

  METHOD agent_without_apps.

    DATA(ls_agent) = VALUE z2ui5_cl_cockpit_agent=>ty_s_setup( installed = abap_true
                                                               readable  = abap_true
                                                               enabled   = abap_true
                                                               admins    = 1 ).
    DATA(lt_check) = z2ui5_cl_cockpit_inst=>evaluate_agent( ls_agent ).
    DATA(ls_check) = check( id       = `AGENT`
                            it_check = lt_check ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-warn
                                        act = ls_check-status ).
    cl_abap_unit_assert=>assert_equals( exp = `enabled, no app reachable`
                                        act = ls_check-value ).

  ENDMETHOD.

  METHOD agent_set_up.

    DATA(ls_agent) = VALUE z2ui5_cl_cockpit_agent=>ty_s_setup( installed = abap_true
                                                               readable  = abap_true
                                                               enabled   = abap_true
                                                               admins    = 2
                                                               opted_in  = 1 ).
    DATA(lt_check) = z2ui5_cl_cockpit_inst=>evaluate_agent( ls_agent ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_inst=>cs_status-info
                                        act = check( id       = `AGENT`
                                                     it_check = lt_check )-status ).

  ENDMETHOD.

ENDCLASS.
