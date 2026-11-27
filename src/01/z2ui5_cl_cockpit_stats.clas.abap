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

    "! The most error groups get_errors( ) returns - a list that long is cut.
    CONSTANTS c_max_error_groups TYPE i VALUE 5000.
    "! The app of the roundtrips whose app could not be resolved, as the Apps
    "! tab and the alert window name it - it is no app name.
    CONSTANTS c_no_app TYPE string VALUE `(no app resolved)`.

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
    "! unused_days setting - none in mode ERRORS (an app without a failure
    "! is no unused app) and OFF (nothing is recorded); get_unused_title( )
    "! says so.
    CLASS-METHODS get_unused
      RETURNING
        VALUE(result) TYPE ty_t_unused.

    "! The heading of the unused apps: what get_unused( ) tells in the mode
    "! recorded with, and since when the cockpit records when that is less
    "! than the unused_days setting.
    CLASS-METHODS get_unused_title
      RETURNING
        VALUE(result) TYPE string.

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

    "! What the recording mode leaves out of the figures - a sentence with a
    "! leading blank, empty in mode ALL.
    CLASS-METHODS mode_note
      RETURNING
        VALUE(result) TYPE string.

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
      "! One error group as the database counts it.
      BEGIN OF ty_s_err_group,
        app         TYPE c LENGTH 30,
        event       TYPE c LENGTH 40,
        error_class TYPE c LENGTH 30,
        error_head  TYPE c LENGTH 200,
        cnt         TYPE i,
        first_ts    TYPE timestampl,
        last_ts     TYPE timestampl,
      END OF ty_s_err_group.
    TYPES ty_t_err_group TYPE STANDARD TABLE OF ty_s_err_group WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_last,
        app     TYPE c LENGTH 30,
        utc_day TYPE c LENGTH 8,
      END OF ty_s_last.
    TYPES ty_t_last TYPE SORTED TABLE OF ty_s_last WITH UNIQUE KEY app.

    TYPES ty_t_sum_app TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY app.

    "! The error groups the database counted, as the Errors tab shows them -
    "! the group key is G1, G2, ... in order of the newest occurrence, the
    "! result sorted by count.
    CLASS-METHODS errors_of
      IMPORTING
        it_group      TYPE ty_t_err_group
      RETURNING
        VALUE(result) TYPE ty_t_error.

    "! The phase that took longest in a slow roundtrip - unknown when the
    "! roundtrip came with no phases (recorded by the HTTP handler alone).
    CLASS-METHODS phase_of
      IMPORTING
        ms_load       TYPE i
        ms_main       TYPE i
        ms_render     TYPE i
      RETURNING
        VALUE(result) TYPE string.

    "! The figures of get_window( ) from the sums of whole UTC hours - the
    "! rows before the hour of from_ts left out, across midnight too.
    CLASS-METHODS window_of
      IMPORTING
        it_rows       TYPE ty_t_db_sum
        from_ts       TYPE timestampl
      RETURNING
        VALUE(result) TYPE ty_t_window.

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

    "! One sum added to another: counts and sums added, maxima kept.
    CLASS-METHODS merge_sum
      IMPORTING
        is_sum TYPE ty_s_sum
      CHANGING
        cs_sum TYPE ty_s_sum.

    "! A row added to the sum of its app, created when there is none yet -
    "! with the newest day and hour of the app's rows, for "last used".
    "! Not by field symbol: the key of a sorted line is write-protected, and
    "! a CHANGING parameter bound to it is CX_SY_DYN_CALL_ILLEGAL_TYPE.
    CLASS-METHODS add_to_app
      IMPORTING
        is_row TYPE ty_s_db_sum
      CHANGING
        ct_sum TYPE ty_t_sum_app.

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
    DATA temp63 TYPE z2ui5_cl_cockpit_stats=>ty_s_monitor-active_class.
    DATA temp64 TYPE string.
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
                            |(load, main, render) need the monitor hook.{ mode_note( ) }|.
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

    CLEAR temp63.

    READ TABLE lt_impl INTO temp64 INDEX 1.
    IF sy-subrc = 0.
      temp63 = temp64.
    ENDIF.
    result-active_class = temp63.

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
                          |user tracking { z2ui5_cl_cockpit_setup=>get( )-user_tracking }, days in UTC.{ mode_note( ) }|.
    ENDIF.

  ENDMETHOD.

  METHOD mode_note.

    DATA temp65 TYPE string.
    CASE z2ui5_cl_cockpit_setup=>get( )-mode.
      WHEN z2ui5_cl_cockpit_setup=>cs_mode-errors.
        temp65 = ` Only failed roundtrips are recorded: no error rate, no user count, the p95 is that of the failures, ` && `and no app is called unused.`.
      WHEN z2ui5_cl_cockpit_setup=>cs_mode-sample.
        temp65 = ` A share of the roundtrips is recorded: counts and sums are estimates, users per day and per app ` && `count only the users of recorded roundtrips.`.
    ENDCASE.
    result = temp65.

  ENDMETHOD.

  METHOD check_recent.

    DATA lv_from TYPE c LENGTH 8.
        DATA temp66 TYPE z2ui5_t_22-utc_day.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( 6 ).
    TRY.

        SELECT SINGLE utc_day FROM z2ui5_t_22 INTO temp66
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
    DATA temp67 TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA ls_row LIKE LINE OF temp67.
      DATA temp68 TYPE z2ui5_cl_cockpit_stats=>ty_s_kpi-error_state.
    DATA lv_slow TYPE z2ui5_cl_cockpit_setup=>ty_s_settings-slow_ms.
    DATA temp69 TYPE z2ui5_cl_cockpit_stats=>ty_s_kpi-p95_state.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.
    DATA temp70 TYPE z2ui5_cl_cockpit_stats=>ty_s_kpi-drafts_state.
    lv_today = z2ui5_cl_cockpit_setup=>day_minus( 0 ).



    temp67 = select_sums( lv_today ).

    LOOP AT temp67 INTO ls_row.
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = ls_sum ).
    ENDLOOP.

    result-roundtrips = to_i( ls_sum-cnt ).
    result-errors     = to_i( ls_sum-cnt_err ).
    result-avg_ms     = avg( sum = ls_sum-ms_sum
                             cnt = ls_sum-cnt ).
    result-p95_ms     = p95( ls_sum ).

    " mode ERRORS: the users of failed roundtrips only - no count of users
    IF z2ui5_cl_cockpit_setup=>get( )-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-none
        OR z2ui5_cl_cockpit_setup=>get( )-mode = z2ui5_cl_cockpit_setup=>cs_mode-errors.
      result-users = `-`.
    ELSE.
      SELECT COUNT( DISTINCT user_key ) FROM z2ui5_t_27 INTO lv_users
        WHERE utc_day = lv_today
        .
      result-users = |{ lv_users }|.
    ENDIF.

    IF z2ui5_cl_cockpit_setup=>get( )-mode = z2ui5_cl_cockpit_setup=>cs_mode-errors.
      " failed roundtrips only - no rate to tell
      result-error_rate  = `-`.
      result-error_state = `Neutral`.
    ELSEIF ls_sum-cnt > 0.
      lv_rate = ls_sum-cnt_err * 100 / ls_sum-cnt.
      result-error_rate = |{ lv_rate }|.

      IF lv_rate >= 5.
        temp68 = `Error`.
      ELSEIF lv_rate >= 1.
        temp68 = `Critical`.
      ELSE.
        temp68 = `Good`.
      ENDIF.
      result-error_state = temp68.
    ELSE.
      result-error_rate  = `0`.
      result-error_state = `Neutral`.
    ENDIF.


    lv_slow = z2ui5_cl_cockpit_setup=>get( )-slow_ms.
    " mode ERRORS: the p95 of the failed roundtrips - no verdict on it

    IF result-roundtrips = 0.
      temp69 = `Neutral`.
    ELSEIF z2ui5_cl_cockpit_setup=>get( )-mode = z2ui5_cl_cockpit_setup=>cs_mode-errors.
      temp69 = `Neutral`.
    ELSEIF result-p95_ms >= lv_slow.
      temp69 = `Error`.
    ELSEIF result-p95_ms >= lv_slow / 2.
      temp69 = `Critical`.
    ELSE.
      temp69 = `Good`.
    ENDIF.
    result-p95_state = temp69.


    ls_draft = z2ui5_cl_cockpit_draft=>get_info( ).
    result-drafts = ls_draft-rows.

    IF ls_draft-check_backlog = abap_true.
      temp70 = `Critical`.
    ELSE.
      temp70 = `Neutral`.
    ENDIF.
    result-drafts_state = temp70.

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
    DATA temp71 TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA ls_row LIKE LINE OF temp71.
    DATA ls_sum LIKE LINE OF lt_sum.
    DATA lv_slow TYPE z2ui5_cl_cockpit_setup=>ty_s_settings-slow_ms.
      DATA temp72 TYPE string.
      DATA lv_day LIKE temp72.
      DATA temp73 TYPE ty_s_day.
      DATA ls_day LIKE temp73.
      DATA ls_users TYPE ty_s_users.
      DATA temp74 TYPE z2ui5_cl_cockpit_stats=>ty_s_day-state.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    " a line of a sorted table is never passed to add_sum( ) by field symbol:
    " its key is write-protected, and a CHANGING parameter bound to it is the
    " runtime error CX_SY_DYN_CALL_ILLEGAL_TYPE - read, add, modify instead

    temp71 = select_sums( lv_from ).

    LOOP AT temp71 INTO ls_row.
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

      temp72 = lv_date.

      lv_day = temp72.

      CLEAR temp73.
      temp73-day = z2ui5_cl_cockpit_setup=>day_text( lv_day ).

      ls_day = temp73.
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
        temp74 = `Error`.
      ELSEIF ls_day-p95_ms >= lv_slow.
        temp74 = `Warning`.
      ELSE.
        temp74 = `Information`.
      ENDIF.
      ls_day-state = temp74.
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
    DATA lt_sum TYPE ty_t_sum_app.

    DATA lv_from TYPE string.
    DATA temp75 TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA ls_row LIKE LINE OF temp75.
    DATA ls_sum LIKE LINE OF lt_sum.
      DATA temp76 TYPE ty_s_app.
      DATA temp9 TYPE z2ui5_cl_cockpit_stats=>ty_s_app-app.
      DATA ls_app LIKE temp76.
      DATA ls_users LIKE LINE OF lt_users.
      DATA temp77 TYPE z2ui5_cl_cockpit_stats=>ty_s_app-error_state.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).


    temp75 = select_sums( lv_from ).

    LOOP AT temp75 INTO ls_row.
      add_to_app( EXPORTING is_row = ls_row
                  CHANGING  ct_sum = lt_sum ).
    ENDLOOP.

    SELECT utc_day app COUNT( * ) AS cnt FROM z2ui5_t_27 INTO CORRESPONDING FIELDS OF TABLE lt_users
      WHERE utc_day >= lv_from
      GROUP BY utc_day, app
      .


    LOOP AT lt_sum INTO ls_sum.

      CLEAR temp76.

      IF ls_sum-app IS INITIAL.
        temp9 = c_no_app.
      ELSE.
        temp9 = ls_sum-app.
      ENDIF.
      temp76-app = temp9.
      temp76-sessions = to_i( ls_sum-cnt_start ).
      temp76-roundtrips = to_i( ls_sum-cnt ).
      temp76-avg_ms = avg( sum = ls_sum-ms_sum cnt = ls_sum-cnt ).
      temp76-p95_ms = p95( ls_sum ).
      temp76-kb_res_avg = avg( sum = ls_sum-kb_res cnt = ls_sum-cnt ).
      temp76-kb_model_max = ls_sum-mod_max DIV 1024.
      temp76-errors = to_i( ls_sum-cnt_err ).
      temp76-last_used = last_text( day = ls_sum-utc_day hour = ls_sum-utc_hour ).

      ls_app = temp76.
      " users: the most on one day - pseudonyms change daily, so a distinct
      " count across days would count the same person once per day

      LOOP AT lt_users INTO ls_users WHERE app = ls_sum-app. "#EC CI_SORTSEQ
        IF ls_users-cnt > ls_app-users.
          ls_app-users = ls_users-cnt.
        ENDIF.
      ENDLOOP.

      IF ls_app-errors > 0.
        temp77 = `Error`.
      ELSE.
        temp77 = `None`.
      ENDIF.
      ls_app-error_state = temp77.
      APPEND ls_app TO result.
    ENDLOOP.

    SORT result BY roundtrips DESCENDING.

  ENDMETHOD.

  METHOD get_app_events.

    TYPES temp4 TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY event.
