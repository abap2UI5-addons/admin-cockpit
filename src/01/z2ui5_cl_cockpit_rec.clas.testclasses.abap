CLASS ltcl_rec DEFINITION DEFERRED.
CLASS z2ui5_cl_cockpit_rec DEFINITION LOCAL FRIENDS ltcl_rec.

"! The recorder against its tables: rows of a test app on a day in 2099,
"! written with write( ) (which never commits). teardown deletes them and
"! rolls back - nothing of a real installation is touched or committed.
CLASS ltcl_rec DEFINITION FINAL FOR TESTING RISK LEVEL DANGEROUS DURATION SHORT.

  PRIVATE SECTION.

    CONSTANTS c_app TYPE string VALUE `ZZ_COCKPIT_UNIT_TEST`.
    CONSTANTS c_day TYPE string VALUE `20990101`.

    TYPES ty_t_log TYPE STANDARD TABLE OF z2ui5_t_ck_log WITH EMPTY KEY.

    METHODS setup.
    METHODS teardown.

    METHODS aggregates_one_hour FOR TESTING RAISING cx_static_check.
    METHODS error_writes_log FOR TESTING RAISING cx_static_check.
    METHODS slow_writes_log FOR TESTING RAISING cx_static_check.
    METHODS name_mode_keeps_user FOR TESTING RAISING cx_static_check.
    METHODS errors_mode_skips_success FOR TESTING RAISING cx_static_check.
    METHODS sample_mode_weights FOR TESTING RAISING cx_static_check.
    METHODS off_mode_writes_nothing FOR TESTING RAISING cx_static_check.
    METHODS sticky_is_buffered FOR TESTING.
    METHODS sums_saturate FOR TESTING.

    METHODS use
      IMPORTING
        mode     TYPE string DEFAULT z2ui5_cl_cockpit_setup=>cs_mode-all
        tracking TYPE string DEFAULT z2ui5_cl_cockpit_setup=>cs_users-none.

    METHODS roundtrip
      IMPORTING
        ms            TYPE i
        event         TYPE string DEFAULT `SAVE`
        ts            TYPE timestampl DEFAULT '20990101101500.5000000'
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cockpit_rec=>ty_s_roundtrip.

    METHODS agg
      IMPORTING
        event         TYPE string DEFAULT `SAVE`
      RETURNING
        VALUE(result) TYPE z2ui5_t_ck_agg.

    METHODS log_rows
      RETURNING
        VALUE(result) TYPE ty_t_log.

ENDCLASS.


