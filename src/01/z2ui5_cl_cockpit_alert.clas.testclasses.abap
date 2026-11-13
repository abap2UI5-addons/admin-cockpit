CLASS ltcl_alert DEFINITION DEFERRED.
CLASS z2ui5_cl_cockpit_alert DEFINITION LOCAL FRIENDS ltcl_alert.

"! The pure logic of the alerts: the rules over the window figures and what
"! a run raises and clears. No database access.
CLASS ltcl_alert DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    CONSTANTS c_app   TYPE string VALUE `ZZ_COCKPIT_TEST_APP`.
    CONSTANTS c_other TYPE string VALUE `ZZ_COCKPIT_TEST_OTHER`.

    METHODS error_rate_raised FOR TESTING.
    METHODS error_rate_below FOR TESTING.
    METHODS error_rate_at_threshold FOR TESTING.
    METHODS p95_raised FOR TESTING.
    METHODS below_minimum_raises_nothing FOR TESTING.
    METHODS zero_switches_rule_off FOR TESTING.
    METHODS all_apps_only_without_app FOR TESTING.
    METHODS all_apps_when_apps_are_small FOR TESTING.
    METHODS diff_raises_new FOR TESTING.
    METHODS diff_keeps_open FOR TESTING.
    METHODS diff_clears_gone FOR TESTING.

    METHODS settings
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.

ENDCLASS.


