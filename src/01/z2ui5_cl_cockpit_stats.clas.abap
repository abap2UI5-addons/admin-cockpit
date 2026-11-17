"! <p class="shorttext synchronized">admin cockpit - monitor statistics</p>
"!
"! The read side of the roundtrip monitor: what the Overview, Apps, Errors,
"! Performance and Live tabs show. Reads only the cockpit's own tables - it
"! activates on every abap2UI5 release, and simply finds no data where the
"! monitor (package 02) is not installed.
"!
"! Days are UTC days. Sums over several days are added up here in packed
"! numbers; the database only sums one day at a time.
CLASS z2ui5_cl_cockpit_stats DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF cs_monitor,
        active       TYPE string VALUE `ACTIVE`,
        off          TYPE string VALUE `OFF`,
        other        TYPE string VALUE `OTHER`,
        no_interface TYPE string VALUE `NO_INTERFACE`,
        no_class     TYPE string VALUE `NO_CLASS`,
        " fed by the ICF handler line z2ui5_cl_cockpit_wire=>run( ), no hook
        handler      TYPE string VALUE `HANDLER`,
      END OF cs_monitor.

    " without the prefix - z2ui5_cl_cockpit_inst=>obj_name( ) puts it in front
    CONSTANTS c_monitor_intf  TYPE string VALUE `IF_UI5_MONITOR`.
    CONSTANTS c_monitor_class TYPE string VALUE `CL_COCKPIT_MONITOR`.

    TYPES:
      BEGIN OF ty_s_monitor,
        state        TYPE string,
        check_data   TYPE abap_bool,
        strip_type   TYPE string,
        text         TYPE string,
        active_class TYPE string,
      END OF ty_s_monitor.

    TYPES:
      BEGIN OF ty_s_kpi,
        users            TYPE string,
        roundtrips       TYPE i,
        p95_ms           TYPE i,
        p95_state        TYPE string,
        avg_ms           TYPE i,
        errors           TYPE i,
        error_rate       TYPE string,
        error_state      TYPE string,
        drafts           TYPE i,
        drafts_state     TYPE string,
      END OF ty_s_kpi.

    TYPES:
      BEGIN OF ty_s_day,
        day        TYPE string,
        roundtrips TYPE i,
        users      TYPE i,
        errors     TYPE i,
        avg_ms     TYPE i,
        p95_ms     TYPE i,
        bar        TYPE i,
        bar_text   TYPE string,
        state      TYPE string,
      END OF ty_s_day.
    TYPES ty_t_day TYPE STANDARD TABLE OF ty_s_day WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_app,
        app          TYPE string,
        users        TYPE i,
        sessions     TYPE i,
        roundtrips   TYPE i,
        avg_ms       TYPE i,
        p95_ms       TYPE i,
        kb_res_avg   TYPE i,
        kb_model_max TYPE i,
        errors       TYPE i,
        error_state  TYPE string,
        last_used    TYPE string,
      END OF ty_s_app.
    TYPES ty_t_app TYPE STANDARD TABLE OF ty_s_app WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_event,
        event      TYPE string,
        roundtrips TYPE i,
        avg_ms     TYPE i,
        p95_ms     TYPE i,
        max_ms     TYPE i,
        errors     TYPE i,
        kb_res_avg TYPE i,
        last_used  TYPE string,
      END OF ty_s_event.
    TYPES ty_t_event TYPE STANDARD TABLE OF ty_s_event WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_unused,
        app       TYPE string,
        last_used TYPE string,
      END OF ty_s_unused.
    TYPES ty_t_unused TYPE STANDARD TABLE OF ty_s_unused WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_error,
        key         TYPE string,
        app         TYPE string,
        event       TYPE string,
        error_class TYPE string,
        error_head  TYPE string,
        count       TYPE i,
        first_seen  TYPE string,
        last_seen   TYPE string,
      END OF ty_s_error.
    TYPES ty_t_error TYPE STANDARD TABLE OF ty_s_error WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_occurrence,
        id            TYPE string,
        time          TYPE string,
        user          TYPE string,
        draft_id      TYPE string,
        draft_id_prev TYPE string,
        event         TYPE string,
        check_sticky  TYPE abap_bool,
        ms_total      TYPE i,
        start         TYPE string,
        " what the user did afterwards, from the drafts - filled by the app
        afterwards       TYPE string,
        afterwards_state TYPE string,
      END OF ty_s_occurrence.
    TYPES ty_t_occurrence TYPE STANDARD TABLE OF ty_s_occurrence WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_slow,
        id         TYPE string,
        time       TYPE string,
        app        TYPE string,
        event      TYPE string,
        ms_total   TYPE i,
        ms_load    TYPE i,
        ms_main    TYPE i,
        ms_render  TYPE i,
        ms_client  TYPE i,
        kb_res     TYPE i,
        kb_model   TYPE i,
        phase      TYPE string,
        main_share TYPE i,
        error      TYPE string,
      END OF ty_s_slow.
    TYPES ty_t_slow TYPE STANDARD TABLE OF ty_s_slow WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_hint,
        state TYPE string,
        app   TYPE string,
        hint  TYPE string,
        value TYPE string,
        fix   TYPE string,
      END OF ty_s_hint.
    TYPES ty_t_hint TYPE STANDARD TABLE OF ty_s_hint WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_live_app,
        app       TYPE string,
        users     TYPE i,
        last_seen TYPE string,
        event     TYPE string,
      END OF ty_s_live_app.
    TYPES ty_t_live_app TYPE STANDARD TABLE OF ty_s_live_app WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_live,
        sessions     TYPE i,
        users        TYPE i,
        apps         TYPE i,
        minutes      TYPE i,
        check_lock   TYPE abap_bool,
        t_app        TYPE ty_t_live_app,
      END OF ty_s_live.

    TYPES:
      BEGIN OF ty_s_window,
        " the app class, empty for the line over all apps
        app        TYPE string,
        roundtrips TYPE i,
        errors     TYPE i,
        p95_ms     TYPE i,
      END OF ty_s_window.
    TYPES ty_t_window TYPE STANDARD TABLE OF ty_s_window WITH DEFAULT KEY.

    CLASS-METHODS get_monitor
      RETURNING
        VALUE(result) TYPE ty_s_monitor.

    CLASS-METHODS get_kpi
      RETURNING
        VALUE(result) TYPE ty_s_kpi.

    "! One row per UTC day, newest first.
    CLASS-METHODS get_trend
      IMPORTING
        days          TYPE i DEFAULT 30
      RETURNING
        VALUE(result) TYPE ty_t_day.

    CLASS-METHODS get_apps
      IMPORTING
        days          TYPE i
      RETURNING
        VALUE(result) TYPE ty_t_app.

    CLASS-METHODS get_app_events
      IMPORTING
        app           TYPE clike
        days          TYPE i
      RETURNING
        VALUE(result) TYPE ty_t_event.

    "! Implementers of z2ui5_if_app without a recorded roundtrip within the
    "! unused_days setting.
    CLASS-METHODS get_unused
      RETURNING
        VALUE(result) TYPE ty_t_unused.

    CLASS-METHODS get_errors
      IMPORTING
        days          TYPE i
      RETURNING
        VALUE(result) TYPE ty_t_error.

    CLASS-METHODS get_error_occurrences
      IMPORTING
        is_error      TYPE ty_s_error
        days          TYPE i
      RETURNING
        VALUE(result) TYPE ty_t_occurrence.

    CLASS-METHODS get_error_text
      IMPORTING
        id            TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! Whose draft a logged roundtrip worked on, as far as the log can tell -
    "! z2ui5_cl_cockpit_repro=&gt;cs_owner. Known from the user name (user
    "! tracking NAME) or from today's pseudonym (HASH, same UTC day only - the
    "! salt of an earlier day is gone, which is the point of it).
    CLASS-METHODS get_occurrence_owner
      IMPORTING
        id            TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS get_slowest
      IMPORTING
        days          TYPE i
        max_rows      TYPE i DEFAULT 50
      RETURNING
        VALUE(result) TYPE ty_t_slow.

    CLASS-METHODS get_hints
      IMPORTING
        days          TYPE i
      RETURNING
        VALUE(result) TYPE ty_t_hint.

    CLASS-METHODS get_live
      IMPORTING
        minutes       TYPE i DEFAULT 5
      RETURNING
        VALUE(result) TYPE ty_s_live.

    "! The figures the alert rules look at: per app and one line over all
    "! apps (app empty, first), for the UTC hour running now and the given
    "! number of full hours before it.
    "! @parameter hours | full UTC hours before the running one, 0 to 23
    CLASS-METHODS get_window
      IMPORTING
        hours         TYPE i
      RETURNING
        VALUE(result) TYPE ty_t_window.

  PROTECTED SECTION.

  PRIVATE SECTION.

    TYPES ty_p TYPE p LENGTH 16 DECIMALS 0.

    "! Whether the aggregates hold a roundtrip of the last 7 days.
    CLASS-METHODS check_recent
      RETURNING
        VALUE(result) TYPE abap_bool.

    TYPES:
      BEGIN OF ty_s_sum,
        utc_day   TYPE c LENGTH 8,
        app       TYPE c LENGTH 30,
        event     TYPE c LENGTH 40,
        utc_hour  TYPE c LENGTH 2,
        cnt       TYPE ty_p,
        cnt_start TYPE ty_p,
        cnt_err   TYPE ty_p,
        ms_sum    TYPE ty_p,
        ms_max    TYPE i,
        ms_load   TYPE ty_p,
        ms_main   TYPE ty_p,
        ms_render TYPE ty_p,
        ms_client TYPE ty_p,
        cnt_client TYPE ty_p,
        kb_res    TYPE ty_p,
        res_max   TYPE i,
        mod_max   TYPE i,
        h01       TYPE ty_p,
        h02       TYPE ty_p,
        h03       TYPE ty_p,
        h04       TYPE ty_p,
        h05       TYPE ty_p,
        h06       TYPE ty_p,
        h07       TYPE ty_p,
        h08       TYPE ty_p,
        h09       TYPE ty_p,
      END OF ty_s_sum.

    TYPES:
      BEGIN OF ty_s_db_sum,
        utc_day   TYPE c LENGTH 8,
        app       TYPE c LENGTH 30,
        event     TYPE c LENGTH 40,
        utc_hour  TYPE c LENGTH 2,
        cnt       TYPE i,
        cnt_start TYPE i,
        cnt_err   TYPE i,
        ms_sum    TYPE ty_p,
        ms_max    TYPE i,
        ms_load   TYPE ty_p,
        ms_main   TYPE ty_p,
        ms_render TYPE ty_p,
        ms_client TYPE ty_p,
        cnt_client TYPE i,
        kb_res    TYPE ty_p,
        res_max   TYPE i,
        mod_max   TYPE i,
        h01       TYPE i,
        h02       TYPE i,
        h03       TYPE i,
        h04       TYPE i,
        h05       TYPE i,
        h06       TYPE i,
        h07       TYPE i,
        h08       TYPE i,
        h09       TYPE i,
      END OF ty_s_db_sum.
    TYPES ty_t_db_sum TYPE STANDARD TABLE OF ty_s_db_sum WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_err_log,
        timestampl  TYPE timestampl,
        app         TYPE c LENGTH 30,
        event       TYPE c LENGTH 40,
        error_class TYPE c LENGTH 30,
        error_head  TYPE c LENGTH 200,
      END OF ty_s_err_log.
    TYPES ty_t_err_log TYPE STANDARD TABLE OF ty_s_err_log WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_last,
        app     TYPE c LENGTH 30,
        utc_day TYPE c LENGTH 8,
      END OF ty_s_last.
    TYPES ty_t_last TYPE SORTED TABLE OF ty_s_last WITH UNIQUE KEY app.

    TYPES ty_t_sum_app TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY app.

    "! Error log rows (newest first) grouped by app, event, exception class
    "! and first line - the group key is G1, G2, ... in order of the newest
    "! occurrence, the result sorted by count.
    CLASS-METHODS group_errors
      IMPORTING
        it_log        TYPE ty_t_err_log
      RETURNING
        VALUE(result) TYPE ty_t_error.

    "! The app classes without a recorded day on or after from_day.
    CLASS-METHODS unused_of
      IMPORTING
        it_impl       TYPE z2ui5_cl_cockpit_setup=>ty_t_names
        it_last       TYPE ty_t_last
        from_day      TYPE clike
      RETURNING
        VALUE(result) TYPE ty_t_unused.

    "! The runtime hint rules over the sums per app of the newer and the
    "! older half of the period, and the draft table figures.
    CLASS-METHODS hints_of
      IMPORTING
        it_new        TYPE ty_t_sum_app
        it_old        TYPE ty_t_sum_app
        is_set        TYPE z2ui5_cl_cockpit_setup=>ty_s_settings
        is_draft      TYPE z2ui5_cl_cockpit_draft=>ty_s_info
      RETURNING
        VALUE(result) TYPE ty_t_hint.

    "! Sums per day and app (event empty), or per day and event of one app.
    CLASS-METHODS select_sums
      IMPORTING
        from_day      TYPE clike
        app           TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_db_sum.

    CLASS-METHODS add_sum
      IMPORTING
        is_row TYPE ty_s_db_sum
      CHANGING
        cs_sum TYPE ty_s_sum.

    CLASS-METHODS p95
      IMPORTING
        is_sum        TYPE ty_s_sum
      RETURNING
        VALUE(result) TYPE i.

    CLASS-METHODS avg
      IMPORTING
        sum           TYPE ty_p
        cnt           TYPE ty_p
      RETURNING
        VALUE(result) TYPE i.

    CLASS-METHODS day_text
      IMPORTING
        day           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS last_text
      IMPORTING
        day           TYPE clike
        hour          TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS to_i
      IMPORTING
        val           TYPE ty_p
      RETURNING
        VALUE(result) TYPE i.

