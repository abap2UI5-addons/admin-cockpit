"! <p class="shorttext synchronized">admin cockpit - settings</p>
"!
"! The settings of the cockpit and of its roundtrip monitor, kept as
"! name/value rows in Z2UI5_T_26, plus the administrators in
"! Z2UI5_T_21. Read once per roll area - the monitor asks on every
"! roundtrip, and the settings change a few times a year.
"!
"! Privacy is part of the settings, not an afterthought: user_tracking
"! decides whether the monitor stores user names (NAME), a pseudonym that
"! cannot be linked across days (HASH, the default) or nothing at all (NONE).
CLASS z2ui5_cl_cockpit_setup DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF cs_mode,
        all    TYPE string VALUE `ALL`,
        errors TYPE string VALUE `ERRORS`,
        sample TYPE string VALUE `SAMPLE`,
        off    TYPE string VALUE `OFF`,
      END OF cs_mode.

    CONSTANTS:
      BEGIN OF cs_users,
        hash TYPE string VALUE `HASH`,
        none TYPE string VALUE `NONE`,
        name TYPE string VALUE `NAME`,
      END OF cs_users.

    TYPES:
      BEGIN OF ty_s_settings,
        " what the monitor records: ALL, ERRORS, SAMPLE or OFF
        mode               TYPE string,
        " SAMPLE: the share of successful roundtrips that is recorded, in
        " percent - a divisor of 100: 1, 2, 4, 5, 10, 20, 25, 50 or 100
        sample_pct         TYPE i,
        " a roundtrip at or above this many milliseconds is slow and lands
        " in the raw log with its phase breakdown
        slow_ms            TYPE i,
        " raw log, user rows and live activity are deleted after this many days
        retention_days     TYPE i,
        " the hourly aggregates are deleted after this many days
        agg_retention_days TYPE i,
        " HASH (default), NONE or NAME - see the class documentation
        user_tracking      TYPE string,
        " an app without a single roundtrip in this many days is unused
        unused_days        TYPE i,
        " runtime hints: a response above this size is reported
        response_warn_kb   TYPE i,
        " runtime hints: a model above this size is reported
        model_warn_kb      TYPE i,
        " alerts: an error rate at or above this many percent raises one,
        " 0 switches the rule off
        alert_err_pct      TYPE i,
        " alerts: a p95 at or above this many milliseconds raises one, 0
        " switches the rule off
        alert_p95_ms       TYPE i,
        " alerts: fewer roundtrips than this in the window raise nothing
        alert_min_cnt      TYPE i,
        " alerts: the window - the UTC hour running now plus this many before
        alert_hours        TYPE i,
        " recorder (z2ui5_cl_cockpit_wire): requests and responses are kept
        " this many days, 0 switches the recording off
        wire_days          TYPE i,
        " the UTC day the own tables were last purged by the monitor
        last_purge         TYPE string,
      END OF ty_s_settings.

    TYPES ty_t_names TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    " the most days a day setting takes - a hundred years
    CONSTANTS c_max_days TYPE i VALUE 36500.
    " the most KB a size threshold takes - still an INT4 in bytes
    CONSTANTS c_max_kb TYPE i VALUE 2097151.

    "! The effective settings - stored values over the defaults.
    CLASS-METHODS get
      RETURNING
        VALUE(result) TYPE ty_s_settings.

    "! The settings a fresh installation runs with.
    CLASS-METHODS get_default
      RETURNING
        VALUE(result) TYPE ty_s_settings.

    "! Validate and persist; COMMIT is the caller's.
    CLASS-METHODS save
      IMPORTING
        settings TYPE ty_s_settings.

    "! Remember the day of the last purge (monitor housekeeping).
    "! Deprecated - the recorders claim the day with claim_purge( ), which
    "! lets exactly one work process purge; kept for callers of its own.
    CLASS-METHODS set_last_purge
      IMPORTING
        day TYPE clike.

    "! Claim the daily purge of the own tables for a UTC day: abap_true for
    "! exactly one caller per day - a conditional UPDATE of LAST_PURGE that
    "! moves it forward only (an INSERT for the very first purge). Not
    "! committed: the caller commits the claim before it purges, so the row
    "! is locked for no longer than this statement.
    "! @parameter day | the UTC day YYYYMMDD
    CLASS-METHODS claim_purge
      IMPORTING
        day           TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS get_admins
      RETURNING
        VALUE(result) TYPE ty_t_names.

    CLASS-METHODS add_admin
      IMPORTING
        uname TYPE clike.

    CLASS-METHODS remove_admin
      IMPORTING
        uname TYPE clike.

    "! The key a user is counted under, by the user_tracking setting: the
    "! name, a pseudonym salted per UTC day, or empty.
    "! @parameter uname | the user name
    "! @parameter day | the UTC day YYYYMMDD the pseudonym is valid for
    CLASS-METHODS user_key
      IMPORTING
        uname         TYPE clike
        day           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! abap_true unless user names are stored in clear text.
    CLASS-METHODS check_privacy
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Forget the buffered settings (after a save, and in tests).
    CLASS-METHODS reset_buffer.

    "! Run this roll area with the given settings instead of the stored
    "! ones, until reset_buffer( ) - for unit tests, and for a forwarding
    "! monitor that wants other settings than the cockpit's.
    CLASS-METHODS set_buffer
      IMPORTING
        settings TYPE ty_s_settings.

    "! The p95 approximation works on these bucket bounds (milliseconds):
    "! H01 counts roundtrips below the first bound, H09 everything above the
    "! last one.
    CLASS-METHODS bucket_index
      IMPORTING
        ms            TYPE i
      RETURNING
        VALUE(result) TYPE i.

    CLASS-METHODS bucket_upper
      IMPORTING
        index         TYPE i
      RETURNING
        VALUE(result) TYPE i.

    "! Current UTC timestamp.
    CLASS-METHODS now
      RETURNING
        VALUE(result) TYPE timestampl.

    "! The UTC day YYYYMMDD of a timestamp.
    CLASS-METHODS day_of
      IMPORTING
        ts            TYPE timestampl
      RETURNING
        VALUE(result) TYPE string.

    "! The UTC hour hh of a timestamp.
    CLASS-METHODS hour_of
      IMPORTING
        ts            TYPE timestampl
      RETURNING
        VALUE(result) TYPE string.

    "! The UTC day YYYYMMDD that lies n days before today.
    CLASS-METHODS day_minus
      IMPORTING
        days          TYPE i
      RETURNING
        VALUE(result) TYPE string.

    "! A timestamp n seconds before now.
    CLASS-METHODS now_minus_seconds
      IMPORTING
        seconds       TYPE i
      RETURNING
        VALUE(result) TYPE timestampl.

    "! A timestamp n days before now - by the date, so any day setting
    "! fits (n * 86400 seconds overflows an INT4 beyond 24855 days).
    CLASS-METHODS now_minus_days
      IMPORTING
        days          TYPE i
      RETURNING
        VALUE(result) TYPE timestampl.

    "! A timestamp n seconds before the given one, in whole seconds.
    CLASS-METHODS ts_minus_seconds
      IMPORTING
        ts            TYPE timestampl
        seconds       TYPE i
      RETURNING
        VALUE(result) TYPE timestampl.

    "! A timestamp as readable UTC text, YYYY-MM-DD hh:mm:ss.
    CLASS-METHODS ts_text
      IMPORTING
        ts            TYPE timestampl
      RETURNING
        VALUE(result) TYPE string.

    "! A day YYYYMMDD as readable text, YYYY-MM-DD - a shorter text as it is.
    CLASS-METHODS day_text
      IMPORTING
        day           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! How a stored user key is shown where names are not: "pseudonym" and
    "! its first 8 characters, "not recorded" when there is none.
    CLASS-METHODS pseudonym_text
      IMPORTING
        user_key      TYPE clike
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_s_row,
        name  TYPE c LENGTH 30,
        value TYPE c LENGTH 255,
      END OF ty_s_row.
    TYPES ty_t_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.

    CLASS-DATA gs_settings TYPE ty_s_settings.
    CLASS-DATA gv_loaded   TYPE abap_bool.
    CLASS-DATA gv_salt_day TYPE string.
    CLASS-DATA gv_salt     TYPE string.

    CLASS-METHODS row_save
      IMPORTING
        name  TYPE clike
        value TYPE clike.

    CLASS-METHODS salt_of_day
      IMPORTING
        day           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! Every setting in its bounds - what get( ) reads and save( ) stores.
    CLASS-METHODS check_settings
      CHANGING
        cs_set TYPE ty_s_settings.

    "! A setting in days: a non-positive value falls back, a value beyond
    "! c_max_days is cut to it.
    CLASS-METHODS days_in_range
      IMPORTING
        val           TYPE i
        fallback      TYPE i
      RETURNING
        VALUE(result) TYPE i.

    "! The alert settings in their bounds: 0 switches a threshold off (not
    "! the default, unlike the other settings), a value out of range falls
    "! back to the default.
    CLASS-METHODS check_alerts
      CHANGING
        cs_set TYPE ty_s_settings.

    CLASS-METHODS to_int
      IMPORTING
        val           TYPE clike
        fallback      TYPE i
      RETURNING
        VALUE(result) TYPE i.

