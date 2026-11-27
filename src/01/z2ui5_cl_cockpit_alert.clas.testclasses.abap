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
    METHODS errors_mode_has_no_rate FOR TESTING.
    METHODS all_apps_only_without_app FOR TESTING.
    METHODS all_apps_when_apps_are_small FOR TESTING.
    METHODS diff_raises_new FOR TESTING.
    METHODS diff_keeps_open FOR TESTING.
    METHODS diff_clears_gone FOR TESTING.
    METHODS quiet_window_keeps_open FOR TESTING.
    METHODS idle_app_closed FOR TESTING.
    METHODS rule_off_closed FOR TESTING.

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

  METHOD errors_mode_has_no_rate.

    " mode ERRORS records failed roundtrips only - 100 % says nothing, and
    " the p95 is that of the failures
    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA temp19 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp20 LIKE LINE OF temp19.
    DATA lt_alert TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    ls_set = settings( ).
    ls_set-mode = z2ui5_cl_cockpit_setup=>cs_mode-errors.

    CLEAR temp19.

    temp20-app = c_app.
    temp20-roundtrips = 30.
    temp20-errors = 30.
    temp20-p95_ms = 9000.
    INSERT temp20 INTO TABLE temp19.

    lt_alert = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = temp19
        is_set    = ls_set ).

    cl_abap_unit_assert=>assert_initial( lt_alert ).

  ENDMETHOD.

  METHOD all_apps_only_without_app.

    " one app explains the error rate over all apps - one alert, for the app;
    " the other app's p95 is raised over all apps too - again only for it
    DATA temp21 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp22 LIKE LINE OF temp21.
    DATA lt_alert TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA temp1 TYPE xsdboolean.
    DATA temp2 LIKE sy-subrc.
    CLEAR temp21.

    temp22-app = ``.
    temp22-roundtrips = 200.
    temp22-errors = 20.
    temp22-p95_ms = 2500.
    INSERT temp22 INTO TABLE temp21.
    temp22-app = c_app.
    temp22-roundtrips = 100.
    temp22-errors = 20.
    temp22-p95_ms = 100.
    INSERT temp22 INTO TABLE temp21.
    temp22-app = c_other.
    temp22-roundtrips = 100.
    temp22-errors = 0.
    temp22-p95_ms = 4000.
    INSERT temp22 INTO TABLE temp21.

    lt_alert = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = temp21
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
    DATA temp23 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp24 LIKE LINE OF temp23.
    DATA lt_alert TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    FIELD-SYMBOLS <temp25> LIKE LINE OF lt_alert.
    DATA temp26 LIKE sy-tabix.
    FIELD-SYMBOLS <temp27> LIKE LINE OF lt_alert.
    DATA temp28 LIKE sy-tabix.
    CLEAR temp23.

    temp24-app = ``.
    temp24-roundtrips = 45.
    temp24-errors = 9.
    temp24-p95_ms = 100.
    INSERT temp24 INTO TABLE temp23.
    temp24-app = c_app.
    temp24-roundtrips = 15.
    temp24-errors = 3.
    temp24-p95_ms = 100.
    INSERT temp24 INTO TABLE temp23.
    temp24-app = c_other.
    temp24-roundtrips = 15.
    temp24-errors = 3.
    temp24-p95_ms = 100.
    INSERT temp24 INTO TABLE temp23.
    temp24-app = `ZZ_COCKPIT_TEST_THIRD`.
    temp24-roundtrips = 15.
    temp24-errors = 3.
    temp24-p95_ms = 100.
    INSERT temp24 INTO TABLE temp23.

    lt_alert = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = temp23
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_alert ) ).


    temp26 = sy-tabix.
    READ TABLE lt_alert INDEX 1 ASSIGNING <temp25>.
    sy-tabix = temp26.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_initial( <temp25>-app ).


    temp28 = sy-tabix.
    READ TABLE lt_alert INDEX 1 ASSIGNING <temp27>.
    sy-tabix = temp28.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `20.0 %`
                                        act = <temp27>-value ).

  ENDMETHOD.

  METHOD diff_raises_new.

    DATA lt_raised TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA lt_cleared TYPE z2ui5_cl_cockpit_alert=>ty_t_open.

    DATA temp29 TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp4 TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA temp5 LIKE LINE OF temp4.
    CLEAR temp29.

    CLEAR temp4.

    temp5-rule = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp5-app = c_app.
    INSERT temp5 INTO TABLE temp4.
    z2ui5_cl_cockpit_alert=>diff(
      EXPORTING it_open    = temp29
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

    DATA temp30 TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp31 LIKE LINE OF temp30.
    DATA temp6 TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA temp7 LIKE LINE OF temp6.
    CLEAR temp30.

    temp31-id = `A1`.
    temp31-rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp31-app = c_app.
    INSERT temp31 INTO TABLE temp30.

    CLEAR temp6.

    temp7-rule = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp7-app = c_app.
    INSERT temp7 INTO TABLE temp6.
    z2ui5_cl_cockpit_alert=>diff(
      EXPORTING it_open    = temp30
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

    DATA temp32 TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp33 LIKE LINE OF temp32.
    DATA temp8 TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA temp9 LIKE LINE OF temp8.
    FIELD-SYMBOLS <temp34> LIKE LINE OF lt_raised.
    DATA temp35 LIKE sy-tabix.
    DATA temp36 TYPE string.
    FIELD-SYMBOLS <temp10> LIKE LINE OF lt_cleared.
    DATA temp11 LIKE sy-tabix.
    CLEAR temp32.

    temp33-id = `A1`.
    temp33-rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp33-app = c_app.
    INSERT temp33 INTO TABLE temp32.

    CLEAR temp8.

    temp9-rule = z2ui5_if_cockpit_notify=>cs_rule-error_rate.
    temp9-app = c_app.
    INSERT temp9 INTO TABLE temp8.
    z2ui5_cl_cockpit_alert=>diff(
      EXPORTING it_open    = temp32
                it_now     = temp8
      IMPORTING et_raised  = lt_raised
                et_cleared = lt_cleared ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_raised ) ).


    temp35 = sy-tabix.
    READ TABLE lt_raised INDEX 1 ASSIGNING <temp34>.
    sy-tabix = temp35.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_if_cockpit_notify=>cs_rule-error_rate
                                        act = <temp34>-rule ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_cleared ) ).



    temp11 = sy-tabix.
    READ TABLE lt_cleared INDEX 1 ASSIGNING <temp10>.
    sy-tabix = temp11.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    temp36 = <temp10>-id.
    cl_abap_unit_assert=>assert_equals( exp = `A1`
                                        act = temp36 ).

  ENDMETHOD.

  METHOD quiet_window_keeps_open.

    " too few roundtrips to tell: the alert stays open - unless its rule is off
    DATA temp37 TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp38 LIKE LINE OF temp37.
    DATA lt_open LIKE temp37.
    DATA temp39 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp40 LIKE LINE OF temp39.
    DATA lt_window LIKE temp39.
    DATA lt_judged TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp41 TYPE string.
    FIELD-SYMBOLS <temp12> LIKE LINE OF lt_judged.
    DATA temp13 LIKE sy-tabix.
    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    FIELD-SYMBOLS <temp42> LIKE LINE OF lt_judged.
    DATA temp43 LIKE sy-tabix.
    FIELD-SYMBOLS <temp44> LIKE LINE OF lt_judged.
    DATA temp45 LIKE sy-tabix.
    CLEAR temp37.

    temp38-id = `A1`.
    temp38-rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp38-app = c_app.
    INSERT temp38 INTO TABLE temp37.
    temp38-id = `A2`.
    temp38-rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp38-app = c_other.
    INSERT temp38 INTO TABLE temp37.
    temp38-id = `A3`.
    temp38-rule_id = z2ui5_if_cockpit_notify=>cs_rule-error_rate.
    temp38-app = ``.
    INSERT temp38 INTO TABLE temp37.

    lt_open = temp37.

    CLEAR temp39.

    temp40-app = ``.
    temp40-roundtrips = 35.
    INSERT temp40 INTO TABLE temp39.
    temp40-app = c_app.
    temp40-roundtrips = 5.
    INSERT temp40 INTO TABLE temp39.
    temp40-app = c_other.
    temp40-roundtrips = 30.
    INSERT temp40 INTO TABLE temp39.

    lt_window = temp39.


    lt_judged = z2ui5_cl_cockpit_alert=>judged( it_open   = lt_open
                                                      it_window = lt_window
                                                      is_set    = settings( ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_judged ) ).



    temp13 = sy-tabix.
    READ TABLE lt_judged INDEX 1 ASSIGNING <temp12>.
    sy-tabix = temp13.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    temp41 = <temp12>-id.
    cl_abap_unit_assert=>assert_equals( exp = `A2`
                                        act = temp41 ).


    ls_set = settings( ).
    ls_set-alert_p95_ms = 0.
    lt_judged = z2ui5_cl_cockpit_alert=>judged( it_open   = lt_open
                                                it_window = lt_window
                                                is_set    = ls_set ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( lt_judged ) ).


    temp43 = sy-tabix.
    READ TABLE lt_judged INDEX 1 ASSIGNING <temp42>.
    sy-tabix = temp43.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_alert=>cs_closing-rule_off
                                        act = <temp42>-closing ).


    temp45 = sy-tabix.
    READ TABLE lt_judged INDEX 3 ASSIGNING <temp44>.
    sy-tabix = temp45.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_initial( <temp44>-closing ).

  ENDMETHOD.

  METHOD idle_app_closed.

    " an app without any roundtrip for days (removed, renamed, unused): its
    " alert is closed without a verdict - a quiet window of an app that is
    " still used keeps its alert open
    DATA temp46 TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp47 LIKE LINE OF temp46.
    DATA lt_open LIKE temp46.
    DATA temp48 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp49 LIKE LINE OF temp48.
    DATA lt_window LIKE temp48.
    DATA temp50 TYPE string_table.
    DATA lt_judged TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp52 TYPE string.
    FIELD-SYMBOLS <temp14> LIKE LINE OF lt_judged.
    DATA temp15 LIKE sy-tabix.
    FIELD-SYMBOLS <temp53> LIKE LINE OF lt_judged.
    DATA temp54 LIKE sy-tabix.
    FIELD-SYMBOLS <temp55> LIKE LINE OF lt_judged.
    DATA temp56 LIKE sy-tabix.
    CLEAR temp46.

    CLEAR temp47.
    temp47-id = `A1`.
    temp47-rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp47-app = c_app.
    temp47-measured = `3000 ms`.
    temp47-threshold = `2000 ms`.
    INSERT temp47 INTO TABLE temp46.
    CLEAR temp47.
    temp47-id = `A2`.
    temp47-rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp47-app = c_other.
    INSERT temp47 INTO TABLE temp46.

    lt_open = temp46.

    CLEAR temp48.

    temp49-app = ``.
    temp49-roundtrips = 5.
    INSERT temp49 INTO TABLE temp48.
    temp49-app = c_other.
    temp49-roundtrips = 5.
    INSERT temp49 INTO TABLE temp48.

    lt_window = temp48.


    CLEAR temp50.
    INSERT c_app INTO TABLE temp50.
    INSERT c_other INTO TABLE temp50.

    lt_judged = z2ui5_cl_cockpit_alert=>judged( it_open   = lt_open
                                                      it_window = lt_window
                                                      is_set    = settings( )
                                                      it_idle   = temp50 ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_judged ) ).



    temp15 = sy-tabix.
    READ TABLE lt_judged INDEX 1 ASSIGNING <temp14>.
    sy-tabix = temp15.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    temp52 = <temp14>-id.
    cl_abap_unit_assert=>assert_equals( exp = `A1`
                                        act = temp52 ).


    temp54 = sy-tabix.
    READ TABLE lt_judged INDEX 1 ASSIGNING <temp53>.
    sy-tabix = temp54.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_alert=>cs_closing-idle
                                        act = <temp53>-closing ).


    temp56 = sy-tabix.
    READ TABLE lt_judged INDEX 1 ASSIGNING <temp55>.
    sy-tabix = temp56.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_char_cp( exp = `p95 response time*closed without a verdict - no roundtrip for 7 days*3000 ms*`
                                         act = z2ui5_cl_cockpit_alert=>clear_text( is_open = <temp55>
                                                                                   raised  = `2099-01-01 10:00:00` ) ).

  ENDMETHOD.

  METHOD rule_off_closed.

    " a rule switched off - or the p95 in mode ERRORS - is no recovery: the
    " text of the cleared alert says so instead of "below again"
    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA temp57 TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp58 LIKE LINE OF temp57.
    DATA temp16 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp17 LIKE LINE OF temp16.
    DATA lt_judged TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    FIELD-SYMBOLS <temp59> LIKE LINE OF lt_judged.
    DATA temp60 LIKE sy-tabix.
    FIELD-SYMBOLS <temp61> LIKE LINE OF lt_judged.
    DATA temp62 LIKE sy-tabix.
    DATA temp63 TYPE z2ui5_cl_cockpit_alert=>ty_t_open.
    DATA temp64 LIKE LINE OF temp63.
    DATA temp18 TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA temp19 LIKE LINE OF temp18.
    FIELD-SYMBOLS <temp65> LIKE LINE OF lt_judged.
    DATA temp66 LIKE sy-tabix.
    ls_set = settings( ).
    ls_set-mode = z2ui5_cl_cockpit_setup=>cs_mode-errors.

    CLEAR temp57.

    temp58-id = `A1`.
    temp58-rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp58-app = c_app.
    temp58-threshold = `2000 ms`.
    INSERT temp58 INTO TABLE temp57.

    CLEAR temp16.

    temp17-app = c_app.
    temp17-roundtrips = 50.
    INSERT temp17 INTO TABLE temp16.

    lt_judged = z2ui5_cl_cockpit_alert=>judged(
        it_open   = temp57
        it_window = temp16
        is_set    = ls_set ).


    temp60 = sy-tabix.
    READ TABLE lt_judged INDEX 1 ASSIGNING <temp59>.
    sy-tabix = temp60.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_alert=>cs_closing-rule_off
                                        act = <temp59>-closing ).


    temp62 = sy-tabix.
    READ TABLE lt_judged INDEX 1 ASSIGNING <temp61>.
    sy-tabix = temp62.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_char_cp( exp = `*closed without a verdict - the rule is switched off*`
                                         act = z2ui5_cl_cockpit_alert=>clear_text( is_open = <temp61>
                                                                                   raised  = `x` ) ).

    " judged by the window: below the threshold again

    CLEAR temp63.

    temp64-id = `A1`.
    temp64-rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95.
    temp64-app = c_app.
    temp64-threshold = `2000 ms`.
    INSERT temp64 INTO TABLE temp63.

    CLEAR temp18.

    temp19-app = c_app.
    temp19-roundtrips = 50.
    INSERT temp19 INTO TABLE temp18.
    lt_judged = z2ui5_cl_cockpit_alert=>judged(
        it_open   = temp63
        it_window = temp18
        is_set    = settings( ) ).


    temp66 = sy-tabix.
    READ TABLE lt_judged INDEX 1 ASSIGNING <temp65>.
    sy-tabix = temp66.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_char_cp( exp = `*is below 2000 ms again*`
                                         act = z2ui5_cl_cockpit_alert=>clear_text( is_open = <temp65>
                                                                                   raised  = `x` ) ).

  ENDMETHOD.

ENDCLASS.