DATA lt_sum TYPE temp4.
    DATA ls_acc TYPE ty_s_sum.

    DATA lv_from TYPE string.
    DATA temp78 TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA ls_row LIKE LINE OF temp78.
    DATA ls_sum LIKE LINE OF lt_sum.
      DATA temp79 TYPE z2ui5_cl_cockpit_stats=>ty_s_event.
      DATA temp10 TYPE z2ui5_cl_cockpit_stats=>ty_s_event-event.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).


    temp78 = select_sums( from_day = lv_from app = app ).

    LOOP AT temp78 INTO ls_row.
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

      CLEAR temp79.

      IF ls_sum-event IS INITIAL.
        temp10 = `(start / navigation)`.
      ELSE.
        temp10 = ls_sum-event.
      ENDIF.
      temp79-event = temp10.
      temp79-roundtrips = to_i( ls_sum-cnt ).
      temp79-avg_ms = avg( sum = ls_sum-ms_sum cnt = ls_sum-cnt ).
      temp79-p95_ms = p95( ls_sum ).
      temp79-max_ms = ls_sum-ms_max.
      temp79-errors = to_i( ls_sum-cnt_err ).
      temp79-kb_res_avg = avg( sum = ls_sum-kb_res cnt = ls_sum-cnt ).
      temp79-last_used = last_text( day = ls_sum-utc_day hour = ls_sum-utc_hour ).
      APPEND temp79 TO result.
    ENDLOOP.

    SORT result BY roundtrips DESCENDING.

  ENDMETHOD.

  METHOD get_unused.

    DATA lt_last TYPE ty_t_last.

    DATA lv_mode TYPE z2ui5_cl_cockpit_setup=>ty_s_settings-mode.
    DATA lv_from TYPE string.
    lv_mode = z2ui5_cl_cockpit_setup=>get( )-mode.
    IF lv_mode = z2ui5_cl_cockpit_setup=>cs_mode-errors OR lv_mode = z2ui5_cl_cockpit_setup=>cs_mode-off.
      RETURN.
    ENDIF.


    lv_from = z2ui5_cl_cockpit_setup=>day_minus( z2ui5_cl_cockpit_setup=>get( )-unused_days ).

    SELECT app MAX( utc_day ) AS utc_day FROM z2ui5_t_22
      GROUP BY app
      INTO CORRESPONDING FIELDS OF TABLE lt_last.      "#EC CI_NOWHERE

    result = unused_of( it_impl   = z2ui5_cl_cockpit_inst=>get_implementers( z2ui5_cl_cockpit_inst=>obj_name( `IF_APP` ) )
                        it_last   = lt_last
                        from_day  = lv_from ).

  ENDMETHOD.

  METHOD get_unused_title.

    DATA lv_oldest TYPE c LENGTH 8.
    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    ls_set = z2ui5_cl_cockpit_setup=>get( ).

    CASE ls_set-mode.
      WHEN z2ui5_cl_cockpit_setup=>cs_mode-errors.
        result = `Unused apps - not shown in mode ERRORS: only failed roundtrips are recorded, ` &&
                 `and an app without a failure is no unused app`.
        RETURN.
      WHEN z2ui5_cl_cockpit_setup=>cs_mode-off.
        result = `Unused apps - not shown while recording is switched off (mode OFF)`.
        RETURN.
    ENDCASE.

    result = |Unused apps - implementers of z2ui5_if_app without a roundtrip in { ls_set-unused_days } days|.
    TRY.
        SELECT MIN( utc_day ) FROM z2ui5_t_22 INTO lv_oldest.
      CATCH cx_root.
        CLEAR lv_oldest.
    ENDTRY.
    IF lv_oldest IS NOT INITIAL AND lv_oldest > z2ui5_cl_cockpit_setup=>day_minus( ls_set-unused_days ).
      result = |{ result } - recorded only since { z2ui5_cl_cockpit_setup=>day_text( lv_oldest ) }, | &&
               |"never recorded" means not since then|.
    ENDIF.
    IF ls_set-mode = z2ui5_cl_cockpit_setup=>cs_mode-sample.
      result = |{ result } - mode SAMPLE records { ls_set-sample_pct } % of the roundtrips, an app with few of them | &&
               |can be listed although it is used|.
    ENDIF.

  ENDMETHOD.

  METHOD unused_of.

    DATA lv_app LIKE LINE OF it_impl.
      DATA temp80 TYPE ty_s_last-app.
      DATA lv_key LIKE temp80.
      DATA ls_last TYPE z2ui5_cl_cockpit_stats=>ty_s_last.
        DATA temp81 TYPE z2ui5_cl_cockpit_stats=>ty_s_unused.
        DATA temp82 TYPE z2ui5_cl_cockpit_stats=>ty_s_unused.
    LOOP AT it_impl INTO lv_app.

      temp80 = to_upper( lv_app ).

      lv_key = temp80.

      READ TABLE it_last INTO ls_last WITH TABLE KEY app = lv_key.
      IF sy-subrc <> 0.

        CLEAR temp81.
        temp81-app = lv_app.
        temp81-last_used = `never recorded`.
        APPEND temp81 TO result.
      ELSEIF ls_last-utc_day < from_day.

        CLEAR temp82.
        temp82-app = lv_app.
        temp82-last_used = z2ui5_cl_cockpit_setup=>day_text( ls_last-utc_day ).
        APPEND temp82 TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_errors.

    DATA lt_group TYPE ty_t_err_group.

    DATA lv_from TYPE string.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    " counted in the database: a flood of one error neither pushes the other
    " groups out of a row limit nor caps its own count and first occurrence
    SELECT app event error_class error_head
           COUNT( * ) AS cnt MIN( timestampl ) AS first_ts MAX( timestampl ) AS last_ts
      FROM z2ui5_t_25 UP TO c_max_error_groups ROWS INTO CORRESPONDING FIELDS OF TABLE lt_group
      WHERE utc_day >= lv_from
        AND check_error = abap_true
      GROUP BY app, event, error_class, error_head

      .

    result = errors_of( lt_group ).

  ENDMETHOD.

  METHOD errors_of.

    DATA lv_key TYPE i.

    DATA lt_group LIKE it_group.
    DATA ls_group LIKE LINE OF lt_group.
      DATA temp83 TYPE z2ui5_cl_cockpit_stats=>ty_s_error.
    lt_group = it_group.
    " the keys in order of the newest occurrence, the same group of the same
    " period keeps its key between two reads
    SORT lt_group BY last_ts DESCENDING app event error_class error_head.


    LOOP AT lt_group INTO ls_group.
      lv_key = lv_key + 1.

      CLEAR temp83.
      temp83-key = |G{ lv_key }|.
      temp83-app = ls_group-app.
      temp83-event = ls_group-event.
      temp83-error_class = ls_group-error_class.
      temp83-error_head = ls_group-error_head.
      temp83-count = ls_group-cnt.
      temp83-first_seen = z2ui5_cl_cockpit_setup=>ts_text( ls_group-first_ts ).
      temp83-last_seen = z2ui5_cl_cockpit_setup=>ts_text( ls_group-last_ts ).
      APPEND temp83 TO result.
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
    TYPES temp5 TYPE STANDARD TABLE OF ty_s_log WITH DEFAULT KEY.