ENDCLASS.


CLASS z2ui5_cl_cockpit_setup IMPLEMENTATION.

  METHOD get.

    DATA lt_rows TYPE ty_t_rows.
    IF gv_loaded = abap_true.
      result = gs_settings.
      RETURN.
    ENDIF.

    result = get_default( ).

    TRY.
        SELECT name, value FROM z2ui5_t_26
          INTO TABLE @lt_rows.                          "#EC CI_NOWHERE
      CATCH cx_root ##NO_HANDLER.
        " a table that is not there yet (half-imported addon) means defaults
    ENDTRY.

    LOOP AT lt_rows INTO DATA(ls_row).
      CASE ls_row-name.
        WHEN `MODE`.
          IF ls_row-value = cs_mode-all OR ls_row-value = cs_mode-errors
              OR ls_row-value = cs_mode-sample OR ls_row-value = cs_mode-off.
            result-mode = ls_row-value.
          ENDIF.
        WHEN `SAMPLE_PCT`.
          result-sample_pct = to_int( val      = ls_row-value
                                      fallback = result-sample_pct ).
        WHEN `SLOW_MS`.
          result-slow_ms = to_int( val      = ls_row-value
                                   fallback = result-slow_ms ).
        WHEN `RETENTION_DAYS`.
          result-retention_days = to_int( val      = ls_row-value
                                          fallback = result-retention_days ).
        WHEN `AGG_RETENTION_DAYS`.
          result-agg_retention_days = to_int( val      = ls_row-value
                                              fallback = result-agg_retention_days ).
        WHEN `USER_TRACKING`.
          IF ls_row-value = cs_users-hash OR ls_row-value = cs_users-none OR ls_row-value = cs_users-name.
            result-user_tracking = ls_row-value.
          ENDIF.
        WHEN `UNUSED_DAYS`.
          result-unused_days = to_int( val      = ls_row-value
                                       fallback = result-unused_days ).
        WHEN `RESPONSE_WARN_KB`.
          result-response_warn_kb = to_int( val      = ls_row-value
                                            fallback = result-response_warn_kb ).
        WHEN `MODEL_WARN_KB`.
          result-model_warn_kb = to_int( val      = ls_row-value
                                         fallback = result-model_warn_kb ).
        WHEN `ALERT_ERR_PCT`.
          result-alert_err_pct = to_int( val      = ls_row-value
                                         fallback = result-alert_err_pct ).
        WHEN `ALERT_P95_MS`.
          result-alert_p95_ms = to_int( val      = ls_row-value
                                        fallback = result-alert_p95_ms ).
        WHEN `ALERT_MIN_CNT`.
          result-alert_min_cnt = to_int( val      = ls_row-value
                                         fallback = result-alert_min_cnt ).
        WHEN `ALERT_HOURS`.
          result-alert_hours = to_int( val      = ls_row-value
                                       fallback = result-alert_hours ).
        WHEN `WIRE_DAYS`.
          result-wire_days = to_int( val      = ls_row-value
                                     fallback = result-wire_days ).
        WHEN `LAST_PURGE`.
          result-last_purge = ls_row-value.
      ENDCASE.
    ENDLOOP.

    check_settings( CHANGING cs_set = result ).

    gs_settings = result.
    gv_loaded   = abap_true.

  ENDMETHOD.

  METHOD get_default.

    result = VALUE #( mode               = cs_mode-all
                      sample_pct         = 10
                      slow_ms            = 2000
                      retention_days     = 30
                      agg_retention_days = 400
                      user_tracking      = cs_users-hash
                      unused_days        = 90
                      response_warn_kb   = 500
                      model_warn_kb      = 1024
                      alert_err_pct      = 5
                      alert_p95_ms       = 2000
                      alert_min_cnt      = 20
                      alert_hours        = 1
                      wire_days          = 2 ).

  ENDMETHOD.

  METHOD save.

    DATA(ls_set) = settings.
    check_settings( CHANGING cs_set = ls_set ).

    row_save( name  = `MODE`
              value = ls_set-mode ).
    row_save( name  = `SAMPLE_PCT`
              value = |{ ls_set-sample_pct }| ).
    row_save( name  = `SLOW_MS`
              value = |{ ls_set-slow_ms }| ).
    row_save( name  = `RETENTION_DAYS`
              value = |{ ls_set-retention_days }| ).
    row_save( name  = `AGG_RETENTION_DAYS`
              value = |{ ls_set-agg_retention_days }| ).
    row_save( name  = `USER_TRACKING`
              value = ls_set-user_tracking ).
    row_save( name  = `UNUSED_DAYS`
              value = |{ ls_set-unused_days }| ).
    row_save( name  = `RESPONSE_WARN_KB`
              value = |{ ls_set-response_warn_kb }| ).
    row_save( name  = `MODEL_WARN_KB`
              value = |{ ls_set-model_warn_kb }| ).
    row_save( name  = `ALERT_ERR_PCT`
              value = |{ ls_set-alert_err_pct }| ).
    row_save( name  = `ALERT_P95_MS`
              value = |{ ls_set-alert_p95_ms }| ).
    row_save( name  = `ALERT_MIN_CNT`
              value = |{ ls_set-alert_min_cnt }| ).
    row_save( name  = `ALERT_HOURS`
              value = |{ ls_set-alert_hours }| ).
    row_save( name  = `WIRE_DAYS`
              value = |{ ls_set-wire_days }| ).

    reset_buffer( ).

  ENDMETHOD.

  METHOD set_last_purge.

    row_save( name  = `LAST_PURGE`
              value = day ).
    gs_settings-last_purge = day.

  ENDMETHOD.

  METHOD claim_purge.

    DATA ls_row TYPE z2ui5_t_26.
    " host variables named like no column (the 7.02 downport drops the @)
    DATA(lv_key) = CONV ty_s_row-name( `LAST_PURGE` ).
    DATA(lv_day) = CONV ty_s_row-value( day ).

    " asked once per roll area and day, whoever wins
    gs_settings-last_purge = day.

    UPDATE z2ui5_t_26 SET value = @lv_day
      WHERE name = @lv_key
        AND value < @lv_day.
    IF sy-dbcnt > 0.
      result = abap_true.
      RETURN.
    ENDIF.
    " no row yet, or the day is claimed already - the INSERT tells which
    ls_row-name  = lv_key.
    ls_row-value = lv_day.
    INSERT z2ui5_t_26 FROM @ls_row.
    result = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.

  METHOD row_save.

    DATA(ls_row) = VALUE z2ui5_t_26( name  = name
                                         value = value ).
    MODIFY z2ui5_t_26 FROM @ls_row.

  ENDMETHOD.

  METHOD get_admins.

    DATA lt_names TYPE STANDARD TABLE OF z2ui5_t_21-uname WITH EMPTY KEY.
    TRY.
        SELECT uname FROM z2ui5_t_21
          ORDER BY uname
          INTO TABLE @lt_names.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    LOOP AT lt_names INTO DATA(lv_name).
      APPEND CONV string( lv_name ) TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD add_admin.

    DATA ls_row TYPE z2ui5_t_21.
    DATA(lv_name) = to_upper( condense( uname ) ).
    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.

    ls_row-uname      = lv_name.
    ls_row-created_by = sy-uname.
    ls_row-created_at = now( ).
    MODIFY z2ui5_t_21 FROM @ls_row.

  ENDMETHOD.

  METHOD remove_admin.

    DATA(lv_name) = to_upper( condense( uname ) ).
    DELETE FROM z2ui5_t_21 WHERE uname = @lv_name.

  ENDMETHOD.

  METHOD user_key.

    DATA(ls_set) = get( ).

    CASE ls_set-user_tracking.
      WHEN cs_users-name.
        result = uname.
      WHEN cs_users-none.
        CLEAR result.
      WHEN OTHERS.
        DATA(lv_salt) = salt_of_day( day ).
        IF lv_salt IS INITIAL.
          RETURN.
        ENDIF.
        TRY.
            cl_abap_message_digest=>calculate_hash_for_char(
              EXPORTING
                if_algorithm  = `SHA256`
                if_data       = |{ lv_salt }{ to_upper( uname ) }|
              IMPORTING
                ef_hashstring = result ).
          CATCH cx_root.
            " no hash function - count nobody rather than store the name
            CLEAR result.
        ENDTRY.
    ENDCASE.

  ENDMETHOD.

  METHOD salt_of_day.

    DATA lv_value TYPE ty_s_row-value.
    " One random salt per UTC day, stored as SALT_<day>. The salt of every
    " earlier day is deleted when a new one is created, and none is created
    " again for a day before today: from that moment the pseudonyms of the
    " earlier day can no longer be recomputed from a name, not even by an
    " administrator with database access - which is the point.
    IF gv_salt_day = day AND gv_salt IS NOT INITIAL.
      result = gv_salt.
      RETURN.
    ENDIF.

    DATA(lv_name) = CONV ty_s_row-name( |SALT_{ day }| ).

    SELECT SINGLE value FROM z2ui5_t_26
      WHERE name = @lv_name
      INTO @lv_value.
    IF sy-subrc <> 0.
      " never for a day before today: its salt was deleted on purpose (a
      " roundtrip that started before midnight UTC, a buffered entry) - a
      " new one would make the day's pseudonyms differ, and its creation
      " would delete the salt of today
      IF day < day_of( now( ) ).
        RETURN.
      ENDIF.
      TRY.
          lv_value = cl_system_uuid=>create_uuid_c32_static( ).
        CATCH cx_uuid_error.
          RETURN.
      ENDTRY.
      DATA(ls_row) = VALUE z2ui5_t_26( name  = lv_name
                                           value = lv_value ).
      INSERT z2ui5_t_26 FROM @ls_row.
      IF sy-subrc <> 0.
        " another work process created it a moment ago - use that one
        SELECT SINGLE value FROM z2ui5_t_26
          WHERE name = @lv_name
          INTO @lv_value.
      ELSE.
        " the earlier days only - a later day's salt another work process
        " created around midnight stays
        DELETE FROM z2ui5_t_26
          WHERE name LIKE 'SALT_%'
            AND name < @lv_name.
      ENDIF.
    ENDIF.

    gv_salt_day = day.
    gv_salt     = lv_value.
    result      = gv_salt.

  ENDMETHOD.

  METHOD check_privacy.

    result = xsdbool( get( )-user_tracking <> cs_users-name ).

  ENDMETHOD.

  METHOD reset_buffer.

    CLEAR gs_settings.
    CLEAR gv_loaded.

  ENDMETHOD.

  METHOD set_buffer.

    gs_settings = settings.
    gv_loaded   = abap_true.

  ENDMETHOD.

  METHOD check_settings.

    DATA(ls_def) = get_default( ).

    IF cs_set-mode <> cs_mode-all AND cs_set-mode <> cs_mode-errors
        AND cs_set-mode <> cs_mode-sample AND cs_set-mode <> cs_mode-off.
      cs_set-mode = ls_def-mode.
    ENDIF.
    IF cs_set-user_tracking <> cs_users-hash AND cs_set-user_tracking <> cs_users-none
        AND cs_set-user_tracking <> cs_users-name.
      cs_set-user_tracking = ls_def-user_tracking.
    ENDIF.
    IF cs_set-sample_pct < 1 OR cs_set-sample_pct > 100.
      cs_set-sample_pct = ls_def-sample_pct.
    ENDIF.
    " a recorded sample counts 100 / pct times - in whole numbers, so only a
    " divisor of 100 keeps the counts unbiased: 60 % counted each roundtrip
    " once. Any other share is rounded down to one (1 at the least)
    WHILE 100 MOD cs_set-sample_pct <> 0.
      cs_set-sample_pct = cs_set-sample_pct - 1.
    ENDWHILE.
    IF cs_set-slow_ms <= 0.
      cs_set-slow_ms = ls_def-slow_ms.
    ENDIF.
    " the day settings from above as well: the housekeeping turns them into
    " a date before today, and a value no date can hold failed every purge
    cs_set-retention_days = days_in_range( val      = cs_set-retention_days
                                           fallback = ls_def-retention_days ).
    cs_set-agg_retention_days = days_in_range( val      = cs_set-agg_retention_days
                                               fallback = ls_def-agg_retention_days ).
    cs_set-unused_days = days_in_range( val      = cs_set-unused_days
                                        fallback = ls_def-unused_days ).
    " the hint thresholds are compared in bytes
    IF cs_set-response_warn_kb <= 0.
      cs_set-response_warn_kb = ls_def-response_warn_kb.
    ELSEIF cs_set-response_warn_kb > c_max_kb.
      cs_set-response_warn_kb = c_max_kb.
    ENDIF.
    IF cs_set-model_warn_kb <= 0.
      cs_set-model_warn_kb = ls_def-model_warn_kb.
    ELSEIF cs_set-model_warn_kb > c_max_kb.
      cs_set-model_warn_kb = c_max_kb.
    ENDIF.
    check_alerts( CHANGING cs_set = cs_set ).
    " 0 is off, as with the alert thresholds - only a negative value is wrong
    IF cs_set-wire_days < 0.
      cs_set-wire_days = ls_def-wire_days.
    ELSEIF cs_set-wire_days > c_max_days.
      cs_set-wire_days = c_max_days.
    ENDIF.

  ENDMETHOD.

  METHOD days_in_range.

    IF val <= 0.
      result = fallback.
    ELSEIF val > c_max_days.
      result = c_max_days.
    ELSE.
      result = val.
    ENDIF.

  ENDMETHOD.

  METHOD check_alerts.

    DATA(ls_def) = get_default( ).
    IF cs_set-alert_err_pct < 0 OR cs_set-alert_err_pct > 100.
      cs_set-alert_err_pct = ls_def-alert_err_pct.
    ENDIF.
    IF cs_set-alert_p95_ms < 0.
      cs_set-alert_p95_ms = ls_def-alert_p95_ms.
    ENDIF.
    IF cs_set-alert_min_cnt <= 0.
      cs_set-alert_min_cnt = ls_def-alert_min_cnt.
    ENDIF.
    IF cs_set-alert_hours < 0 OR cs_set-alert_hours > 23.
      cs_set-alert_hours = ls_def-alert_hours.
    ENDIF.

  ENDMETHOD.

  METHOD to_int.

    result = fallback.
    DATA(lv_val) = condense( val ).
    IF lv_val IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        result = lv_val.
      CATCH cx_root.
        result = fallback.
    ENDTRY.

  ENDMETHOD.

  METHOD bucket_index.

    result = 9.
    DO 8 TIMES.
      IF ms < bucket_upper( sy-index ).
        result = sy-index.
        RETURN.
      ENDIF.
    ENDDO.

  ENDMETHOD.

  METHOD bucket_upper.

    CASE index.
      WHEN 1.
        result = 100.
      WHEN 2.
        result = 250.
      WHEN 3.
        result = 500.
      WHEN 4.
        result = 1000.
      WHEN 5.
        result = 2000.
      WHEN 6.
        result = 5000.
      WHEN 7.
        result = 10000.
      WHEN 8.
        result = 30000.
      WHEN OTHERS.
        result = 60000.
    ENDCASE.

  ENDMETHOD.

  METHOD now.

    GET TIME STAMP FIELD result.

  ENDMETHOD.

  METHOD day_of.

    DATA lv_date TYPE d.
    DATA lv_time TYPE t.
    CONVERT TIME STAMP ts TIME ZONE `UTC` INTO DATE lv_date TIME lv_time.
    result = lv_date.

  ENDMETHOD.

  METHOD hour_of.

    DATA lv_date TYPE d.
    DATA lv_time TYPE t.
    CONVERT TIME STAMP ts TIME ZONE `UTC` INTO DATE lv_date TIME lv_time.
    result = lv_time(2).

  ENDMETHOD.

  METHOD day_minus.

    DATA lv_date TYPE d.
    lv_date = day_of( now( ) ).
    lv_date = lv_date - days.
    result = lv_date.

  ENDMETHOD.

  METHOD now_minus_seconds.

    result = ts_minus_seconds( ts      = now( )
                               seconds = seconds ).

  ENDMETHOD.

  METHOD now_minus_days.

    DATA lv_date TYPE d.
    DATA lv_time TYPE t.
    DATA(lv_now) = now( ).
    CONVERT TIME STAMP lv_now TIME ZONE `UTC` INTO DATE lv_date TIME lv_time.
    lv_date = lv_date - days.
    CONVERT DATE lv_date TIME lv_time INTO TIME STAMP result TIME ZONE `UTC`.

  ENDMETHOD.

  METHOD ts_minus_seconds.

    " By hand, not with cl_abap_tstmp=>subtractsecs: on a system that
    " raised CX_PARAMETER_INVALID_TYPE ("Parameter TSTMP has invalid type")
    " for every caller - the first screen after the claim (2026-10-06).
    " Date and time of day in UTC, the whole days off the date, the rest off
    " the time - one day more when the time of day is smaller than the rest
    " (the subtraction of a t wraps around midnight by itself).
    DATA lv_date TYPE d.
    DATA lv_time TYPE t.
    DATA lv_rest TYPE i.
    DATA lv_time_secs TYPE i.

    CONVERT TIME STAMP ts TIME ZONE `UTC` INTO DATE lv_date TIME lv_time.
    lv_rest = seconds MOD 86400.
    lv_date = lv_date - seconds DIV 86400.
    lv_time_secs = lv_time.
    IF lv_time_secs < lv_rest.
      lv_date = lv_date - 1.
    ENDIF.
    lv_time = lv_time - lv_rest.
    CONVERT DATE lv_date TIME lv_time INTO TIME STAMP result TIME ZONE `UTC`.

  ENDMETHOD.

  METHOD ts_text.

    DATA lv_time TYPE t.
    DATA lv_date TYPE d.
    IF ts IS INITIAL.
      RETURN.
    ENDIF.
    CONVERT TIME STAMP ts TIME ZONE `UTC` INTO DATE lv_date TIME lv_time.
    result = |{ day_text( lv_date ) } { lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }|.

  ENDMETHOD.

  METHOD day_text.

    DATA lv_day TYPE string.
    lv_day = day.
    IF strlen( lv_day ) < 8.
      result = lv_day.
      RETURN.
    ENDIF.
    result = |{ lv_day(4) }-{ lv_day+4(2) }-{ lv_day+6(2) }|.

  ENDMETHOD.

  METHOD pseudonym_text.

    DATA lv_key TYPE string.
    lv_key = user_key.
    IF lv_key IS INITIAL.
      result = `not recorded`.
    ELSEIF strlen( lv_key ) > 8.
      result = |pseudonym { lv_key(8) }|.
    ELSE.
      result = |pseudonym { lv_key }|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
