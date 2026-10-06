CLASS ltcl_privacy DEFINITION DEFERRED.
CLASS ltcl_salt DEFINITION DEFERRED.
CLASS z2ui5_cl_cockpit_setup DEFINITION LOCAL FRIENDS ltcl_privacy ltcl_salt.

"! The user key per privacy mode and the latency buckets - settings and the
"! day's salt are put into the roll-area buffer, nothing is read or written.
CLASS ltcl_privacy DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    METHODS teardown.

    METHODS name_mode FOR TESTING.
    METHODS none_mode FOR TESTING.
    METHODS hash_mode_known_vector FOR TESTING.
    METHODS hash_mode_differs_per_day FOR TESTING.
    METHODS hash_mode_without_name FOR TESTING.
    METHODS hash_mode_ignores_case FOR TESTING.
    METHODS buckets FOR TESTING.
    METHODS alert_settings FOR TESTING.
    METHODS ts_minus_seconds FOR TESTING.
    METHODS assert_minus
      IMPORTING
        ts      TYPE string
        seconds TYPE i
        exp     TYPE string.

    METHODS use
      IMPORTING
        tracking TYPE string.

ENDCLASS.


CLASS ltcl_privacy IMPLEMENTATION.

  METHOD teardown.

    z2ui5_cl_cockpit_setup=>reset_buffer( ).
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt_day.
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt.

  ENDMETHOD.

  METHOD use.

    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-user_tracking = tracking.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).

  ENDMETHOD.

  METHOD name_mode.

    use( z2ui5_cl_cockpit_setup=>cs_users-name ).
    cl_abap_unit_assert=>assert_equals( exp = `ALICE`
                                        act = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                                                day   = `20990101` ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_cockpit_setup=>check_privacy( ) ).

  ENDMETHOD.

  METHOD none_mode.

    use( z2ui5_cl_cockpit_setup=>cs_users-none ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                                           day   = `20990101` ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_cockpit_setup=>check_privacy( ) ).

  ENDMETHOD.

  METHOD hash_mode_known_vector.

    " SHA-256 of salt and upper-cased name: AB + C = ABC
    use( z2ui5_cl_cockpit_setup=>cs_users-hash ).
    z2ui5_cl_cockpit_setup=>gv_salt_day = `20990101`.
    z2ui5_cl_cockpit_setup=>gv_salt     = `AB`.

    DATA(lv_key) = z2ui5_cl_cockpit_setup=>user_key( uname = `c`
                                                     day   = `20990101` ).

    cl_abap_unit_assert=>assert_equals( exp = `B5D4045C3F466FA91FE2CC6ABE79232A1A57CDF104F7A26E716E0A1E2789DF78`
                                        act = to_upper( lv_key ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_cockpit_setup=>check_privacy( ) ).

  ENDMETHOD.

  METHOD hash_mode_differs_per_day.

    use( z2ui5_cl_cockpit_setup=>cs_users-hash ).
    z2ui5_cl_cockpit_setup=>gv_salt_day = `20990101`.
    z2ui5_cl_cockpit_setup=>gv_salt     = `SALT-OF-DAY-ONE`.
    DATA(lv_day1) = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                      day   = `20990101` ).
    DATA(lv_day1_again) = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                            day   = `20990101` ).

    z2ui5_cl_cockpit_setup=>gv_salt_day = `20990102`.
    z2ui5_cl_cockpit_setup=>gv_salt     = `SALT-OF-DAY-TWO`.
    DATA(lv_day2) = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                      day   = `20990102` ).

    cl_abap_unit_assert=>assert_equals( exp = lv_day1
                                        act = lv_day1_again ).
    cl_abap_unit_assert=>assert_differs( exp = lv_day1
                                         act = lv_day2 ).

  ENDMETHOD.

  METHOD hash_mode_without_name.

    use( z2ui5_cl_cockpit_setup=>cs_users-hash ).
    z2ui5_cl_cockpit_setup=>gv_salt_day = `20990101`.
    z2ui5_cl_cockpit_setup=>gv_salt     = `SALT`.

    DATA(lv_key) = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                     day   = `20990101` ).

    cl_abap_unit_assert=>assert_equals( exp = 64
                                        act = strlen( lv_key ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( to_upper( lv_key ) CS `ALICE` ) ).

  ENDMETHOD.

  METHOD hash_mode_ignores_case.

    use( z2ui5_cl_cockpit_setup=>cs_users-hash ).
    z2ui5_cl_cockpit_setup=>gv_salt_day = `20990101`.
    z2ui5_cl_cockpit_setup=>gv_salt     = `SALT`.

    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                                                day   = `20990101` )
                                        act = z2ui5_cl_cockpit_setup=>user_key( uname = `alice`
                                                                                day   = `20990101` ) ).

  ENDMETHOD.

  METHOD buckets.

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = z2ui5_cl_cockpit_setup=>bucket_index( 0 ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = z2ui5_cl_cockpit_setup=>bucket_index( 99 ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = z2ui5_cl_cockpit_setup=>bucket_index( 100 ) ).
    cl_abap_unit_assert=>assert_equals( exp = 5
                                        act = z2ui5_cl_cockpit_setup=>bucket_index( 1999 ) ).
    cl_abap_unit_assert=>assert_equals( exp = 8
                                        act = z2ui5_cl_cockpit_setup=>bucket_index( 29999 ) ).
    cl_abap_unit_assert=>assert_equals( exp = 9
                                        act = z2ui5_cl_cockpit_setup=>bucket_index( 30000 ) ).
    cl_abap_unit_assert=>assert_equals( exp = 9
                                        act = z2ui5_cl_cockpit_setup=>bucket_index( 999999 ) ).

  ENDMETHOD.

  METHOD alert_settings.

    " 0 keeps a threshold switched off through a save; out of range falls back
    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-alert_err_pct = 0.
    ls_set-alert_p95_ms  = -1.
    ls_set-alert_min_cnt = 0.
    ls_set-alert_hours   = 24.

    z2ui5_cl_cockpit_setup=>check_alerts( CHANGING cs_set = ls_set ).

    DATA(ls_def) = z2ui5_cl_cockpit_setup=>get_default( ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = ls_set-alert_err_pct ).
    cl_abap_unit_assert=>assert_equals( exp = ls_def-alert_p95_ms
                                        act = ls_set-alert_p95_ms ).
    cl_abap_unit_assert=>assert_equals( exp = ls_def-alert_min_cnt
                                        act = ls_set-alert_min_cnt ).
    cl_abap_unit_assert=>assert_equals( exp = ls_def-alert_hours
                                        act = ls_set-alert_hours ).

  ENDMETHOD.

  METHOD ts_minus_seconds.

    " within the day, across midnight, across a month and a year, whole days
    assert_minus( ts      = '20990315103000'
                  seconds = 10
                  exp     = '20990315102950' ).
    assert_minus( ts      = '20990101000010'
                  seconds = 20
                  exp     = '20981231235950' ).
    assert_minus( ts      = '20990301120000'
                  seconds = 2 * 86400
                  exp     = '20990227120000' ).
    assert_minus( ts      = '20990301000000'
                  seconds = 86400 + 3600
                  exp     = '20990227230000' ).

  ENDMETHOD.

  METHOD assert_minus.

    DATA lv_ts TYPE timestampl.
    DATA lv_exp TYPE timestampl.
    lv_ts = ts.
    lv_exp = exp.
    cl_abap_unit_assert=>assert_equals( exp = lv_exp
                                        act = z2ui5_cl_cockpit_setup=>ts_minus_seconds( ts      = lv_ts
                                                                                       seconds = seconds ) ).

  ENDMETHOD.

ENDCLASS.


"! The daily salt rotation, against Z2UI5_T_CK_SET: test days in the year
"! 2099, nothing committed - teardown deletes the test rows and rolls back,
"! which also brings back the salt of today that the rotation deletes.
CLASS ltcl_salt DEFINITION FINAL FOR TESTING RISK LEVEL DANGEROUS DURATION SHORT.

  PRIVATE SECTION.

    METHODS setup.
    METHODS teardown.

    METHODS salt_rotates_daily FOR TESTING.

    METHODS salt_exists
      IMPORTING
        day           TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

ENDCLASS.


CLASS ltcl_salt IMPLEMENTATION.

  METHOD setup.

    z2ui5_cl_cockpit_setup=>set_buffer( z2ui5_cl_cockpit_setup=>get_default( ) ).
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt_day.
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt.

  ENDMETHOD.

  METHOD teardown.

    DATA lv_pattern TYPE z2ui5_t_ck_set-name.
    lv_pattern = `SALT_2099%`.
    DELETE FROM z2ui5_t_ck_set WHERE name LIKE @lv_pattern.
    ROLLBACK WORK.                                       "#EC CI_ROLLBACK
    z2ui5_cl_cockpit_setup=>reset_buffer( ).
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt_day.
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt.

  ENDMETHOD.

  METHOD salt_rotates_daily.

    DATA(lv_day1) = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                      day   = `20990101` ).
    cl_abap_unit_assert=>assert_equals( exp = 64
                                        act = strlen( lv_day1 ) ).
    cl_abap_unit_assert=>assert_true( salt_exists( `20990101` ) ).

    " a second roll area reads the same salt back from the database
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt_day.
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt.
    cl_abap_unit_assert=>assert_equals( exp = lv_day1
                                        act = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                                                day   = `20990101` ) ).

    " the next day: a new salt, a new pseudonym, and the old salt is gone
    DATA(lv_day2) = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                      day   = `20990102` ).
    cl_abap_unit_assert=>assert_differs( exp = lv_day1
                                         act = lv_day2 ).
    cl_abap_unit_assert=>assert_true( salt_exists( `20990102` ) ).
    cl_abap_unit_assert=>assert_false( salt_exists( `20990101` ) ).

  ENDMETHOD.

  METHOD salt_exists.

    DATA lv_value TYPE z2ui5_t_ck_set-value.
    DATA(lv_name) = CONV z2ui5_t_ck_set-name( |SALT_{ day }| ).
    SELECT SINGLE value FROM z2ui5_t_ck_set
      WHERE name = @lv_name
      INTO @lv_value.
    result = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.

ENDCLASS.