DATA lt_log TYPE temp5.

    DATA lv_from TYPE string.
    DATA lv_app LIKE is_error-app.
    DATA lv_event LIKE is_error-event.
    DATA lv_class LIKE is_error-error_class.
    DATA lv_head LIKE is_error-error_head.
    DATA lv_privacy TYPE abap_bool.
    DATA ls_log LIKE LINE OF lt_log.
      DATA temp84 TYPE ty_s_occurrence.
      DATA temp11 TYPE z2ui5_cl_cockpit_stats=>ty_s_occurrence-start.
      DATA ls_occ LIKE temp84.
    lv_from  = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    lv_app = is_error-app.

    lv_event = is_error-event.

    lv_class = is_error-error_class.

    lv_head = is_error-error_head.

    SELECT id timestampl event uname user_key draft_id draft_id_prev check_sticky ms_total check_start
      FROM z2ui5_t_25 UP TO 200 ROWS INTO CORRESPONDING FIELDS OF TABLE lt_log
      WHERE utc_day >= lv_from
        AND check_error = abap_true
        AND app = lv_app
        AND event = lv_event
        AND error_class = lv_class
        AND error_head = lv_head
      ORDER BY timestampl DESCENDING

      .


    lv_privacy = z2ui5_cl_cockpit_setup=>check_privacy( ).

    LOOP AT lt_log INTO ls_log.

      CLEAR temp84.
      temp84-id = ls_log-id.
      temp84-time = z2ui5_cl_cockpit_setup=>ts_text( ls_log-timestampl ).
      temp84-draft_id = ls_log-draft_id.
      temp84-draft_id_prev = ls_log-draft_id_prev.
      temp84-event = ls_log-event.
      temp84-check_sticky = ls_log-check_sticky.
      temp84-ms_total = ls_log-ms_total.

      IF ls_log-check_start = abap_true.
        temp11 = `app start`.
      ELSE.
        CLEAR temp11.
      ENDIF.
      temp84-start = temp11.

      ls_occ = temp84.
      IF lv_privacy = abap_false AND ls_log-uname IS NOT INITIAL.
        ls_occ-user = ls_log-uname.
      ELSE.
        ls_occ-user = z2ui5_cl_cockpit_setup=>pseudonym_text( ls_log-user_key ).
      ENDIF.
      APPEND ls_occ TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_error_text.

    DATA temp85 TYPE z2ui5_t_25-id.
    DATA lv_id LIKE temp85.
    temp85 = id.

    lv_id = temp85.
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
    DATA temp86 TYPE z2ui5_t_25-id.
    DATA lv_id LIKE temp86.
      DATA temp87 TYPE string.
    DATA lv_today TYPE string.
    DATA temp88 TYPE string.

    result = z2ui5_cl_cockpit_repro=>cs_owner-unknown.

    temp86 = id.

    lv_id = temp86.
    SELECT SINGLE uname user_key utc_day FROM z2ui5_t_25 INTO (lv_uname, lv_user_key, lv_day)
      WHERE id = lv_id
      .
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF lv_uname IS NOT INITIAL.

      IF lv_uname = sy-uname.
        temp87 = z2ui5_cl_cockpit_repro=>cs_owner-you.
      ELSE.
        temp87 = z2ui5_cl_cockpit_repro=>cs_owner-other.
      ENDIF.
      result = temp87.
      RETURN.
    ENDIF.


    lv_today = z2ui5_cl_cockpit_setup=>day_minus( 0 ).
    IF lv_user_key IS INITIAL OR lv_day <> lv_today
        OR z2ui5_cl_cockpit_setup=>get( )-user_tracking <> z2ui5_cl_cockpit_setup=>cs_users-hash.
      RETURN.
    ENDIF.

    IF z2ui5_cl_cockpit_setup=>user_key( uname = sy-uname day = lv_today ) = lv_user_key.
      temp88 = z2ui5_cl_cockpit_repro=>cs_owner-you.
    ELSE.
      temp88 = z2ui5_cl_cockpit_repro=>cs_owner-other.
    ENDIF.
    result = temp88.

  ENDMETHOD.

  METHOD get_slowest.

    TYPES temp6 TYPE STANDARD TABLE OF z2ui5_t_25 WITH DEFAULT KEY.
