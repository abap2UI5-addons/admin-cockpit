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
    DATA temp1 TYPE z2ui5_cl_cockpit_agent=>ty_t_row.
    DATA temp2 LIKE LINE OF temp1.
    CLEAR temp1.

    CLEAR temp2.
    temp2-timestampl = '20990102090000'.
    temp2-uname = `ALICE`.
    temp2-app = `ZCL_ORDERS`.
    temp2-operation = `app_act`.
    temp2-event = `POST`.
    temp2-outcome = `error`.
    temp2-text = `event POST (b1 "Post") needs a human - agents never fire it`.
    temp2-mcp_client = `ide-agent 2.1`.
    INSERT temp2 INTO TABLE temp1.
    CLEAR temp2.
    temp2-timestampl = '20990102080000'.
    temp2-uname = `ALICE`.
    temp2-app = `ZCL_ORDERS`.
    temp2-operation = `app_act`.
    temp2-event = `SAVE`.
    temp2-outcome = `error`.
    temp2-text = `no field 'QTY' on this screen`.
    temp2-mcp_client = `ide-agent 2.1`.
    INSERT temp2 INTO TABLE temp1.
    CLEAR temp2.
    temp2-timestampl = '20990101170000'.
    temp2-uname = `BOB`.
    temp2-app = `ZCL_STOCK`.
    temp2-operation = `app_start`.
    temp2-outcome = `ok`.
    temp2-mcp_client = `other-agent 1.0`.
    INSERT temp2 INTO TABLE temp1.
    CLEAR temp2.
    temp2-timestampl = '20990101160000'.
    temp2-uname = `ALICE`.
    temp2-app = `ZCL_ORDERS`.
    temp2-operation = `app_start`.
    temp2-outcome = `ok`.
    temp2-mcp_client = `ide-agent 2.1`.
    INSERT temp2 INTO TABLE temp1.
    result = temp1.

  ENDMETHOD.

  METHOD setup_of_settings.

    DATA temp3 TYPE z2ui5_cl_cockpit_agent=>ty_t_set.
    DATA temp4 LIKE LINE OF temp3.
    DATA lt_set LIKE temp3.
    DATA ls_setup TYPE z2ui5_cl_cockpit_agent=>ty_s_setup.
    DATA temp5 TYPE z2ui5_cl_cockpit_agent=>ty_s_set.
    CLEAR temp3.

    CLEAR temp4.
    temp4-kind = `ENABLED`.
    temp4-app = `*`.
    temp4-value = `X`.
    INSERT temp4 INTO TABLE temp3.
    CLEAR temp4.
    temp4-kind = `ADMIN`.
    temp4-app = `ALICE`.
    INSERT temp4 INTO TABLE temp3.
    CLEAR temp4.
    temp4-kind = `ADMIN`.
    temp4-app = `BOB`.
    INSERT temp4 INTO TABLE temp3.
    CLEAR temp4.
    temp4-kind = `APP`.
    temp4-app = `ZCL_ORDERS`.
    temp4-value = `allow`.
    INSERT temp4 INTO TABLE temp3.
    CLEAR temp4.
    temp4-kind = `APP`.
    temp4-app = `ZCL_SECRET*`.
    temp4-value = `deny`.
    INSERT temp4 INTO TABLE temp3.
    CLEAR temp4.
    temp4-kind = `EVENT`.
    temp4-app = `ZCL_ORDERS`.
    temp4-item = `POST`.
    temp4-value = `confirm`.
    INSERT temp4 INTO TABLE temp3.

    lt_set = temp3.

    ls_setup = z2ui5_cl_cockpit_agent=>setup_of( lt_set ).
    cl_abap_unit_assert=>assert_true( ls_setup-enabled ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_setup-admins ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_setup-app_rules ).
    cl_abap_unit_assert=>assert_false( ls_setup-allow_all ).


    CLEAR temp5.
    temp5-kind = `APP`.
    temp5-app = `*`.
    temp5-value = `allow`.
    APPEND temp5 TO lt_set.
    cl_abap_unit_assert=>assert_true( z2ui5_cl_cockpit_agent=>setup_of( lt_set )-allow_all ).

  ENDMETHOD.

  METHOD setup_of_nothing.

    " no rows: the addon's default - disabled
    DATA lt_set TYPE z2ui5_cl_cockpit_agent=>ty_t_set.
    DATA ls_setup TYPE z2ui5_cl_cockpit_agent=>ty_s_setup.
    ls_setup = z2ui5_cl_cockpit_agent=>setup_of( lt_set ).
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
        exp = z2ui5_cl_cockpit_agent=>cs_kind-policy
        act = z2ui5_cl_cockpit_agent=>classify( outcome = `error`
                                                text    = `ZCL_X is denied for agents by the setting APP ZCL_*` ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = z2ui5_cl_cockpit_agent=>cs_kind-validation
        act = z2ui5_cl_cockpit_agent=>classify( outcome = `error`
                                                text    = `QTY holds a number - "ten" is none` ) ).

  ENDMETHOD.

  METHOD aggregate_rows.

    DATA ls_info TYPE z2ui5_cl_cockpit_agent=>ty_s_info.
    FIELD-SYMBOLS <temp6> LIKE LINE OF ls_info-t_day.
    DATA temp7 LIKE sy-tabix.
    FIELD-SYMBOLS <temp8> LIKE LINE OF ls_info-t_day.
    DATA temp9 LIKE sy-tabix.
    FIELD-SYMBOLS <temp10> LIKE LINE OF ls_info-t_day.
    DATA temp11 LIKE sy-tabix.
    FIELD-SYMBOLS <temp12> LIKE LINE OF ls_info-t_day.
    DATA temp13 LIKE sy-tabix.
    FIELD-SYMBOLS <temp14> LIKE LINE OF ls_info-t_day.
    DATA temp15 LIKE sy-tabix.
    FIELD-SYMBOLS <temp16> LIKE LINE OF ls_info-t_day.
    DATA temp17 LIKE sy-tabix.
    FIELD-SYMBOLS <temp18> LIKE LINE OF ls_info-t_app.
    DATA temp19 LIKE sy-tabix.
    FIELD-SYMBOLS <temp20> LIKE LINE OF ls_info-t_app.
    DATA temp21 LIKE sy-tabix.
    FIELD-SYMBOLS <temp22> LIKE LINE OF ls_info-t_app.
    DATA temp23 LIKE sy-tabix.
    FIELD-SYMBOLS <temp24> LIKE LINE OF ls_info-t_client.
    DATA temp25 LIKE sy-tabix.
    FIELD-SYMBOLS <temp26> LIKE LINE OF ls_info-t_last.
    DATA temp27 LIKE sy-tabix.
    FIELD-SYMBOLS <temp28> LIKE LINE OF ls_info-t_last.
    DATA temp29 LIKE sy-tabix.
    ls_info = z2ui5_cl_cockpit_agent=>aggregate( it_row  = rows( )
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


    temp7 = sy-tabix.
    READ TABLE ls_info-t_day INDEX 1 ASSIGNING <temp6>.
    sy-tabix = temp7.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `2099-01-02`
                                        act = <temp6>-day ).


    temp9 = sy-tabix.
    READ TABLE ls_info-t_day INDEX 1 ASSIGNING <temp8>.
    sy-tabix = temp9.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = <temp8>-calls ).


    temp11 = sy-tabix.
    READ TABLE ls_info-t_day INDEX 1 ASSIGNING <temp10>.
    sy-tabix = temp11.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 100
                                        act = <temp10>-bar ).


    temp13 = sy-tabix.
    READ TABLE ls_info-t_day INDEX 1 ASSIGNING <temp12>.
    sy-tabix = temp13.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Warning`
                                        act = <temp12>-state ).


    temp15 = sy-tabix.
    READ TABLE ls_info-t_day INDEX 2 ASSIGNING <temp14>.
    sy-tabix = temp15.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = <temp14>-calls ).


    temp17 = sy-tabix.
    READ TABLE ls_info-t_day INDEX 3 ASSIGNING <temp16>.
    sy-tabix = temp17.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = <temp16>-calls ).

    " per app and per client, most calls first


    temp19 = sy-tabix.
    READ TABLE ls_info-t_app INDEX 1 ASSIGNING <temp18>.
    sy-tabix = temp19.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ZCL_ORDERS`
                                        act = <temp18>-name ).


    temp21 = sy-tabix.
    READ TABLE ls_info-t_app INDEX 1 ASSIGNING <temp20>.
    sy-tabix = temp21.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = <temp20>-calls ).


    temp23 = sy-tabix.
    READ TABLE ls_info-t_app INDEX 1 ASSIGNING <temp22>.
    sy-tabix = temp23.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `2099-01-02 09:00:00`
                                        act = <temp22>-last ).


    temp25 = sy-tabix.
    READ TABLE ls_info-t_client INDEX 1 ASSIGNING <temp24>.
    sy-tabix = temp25.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ide-agent 2.1`
                                        act = <temp24>-name ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( ls_info-t_client ) ).

    " the last entries, capped
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( ls_info-t_last ) ).


    temp27 = sy-tabix.
    READ TABLE ls_info-t_last INDEX 1 ASSIGNING <temp26>.
    sy-tabix = temp27.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_agent=>cs_kind-policy
                                        act = <temp26>-kind ).


    temp29 = sy-tabix.
    READ TABLE ls_info-t_last INDEX 1 ASSIGNING <temp28>.
    sy-tabix = temp29.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ALICE`
                                        act = <temp28>-user ).

  ENDMETHOD.

  METHOD aggregate_respects_privacy.

    DATA ls_info TYPE z2ui5_cl_cockpit_agent=>ty_s_info.
    DATA ls_entry LIKE LINE OF ls_info-t_last.
    ls_info = z2ui5_cl_cockpit_agent=>aggregate( it_row = rows( )
                                                       days   = 1
                                                       today  = `20990102` ).

    LOOP AT ls_info-t_last INTO ls_entry.
      cl_abap_unit_assert=>assert_equals( exp = `(hidden)`
                                          act = ls_entry-user ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = lines( ls_info-t_last ) ).

  ENDMETHOD.

ENDCLASS.