ENDCLASS.


CLASS z2ui5_cl_cockpit_stats IMPLEMENTATION.

  METHOD get_monitor.

    DATA lv_handler_line TYPE string.
    DATA lv_hook TYPE abap_bool.
    DATA temp1 TYPE xsdboolean.
    DATA lt_impl TYPE z2ui5_cl_cockpit_setup=>ty_t_names.
    DATA temp38 TYPE z2ui5_cl_cockpit_stats=>ty_s_monitor-active_class.
    DATA temp39 TYPE string.
    lv_handler_line = `Or replace abap2UI5's call in your HTTP handler class by z2ui5_cl_cockpit_wire=>run( server ) - ` &&
                      `it records on every abap2UI5 release (Installation tab, row Recorder, says where).`.



    temp1 = boolc( z2ui5_cl_cockpit_inst=>check_type_exists( z2ui5_cl_cockpit_inst=>obj_name( c_monitor_intf ) ) = abap_true AND z2ui5_cl_cockpit_inst=>check_class_exists( z2ui5_cl_cockpit_inst=>obj_name( c_monitor_class ) ) = abap_true ).
    lv_hook = temp1.

    " without the hook the numbers come from the handler line - recent ones
    " show that it is in place
    IF lv_hook = abap_false AND check_recent( ) = abap_true.
      result-check_data = abap_true.
      IF z2ui5_cl_cockpit_setup=>get( )-mode = z2ui5_cl_cockpit_setup=>cs_mode-off.
        result-state      = cs_monitor-off.
        result-strip_type = `Warning`.
        result-text       = `Recording is switched off (Settings tab, mode OFF) - the numbers below stop at that point.`.
      ELSE.
        result-state      = cs_monitor-handler.
        result-strip_type = `Success`.
        result-text       = |Recording through the HTTP handler (z2ui5_cl_cockpit_wire=>run): mode | &&
                            |{ z2ui5_cl_cockpit_setup=>get( )-mode }, user tracking | &&
                            |{ z2ui5_cl_cockpit_setup=>get( )-user_tracking }, days in UTC. Phases of a roundtrip | &&
                            |(load, main, render) need the monitor hook.|.
      ENDIF.
      RETURN.
    ENDIF.

    IF z2ui5_cl_cockpit_inst=>check_type_exists( z2ui5_cl_cockpit_inst=>obj_name( c_monitor_intf ) ) = abap_false.
      CLEAR result.
      result-state = cs_monitor-no_interface.
      result-strip_type = `Information`.
      result-text = |Nothing recorded yet. The roundtrip monitor hook { z2ui5_cl_cockpit_inst=>obj_name( c_monitor_intf ) } ships with | &&
|the abap2UI5 release after { z2ui5_if_app=>version }. { lv_handler_line } | &&
|Installation & Security and Drafts work already.|.
      RETURN.
    ENDIF.

    IF z2ui5_cl_cockpit_inst=>check_class_exists( z2ui5_cl_cockpit_inst=>obj_name( c_monitor_class ) ) = abap_false.
      CLEAR result.
      result-state = cs_monitor-no_class.
      result-strip_type = `Information`.
      result-text = |Your abap2UI5 offers the monitor hook, but the cockpit's monitor class | &&
