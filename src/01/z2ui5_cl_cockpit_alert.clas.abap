"! <p class="shorttext synchronized">admin cockpit - alerts</p>
"!
"! Alert thresholds on the figures of the roundtrip monitor: an error rate
"! and a p95 response time, per app and over all apps, in a window of the
"! UTC hour running now plus a number of full hours before it (Settings
"! tab). check( ) evaluates them live - the Overview tab shows the result.
"! run( ) - called by the housekeeping job z2ui5_cl_cockpit_job=&gt;run( ) -
"! keeps the history in Z2UI5_T_23: an alert is raised by the first run
"! that finds the threshold exceeded and cleared by the first run that no
"! longer finds it, and each of the two is handed to the customer class
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
      END OF ty_s_open.
    TYPES ty_t_open TYPE STANDARD TABLE OF ty_s_open WITH DEFAULT KEY.

    CLASS-DATA gv_notifier       TYPE string.
    CLASS-DATA gv_notifier_known TYPE abap_bool.

    "! The alert rules over the window figures - pure. An app below the
    "! minimum of roundtrips raises nothing; the line over all apps raises
    "! a rule only when no single app raises it already.
    CLASS-METHODS evaluate
      IMPORTING
        it_window     TYPE z2ui5_cl_cockpit_stats=>ty_t_window
        is_set        TYPE z2ui5_cl_cockpit_setup=>ty_s_settings
      RETURNING
        VALUE(result) TYPE ty_t_alert.

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
          DATA temp35 TYPE z2ui5_if_cockpit_notify=>ty_s_alert.
        DATA temp36 TYPE z2ui5_if_cockpit_notify=>ty_s_alert.
    DATA ls_alert LIKE LINE OF result.
    DATA lv_rule LIKE LINE OF lt_app_rules.
    LOOP AT it_window INTO ls_win.
      IF ls_win-roundtrips <= 0 OR ls_win-roundtrips < is_set-alert_min_cnt.
        CONTINUE.
      ENDIF.

      IF is_set-alert_err_pct > 0.
        lv_rate = ls_win-errors * 100 / ls_win-roundtrips.
        IF lv_rate >= is_set-alert_err_pct.

          CLEAR temp35.
          temp35-rule = z2ui5_if_cockpit_notify=>cs_rule-error_rate.
          temp35-app = ls_win-app.
          temp35-value = |{ lv_rate } %|.
          temp35-limit = |{ is_set-alert_err_pct } %|.
          temp35-roundtrips = ls_win-roundtrips.
          temp35-text = |Error rate { lv_rate } % { app_text( ls_win-app ) } - { ls_win-errors } of | && |{ ls_win-roundtrips } roundtrips failed, threshold { is_set-alert_err_pct } %|.
          APPEND temp35
                 TO result.
        ENDIF.
      ENDIF.

      IF is_set-alert_p95_ms > 0 AND ls_win-p95_ms >= is_set-alert_p95_ms.

        CLEAR temp36.
        temp36-rule = z2ui5_if_cockpit_notify=>cs_rule-p95.
        temp36-app = ls_win-app.
        temp36-value = |{ ls_win-p95_ms } ms|.
        temp36-limit = |{ is_set-alert_p95_ms } ms|.
        temp36-roundtrips = ls_win-roundtrips.
        temp36-text = |p95 response time { ls_win-p95_ms } ms { app_text( ls_win-app ) } - | && |{ ls_win-roundtrips } roundtrips, threshold { is_set-alert_p95_ms } ms|.
        APPEND temp36
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

  METHOD diff.
    DATA ls_now LIKE LINE OF it_now.
      DATA temp37 TYPE ty_s_open-app.
      DATA lv_app LIKE temp37.
      DATA temp38 TYPE ty_s_open-rule_id.
      DATA lv_rule LIKE temp38.
      DATA temp39 LIKE sy-subrc.
    DATA ls_open LIKE LINE OF it_open.
      DATA lv_found LIKE abap_false.
        DATA temp40 TYPE ty_s_open-rule_id.
        DATA temp12 TYPE ty_s_open-app.

    CLEAR et_raised.
    CLEAR et_cleared.


    LOOP AT it_now INTO ls_now.

      temp37 = ls_now-app.

      lv_app = temp37.

      temp38 = ls_now-rule.

      lv_rule = temp38.

      READ TABLE it_open WITH KEY rule_id = lv_rule app = lv_app TRANSPORTING NO FIELDS.
      temp39 = sy-subrc.
      IF NOT temp39 = 0. "#EC CI_SORTSEQ
        APPEND ls_now TO et_raised.
      ENDIF.
    ENDLOOP.


    LOOP AT it_open INTO ls_open.

      lv_found = abap_false.
      LOOP AT it_now INTO ls_now.

        temp40 = ls_now-rule.

        temp12 = ls_now-app.
        IF temp40 = ls_open-rule_id AND temp12 = ls_open-app.
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
    DATA ls_row TYPE z2ui5_t_23.
    DATA lv_zero TYPE timestampl.

    DATA lt_now TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA lv_now TYPE timestampl.
    DATA lv_system TYPE string.
    DATA ls_alert LIKE LINE OF lt_raised.
    DATA ls_open LIKE LINE OF lt_cleared.
      DATA temp41 TYPE ty_s_alert.
      DATA ls_clear LIKE temp41.
      DATA temp42 TYPE ty_s_open-note.
      DATA lv_note LIKE temp42.
    lt_now = check( ).

    SELECT id rule_id app raised measured threshold cnt note FROM z2ui5_t_23 INTO CORRESPONDING FIELDS OF TABLE lt_open
      WHERE cleared = lv_zero
      .

    diff( EXPORTING it_open    = lt_open
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
      INSERT z2ui5_t_23 FROM ls_row.
      result-raised = result-raised + 1.
    ENDLOOP.


    LOOP AT lt_cleared INTO ls_open.

      CLEAR temp41.
      temp41-event = z2ui5_if_cockpit_notify=>cs_event-cleared.
      temp41-rule = ls_open-rule_id.
      temp41-app = ls_open-app.
      temp41-value = ls_open-measured.
      temp41-limit = ls_open-threshold.
      temp41-roundtrips = ls_open-cnt.
      temp41-raised = z2ui5_cl_cockpit_setup=>ts_text( ls_open-raised ).
      temp41-system = lv_system.

      ls_clear = temp41.
      ls_clear-text = |{ rule_text( ls_open-rule_id ) } { app_text( ls_open-app ) } is below | &&
                      |{ ls_open-threshold } again (raised { ls_clear-raised } UTC at { ls_open-measured })|.

      temp42 = |{ ls_open-note }; cleared: { notify( ls_clear ) }|.

      lv_note = temp42.
      UPDATE z2ui5_t_23
        SET cleared = lv_now,
            note    = lv_note
        WHERE id = ls_open-id.
      result-cleared = result-cleared + 1.
    ENDLOOP.

    result-message = |alerts: { result-raised } raised, { result-cleared } cleared, | &&
                     |{ lines( lt_now ) } threshold(s) exceeded now|.

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

    TYPES temp2 TYPE STANDARD TABLE OF z2ui5_t_23 WITH DEFAULT KEY.
DATA lt_rows TYPE temp2.
    DATA ls_row LIKE LINE OF lt_rows.
      DATA lv_open TYPE abap_bool.
      DATA temp1 TYPE xsdboolean.
      DATA temp43 TYPE z2ui5_cl_cockpit_alert=>ty_s_history.
      DATA temp13 TYPE z2ui5_cl_cockpit_alert=>ty_s_history-status.
      DATA temp14 TYPE z2ui5_cl_cockpit_alert=>ty_s_history-state.
      DATA temp15 TYPE z2ui5_cl_cockpit_alert=>ty_s_history-app.
    TRY.
        SELECT * FROM z2ui5_t_23
          ORDER BY raised DESCENDING
          INTO TABLE lt_rows
          UP TO max_rows ROWS.                         "#EC CI_NOWHERE
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.


    LOOP AT lt_rows INTO ls_row.


      temp1 = boolc( ls_row-cleared IS INITIAL ).
      lv_open = temp1.

      CLEAR temp43.
      temp43-id = ls_row-id.

      IF lv_open = abap_true.
        temp13 = `open`.
      ELSE.
        temp13 = `cleared`.
      ENDIF.
      temp43-status = temp13.

      IF lv_open = abap_true.
        temp14 = `Error`.
      ELSE.
        temp14 = `Success`.
      ENDIF.
      temp43-state = temp14.
      temp43-rule = rule_text( ls_row-rule_id ).

      IF ls_row-app IS INITIAL.
        temp15 = `(all apps)`.
      ELSE.
        temp15 = ls_row-app.
      ENDIF.
      temp43-app = temp15.
      temp43-raised = z2ui5_cl_cockpit_setup=>ts_text( ls_row-raised ).
      temp43-cleared = z2ui5_cl_cockpit_setup=>ts_text( ls_row-cleared ).
      temp43-value = ls_row-measured.
      temp43-limit = ls_row-threshold.
      temp43-roundtrips = ls_row-cnt.
      temp43-text = ls_row-text.
      temp43-note = ls_row-note.
      APPEND temp43 TO result.
    ENDLOOP.

    " open ones first, each group newest first
    SORT result BY status DESCENDING raised DESCENDING.

  ENDMETHOD.

  METHOD get_status.

    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA temp2 TYPE xsdboolean.
    DATA temp44 TYPE string.
    DATA lv_window LIKE temp44.
    DATA temp45 TYPE string.
    ls_set = z2ui5_cl_cockpit_setup=>get( ).
    result-notifier  = get_notifier_class( ).

    temp2 = boolc( it_now IS NOT INITIAL ).
    result-check_now = temp2.

    IF ls_set-alert_err_pct = 0 AND ls_set-alert_p95_ms = 0.
      result-strip_type = `Information`.
      result-text       = `Alerts are switched off - set an error rate or a p95 threshold on the Settings tab.`.
      RETURN.
    ENDIF.


    IF ls_set-alert_hours = 0.
      temp44 = `the UTC hour running now`.
    ELSE.
      temp44 = |the UTC hour running now and the { ls_set-alert_hours } before|.
    ENDIF.

    lv_window = temp44.
    IF it_now IS INITIAL.
      result-strip_type = `Success`.
      result-text       = |No alert threshold exceeded in { lv_window }.|.
    ELSE.
      result-strip_type = `Error`.
      result-text       = |{ lines( it_now ) } alert threshold(s) exceeded in { lv_window }.|.
    ENDIF.


    IF result-notifier IS INITIAL.
      temp45 = ` - nobody is told: no class implements z2ui5_if_cockpit_notify.`.
    ELSE.
      temp45 = | - notification: { result-notifier }.|.
    ENDIF.
    result-text = result-text && | Alerts are kept and sent by the housekeeping job z2ui5_cl_cockpit_job=>run( )| &&
                  temp45.

  ENDMETHOD.

  METHOD get_notifier_class.
    DATA lt_classes TYPE z2ui5_cl_cockpit_setup=>ty_t_names.
    DATA temp46 TYPE string.
    DATA temp47 TYPE string.

    IF gv_notifier_known = abap_true.
      result = gv_notifier.
      RETURN.
    ENDIF.


    lt_classes = z2ui5_cl_cockpit_inst=>get_implementers( z2ui5_cl_cockpit_inst=>obj_name( c_notify_intf ) ).

    CLEAR temp46.

    READ TABLE lt_classes INTO temp47 INDEX 1.
    IF sy-subrc = 0.
      temp46 = temp47.
    ENDIF.
    gv_notifier = temp46.
    gv_notifier_known = abap_true.
    result = gv_notifier.

  ENDMETHOD.

  METHOD send_test.

    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA temp48 TYPE ty_s_alert.
    DATA ls_alert LIKE temp48.
    ls_set = z2ui5_cl_cockpit_setup=>get( ).

    CLEAR temp48.
    temp48-event = z2ui5_if_cockpit_notify=>cs_event-test.
    temp48-rule = z2ui5_if_cockpit_notify=>cs_rule-error_rate.
    temp48-value = `0 %`.
    temp48-limit = |{ ls_set-alert_err_pct } %|.
    temp48-raised = z2ui5_cl_cockpit_setup=>ts_text( z2ui5_cl_cockpit_setup=>now( ) ).
    temp48-system = |{ sy-sysid }/{ sy-mandt }|.

    ls_alert = temp48.
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

    DATA temp49 TYPE string.
    IF app IS INITIAL.
      temp49 = `over all apps`.
    ELSE.
      temp49 = |in { app }|.
    ENDIF.
    result = temp49.

  ENDMETHOD.

ENDCLASS.
