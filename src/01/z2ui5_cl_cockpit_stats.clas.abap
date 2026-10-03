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
      END OF cs_monitor.

    CONSTANTS c_monitor_intf  TYPE string VALUE `Z2UI5_IF_UI5_MONITOR`.
    CONSTANTS c_monitor_class TYPE string VALUE `Z2UI5_CL_COCKPIT_MONITOR`.

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
    TYPES ty_t_day TYPE STANDARD TABLE OF ty_s_day WITH EMPTY KEY.

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
    TYPES ty_t_app TYPE STANDARD TABLE OF ty_s_app WITH EMPTY KEY.

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
    TYPES ty_t_event TYPE STANDARD TABLE OF ty_s_event WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_unused,
        app       TYPE string,
        last_used TYPE string,
      END OF ty_s_unused.
    TYPES ty_t_unused TYPE STANDARD TABLE OF ty_s_unused WITH EMPTY KEY.

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
    TYPES ty_t_error TYPE STANDARD TABLE OF ty_s_error WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_occurrence,
        id       TYPE string,
        time     TYPE string,
        user     TYPE string,
        draft_id TYPE string,
        ms_total TYPE i,
        start    TYPE string,
      END OF ty_s_occurrence.
    TYPES ty_t_occurrence TYPE STANDARD TABLE OF ty_s_occurrence WITH EMPTY KEY.

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
    TYPES ty_t_slow TYPE STANDARD TABLE OF ty_s_slow WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_hint,
        state TYPE string,
        app   TYPE string,
        hint  TYPE string,
        value TYPE string,
        fix   TYPE string,
      END OF ty_s_hint.
    TYPES ty_t_hint TYPE STANDARD TABLE OF ty_s_hint WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_live_app,
        app       TYPE string,
        users     TYPE i,
        last_seen TYPE string,
        event     TYPE string,
      END OF ty_s_live_app.
    TYPES ty_t_live_app TYPE STANDARD TABLE OF ty_s_live_app WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_live,
        sessions     TYPE i,
        users        TYPE i,
        apps         TYPE i,
        minutes      TYPE i,
        check_lock   TYPE abap_bool,
        t_app        TYPE ty_t_live_app,
      END OF ty_s_live.

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

  PROTECTED SECTION.

  PRIVATE SECTION.

    TYPES ty_p TYPE p LENGTH 16 DECIMALS 0.

    TYPES:
      BEGIN OF ty_s_sum,
        day       TYPE c LENGTH 8,
        app       TYPE c LENGTH 30,
        event     TYPE c LENGTH 40,
        hour      TYPE c LENGTH 2,
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
        day       TYPE c LENGTH 8,
        app       TYPE c LENGTH 30,
        event     TYPE c LENGTH 40,
        hour      TYPE c LENGTH 2,
        cnt       TYPE i,
        cnt_start TYPE i,
        cnt_err   TYPE i,
        ms_sum    TYPE i,
        ms_max    TYPE i,
        ms_load   TYPE i,
        ms_main   TYPE i,
        ms_render TYPE i,
        ms_client TYPE i,
        cnt_client TYPE i,
        kb_res    TYPE i,
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
    TYPES ty_t_db_sum TYPE STANDARD TABLE OF ty_s_db_sum WITH EMPTY KEY.

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

    IF z2ui5_cl_cockpit_inst=>check_type_exists( c_monitor_intf ) = abap_false.
      result = VALUE #( state      = cs_monitor-no_interface
                        strip_type = `Information`
                        text       = |This tab needs the roundtrip monitor hook { c_monitor_intf } of abap2UI5 - | &&
                                     |it ships with the abap2UI5 release after { z2ui5_if_app=>version }. | &&
                                     |Update abap2UI5, then pull the admin cockpit from its main branch. | &&
                                     |Installation & Security and Drafts work already.| ).
      RETURN.
    ENDIF.

    IF z2ui5_cl_cockpit_inst=>check_class_exists( c_monitor_class ) = abap_false.
      result = VALUE #( state      = cs_monitor-no_class
                        strip_type = `Information`
                        text       = |Your abap2UI5 offers the monitor hook, but the cockpit's monitor class | &&
                                     |{ c_monitor_class } (package 02) is not installed. Pull the main branch | &&
                                     |of the admin cockpit to start recording.| ).
      RETURN.
    ENDIF.

    result-check_data = abap_true.
    DATA(lt_impl) = z2ui5_cl_cockpit_inst=>get_implementers( c_monitor_intf ).
    result-active_class = VALUE #( lt_impl[ 1 ] OPTIONAL ).

    IF result-active_class IS NOT INITIAL AND result-active_class <> c_monitor_class.
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

  METHOD get_kpi.

    DATA lv_rate TYPE p LENGTH 8 DECIMALS 1.
    DATA lv_users TYPE i.
    DATA(lv_today) = z2ui5_cl_cockpit_setup=>day_minus( 0 ).
    DATA ls_sum TYPE ty_s_sum.

    LOOP AT select_sums( lv_today ) INTO DATA(ls_row).
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
      SELECT COUNT( DISTINCT user_key ) FROM z2ui5_t_ck_usr
        WHERE day = @lv_today
        INTO @lv_users.
      result-users = |{ lv_users }|.
    ENDIF.

    IF ls_sum-cnt > 0.
      lv_rate = ls_sum-cnt_err * 100 / ls_sum-cnt.
      result-error_rate = |{ lv_rate }|.
      result-error_state = COND #( WHEN lv_rate >= 5 THEN `Error`
                                   WHEN lv_rate >= 1 THEN `Critical`
                                   ELSE `Good` ).
    ELSE.
      result-error_rate  = `0`.
      result-error_state = `Neutral`.
    ENDIF.

    DATA(lv_slow) = z2ui5_cl_cockpit_setup=>get( )-slow_ms.
    result-p95_state = COND #( WHEN result-roundtrips = 0 THEN `Neutral`
                               WHEN result-p95_ms >= lv_slow THEN `Error`
                               WHEN result-p95_ms >= lv_slow / 2 THEN `Critical`
                               ELSE `Good` ).

    DATA(ls_draft) = z2ui5_cl_cockpit_draft=>get_info( ).
    result-drafts = ls_draft-rows.
    result-drafts_state = COND #( WHEN ls_draft-check_backlog = abap_true THEN `Critical`
                                  ELSE `Neutral` ).

  ENDMETHOD.

  METHOD get_trend.

    DATA lv_date TYPE d.
    DATA lv_max TYPE ty_p.
    TYPES:
      BEGIN OF ty_s_users,
        day TYPE c LENGTH 8,
        cnt TYPE i,
      END OF ty_s_users.
    DATA lt_users TYPE STANDARD TABLE OF ty_s_users WITH EMPTY KEY.
    DATA lt_sum TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY day.

    DATA(lv_from) = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    LOOP AT select_sums( lv_from ) INTO DATA(ls_row).
      READ TABLE lt_sum WITH TABLE KEY day = ls_row-day ASSIGNING FIELD-SYMBOL(<sum>).
      IF sy-subrc <> 0.
        INSERT VALUE #( day = ls_row-day ) INTO TABLE lt_sum ASSIGNING <sum>.
      ENDIF.
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = <sum> ).
    ENDLOOP.

    SELECT day, COUNT( DISTINCT user_key ) AS cnt FROM z2ui5_t_ck_usr
      WHERE day >= @lv_from
      GROUP BY day
      INTO CORRESPONDING FIELDS OF TABLE @lt_users.

    LOOP AT lt_sum INTO DATA(ls_sum).
      IF ls_sum-cnt > lv_max.
        lv_max = ls_sum-cnt.
      ENDIF.
    ENDLOOP.

    DATA(lv_slow) = z2ui5_cl_cockpit_setup=>get( )-slow_ms.
    lv_date = z2ui5_cl_cockpit_setup=>day_minus( 0 ).
    DO days TIMES.
      DATA(lv_day) = CONV string( lv_date ).
      DATA(ls_day) = VALUE ty_s_day( day = day_text( lv_day ) ).
      READ TABLE lt_sum INTO ls_sum WITH TABLE KEY day = lv_day.
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
      READ TABLE lt_users INTO DATA(ls_users) WITH KEY day = lv_day. "#EC CI_SORTSEQ
      IF sy-subrc = 0.
        ls_day-users = ls_users-cnt.
      ENDIF.
      ls_day-bar_text = |{ ls_day-roundtrips }|.
      ls_day-state = COND #( WHEN ls_day-errors > 0 THEN `Error`
                             WHEN ls_day-p95_ms >= lv_slow THEN `Warning`
                             ELSE `Information` ).
      APPEND ls_day TO result.
      lv_date = lv_date - 1.
    ENDDO.

  ENDMETHOD.

  METHOD get_apps.

    TYPES:
      BEGIN OF ty_s_users,
        day TYPE c LENGTH 8,
        app TYPE c LENGTH 30,
        cnt TYPE i,
      END OF ty_s_users.
    DATA lt_users TYPE STANDARD TABLE OF ty_s_users WITH EMPTY KEY.
    DATA lt_sum TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY app.

    DATA(lv_from) = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    LOOP AT select_sums( lv_from ) INTO DATA(ls_row).
      READ TABLE lt_sum WITH TABLE KEY app = ls_row-app ASSIGNING FIELD-SYMBOL(<sum>).
      IF sy-subrc <> 0.
        INSERT VALUE #( app = ls_row-app ) INTO TABLE lt_sum ASSIGNING <sum>.
      ENDIF.
      " the newest day and hour of the group, for "last used"
      IF ls_row-day > <sum>-day OR ( ls_row-day = <sum>-day AND ls_row-hour > <sum>-hour ).
        <sum>-day  = ls_row-day.
        <sum>-hour = ls_row-hour.
      ENDIF.
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = <sum> ).
    ENDLOOP.

    SELECT day, app, COUNT( * ) AS cnt FROM z2ui5_t_ck_usr
      WHERE day >= @lv_from
      GROUP BY day, app
      INTO CORRESPONDING FIELDS OF TABLE @lt_users.

    LOOP AT lt_sum INTO DATA(ls_sum).
      DATA(ls_app) = VALUE ty_s_app( app          = COND #( WHEN ls_sum-app IS INITIAL
                                                            THEN `(no app resolved)` ELSE ls_sum-app )
                                     sessions     = to_i( ls_sum-cnt_start )
                                     roundtrips   = to_i( ls_sum-cnt )
                                     avg_ms       = avg( sum = ls_sum-ms_sum
                                                         cnt = ls_sum-cnt )
                                     p95_ms       = p95( ls_sum )
                                     kb_res_avg   = avg( sum = ls_sum-kb_res
                                                         cnt = ls_sum-cnt )
                                     kb_model_max = ls_sum-mod_max DIV 1024
                                     errors       = to_i( ls_sum-cnt_err )
                                     last_used    = last_text( day  = ls_sum-day
                                                               hour = ls_sum-hour ) ).
      " users: the most on one day - pseudonyms change daily, so a distinct
      " count across days would count the same person once per day
      LOOP AT lt_users INTO DATA(ls_users) WHERE app = ls_sum-app. "#EC CI_SORTSEQ
        IF ls_users-cnt > ls_app-users.
          ls_app-users = ls_users-cnt.
        ENDIF.
      ENDLOOP.
      ls_app-error_state = COND #( WHEN ls_app-errors > 0 THEN `Error` ELSE `None` ).
      APPEND ls_app TO result.
    ENDLOOP.

    SORT result BY roundtrips DESCENDING.

  ENDMETHOD.

  METHOD get_app_events.

    DATA lt_sum TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY event.

    DATA(lv_from) = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    LOOP AT select_sums( from_day = lv_from
                         app      = app ) INTO DATA(ls_row).
      READ TABLE lt_sum WITH TABLE KEY event = ls_row-event ASSIGNING FIELD-SYMBOL(<sum>).
      IF sy-subrc <> 0.
        INSERT VALUE #( event = ls_row-event ) INTO TABLE lt_sum ASSIGNING <sum>.
      ENDIF.
      IF ls_row-day > <sum>-day OR ( ls_row-day = <sum>-day AND ls_row-hour > <sum>-hour ).
        <sum>-day  = ls_row-day.
        <sum>-hour = ls_row-hour.
      ENDIF.
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = <sum> ).
    ENDLOOP.

    LOOP AT lt_sum INTO DATA(ls_sum).
      APPEND VALUE #( event      = COND #( WHEN ls_sum-event IS INITIAL
                                           THEN `(start / navigation)` ELSE ls_sum-event )
                      roundtrips = to_i( ls_sum-cnt )
                      avg_ms     = avg( sum = ls_sum-ms_sum
                                        cnt = ls_sum-cnt )
                      p95_ms     = p95( ls_sum )
                      max_ms     = ls_sum-ms_max
                      errors     = to_i( ls_sum-cnt_err )
                      kb_res_avg = avg( sum = ls_sum-kb_res
                                        cnt = ls_sum-cnt )
                      last_used  = last_text( day  = ls_sum-day
                                              hour = ls_sum-hour ) ) TO result.
    ENDLOOP.

    SORT result BY roundtrips DESCENDING.

  ENDMETHOD.

  METHOD get_unused.

    TYPES:
      BEGIN OF ty_s_last,
        app TYPE c LENGTH 30,
        day TYPE c LENGTH 8,
      END OF ty_s_last.
    DATA lt_last TYPE SORTED TABLE OF ty_s_last WITH UNIQUE KEY app.

    DATA(lv_from) = z2ui5_cl_cockpit_setup=>day_minus( z2ui5_cl_cockpit_setup=>get( )-unused_days ).

    SELECT app, MAX( day ) AS day FROM z2ui5_t_ck_agg
      GROUP BY app
      INTO CORRESPONDING FIELDS OF TABLE @lt_last.      "#EC CI_NOWHERE

    LOOP AT z2ui5_cl_cockpit_inst=>get_implementers( `Z2UI5_IF_APP` ) INTO DATA(lv_app).
      DATA(lv_key) = CONV ty_s_last-app( lv_app ).
      READ TABLE lt_last INTO DATA(ls_last) WITH TABLE KEY app = lv_key.
      IF sy-subrc <> 0.
        APPEND VALUE #( app       = lv_app
                        last_used = `never recorded` ) TO result.
      ELSEIF ls_last-day < lv_from.
        APPEND VALUE #( app       = lv_app
                        last_used = day_text( ls_last-day ) ) TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_errors.

    TYPES:
      BEGIN OF ty_s_log,
        timestampl  TYPE timestampl,
        app         TYPE c LENGTH 30,
        event       TYPE c LENGTH 40,
        error_class TYPE c LENGTH 30,
        error_head  TYPE c LENGTH 200,
      END OF ty_s_log.
    DATA lt_log TYPE STANDARD TABLE OF ty_s_log WITH EMPTY KEY.
    DATA lt_first TYPE STANDARD TABLE OF timestampl WITH EMPTY KEY.
    DATA lt_last TYPE STANDARD TABLE OF timestampl WITH EMPTY KEY.

    DATA(lv_from) = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    SELECT timestampl, app, event, error_class, error_head FROM z2ui5_t_ck_log
      INTO CORRESPONDING FIELDS OF TABLE @lt_log
      UP TO 5000 ROWS
      WHERE day >= @lv_from
        AND check_error = @abap_true
      ORDER BY timestampl DESCENDING.

    LOOP AT lt_log INTO DATA(ls_log).
      READ TABLE result ASSIGNING FIELD-SYMBOL(<error>)
           WITH KEY app         = ls_log-app
                    event       = ls_log-event
                    error_class = ls_log-error_class
                    error_head  = ls_log-error_head.     "#EC CI_SORTSEQ
      DATA(lv_index) = sy-tabix.
      IF sy-subrc <> 0.
        APPEND VALUE #( key         = |G{ lines( result ) + 1 }|
                        app         = ls_log-app
                        event       = ls_log-event
                        error_class = ls_log-error_class
                        error_head  = ls_log-error_head ) TO result ASSIGNING <error>.
        lv_index = lines( result ).
        " the rows come newest first: the first row of a group is its last
        " occurrence, every later one moves the first occurrence back
        APPEND ls_log-timestampl TO lt_last.
        APPEND ls_log-timestampl TO lt_first.
      ENDIF.
      <error>-count = <error>-count + 1.
      lt_first[ lv_index ] = ls_log-timestampl.
    ENDLOOP.

    LOOP AT result ASSIGNING <error>.
      lv_index = sy-tabix.
      <error>-first_seen = z2ui5_cl_cockpit_setup=>ts_text( lt_first[ lv_index ] ).
      <error>-last_seen  = z2ui5_cl_cockpit_setup=>ts_text( lt_last[ lv_index ] ).
    ENDLOOP.

    SORT result BY count DESCENDING.

  ENDMETHOD.

  METHOD get_error_occurrences.

    TYPES:
      BEGIN OF ty_s_log,
        id          TYPE c LENGTH 32,
        timestampl  TYPE timestampl,
        uname       TYPE c LENGTH 12,
        user_key    TYPE c LENGTH 64,
        draft_id    TYPE c LENGTH 32,
        ms_total    TYPE i,
        check_start TYPE abap_bool,
      END OF ty_s_log.
    DATA lt_log TYPE STANDARD TABLE OF ty_s_log WITH EMPTY KEY.

    DATA(lv_from)  = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).
    DATA(lv_app)   = CONV ty_s_error-app( is_error-app ).
    DATA(lv_event) = is_error-event.
    DATA(lv_class) = is_error-error_class.
    DATA(lv_head)  = is_error-error_head.

    SELECT id, timestampl, uname, user_key, draft_id, ms_total, check_start FROM z2ui5_t_ck_log
      INTO CORRESPONDING FIELDS OF TABLE @lt_log
      UP TO 200 ROWS
      WHERE day >= @lv_from
        AND check_error = @abap_true
        AND app = @lv_app
        AND event = @lv_event
        AND error_class = @lv_class
        AND error_head = @lv_head
      ORDER BY timestampl DESCENDING.

    DATA(lv_privacy) = z2ui5_cl_cockpit_setup=>check_privacy( ).
    LOOP AT lt_log INTO DATA(ls_log).
      DATA(ls_occ) = VALUE ty_s_occurrence( id       = ls_log-id
                                            time     = z2ui5_cl_cockpit_setup=>ts_text( ls_log-timestampl )
                                            draft_id = ls_log-draft_id
                                            ms_total = ls_log-ms_total
                                            start    = COND #( WHEN ls_log-check_start = abap_true
                                                               THEN `app start` ) ).
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

    DATA(lv_id) = CONV z2ui5_t_ck_log-id( id ).
    SELECT SINGLE error_text FROM z2ui5_t_ck_log
      WHERE id = @lv_id
      INTO @result.
    IF sy-subrc <> 0.
      CLEAR result.
    ENDIF.

  ENDMETHOD.

  METHOD get_slowest.

    DATA lt_log TYPE STANDARD TABLE OF z2ui5_t_ck_log WITH EMPTY KEY.

    DATA(lv_from) = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).

    SELECT id, timestampl, app, event, ms_total, ms_load, ms_main, ms_render, ms_client_prev,
           bytes_response, bytes_model, check_error
      FROM z2ui5_t_ck_log
      INTO CORRESPONDING FIELDS OF TABLE @lt_log
      UP TO @max_rows ROWS
      WHERE day >= @lv_from
        AND check_slow = @abap_true
      ORDER BY ms_total DESCENDING.

    LOOP AT lt_log INTO DATA(ls_log).
      DATA(ls_slow) = VALUE ty_s_slow( id        = ls_log-id
                                       time      = z2ui5_cl_cockpit_setup=>ts_text( ls_log-timestampl )
                                       app       = ls_log-app
                                       event     = ls_log-event
                                       ms_total  = ls_log-ms_total
                                       ms_load   = ls_log-ms_load
                                       ms_main   = ls_log-ms_main
                                       ms_render = ls_log-ms_render
                                       ms_client = ls_log-ms_client_prev
                                       kb_res    = ls_log-bytes_response DIV 1024
                                       kb_model  = ls_log-bytes_model DIV 1024
                                       error     = COND #( WHEN ls_log-check_error = abap_true THEN `error` ) ).
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

    DATA lt_all TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY app.
    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get( ).
    DATA(lv_from) = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).
    " growth: the model maximum of the newer half against the older half
    DATA(lv_half) = z2ui5_cl_cockpit_setup=>day_minus( days DIV 2 ).
    DATA lt_new TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY app.
    DATA lt_old TYPE SORTED TABLE OF ty_s_sum WITH UNIQUE KEY app.

    LOOP AT select_sums( lv_from ) INTO DATA(ls_row).
      IF ls_row-day > lv_half.
        READ TABLE lt_new WITH TABLE KEY app = ls_row-app ASSIGNING FIELD-SYMBOL(<sum>).
        IF sy-subrc <> 0.
          INSERT VALUE #( app = ls_row-app ) INTO TABLE lt_new ASSIGNING <sum>.
        ENDIF.
      ELSE.
        READ TABLE lt_old WITH TABLE KEY app = ls_row-app ASSIGNING <sum>.
        IF sy-subrc <> 0.
          INSERT VALUE #( app = ls_row-app ) INTO TABLE lt_old ASSIGNING <sum>.
        ENDIF.
      ENDIF.
      add_sum( EXPORTING is_row = ls_row
               CHANGING  cs_sum = <sum> ).
    ENDLOOP.

    " the whole period per app = newer + older half
    lt_all = lt_new.
    LOOP AT lt_old INTO DATA(ls_old).
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

    LOOP AT lt_all INTO DATA(ls_sum).
      DATA(lv_app) = CONV string( ls_sum-app ).

      IF ls_sum-mod_max > ls_set-model_warn_kb * 1024.
        APPEND VALUE #( state = `Warning`
                        app   = lv_app
                        hint  = `Large model`
                        value = |{ ls_sum-mod_max DIV 1024 } KB|
                        fix   = `Every PUBLIC attribute is serialized and sent on every roundtrip - keep only ` &&
                                `bound data public, page large tables.` ) TO result.
      ENDIF.

      IF ls_sum-res_max > ls_set-response_warn_kb * 1024.
        APPEND VALUE #( state = `Warning`
                        app   = lv_app
                        hint  = `Large response`
                        value = |{ ls_sum-res_max DIV 1024 } KB|
                        fix   = `Avoid re-rendering the whole view on every event; bound data changes are ` &&
                                `pushed without view_display( ).` ) TO result.
      ENDIF.

      DATA(lv_p95) = p95( ls_sum ).
      IF ls_sum-cnt >= 20 AND lv_p95 >= ls_set-slow_ms.
        APPEND VALUE #( state = `Warning`
                        app   = lv_app
                        hint  = `Slow p95`
                        value = |{ lv_p95 } ms|
                        fix   = `See the slowest roundtrips of this app and their dominant phase.` ) TO result.
      ENDIF.

      IF ls_sum-cnt >= 20 AND ls_sum-cnt_err * 20 >= ls_sum-cnt.
        APPEND VALUE #( state = `Error`
                        app   = lv_app
                        hint  = `Error rate of 5 % or more`
                        value = |{ to_i( ls_sum-cnt_err ) } of { to_i( ls_sum-cnt ) }|
                        fix   = `Errors tab: grouped by event and exception class.` ) TO result.
      ENDIF.

      IF ls_sum-ms_sum > 0 AND ls_sum-ms_load * 2 > ls_sum-ms_sum AND ls_sum-cnt >= 20.
        APPEND VALUE #( state = `Information`
                        app   = lv_app
                        hint  = `Load phase dominates`
                        value = |{ to_i( ls_sum-ms_load * 100 / ls_sum-ms_sum ) } % of the time|
                        fix   = `Reading and deserializing the draft takes longer than the app itself - ` &&
                                `the app state is large.` ) TO result.
      ENDIF.

      IF ls_sum-ms_sum > 0 AND ls_sum-ms_render * 2 > ls_sum-ms_sum AND ls_sum-cnt >= 20.
        APPEND VALUE #( state = `Information`
                        app   = lv_app
                        hint  = `Render phase dominates`
                        value = |{ to_i( ls_sum-ms_render * 100 / ls_sum-ms_sum ) } % of the time|
                        fix   = `Serializing model and draft takes longer than the app itself.` ) TO result.
      ENDIF.

      IF ls_sum-cnt_client > 0 AND ls_sum-cnt > 0.
        DATA(lv_client) = avg( sum = ls_sum-ms_client
                               cnt = ls_sum-cnt_client ).
        DATA(lv_server) = avg( sum = ls_sum-ms_sum
                               cnt = ls_sum-cnt ).
        IF lv_client - lv_server > 1000.
          APPEND VALUE #( state = `Information`
                          app   = lv_app
                          hint  = `Browser and network time dominates`
                          value = |{ lv_client } ms in the browser, { lv_server } ms on the server|
                          fix   = `Check network latency, UI5 bootstrap location and the size of the view.` ) TO result.
        ENDIF.
      ENDIF.

      READ TABLE lt_old INTO ls_old WITH TABLE KEY app = ls_sum-app.
      IF sy-subrc = 0.
        READ TABLE lt_new INTO DATA(ls_new) WITH TABLE KEY app = ls_sum-app.
        IF sy-subrc = 0 AND ls_new-mod_max > 102400 AND ls_new-mod_max * 2 > ls_old-mod_max * 3.
          APPEND VALUE #( state = `Warning`
                          app   = lv_app
                          hint  = `Growing app state`
                          value = |{ ls_old-mod_max DIV 1024 } KB to { ls_new-mod_max DIV 1024 } KB|
                          fix   = `The model grows from one period to the next - data accumulating in ` &&
                                  `attributes (a log, a history table) that is never cleared?` ) TO result.
        ENDIF.
      ENDIF.
    ENDLOOP.

    DATA(ls_draft) = z2ui5_cl_cockpit_draft=>get_info( ).
    IF ls_draft-check_backlog = abap_true.
      APPEND VALUE #( state = `Warning`
                      app   = `(draft table)`
                      hint  = `Expired drafts are not deleted`
                      value = |{ ls_draft-rows_expired } expired, oldest { ls_draft-oldest }|
                      fix   = `Drafts & Housekeeping tab: delete expired drafts, schedule z2ui5_cl_cockpit_job.` ) TO result.
    ENDIF.
    IF ls_draft-rows > 100000.
      APPEND VALUE #( state = `Warning`
                      app   = `(draft table)`
                      hint  = `Large draft table`
                      value = |{ ls_draft-rows } rows|
                      fix   = `Shorten the draft expiry in the user exit, check which apps write large drafts.` ) TO result.
    ENDIF.

  ENDMETHOD.

  METHOD get_live.

    TYPES:
      BEGIN OF ty_s_act,
        app       TYPE c LENGTH 30,
        users     TYPE i,
        last_seen TYPE timestampl,
      END OF ty_s_act.
    DATA lt_act TYPE STANDARD TABLE OF ty_s_act WITH EMPTY KEY.

    result-minutes = minutes.
    DATA(ls_draft) = z2ui5_cl_cockpit_draft=>get_info( minutes ).
    result-sessions = ls_draft-rows_active.
    result-users    = ls_draft-users_active.

    DATA(lv_since) = z2ui5_cl_cockpit_setup=>now_minus_seconds( minutes * 60 ).
    SELECT app, COUNT( * ) AS users, MAX( last_seen ) AS last_seen FROM z2ui5_t_ck_act
      WHERE last_seen >= @lv_since
      GROUP BY app
      INTO CORRESPONDING FIELDS OF TABLE @lt_act.

    DATA(lv_none) = xsdbool( z2ui5_cl_cockpit_setup=>get( )-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-none ).
    LOOP AT lt_act INTO DATA(ls_act).
      APPEND VALUE #( app       = ls_act-app
                      users     = COND #( WHEN lv_none = abap_false THEN ls_act-users )
                      last_seen = z2ui5_cl_cockpit_setup=>ts_text( ls_act-last_seen ) ) TO result-t_app.
    ENDLOOP.
    SORT result-t_app BY users DESCENDING.
    result-apps = lines( result-t_app ).

    " the lock-manager addon is a hint only, never a dependency
    result-check_lock = xsdbool( z2ui5_cl_cockpit_inst=>check_class_exists( `Z2UI5_CL_APP_SM12` ) = abap_true ).

  ENDMETHOD.

  METHOD select_sums.

    IF app IS SUPPLIED.
      DATA(lv_app) = CONV ty_s_db_sum-app( app ).
      SELECT day, event, MAX( hour ) AS hour,
             SUM( cnt ) AS cnt, SUM( cnt_start ) AS cnt_start, SUM( cnt_err ) AS cnt_err,
             SUM( ms_sum ) AS ms_sum, MAX( ms_max ) AS ms_max,
             SUM( ms_load ) AS ms_load, SUM( ms_main ) AS ms_main, SUM( ms_render ) AS ms_render,
             SUM( ms_client ) AS ms_client, SUM( cnt_client ) AS cnt_client,
             SUM( kb_res ) AS kb_res, MAX( bytes_res_max ) AS res_max, MAX( bytes_mod_max ) AS mod_max,
             SUM( h01 ) AS h01, SUM( h02 ) AS h02, SUM( h03 ) AS h03, SUM( h04 ) AS h04, SUM( h05 ) AS h05,
             SUM( h06 ) AS h06, SUM( h07 ) AS h07, SUM( h08 ) AS h08, SUM( h09 ) AS h09
        FROM z2ui5_t_ck_agg
        WHERE day >= @from_day
          AND app = @lv_app
        GROUP BY day, event
        INTO CORRESPONDING FIELDS OF TABLE @result.
      LOOP AT result ASSIGNING FIELD-SYMBOL(<row>).
        <row>-app = lv_app.
      ENDLOOP.
    ELSE.
      SELECT day, app, MAX( hour ) AS hour,
             SUM( cnt ) AS cnt, SUM( cnt_start ) AS cnt_start, SUM( cnt_err ) AS cnt_err,
             SUM( ms_sum ) AS ms_sum, MAX( ms_max ) AS ms_max,
             SUM( ms_load ) AS ms_load, SUM( ms_main ) AS ms_main, SUM( ms_render ) AS ms_render,
             SUM( ms_client ) AS ms_client, SUM( cnt_client ) AS cnt_client,
             SUM( kb_res ) AS kb_res, MAX( bytes_res_max ) AS res_max, MAX( bytes_mod_max ) AS mod_max,
             SUM( h01 ) AS h01, SUM( h02 ) AS h02, SUM( h03 ) AS h03, SUM( h04 ) AS h04, SUM( h05 ) AS h05,
             SUM( h06 ) AS h06, SUM( h07 ) AS h07, SUM( h08 ) AS h08, SUM( h09 ) AS h09
        FROM z2ui5_t_ck_agg
        WHERE day >= @from_day
        GROUP BY day, app
        INTO CORRESPONDING FIELDS OF TABLE @result.
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
    DATA lt_h TYPE STANDARD TABLE OF ty_p WITH EMPTY KEY.
    DATA lv_total TYPE ty_p.
    DATA lv_cum TYPE ty_p.
    DATA lv_lower TYPE i.

    lt_h = VALUE #( ( is_sum-h01 ) ( is_sum-h02 ) ( is_sum-h03 ) ( is_sum-h04 ) ( is_sum-h05 )
                    ( is_sum-h06 ) ( is_sum-h07 ) ( is_sum-h08 ) ( is_sum-h09 ) ).
    LOOP AT lt_h INTO DATA(lv_h).
      lv_total = lv_total + lv_h.
    ENDLOOP.
    IF lv_total <= 0.
      RETURN.
    ENDIF.

    DATA(lv_target) = lv_total * 95 / 100.
    LOOP AT lt_h INTO lv_h.
      DATA(lv_index) = sy-tabix.
      DATA(lv_upper) = z2ui5_cl_cockpit_setup=>bucket_upper( lv_index ).
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