|{ z2ui5_cl_cockpit_inst=>obj_name( c_monitor_class ) } (package 02) is not installed - pull the main branch | &&
|of the admin cockpit. { lv_handler_line }|.
      RETURN.
    ENDIF.

    result-check_data = abap_true.

    lt_impl = z2ui5_cl_cockpit_inst=>get_implementers( z2ui5_cl_cockpit_inst=>obj_name( c_monitor_intf ) ).

    CLEAR temp38.

    READ TABLE lt_impl INTO temp39 INDEX 1.
    IF sy-subrc = 0.
      temp38 = temp39.
    ENDIF.
    result-active_class = temp38.

    IF result-active_class IS NOT INITIAL AND result-active_class <> z2ui5_cl_cockpit_inst=>obj_name( c_monitor_class ).
      result-state      = cs_monitor-other.
      result-strip_type = `Warning`.
      result-text       = |{ result-active_class } is the active monitor - abap2UI5 calls only the first | &&
                          |implementer by name. Forward from it to z2ui5_cl_cockpit_rec=>record( ) | &&
                          |to fill these tabs.|.
    ELSEIF z2ui5_cl_cockpit_setup=>get( )-mode = z2ui5_cl_cockpit_setup=>cs_mode-off.
      result-state      = cs_monitor-off.
      result-strip_type = `Warning`.
      result-text       = `Recording is switched off (Settings tab, mode OFF) - the numbers below stop at that point.`.
    ELSE.
      result-state      = cs_monitor-active.
      result-strip_type = `Success`.
      result-text       = |Recording: mode { z2ui5_cl_cockpit_setup=>get( )-mode }, | &&
                          |user tracking { z2ui5_cl_cockpit_setup=>get( )-user_tracking }, days in UTC.|.
    ENDIF.

  ENDMETHOD.

  METHOD check_recent.

    DATA lv_from TYPE c LENGTH 8.
        DATA temp40 TYPE z2ui5_t_22-utc_day.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( 6 ).
    TRY.

        SELECT SINGLE utc_day FROM z2ui5_t_22 INTO temp40
          WHERE utc_day >= lv_from
          .
CLEAR result.
IF sy-subrc = 0.
  result = abap_true.
ENDIF. "#EC CI_NOORDER
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.

  METHOD get_kpi.

    DATA lv_rate TYPE p LENGTH 8 DECIMALS 1.
    DATA lv_users TYPE i.
    DATA lv_today TYPE string.
    DATA ls_sum TYPE ty_s_sum.
    DATA temp41 TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA ls_row LIKE LINE OF temp41.
      DATA temp42 TYPE z2ui5_cl_cockpit_stats=>ty_s_kpi-error_state.
    DATA lv_slow TYPE z2ui5_cl_cockpit_setup=>ty_s_settings-slow_ms.
    DATA temp43 TYPE z2ui5_cl_cockpit_stats=>ty_s_kpi-p95_state.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.
    DATA temp44 TYPE z2ui5_cl_cockpit_stats=>ty_s_kpi-drafts_state.
    lv_today = z2ui5_cl_cockpit_setup=>day_minus( 0 ).



    temp41 = select_sums( lv_today ).

    LOOP AT temp41 INTO ls_row.
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = ls_sum ).
    ENDLOOP.

    result-roundtrips = to_i( ls_sum-cnt ).
    result-errors     = to_i( ls_sum-cnt_err ).
    result-avg_ms     = avg( sum = ls_sum-ms_sum
                             cnt = ls_sum-cnt ).
    result-p95_ms     = p95( ls_sum ).

    IF z2ui5_cl_cockpit_setup=>get( )-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-none.
      result-users = `-`.
    ELSE.
      SELECT COUNT( DISTINCT user_key ) FROM z2ui5_t_27 INTO lv_users
        WHERE utc_day = lv_today
        .
      result-users = |{ lv_users }|.
    ENDIF.

    IF ls_sum-cnt > 0.
      lv_rate = ls_sum-cnt_err * 100 / ls_sum-cnt.
      result-error_rate = |{ lv_rate }|.

      IF lv_rate >= 5.
        temp42 = `Error`.
      ELSEIF lv_rate >= 1.
        temp42 = `Critical`.
      ELSE.
        temp42 = `Good`.
      ENDIF.
      result-error_state = temp42.
    ELSE.
      result-error_rate  = `0`.
      result-error_state = `Neutral`.
    ENDIF.


    lv_slow = z2ui5_cl_cockpit_setup=>get( )-slow_ms.

    IF result-roundtrips = 0.
      temp43 = `Neutral`.
    ELSEIF result-p95_ms >= lv_slow.
      temp43 = `Error`.
    ELSEIF result-p95_ms >= lv_slow / 2.
      temp43 = `Critical`.
    ELSE.
      temp43 = `Good`.
    ENDIF.
    result-p95_state = temp43.


    ls_draft = z2ui5_cl_cockpit_draft=>get_info( ).
    result-drafts = ls_draft-rows.

    IF ls_draft-check_backlog = abap_true.
      temp44 = `Critical`.
    ELSE.
      temp44 = `Neutral`.
    ENDIF.
    result-drafts_state = temp44.

  ENDMETHOD.

  METHOD get_trend.

    DATA lv_date TYPE d.
    DATA lv_max TYPE ty_p.
    TYPES:
      BEGIN OF ty_s_users,
        utc_day TYPE c LENGTH 8,
        cnt TYPE i,
      END OF ty_s_users.
    TYPES temp1 TYPE STANDARD TABLE OF ty_s_users WITH DEFAULT KEY.
DATA lt_users TYPE temp1.
    TYPES temp2 TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY utc_day.
DATA lt_sum TYPE temp2.
    DATA ls_acc TYPE ty_s_sum.

    DATA lv_from TYPE string.
    DATA temp45 TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA ls_row LIKE LINE OF temp45.
    DATA ls_sum LIKE LINE OF lt_sum.
    DATA lv_slow TYPE z2ui5_cl_cockpit_setup=>ty_s_settings-slow_ms.
      DATA temp46 TYPE string.
      DATA lv_day LIKE temp46.
      DATA temp47 TYPE ty_s_day.
      DATA ls_day LIKE temp47.
      DATA ls_users TYPE ty_s_users.
      DATA temp48 TYPE z2ui5_cl_cockpit_stats=>ty_s_day-state.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    " a line of a sorted table is never passed to add_sum( ) by field symbol:
    " its key is write-protected, and a CHANGING parameter bound to it is the
    " runtime error CX_SY_DYN_CALL_ILLEGAL_TYPE - read, add, modify instead

    temp45 = select_sums( lv_from ).

    LOOP AT temp45 INTO ls_row.
      READ TABLE lt_sum WITH TABLE KEY utc_day = ls_row-utc_day INTO ls_acc.
      IF sy-subrc <> 0.
        CLEAR ls_acc.
        ls_acc-utc_day = ls_row-utc_day.
        INSERT ls_acc INTO TABLE lt_sum.
      ENDIF.
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = ls_acc ).
      MODIFY TABLE lt_sum FROM ls_acc.
    ENDLOOP.

    SELECT utc_day COUNT( DISTINCT user_key ) AS cnt FROM z2ui5_t_27 INTO CORRESPONDING FIELDS OF TABLE lt_users
      WHERE utc_day >= lv_from
      GROUP BY utc_day
      .


    LOOP AT lt_sum INTO ls_sum.
      IF ls_sum-cnt > lv_max.
        lv_max = ls_sum-cnt.
      ENDIF.
    ENDLOOP.


    lv_slow = z2ui5_cl_cockpit_setup=>get( )-slow_ms.
    lv_date = z2ui5_cl_cockpit_setup=>day_minus( 0 ).
    DO days TIMES.

      temp46 = lv_date.

      lv_day = temp46.

      CLEAR temp47.
      temp47-day = day_text( lv_day ).

      ls_day = temp47.
      READ TABLE lt_sum INTO ls_sum WITH TABLE KEY utc_day = lv_day.
      IF sy-subrc = 0.
        ls_day-roundtrips = to_i( ls_sum-cnt ).
        ls_day-errors     = to_i( ls_sum-cnt_err ).
        ls_day-avg_ms     = avg( sum = ls_sum-ms_sum
                                 cnt = ls_sum-cnt ).
        ls_day-p95_ms     = p95( ls_sum ).
        IF lv_max > 0.
          ls_day-bar = to_i( ls_sum-cnt * 100 / lv_max ).
        ENDIF.
      ENDIF.

      READ TABLE lt_users INTO ls_users WITH KEY utc_day = lv_day. "#EC CI_SORTSEQ
      IF sy-subrc = 0.
        ls_day-users = ls_users-cnt.
      ENDIF.
      ls_day-bar_text = |{ ls_day-roundtrips }|.

      IF ls_day-errors > 0.
        temp48 = `Error`.
      ELSEIF ls_day-p95_ms >= lv_slow.
        temp48 = `Warning`.
      ELSE.
        temp48 = `Information`.
      ENDIF.
      ls_day-state = temp48.
      APPEND ls_day TO result.
      lv_date = lv_date - 1.
    ENDDO.

  ENDMETHOD.

  METHOD get_apps.

    TYPES:
      BEGIN OF ty_s_users,
        utc_day TYPE c LENGTH 8,
        app TYPE c LENGTH 30,
        cnt TYPE i,
      END OF ty_s_users.
    TYPES temp3 TYPE STANDARD TABLE OF ty_s_users WITH DEFAULT KEY.
