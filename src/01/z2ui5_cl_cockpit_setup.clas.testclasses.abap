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
    METHODS settings_bounds FOR TESTING.
    METHODS sample_share_divides_100 FOR TESTING.
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

    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    ls_set = z2ui5_cl_cockpit_setup=>get_default( ).
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
    DATA lv_key TYPE string.

    " SHA-256 of salt and upper-cased name: AB + C = ABC
    use( z2ui5_cl_cockpit_setup=>cs_users-hash ).
    z2ui5_cl_cockpit_setup=>gv_salt_day = `20990101`.
    z2ui5_cl_cockpit_setup=>gv_salt     = `AB`.


    lv_key = z2ui5_cl_cockpit_setup=>user_key( uname = `c`
                                                     day   = `20990101` ).

    cl_abap_unit_assert=>assert_equals( exp = `B5D4045C3F466FA91FE2CC6ABE79232A1A57CDF104F7A26E716E0A1E2789DF78`
                                        act = to_upper( lv_key ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_cockpit_setup=>check_privacy( ) ).

  ENDMETHOD.

  METHOD hash_mode_differs_per_day.
    DATA lv_day1 TYPE string.
    DATA lv_day1_again TYPE string.
    DATA lv_day2 TYPE string.

    use( z2ui5_cl_cockpit_setup=>cs_users-hash ).
    z2ui5_cl_cockpit_setup=>gv_salt_day = `20990101`.
    z2ui5_cl_cockpit_setup=>gv_salt     = `SALT-OF-DAY-ONE`.

    lv_day1 = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                      day   = `20990101` ).

    lv_day1_again = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                            day   = `20990101` ).

    z2ui5_cl_cockpit_setup=>gv_salt_day = `20990102`.
    z2ui5_cl_cockpit_setup=>gv_salt     = `SALT-OF-DAY-TWO`.

    lv_day2 = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                      day   = `20990102` ).

    cl_abap_unit_assert=>assert_equals( exp = lv_day1
                                        act = lv_day1_again ).
    cl_abap_unit_assert=>assert_differs( exp = lv_day1
                                         act = lv_day2 ).

  ENDMETHOD.

  METHOD hash_mode_without_name.
    DATA lv_key TYPE string.
    DATA temp1 TYPE xsdboolean.

    use( z2ui5_cl_cockpit_setup=>cs_users-hash ).
    z2ui5_cl_cockpit_setup=>gv_salt_day = `20990101`.
    z2ui5_cl_cockpit_setup=>gv_salt     = `SALT`.


    lv_key = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                     day   = `20990101` ).

    cl_abap_unit_assert=>assert_equals( exp = 64
                                        act = strlen( lv_key ) ).

    temp1 = boolc( to_upper( lv_key ) CS `ALICE` ).
    cl_abap_unit_assert=>assert_false( temp1 ).

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
    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA ls_def TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    ls_set = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-alert_err_pct = 0.
    ls_set-alert_p95_ms  = -1.
    ls_set-alert_min_cnt = 0.
    ls_set-alert_hours   = 24.

    z2ui5_cl_cockpit_setup=>check_alerts( CHANGING cs_set = ls_set ).


    ls_def = z2ui5_cl_cockpit_setup=>get_default( ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = ls_set-alert_err_pct ).
    cl_abap_unit_assert=>assert_equals( exp = ls_def-alert_p95_ms
                                        act = ls_set-alert_p95_ms ).
    cl_abap_unit_assert=>assert_equals( exp = ls_def-alert_min_cnt
                                        act = ls_set-alert_min_cnt ).
    cl_abap_unit_assert=>assert_equals( exp = ls_def-alert_hours
                                        act = ls_set-alert_hours ).

  ENDMETHOD.

  METHOD settings_bounds.

    " a day setting no date can hold and a size no INT4 byte count can hold
    " are cut - the housekeeping and the hints compute with them
    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA temp2 TYPE xsdboolean.
    ls_set = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-retention_days     = 99999.
    ls_set-agg_retention_days = 0.
    ls_set-wire_days          = 2147483647.
    ls_set-model_warn_kb      = 2147483647.

    z2ui5_cl_cockpit_setup=>check_settings( CHANGING cs_set = ls_set ).

    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_setup=>c_max_days
                                        act = ls_set-retention_days ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_setup=>get_default( )-agg_retention_days
                                        act = ls_set-agg_retention_days ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_setup=>c_max_days
                                        act = ls_set-wire_days ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_setup=>c_max_kb
                                        act = ls_set-model_warn_kb ).
    " and the longest retention is still a date

    temp2 = boolc( z2ui5_cl_cockpit_setup=>now_minus_days( ls_set-wire_days ) < z2ui5_cl_cockpit_setup=>now( ) ).
    cl_abap_unit_assert=>assert_true( temp2 ).

  ENDMETHOD.

  METHOD sample_share_divides_100.

    " each recorded sample counts 100 / pct times, in whole numbers - a
    " share that does not divide 100 is rounded down to one that does
    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    ls_set = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-sample_pct = 60.
    z2ui5_cl_cockpit_setup=>check_settings( CHANGING cs_set = ls_set ).
    cl_abap_unit_assert=>assert_equals( exp = 50
                                        act = ls_set-sample_pct ).
    ls_set-sample_pct = 3.
    z2ui5_cl_cockpit_setup=>check_settings( CHANGING cs_set = ls_set ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_set-sample_pct ).
    ls_set-sample_pct = 25.
    z2ui5_cl_cockpit_setup=>check_settings( CHANGING cs_set = ls_set ).
    cl_abap_unit_assert=>assert_equals( exp = 25
                                        act = ls_set-sample_pct ).

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


