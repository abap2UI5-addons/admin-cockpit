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
    DATA(lt_alert) = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = VALUE #( ( app = `` roundtrips = 100 errors = 10 p95_ms = 100 )
                             ( app = c_app roundtrips = 100 errors = 10 p95_ms = 100 ) )
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_alert ) ).
    DATA(ls_alert) = lt_alert[ 1 ].
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

    DATA(lt_alert) = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = VALUE #( ( app = c_app roundtrips = 100 errors = 4 p95_ms = 100 ) )
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_initial( lt_alert ).

  ENDMETHOD.

  METHOD error_rate_at_threshold.

    " exactly the threshold raises - "from 5 %"
    DATA(lt_alert) = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = VALUE #( ( app = c_app roundtrips = 100 errors = 5 p95_ms = 100 ) )
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_alert ) ).

  ENDMETHOD.

  METHOD p95_raised.

    DATA(lt_alert) = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = VALUE #( ( app = c_app roundtrips = 50 errors = 0 p95_ms = 3400 ) )
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_alert ) ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_if_cockpit_notify=>cs_rule-p95
                                        act = lt_alert[ 1 ]-rule ).
    cl_abap_unit_assert=>assert_equals( exp = `3400 ms`
                                        act = lt_alert[ 1 ]-value ).

  ENDMETHOD.

  METHOD below_minimum_raises_nothing.

    " every one of 10 roundtrips failed and was slow - but 10 is below 20
    DATA(lt_alert) = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = VALUE #( ( app = c_app roundtrips = 10 errors = 10 p95_ms = 9000 ) )
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_initial( lt_alert ).

  ENDMETHOD.

  METHOD zero_switches_rule_off.

    DATA(ls_set) = settings( ).
    ls_set-alert_err_pct = 0.

    DATA(lt_alert) = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = VALUE #( ( app = c_app roundtrips = 100 errors = 100 p95_ms = 9000 ) )
        is_set    = ls_set ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_alert ) ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_if_cockpit_notify=>cs_rule-p95
                                        act = lt_alert[ 1 ]-rule ).

  ENDMETHOD.

  METHOD all_apps_only_without_app.

    " one app explains the error rate over all apps - one alert, for the app;
    " the other app's p95 is raised over all apps too - again only for it
    DATA(lt_alert) = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = VALUE #( ( app = `` roundtrips = 200 errors = 20 p95_ms = 2500 )
                             ( app = c_app roundtrips = 100 errors = 20 p95_ms = 100 )
                             ( app = c_other roundtrips = 100 errors = 0 p95_ms = 4000 ) )
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_alert ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( lt_alert[ app = `` ] ) ) ).

  ENDMETHOD.

  METHOD all_apps_when_apps_are_small.

    " three apps, 15 roundtrips each - each below the minimum, together not
    DATA(lt_alert) = z2ui5_cl_cockpit_alert=>evaluate(
        it_window = VALUE #( ( app = `` roundtrips = 45 errors = 9 p95_ms = 100 )
                             ( app = c_app roundtrips = 15 errors = 3 p95_ms = 100 )
                             ( app = c_other roundtrips = 15 errors = 3 p95_ms = 100 )
                             ( app = `ZZ_COCKPIT_TEST_THIRD` roundtrips = 15 errors = 3 p95_ms = 100 ) )
        is_set    = settings( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_alert ) ).
    cl_abap_unit_assert=>assert_initial( lt_alert[ 1 ]-app ).
    cl_abap_unit_assert=>assert_equals( exp = `20.0 %`
                                        act = lt_alert[ 1 ]-value ).

  ENDMETHOD.

  METHOD diff_raises_new.

    DATA lt_raised TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA lt_cleared TYPE z2ui5_cl_cockpit_alert=>ty_t_open.

    z2ui5_cl_cockpit_alert=>diff(
      EXPORTING it_open    = VALUE #( )
                it_now     = VALUE #( ( rule = z2ui5_if_cockpit_notify=>cs_rule-p95 app = c_app ) )
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

    z2ui5_cl_cockpit_alert=>diff(
      EXPORTING it_open    = VALUE #( ( id = `A1` rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95 app = c_app ) )
                it_now     = VALUE #( ( rule = z2ui5_if_cockpit_notify=>cs_rule-p95 app = c_app ) )
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

    z2ui5_cl_cockpit_alert=>diff(
      EXPORTING it_open    = VALUE #( ( id = `A1` rule_id = z2ui5_if_cockpit_notify=>cs_rule-p95 app = c_app ) )
                it_now     = VALUE #( ( rule = z2ui5_if_cockpit_notify=>cs_rule-error_rate app = c_app ) )
      IMPORTING et_raised  = lt_raised
                et_cleared = lt_cleared ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_raised ) ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_if_cockpit_notify=>cs_rule-error_rate
                                        act = lt_raised[ 1 ]-rule ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_cleared ) ).
    cl_abap_unit_assert=>assert_equals( exp = `A1`
                                        act = CONV string( lt_cleared[ 1 ]-id ) ).

  ENDMETHOD.

ENDCLASS.