DATA lt_log TYPE temp6.

    DATA lv_from TYPE string.
    DATA ls_log LIKE LINE OF lt_log.
      DATA temp89 TYPE ty_s_slow.
      DATA temp12 TYPE z2ui5_cl_cockpit_stats=>ty_s_slow-error.
      DATA ls_slow LIKE temp89.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    SELECT id timestampl app event ms_total ms_load ms_main ms_render ms_client_prev
           bytes_response bytes_model check_error
      FROM z2ui5_t_25 UP TO max_rows ROWS INTO CORRESPONDING FIELDS OF TABLE lt_log
      WHERE utc_day >= lv_from
        AND check_slow = abap_true
      ORDER BY ms_total DESCENDING

      .


    LOOP AT lt_log INTO ls_log.

      CLEAR temp89.
      temp89-id = ls_log-id.
      temp89-time = z2ui5_cl_cockpit_setup=>ts_text( ls_log-timestampl ).
      temp89-app = ls_log-app.
      temp89-event = ls_log-event.
      temp89-ms_total = ls_log-ms_total.
      temp89-ms_load = ls_log-ms_load.
      temp89-ms_main = ls_log-ms_main.
      temp89-ms_render = ls_log-ms_render.
      temp89-ms_client = ls_log-ms_client_prev.
      temp89-kb_res = ls_log-bytes_response DIV 1024.
      temp89-kb_model = ls_log-bytes_model DIV 1024.

      IF ls_log-check_error = abap_true.
        temp12 = `error`.
      ELSE.
        CLEAR temp12.
      ENDIF.
      temp89-error = temp12.

      ls_slow = temp89.
      ls_slow-phase = phase_of( ms_load   = ls_log-ms_load
                                ms_main   = ls_log-ms_main
                                ms_render = ls_log-ms_render ).
      IF ls_log-ms_total > 0.
        ls_slow-main_share = ls_log-ms_main * 100 / ls_log-ms_total.
      ENDIF.
      APPEND ls_slow TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD phase_of.

    IF ms_load <= 0 AND ms_main <= 0 AND ms_render <= 0.
      " the ICF handler line records the total only - no phase to blame
      result = `unknown - recorded by the HTTP handler, the phases need the monitor hook`.
    ELSEIF ms_main >= ms_load AND ms_main >= ms_render.
      result = `main - the app's own code`.
    ELSEIF ms_load >= ms_render.
      result = `load - draft read and deserialize`.
    ELSE.
      result = `render - serialize and draft save`.
    ENDIF.

  ENDMETHOD.

  METHOD get_hints.

    DATA lt_new TYPE ty_t_sum_app.
    DATA lt_old TYPE ty_t_sum_app.
    DATA lv_from TYPE string.
    DATA lv_half TYPE string.
    DATA temp90 TYPE z2ui5_cl_cockpit_stats=>ty_t_db_sum.
    DATA ls_row LIKE LINE OF temp90.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).
    " growth: the model maximum of the newer half against the older half

    lv_half = z2ui5_cl_cockpit_setup=>day_minus( days DIV 2 ).


    temp90 = select_sums( lv_from ).

    LOOP AT temp90 INTO ls_row.
      IF ls_row-utc_day > lv_half.
        add_to_app( EXPORTING is_row = ls_row
                    CHANGING  ct_sum = lt_new ).
      ELSE.
        add_to_app( EXPORTING is_row = ls_row
                    CHANGING  ct_sum = lt_old ).
      ENDIF.
    ENDLOOP.

    result = hints_of( it_new   = lt_new
                       it_old   = lt_old
                       is_set   = z2ui5_cl_cockpit_setup=>get( )
                       is_draft = z2ui5_cl_cockpit_draft=>get_info( ) ).

  ENDMETHOD.

  METHOD hints_of.

    DATA lt_all TYPE ty_t_sum_app.
    DATA ls_acc TYPE ty_s_sum.
    DATA lv_model_limit TYPE ty_p.
    DATA lv_response_limit TYPE ty_p.
    DATA lv_new_mod TYPE ty_p.
    DATA lv_old_mod TYPE ty_p.
    DATA ls_old LIKE LINE OF it_old.
    DATA ls_sum LIKE LINE OF lt_all.
      DATA temp91 TYPE string.
      DATA lv_app LIKE temp91.
        DATA temp92 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA temp93 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
      DATA lv_p95 TYPE i.
        DATA temp94 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA temp95 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA temp96 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA temp97 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA lv_client TYPE i.
        DATA lv_server TYPE i.
          DATA temp98 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
        DATA ls_new TYPE z2ui5_cl_cockpit_stats=>ty_s_sum.
            DATA temp99 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
    DATA ls_draft LIKE is_draft.
      DATA temp100 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
      DATA temp101 TYPE z2ui5_cl_cockpit_stats=>ty_s_hint.
    " the whole period per app = newer + older half
    lt_all = it_new.

    LOOP AT it_old INTO ls_old.
      READ TABLE lt_all WITH TABLE KEY app = ls_old-app INTO ls_acc.
      IF sy-subrc <> 0.
        INSERT ls_old INTO TABLE lt_all.
        CONTINUE.
      ENDIF.
      merge_sum( EXPORTING is_sum = ls_old
                 CHANGING  cs_sum = ls_acc ).
      MODIFY TABLE lt_all FROM ls_acc.
    ENDLOOP.

    " the thresholds in bytes, and the growth below, in p - an INT4 product
    " overflows from 2 GB on
    lv_model_limit = is_set-model_warn_kb.
    lv_model_limit = lv_model_limit * 1024.
    lv_response_limit = is_set-response_warn_kb.
    lv_response_limit = lv_response_limit * 1024.


    LOOP AT lt_all INTO ls_sum.

      temp91 = ls_sum-app.

      lv_app = temp91.

      IF ls_sum-mod_max > lv_model_limit.

        CLEAR temp92.
        temp92-state = `Warning`.
        temp92-app = lv_app.
        temp92-hint = `Large model`.
        temp92-value = |{ ls_sum-mod_max DIV 1024 } KB|.
        temp92-fix = `Every PUBLIC attribute is serialized and sent on every roundtrip - keep only ` && `bound data public, page large tables.`.
        APPEND temp92 TO result.
      ENDIF.

      IF ls_sum-res_max > lv_response_limit.

        CLEAR temp93.
        temp93-state = `Warning`.
        temp93-app = lv_app.
        temp93-hint = `Large response`.
        temp93-value = |{ ls_sum-res_max DIV 1024 } KB|.
        temp93-fix = `Avoid re-rendering the whole view on every event; bound data changes are ` && `pushed without view_display( ).`.
        APPEND temp93 TO result.
      ENDIF.


      lv_p95 = p95( ls_sum ).
      IF ls_sum-cnt >= 20 AND lv_p95 >= is_set-slow_ms.

        CLEAR temp94.
        temp94-state = `Warning`.
        temp94-app = lv_app.
        temp94-hint = `Slow p95`.
        temp94-value = |{ lv_p95 } ms|.
        temp94-fix = `See the slowest roundtrips of this app and their dominant phase.`.
        APPEND temp94 TO result.
      ENDIF.

      " not in mode ERRORS: it records failed roundtrips only
      IF ls_sum-cnt >= 20 AND ls_sum-cnt_err * 20 >= ls_sum-cnt
          AND is_set-mode <> z2ui5_cl_cockpit_setup=>cs_mode-errors.

        CLEAR temp95.
        temp95-state = `Error`.
        temp95-app = lv_app.
        temp95-hint = `Error rate of 5 % or more`.
        temp95-value = |{ to_i( ls_sum-cnt_err ) } of { to_i( ls_sum-cnt ) }|.
        temp95-fix = `Errors tab: grouped by event and exception class.`.
        APPEND temp95 TO result.
      ENDIF.

      IF ls_sum-ms_sum > 0 AND ls_sum-ms_load * 2 > ls_sum-ms_sum AND ls_sum-cnt >= 20.

        CLEAR temp96.
        temp96-state = `Information`.
        temp96-app = lv_app.
        temp96-hint = `Load phase dominates`.
        temp96-value = |{ to_i( ls_sum-ms_load * 100 / ls_sum-ms_sum ) } % of the time|.
        temp96-fix = `Reading and deserializing the draft takes longer than the app itself - ` && `the app state is large.`.
        APPEND temp96 TO result.
      ENDIF.

      IF ls_sum-ms_sum > 0 AND ls_sum-ms_render * 2 > ls_sum-ms_sum AND ls_sum-cnt >= 20.

        CLEAR temp97.
        temp97-state = `Information`.
        temp97-app = lv_app.
        temp97-hint = `Render phase dominates`.
        temp97-value = |{ to_i( ls_sum-ms_render * 100 / ls_sum-ms_sum ) } % of the time|.
        temp97-fix = `Serializing model and draft takes longer than the app itself.`.
        APPEND temp97 TO result.
      ENDIF.

      IF ls_sum-cnt_client > 0 AND ls_sum-cnt > 0.

        lv_client = avg( sum = ls_sum-ms_client
                               cnt = ls_sum-cnt_client ).

        lv_server = avg( sum = ls_sum-ms_sum
                               cnt = ls_sum-cnt ).
        IF lv_client - lv_server > 1000.

          CLEAR temp98.
          temp98-state = `Information`.
          temp98-app = lv_app.
          temp98-hint = `Browser and network time dominates`.
          temp98-value = |{ lv_client } ms in the browser, { lv_server } ms on the server|.
          temp98-fix = `Check network latency, UI5 bootstrap location and the size of the view.`.
          APPEND temp98 TO result.
        ENDIF.
      ENDIF.

      READ TABLE it_old INTO ls_old WITH TABLE KEY app = ls_sum-app.
      IF sy-subrc = 0.

        READ TABLE it_new INTO ls_new WITH TABLE KEY app = ls_sum-app.
        IF sy-subrc = 0.
          lv_new_mod = ls_new-mod_max.
          lv_old_mod = ls_old-mod_max.
          IF lv_new_mod > 102400 AND lv_new_mod * 2 > lv_old_mod * 3.

            CLEAR temp99.
            temp99-state = `Warning`.
            temp99-app = lv_app.
            temp99-hint = `Growing app state`.
            temp99-value = |{ ls_old-mod_max DIV 1024 } KB to { ls_new-mod_max DIV 1024 } KB|.
            temp99-fix = `The model grows from one period to the next - data accumulating in ` && `attributes (a log, a history table) that is never cleared?`.
            APPEND temp99 TO result.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.


    ls_draft = is_draft.
    IF ls_draft-check_backlog = abap_true.

      CLEAR temp100.
      temp100-state = `Warning`.
      temp100-app = `(draft table)`.
      temp100-hint = `Expired drafts are not deleted`.
      temp100-value = |{ ls_draft-rows_expired } expired, oldest { ls_draft-oldest }|.
      temp100-fix = `Drafts & Housekeeping tab: delete expired drafts, schedule z2ui5_cl_cockpit_job.`.
      APPEND temp100 TO result.
    ENDIF.
    IF ls_draft-rows > 100000.

      CLEAR temp101.
      temp101-state = `Warning`.
      temp101-app = `(draft table)`.
      temp101-hint = `Large draft table`.
      temp101-value = |{ ls_draft-rows } rows|.
      temp101-fix = `Shorten the draft expiry in the user exit, check which apps write large drafts.`.
      APPEND temp101 TO result.
    ENDIF.

  ENDMETHOD.

  METHOD get_live.

    TYPES:
      BEGIN OF ty_s_act,
        app       TYPE c LENGTH 30,
        users     TYPE i,
        last_seen TYPE timestampl,
      END OF ty_s_act.
    TYPES temp7 TYPE STANDARD TABLE OF ty_s_act WITH DEFAULT KEY.
