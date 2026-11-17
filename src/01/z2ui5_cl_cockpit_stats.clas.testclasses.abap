CLASS ltcl_stats DEFINITION DEFERRED.
CLASS z2ui5_cl_cockpit_stats DEFINITION LOCAL FRIENDS ltcl_stats.

"! The pure logic of the statistics: the p95 from the latency histogram,
"! the runtime hint rules, the grouping of errors and the unused apps. No
"! database access.
CLASS ltcl_stats DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    CONSTANTS c_app TYPE string VALUE `ZZ_COCKPIT_TEST_APP`.

    METHODS p95_empty FOR TESTING.
    METHODS p95_one_bucket FOR TESTING.
    METHODS p95_interpolated FOR TESTING.
    METHODS p95_capped_by_max FOR TESTING.
    METHODS p95_last_bucket_uses_max FOR TESTING.
    METHODS hints_none FOR TESTING.
    METHODS hints_large_model FOR TESTING.
    METHODS hints_slow_p95_needs_volume FOR TESTING.
    METHODS hints_error_rate FOR TESTING.
    METHODS hints_growing_state FOR TESTING.
    METHODS hints_load_dominates FOR TESTING.
    METHODS hints_draft_backlog FOR TESTING.
    METHODS errors_grouped FOR TESTING.
    METHODS errors_tie_keeps_newest_first FOR TESTING.
    METHODS unused_apps FOR TESTING.

    METHODS hint_exists
      IMPORTING
        it_hint       TYPE z2ui5_cl_cockpit_stats=>ty_t_hint
        hint          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

ENDCLASS.


