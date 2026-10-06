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

    DATA lt_log TYPE z2ui5_cl_cockpit_stats=>ty_t_err_log.

    " newest first, as the SELECT delivers them
    lt_log = VALUE #( ( timestampl  = '20990101120000'
                        app         = c_app
                        event       = `SAVE`
                        error_class = `CX_SY_ZERODIVIDE`
                        error_head  = `Division by zero` )
                      ( timestampl  = '20990101110000'
                        app         = c_app
                        event       = `SAVE`
                        error_class = `CX_SY_ITAB_LINE_NOT_FOUND`
                        error_head  = `Line not found` )
                      ( timestampl  = '20990101100000'
                        app         = c_app
                        event       = `SAVE`
                        error_class = `CX_SY_ZERODIVIDE`
                        error_head  = `Division by zero` ) ).

    DATA(lt_error) = z2ui5_cl_cockpit_stats=>group_errors( lt_log ).

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

    DATA lt_log TYPE z2ui5_cl_cockpit_stats=>ty_t_err_log.

    lt_log = VALUE #( ( timestampl  = '20990101120000'
                        app         = c_app
                        event       = `B`
                        error_class = `CX_B`
                        error_head  = `b` )
                      ( timestampl  = '20990101110000'
                        app         = c_app
                        event       = `A`
                        error_class = `CX_A`
                        error_head  = `a` ) ).

    DATA(lt_error) = z2ui5_cl_cockpit_stats=>group_errors( lt_log ).

    cl_abap_unit_assert=>assert_equals( exp = `B`
                                        act = lt_error[ 1 ]-event ).
    cl_abap_unit_assert=>assert_equals( exp = `A`
                                        act = lt_error[ 2 ]-event ).

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
