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
    TYPES ty_t_alert TYPE STANDARD TABLE OF ty_s_alert WITH DEFAULT KEY.

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
    TYPES ty_t_history TYPE STANDARD TABLE OF ty_s_history WITH DEFAULT KEY.

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
    TYPES ty_t_open TYPE STANDARD TABLE OF ty_s_open WITH DEFAULT KEY.

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

    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    ls_set = z2ui5_cl_cockpit_setup=>get( ).
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
    TYPES temp1 TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_app_rules TYPE temp1.

    DATA ls_win LIKE LINE OF it_window.
          DATA temp67 TYPE z2ui5_cl_cockpit_alert=>ty_s_alert.
        DATA temp68 TYPE z2ui5_cl_cockpit_alert=>ty_s_alert.
    DATA ls_alert LIKE LINE OF result.
    DATA lv_rule LIKE LINE OF lt_app_rules.
    LOOP AT it_window INTO ls_win.
      IF ls_win-roundtrips <= 0 OR ls_win-roundtrips < is_set-alert_min_cnt.
        CONTINUE.
      ENDIF.

      " ERRORS records failed roundtrips only - every rate would be 100 %
      IF is_set-alert_err_pct > 0 AND is_set-mode <> z2ui5_cl_cockpit_setup=>cs_mode-errors.
        lv_rate = ls_win-errors * 100 / ls_win-roundtrips.
        IF lv_rate >= is_set-alert_err_pct.

          CLEAR temp67.
          temp67-rule = z2ui5_if_cockpit_notify=>cs_rule-error_rate.
          temp67-app = ls_win-app.
          temp67-value = |{ lv_rate } %|.
          temp67-limit = |{ is_set-alert_err_pct } %|.
          temp67-roundtrips = ls_win-roundtrips.
          temp67-text = |Error rate { lv_rate } % { app_text( ls_win-app ) } - { ls_win-errors } of | && |{ ls_win-roundtrips } roundtrips failed, threshold { is_set-alert_err_pct } %|.
          APPEND temp67
                 TO result.
        ENDIF.
      ENDIF.

      " ERRORS: the p95 of the failed roundtrips only - no response time
      IF is_set-alert_p95_ms > 0 AND is_set-mode <> z2ui5_cl_cockpit_setup=>cs_mode-errors
          AND ls_win-p95_ms >= is_set-alert_p95_ms.

        CLEAR temp68.
        temp68-rule = z2ui5_if_cockpit_notify=>cs_rule-p95.
        temp68-app = ls_win-app.
        temp68-value = |{ ls_win-p95_ms } ms|.
        temp68-limit = |{ is_set-alert_p95_ms } ms|.
        temp68-roundtrips = ls_win-roundtrips.
        temp68-text = |p95 response time { ls_win-p95_ms } ms { app_text( ls_win-app ) } - | && |{ ls_win-roundtrips } roundtrips, threshold { is_set-alert_p95_ms } ms|.
        APPEND temp68
               TO result.
      ENDIF.
    ENDLOOP.

    " the line over all apps is for the many small apps that stay below the
    " minimum one by one - when an app raises the rule itself, it says more

    LOOP AT result INTO ls_alert WHERE app IS NOT INITIAL. "#EC CI_SORTSEQ
      INSERT ls_alert-rule INTO TABLE lt_app_rules.
    ENDLOOP.

    LOOP AT lt_app_rules INTO lv_rule.
      DELETE result WHERE app IS INITIAL AND rule = lv_rule.
    ENDLOOP.

  ENDMETHOD.

  METHOD judged.

    DATA ls_open LIKE LINE OF it_open.
      DATA temp69 TYPE abap_bool.
      DATA temp20 TYPE string.
          DATA temp1 TYPE xsdboolean.
          DATA temp2 TYPE xsdboolean.
      DATA lv_active LIKE temp69.
        DATA lv_roundtrips TYPE i.
        DATA ls_win LIKE LINE OF it_window.
          DATA temp70 TYPE ty_s_open-app.
          DATA temp71 TYPE string.
          DATA lv_app LIKE temp71.
          DATA temp72 LIKE sy-subrc.
    LOOP AT it_open INTO ls_open.


      temp20 = ls_open-rule_id.
      CASE temp20.
        WHEN z2ui5_if_cockpit_notify=>cs_rule-error_rate.

          temp1 = boolc( is_set-alert_err_pct > 0 AND is_set-mode <> z2ui5_cl_cockpit_setup=>cs_mode-errors ).
          temp69 = temp1.
        WHEN z2ui5_if_cockpit_notify=>cs_rule-p95.

          temp2 = boolc( is_set-alert_p95_ms > 0 AND is_set-mode <> z2ui5_cl_cockpit_setup=>cs_mode-errors ).
          temp69 = temp2.
      ENDCASE.

      lv_active = temp69.
      CLEAR ls_open-closing.
      IF lv_active = abap_false.
        ls_open-closing = cs_closing-rule_off.
      ELSE.

        lv_roundtrips = 0.

        LOOP AT it_window INTO ls_win.

          temp70 = ls_win-app.
          IF temp70 = ls_open-app.
            lv_roundtrips = ls_win-roundtrips.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_roundtrips < is_set-alert_min_cnt.

          temp71 = ls_open-app.

          lv_app = temp71.

          READ TABLE it_idle WITH KEY table_line = lv_app TRANSPORTING NO FIELDS.
          temp72 = sy-subrc.
          IF lv_roundtrips > 0 OR NOT temp72 = 0. "#EC CI_SORTSEQ
            CONTINUE.
          ENDIF.
          ls_open-closing = cs_closing-idle.
        ENDIF.
      ENDIF.
      APPEND ls_open TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD diff.
    DATA ls_now LIKE LINE OF it_now.
      DATA temp73 TYPE ty_s_open-app.
      DATA lv_app LIKE temp73.
      DATA temp74 TYPE ty_s_open-rule_id.
      DATA lv_rule LIKE temp74.
      DATA temp75 LIKE sy-subrc.
    DATA ls_open LIKE LINE OF it_open.
      DATA lv_found LIKE abap_false.
        DATA temp76 TYPE ty_s_open-rule_id.
        DATA temp21 TYPE ty_s_open-app.

    CLEAR et_raised.
    CLEAR et_cleared.


    LOOP AT it_now INTO ls_now.

      temp73 = ls_now-app.

      lv_app = temp73.

      temp74 = ls_now-rule.

      lv_rule = temp74.

      READ TABLE it_open WITH KEY rule_id = lv_rule app = lv_app TRANSPORTING NO FIELDS.
      temp75 = sy-subrc.
      IF NOT temp75 = 0. "#EC CI_SORTSEQ
        APPEND ls_now TO et_raised.
      ENDIF.
    ENDLOOP.


    LOOP AT it_open INTO ls_open.

      lv_found = abap_false.
      LOOP AT it_now INTO ls_now.

        temp76 = ls_now-rule.

        temp21 = ls_now-app.
        IF temp76 = ls_open-rule_id AND temp21 = ls_open-app.
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
    TYPES temp2 TYPE STANDARD TABLE OF z2ui5_t_23 WITH DEFAULT KEY.
