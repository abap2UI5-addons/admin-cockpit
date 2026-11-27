CLASS ltcl_stats DEFINITION DEFERRED.
CLASS ltcl_stats_db DEFINITION DEFERRED.
CLASS z2ui5_cl_cockpit_stats DEFINITION LOCAL FRIENDS ltcl_stats ltcl_stats_db.

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
    METHODS phase_dominant FOR TESTING.
    METHODS phase_unknown_without_hook FOR TESTING.
    METHODS window_across_midnight FOR TESTING.
    METHODS window_no_app_named FOR TESTING.
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

    INSERT VALUE #( app     = c_app
                    cnt     = 100
                    h01     = 100
                    ms_sum  = 5000
                    ms_load = 500
                    mod_max = 2048
                    res_max = 4096 ) INTO TABLE lt_new.

    DATA(lt_hint) = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_initial( lt_hint ).

  ENDMETHOD.

  METHOD hints_large_model.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    INSERT VALUE #( app     = c_app
                    cnt     = 1
                    h01     = 1
                    mod_max = 2 * 1024 * 1024
                    res_max = 600 * 1024 ) INTO TABLE lt_new.

    DATA(lt_hint) = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_true( hint_exists( it_hint = lt_hint
                                                   hint    = `Large model` ) ).
    cl_abap_unit_assert=>assert_true( hint_exists( it_hint = lt_hint
                                                   hint    = `Large response` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `2048 KB`
                                        act = lt_hint[ hint = `Large model` ]-value ). "#EC CI_SORTSEQ

  ENDMETHOD.

  METHOD hints_slow_p95_needs_volume.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    " ten slow roundtrips are too few to judge
    INSERT VALUE #( app = c_app
                    cnt = 10
                    h06 = 10 ) INTO TABLE lt_new.
    DATA(lt_hint) = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_false( hint_exists( it_hint = lt_hint
                                                    hint    = `Slow p95` ) ).

    " twenty are enough - p95 = 2000 + 3000 * 19 / 20
    CLEAR lt_new.
    INSERT VALUE #( app = c_app
                    cnt = 20
                    h06 = 20 ) INTO TABLE lt_new.
    lt_hint = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                it_old   = lt_old
                                                is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_equals( exp = `4850 ms`
                                        act = lt_hint[ hint = `Slow p95` ]-value ). "#EC CI_SORTSEQ

  ENDMETHOD.

  METHOD hints_error_rate.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    " 1 of 40 is 2.5 % - no hint; the older half adds another error: 5 %
    INSERT VALUE #( app     = c_app
                    cnt     = 20
                    cnt_err = 1
                    h01     = 20 ) INTO TABLE lt_new.
    INSERT VALUE #( app     = c_app
                    cnt     = 20
                    h01     = 20 ) INTO TABLE lt_old.
    DATA(lt_hint) = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_false( hint_exists( it_hint = lt_hint
                                                    hint    = `Error rate of 5 % or more` ) ).

    CLEAR lt_old.
    INSERT VALUE #( app     = c_app
                    cnt     = 20
                    cnt_err = 1
                    h01     = 20 ) INTO TABLE lt_old.
    lt_hint = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                it_old   = lt_old
                                                is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                is_draft = ls_draft ).
    DATA(ls_hint) = lt_hint[ hint = `Error rate of 5 % or more` ]. "#EC CI_SORTSEQ
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = ls_hint-state ).
    cl_abap_unit_assert=>assert_equals( exp = `2 of 40`
                                        act = ls_hint-value ).

  ENDMETHOD.

  METHOD hints_growing_state.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    INSERT VALUE #( app     = c_app
                    cnt     = 1
                    h01     = 1
                    mod_max = 200 * 1024 ) INTO TABLE lt_old.
    INSERT VALUE #( app     = c_app
                    cnt     = 1
                    h01     = 1
                    mod_max = 400 * 1024 ) INTO TABLE lt_new.

    DATA(lt_hint) = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_equals( exp = `200 KB to 400 KB`
                                        act = lt_hint[ hint = `Growing app state` ]-value ). "#EC CI_SORTSEQ
    cl_abap_unit_assert=>assert_false( hint_exists( it_hint = lt_hint
                                                    hint    = `Large model` ) ).

  ENDMETHOD.

  METHOD hints_load_dominates.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    INSERT VALUE #( app     = c_app
                    cnt     = 20
                    h01     = 20
                    ms_sum  = 1000
                    ms_load = 600
                    ms_main = 400 ) INTO TABLE lt_new.

    DATA(lt_hint) = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_equals( exp = `60 % of the time`
                                        act = lt_hint[ hint = `Load phase dominates` ]-value ). "#EC CI_SORTSEQ
    cl_abap_unit_assert=>assert_false( hint_exists( it_hint = lt_hint
                                                    hint    = `Render phase dominates` ) ).

  ENDMETHOD.

  METHOD hints_draft_backlog.

    DATA lt_new TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA lt_old TYPE z2ui5_cl_cockpit_stats=>ty_t_sum_app.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.

    ls_draft-check_backlog = abap_true.
    ls_draft-rows_expired  = 12.
    ls_draft-oldest        = `2099-01-01 10:00:00`.
    ls_draft-rows          = 100001.

    DATA(lt_hint) = z2ui5_cl_cockpit_stats=>hints_of( it_new   = lt_new
                                                      it_old   = lt_old
                                                      is_set   = z2ui5_cl_cockpit_setup=>get_default( )
                                                      is_draft = ls_draft ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_hint ) ).
    cl_abap_unit_assert=>assert_equals( exp = `12 expired, oldest 2099-01-01 10:00:00`
                                        act = lt_hint[ hint = `Expired drafts are not deleted` ]-value ). "#EC CI_SORTSEQ
    cl_abap_unit_assert=>assert_true( hint_exists( it_hint = lt_hint
                                                   hint    = `Large draft table` ) ).

  ENDMETHOD.

  METHOD errors_grouped.

    DATA lt_group TYPE z2ui5_cl_cockpit_stats=>ty_t_err_group.

    " as the database counts them - in no particular order
    lt_group = VALUE #( ( app         = c_app
                          event       = `SAVE`
                          error_class = `CX_SY_ITAB_LINE_NOT_FOUND`
                          error_head  = `Line not found`
                          cnt         = 1
                          first_ts    = '20990101110000'
                          last_ts     = '20990101110000' )
                        ( app         = c_app
                          event       = `SAVE`
                          error_class = `CX_SY_ZERODIVIDE`
                          error_head  = `Division by zero`
                          cnt         = 2
                          first_ts    = '20990101100000'
                          last_ts     = '20990101120000' ) ).

    DATA(lt_error) = z2ui5_cl_cockpit_stats=>errors_of( lt_group ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_error ) ).
    DATA(ls_first) = lt_error[ 1 ].
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
    DATA(ls_second) = lt_error[ 2 ].
    cl_abap_unit_assert=>assert_equals( exp = `G2`
                                        act = ls_second-key ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_second-count ).
    cl_abap_unit_assert=>assert_equals( exp = ls_second-first_seen
                                        act = ls_second-last_seen ).

  ENDMETHOD.

  METHOD errors_tie_keeps_newest_first.

    DATA lt_group TYPE z2ui5_cl_cockpit_stats=>ty_t_err_group.

    lt_group = VALUE #( ( app         = c_app
                          event       = `A`
                          error_class = `CX_A`
                          error_head  = `a`
                          cnt         = 1
                          first_ts    = '20990101110000'
                          last_ts     = '20990101110000' )
                        ( app         = c_app
                          event       = `B`
                          error_class = `CX_B`
                          error_head  = `b`
                          cnt         = 1
                          first_ts    = '20990101120000'
                          last_ts     = '20990101120000' ) ).

    DATA(lt_error) = z2ui5_cl_cockpit_stats=>errors_of( lt_group ).

    cl_abap_unit_assert=>assert_equals( exp = `B`
                                        act = lt_error[ 1 ]-event ).
    cl_abap_unit_assert=>assert_equals( exp = `A`
                                        act = lt_error[ 2 ]-event ).

  ENDMETHOD.

  METHOD phase_dominant.

    cl_abap_unit_assert=>assert_equals( exp = `main - the app's own code`
                                        act = z2ui5_cl_cockpit_stats=>phase_of( ms_load   = 10
                                                                                ms_main   = 900
                                                                                ms_render = 20 ) ).
    cl_abap_unit_assert=>assert_equals( exp = `load - draft read and deserialize`
                                        act = z2ui5_cl_cockpit_stats=>phase_of( ms_load   = 900
                                                                                ms_main   = 10
                                                                                ms_render = 20 ) ).
    cl_abap_unit_assert=>assert_equals( exp = `render - serialize and draft save`
                                        act = z2ui5_cl_cockpit_stats=>phase_of( ms_load   = 10
                                                                                ms_main   = 10
                                                                                ms_render = 900 ) ).

  ENDMETHOD.

  METHOD phase_unknown_without_hook.

    " recorded by the HTTP handler: the total only, no phase is blamed
    DATA(lv_phase) = z2ui5_cl_cockpit_stats=>phase_of( ms_load   = 0
                                                       ms_main   = 0
                                                       ms_render = 0 ).

    cl_abap_unit_assert=>assert_char_cp( exp = `unknown*`
                                         act = lv_phase ).

  ENDMETHOD.

  METHOD window_across_midnight.

    DATA lt_rows TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA lv_from TYPE timestampl.

    " the hours 22 and 23 of the day before, 00 and 01 of the day - the
    " window starts within hour 23 of the day before
    lt_rows = VALUE #( app = c_app
                       ( utc_day = `20981231` utc_hour = `22` cnt = 100 cnt_err = 50 )
                       ( utc_day = `20981231` utc_hour = `23` cnt = 10 cnt_err = 1 )
                       ( utc_day = `20990101` utc_hour = `00` cnt = 20 cnt_err = 2 )
                       ( utc_day = `20990101` utc_hour = `01` cnt = 30 cnt_err = 3 ) ).

    lv_from = '20981231233000'.
    DATA(lt_window) = z2ui5_cl_cockpit_stats=>window_of( it_rows = lt_rows
                                                         from_ts = lv_from ).

    " the line over all apps first, then the app
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_window ) ).
    cl_abap_unit_assert=>assert_initial( lt_window[ 1 ]-app ).
    cl_abap_unit_assert=>assert_equals( exp = 60
                                        act = lt_window[ 1 ]-roundtrips ).
    cl_abap_unit_assert=>assert_equals( exp = 6
                                        act = lt_window[ 1 ]-errors ).
    cl_abap_unit_assert=>assert_equals( exp = c_app
                                        act = lt_window[ 2 ]-app ).
    cl_abap_unit_assert=>assert_equals( exp = 60
                                        act = lt_window[ 2 ]-roundtrips ).

    " the same rows, the window starting on the day itself
    lv_from = '20990101010000'.
    lt_window = z2ui5_cl_cockpit_stats=>window_of( it_rows = lt_rows
                                                   from_ts = lv_from ).
    cl_abap_unit_assert=>assert_equals( exp = 30
                                        act = lt_window[ 1 ]-roundtrips ).

  ENDMETHOD.

  METHOD window_no_app_named.

    DATA lt_rows TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA lv_from TYPE timestampl.

    lt_rows = VALUE #( ( utc_day = `20990101` utc_hour = `10` cnt = 5 ) ).

    lv_from = '20990101100000'.
    DATA(lt_window) = z2ui5_cl_cockpit_stats=>window_of( it_rows = lt_rows
                                                         from_ts = lv_from ).

    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_stats=>c_no_app
                                        act = lt_window[ 2 ]-app ).

  ENDMETHOD.

  METHOD unused_apps.

    DATA lt_last TYPE z2ui5_cl_cockpit_stats=>ty_t_last.

    DATA(lt_impl) = VALUE z2ui5_cl_cockpit_setup=>ty_t_names( ( `ZZ_APP_OLD` )
                                                              ( `ZZ_APP_RECENT` )
                                                              ( `ZZ_APP_NEVER` ) ).
    INSERT VALUE #( app     = `ZZ_APP_OLD`
                    utc_day = `20260101` ) INTO TABLE lt_last.
    INSERT VALUE #( app     = `ZZ_APP_RECENT`
                    utc_day = `20261001` ) INTO TABLE lt_last.

    DATA(lt_unused) = z2ui5_cl_cockpit_stats=>unused_of( it_impl  = lt_impl
                                                         it_last  = lt_last
                                                         from_day = `20260701` ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_unused ) ).
    cl_abap_unit_assert=>assert_equals( exp = `2026-01-01`
                                        act = lt_unused[ app = `ZZ_APP_OLD` ]-last_used ). "#EC CI_SORTSEQ
    cl_abap_unit_assert=>assert_equals( exp = `never recorded`
                                        act = lt_unused[ app = `ZZ_APP_NEVER` ]-last_used ). "#EC CI_SORTSEQ
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( lt_unused[ app = `ZZ_APP_RECENT` ] ) ) ). "#EC CI_SORTSEQ

  ENDMETHOD.

  METHOD hint_exists.

    result = xsdbool( line_exists( it_hint[ hint = hint ] ) ). "#EC CI_SORTSEQ

  ENDMETHOD.