DATA lt_users TYPE temp3.
    TYPES temp4 TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY app.
DATA lt_sum TYPE temp4.
    DATA ls_acc TYPE ty_s_sum.

    DATA lv_from TYPE string.
    DATA temp49 TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA ls_row LIKE LINE OF temp49.
    DATA ls_sum LIKE LINE OF lt_sum.
      DATA temp50 TYPE ty_s_app.
      DATA temp7 TYPE z2ui5_cl_cockpit_stats=>ty_s_app-app.
      DATA ls_app LIKE temp50.
      DATA ls_users LIKE LINE OF lt_users.
      DATA temp51 TYPE z2ui5_cl_cockpit_stats=>ty_s_app-error_state.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).


    temp49 = select_sums( lv_from ).

    LOOP AT temp49 INTO ls_row.
      READ TABLE lt_sum WITH TABLE KEY app = ls_row-app INTO ls_acc.
      IF sy-subrc <> 0.
        CLEAR ls_acc.
        ls_acc-app = ls_row-app.
        INSERT ls_acc INTO TABLE lt_sum.
      ENDIF.
      " the newest day and hour of the group, for "last used"
      IF ls_row-utc_day > ls_acc-utc_day OR ( ls_row-utc_day = ls_acc-utc_day AND ls_row-utc_hour > ls_acc-utc_hour ).
        ls_acc-utc_day  = ls_row-utc_day.
        ls_acc-utc_hour = ls_row-utc_hour.
      ENDIF.
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = ls_acc ).
      MODIFY TABLE lt_sum FROM ls_acc.
    ENDLOOP.

    SELECT utc_day app COUNT( * ) AS cnt FROM z2ui5_t_27 INTO CORRESPONDING FIELDS OF TABLE lt_users
      WHERE utc_day >= lv_from
      GROUP BY utc_day, app
      .


    LOOP AT lt_sum INTO ls_sum.

      CLEAR temp50.

      IF ls_sum-app IS INITIAL.
        temp7 = `(no app resolved)`.
      ELSE.
        temp7 = ls_sum-app.
      ENDIF.
      temp50-app = temp7.
      temp50-sessions = to_i( ls_sum-cnt_start ).
      temp50-roundtrips = to_i( ls_sum-cnt ).
      temp50-avg_ms = avg( sum = ls_sum-ms_sum cnt = ls_sum-cnt ).
      temp50-p95_ms = p95( ls_sum ).
      temp50-kb_res_avg = avg( sum = ls_sum-kb_res cnt = ls_sum-cnt ).
      temp50-kb_model_max = ls_sum-mod_max DIV 1024.
      temp50-errors = to_i( ls_sum-cnt_err ).
      temp50-last_used = last_text( day = ls_sum-utc_day hour = ls_sum-utc_hour ).

      ls_app = temp50.
      " users: the most on one day - pseudonyms change daily, so a distinct
      " count across days would count the same person once per day

      LOOP AT lt_users INTO ls_users WHERE app = ls_sum-app. "#EC CI_SORTSEQ
        IF ls_users-cnt > ls_app-users.
          ls_app-users = ls_users-cnt.
        ENDIF.
      ENDLOOP.

      IF ls_app-errors > 0.
        temp51 = `Error`.
      ELSE.
        temp51 = `None`.
      ENDIF.
      ls_app-error_state = temp51.
      APPEND ls_app TO result.
    ENDLOOP.

    SORT result BY roundtrips DESCENDING.

  ENDMETHOD.

  METHOD get_app_events.

    TYPES temp5 TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY event.
DATA lt_sum TYPE temp5.
    DATA ls_acc TYPE ty_s_sum.

    DATA lv_from TYPE string.
    DATA temp52 TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA ls_row LIKE LINE OF temp52.
    DATA ls_sum LIKE LINE OF lt_sum.
      DATA temp53 TYPE z2ui5_cl_cockpit_stats=>ty_s_event.
      DATA temp8 TYPE z2ui5_cl_cockpit_stats=>ty_s_event-event.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).


    temp52 = select_sums( from_day = lv_from app = app ).

    LOOP AT temp52 INTO ls_row.
      READ TABLE lt_sum WITH TABLE KEY event = ls_row-event INTO ls_acc.
      IF sy-subrc <> 0.
        CLEAR ls_acc.
        ls_acc-event = ls_row-event.
        INSERT ls_acc INTO TABLE lt_sum.
      ENDIF.
      IF ls_row-utc_day > ls_acc-utc_day OR ( ls_row-utc_day = ls_acc-utc_day AND ls_row-utc_hour > ls_acc-utc_hour ).
        ls_acc-utc_day  = ls_row-utc_day.
        ls_acc-utc_hour = ls_row-utc_hour.
      ENDIF.
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = ls_acc ).
      MODIFY TABLE lt_sum FROM ls_acc.
    ENDLOOP.


    LOOP AT lt_sum INTO ls_sum.

      CLEAR temp53.

      IF ls_sum-event IS INITIAL.
        temp8 = `(start / navigation)`.
      ELSE.
        temp8 = ls_sum-event.
      ENDIF.
      temp53-event = temp8.
      temp53-roundtrips = to_i( ls_sum-cnt ).
      temp53-avg_ms = avg( sum = ls_sum-ms_sum cnt = ls_sum-cnt ).
      temp53-p95_ms = p95( ls_sum ).
      temp53-max_ms = ls_sum-ms_max.
      temp53-errors = to_i( ls_sum-cnt_err ).
      temp53-kb_res_avg = avg( sum = ls_sum-kb_res cnt = ls_sum-cnt ).
      temp53-last_used = last_text( day = ls_sum-utc_day hour = ls_sum-utc_hour ).
      APPEND temp53 TO result.
    ENDLOOP.

    SORT result BY roundtrips DESCENDING.

  ENDMETHOD.

  METHOD get_unused.

    DATA lt_last TYPE ty_t_last.

    DATA lv_from TYPE string.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( z2ui5_cl_cockpit_setup=>get( )-unused_days ).

    SELECT app MAX( utc_day ) AS utc_day FROM z2ui5_t_22
      GROUP BY app
      INTO CORRESPONDING FIELDS OF TABLE lt_last.      "#EC CI_NOWHERE

    result = unused_of( it_impl   = z2ui5_cl_cockpit_inst=>get_implementers( z2ui5_cl_cockpit_inst=>obj_name( `IF_APP` ) )
                        it_last   = lt_last
                        from_day  = lv_from ).

  ENDMETHOD.

  METHOD unused_of.

    DATA lv_app LIKE LINE OF it_impl.
      DATA temp54 TYPE ty_s_last-app.
      DATA lv_key LIKE temp54.
      DATA ls_last TYPE z2ui5_cl_cockpit_stats=>ty_s_last.
        DATA temp55 TYPE z2ui5_cl_cockpit_stats=>ty_s_unused.
        DATA temp56 TYPE z2ui5_cl_cockpit_stats=>ty_s_unused.
    LOOP AT it_impl INTO lv_app.

      temp54 = to_upper( lv_app ).

      lv_key = temp54.

      READ TABLE it_last INTO ls_last WITH TABLE KEY app = lv_key.
      IF sy-subrc <> 0.

        CLEAR temp55.
        temp55-app = lv_app.
        temp55-last_used = `never recorded`.
        APPEND temp55 TO result.
      ELSEIF ls_last-utc_day < from_day.

        CLEAR temp56.
        temp56-app = lv_app.
        temp56-last_used = day_text( ls_last-utc_day ).
        APPEND temp56 TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_errors.

    DATA lt_log TYPE ty_t_err_log.

    DATA lv_from TYPE string.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    SELECT timestampl app event error_class error_head FROM z2ui5_t_25 INTO CORRESPONDING FIELDS OF TABLE lt_log
      WHERE utc_day >= lv_from
        AND check_error = abap_true
      ORDER BY timestampl DESCENDING

      UP TO 5000 ROWS.

    result = group_errors( lt_log ).

  ENDMETHOD.

  METHOD group_errors.

    TYPES temp6 TYPE STANDARD TABLE OF timestampl WITH DEFAULT KEY.