DATA lt_row TYPE temp2.
    DATA lv_zero TYPE timestampl.

    " not check( ), which swallows a failure: an evaluation that fails must
    " raise - an empty result would clear every open alert
    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA lv_now TYPE timestampl.
    DATA lv_system TYPE string.
    DATA ls_alert LIKE LINE OF lt_raised.
    DATA ls_open LIKE LINE OF lt_cleared.
      DATA temp77 TYPE ty_s_alert.
      DATA ls_clear LIKE temp77.
      DATA temp78 TYPE ty_s_open-note.
      DATA lv_note LIKE temp78.
    ls_set = z2ui5_cl_cockpit_setup=>get( ).
    IF ls_set-alert_err_pct > 0 OR ls_set-alert_p95_ms > 0.
      lt_window = z2ui5_cl_cockpit_stats=>get_window( ls_set-alert_hours ).
      lt_now = evaluate( it_window = lt_window
                         is_set    = ls_set ).
    ENDIF.

    SELECT id rule_id app raised measured threshold cnt note FROM z2ui5_t_23 INTO CORRESPONDING FIELDS OF TABLE lt_open
      WHERE cleared = lv_zero
      .

    diff( EXPORTING it_open    = judged( it_open   = lt_open
                                         it_window = lt_window
                                         is_set    = ls_set
                                         it_idle   = idle_apps( lt_open ) )
                    it_now     = lt_now
          IMPORTING et_raised  = lt_raised
                    et_cleared = lt_cleared ).


    lv_now = z2ui5_cl_cockpit_setup=>now( ).

    lv_system = |{ sy-sysid }/{ sy-mandt }|.


    LOOP AT lt_raised INTO ls_alert.
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
      INSERT z2ui5_t_23 FROM TABLE lt_row.
    ENDIF.


    LOOP AT lt_cleared INTO ls_open.

      CLEAR temp77.
      temp77-event = z2ui5_if_cockpit_notify=>cs_event-cleared.
      temp77-rule = ls_open-rule_id.
      temp77-app = ls_open-app.
      temp77-value = ls_open-measured.
      temp77-limit = ls_open-threshold.
      temp77-roundtrips = ls_open-cnt.
      temp77-raised = z2ui5_cl_cockpit_setup=>ts_text( ls_open-raised ).
      temp77-system = lv_system.

      ls_clear = temp77.
      ls_clear-text = clear_text( is_open = ls_open
                                  raised  = ls_clear-raised ).

      temp78 = |{ ls_open-note }; cleared: { notify( ls_clear ) }|.

      lv_note = temp78.
      UPDATE z2ui5_t_23
        SET cleared = lv_now,
            note    = lv_note
        WHERE id = ls_open-id.
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
    DATA ls_open LIKE LINE OF it_open.
            DATA temp79 TYPE z2ui5_t_22-utc_day.
            DATA temp80 TYPE z2ui5_t_22-app.
        DATA temp81 LIKE LINE OF result.

    lv_day = z2ui5_cl_cockpit_setup=>day_minus( c_idle_days ).

    LOOP AT it_open INTO ls_open.
      lv_app = ls_open-app.
      CLEAR lv_seen.
      TRY.
          IF lv_app IS INITIAL.

            SELECT SINGLE utc_day FROM z2ui5_t_22 INTO temp79
              WHERE utc_day >= lv_day
              .