CLASS ltcl_alert IMPLEMENTATION.

  METHOD settings.

    result = z2ui5_cl_cockpit_setup=>get_default( ).
    result-alert_err_pct = 5.
    result-alert_p95_ms  = 2000.
    result-alert_min_cnt = 20.

  ENDMETHOD.

  METHOD error_rate_raised.

    " 10 of 100 failed - 10 %, threshold 5 %
    DATA temp1 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp2 LIKE LINE OF temp1.
    DATA lt_alert TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA ls_alert LIKE LINE OF lt_alert.
    FIELD-SYMBOLS <temp1> LIKE LINE OF lt_alert.
    DATA temp3 LIKE sy-tabix.
    CLEAR temp1.

    temp2-app = ``.
    temp2-roundtrips = 100.
    temp2-errors = 10.
    temp2-p95_ms = 100.
    INSERT temp2 INTO TABLE temp1.
    temp2-app = c_app.
    temp2-roundtrips = 100.
    temp2-errors = 10.
    temp2-p95_ms = 100.
    INSERT temp2 INTO TABLE temp1.

    lt_alert = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = temp1
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_alert ) ).



    temp3 = sy-tabix.
    READ TABLE lt_alert INDEX 1 ASSIGNING <temp1>.
    sy-tabix = temp3.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_alert = <temp1>.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_if_cockpit_notify=>cs_rule-error_rate
                                        act = ls_alert-rule ).
    cl_abap_unit_assert=>assert_equals( exp = c_app
                                        act = ls_alert-app ).
    cl_abap_unit_assert=>assert_equals( exp = `10.0 %`
                                        act = ls_alert-value ).
    cl_abap_unit_assert=>assert_equals( exp = `5 %`
                                        act = ls_alert-limit ).
    cl_abap_unit_assert=>assert_equals( exp = 100
                                        act = ls_alert-roundtrips ).

  ENDMETHOD.

  METHOD error_rate_below.

    DATA temp3 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp4 LIKE LINE OF temp3.
    DATA lt_alert TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    CLEAR temp3.

    temp4-app = c_app.
    temp4-roundtrips = 100.
    temp4-errors = 4.
    temp4-p95_ms = 100.
    INSERT temp4 INTO TABLE temp3.

    lt_alert = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = temp3
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_initial( lt_alert ).

  ENDMETHOD.

  METHOD error_rate_at_threshold.

    " exactly the threshold raises - "from 5 %"
    DATA temp5 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp6 LIKE LINE OF temp5.
    DATA lt_alert TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    CLEAR temp5.

    temp6-app = c_app.
    temp6-roundtrips = 100.
    temp6-errors = 5.
    temp6-p95_ms = 100.
    INSERT temp6 INTO TABLE temp5.

    lt_alert = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = temp5
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_alert ) ).

  ENDMETHOD.

  METHOD p95_raised.

    DATA temp7 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp8 LIKE LINE OF temp7.
    DATA lt_alert TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    FIELD-SYMBOLS <temp9> LIKE LINE OF lt_alert.
    DATA temp10 LIKE sy-tabix.
    FIELD-SYMBOLS <temp11> LIKE LINE OF lt_alert.
    DATA temp12 LIKE sy-tabix.
    CLEAR temp7.

    temp8-app = c_app.
    temp8-roundtrips = 50.
    temp8-errors = 0.
    temp8-p95_ms = 3400.
    INSERT temp8 INTO TABLE temp7.

    lt_alert = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = temp7
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_alert ) ).


    temp10 = sy-tabix.
    READ TABLE lt_alert INDEX 1 ASSIGNING <temp9>.
    sy-tabix = temp10.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_if_cockpit_notify=>cs_rule-p95
                                        act = <temp9>-rule ).


    temp12 = sy-tabix.
    READ TABLE lt_alert INDEX 1 ASSIGNING <temp11>.
    sy-tabix = temp12.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `3400 ms`
                                        act = <temp11>-value ).

  ENDMETHOD.

  METHOD below_minimum_raises_nothing.

    " every one of 10 roundtrips failed and was slow - but 10 is below 20
    DATA temp13 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp14 LIKE LINE OF temp13.
    DATA lt_alert TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    CLEAR temp13.

    temp14-app = c_app.
    temp14-roundtrips = 10.
    temp14-errors = 10.
    temp14-p95_ms = 9000.
    INSERT temp14 INTO TABLE temp13.

    lt_alert = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = temp13
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_initial( lt_alert ).

  ENDMETHOD.

  METHOD zero_switches_rule_off.

    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA temp15 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp16 LIKE LINE OF temp15.
    DATA lt_alert TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    FIELD-SYMBOLS <temp17> LIKE LINE OF lt_alert.
    DATA temp18 LIKE sy-tabix.
    ls_set = settings( ).
    ls_set-alert_err_pct = 0.


    CLEAR temp15.

    temp16-app = c_app.
    temp16-roundtrips = 100.
    temp16-errors = 100.
    temp16-p95_ms = 9000.
    INSERT temp16 INTO TABLE temp15.

    lt_alert = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = temp15
        is_set    = ls_set ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_alert ) ).


    temp18 = sy-tabix.
    READ TABLE lt_alert INDEX 1 ASSIGNING <temp17>.
    sy-tabix = temp18.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_if_cockpit_notify=>cs_rule-p95
                                        act = <temp17>-rule ).

  ENDMETHOD.

  METHOD all_apps_only_without_app.

    " one app explains the error rate over all apps - one alert, for the app;
    " the other app's p95 is raised over all apps too - again only for it
    DATA temp19 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp20 LIKE LINE OF temp19.
    DATA lt_alert TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA temp1 TYPE xsdboolean.
    DATA temp2 LIKE sy-subrc.
    CLEAR temp19.

    temp20-app = ``.
    temp20-roundtrips = 200.
    temp20-errors = 20.
    temp20-p95_ms = 2500.
    INSERT temp20 INTO TABLE temp19.
    temp20-app = c_app.
    temp20-roundtrips = 100.
    temp20-errors = 20.
    temp20-p95_ms = 100.
    INSERT temp20 INTO TABLE temp19.
    temp20-app = c_other.
    temp20-roundtrips = 100.
    temp20-errors = 0.
    temp20-p95_ms = 4000.
    INSERT temp20 INTO TABLE temp19.

    lt_alert = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = temp19
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_alert ) ).


    READ TABLE lt_alert WITH KEY app = `` TRANSPORTING NO FIELDS.
    temp2 = sy-subrc.
    temp1 = boolc( temp2 = 0 ).
    cl_abap_unit_assert=>assert_false( temp1 ).

  ENDMETHOD.

  METHOD all_apps_when_apps_are_small.

    " three apps, 15 roundtrips each - each below the minimum, together not
    DATA temp21 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp22 LIKE LINE OF temp21.
    DATA lt_alert TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    FIELD-SYMBOLS <temp23> LIKE LINE OF lt_alert.
    DATA temp24 LIKE sy-tabix.
    FIELD-SYMBOLS <temp25> LIKE LINE OF lt_alert.
    DATA temp26 LIKE sy-tabix.
    CLEAR temp21.

    temp22-app = ``.
    temp22-roundtrips = 45.
    temp22-errors = 9.
    temp22-p95_ms = 100.
    INSERT temp22 INTO TABLE temp21.
    temp22-app = c_app.
    temp22-roundtrips = 15.
    temp22-errors = 3.
    temp22-p95_ms = 100.
    INSERT temp22 INTO TABLE temp21.
    temp22-app = c_other.
    temp22-roundtrips = 15.
    temp22-errors = 3.
    temp22-p95_ms = 100.
    INSERT temp22 INTO TABLE temp21.
    temp22-app = `ZZ_COCKPIT_TEST_THIRD`.
    temp22-roundtrips = 15.
    temp22-errors = 3.
    temp22-p95_ms = 100.
    INSERT temp22 INTO TABLE temp21.

    lt_alert = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = temp21
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_alert ) ).


    temp24 = sy-tabix.
    READ TABLE lt_alert INDEX 1 ASSIGNING <temp23>.
    sy-tabix = temp24.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_initial( <temp23>-app ).


    temp26 = sy-tabix.
    READ TABLE lt_alert INDEX 1 ASSIGNING <temp25>.
    sy-tabix = temp26.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `20.0 %`
                                        act = <temp25>-value ).

  ENDMETHOD.

  METHOD diff_raises_new.

    DATA lt_raised TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA lt_cleared TYPE z2ui5_cl_cockpit_alert=>ty_t_open.

    DATA temp27 TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp4 TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA temp5 LIKE LINE OF temp4.
    CLEAR temp27.

    CLEAR temp4.

    temp5-rule = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp5-app = c_app.
    INSERT temp5 INTO TABLE temp4.
    z2ui5_cl_cockpit_alert=>diff(
      EXPORTING it_open    = temp27
                it_now     = temp4
      IMPORTING et_raised  = lt_raised
                et_cleared = lt_cleared ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_raised ) ).
    cl_abap_unit_assert=>assert_initial( lt_cleared ).

  ENDMETHOD.

  METHOD diff_keeps_open.

    " still exceeded: neither raised again nor cleared - one notification
    " per alert, not one per job run
    DATA lt_raised TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA lt_cleared TYPE z2ui5_cl_cockpit_alert=>ty_t_open.

    DATA temp28 TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp29 LIKE LINE OF temp28.
    DATA temp6 TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA temp7 LIKE LINE OF temp6.
    CLEAR temp28.

    temp29-id = `A1`.
    temp29-rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp29-app = c_app.
    INSERT temp29 INTO TABLE temp28.

    CLEAR temp6.

    temp7-rule = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp7-app = c_app.
    INSERT temp7 INTO TABLE temp6.
    z2ui5_cl_cockpit_alert=>diff(
      EXPORTING it_open    = temp28
                it_now     = temp6
      IMPORTING et_raised  = lt_raised
                et_cleared = lt_cleared ).

    cl_abap_unit_assert=>assert_initial( lt_raised ).
    cl_abap_unit_assert=>assert_initial( lt_cleared ).

  ENDMETHOD.

  METHOD diff_clears_gone.

    " the p95 of the app is fine again, its error rate is not: the one is
    " cleared, the other raised - same app, different rules
    DATA lt_raised TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA lt_cleared TYPE z2ui5_cl_cockpit_alert=>ty_t_open.

    DATA temp30 TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp31 LIKE LINE OF temp30.
    DATA temp8 TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA temp9 LIKE LINE OF temp8.
    FIELD-SYMBOLS <temp32> LIKE LINE OF lt_raised.
    DATA temp33 LIKE sy-tabix.
    DATA temp34 TYPE string.
    FIELD-SYMBOLS <temp10> LIKE LINE OF lt_cleared.
    DATA temp11 LIKE sy-tabix.
    CLEAR temp30.

    temp31-id = `A1`.
    temp31-rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp31-app = c_app.
    INSERT temp31 INTO TABLE temp30.

    CLEAR temp8.

    temp9-rule = z2ui5_if_cockpit_notify=>cs_rule-error_rate.
    temp9-app = c_app.
    INSERT temp9 INTO TABLE temp8.
    z2ui5_cl_cockpit_alert=>diff(
      EXPORTING it_open    = temp30
                it_now     = temp8
      IMPORTING et_raised  = lt_raised
                et_cleared = lt_cleared ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_raised ) ).


    temp33 = sy-tabix.
    READ TABLE lt_raised INDEX 1 ASSIGNING <temp32>.
    sy-tabix = temp33.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_if_cockpit_notify=>cs_rule-error_rate
                                        act = <temp32>-rule ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_cleared ) ).



    temp11 = sy-tabix.
    READ TABLE lt_cleared INDEX 1 ASSIGNING <temp10>.
    sy-tabix = temp11.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    temp34 = <temp10>-id.
    cl_abap_unit_assert=>assert_equals( exp = `A1`
                                        act = temp34 ).

  ENDMETHOD.

ENDCLASS.