DATA lt_first TYPE temp6.
    TYPES temp7 TYPE STANDARD TABLE OF timestampl WITH DEFAULT KEY.
DATA lt_last TYPE temp7.

    DATA ls_log LIKE LINE OF it_log.
      FIELD-SYMBOLS <error> TYPE z2ui5_cl_cockpit_stats=>ty_s_error.
      DATA lv_index LIKE sy-tabix.
        DATA temp57 TYPE z2ui5_cl_cockpit_stats=>ty_s_error.
      FIELD-SYMBOLS <temp58> LIKE LINE OF lt_first.
      DATA temp59 LIKE sy-tabix.
      FIELD-SYMBOLS <temp60> LIKE LINE OF lt_first.
      DATA temp61 LIKE sy-tabix.
      FIELD-SYMBOLS <temp62> LIKE LINE OF lt_last.
      DATA temp63 LIKE sy-tabix.
    LOOP AT it_log INTO ls_log.

      READ TABLE result ASSIGNING <error>
           WITH KEY app         = ls_log-app
                    event       = ls_log-event
                    error_class = ls_log-error_class
                    error_head  = ls_log-error_head.     "#EC CI_SORTSEQ

      lv_index = sy-tabix.
      IF sy-subrc <> 0.

        CLEAR temp57.
        temp57-key = |G{ lines( result ) + 1 }|.
        temp57-app = ls_log-app.
        temp57-event = ls_log-event.
        temp57-error_class = ls_log-error_class.
        temp57-error_head = ls_log-error_head.
        APPEND temp57 TO result ASSIGNING <error>.
        lv_index = lines( result ).
        " the rows come newest first: the first row of a group is its last
        " occurrence, every later one moves the first occurrence back
        APPEND ls_log-timestampl TO lt_last.
        APPEND ls_log-timestampl TO lt_first.
      ENDIF.
      <error>-count = <error>-count + 1.


      temp59 = sy-tabix.
      READ TABLE lt_first INDEX lv_index ASSIGNING <temp58>.
      sy-tabix = temp59.
      IF sy-subrc <> 0.
        ASSERT 1 = 0.
      ENDIF.
      <temp58> = ls_log-timestampl.
    ENDLOOP.

    LOOP AT result ASSIGNING <error>.
      lv_index = sy-tabix.


      temp61 = sy-tabix.
      READ TABLE lt_first INDEX lv_index ASSIGNING <temp60>.
      sy-tabix = temp61.
      IF sy-subrc <> 0.
        ASSERT 1 = 0.
      ENDIF.
      <error>-first_seen = z2ui5_cl_cockpit_setup=>ts_text( <temp60> ).


      temp63 = sy-tabix.
      READ TABLE lt_last INDEX lv_index ASSIGNING <temp62>.
      sy-tabix = temp63.
      IF sy-subrc <> 0.
        ASSERT 1 = 0.
      ENDIF.
      <error>-last_seen  = z2ui5_cl_cockpit_setup=>ts_text( <temp62> ).
    ENDLOOP.

    SORT result STABLE BY count DESCENDING.

  ENDMETHOD.

  METHOD get_error_occurrences.

    TYPES:
      BEGIN OF ty_s_log,
        id            TYPE c LENGTH 32,
        timestampl    TYPE timestampl,
        event         TYPE c LENGTH 40,
        uname         TYPE c LENGTH 12,
        user_key      TYPE c LENGTH 64,
        draft_id      TYPE c LENGTH 32,
        draft_id_prev TYPE c LENGTH 32,
        check_sticky  TYPE abap_bool,
        ms_total      TYPE i,
        check_start   TYPE abap_bool,
      END OF ty_s_log.
    TYPES temp8 TYPE STANDARD TABLE OF ty_s_log WITH DEFAULT KEY.
DATA lt_log TYPE temp8.

    DATA lv_from TYPE string.
    DATA lv_app LIKE is_error-app.
    DATA lv_event LIKE is_error-event.
    DATA lv_class LIKE is_error-error_class.
    DATA lv_head LIKE is_error-error_head.
    DATA lv_privacy TYPE abap_bool.
    DATA ls_log LIKE LINE OF lt_log.
      DATA temp64 TYPE ty_s_occurrence.
      DATA temp9 TYPE z2ui5_cl_cockpit_stats=>ty_s_occurrence-start.
      DATA ls_occ LIKE temp64.
    lv_from  = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    lv_app = is_error-app.

    lv_event = is_error-event.

    lv_class = is_error-error_class.

    lv_head = is_error-error_head.

    SELECT id timestampl event uname user_key draft_id draft_id_prev check_sticky ms_total check_start
      FROM z2ui5_t_25 INTO CORRESPONDING FIELDS OF TABLE lt_log
      WHERE utc_day >= lv_from
        AND check_error = abap_true
        AND app = lv_app
        AND event = lv_event
        AND error_class = lv_class
        AND error_head = lv_head
      ORDER BY timestampl DESCENDING

      UP TO 200 ROWS.


    lv_privacy = z2ui5_cl_cockpit_setup=>check_privacy( ).

    LOOP AT lt_log INTO ls_log.

      CLEAR temp64.
      temp64-id = ls_log-id.
      temp64-time = z2ui5_cl_cockpit_setup=>ts_text( ls_log-timestampl ).
      temp64-draft_id = ls_log-draft_id.
      temp64-draft_id_prev = ls_log-draft_id_prev.
      temp64-event = ls_log-event.
      temp64-check_sticky = ls_log-check_sticky.
      temp64-ms_total = ls_log-ms_total.

      IF ls_log-check_start = abap_true.
        temp9 = `app start`.
      ELSE.
        CLEAR temp9.
      ENDIF.
      temp64-start = temp9.

      ls_occ = temp64.
      IF lv_privacy = abap_false AND ls_log-uname IS NOT INITIAL.
        ls_occ-user = ls_log-uname.
      ELSEIF ls_log-user_key IS NOT INITIAL.
        ls_occ-user = |pseudonym { ls_log-user_key(8) }|.
      ELSE.
        ls_occ-user = `not recorded`.
      ENDIF.
      APPEND ls_occ TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_error_text.

    DATA temp65 TYPE z2ui5_t_25-id.
    DATA lv_id LIKE temp65.
    temp65 = id.

    lv_id = temp65.
    SELECT SINGLE error_text FROM z2ui5_t_25 INTO result
      WHERE id = lv_id
      .
    IF sy-subrc <> 0.
      CLEAR result.
    ENDIF.

  ENDMETHOD.

  METHOD get_occurrence_owner.

    DATA lv_uname TYPE z2ui5_t_25-uname.
    DATA lv_user_key TYPE z2ui5_t_25-user_key.
    DATA lv_day TYPE z2ui5_t_25-utc_day.
    DATA temp66 TYPE z2ui5_t_25-id.
    DATA lv_id LIKE temp66.
      DATA temp67 TYPE string.
    DATA lv_today TYPE string.
    DATA temp68 TYPE string.

    result = z2ui5_cl_cockpit_repro=>cs_owner-unknown.

    temp66 = id.

    lv_id = temp66.
    SELECT SINGLE uname user_key utc_day FROM z2ui5_t_25 INTO (lv_uname, lv_user_key, lv_day)
      WHERE id = lv_id
      .
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF lv_uname IS NOT INITIAL.

      IF lv_uname = sy-uname.
        temp67 = z2ui5_cl_cockpit_repro=>cs_owner-you.
      ELSE.
        temp67 = z2ui5_cl_cockpit_repro=>cs_owner-other.
      ENDIF.
      result = temp67.
      RETURN.
    ENDIF.


    lv_today = z2ui5_cl_cockpit_setup=>day_minus( 0 ).
    IF lv_user_key IS INITIAL OR lv_day <> lv_today
        OR z2ui5_cl_cockpit_setup=>get( )-user_tracking <> z2ui5_cl_cockpit_setup=>cs_users-hash.
      RETURN.
    ENDIF.

    IF z2ui5_cl_cockpit_setup=>user_key( uname = sy-uname day = lv_today ) = lv_user_key.
      temp68 = z2ui5_cl_cockpit_repro=>cs_owner-you.
    ELSE.
      temp68 = z2ui5_cl_cockpit_repro=>cs_owner-other.
    ENDIF.
    result = temp68.

  ENDMETHOD.

  METHOD get_slowest.

    TYPES temp9 TYPE STANDARD TABLE OF z2ui5_t_25 WITH DEFAULT KEY.