CLEAR lv_seen.
IF sy-subrc = 0.
  lv_seen = abap_true.
ENDIF. "#EC CI_NOORDER
          ELSE.

            SELECT SINGLE app FROM z2ui5_t_22 INTO temp80
              WHERE app = lv_app
                AND utc_day >= lv_day
              .
CLEAR lv_seen.
IF sy-subrc = 0.
  lv_seen = abap_true.
ENDIF. "#EC CI_NOORDER
          ENDIF.
        CATCH cx_root.
          " cannot tell - keep it open
          lv_seen = abap_true.
      ENDTRY.
      IF lv_seen = abap_false.

        temp81 = lv_app.
        INSERT temp81 INTO TABLE result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD clear_text.

    DATA temp82 TYPE string.
    CASE is_open-closing.
      WHEN cs_closing-rule_off.
        temp82 = |{ rule_text( is_open-rule_id ) } { app_text( is_open-app ) } closed without a verdict - the rule is switched off | && |or not evaluated in this recording mode (raised { raised } UTC at { is_open-measured })|.
      WHEN cs_closing-idle.
        temp82 = |{ rule_text( is_open-rule_id ) } { app_text( is_open-app ) } closed without a verdict - no roundtrip for | && |{ c_idle_days } days (raised { raised } UTC at { is_open-measured })|.
      WHEN OTHERS.
        temp82 = |{ rule_text( is_open-rule_id ) } { app_text( is_open-app ) } is below | && |{ is_open-threshold } again (raised { raised } UTC at { is_open-measured })|.
    ENDCASE.
    result = temp82.

  ENDMETHOD.

  METHOD notify.

    DATA lo_notify TYPE REF TO z2ui5_if_cockpit_notify.
    DATA lv_class TYPE string.
        DATA lx TYPE REF TO cx_root.
    lv_class = get_notifier_class( ).
    IF lv_class IS INITIAL.
      result = `not sent - no class implements z2ui5_if_cockpit_notify`.
      RETURN.
    ENDIF.

    TRY.
        CREATE OBJECT lo_notify TYPE (lv_class).
        lo_notify->notify( is_alert ).
        result = |sent by { lv_class }|.

      CATCH cx_root INTO lx.
        result = |{ lv_class } failed: { lx->get_text( ) }|.
    ENDTRY.

  ENDMETHOD.

  METHOD get_history.

    TYPES temp3 TYPE STANDARD TABLE OF z2ui5_t_23 WITH DEFAULT KEY.