DATA lt_act TYPE temp7.
    DATA ls_draft TYPE z2ui5_cl_cockpit_draft=>ty_s_info.
    DATA lv_since TYPE timestampl.
    DATA lv_none TYPE abap_bool.
    DATA temp2 TYPE xsdboolean.
    DATA ls_act LIKE LINE OF lt_act.
      DATA temp102 TYPE z2ui5_cl_cockpit_stats=>ty_s_live_app.
      DATA temp13 TYPE z2ui5_cl_cockpit_stats=>ty_s_live_app-users.
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

      CLEAR temp102.
      temp102-app = ls_act-app.

      IF lv_none = abap_false.
        temp13 = ls_act-users.
      ELSE.
        CLEAR temp13.
      ENDIF.
      temp102-users = temp13.
      temp102-last_seen = z2ui5_cl_cockpit_setup=>ts_text( ls_act-last_seen ).
      APPEND temp102 TO result-t_app.
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

    DATA lv_from_ts TYPE timestampl.
    DATA lv_from_day TYPE string.
    lv_from_ts = z2ui5_cl_cockpit_setup=>now_minus_seconds( hours * 3600 ).

    lv_from_day = z2ui5_cl_cockpit_setup=>day_of( lv_from_ts ).

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

    result = window_of( it_rows = lt_rows
                        from_ts = lv_from_ts ).

  ENDMETHOD.

  METHOD window_of.

    DATA ls_all TYPE ty_s_sum.
    DATA lt_sum TYPE ty_t_sum_app.

    " day and hour as one key - the window of the first hours of a UTC day
    " starts on the day before
    DATA lv_from_key TYPE string.
    DATA ls_row LIKE LINE OF it_rows.
    DATA temp103 TYPE z2ui5_cl_cockpit_stats=>ty_s_window.
    DATA ls_sum LIKE LINE OF lt_sum.
      DATA temp104 TYPE z2ui5_cl_cockpit_stats=>ty_s_window.
      DATA temp14 TYPE z2ui5_cl_cockpit_stats=>ty_s_window-app.
    lv_from_key = |{ z2ui5_cl_cockpit_setup=>day_of( from_ts ) }{ z2ui5_cl_cockpit_setup=>hour_of( from_ts ) }|.


    LOOP AT it_rows INTO ls_row.
      IF |{ ls_row-utc_day }{ ls_row-utc_hour }| < lv_from_key.
        CONTINUE.
      ENDIF.
      add_to_app( EXPORTING is_row = ls_row
                  CHANGING  ct_sum = lt_sum ).
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = ls_all ).
    ENDLOOP.


    CLEAR temp103.
    temp103-roundtrips = to_i( ls_all-cnt ).
    temp103-errors = to_i( ls_all-cnt_err ).
    temp103-p95_ms = p95( ls_all ).
    APPEND temp103 TO result.

    LOOP AT lt_sum INTO ls_sum.

      CLEAR temp104.

      IF ls_sum-app IS INITIAL.
        temp14 = c_no_app.
      ELSE.
        temp14 = ls_sum-app.
      ENDIF.
      temp104-app = temp14.
      temp104-roundtrips = to_i( ls_sum-cnt ).
      temp104-errors = to_i( ls_sum-cnt_err ).
      temp104-p95_ms = p95( ls_sum ).
      APPEND temp104 TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD select_sums.
      DATA temp105 TYPE ty_s_db_sum-app.
      DATA lv_app LIKE temp105.
      FIELD-SYMBOLS <row> LIKE LINE OF result.

    IF app IS SUPPLIED.

      temp105 = app.

      lv_app = temp105.
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

    DATA ls_sum TYPE ty_s_sum.
    MOVE-CORRESPONDING is_row TO ls_sum.
    merge_sum( EXPORTING is_sum = ls_sum
               CHANGING  cs_sum = cs_sum ).

  ENDMETHOD.

  METHOD add_to_app.

    DATA ls_acc TYPE ty_s_sum.
    READ TABLE ct_sum WITH TABLE KEY app = is_row-app INTO ls_acc.
    IF sy-subrc <> 0.
      CLEAR ls_acc.
      ls_acc-app = is_row-app.
      INSERT ls_acc INTO TABLE ct_sum.
    ENDIF.
    IF is_row-utc_day > ls_acc-utc_day OR ( is_row-utc_day = ls_acc-utc_day AND is_row-utc_hour > ls_acc-utc_hour ).
      ls_acc-utc_day  = is_row-utc_day.
      ls_acc-utc_hour = is_row-utc_hour.
    ENDIF.
    add_sum( EXPORTING is_row = is_row
             CHANGING  cs_sum = ls_acc ).
    MODIFY TABLE ct_sum FROM ls_acc.

  ENDMETHOD.

  METHOD merge_sum.

    cs_sum-cnt        = cs_sum-cnt + is_sum-cnt.
    cs_sum-cnt_start  = cs_sum-cnt_start + is_sum-cnt_start.
    cs_sum-cnt_err    = cs_sum-cnt_err + is_sum-cnt_err.
    cs_sum-ms_sum     = cs_sum-ms_sum + is_sum-ms_sum.
    cs_sum-ms_load    = cs_sum-ms_load + is_sum-ms_load.
    cs_sum-ms_main    = cs_sum-ms_main + is_sum-ms_main.
    cs_sum-ms_render  = cs_sum-ms_render + is_sum-ms_render.
    cs_sum-ms_client  = cs_sum-ms_client + is_sum-ms_client.
    cs_sum-cnt_client = cs_sum-cnt_client + is_sum-cnt_client.
    cs_sum-kb_res     = cs_sum-kb_res + is_sum-kb_res.
    cs_sum-h01 = cs_sum-h01 + is_sum-h01.
    cs_sum-h02 = cs_sum-h02 + is_sum-h02.
    cs_sum-h03 = cs_sum-h03 + is_sum-h03.
    cs_sum-h04 = cs_sum-h04 + is_sum-h04.
    cs_sum-h05 = cs_sum-h05 + is_sum-h05.
    cs_sum-h06 = cs_sum-h06 + is_sum-h06.
    cs_sum-h07 = cs_sum-h07 + is_sum-h07.
    cs_sum-h08 = cs_sum-h08 + is_sum-h08.
    cs_sum-h09 = cs_sum-h09 + is_sum-h09.
    IF is_sum-ms_max > cs_sum-ms_max.
      cs_sum-ms_max = is_sum-ms_max.
    ENDIF.
    IF is_sum-res_max > cs_sum-res_max.
      cs_sum-res_max = is_sum-res_max.
    ENDIF.
    IF is_sum-mod_max > cs_sum-mod_max.
      cs_sum-mod_max = is_sum-mod_max.
    ENDIF.

  ENDMETHOD.

  METHOD p95.

    " The histogram knows how many roundtrips fell into each latency bucket.
    " The 95th percentile lies in the bucket where the running count passes
    " 95 % - interpolated linearly inside it, capped by the observed maximum.
    TYPES temp8 TYPE STANDARD TABLE OF ty_p WITH DEFAULT KEY.
