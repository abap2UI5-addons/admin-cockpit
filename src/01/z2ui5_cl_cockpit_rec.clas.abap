"! <p class="shorttext synchronized">admin cockpit - roundtrip recorder</p>
"!
"! Everything the roundtrip monitor persists, without naming the core's
"! monitor interface: z2ui5_cl_cockpit_monitor (package 02) maps the core's
"! structure onto ty_s_roundtrip and calls record( ). That keeps the logic in
"! the package that activates on every abap2UI5 release, and it is the door
"! for an installation that already has a monitor of its own - only one
"! implementer of z2ui5_if_ui5_monitor is called, so that one forwards here.
"!
"! What is written per roundtrip:
"! - Z2UI5_T_CK_AGG - one row per UTC day, hour, app and event, updated
"!   in place and lock-free (UPDATE ... SET col = col + n): counts, sums
"!   (DEC 15, saturated), maxima and a latency histogram (p95)
"! - Z2UI5_T_CK_USR - the user key per day and app, inserted once
"! - Z2UI5_T_CK_ACT - the user key per app with the last-seen timestamp
"!   (the Live tab)
"! - Z2UI5_T_CK_LOG - only for errors and for slow roundtrips: one raw row
"!   with the phase breakdown and the full error text
CLASS z2ui5_cl_cockpit_rec DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      "! The roundtrip as the core reports it (Contract A of
      "! z2ui5_if_ui5_monitor=&gt;ty_s_roundtrip, field by field). The monitor
      "! fills it with MOVE-CORRESPONDING, so a field the core renames arrives
      "! empty here instead of breaking the activation.
      BEGIN OF ty_s_roundtrip,
        app            TYPE string,
        event          TYPE string,
        draft_id       TYPE string,
        draft_id_prev  TYPE string,
        uname          TYPE string,
        check_sticky   TYPE abap_bool,
        check_start    TYPE abap_bool,
        timestampl     TYPE timestampl,
        ms_total       TYPE i,
        ms_load        TYPE i,
        ms_main        TYPE i,
        ms_render      TYPE i,
        bytes_request  TYPE i,
        bytes_response TYPE i,
        bytes_model    TYPE i,
        ms_client_prev TYPE i,
        check_error    TYPE abap_bool,
        error_text     TYPE string,
        error_class    TYPE string,
      END OF ty_s_roundtrip.

    "! Persist one roundtrip according to the settings, and commit. A sticky
    "! roundtrip is buffered instead and written with the next one that is
    "! not sticky. Never raises - a monitor must not break an app.
    CLASS-METHODS record
      IMPORTING
        is_roundtrip TYPE ty_s_roundtrip.

    "! The same without the commit and without the error handling - the
    "! unit of work a test or a forwarding monitor wants to control itself.
    CLASS-METHODS write
      IMPORTING
        is_roundtrip TYPE ty_s_roundtrip
      RAISING
        cx_static_check.

  PROTECTED SECTION.

  PRIVATE SECTION.

    " a sum column: DEC 15, no decimals (INT4 overflows on a busy system)
    TYPES ty_sum TYPE p LENGTH 8 DECIMALS 0.
    CONSTANTS c_dec_max TYPE ty_sum VALUE 999999999999999.
    " entries of sticky roundtrips waiting for a roundtrip that may commit
    CONSTANTS c_buffer_max TYPE i VALUE 500.

    CLASS-DATA gt_buffer TYPE STANDARD TABLE OF ty_s_roundtrip WITH EMPTY KEY.

    CLASS-METHODS write_agg
      IMPORTING
        is_rt  TYPE ty_s_roundtrip
        day    TYPE clike
        hour   TYPE clike
        weight TYPE i
        slow   TYPE abap_bool.

    CLASS-METHODS write_user
      IMPORTING
        is_rt    TYPE ty_s_roundtrip
        day      TYPE clike
        user_key TYPE clike.

    CLASS-METHODS write_log
      IMPORTING
        is_rt    TYPE ty_s_roundtrip
        day      TYPE clike
        user_key TYPE clike
        slow     TYPE abap_bool
      RAISING
        cx_static_check.

    CLASS-METHODS purge_daily
      IMPORTING
        day TYPE clike.

    "! The increment of a sum column: val times weight, saturated at the
    "! largest DEC 15 - never an overflow dump, whatever the core reports.
    CLASS-METHODS sum_inc
      IMPORTING
        val           TYPE i
        weight        TYPE i
      RETURNING
        VALUE(result) TYPE ty_sum.

    CLASS-METHODS first_line
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS z2ui5_cl_cockpit_rec IMPLEMENTATION.

  METHOD record.

    " The LUW this runs in, as z2ui5_if_ui5_monitor documents it:
    " - not sticky: empty - the framework committed its draft save on
    "   success and rolled back before the call on failure. COMMIT WORK
    "   commits the monitor's rows and nothing of the app.
    " - sticky: the app's own - it may hold uncommitted work, update task
    "   registrations and locks across roundtrips. Nothing is written then:
    "   the entry waits in the roll area (which a sticky session keeps) and
    "   is written with the first roundtrip of this roll area that is not
    "   sticky. A session that ends while still sticky loses its buffered
    "   entries - the price of never touching the app's LUW. A secondary
    "   database connection would avoid that, but exists on Standard ABAP
    "   only, and the cockpit runs on ABAP Cloud as well.
    TRY.
        IF is_roundtrip-check_sticky = abap_true.
          IF lines( gt_buffer ) < c_buffer_max.
            APPEND is_roundtrip TO gt_buffer.
          ENDIF.
          RETURN.
        ENDIF.

        DATA(lt_buffer) = gt_buffer.
        CLEAR gt_buffer.
        LOOP AT lt_buffer INTO DATA(ls_buffered).
          write( ls_buffered ).
        ENDLOOP.
        write( is_roundtrip ).
        COMMIT WORK.
      CATCH cx_root.
        " never break an app because of the monitor - and the LUW held
        " nothing but the monitor's own rows, so nothing else is undone
        TRY.
            ROLLBACK WORK.                               "#EC CI_ROLLBACK
          CATCH cx_root ##NO_HANDLER.
        ENDTRY.
    ENDTRY.

  ENDMETHOD.

  METHOD write.

    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get( ).
    IF ls_set-mode = z2ui5_cl_cockpit_setup=>cs_mode-off.
      RETURN.
    ENDIF.

    DATA(ls_rt) = is_roundtrip.
    IF ls_rt-timestampl IS INITIAL.
      ls_rt-timestampl = z2ui5_cl_cockpit_setup=>now( ).
    ENDIF.
    ls_rt-app = to_upper( ls_rt-app ).

    DATA(lv_slow) = xsdbool( ls_rt-ms_total >= ls_set-slow_ms ).
    DATA(lv_weight) = 1.

    CASE ls_set-mode.
      WHEN z2ui5_cl_cockpit_setup=>cs_mode-errors.
        IF ls_rt-check_error = abap_false.
          RETURN.
        ENDIF.
      WHEN z2ui5_cl_cockpit_setup=>cs_mode-sample.
        " errors are always recorded; of the rest a share, decided on the
        " milliseconds of the start time - cheap, evenly spread, and every
        " platform's clock has them (not every one has the microseconds,
        " where the decision would always say yes). Each recorded roundtrip
        " then counts for 100 / pct, so counts and sums stay estimates of
        " the real totals
        IF ls_rt-check_error = abap_false.
          DATA(lv_ms) = CONV i( trunc( frac( ls_rt-timestampl ) * 1000 ) ).
          IF lv_ms MOD 100 >= ls_set-sample_pct.
            RETURN.
          ENDIF.
          lv_weight = 100 DIV ls_set-sample_pct.
        ENDIF.
    ENDCASE.

    DATA(lv_day) = z2ui5_cl_cockpit_setup=>day_of( ls_rt-timestampl ).
    DATA(lv_hour) = z2ui5_cl_cockpit_setup=>hour_of( ls_rt-timestampl ).

    IF ls_set-last_purge <> lv_day.
      purge_daily( lv_day ).
    ENDIF.

    write_agg( is_rt  = ls_rt
               day    = lv_day
               hour   = lv_hour
               weight = lv_weight
               slow   = lv_slow ).

    DATA(lv_user_key) = z2ui5_cl_cockpit_setup=>user_key( uname = ls_rt-uname
                                                          day   = lv_day ).
    write_user( is_rt    = ls_rt
                day      = lv_day
                user_key = lv_user_key ).

    IF ls_rt-check_error = abap_true OR lv_slow = abap_true.
      write_log( is_rt    = ls_rt
                 day      = lv_day
                 user_key = lv_user_key
                 slow     = lv_slow ).
    ENDIF.

  ENDMETHOD.

  METHOD write_agg.

    " Lock-free: one UPDATE adds this roundtrip to the row of its hour
    " (SET col = col + n is atomic on every database), an INSERT creates the
    " row when there is none, and the UPDATE runs once more when another work
    " process created it in between. No SELECT ... FOR UPDATE - nothing waits
    " for a row lock, and the statement is the same on ABAP Cloud.
    DATA ls_agg TYPE z2ui5_t_ck_agg.
    DATA lt_h TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    " host variables named like no column - after the 7.02 downport drops
    " the @ escapes, a parameter called DAY would compare the column to itself
    DATA(lv_day) = CONV z2ui5_t_ck_agg-day( day ).
    DATA(lv_hour) = CONV z2ui5_t_ck_agg-hour( hour ).
    DATA(lv_event) = CONV z2ui5_t_ck_agg-event( is_rt-event ).
    DATA(lv_app) = CONV z2ui5_t_ck_agg-app( is_rt-app ).

    " the increments - counts in INT4, sums in DEC 15, each saturated
    DATA(lv_cnt) = weight.
    DATA(lv_start) = COND i( WHEN is_rt-check_start = abap_true THEN weight ).
    DATA(lv_err) = COND i( WHEN is_rt-check_error = abap_true THEN 1 ).
    DATA(lv_slow) = COND i( WHEN slow = abap_true THEN weight ).
    DATA(lv_ms_sum) = sum_inc( val    = is_rt-ms_total
                               weight = weight ).
    DATA(lv_ms_load) = sum_inc( val    = is_rt-ms_load
                                weight = weight ).
    DATA(lv_ms_main) = sum_inc( val    = is_rt-ms_main
                                weight = weight ).
    DATA(lv_ms_render) = sum_inc( val    = is_rt-ms_render
                                  weight = weight ).
    DATA(lv_ms_client) = sum_inc( val    = is_rt-ms_client_prev
                                  weight = weight ).
    DATA(lv_cnt_client) = COND i( WHEN is_rt-ms_client_prev > 0 THEN weight ).
    DATA(lv_kb_req) = sum_inc( val    = is_rt-bytes_request DIV 1024
                               weight = weight ).
    DATA(lv_kb_res) = sum_inc( val    = is_rt-bytes_response DIV 1024
                               weight = weight ).
    DO 9 TIMES.
      APPEND 0 TO lt_h.
    ENDDO.
    lt_h[ z2ui5_cl_cockpit_setup=>bucket_index( is_rt-ms_total ) ] = weight.
    DATA(lv_h01) = lt_h[ 1 ].
    DATA(lv_h02) = lt_h[ 2 ].
    DATA(lv_h03) = lt_h[ 3 ].
    DATA(lv_h04) = lt_h[ 4 ].
    DATA(lv_h05) = lt_h[ 5 ].
    DATA(lv_h06) = lt_h[ 6 ].
    DATA(lv_h07) = lt_h[ 7 ].
    DATA(lv_h08) = lt_h[ 8 ].
    DATA(lv_h09) = lt_h[ 9 ].

    DO 2 TIMES.
      UPDATE z2ui5_t_ck_agg
        SET cnt        = cnt + @lv_cnt,
            cnt_start  = cnt_start + @lv_start,
            cnt_err    = cnt_err + @lv_err,
            cnt_slow   = cnt_slow + @lv_slow,
            ms_sum     = ms_sum + @lv_ms_sum,
            ms_load    = ms_load + @lv_ms_load,
            ms_main    = ms_main + @lv_ms_main,
            ms_render  = ms_render + @lv_ms_render,
            ms_client  = ms_client + @lv_ms_client,
            cnt_client = cnt_client + @lv_cnt_client,
            kb_req     = kb_req + @lv_kb_req,
            kb_res     = kb_res + @lv_kb_res,
            h01        = h01 + @lv_h01,
            h02        = h02 + @lv_h02,
            h03        = h03 + @lv_h03,
            h04        = h04 + @lv_h04,
            h05        = h05 + @lv_h05,
            h06        = h06 + @lv_h06,
            h07        = h07 + @lv_h07,
            h08        = h08 + @lv_h08,
            h09        = h09 + @lv_h09
        WHERE day   = @lv_day
          AND hour  = @lv_hour
          AND app   = @lv_app
          AND event = @lv_event.
      IF sy-dbcnt > 0.
        EXIT.
      ENDIF.

      ls_agg = VALUE #( day           = lv_day
                        hour          = lv_hour
                        app           = lv_app
                        event         = lv_event
                        cnt           = lv_cnt
                        cnt_start     = lv_start
                        cnt_err       = lv_err
                        cnt_slow      = lv_slow
                        ms_sum        = lv_ms_sum
                        ms_max        = is_rt-ms_total
                        ms_load       = lv_ms_load
                        ms_main       = lv_ms_main
                        ms_render     = lv_ms_render
                        ms_client     = lv_ms_client
                        cnt_client    = lv_cnt_client
                        kb_req        = lv_kb_req
                        kb_res        = lv_kb_res
                        bytes_res_max = is_rt-bytes_response
                        bytes_mod_max = is_rt-bytes_model
                        h01           = lv_h01
                        h02           = lv_h02
                        h03           = lv_h03
                        h04           = lv_h04
                        h05           = lv_h05
                        h06           = lv_h06
                        h07           = lv_h07
                        h08           = lv_h08
                        h09           = lv_h09 ).
      INSERT z2ui5_t_ck_agg FROM @ls_agg.
      IF sy-subrc = 0.
        " the maxima are in the new row already
        RETURN.
      ENDIF.
      " lost the race for the first row of this hour - the next pass adds
      " this roundtrip to the row the other process created
    ENDDO.

    " the maxima: a conditional UPDATE each, atomic as well
    DATA(lv_ms_max) = is_rt-ms_total.
    DATA(lv_res_max) = is_rt-bytes_response.
    DATA(lv_mod_max) = is_rt-bytes_model.
    IF lv_ms_max > 0.
      UPDATE z2ui5_t_ck_agg SET ms_max = @lv_ms_max
        WHERE day = @lv_day AND hour = @lv_hour AND app = @lv_app AND event = @lv_event
          AND ms_max < @lv_ms_max.
    ENDIF.
    IF lv_res_max > 0.
      UPDATE z2ui5_t_ck_agg SET bytes_res_max = @lv_res_max
        WHERE day = @lv_day AND hour = @lv_hour AND app = @lv_app AND event = @lv_event
          AND bytes_res_max < @lv_res_max.
    ENDIF.
    IF lv_mod_max > 0.
      UPDATE z2ui5_t_ck_agg SET bytes_mod_max = @lv_mod_max
        WHERE day = @lv_day AND hour = @lv_hour AND app = @lv_app AND event = @lv_event
          AND bytes_mod_max < @lv_mod_max.
    ENDIF.

  ENDMETHOD.

  METHOD write_user.

    DATA ls_act TYPE z2ui5_t_ck_act.
    DATA ls_usr TYPE z2ui5_t_ck_usr.
    DATA(lv_app) = CONV z2ui5_t_ck_usr-app( is_rt-app ).
    DATA(lv_now) = z2ui5_cl_cockpit_setup=>now( ).

    IF user_key IS NOT INITIAL.
      ls_usr-day        = day.
      ls_usr-app        = lv_app.
      ls_usr-user_key   = user_key.
      ls_usr-first_seen = lv_now.
      " a duplicate key is the normal case - the user was counted already
      INSERT z2ui5_t_ck_usr FROM @ls_usr ##SUBRC_OK.
    ENDIF.

    ls_act-user_key  = user_key.
    ls_act-app       = lv_app.
    ls_act-last_seen = lv_now.
    ls_act-event     = is_rt-event.
    ls_act-cnt       = 1.
    MODIFY z2ui5_t_ck_act FROM @ls_act.

  ENDMETHOD.

  METHOD write_log.

    DATA ls_log TYPE z2ui5_t_ck_log.

    ls_log-id             = cl_system_uuid=>create_uuid_c32_static( ).
    ls_log-timestampl     = is_rt-timestampl.
    ls_log-day            = day.
    ls_log-app            = is_rt-app.
    ls_log-event          = is_rt-event.
    ls_log-user_key       = user_key.
    IF z2ui5_cl_cockpit_setup=>check_privacy( ) = abap_false.
      ls_log-uname = is_rt-uname.
    ENDIF.
    ls_log-draft_id       = is_rt-draft_id.
    ls_log-draft_id_prev  = is_rt-draft_id_prev.
    ls_log-check_start    = is_rt-check_start.
    ls_log-check_sticky   = is_rt-check_sticky.
    ls_log-check_error    = is_rt-check_error.
    ls_log-check_slow     = slow.
    ls_log-ms_total       = is_rt-ms_total.
    ls_log-ms_load        = is_rt-ms_load.
    ls_log-ms_main        = is_rt-ms_main.
    ls_log-ms_render      = is_rt-ms_render.
    ls_log-ms_client_prev = is_rt-ms_client_prev.
    ls_log-bytes_request  = is_rt-bytes_request.
    ls_log-bytes_response = is_rt-bytes_response.
    ls_log-bytes_model    = is_rt-bytes_model.
    ls_log-error_class    = is_rt-error_class.
    ls_log-error_head     = first_line( is_rt-error_text ).
    ls_log-error_text     = is_rt-error_text.

    INSERT z2ui5_t_ck_log FROM @ls_log.

  ENDMETHOD.

  METHOD purge_daily.

    " once per UTC day, on the first recorded roundtrip: the own tables
    " follow their retention without a background job. The job class does
    " the same on demand.
    z2ui5_cl_cockpit_setup=>set_last_purge( day ).
    z2ui5_cl_cockpit_job=>purge_own( ).

  ENDMETHOD.

  METHOD sum_inc.

    DATA lv_sum TYPE p LENGTH 16 DECIMALS 0.
    IF val <= 0 OR weight <= 0.
      RETURN.
    ENDIF.
    lv_sum = val.
    lv_sum = lv_sum * weight.
    IF lv_sum > c_dec_max.
      result = c_dec_max.
    ELSE.
      result = lv_sum.
    ENDIF.

  ENDMETHOD.

  METHOD first_line.

    result = val.
    FIND FIRST OCCURRENCE OF cl_abap_char_utilities=>newline IN result MATCH OFFSET DATA(lv_off).
    IF sy-subrc = 0.
      result = result(lv_off).
    ENDIF.
    IF strlen( result ) > 200.
      result = result(200).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