DATA lt_log TYPE temp9.

    DATA lv_from TYPE string.
    DATA ls_log LIKE LINE OF lt_log.
      DATA temp69 TYPE ty_s_slow.
      DATA temp10 TYPE z2ui5_cl_cockpit_stats=>ty_s_slow-error.
      DATA ls_slow LIKE temp69.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    SELECT id timestampl app event ms_total ms_load ms_main ms_render ms_client_prev
           bytes_response bytes_model check_error
      FROM z2ui5_t_25 INTO CORRESPONDING FIELDS OF TABLE lt_log
      WHERE utc_day >= lv_from
        AND check_slow = abap_true
      ORDER BY ms_total DESCENDING

      UP TO max_rows ROWS.


    LOOP AT lt_log INTO ls_log.

      CLEAR temp69.
      temp69-id = ls_log-id.
      temp69-time = z2ui5_cl_cockpit_setup=>ts_text( ls_log-timestampl ).
      temp69-app = ls_log-app.
      temp69-event = ls_log-event.
      temp69-ms_total = ls_log-ms_total.
      temp69-ms_load = ls_log-ms_load.
      temp69-ms_main = ls_log-ms_main.
      temp69-ms_render = ls_log-ms_render.
      temp69-ms_client = ls_log-ms_client_prev.
      temp69-kb_res = ls_log-bytes_response DIV 1024.
      temp69-kb_model = ls_log-bytes_model DIV 1024.

      IF ls_log-check_error = abap_true.
        temp10 = `error`.
      ELSE.
        CLEAR temp10.
      ENDIF.
      temp69-error = temp10.

      ls_slow = temp69.
      IF ls_log-ms_main >= ls_log-ms_load AND ls_log-ms_main >= ls_log-ms_render.
        ls_slow-phase = `main - the app's own code`.
      ELSEIF ls_log-ms_load >= ls_log-ms_render.
        ls_slow-phase = `load - draft read and deserialize`.
      ELSE.
        ls_slow-phase = `render - serialize and draft save`.
      ENDIF.
      IF ls_log-ms_total > 0.
        ls_slow-main_share = ls_log-ms_main * 100 / ls_log-ms_total.
      ENDIF.
      APPEND ls_slow TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_hints.

    DATA lt_new TYPE ty_t_sum_app.
    DATA lt_old TYPE ty_t_sum_app.
    DATA ls_acc TYPE ty_s_sum.
    DATA lv_from TYPE string.
    DATA lv_half TYPE string.
    DATA temp70 TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA ls_row LIKE LINE OF temp70.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).
    " growth: the model maximum of the newer half against the older half

    lv_half = z2ui5_cl_cockpit_setup=>day_minus( days DIV 2 ).


    temp70 = select_sums( lv_from ).

    LOOP AT temp70 INTO ls_row.
      IF ls_row-utc_day > lv_half.
        READ TABLE lt_new WITH TABLE KEY app = ls_row-app INTO ls_acc.
        IF sy-subrc <> 0.
          CLEAR ls_acc.
          ls_acc-app = ls_row-app.
          INSERT ls_acc INTO TABLE lt_new.
        ENDIF.
        add_sum( EXPORTING is_row = ls_row
                 CHANGING  cs_sum = ls_acc ).
        MODIFY TABLE lt_new FROM ls_acc.
      ELSE.
        READ TABLE lt_old WITH TABLE KEY app = ls_row-app INTO ls_acc.
        IF sy-subrc <> 0.
          CLEAR ls_acc.
          ls_acc-app = ls_row-app.
          INSERT ls_acc INTO TABLE lt_old.
        ENDIF.
        add_sum( EXPORTING is_row = ls_row
                 CHANGING  cs_sum = ls_acc ).
        MODIFY TABLE lt_old FROM ls_acc.
      ENDIF.
    ENDLOOP.

    result = hints_of( it_new   = lt_new
                       it_old   = lt_old
                       is_set   = z2ui5_cl_cockpit_setup=>get( )
                       is_draft = z2ui5_cl_cockpit_draft=>get_info( ) ).

  ENDMETHOD.

  METHOD hints_of.

    DATA lt_all TYPE ty_t_sum_app.
    DATA ls_old LIKE LINE OF it_old.
      FIELD-SYMBOLS <sum> TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
    DATA ls_sum LIKE LINE OF lt_all.
      DATA temp71 TYPE string.
      DATA lv_app LIKE temp71.
        DATA temp72 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA temp73 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
      DATA lv_p95 TYPE i.
        DATA temp74 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA temp75 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA temp76 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA temp77 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA lv_client TYPE i.
        DATA lv_server TYPE i.
          DATA temp78 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA ls_new TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
          DATA temp79 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
    DATA ls_draft LIKE is_draft.
      DATA temp80 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
      DATA temp81 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
    " the whole period per app = newer + older half
    lt_all = it_new.

    LOOP AT it_old INTO ls_old.

      READ TABLE lt_all WITH TABLE KEY app = ls_old-app ASSIGNING <sum>.
      IF sy-subrc <> 0.
        INSERT ls_old INTO TABLE lt_all.
        CONTINUE.
      ENDIF.
      <sum>-cnt       = <sum>-cnt + ls_old-cnt.
      <sum>-cnt_err   = <sum>-cnt_err + ls_old-cnt_err.
      <sum>-ms_sum    = <sum>-ms_sum + ls_old-ms_sum.
      <sum>-ms_load   = <sum>-ms_load + ls_old-ms_load.
      <sum>-ms_main   = <sum>-ms_main + ls_old-ms_main.
      <sum>-ms_render = <sum>-ms_render + ls_old-ms_render.
      <sum>-ms_client = <sum>-ms_client + ls_old-ms_client.
      <sum>-cnt_client = <sum>-cnt_client + ls_old-cnt_client.
      <sum>-h01 = <sum>-h01 + ls_old-h01.
      <sum>-h02 = <sum>-h02 + ls_old-h02.
      <sum>-h03 = <sum>-h03 + ls_old-h03.
      <sum>-h04 = <sum>-h04 + ls_old-h04.
      <sum>-h05 = <sum>-h05 + ls_old-h05.
      <sum>-h06 = <sum>-h06 + ls_old-h06.
      <sum>-h07 = <sum>-h07 + ls_old-h07.
      <sum>-h08 = <sum>-h08 + ls_old-h08.
      <sum>-h09 = <sum>-h09 + ls_old-h09.
      IF ls_old-ms_max > <sum>-ms_max.
        <sum>-ms_max = ls_old-ms_max.
      ENDIF.
      IF ls_old-res_max > <sum>-res_max.
        <sum>-res_max = ls_old-res_max.
      ENDIF.
      IF ls_old-mod_max > <sum>-mod_max.
        <sum>-mod_max = ls_old-mod_max.
      ENDIF.
    ENDLOOP.


    LOOP AT lt_all INTO ls_sum.

      temp71 = ls_sum-app.

      lv_app = temp71.

      IF ls_sum-mod_max > is_set-model_warn_kb * 1024.

        CLEAR temp72.
        temp72-state = `Warning`.
        temp72-app = lv_app.
        temp72-hint = `Large model`.
        temp72-value = |{ ls_sum-mod_max DIV 1024 } KB|.
        temp72-fix = `Every PUBLIC attribute is serialized and sent on every roundtrip - keep only ` && `bound data public, page large tables.`.
        APPEND temp72 TO result.
      ENDIF.

      IF ls_sum-res_max > is_set-response_warn_kb * 1024.

        CLEAR temp73.
        temp73-state = `Warning`.
        temp73-app = lv_app.
        temp73-hint = `Large response`.
        temp73-value = |{ ls_sum-res_max DIV 1024 } KB|.
        temp73-fix = `Avoid re-rendering the whole view on every event; bound data changes are ` && `pushed without view_display( ).`.
        APPEND temp73 TO result.
      ENDIF.


      lv_p95 = p95( ls_sum ).
      IF ls_sum-cnt >= 20 AND lv_p95 >= is_set-slow_ms.

        CLEAR temp74.
        temp74-state = `Warning`.
        temp74-app = lv_app.
        temp74-hint = `Slow p95`.
        temp74-value = |{ lv_p95 } ms|.
        temp74-fix = `See the slowest roundtrips of this app and their dominant phase.`.
        APPEND temp74 TO result.
      ENDIF.

      IF ls_sum-cnt >= 20 AND ls_sum-cnt_err * 20 >= ls_sum-cnt.

        CLEAR temp75.
        temp75-state = `Error`.
        temp75-app = lv_app.
        temp75-hint = `Error rate of 5 % or more`.
        temp75-value = |{ to_i( ls_sum-cnt_err ) } of { to_i( ls_sum-cnt ) }|.
        temp75-fix = `Errors tab: grouped by event and exception class.`.
        APPEND temp75 TO result.
      ENDIF.

      IF ls_sum-ms_sum > 0 AND ls_sum-ms_load * 2 > ls_sum-ms_sum AND ls_sum-cnt >= 20.

        CLEAR temp76.
        temp76-state = `Information`.
        temp76-app = lv_app.
        temp76-hint = `Load phase dominates`.
        temp76-value = |{ to_i( ls_sum-ms_load * 100 / ls_sum-ms_sum ) } % of the time|.
        temp76-fix = `Reading and deserializing the draft takes longer than the app itself - ` && `the app state is large.`.
        APPEND temp76 TO result.
      ENDIF.

      IF ls_sum-ms_sum > 0 AND ls_sum-ms_render * 2 > ls_sum-ms_sum AND ls_sum-cnt >= 20.

        CLEAR temp77.
        temp77-state = `Information`.
        temp77-app = lv_app.
        temp77-hint = `Render phase dominates`.
        temp77-value = |{ to_i( ls_sum-ms_render * 100 / ls_sum-ms_sum ) } % of the time|.
        temp77-fix = `Serializing model and draft takes longer than the app itself.`.
        APPEND temp77 TO result.
      ENDIF.

      IF ls_sum-cnt_client > 0 AND ls_sum-cnt > 0.

        lv_client = avg( sum = ls_sum-ms_client
                               cnt = ls_sum-cnt_client ).

        lv_server = avg( sum = ls_sum-ms_sum
                               cnt = ls_sum-cnt ).
        IF lv_client - lv_server > 1000.

          CLEAR temp78.
          temp78-state = `Information`.
          temp78-app = lv_app.
          temp78-hint = `Browser and network time dominates`.
          temp78-value = |{ lv_client } ms in the browser, { lv_server } ms on the server|.
          temp78-fix = `Check network latency, UI5 bootstrap location and the size of the view.`.
          APPEND temp78 TO result.
        ENDIF.
      ENDIF.

      READ TABLE it_old INTO ls_old WITH TABLE KEY app = ls_sum-app.
      IF sy-subrc = 0.

        READ TABLE it_new INTO ls_new WITH TABLE KEY app = ls_sum-app.
        IF sy-subrc = 0 AND ls_new-mod_max > 102400 AND ls_new-mod_max * 2 > ls_old-mod_max * 3.

          CLEAR temp79.
          temp79-state = `Warning`.
          temp79-app = lv_app.
          temp79-hint = `Growing app state`.
          temp79-value = |{ ls_old-mod_max DIV 1024 } KB to { ls_new-mod_max DIV 1024 } KB|.
          temp79-fix = `The model grows from one period to the next - data accumulating in ` && `attributes (a log, a history table) that is never cleared?`.
          APPEND temp79 TO result.
        ENDIF.
      ENDIF.
    ENDLOOP.


    ls_draft = is_draft.
    IF ls_draft-check_backlog = abap_true.

      CLEAR temp80.
      temp80-state = `Warning`.
      temp80-app = `(draft table)`.
      temp80-hint = `Expired drafts are not deleted`.
      temp80-value = |{ ls_draft-rows_expired } expired, oldest { ls_draft-oldest }|.
      temp80-fix = `Drafts & Housekeeping tab: delete expired drafts, schedule z2ui5_cl_cockpit_job.`.
      APPEND temp80 TO result.
    ENDIF.
    IF ls_draft-rows > 100000.

      CLEAR temp81.
      temp81-state = `Warning`.
      temp81-app = `(draft table)`.
      temp81-hint = `Large draft table`.
      temp81-value = |{ ls_draft-rows } rows|.
      temp81-fix = `Shorten the draft expiry in the user exit, check which apps write large drafts.`.
      APPEND temp81 TO result.
    ENDIF.

  ENDMETHOD.

  METHOD get_live.

    TYPES:
      BEGIN OF ty_s_act,
        app       TYPE c LENGTH 30,
        users     TYPE i,
        last_seen TYPE timestampl,
      END OF ty_s_act.
    TYPES temp10 TYPE STANDARD TABLE OF ty_s_act WITH DEFAULT KEY.