ENDCLASS.


"! The error log read for real: rows of a test app on a day in 2099,
"! deleted again in teardown and rolled back - nothing is committed.
CLASS ltcl_stats_db DEFINITION FINAL FOR TESTING RISK LEVEL DANGEROUS DURATION SHORT.

  PRIVATE SECTION.

    CONSTANTS c_app TYPE string VALUE `ZZ_COCKPIT_UNIT_TEST`.

    METHODS teardown.

    METHODS errors_flood_keeps_other_group FOR TESTING.

ENDCLASS.


CLASS ltcl_stats_db IMPLEMENTATION.

  METHOD teardown.

    DATA(lv_app) = CONV z2ui5_t_25-app( c_app ).
    DELETE FROM z2ui5_t_25 WHERE app = @lv_app.
    ROLLBACK WORK.                                       "#EC CI_ROLLBACK

  ENDMETHOD.

  METHOD errors_flood_keeps_other_group.

    DATA lt_log TYPE STANDARD TABLE OF z2ui5_t_25 WITH EMPTY KEY.
    DATA lv_ts TYPE timestampl.
    DATA lv_end TYPE timestampl.

    " one error more often than a row limit of 5000 would read, all of it
    " newer than the one occurrence of a second error
    lv_end = '20990101120000'.
    lv_ts = '20990101100000'.
    APPEND VALUE #( id          = `ZZCKUTERR0`
                    timestampl  = lv_ts
                    utc_day     = `20990101`
                    app         = c_app
                    event       = `OTHER`
                    check_error = abap_true
                    error_class = `CX_SY_ITAB_LINE_NOT_FOUND`
                    error_head  = `Line not found` ) TO lt_log.
    DO 5001 TIMES.
      lv_ts = z2ui5_cl_cockpit_setup=>ts_minus_seconds( ts      = lv_end
                                                        seconds = sy-index ).
      APPEND VALUE #( id          = |ZZCKUTERR{ sy-index }|
                      timestampl  = lv_ts
                      utc_day     = `20990101`
                      app         = c_app
                      event       = `POLL`
                      check_error = abap_true
                      error_class = `CX_SY_ZERODIVIDE`
                      error_head  = `Division by zero` ) TO lt_log.
    ENDDO.
    INSERT z2ui5_t_25 FROM TABLE @lt_log.

    DATA(lt_error) = z2ui5_cl_cockpit_stats=>get_errors( 1 ).
    DELETE lt_error WHERE app <> c_app.

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_error ) ).
    DATA(ls_flood) = lt_error[ 1 ].
    cl_abap_unit_assert=>assert_equals( exp = `POLL`
                                        act = ls_flood-event ).
    cl_abap_unit_assert=>assert_equals( exp = 5001
                                        act = ls_flood-count ).
    cl_abap_unit_assert=>assert_equals( exp = `2099-01-01 10:36:39`
                                        act = ls_flood-first_seen ).
    cl_abap_unit_assert=>assert_equals( exp = `OTHER`
                                        act = lt_error[ 2 ]-event ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lt_error[ 2 ]-count ).

  ENDMETHOD.

ENDCLASS.