CLASS ltcl_stats IMPLEMENTATION.

  METHOD p95_empty.

    DATA ls_sum TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = z2ui5_cl_cockpit_stats=>p95( ls_sum ) ).

  ENDMETHOD.

  METHOD p95_one_bucket.

    " 100 roundtrips below 100 ms: the 95th lies at 95 % of the first bucket
    DATA ls_sum TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    ls_sum-h01 = 100.
    cl_abap_unit_assert=>assert_equals( exp = 95
                                        act = z2ui5_cl_cockpit_stats=>p95( ls_sum ) ).

  ENDMETHOD.

  METHOD p95_interpolated.

    " 90 below 100 ms, 10 between 100 and 250 ms: the 95th is the 5th of the
    " 10 in the second bucket - half way, 175 ms
    DATA ls_sum TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    ls_sum-h01 = 90.
    ls_sum-h02 = 10.
    cl_abap_unit_assert=>assert_equals( exp = 175
                                        act = z2ui5_cl_cockpit_stats=>p95( ls_sum ) ).

  ENDMETHOD.

  METHOD p95_capped_by_max.

    DATA ls_sum TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    ls_sum-h01 = 90.
    ls_sum-h02 = 10.
    ls_sum-ms_max = 150.
    cl_abap_unit_assert=>assert_equals( exp = 150
                                        act = z2ui5_cl_cockpit_stats=>p95( ls_sum ) ).

  ENDMETHOD.

  METHOD p95_last_bucket_uses_max.

    " the open last bucket ends at the observed maximum
    DATA ls_sum TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    ls_sum-h09 = 100.
    ls_sum-ms_max = 40000.
    cl_abap_unit_assert=>assert_equals( exp = 39500
                                        act = z2ui5_cl_cockpit_stats=>p95( ls_sum ) ).

  ENDMETHOD.

  METHOD hints_none.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    DATA temp1 TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    DATA lt_hint TYPE z2ui5_cl_cockpit_stats=>ty_t_hint.
    CLEAR temp1.
    temp1-app = c_app.
    temp1-cnt = 100.
    temp1-h01 = 100.
    temp1-ms_sum = 5000.
    temp1-ms_load = 500.
    temp1-mod_max = 2048.
    temp1-res_max = 4096.
    INSERT temp1 INTO TABLE lt_new.


    lt_hint = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_initial( lt_hint ).

  ENDMETHOD.

  METHOD hints_large_model.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    DATA temp2 TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    DATA lt_hint TYPE z2ui5_cl_cockpit_stats=>ty_t_hint.
    FIELD-SYMBOLS <temp3> LIKE LINE OF lt_hint.
    DATA temp4 LIKE sy-tabix.
    CLEAR temp2.
    temp2-app = c_app.
    temp2-cnt = 1.
    temp2-h01 = 1.
    temp2-mod_max = 2 * 1024 * 1024.
    temp2-res_max = 600 * 1024.
    INSERT temp2 INTO TABLE lt_new.


    lt_hint = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_true( hint_exists( it_hint = lt_hint
                                                   hint    = `Large model` ) ).
    cl_abap_unit_assert=>assert_true( hint_exists( it_hint = lt_hint
                                                   hint    = `Large response` ) ).


    temp4 = sy-tabix.
    READ TABLE lt_hint WITH KEY hint = `Large model` ASSIGNING <temp3>.
    sy-tabix = temp4.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `2048 KB`
                                        act = <temp3>-value ). "#EC CI_SORTSEQ

  ENDMETHOD.

  METHOD hints_slow_p95_needs_volume.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    " ten slow roundtrips are too few to judge
    DATA temp5 TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    DATA lt_hint TYPE z2ui5_cl_cockpit_stats=>ty_t_hint.
    DATA temp6 TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    FIELD-SYMBOLS <temp7> LIKE LINE OF lt_hint.
    DATA temp8 LIKE sy-tabix.
    CLEAR temp5.
    temp5-app = c_app.
    temp5-cnt = 10.
    temp5-h06 = 10.
    INSERT temp5 INTO TABLE lt_new.

    lt_hint = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_false( hint_exists( it_hint = lt_hint
                                                    hint    = `Slow p95` ) ).

    " twenty are enough - p95 = 2000 + 3000 * 19 / 20
    CLEAR lt_new.

    CLEAR temp6.
    temp6-app = c_app.
    temp6-cnt = 20.
    temp6-h06 = 20.
    INSERT temp6 INTO TABLE lt_new.
    lt_hint = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                it_old   = lt_old
                                                is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                is_draft = ls_draft ).


    temp8 = sy-tabix.
    READ TABLE lt_hint WITH KEY hint = `Slow p95` ASSIGNING <temp7>.
    sy-tabix = temp8.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `4850 ms`
                                        act = <temp7>-value ). "#EC CI_SORTSEQ

  ENDMETHOD.

  METHOD hints_error_rate.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    " 1 of 40 is 2.5 % - no hint; the older half adds another error: 5 %
    DATA temp9 TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    DATA temp10 TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    DATA lt_hint TYPE z2ui5_cl_cockpit_stats=>ty_t_hint.
    DATA temp11 TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    DATA ls_hint LIKE LINE OF lt_hint.
    FIELD-SYMBOLS <temp1> LIKE LINE OF lt_hint.
    DATA temp2 LIKE sy-tabix.
    CLEAR temp9.
    temp9-app = c_app.
    temp9-cnt = 20.
    temp9-cnt_err = 1.
    temp9-h01 = 20.
    INSERT temp9 INTO TABLE lt_new.

    CLEAR temp10.
    temp10-app = c_app.
    temp10-cnt = 20.
    temp10-h01 = 20.
    INSERT temp10 INTO TABLE lt_old.

    lt_hint = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_false( hint_exists( it_hint = lt_hint
                                                    hint    = `Error rate of 5 % or more` ) ).

    CLEAR lt_old.

    CLEAR temp11.
    temp11-app = c_app.
    temp11-cnt = 20.
    temp11-cnt_err = 1.
    temp11-h01 = 20.
    INSERT temp11 INTO TABLE lt_old.
    lt_hint = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                it_old   = lt_old
                                                is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                is_draft = ls_draft ).



    temp2 = sy-tabix.
    READ TABLE lt_hint WITH KEY hint = `Error rate of 5 % or more` ASSIGNING <temp1>.
    sy-tabix = temp2.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_hint = <temp1>. "#EC CI_SORTSEQ
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = ls_hint-state ).
    cl_abap_unit_assert=>assert_equals( exp = `2 of 40`
                                        act = ls_hint-value ).

  ENDMETHOD.

  METHOD hints_growing_state.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    DATA temp12 TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    DATA temp13 TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    DATA lt_hint TYPE z2ui5_cl_cockpit_stats=>ty_t_hint.
    FIELD-SYMBOLS <temp14> LIKE LINE OF lt_hint.
    DATA temp15 LIKE sy-tabix.
    CLEAR temp12.
    temp12-app = c_app.
    temp12-cnt = 1.
    temp12-h01 = 1.
    temp12-mod_max = 200 * 1024.
    INSERT temp12 INTO TABLE lt_old.

    CLEAR temp13.
    temp13-app = c_app.
    temp13-cnt = 1.
    temp13-h01 = 1.
    temp13-mod_max = 400 * 1024.
    INSERT temp13 INTO TABLE lt_new.


    lt_hint = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).


    temp15 = sy-tabix.
    READ TABLE lt_hint WITH KEY hint = `Growing app state` ASSIGNING <temp14>.
    sy-tabix = temp15.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `200 KB to 400 KB`
                                        act = <temp14>-value ). "#EC CI_SORTSEQ
    cl_abap_unit_assert=>assert_false( hint_exists( it_hint = lt_hint
                                                    hint    = `Large model` ) ).

  ENDMETHOD.

  METHOD hints_load_dominates.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    DATA temp16 TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    DATA lt_hint TYPE z2ui5_cl_cockpit_stats=>ty_t_hint.
    FIELD-SYMBOLS <temp17> LIKE LINE OF lt_hint.
    DATA temp18 LIKE sy-tabix.
    CLEAR temp16.
    temp16-app = c_app.
    temp16-cnt = 20.
    temp16-h01 = 20.
    temp16-ms_sum = 1000.
    temp16-ms_load = 600.
    temp16-ms_main = 400.
    INSERT temp16 INTO TABLE lt_new.


    lt_hint = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).


    temp18 = sy-tabix.
    READ TABLE lt_hint WITH KEY hint = `Load phase dominates` ASSIGNING <temp17>.
    sy-tabix = temp18.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `60 % of the time`
                                        act = <temp17>-value ). "#EC CI_SORTSEQ
    cl_abap_unit_assert=>assert_false( hint_exists( it_hint = lt_hint
                                                    hint    = `Render phase dominates` ) ).

  ENDMETHOD.

  METHOD hints_draft_backlog.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.
    DATA lt_hint TYPE z2ui5_cl_cockpit_stats=>ty_t_hint.
    FIELD-SYMBOLS <temp19> LIKE LINE OF lt_hint.
    DATA temp20 LIKE sy-tabix.

    ls_draft-check_backlog = abap_true.
    ls_draft-rows_expired  = 12.
    ls_draft-oldest        = `2099-01-01 10:00:00`.
    ls_draft-rows          = 100001.


    lt_hint = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_hint ) ).


    temp20 = sy-tabix.
    READ TABLE lt_hint WITH KEY hint = `Expired drafts are not deleted` ASSIGNING <temp19>.
    sy-tabix = temp20.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `12 expired, oldest 2099-01-01 10:00:00`
                                        act = <temp19>-value ). "#EC CI_SORTSEQ
    cl_abap_unit_assert=>assert_true( hint_exists( it_hint = lt_hint
                                                   hint    = `Large draft table` ) ).

  ENDMETHOD.

  METHOD errors_grouped.

    DATA lt_log TYPE z2ui5_cl_cockpit_stats=>ty_t_err_log.

    " newest first, as the SELECT delivers them
    DATA temp21 TYPE z2ui5_cl_cockpit_stats=>ty_t_err_log.
    DATA temp22 LIKE LINE OF temp21.
    DATA lt_error TYPE z2ui5_cl_cockpit_stats=>ty_t_error.
    DATA ls_first LIKE LINE OF lt_error.
    FIELD-SYMBOLS <temp3> LIKE LINE OF lt_error.
    DATA temp4 LIKE sy-tabix.
    DATA ls_second LIKE LINE OF lt_error.
    FIELD-SYMBOLS <temp5> LIKE LINE OF lt_error.
    DATA temp6 LIKE sy-tabix.
    CLEAR temp21.

    temp22-timestampl = '20990101120000'.
    temp22-app = c_app.
    temp22-event = `SAVE`.
    temp22-error_class = `CX_SY_ZERODIVIDE`.
    temp22-error_head = `Division by zero`.
    INSERT temp22 INTO TABLE temp21.
    temp22-timestampl = '20990101110000'.
    temp22-app = c_app.
    temp22-event = `SAVE`.
    temp22-error_class = `CX_SY_ITAB_LINE_NOT_FOUND`.
    temp22-error_head = `Line not found`.
    INSERT temp22 INTO TABLE temp21.
    temp22-timestampl = '20990101100000'.
    temp22-app = c_app.
    temp22-event = `SAVE`.
    temp22-error_class = `CX_SY_ZERODIVIDE`.
    temp22-error_head = `Division by zero`.
    INSERT temp22 INTO TABLE temp21.
    lt_log = temp21.


    lt_error = z2ui5_cl_cockpit_stats=>group_errors( lt_log ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_error ) ).



    temp4 = sy-tabix.
    READ TABLE lt_error INDEX 1 ASSIGNING <temp3>.
    sy-tabix = temp4.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_first = <temp3>.
    cl_abap_unit_assert=>assert_equals( exp = `G1`
                                        act = ls_first-key ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_first-count ).
    cl_abap_unit_assert=>assert_equals( exp = `CX_SY_ZERODIVIDE`
                                        act = ls_first-error_class ).
    cl_abap_unit_assert=>assert_equals( exp = `2099-01-01 10:00:00`
                                        act = ls_first-first_seen ).
    cl_abap_unit_assert=>assert_equals( exp = `2099-01-01 12:00:00`
                                        act = ls_first-last_seen ).



    temp6 = sy-tabix.
    READ TABLE lt_error INDEX 2 ASSIGNING <temp5>.
    sy-tabix = temp6.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_second = <temp5>.
    cl_abap_unit_assert=>assert_equals( exp = `G2`
                                        act = ls_second-key ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_second-count ).
    cl_abap_unit_assert=>assert_equals( exp = ls_second-first_seen
                                        act = ls_second-last_seen ).

  ENDMETHOD.

  METHOD errors_tie_keeps_newest_first.

    DATA lt_log TYPE z2ui5_cl_cockpit_stats=>ty_t_err_log.

    DATA temp23 TYPE z2ui5_cl_cockpit_stats=>ty_t_err_log.
    DATA temp24 LIKE LINE OF temp23.
    DATA lt_error TYPE z2ui5_cl_cockpit_stats=>ty_t_error.
    FIELD-SYMBOLS <temp25> LIKE LINE OF lt_error.
    DATA temp26 LIKE sy-tabix.
    FIELD-SYMBOLS <temp27> LIKE LINE OF lt_error.
    DATA temp28 LIKE sy-tabix.
    CLEAR temp23.

    temp24-timestampl = '20990101120000'.
    temp24-app = c_app.
    temp24-event = `B`.
    temp24-error_class = `CX_B`.
    temp24-error_head = `b`.
    INSERT temp24 INTO TABLE temp23.
    temp24-timestampl = '20990101110000'.
    temp24-app = c_app.
    temp24-event = `A`.
    temp24-error_class = `CX_A`.
    temp24-error_head = `a`.
    INSERT temp24 INTO TABLE temp23.
    lt_log = temp23.


    lt_error = z2ui5_cl_cockpit_stats=>group_errors( lt_log ).



    temp26 = sy-tabix.
    READ TABLE lt_error INDEX 1 ASSIGNING <temp25>.
    sy-tabix = temp26.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `B`
                                        act = <temp25>-event ).


    temp28 = sy-tabix.
    READ TABLE lt_error INDEX 2 ASSIGNING <temp27>.
    sy-tabix = temp28.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `A`
                                        act = <temp27>-event ).

  ENDMETHOD.

  METHOD unused_apps.

    DATA lt_last TYPE z2ui5_cl_cockpit_stats=>ty_t_last.

    DATA temp29 TYPE z2ui5_cl_cockpit_setup=>ty_t_names.
    DATA lt_impl LIKE temp29.
    DATA temp31 TYPE z2ui5_cl_cockpit_stats=>ty_s_last.
    DATA temp32 TYPE z2ui5_cl_cockpit_stats=>ty_s_last.
    DATA lt_unused TYPE z2ui5_cl_cockpit_stats=>ty_t_unused.
    FIELD-SYMBOLS <temp33> LIKE LINE OF lt_unused.
    DATA temp34 LIKE sy-tabix.
    FIELD-SYMBOLS <temp35> LIKE LINE OF lt_unused.
    DATA temp36 LIKE sy-tabix.
    DATA temp1 TYPE xsdboolean.
    DATA temp2 LIKE sy-subrc.
    CLEAR temp29.
    INSERT `ZZ_APP_OLD` INTO TABLE temp29.
    INSERT `ZZ_APP_RECENT` INTO TABLE temp29.
    INSERT `ZZ_APP_NEVER` INTO TABLE temp29.

    lt_impl = temp29.

    CLEAR temp31.
    temp31-app = `ZZ_APP_OLD`.
    temp31-utc_day = `20260101`.
    INSERT temp31 INTO TABLE lt_last.

    CLEAR temp32.
    temp32-app = `ZZ_APP_RECENT`.
    temp32-utc_day = `20261001`.
    INSERT temp32 INTO TABLE lt_last.


    lt_unused = z2ui5_cl_cockpit_stats=>unused_of( it_impl  = lt_impl
                                                         it_last  = lt_last
                                                         from_day = `20260701` ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_unused ) ).


    temp34 = sy-tabix.
    READ TABLE lt_unused WITH KEY app = `ZZ_APP_OLD` ASSIGNING <temp33>.
    sy-tabix = temp34.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `2026-01-01`
                                        act = <temp33>-last_used ). "#EC CI_SORTSEQ


    temp36 = sy-tabix.
    READ TABLE lt_unused WITH KEY app = `ZZ_APP_NEVER` ASSIGNING <temp35>.
    sy-tabix = temp36.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `never recorded`
                                        act = <temp35>-last_used ). "#EC CI_SORTSEQ


    READ TABLE lt_unused WITH KEY app = `ZZ_APP_RECENT` TRANSPORTING NO FIELDS.
    temp2 = sy-subrc.
    temp1 = boolc( temp2 = 0 ).
    cl_abap_unit_assert=>assert_false( temp1 ). "#EC CI_SORTSEQ

  ENDMETHOD.

  METHOD hint_exists.

    DATA temp37 LIKE sy-subrc.
    DATA temp2 TYPE xsdboolean.
    READ TABLE it_hint WITH KEY hint = hint TRANSPORTING NO FIELDS.
    temp37 = sy-subrc.

    temp2 = boolc( temp37 = 0 ).
    result = temp2. "#EC CI_SORTSEQ

  ENDMETHOD.

ENDCLASS.