DATA lt_rows TYPE temp3.
    DATA ls_row LIKE LINE OF lt_rows.
      DATA lv_open TYPE abap_bool.
      DATA temp4 TYPE xsdboolean.
      DATA temp83 TYPE z2ui5_cl_cockpit_alert=>ty_s_history.
      DATA temp22 TYPE z2ui5_cl_cockpit_alert=>ty_s_history-status.
      DATA temp23 TYPE z2ui5_cl_cockpit_alert=>ty_s_history-state.
      DATA temp24 TYPE z2ui5_cl_cockpit_alert=>ty_s_history-app.
    TRY.
        SELECT * FROM z2ui5_t_23
          ORDER BY raised DESCENDING
          INTO CORRESPONDING FIELDS OF TABLE lt_rows
          UP TO max_rows ROWS.                         "#EC CI_NOWHERE
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.


    LOOP AT lt_rows INTO ls_row.


      temp4 = boolc( ls_row-cleared IS INITIAL ).
      lv_open = temp4.

      CLEAR temp83.
      temp83-id = ls_row-id.

      IF lv_open = abap_true.
        temp22 = `open`.
      ELSE.
        temp22 = `cleared`.
      ENDIF.
      temp83-status = temp22.

      IF lv_open = abap_true.
        temp23 = `Error`.
      ELSE.
        temp23 = `Success`.
      ENDIF.
      temp83-state = temp23.
      temp83-rule = rule_text( ls_row-rule_id ).

      IF ls_row-app IS INITIAL.
        temp24 = `(all apps)`.
      ELSE.
        temp24 = ls_row-app.
      ENDIF.
      temp83-app = temp24.
      temp83-raised = z2ui5_cl_cockpit_setup=>ts_text( ls_row-raised ).
      temp83-cleared = z2ui5_cl_cockpit_setup=>ts_text( ls_row-cleared ).
      temp83-value = ls_row-measured.
      temp83-limit = ls_row-threshold.
      temp83-roundtrips = ls_row-cnt.
      temp83-text = ls_row-text.
      temp83-note = ls_row-note.
      APPEND temp83 TO result.
    ENDLOOP.

    " open ones first, each group newest first
    SORT result BY status DESCENDING raised DESCENDING.

  ENDMETHOD.

  METHOD get_status.

    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA temp5 TYPE xsdboolean.
    DATA temp84 TYPE string.
    DATA lv_window LIKE temp84.
    DATA temp85 TYPE string.
    ls_set = z2ui5_cl_cockpit_setup=>get( ).
    result-notifier  = get_notifier_class( ).

    temp5 = boolc( it_now IS NOT INITIAL ).
    result-check_now = temp5.

    IF ls_set-alert_err_pct = 0 AND ls_set-alert_p95_ms = 0.
      result-strip_type = `Information`.
      result-text       = `Alerts are switched off - set an error rate or a p95 threshold on the Settings tab.`.
      RETURN.
    ENDIF.


    IF ls_set-alert_hours = 0.
      temp84 = `the UTC hour running now`.
    ELSE.
      temp84 = |the UTC hour running now and the { ls_set-alert_hours } before|.
    ENDIF.

    lv_window = temp84.
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

    IF result-notifier IS INITIAL.
      temp85 = ` - nobody is told: no class implements z2ui5_if_cockpit_notify.`.
    ELSE.
      temp85 = | - notification: { result-notifier }.|.
    ENDIF.
    result-text = result-text && | Alerts are kept and sent by the housekeeping job z2ui5_cl_cockpit_job=>run( )| &&
                  temp85.

  ENDMETHOD.

  METHOD get_notifier_class.
    DATA lt_classes TYPE z2ui5_cl_cockpit_setup=>ty_t_names.
    DATA temp86 TYPE string.
    DATA temp87 TYPE string.

    IF gv_notifier_known = abap_true.
      result = gv_notifier.
      RETURN.
    ENDIF.


    lt_classes = z2ui5_cl_cockpit_inst=>get_implementers( z2ui5_cl_cockpit_inst=>obj_name( c_notify_intf ) ).

    CLEAR temp86.

    READ TABLE lt_classes INTO temp87 INDEX 1.
    IF sy-subrc = 0.
      temp86 = temp87.
    ENDIF.
    gv_notifier = temp86.
    gv_notifier_known = abap_true.
    result = gv_notifier.

  ENDMETHOD.

  METHOD send_test.

    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA temp88 TYPE ty_s_alert.
    DATA ls_alert LIKE temp88.
    ls_set = z2ui5_cl_cockpit_setup=>get( ).

    CLEAR temp88.
    temp88-event = z2ui5_if_cockpit_notify=>cs_event-test.
    temp88-rule = z2ui5_if_cockpit_notify=>cs_rule-error_rate.
    temp88-value = `0 %`.
    temp88-limit = |{ ls_set-alert_err_pct } %|.
    temp88-raised = z2ui5_cl_cockpit_setup=>ts_text( z2ui5_cl_cockpit_setup=>now( ) ).
    temp88-system = |{ sy-sysid }/{ sy-mandt }|.

    ls_alert = temp88.
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

    DATA temp89 TYPE string.
    IF app IS INITIAL.
      temp89 = `over all apps`.
    ELSE.
      temp89 = |in { app }|.
    ENDIF.
    result = temp89.

  ENDMETHOD.

ENDCLASS.
