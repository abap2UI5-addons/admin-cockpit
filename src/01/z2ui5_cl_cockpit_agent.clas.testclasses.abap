"! The figures of the Agents tab from given settings and audit rows - the
"! agent addon itself is not needed.
CLASS ltcl_agent DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    METHODS setup_of_settings FOR TESTING.
    METHODS setup_of_nothing FOR TESTING.
    METHODS classify_outcomes FOR TESTING.
    METHODS aggregate_rows FOR TESTING.
    METHODS aggregate_respects_privacy FOR TESTING.

    METHODS rows
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cockpit_agent=>ty_t_row.

ENDCLASS.


CLASS ltcl_agent IMPLEMENTATION.

  METHOD rows.

    " newest first, as the SELECT delivers them
    result = VALUE #( ( timestampl = '20990102090000'
                        uname      = `ALICE`
                        app        = `ZCL_ORDERS`
                        operation  = `app_act`
                        event      = `POST`
                        outcome    = `error`
                        text       = `event POST (b1 "Post") needs a human - agents never fire it`
                        mcp_client = `ide-agent 2.1` )
                      ( timestampl = '20990102080000'
                        uname      = `ALICE`
                        app        = `ZCL_ORDERS`
                        operation  = `app_act`
                        event      = `SAVE`
                        outcome    = `error`
                        text       = `no field 'QTY' on this screen`
                        mcp_client = `ide-agent 2.1` )
                      ( timestampl = '20990101170000'
                        uname      = `BOB`
                        app        = `ZCL_STOCK`
                        operation  = `app_start`
                        outcome    = `ok`
                        mcp_client = `other-agent 1.0` )
                      ( timestampl = '20990101160000'
                        uname      = `ALICE`
                        app        = `ZCL_ORDERS`
                        operation  = `app_start`
                        outcome    = `ok`
                        mcp_client = `ide-agent 2.1` ) ).

  ENDMETHOD.

  METHOD setup_of_settings.

    DATA(lt_set) = VALUE z2ui5_cl_cockpit_agent=>ty_t_set( ( kind = `ENABLED` app = `*` value = `X` )
                                                           ( kind = `ADMIN` app = `ALICE` )
                                                           ( kind = `ADMIN` app = `BOB` )
                                                           ( kind = `APP` app = `ZCL_ORDERS` value = `allow` )
                                                           ( kind = `APP` app = `ZCL_SECRET*` value = `deny` )
                                                           ( kind = `EVENT` app = `ZCL_ORDERS` item = `POST`
                                                             value = `confirm` ) ).
    DATA(ls_setup) = z2ui5_cl_cockpit_agent=>setup_of( lt_set ).
    cl_abap_unit_assert=>assert_true( ls_setup-enabled ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_setup-admins ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_setup-app_rules ).
    cl_abap_unit_assert=>assert_false( ls_setup-allow_all ).

    APPEND VALUE #( kind  = `APP`
                    app   = `*`
                    value = `allow` ) TO lt_set.
    cl_abap_unit_assert=>assert_true( z2ui5_cl_cockpit_agent=>setup_of( lt_set )-allow_all ).

  ENDMETHOD.

  METHOD setup_of_nothing.

    " no rows: the addon's default - disabled
    DATA lt_set TYPE z2ui5_cl_cockpit_agent=>ty_t_set.
    DATA(ls_setup) = z2ui5_cl_cockpit_agent=>setup_of( lt_set ).
    cl_abap_unit_assert=>assert_false( ls_setup-enabled ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = ls_setup-admins ).

  ENDMETHOD.

  METHOD classify_outcomes.

    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_agent=>cs_kind-ok
                                        act = z2ui5_cl_cockpit_agent=>classify( outcome = `ok`
                                                                                text    = `` ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = z2ui5_cl_cockpit_agent=>cs_kind-policy
        act = z2ui5_cl_cockpit_agent=>classify( outcome = `error`
                                                text    = `event DEL (b2 "Delete") is forbidden for agents - app` ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = z2ui5_cl_cockpit_agent=>cs_kind-policy
        act = z2ui5_cl_cockpit_agent=>classify( outcome = `error`
                                                text    = `ZCL_X is not enabled for agents - the app implements ...` ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = z2ui5_cl_cockpit_agent=>cs_kind-policy
        act = z2ui5_cl_cockpit_agent=>classify( outcome = `error`
                                                text    = `the abap2UI5 agent endpoint is disabled on this system` ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = z2ui5_cl_cockpit_agent=>cs_kind-validation
        act = z2ui5_cl_cockpit_agent=>classify( outcome = `error`
                                                text    = `QTY holds a number - "ten" is none` ) ).

  ENDMETHOD.

  METHOD aggregate_rows.

    DATA(ls_info) = z2ui5_cl_cockpit_agent=>aggregate( it_row  = rows( )
                                                       days    = 3
                                                       last    = 3
                                                       today   = `20990102`
                                                       privacy = abap_false ).

    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = ls_info-calls ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_info-policy ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_info-validation ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_info-users ).

    " three days, newest first; the third has no call
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( ls_info-t_day ) ).
    cl_abap_unit_assert=>assert_equals( exp = `2099-01-02`
                                        act = ls_info-t_day[ 1 ]-day ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_info-t_day[ 1 ]-calls ).
    cl_abap_unit_assert=>assert_equals( exp = 100
                                        act = ls_info-t_day[ 1 ]-bar ).
    cl_abap_unit_assert=>assert_equals( exp = `Warning`
                                        act = ls_info-t_day[ 1 ]-state ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_info-t_day[ 2 ]-calls ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = ls_info-t_day[ 3 ]-calls ).

    " per app and per client, most calls first
    cl_abap_unit_assert=>assert_equals( exp = `ZCL_ORDERS`
                                        act = ls_info-t_app[ 1 ]-name ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = ls_info-t_app[ 1 ]-calls ).
    cl_abap_unit_assert=>assert_equals( exp = `2099-01-02 09:00:00`
                                        act = ls_info-t_app[ 1 ]-last ).
    cl_abap_unit_assert=>assert_equals( exp = `ide-agent 2.1`
                                        act = ls_info-t_client[ 1 ]-name ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( ls_info-t_client ) ).

    " the last entries, capped
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( ls_info-t_last ) ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_agent=>cs_kind-policy
                                        act = ls_info-t_last[ 1 ]-kind ).
    cl_abap_unit_assert=>assert_equals( exp = `ALICE`
                                        act = ls_info-t_last[ 1 ]-user ).

  ENDMETHOD.

  METHOD aggregate_respects_privacy.

    DATA(ls_info) = z2ui5_cl_cockpit_agent=>aggregate( it_row = rows( )
                                                       days   = 1
                                                       today  = `20990102` ).
    LOOP AT ls_info-t_last INTO DATA(ls_entry).
      cl_abap_unit_assert=>assert_equals( exp = `(hidden)`
                                          act = ls_entry-user ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = lines( ls_info-t_last ) ).

  ENDMETHOD.

ENDCLASS.
