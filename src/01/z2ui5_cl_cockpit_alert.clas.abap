"! <p class="shorttext synchronized">admin cockpit - alerts</p>
"!
"! Alert thresholds on the figures of the roundtrip monitor: an error rate
"! and a p95 response time, per app and over all apps, in a window of the
"! UTC hour running now plus a number of full hours before it (Settings
"! tab). check( ) evaluates them live - the Overview tab shows the result.
"! run( ) - called by the housekeeping job z2ui5_cl_cockpit_job=&gt;run( ) -
"! keeps the history in Z2UI5_T_23: an alert is raised by the first run
"! that finds the threshold exceeded and cleared by the first run that no
"! longer finds it with enough roundtrips to judge - or, without a verdict,
"! once its rule is switched off or its app has had no roundtrip for
"! c_idle_days days -, and each of the two is handed to the customer class
"! implementing z2ui5_if_cockpit_notify, if there is one.
"!
"! Reads only the cockpit's own tables: without the monitor (package 02)
"! there are no figures and nothing is ever raised.
CLASS z2ui5_cl_cockpit_alert DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES ty_s_alert TYPE z2ui5_if_cockpit_notify=>ty_s_alert.
    TYPES ty_t_alert TYPE STANDARD TABLE OF ty_s_alert WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_history,
        id         TYPE string,
        " open or cleared
        status     TYPE string,
        " Error while open, Success once cleared
        state      TYPE string,
        rule       TYPE string,
        app        TYPE string,
        raised     TYPE string,
        cleared    TYPE string,
        value      TYPE string,
        limit      TYPE string,
        roundtrips TYPE i,
        text       TYPE string,
        note       TYPE string,
      END OF ty_s_history.
    TYPES ty_t_history TYPE STANDARD TABLE OF ty_s_history WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_status,
        text       TYPE string,
        strip_type TYPE string,
        notifier   TYPE string,
        check_now  TYPE abap_bool,
      END OF ty_s_status.

    TYPES:
      BEGIN OF ty_s_run,
        raised  TYPE i,
        cleared TYPE i,
        message TYPE string,
      END OF ty_s_run.

    "! The thresholds exceeded right now - evaluated live, nothing written.
    CLASS-METHODS check
      RETURNING
        VALUE(result) TYPE ty_t_alert.

    "! Evaluate, raise and clear in Z2UI5_T_23, notify. No commit - the
    "! caller commits, which also sends what the notification queued.
    CLASS-METHODS run
      RETURNING
        VALUE(result) TYPE ty_s_run.

    "! The alert history, open alerts first, then newest first.
    CLASS-METHODS get_history
      IMPORTING
        max_rows      TYPE i DEFAULT 50
      RETURNING
        VALUE(result) TYPE ty_t_history.

    "! The line above the alerts on the Overview tab.
    "! @parameter it_now | the result of check( )
    CLASS-METHODS get_status
      IMPORTING
        it_now        TYPE ty_t_alert
      RETURNING
        VALUE(result) TYPE ty_s_status.

    "! The customer class implementing z2ui5_if_cockpit_notify, if any.
    CLASS-METHODS get_notifier_class
      RETURNING
        VALUE(result) TYPE string.

    "! Hand a test alert to the notification class. No commit - the caller
    "! commits, which also sends what the notification queued.
    "! @parameter result | what happened, one line
    CLASS-METHODS send_test
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.

  PRIVATE SECTION.

    " without the prefix - z2ui5_cl_cockpit_inst=>obj_name( ) puts it in front
    CONSTANTS c_notify_intf TYPE string VALUE `IF_COCKPIT_NOTIFY`.

    "! Days without any roundtrip of its app after which an open alert is
    "! closed without a verdict - the app was removed, renamed or is no
    "! longer used, and no window would ever judge it again.
    CONSTANTS c_idle_days TYPE i VALUE 7.

    CONSTANTS:
      "! Why judged( ) hands an open alert on although the window cannot
      "! judge it: its rule is off, or its app idle.
      BEGIN OF cs_closing,
        rule_off TYPE string VALUE `RULE_OFF`,
        idle     TYPE string VALUE `IDLE`,
      END OF cs_closing.

    TYPES:
      BEGIN OF ty_s_open,
        id        TYPE c LENGTH 32,
        rule_id   TYPE c LENGTH 30,
        app       TYPE c LENGTH 30,
        raised    TYPE timestampl,
        measured  TYPE c LENGTH 30,
        threshold TYPE c LENGTH 30,
        cnt       TYPE i,
        note      TYPE c LENGTH 255,
        " set by judged( ) - cs_closing, empty when the window judges it
        closing   TYPE string,
      END OF ty_s_open.
    TYPES ty_t_open TYPE STANDARD TABLE OF ty_s_open WITH EMPTY KEY.

    CLASS-DATA gv_notifier       TYPE string.
    CLASS-DATA gv_notifier_known TYPE abap_bool.

    "! The alert rules over the window figures - pure. An app below the
    "! minimum of roundtrips raises nothing; the line over all apps raises
    "! a rule only when no single app raises it already. Neither the error
    "! rate nor the p95 is a rule in mode ERRORS, which records failed
    "! roundtrips only (every rate 100 %, the p95 that of the failures).
    CLASS-METHODS evaluate
      IMPORTING
        it_window     TYPE z2ui5_cl_cockpit_stats=>ty_t_window
        is_set        TYPE z2ui5_cl_cockpit_setup=>ty_s_settings
      RETURNING
        VALUE(result) TYPE ty_t_alert.

    "! The open alerts the window can judge - pure. The alert of an app (or
    "! of all apps) with fewer roundtrips in the window than the minimum is
    "! left out and stays open: a quiet hour is no recovery - unless its app
    "! is in it_idle (closing IDLE). The alert of a rule that is switched off,
    "! or not evaluated in the mode, is handed on too (closing RULE_OFF);
    "! diff( ) then clears both.
    "! @parameter it_idle | apps (empty: all apps) without any roundtrip for c_idle_days days
    CLASS-METHODS judged
      IMPORTING
        it_open       TYPE ty_t_open
        it_window     TYPE z2ui5_cl_cockpit_stats=>ty_t_window
        is_set        TYPE z2ui5_cl_cockpit_setup=>ty_s_settings
        it_idle       TYPE string_table OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_open.

    "! The apps of the open alerts without any roundtrip for c_idle_days
    "! days - empty for the alert over all apps when no app had one.
    CLASS-METHODS idle_apps
      IMPORTING
        it_open       TYPE ty_t_open
      RETURNING
        VALUE(result) TYPE string_table.

    "! The text of a cleared alert - pure: below the threshold again, or
    "! closed without a verdict (cs_closing).
    CLASS-METHODS clear_text
      IMPORTING
        is_open       TYPE ty_s_open
        raised        TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! What changed since the last run - pure: the alerts of it_now without
    "! an open row are raised, the open rows without an alert are cleared.
    CLASS-METHODS diff
      IMPORTING
        it_open    TYPE ty_t_open
        it_now     TYPE ty_t_alert
      EXPORTING
        et_raised  TYPE ty_t_alert
        et_cleared TYPE ty_t_open.

    "! Hand an alert to the notification class.
    "! @parameter result | the note kept in the history
    CLASS-METHODS notify
      IMPORTING
        is_alert      TYPE ty_s_alert
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS rule_text
      IMPORTING
        rule          TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS app_text
      IMPORTING
        app           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS z2ui5_cl_cockpit_alert IMPLEMENTATION.

  METHOD check.

    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get( ).
    IF ls_set-alert_err_pct = 0 AND ls_set-alert_p95_ms = 0.
      RETURN.
    ENDIF.

    TRY.
        result = evaluate( it_window = z2ui5_cl_cockpit_stats=>get_window( ls_set-alert_hours )
                           is_set    = ls_set ).
      CATCH cx_root ##NO_HANDLER.
        " no aggregate table yet (half-imported addon) - nothing to raise
    ENDTRY.

  ENDMETHOD.

  METHOD evaluate.

    DATA lv_rate TYPE p LENGTH 8 DECIMALS 1.
    DATA lt_app_rules TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT it_window INTO DATA(ls_win).
      IF ls_win-roundtrips <= 0 OR ls_win-roundtrips < is_set-alert_min_cnt.
        CONTINUE.
      ENDIF.

      " ERRORS records failed roundtrips only - every rate would be 100 %
      IF is_set-alert_err_pct > 0 AND is_set-mode <> z2ui5_cl_cockpit_setup=>cs_mode-errors.
        lv_rate = ls_win-errors * 100 / ls_win-roundtrips.
        IF lv_rate >= is_set-alert_err_pct.
          APPEND VALUE #( rule       = z2ui5_if_cockpit_notify=>cs_rule-error_rate
                          app        = ls_win-app
                          value      = |{ lv_rate } %|
                          limit      = |{ is_set-alert_err_pct } %|
                          roundtrips = ls_win-roundtrips
                          text       = |Error rate { lv_rate } % { app_text( ls_win-app ) } - { ls_win-errors } of | &&
                                       |{ ls_win-roundtrips } roundtrips failed, threshold { is_set-alert_err_pct } %| )
                 TO result.
        ENDIF.
      ENDIF.

      " ERRORS: the p95 of the failed roundtrips only - no response time
      IF is_set-alert_p95_ms > 0 AND is_set-mode <> z2ui5_cl_cockpit_setup=>cs_mode-errors
          AND ls_win-p95_ms >= is_set-alert_p95_ms.
        APPEND VALUE #( rule       = z2ui5_if_cockpit_notify=>cs_rule-p95
                        app        = ls_win-app
                        value      = |{ ls_win-p95_ms } ms|
                        limit      = |{ is_set-alert_p95_ms } ms|
                        roundtrips = ls_win-roundtrips
                        text       = |p95 response time { ls_win-p95_ms } ms { app_text( ls_win-app ) } - | &&
                                     |{ ls_win-roundtrips } roundtrips, threshold { is_set-alert_p95_ms } ms| )
               TO result.
      ENDIF.
    ENDLOOP.

    " the line over all apps is for the many small apps that stay below the
    " minimum one by one - when an app raises the rule itself, it says more
    LOOP AT result INTO DATA(ls_alert) WHERE app IS NOT INITIAL. "#EC CI_SORTSEQ
      INSERT ls_alert-rule INTO TABLE lt_app_rules.
    ENDLOOP.
    LOOP AT lt_app_rules INTO DATA(lv_rule).
      DELETE result WHERE app IS INITIAL AND rule = lv_rule.
    ENDLOOP.

  ENDMETHOD.

  METHOD judged.

    LOOP AT it_open INTO DATA(ls_open).
      DATA(lv_active) = SWITCH abap_bool( CONV string( ls_open-rule_id )
        WHEN z2ui5_if_cockpit_notify=>cs_rule-error_rate
        THEN xsdbool( is_set-alert_err_pct > 0 AND is_set-mode <> z2ui5_cl_cockpit_setup=>cs_mode-errors )
        WHEN z2ui5_if_cockpit_notify=>cs_rule-p95
        THEN xsdbool( is_set-alert_p95_ms > 0 AND is_set-mode <> z2ui5_cl_cockpit_setup=>cs_mode-errors ) ).
      CLEAR ls_open-closing.
      IF lv_active = abap_false.
        ls_open-closing = cs_closing-rule_off.
      ELSE.
        DATA(lv_roundtrips) = 0.
        LOOP AT it_window INTO DATA(ls_win).
          IF CONV ty_s_open-app( ls_win-app ) = ls_open-app.
            lv_roundtrips = ls_win-roundtrips.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_roundtrips < is_set-alert_min_cnt.
          DATA(lv_app) = CONV string( ls_open-app ).
          IF lv_roundtrips > 0 OR NOT line_exists( it_idle[ table_line = lv_app ] ). "#EC CI_SORTSEQ
            CONTINUE.
          ENDIF.
          ls_open-closing = cs_closing-idle.
        ENDIF.
      ENDIF.
      APPEND ls_open TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD diff.

    CLEAR et_raised.
    CLEAR et_cleared.

    LOOP AT it_now INTO DATA(ls_now).
      DATA(lv_app) = CONV ty_s_open-app( ls_now-app ).
      DATA(lv_rule) = CONV ty_s_open-rule_id( ls_now-rule ).
      IF NOT line_exists( it_open[ rule_id = lv_rule app = lv_app ] ). "#EC CI_SORTSEQ
        APPEND ls_now TO et_raised.
      ENDIF.
    ENDLOOP.

    LOOP AT it_open INTO DATA(ls_open).
      DATA(lv_found) = abap_false.
      LOOP AT it_now INTO ls_now.
        IF CONV ty_s_open-rule_id( ls_now-rule ) = ls_open-rule_id AND CONV ty_s_open-app( ls_now-app ) = ls_open-app.
          lv_found = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_found = abap_false.
        APPEND ls_open TO et_cleared.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD run.

    DATA lt_open TYPE ty_t_open.
    DATA lt_raised TYPE ty_t_alert.
    DATA lt_cleared TYPE ty_t_open.
    DATA lt_window TYPE z2ui5_cl_cockpit_stats=>ty_t_window.
    DATA lt_now TYPE ty_t_alert.
    DATA ls_row TYPE z2ui5_t_23.
    DATA lt_row TYPE STANDARD TABLE OF z2ui5_t_23 WITH EMPTY KEY.
    DATA lv_zero TYPE timestampl.

    " not check( ), which swallows a failure: an evaluation that fails must
    " raise - an empty result would clear every open alert
    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get( ).
    IF ls_set-alert_err_pct > 0 OR ls_set-alert_p95_ms > 0.
      lt_window = z2ui5_cl_cockpit_stats=>get_window( ls_set-alert_hours ).
      lt_now = evaluate( it_window = lt_window
                         is_set    = ls_set ).
    ENDIF.

    SELECT id, rule_id, app, raised, measured, threshold, cnt, note FROM z2ui5_t_23
      WHERE cleared = @lv_zero
      INTO CORRESPONDING FIELDS OF TABLE @lt_open.

    diff( EXPORTING it_open    = judged( it_open   = lt_open
                                         it_window = lt_window
                                         is_set    = ls_set
                                         it_idle   = idle_apps( lt_open ) )
                    it_now     = lt_now
          IMPORTING et_raised  = lt_raised
                    et_cleared = lt_cleared ).

    DATA(lv_now) = z2ui5_cl_cockpit_setup=>now( ).
    DATA(lv_system) = |{ sy-sysid }/{ sy-mandt }|.

    LOOP AT lt_raised INTO DATA(ls_alert).
      ls_alert-event  = z2ui5_if_cockpit_notify=>cs_event-raised.
      ls_alert-raised = z2ui5_cl_cockpit_setup=>ts_text( lv_now ).
      ls_alert-system = lv_system.
      CLEAR ls_row.
      TRY.
          ls_row-id = cl_system_uuid=>create_uuid_c32_static( ).
        CATCH cx_uuid_error.
          CONTINUE.
      ENDTRY.
      ls_row-rule_id   = ls_alert-rule.
      ls_row-app       = ls_alert-app.
      ls_row-raised    = lv_now.
      ls_row-measured  = ls_alert-value.
      ls_row-threshold = ls_alert-limit.
      ls_row-cnt       = ls_alert-roundtrips.
      ls_row-text      = ls_alert-text.
      ls_row-note      = notify( ls_alert ).
      APPEND ls_row TO lt_row.
      result-raised = result-raised + 1.
    ENDLOOP.
    IF lt_row IS NOT INITIAL.
      INSERT z2ui5_t_23 FROM TABLE @lt_row.
    ENDIF.

    LOOP AT lt_cleared INTO DATA(ls_open).
      DATA(ls_clear) = VALUE ty_s_alert( event      = z2ui5_if_cockpit_notify=>cs_event-cleared
                                         rule       = ls_open-rule_id
                                         app        = ls_open-app
                                         value      = ls_open-measured
                                         limit      = ls_open-threshold
                                         roundtrips = ls_open-cnt
                                         raised     = z2ui5_cl_cockpit_setup=>ts_text( ls_open-raised )
                                         system     = lv_system ).
      ls_clear-text = clear_text( is_open = ls_open
                                  raised  = ls_clear-raised ).
      DATA(lv_note) = CONV ty_s_open-note( |{ ls_open-note }; cleared: { notify( ls_clear ) }| ).
      UPDATE z2ui5_t_23
        SET cleared = @lv_now,
            note    = @lv_note
        WHERE id = @ls_open-id.
      result-cleared = result-cleared + 1.
    ENDLOOP.

    result-message = |alerts: { result-raised } raised, { result-cleared } cleared, | &&
                     |{ lines( lt_now ) } threshold(s) exceeded now|.

  ENDMETHOD.

  METHOD idle_apps.

    " host variables named like no column (the 7.02 downport drops the @)
    DATA lv_day TYPE c LENGTH 8.
    DATA lv_app TYPE ty_s_open-app.
    DATA lv_seen TYPE abap_bool.

    lv_day = z2ui5_cl_cockpit_setup=>day_minus( c_idle_days ).
    LOOP AT it_open INTO DATA(ls_open).
      lv_app = ls_open-app.
      CLEAR lv_seen.
      TRY.
          IF lv_app IS INITIAL.
            SELECT SINGLE @abap_true FROM z2ui5_t_22
              WHERE utc_day >= @lv_day
              INTO @lv_seen. "#EC CI_NOORDER
          ELSE.
            SELECT SINGLE @abap_true FROM z2ui5_t_22
              WHERE app = @lv_app
                AND utc_day >= @lv_day
              INTO @lv_seen. "#EC CI_NOORDER
          ENDIF.
        CATCH cx_root.
          " cannot tell - keep it open
          lv_seen = abap_true.
      ENDTRY.
      IF lv_seen = abap_false.
        INSERT CONV string( lv_app ) INTO TABLE result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD clear_text.

    result = SWITCH #( is_open-closing
      WHEN cs_closing-rule_off
      THEN |{ rule_text( is_open-rule_id ) } { app_text( is_open-app ) } closed without a verdict - the rule is switched off | &&
           |or not evaluated in this recording mode (raised { raised } UTC at { is_open-measured })|
      WHEN cs_closing-idle
      THEN |{ rule_text( is_open-rule_id ) } { app_text( is_open-app ) } closed without a verdict - no roundtrip for | &&
           |{ c_idle_days } days (raised { raised } UTC at { is_open-measured })|
      ELSE |{ rule_text( is_open-rule_id ) } { app_text( is_open-app ) } is below | &&
           |{ is_open-threshold } again (raised { raised } UTC at { is_open-measured })| ).

  ENDMETHOD.

  METHOD notify.

    DATA lo_notify TYPE REF TO z2ui5_if_cockpit_notify.
    DATA(lv_class) = get_notifier_class( ).
    IF lv_class IS INITIAL.
      result = `not sent - no class implements z2ui5_if_cockpit_notify`.
      RETURN.
    ENDIF.

    TRY.
        CREATE OBJECT lo_notify TYPE (lv_class).
        lo_notify->notify( is_alert ).
        result = |sent by { lv_class }|.
      CATCH cx_root INTO DATA(lx).
        result = |{ lv_class } failed: { lx->get_text( ) }|.
    ENDTRY.

  ENDMETHOD.

  METHOD get_history.

    DATA lt_rows TYPE STANDARD TABLE OF z2ui5_t_23 WITH EMPTY KEY.
    TRY.
        SELECT * FROM z2ui5_t_23
          ORDER BY raised DESCENDING
          INTO CORRESPONDING FIELDS OF TABLE @lt_rows
          UP TO @max_rows ROWS.                         "#EC CI_NOWHERE
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    LOOP AT lt_rows INTO DATA(ls_row).
      DATA(lv_open) = xsdbool( ls_row-cleared IS INITIAL ).
      APPEND VALUE #( id         = ls_row-id
                      status     = COND #( WHEN lv_open = abap_true THEN `open` ELSE `cleared` )
                      state      = COND #( WHEN lv_open = abap_true THEN `Error` ELSE `Success` )
                      rule       = rule_text( ls_row-rule_id )
                      app        = COND #( WHEN ls_row-app IS INITIAL THEN `(all apps)` ELSE ls_row-app )
                      raised     = z2ui5_cl_cockpit_setup=>ts_text( ls_row-raised )
                      cleared    = z2ui5_cl_cockpit_setup=>ts_text( ls_row-cleared )
                      value      = ls_row-measured
                      limit      = ls_row-threshold
                      roundtrips = ls_row-cnt
                      text       = ls_row-text
                      note       = ls_row-note ) TO result.
    ENDLOOP.

    " open ones first, each group newest first
    SORT result BY status DESCENDING raised DESCENDING.

  ENDMETHOD.

  METHOD get_status.

    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get( ).
    result-notifier  = get_notifier_class( ).
    result-check_now = xsdbool( it_now IS NOT INITIAL ).

    IF ls_set-alert_err_pct = 0 AND ls_set-alert_p95_ms = 0.
      result-strip_type = `Information`.
      result-text       = `Alerts are switched off - set an error rate or a p95 threshold on the Settings tab.`.
      RETURN.
    ENDIF.

    DATA(lv_window) = COND string( WHEN ls_set-alert_hours = 0 THEN `the UTC hour running now`
                                   ELSE |the UTC hour running now and the { ls_set-alert_hours } before| ).
    IF it_now IS INITIAL.
      result-strip_type = `Success`.
      result-text       = |No alert threshold exceeded in { lv_window }.|.
    ELSE.
      result-strip_type = `Error`.
      result-text       = |{ lines( it_now ) } alert threshold(s) exceeded in { lv_window }.|.
    ENDIF.

    IF ( ls_set-alert_err_pct > 0 OR ls_set-alert_p95_ms > 0 ) AND ls_set-mode = z2ui5_cl_cockpit_setup=>cs_mode-errors.
      result-text = result-text && ` Neither the error rate nor the p95 is evaluated: mode ERRORS records failed roundtrips only.`.
    ENDIF.
    result-text = result-text && | Alerts are kept and sent by the housekeeping job z2ui5_cl_cockpit_job=>run( )| &&
                  COND string( WHEN result-notifier IS INITIAL
                               THEN ` - nobody is told: no class implements z2ui5_if_cockpit_notify.`
                               ELSE | - notification: { result-notifier }.| ).

  ENDMETHOD.

  METHOD get_notifier_class.

    IF gv_notifier_known = abap_true.
      result = gv_notifier.
      RETURN.
    ENDIF.

    DATA(lt_classes) = z2ui5_cl_cockpit_inst=>get_implementers( z2ui5_cl_cockpit_inst=>obj_name( c_notify_intf ) ).
    gv_notifier = VALUE #( lt_classes[ 1 ] OPTIONAL ).
    gv_notifier_known = abap_true.
    result = gv_notifier.

  ENDMETHOD.

  METHOD send_test.

    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get( ).
    DATA(ls_alert) = VALUE ty_s_alert( event  = z2ui5_if_cockpit_notify=>cs_event-test
                                       rule   = z2ui5_if_cockpit_notify=>cs_rule-error_rate
                                       value  = `0 %`
                                       limit  = |{ ls_set-alert_err_pct } %|
                                       raised = z2ui5_cl_cockpit_setup=>ts_text( z2ui5_cl_cockpit_setup=>now( ) )
                                       system = |{ sy-sysid }/{ sy-mandt }| ).
    ls_alert-text = |Test notification of the abap2UI5 admin cockpit on { ls_alert-system }, sent by { sy-uname } - | &&
                    `nothing is exceeded.`.
    result = notify( ls_alert ).

  ENDMETHOD.

  METHOD rule_text.

    CASE rule.
      WHEN z2ui5_if_cockpit_notify=>cs_rule-error_rate.
        result = `Error rate`.
      WHEN z2ui5_if_cockpit_notify=>cs_rule-p95.
        result = `p95 response time`.
      WHEN OTHERS.
        result = rule.
    ENDCASE.

  ENDMETHOD.

  METHOD app_text.

    result = COND #( WHEN app IS INITIAL THEN `over all apps` ELSE |in { app }| ).

  ENDMETHOD.

ENDCLASS.