DATA lt_act TYPE temp10.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.
    DATA lv_since TYPE timestampl.
    DATA lv_none TYPE abap_bool.
    DATA temp2 TYPE xsdboolean.
    DATA ls_act LIKE LINE OF lt_act.
      DATA temp82 TYPE z2ui5_cl_cockpit_stats=>ty_s_live_app.
      DATA temp11 TYPE z2ui5_cl_cockpit_stats=>ty_s_live_app-users.
    DATA temp3 TYPE xsdboolean.

    result-minutes = minutes.

    ls_draft = z2ui5_cl_cockpit_draft=>get_info( minutes ).
    result-sessions = ls_draft-rows_active.
    result-users    = ls_draft-users_active.


    lv_since = z2ui5_cl_cockpit_setup=>now_minus_seconds( minutes * 60 ).
    SELECT app COUNT( * ) AS users MAX( last_seen ) AS last_seen FROM z2ui5_t_20 INTO CORRESPONDING FIELDS OF TABLE lt_act
      WHERE last_seen >= lv_since
      GROUP BY app
      .



    temp2 = boolc( z2ui5_cl_cockpit_setup=>get( )-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-none ).
    lv_none = temp2.

    LOOP AT lt_act INTO ls_act.

      CLEAR temp82.
      temp82-app = ls_act-app.

      IF lv_none = abap_false.
        temp11 = ls_act-users.
      ELSE.
        CLEAR temp11.
      ENDIF.
      temp82-users = temp11.
      temp82-last_seen = z2ui5_cl_cockpit_setup=>ts_text( ls_act-last_seen ).
      APPEND temp82 TO result-t_app.
    ENDLOOP.
    SORT result-t_app BY users DESCENDING.
    result-apps = lines( result-t_app ).

    " the lock-manager addon is a hint only, never a dependency
    " Z2UI5_CL_APP_SM12: its name before lock-manager renamed it

    temp3 = boolc( z2ui5_cl_cockpit_inst=>check_class_exists( z2ui5_cl_cockpit_inst=>obj_name( `CL_LOCK_APP_SM12` ) ) = abap_true OR z2ui5_cl_cockpit_inst=>check_class_exists( z2ui5_cl_cockpit_inst=>obj_name( `CL_APP_SM12` ) ) = abap_true ).
    result-check_lock = temp3.

  ENDMETHOD.

  METHOD get_window.

    DATA lt_rows TYPE ty_t_db_sum.
    DATA ls_all TYPE ty_s_sum.
    DATA lt_sum TYPE ty_t_sum_app.
    DATA ls_acc TYPE ty_s_sum.

    DATA lv_from_ts TYPE timestampl.
    DATA lv_from_day TYPE string.
    DATA lv_from_key TYPE string.
    DATA ls_row LIKE LINE OF lt_rows.
    DATA temp83 TYPE z2ui5_cl_cockpit_stats=>ty_s_window.
    DATA ls_sum LIKE LINE OF lt_sum.
      DATA temp84 TYPE z2ui5_cl_cockpit_stats=>ty_s_window.
      DATA temp12 TYPE z2ui5_cl_cockpit_stats=>ty_s_window-app.
    lv_from_ts = z2ui5_cl_cockpit_setup=>now_minus_seconds( hours * 3600 ).

    lv_from_day = z2ui5_cl_cockpit_setup=>day_of( lv_from_ts ).

    lv_from_key = |{ lv_from_day }{ z2ui5_cl_cockpit_setup=>hour_of( lv_from_ts ) }|.

    " one day or two (the window may span midnight UTC) - the hours are
    " filtered here, a key over day and hour does not exist in the table
    SELECT utc_day utc_hour app
           SUM( cnt ) AS cnt SUM( cnt_err ) AS cnt_err
           SUM( ms_sum ) AS ms_sum MAX( ms_max ) AS ms_max
           SUM( h01 ) AS h01 SUM( h02 ) AS h02 SUM( h03 ) AS h03 SUM( h04 ) AS h04 SUM( h05 ) AS h05
           SUM( h06 ) AS h06 SUM( h07 ) AS h07 SUM( h08 ) AS h08 SUM( h09 ) AS h09
      FROM z2ui5_t_22 INTO CORRESPONDING FIELDS OF TABLE lt_rows
      WHERE utc_day >= lv_from_day
      GROUP BY utc_day, utc_hour, app
      .


    LOOP AT lt_rows INTO ls_row.
      IF |{ ls_row-utc_day }{ ls_row-utc_hour }| < lv_from_key.
        CONTINUE.
      ENDIF.
      READ TABLE lt_sum WITH TABLE KEY app = ls_row-app INTO ls_acc.
      IF sy-subrc <> 0.
        CLEAR ls_acc.
        ls_acc-app = ls_row-app.
        INSERT ls_acc INTO TABLE lt_sum.
      ENDIF.
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = ls_acc ).
      MODIFY TABLE lt_sum FROM ls_acc.
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = ls_all ).
    ENDLOOP.


    CLEAR temp83.
    temp83-roundtrips = to_i( ls_all-cnt ).
    temp83-errors = to_i( ls_all-cnt_err ).
    temp83-p95_ms = p95( ls_all ).
    APPEND temp83 TO result.

    LOOP AT lt_sum INTO ls_sum.

      CLEAR temp84.

      IF ls_sum-app IS INITIAL.
        temp12 = `(no app resolved)`.
      ELSE.
        temp12 = ls_sum-app.
      ENDIF.
      temp84-app = temp12.
      temp84-roundtrips = to_i( ls_sum-cnt ).
      temp84-errors = to_i( ls_sum-cnt_err ).
      temp84-p95_ms = p95( ls_sum ).
      APPEND temp84 TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD select_sums.
      DATA temp85 TYPE ty_s_db_sum-app.
      DATA lv_app LIKE temp85.
      FIELD-SYMBOLS <row> LIKE LINE OF result.

    IF app IS SUPPLIED.

      temp85 = app.

      lv_app = temp85.
      SELECT utc_day event MAX( utc_hour ) AS utc_hour
             SUM( cnt ) AS cnt SUM( cnt_start ) AS cnt_start SUM( cnt_err ) AS cnt_err
             SUM( ms_sum ) AS ms_sum MAX( ms_max ) AS ms_max
             SUM( ms_load ) AS ms_load SUM( ms_main ) AS ms_main SUM( ms_render ) AS ms_render
             SUM( ms_client ) AS ms_client SUM( cnt_client ) AS cnt_client
             SUM( kb_res ) AS kb_res MAX( bytes_res_max ) AS res_max MAX( bytes_mod_max ) AS mod_max
             SUM( h01 ) AS h01 SUM( h02 ) AS h02 SUM( h03 ) AS h03 SUM( h04 ) AS h04 SUM( h05 ) AS h05
             SUM( h06 ) AS h06 SUM( h07 ) AS h07 SUM( h08 ) AS h08 SUM( h09 ) AS h09
        FROM z2ui5_t_22 INTO CORRESPONDING FIELDS OF TABLE result
        WHERE utc_day >= from_day
          AND app = lv_app
        GROUP BY utc_day, event
        .

      LOOP AT result ASSIGNING <row>.
        <row>-app = lv_app.
      ENDLOOP.
    ELSE.
      SELECT utc_day app MAX( utc_hour ) AS utc_hour
             SUM( cnt ) AS cnt SUM( cnt_start ) AS cnt_start SUM( cnt_err ) AS cnt_err
             SUM( ms_sum ) AS ms_sum MAX( ms_max ) AS ms_max
             SUM( ms_load ) AS ms_load SUM( ms_main ) AS ms_main SUM( ms_render ) AS ms_render
             SUM( ms_client ) AS ms_client SUM( cnt_client ) AS cnt_client
             SUM( kb_res ) AS kb_res MAX( bytes_res_max ) AS res_max MAX( bytes_mod_max ) AS mod_max
             SUM( h01 ) AS h01 SUM( h02 ) AS h02 SUM( h03 ) AS h03 SUM( h04 ) AS h04 SUM( h05 ) AS h05
             SUM( h06 ) AS h06 SUM( h07 ) AS h07 SUM( h08 ) AS h08 SUM( h09 ) AS h09
        FROM z2ui5_t_22 INTO CORRESPONDING FIELDS OF TABLE result
        WHERE utc_day >= from_day
        GROUP BY utc_day, app
        .
    ENDIF.

  ENDMETHOD.

  METHOD add_sum.

    cs_sum-cnt        = cs_sum-cnt + is_row-cnt.
    cs_sum-cnt_start  = cs_sum-cnt_start + is_row-cnt_start.
    cs_sum-cnt_err    = cs_sum-cnt_err + is_row-cnt_err.
    cs_sum-ms_sum     = cs_sum-ms_sum + is_row-ms_sum.
    cs_sum-ms_load    = cs_sum-ms_load + is_row-ms_load.
    cs_sum-ms_main    = cs_sum-ms_main + is_row-ms_main.
    cs_sum-ms_render  = cs_sum-ms_render + is_row-ms_render.
    cs_sum-ms_client  = cs_sum-ms_client + is_row-ms_client.
    cs_sum-cnt_client = cs_sum-cnt_client + is_row-cnt_client.
    cs_sum-kb_res     = cs_sum-kb_res + is_row-kb_res.
    cs_sum-h01 = cs_sum-h01 + is_row-h01.
    cs_sum-h02 = cs_sum-h02 + is_row-h02.
    cs_sum-h03 = cs_sum-h03 + is_row-h03.
    cs_sum-h04 = cs_sum-h04 + is_row-h04.
    cs_sum-h05 = cs_sum-h05 + is_row-h05.
    cs_sum-h06 = cs_sum-h06 + is_row-h06.
    cs_sum-h07 = cs_sum-h07 + is_row-h07.
    cs_sum-h08 = cs_sum-h08 + is_row-h08.
    cs_sum-h09 = cs_sum-h09 + is_row-h09.
    IF is_row-ms_max > cs_sum-ms_max.
      cs_sum-ms_max = is_row-ms_max.
    ENDIF.
    IF is_row-res_max > cs_sum-res_max.
      cs_sum-res_max = is_row-res_max.
    ENDIF.
    IF is_row-mod_max > cs_sum-mod_max.
      cs_sum-mod_max = is_row-mod_max.
    ENDIF.

  ENDMETHOD.

  METHOD p95.

    " The histogram knows how many roundtrips fell into each latency bucket.
    " The 95th percentile lies in the bucket where the running count passes
    " 95 % - interpolated linearly inside it, capped by the observed maximum.
    TYPES temp11 TYPE STANDARD TABLE OF ty_p WITH DEFAULT KEY.