DATA lt_h TYPE temp8.
    DATA lv_total TYPE ty_p.
    DATA lv_cum TYPE ty_p.
    DATA lv_target TYPE ty_p.
    DATA lv_lower TYPE i.

    DATA temp106 LIKE lt_h.
    DATA lv_h LIKE LINE OF lt_h.
      DATA lv_index LIKE sy-tabix.
      DATA lv_upper TYPE i.
    CLEAR temp106.
    INSERT is_sum-h01 INTO TABLE temp106.
    INSERT is_sum-h02 INTO TABLE temp106.
    INSERT is_sum-h03 INTO TABLE temp106.
    INSERT is_sum-h04 INTO TABLE temp106.
    INSERT is_sum-h05 INTO TABLE temp106.
    INSERT is_sum-h06 INTO TABLE temp106.
    INSERT is_sum-h07 INTO TABLE temp106.
    INSERT is_sum-h08 INTO TABLE temp106.
    INSERT is_sum-h09 INTO TABLE temp106.
    lt_h = temp106.

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

  METHOD last_text.

    IF day IS INITIAL.
      RETURN.
    ENDIF.
    result = |{ z2ui5_cl_cockpit_setup=>day_text( day ) } { hour }:00 UTC|.

  ENDMETHOD.

  METHOD to_i.

    IF val > 2147483647.
      result = 2147483647.
    ELSE.
      result = val.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