"! The daily salt rotation and the claim of the daily purge, against
"! Z2UI5_T_26: test days in the year 2099, nothing committed - teardown
"! deletes the test rows and rolls back, which also brings back the salt of
"! today that the rotation deletes and the day of the last purge.
CLASS ltcl_salt DEFINITION FINAL FOR TESTING RISK LEVEL DANGEROUS DURATION SHORT.

  PRIVATE SECTION.

    METHODS setup.
    METHODS teardown.

    METHODS salt_rotates_daily FOR TESTING.
    METHODS no_salt_for_a_past_day FOR TESTING.
    METHODS purge_claimed_once FOR TESTING.
    METHODS old_salts_deleted FOR TESTING.

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

    DATA lv_pattern TYPE z2ui5_t_26-name.
    lv_pattern = `SALT_2099%`.
    DELETE FROM z2ui5_t_26 WHERE name LIKE lv_pattern.
    ROLLBACK WORK.                                       "#EC CI_ROLLBACK
    z2ui5_cl_cockpit_setup=>reset_buffer( ).
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt_day.
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt.

  ENDMETHOD.

  METHOD salt_rotates_daily.

    DATA lv_day1 TYPE string.
    DATA lv_day2 TYPE string.
    lv_day1 = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
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

    lv_day2 = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                      day   = `20990102` ).
    cl_abap_unit_assert=>assert_differs( exp = lv_day1
                                         act = lv_day2 ).
    cl_abap_unit_assert=>assert_true( salt_exists( `20990102` ) ).
    cl_abap_unit_assert=>assert_false( salt_exists( `20990101` ) ).

  ENDMETHOD.

  METHOD no_salt_for_a_past_day.
    DATA lv_later TYPE string.

    " a roundtrip of yesterday recorded today: its salt is gone on purpose -
    " no pseudonym rather than a new salt that deletes today's
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                                           day   = `20000101` ) ).
    cl_abap_unit_assert=>assert_false( salt_exists( `20000101` ) ).

    " a later day's salt survives the creation of an earlier one

    lv_later = z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                                       day   = `20990102` ).
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt_day.
    CLEAR z2ui5_cl_cockpit_setup=>gv_salt.
    z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                      day   = `20990101` ).
    cl_abap_unit_assert=>assert_true( salt_exists( `20990102` ) ).
    cl_abap_unit_assert=>assert_true( salt_exists( `20990101` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 64
                                        act = strlen( lv_later ) ).

  ENDMETHOD.

  METHOD purge_claimed_once.

    " one work process per day purges: the claim moves LAST_PURGE forward
    " only - an earlier day, or the same day again, is no claim
    cl_abap_unit_assert=>assert_true( z2ui5_cl_cockpit_setup=>claim_purge( `20990101` ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_cockpit_setup=>claim_purge( `20990101` ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_cockpit_setup=>claim_purge( `20981231` ) ).
    cl_abap_unit_assert=>assert_true( z2ui5_cl_cockpit_setup=>claim_purge( `20990102` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `20990102`
                                        act = z2ui5_cl_cockpit_setup=>get( )-last_purge ).

  ENDMETHOD.

  METHOD old_salts_deleted.
    DATA temp1 TYPE z2ui5_t_26.
    DATA ls_row LIKE temp1.

    " the daily purge deletes an earlier day's salt also when no later day
    " creates one (NONE or NAME since, mode OFF, no traffic) - today's and
    " later ones stay
    z2ui5_cl_cockpit_setup=>user_key( uname = `ALICE`
                                      day   = `20990101` ).

    CLEAR temp1.
    temp1-name = `SALT_20000101`.
    temp1-value = `unit test`.

    ls_row = temp1.
    INSERT z2ui5_t_26 FROM ls_row.
    cl_abap_unit_assert=>assert_true( salt_exists( `20000101` ) ).

    z2ui5_cl_cockpit_setup=>delete_old_salts( ).
    cl_abap_unit_assert=>assert_false( salt_exists( `20000101` ) ).
    cl_abap_unit_assert=>assert_true( salt_exists( `20990101` ) ).

  ENDMETHOD.

  METHOD salt_exists.

    DATA lv_value TYPE z2ui5_t_26-value.
    DATA temp2 TYPE z2ui5_t_26-name.
    DATA lv_name LIKE temp2.
    DATA temp3 TYPE xsdboolean.
    temp2 = |SALT_{ day }|.

    lv_name = temp2.
    SELECT SINGLE value FROM z2ui5_t_26 INTO lv_value
      WHERE name = lv_name
      .

    temp3 = boolc( sy-subrc = 0 ).
    result = temp3.

  ENDMETHOD.

ENDCLASS.
