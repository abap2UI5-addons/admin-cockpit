"! <p class="shorttext synchronized">admin cockpit - settings</p>
"!
"! The settings of the cockpit and of its roundtrip monitor, kept as
"! name/value rows in Z2UI5_T_CK_SET, plus the administrators in
"! Z2UI5_T_CK_ADM. Read once per roll area - the monitor asks on every
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
        " SAMPLE: the share of successful roundtrips that is recorded, 1-100
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
        " the UTC day the own tables were last purged by the monitor
        last_purge         TYPE string,
      END OF ty_s_settings.

    TYPES ty_t_names TYPE STANDARD TABLE OF string WITH EMPTY KEY.

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
    CLASS-METHODS set_last_purge
      IMPORTING
        day TYPE clike.

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

    "! A timestamp as readable UTC text, YYYY-MM-DD hh:mm:ss.
    CLASS-METHODS ts_text
      IMPORTING
        ts            TYPE timestampl
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

    CLASS-METHODS to_int
      IMPORTING
        val           TYPE clike
        default       TYPE i
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
        SELECT name, value FROM z2ui5_t_ck_set
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
          result-sample_pct = to_int( val     = ls_row-value
                                      default = result-sample_pct ).
        WHEN `SLOW_MS`.
          result-slow_ms = to_int( val     = ls_row-value
                                   default = result-slow_ms ).
        WHEN `RETENTION_DAYS`.
          result-retention_days = to_int( val     = ls_row-value
                                          default = result-retention_days ).
        WHEN `AGG_RETENTION_DAYS`.
          result-agg_retention_days = to_int( val     = ls_row-value
                                              default = result-agg_retention_days ).
        WHEN `USER_TRACKING`.
          IF ls_row-value = cs_users-hash OR ls_row-value = cs_users-none OR ls_row-value = cs_users-name.
            result-user_tracking = ls_row-value.
          ENDIF.
        WHEN `UNUSED_DAYS`.
          result-unused_days = to_int( val     = ls_row-value
                                       default = result-unused_days ).
        WHEN `RESPONSE_WARN_KB`.
          result-response_warn_kb = to_int( val     = ls_row-value
                                            default = result-response_warn_kb ).
        WHEN `MODEL_WARN_KB`.
          result-model_warn_kb = to_int( val     = ls_row-value
                                         default = result-model_warn_kb ).
        WHEN `LAST_PURGE`.
          result-last_purge = ls_row-value.
      ENDCASE.
    ENDLOOP.

    IF result-sample_pct < 1 OR result-sample_pct > 100.
      result-sample_pct = get_default( )-sample_pct.
    ENDIF.

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
                      model_warn_kb      = 1024 ).

  ENDMETHOD.

  METHOD save.

    DATA(ls_set) = settings.
    DATA(ls_def) = get_default( ).

    IF ls_set-mode <> cs_mode-all AND ls_set-mode <> cs_mode-errors
        AND ls_set-mode <> cs_mode-sample AND ls_set-mode <> cs_mode-off.
      ls_set-mode = ls_def-mode.
    ENDIF.
    IF ls_set-user_tracking <> cs_users-hash AND ls_set-user_tracking <> cs_users-none
        AND ls_set-user_tracking <> cs_users-name.
      ls_set-user_tracking = ls_def-user_tracking.
    ENDIF.
    IF ls_set-sample_pct < 1 OR ls_set-sample_pct > 100.
      ls_set-sample_pct = ls_def-sample_pct.
    ENDIF.
    IF ls_set-slow_ms <= 0.
      ls_set-slow_ms = ls_def-slow_ms.
    ENDIF.
    IF ls_set-retention_days <= 0.
      ls_set-retention_days = ls_def-retention_days.
    ENDIF.
    IF ls_set-agg_retention_days <= 0.
      ls_set-agg_retention_days = ls_def-agg_retention_days.
    ENDIF.
    IF ls_set-unused_days <= 0.
      ls_set-unused_days = ls_def-unused_days.
    ENDIF.
    IF ls_set-response_warn_kb <= 0.
      ls_set-response_warn_kb = ls_def-response_warn_kb.
    ENDIF.
    IF ls_set-model_warn_kb <= 0.
      ls_set-model_warn_kb = ls_def-model_warn_kb.
    ENDIF.

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

    reset_buffer( ).

  ENDMETHOD.

  METHOD set_last_purge.

    row_save( name  = `LAST_PURGE`
              value = day ).
    gs_settings-last_purge = day.

  ENDMETHOD.

  METHOD row_save.

    DATA(ls_row) = VALUE ty_s_row( name  = name
                                   value = value ).
    MODIFY z2ui5_t_ck_set FROM @ls_row.

  ENDMETHOD.

  METHOD get_admins.

    DATA lt_names TYPE STANDARD TABLE OF z2ui5_t_ck_adm-uname WITH EMPTY KEY.
    TRY.
        SELECT uname FROM z2ui5_t_ck_adm
          ORDER BY uname
          INTO TABLE @lt_names.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    LOOP AT lt_names INTO DATA(lv_name).
      APPEND CONV string( lv_name ) TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD add_admin.

    DATA ls_row TYPE z2ui5_t_ck_adm.
    DATA(lv_name) = to_upper( condense( uname ) ).
    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.

    ls_row-uname      = lv_name.
    ls_row-created_by = sy-uname.
    ls_row-created_at = now( ).
    MODIFY z2ui5_t_ck_adm FROM @ls_row.

  ENDMETHOD.

  METHOD remove_admin.

    DATA(lv_name) = to_upper( condense( uname ) ).
    DELETE FROM z2ui5_t_ck_adm WHERE uname = @lv_name.

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
    " earlier day is deleted when a new one is created: from that moment the
    " pseudonyms of the earlier day can no longer be recomputed from a name,
    " not even by an administrator with database access - which is the point.
    IF gv_salt_day = day AND gv_salt IS NOT INITIAL.
      result = gv_salt.
      RETURN.
    ENDIF.

    DATA(lv_name) = CONV ty_s_row-name( |SALT_{ day }| ).

    SELECT SINGLE value FROM z2ui5_t_ck_set
      WHERE name = @lv_name
      INTO @lv_value.
    IF sy-subrc <> 0.
      TRY.
          lv_value = cl_system_uuid=>create_uuid_c32_static( ).
        CATCH cx_uuid_error.
          RETURN.
      ENDTRY.
      DATA(ls_row) = VALUE ty_s_row( name  = lv_name
                                     value = lv_value ).
      INSERT z2ui5_t_ck_set FROM @ls_row.
      IF sy-subrc <> 0.
        " another work process created it a moment ago - use that one
        SELECT SINGLE value FROM z2ui5_t_ck_set
          WHERE name = @lv_name
          INTO @lv_value.
      ELSE.
        DELETE FROM z2ui5_t_ck_set
          WHERE name LIKE 'SALT_%'
            AND name <> @lv_name.
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

  METHOD to_int.

    result = default.
    DATA(lv_val) = condense( val ).
    IF lv_val IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        result = lv_val.
      CATCH cx_root.
        result = default.
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

    result = cl_abap_tstmp=>subtractsecs( tstmp = now( )
                                          secs  = seconds ).

  ENDMETHOD.

  METHOD ts_text.

    DATA lv_time TYPE t.
    DATA lv_date TYPE d.
    IF ts IS INITIAL.
      RETURN.
    ENDIF.
    CONVERT TIME STAMP ts TIME ZONE `UTC` INTO DATE lv_date TIME lv_time.
    result = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) } { lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }|.

  ENDMETHOD.

ENDCLASS.