CLASS ltcl_rec IMPLEMENTATION.

  METHOD setup.

    use( ).
    CLEAR z2ui5_cl_cockpit_rec=>gt_buffer.

  ENDMETHOD.

  METHOD teardown.

    DATA lv_app TYPE z2ui5_t_ck_agg-app.
    lv_app = c_app.
    DELETE FROM z2ui5_t_ck_agg WHERE app = @lv_app.
    DELETE FROM z2ui5_t_ck_usr WHERE app = @lv_app.
    DELETE FROM z2ui5_t_ck_act WHERE app = @lv_app.
    DELETE FROM z2ui5_t_ck_log WHERE app = @lv_app.
    ROLLBACK WORK.                                       "#EC CI_ROLLBACK
    CLEAR z2ui5_cl_cockpit_rec=>gt_buffer.
    z2ui5_cl_cockpit_setup=>reset_buffer( ).

  ENDMETHOD.

  METHOD use.

    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-mode          = mode.
    ls_set-user_tracking = tracking.
    " purged today already - the test rows are not followed by a purge
    ls_set-last_purge    = c_day.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).

  ENDMETHOD.

  METHOD roundtrip.

    result = VALUE #( app            = c_app
                      event          = event
                      draft_id       = `NEW`
                      draft_id_prev  = `PREV`
                      uname          = `ALICE`
                      timestampl     = ts
                      ms_total       = ms
                      ms_load        = ms DIV 4
                      ms_main        = ms DIV 2
                      ms_render      = ms DIV 4
                      bytes_request  = 1024
                      bytes_response = 2048
                      bytes_model    = 4096 ).

  ENDMETHOD.

  METHOD agg.

    DATA lv_app TYPE z2ui5_t_ck_agg-app.
    DATA lv_day TYPE z2ui5_t_ck_agg-day.
    DATA lv_event TYPE z2ui5_t_ck_agg-event.
    lv_app = c_app.
    lv_day = c_day.
    lv_event = event.
    SELECT SINGLE * FROM z2ui5_t_ck_agg
      WHERE day   = @lv_day
        AND app   = @lv_app
        AND event = @lv_event
      INTO @result.
    IF sy-subrc <> 0.
      CLEAR result.
    ENDIF.

  ENDMETHOD.

  METHOD log_rows.

    DATA lv_app TYPE z2ui5_t_ck_log-app.
    lv_app = c_app.
    SELECT * FROM z2ui5_t_ck_log
      WHERE app = @lv_app
      ORDER BY timestampl
      INTO TABLE @result.

  ENDMETHOD.

  METHOD aggregates_one_hour.

    DATA(ls_first) = roundtrip( 120 ).
    ls_first-check_start = abap_true.
    z2ui5_cl_cockpit_rec=>write( ls_first ).
    DATA(ls_second) = roundtrip( 3000 ).
    ls_second-bytes_response = 1024.
    ls_second-bytes_model    = 8192.
    z2ui5_cl_cockpit_rec=>write( ls_second ).

    DATA(ls_agg) = agg( ).
    cl_abap_unit_assert=>assert_equals( exp = `10`
                                        act = ls_agg-hour ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_agg-cnt ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_agg-cnt_start ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = ls_agg-cnt_err ).
    " 3000 ms is at or above the default slow threshold of 2000 ms
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_agg-cnt_slow ).
    cl_abap_unit_assert=>assert_equals( exp = 3120
                                        act = ls_agg-ms_sum ).
    cl_abap_unit_assert=>assert_equals( exp = 1560
                                        act = ls_agg-ms_main ).
    cl_abap_unit_assert=>assert_equals( exp = 3000
                                        act = ls_agg-ms_max ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = ls_agg-kb_res ).
    cl_abap_unit_assert=>assert_equals( exp = 2048
                                        act = ls_agg-bytes_res_max ).
    cl_abap_unit_assert=>assert_equals( exp = 8192
                                        act = ls_agg-bytes_mod_max ).
    " 120 ms in the bucket 100-250, 3000 ms in 2000-5000
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_agg-h02 ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_agg-h06 ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = ls_agg-h01 ).

  ENDMETHOD.

  METHOD error_writes_log.

    DATA(ls_rt) = roundtrip( ms    = 50
                             event = `GO` ).
    ls_rt-check_error = abap_true.
    ls_rt-error_class = `CX_SY_ZERODIVIDE`.
    ls_rt-error_text  = |Division by zero{ cl_abap_char_utilities=>newline }raised in GO|.
    z2ui5_cl_cockpit_rec=>write( ls_rt ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = agg( `GO` )-cnt_err ).
    DATA(lt_log) = log_rows( ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_log ) ).
    DATA(ls_log) = lt_log[ 1 ].
    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = ls_log-check_error ).
    cl_abap_unit_assert=>assert_equals( exp = abap_false
                                        act = ls_log-check_slow ).
    cl_abap_unit_assert=>assert_equals( exp = `Division by zero`
                                        act = ls_log-error_head ).
    cl_abap_unit_assert=>assert_equals( exp = `PREV`
                                        act = ls_log-draft_id_prev ).
    cl_abap_unit_assert=>assert_equals( exp = c_day
                                        act = ls_log-day ).
    " user tracking NONE: neither a name nor a pseudonym
    cl_abap_unit_assert=>assert_initial( ls_log-uname ).
    cl_abap_unit_assert=>assert_initial( ls_log-user_key ).

  ENDMETHOD.

  METHOD slow_writes_log.

    z2ui5_cl_cockpit_rec=>write( roundtrip( 1999 ) ).
    cl_abap_unit_assert=>assert_initial( log_rows( ) ).

    z2ui5_cl_cockpit_rec=>write( roundtrip( 2000 ) ).
    DATA(lt_log) = log_rows( ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_log ) ).
    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = lt_log[ 1 ]-check_slow ).
    cl_abap_unit_assert=>assert_equals( exp = 1000
                                        act = lt_log[ 1 ]-ms_main ).

  ENDMETHOD.

  METHOD name_mode_keeps_user.

    DATA lv_count TYPE i.
    DATA lv_app TYPE z2ui5_t_ck_usr-app.
    DATA lv_day TYPE z2ui5_t_ck_usr-day.

    use( tracking = z2ui5_cl_cockpit_setup=>cs_users-name ).
    DATA(ls_rt) = roundtrip( 10 ).
    ls_rt-check_error = abap_true.
    z2ui5_cl_cockpit_rec=>write( ls_rt ).

    DATA(lt_log) = log_rows( ).
    cl_abap_unit_assert=>assert_equals( exp = `ALICE`
                                        act = lt_log[ 1 ]-uname ).

    lv_app = c_app.
    lv_day = c_day.
    SELECT COUNT( * ) FROM z2ui5_t_ck_usr
      WHERE app = @lv_app
        AND day = @lv_day
      INTO @lv_count.
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lv_count ).

  ENDMETHOD.

  METHOD errors_mode_skips_success.

    use( mode = z2ui5_cl_cockpit_setup=>cs_mode-errors ).
    z2ui5_cl_cockpit_rec=>write( roundtrip( 100 ) ).
    cl_abap_unit_assert=>assert_initial( agg( ) ).

    DATA(ls_rt) = roundtrip( 100 ).
    ls_rt-check_error = abap_true.
    z2ui5_cl_cockpit_rec=>write( ls_rt ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = agg( )-cnt ).

  ENDMETHOD.

  METHOD sample_mode_weights.

    " SAMPLE with 10 %: the milliseconds of the start decide - 5 is in the
    " sample and counts 10 times, 55 is not recorded at all
    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-mode          = z2ui5_cl_cockpit_setup=>cs_mode-sample.
    ls_set-sample_pct    = 10.
    ls_set-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-none.
    ls_set-last_purge    = c_day.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).

    z2ui5_cl_cockpit_rec=>write( roundtrip( ms = 100
                                            ts = '20990101101500.0550000' ) ).
    cl_abap_unit_assert=>assert_initial( agg( ) ).

    z2ui5_cl_cockpit_rec=>write( roundtrip( ms = 100
                                            ts = '20990101101500.0050000' ) ).
    DATA(ls_agg) = agg( ).
    cl_abap_unit_assert=>assert_equals( exp = 10
                                        act = ls_agg-cnt ).
    cl_abap_unit_assert=>assert_equals( exp = 1000
                                        act = ls_agg-ms_sum ).
    cl_abap_unit_assert=>assert_equals( exp = 10
                                        act = ls_agg-h02 ).

  ENDMETHOD.

  METHOD off_mode_writes_nothing.

    use( mode = z2ui5_cl_cockpit_setup=>cs_mode-off ).
    DATA(ls_rt) = roundtrip( 5000 ).
    ls_rt-check_error = abap_true.
    z2ui5_cl_cockpit_rec=>write( ls_rt ).
    cl_abap_unit_assert=>assert_initial( agg( ) ).
    cl_abap_unit_assert=>assert_initial( log_rows( ) ).

  ENDMETHOD.

  METHOD sticky_is_buffered.

    " a sticky roundtrip owns the LUW: nothing is written, nothing committed
    DATA(ls_rt) = roundtrip( 100 ).
    ls_rt-check_sticky = abap_true.
    z2ui5_cl_cockpit_rec=>record( ls_rt ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( z2ui5_cl_cockpit_rec=>gt_buffer ) ).
    cl_abap_unit_assert=>assert_initial( agg( ) ).

  ENDMETHOD.

  METHOD sums_saturate.

    cl_abap_unit_assert=>assert_equals( exp = 1000
                                        act = z2ui5_cl_cockpit_rec=>sum_inc( val    = 100
                                                                             weight = 10 ) ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = z2ui5_cl_cockpit_rec=>sum_inc( val    = -5
                                                                             weight = 1 ) ).
    " 2147483647 * 1000000 is beyond DEC 15 - saturated, not an overflow
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_rec=>c_dec_max
                                        act = z2ui5_cl_cockpit_rec=>sum_inc( val    = 2147483647
                                                                             weight = 1000000 ) ).

  ENDMETHOD.

ENDCLASS.