DATA lt_h TYPE temp11.
    DATA lv_total TYPE ty_p.
    DATA lv_cum TYPE ty_p.
    DATA lv_target TYPE ty_p.
    DATA lv_lower TYPE i.

    DATA temp86 LIKE lt_h.
    DATA lv_h LIKE LINE OF lt_h.
      DATA lv_index LIKE sy-tabix.
      DATA lv_upper TYPE i.
    CLEAR temp86.
    INSERT is_sum-h01 INTO TABLE temp86.
    INSERT is_sum-h02 INTO TABLE temp86.
    INSERT is_sum-h03 INTO TABLE temp86.
    INSERT is_sum-h04 INTO TABLE temp86.
    INSERT is_sum-h05 INTO TABLE temp86.
    INSERT is_sum-h06 INTO TABLE temp86.
    INSERT is_sum-h07 INTO TABLE temp86.
    INSERT is_sum-h08 INTO TABLE temp86.
    INSERT is_sum-h09 INTO TABLE temp86.
    lt_h = temp86.

    LOOP AT lt_h INTO lv_h.
      lv_total = lv_total + lv_h.
    ENDLOOP.
    IF lv_total <= 0.
      RETURN.
    ENDIF.

    lv_target = lv_total * 95 / 100.
    LOOP AT lt_h INTO lv_h.

      lv_index = sy-tabix.

      lv_upper = z2ui5_cl_cockpit_setup=>bucket_upper( lv_index ).
      IF lv_index = 9 AND is_sum-ms_max > lv_lower.
        lv_upper = is_sum-ms_max.
      ENDIF.
      IF lv_cum + lv_h >= lv_target AND lv_h > 0.
        result = lv_lower + ( lv_upper - lv_lower ) * ( lv_target - lv_cum ) / lv_h.
        IF is_sum-ms_max > 0 AND result > is_sum-ms_max.
          result = is_sum-ms_max.
        ENDIF.
        RETURN.
      ENDIF.
      lv_cum = lv_cum + lv_h.
      lv_lower = lv_upper.
    ENDLOOP.

  ENDMETHOD.

  METHOD avg.

    IF cnt <= 0.
      RETURN.
    ENDIF.
    result = to_i( sum / cnt ).

  ENDMETHOD.

  METHOD day_text.

    IF strlen( day ) < 8.
      result = day.
      RETURN.
    ENDIF.
    result = |{ day(4) }-{ day+4(2) }-{ day+6(2) }|.

  ENDMETHOD.

  METHOD last_text.

    IF day IS INITIAL.
      RETURN.
    ENDIF.
    result = |{ day_text( day ) } { hour }:00 UTC|.

  ENDMETHOD.

  METHOD to_i.

    IF val > 2147483647.
      result = 2147483647.
    ELSE.
      result = val.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
