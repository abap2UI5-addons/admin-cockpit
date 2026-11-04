"! <p class="shorttext synchronized">admin cockpit - agent endpoint</p>
"!
"! The Agents tab and the agent line of the traffic light: what the agent
"! addon (abap2UI5-addons/abap-agent-runtime, an MCP endpoint that lets AI agents operate
"! abap2UI5 apps) is set up to do and what agents did - calls per day, app
"! and client, refusals, the last entries of its audit log.
"!
"! The addon is optional and never a dependency: its tables and classes are
"! only named in literals and read with dynamic SQL inside TRY, so the
"! cockpit activates without it and shows "not installed" instead.
CLASS z2ui5_cl_cockpit_agent DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS c_log_table      TYPE string VALUE `T_14`.
    CONSTANTS c_set_table      TYPE string VALUE `T_17`.
    " the names of the two tables before the agent addon renumbered them -
    " an install that has not pulled the rename still has these
    CONSTANTS c_log_table_old  TYPE string VALUE `T_AG_LOG`.
    CONSTANTS c_set_table_old  TYPE string VALUE `T_AG_SET`.
    CONSTANTS c_settings_class TYPE string VALUE `CL_AGENT_SETTINGS`.
    CONSTANTS c_app_intf       TYPE string VALUE `IF_AGENT_APP`.
    " the most audit rows one display reads
    CONSTANTS c_max_rows       TYPE i VALUE 20000.

    CONSTANTS:
      BEGIN OF cs_kind,
        ok         TYPE string VALUE `ok`,
        " refused by the rules: endpoint off, app not enabled, event
        " forbidden or reserved for a human
        policy     TYPE string VALUE `policy`,
        " refused or failed for the request itself: wrong field, value,
        " session, or the app raised
        validation TYPE string VALUE `validation`,
      END OF cs_kind.

    TYPES:
      BEGIN OF ty_s_setup,
        installed TYPE abap_bool,
        readable  TYPE abap_bool,
        error     TYPE string,
        enabled   TYPE abap_bool,
        admins    TYPE i,
        app_rules TYPE i,
        allow_all TYPE abap_bool,
        opted_in  TYPE i,
      END OF ty_s_setup.

    TYPES:
      "! A row of Z2UI5_T_17, as far as the cockpit reads it.
      BEGIN OF ty_s_set,
        kind  TYPE c LENGTH 10,
        app   TYPE c LENGTH 60,
        item  TYPE c LENGTH 60,
        value TYPE c LENGTH 255,
      END OF ty_s_set.
    TYPES ty_t_set TYPE STANDARD TABLE OF ty_s_set WITH DEFAULT KEY.

    TYPES:
      "! A row of Z2UI5_T_14, as far as the cockpit reads it.
      BEGIN OF ty_s_row,
        timestampl TYPE timestampl,
        uname      TYPE c LENGTH 12,
        app        TYPE c LENGTH 30,
        operation  TYPE c LENGTH 20,
        event      TYPE c LENGTH 60,
        outcome    TYPE c LENGTH 10,
        text       TYPE c LENGTH 255,
        mcp_client TYPE c LENGTH 60,
      END OF ty_s_row.
    TYPES ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_day,
        day        TYPE string,
        calls      TYPE i,
        policy     TYPE i,
        validation TYPE i,
        bar        TYPE i,
        state      TYPE string,
      END OF ty_s_day.
    TYPES ty_t_day TYPE STANDARD TABLE OF ty_s_day WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_count,
        name       TYPE string,
        calls      TYPE i,
        policy     TYPE i,
        validation TYPE i,
        last       TYPE string,
      END OF ty_s_count.
    TYPES ty_t_count TYPE STANDARD TABLE OF ty_s_count WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_entry,
        time      TYPE string,
        user      TYPE string,
        app       TYPE string,
        operation TYPE string,
        event     TYPE string,
        kind      TYPE string,
        state     TYPE string,
        text      TYPE string,
        client    TYPE string,
      END OF ty_s_entry.
    TYPES ty_t_entry TYPE STANDARD TABLE OF ty_s_entry WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_info,
        installed    TYPE abap_bool,
        readable     TYPE abap_bool,
        strip_type   TYPE string,
        text         TYPE string,
        enabled_text TYPE string,
        calls        TYPE i,
        policy       TYPE i,
        validation   TYPE i,
        users        TYPE i,
        check_capped TYPE abap_bool,
        t_day        TYPE ty_t_day,
        t_app        TYPE ty_t_count,
        t_client     TYPE ty_t_count,
        t_last       TYPE ty_t_entry,
      END OF ty_s_info.

    "! Whether the addon is there and how its endpoint is set up.
    CLASS-METHODS get_setup
      RETURNING
        VALUE(result) TYPE ty_s_setup.

    "! The Agents tab: the setup and the audit log of the last days.
    CLASS-METHODS get_info
      IMPORTING
        days          TYPE i
        last          TYPE i DEFAULT 50
      RETURNING
        VALUE(result) TYPE ty_s_info.

    "! The setup figures of a set of settings rows (the addon's own table).
    CLASS-METHODS setup_of
      IMPORTING
        it_set        TYPE ty_t_set
      RETURNING
        VALUE(result) TYPE ty_s_setup.

    "! ok, policy or validation - what an audit row says about the call.
    CLASS-METHODS classify
      IMPORTING
        outcome       TYPE clike
        text          TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! The figures of audit rows (newest first): per day (the last days
    "! days, newest first), per app, per MCP client, and the last entries.
    CLASS-METHODS aggregate
      IMPORTING
        it_row        TYPE ty_t_row
        days          TYPE i
        last          TYPE i DEFAULT 50
        today         TYPE clike OPTIONAL
        privacy       TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(result) TYPE ty_s_info.

  PROTECTED SECTION.

  PRIVATE SECTION.

    "! the table name as installed: the current one, or the one before the
    "! agent addon renumbered its tables
    CLASS-METHODS table_name
      IMPORTING
        current       TYPE string
        old           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS count_add
      IMPORTING
        name  TYPE clike
        kind  TYPE string
        time  TYPE timestampl
      CHANGING
        count TYPE ty_t_count.

    CLASS-METHODS day_start
      IMPORTING
        day           TYPE clike
      RETURNING
        VALUE(result) TYPE timestampl.

ENDCLASS.


CLASS z2ui5_cl_cockpit_agent IMPLEMENTATION.

  METHOD get_setup.

    DATA lt_set TYPE ty_t_set.
    DATA lv_tab TYPE string.

    DATA lv_settings TYPE string.
    DATA lv_log TYPE string.
    DATA lv_log_old TYPE string.
    DATA temp1 TYPE xsdboolean.
        DATA lx TYPE REF TO cx_root.
    DATA ls_setup TYPE z2ui5_cl_cockpit_agent=>ty_s_setup.
    lv_settings = z2ui5_cl_cockpit_inst=>obj_name( c_settings_class ).

    lv_log = z2ui5_cl_cockpit_inst=>obj_name( c_log_table ).

    lv_log_old = z2ui5_cl_cockpit_inst=>obj_name( c_log_table_old ).

    temp1 = boolc( z2ui5_cl_cockpit_inst=>check_class_exists( lv_settings ) = abap_true OR z2ui5_cl_cockpit_inst=>check_type_exists( lv_log ) = abap_true OR z2ui5_cl_cockpit_inst=>check_type_exists( lv_log_old ) = abap_true ).
    result-installed = temp1.
    IF result-installed = abap_false.
      RETURN.
    ENDIF.

    lv_tab = table_name( current = z2ui5_cl_cockpit_inst=>obj_name( c_set_table )
                         old     = z2ui5_cl_cockpit_inst=>obj_name( c_set_table_old ) ).
    TRY.
        SELECT kind app item value FROM (lv_tab)
          INTO CORRESPONDING FIELDS OF TABLE lt_set.   "#EC CI_NOWHERE

      CATCH cx_root INTO lx.
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.


    ls_setup = setup_of( lt_set ).
    result-readable  = abap_true.
    result-enabled   = ls_setup-enabled.
    result-admins    = ls_setup-admins.
    result-app_rules = ls_setup-app_rules.
    result-allow_all = ls_setup-allow_all.
    result-opted_in  = lines( z2ui5_cl_cockpit_inst=>get_implementers( z2ui5_cl_cockpit_inst=>obj_name( c_app_intf ) ) ).

  ENDMETHOD.

  METHOD setup_of.

    DATA ls_set LIKE LINE OF it_set.
      DATA lv_kind TYPE string.
      DATA lv_value TYPE string.
      DATA lv_pattern TYPE string.
    LOOP AT it_set INTO ls_set.

      lv_kind = to_upper( ls_set-kind ).

      lv_value = to_upper( condense( ls_set-value ) ).

      lv_pattern = condense( ls_set-app ).
      CASE lv_kind.
        WHEN `ENABLED`.
          IF lv_value = abap_true.
            result-enabled = abap_true.
          ENDIF.
        WHEN `ADMIN`.
          result-admins = result-admins + 1.
        WHEN `APP`.
          IF lv_value = `ALLOW`.
            result-app_rules = result-app_rules + 1.
            IF lv_pattern = `*`.
              result-allow_all = abap_true.
            ENDIF.
          ENDIF.
      ENDCASE.
    ENDLOOP.
    result-installed = abap_true.
    result-readable  = abap_true.

  ENDMETHOD.

  METHOD classify.

    DATA lv_text TYPE string.
    DATA lv_outcome TYPE string.

    lv_outcome = to_lower( outcome ).
    IF lv_outcome = `ok`.
      result = cs_kind-ok.
      RETURN.
    ENDIF.

    lv_text = to_lower( text ).
    IF lv_text CS `forbidden for agents`
        OR lv_text CS `needs a human`
        OR lv_text CS `not enabled for agents`
        OR lv_text CS `endpoint is disabled`
        OR lv_text CS `never operable by an agent`.
      result = cs_kind-policy.
    ELSE.
      result = cs_kind-validation.
    ENDIF.

  ENDMETHOD.

  METHOD get_info.

    DATA lt_row TYPE ty_t_row.
    DATA lv_tab TYPE string.

    DATA ls_setup TYPE z2ui5_cl_cockpit_agent=>ty_s_setup.
    DATA lv_from TYPE timestampl.
        DATA lx TYPE REF TO cx_root.
    DATA temp2 TYPE xsdboolean.
    DATA temp30 TYPE z2ui5_cl_cockpit_agent=>ty_s_info-strip_type.
    DATA temp31 TYPE string.
    ls_setup = get_setup( ).
    result-installed = ls_setup-installed.
    IF ls_setup-installed = abap_false.
      result-strip_type = `Information`.
      result-text = `The agent addon (github.com/abap2UI5-addons/abap-agent-runtime) is not installed - nothing to show. ` &&
                    `It is an MCP endpoint that lets AI agents operate abap2UI5 apps as the calling user.`.
      RETURN.
    ENDIF.


    lv_from = day_start( z2ui5_cl_cockpit_setup=>day_minus( days - 1 ) ).
    lv_tab = table_name( current = z2ui5_cl_cockpit_inst=>obj_name( c_log_table )
                         old     = z2ui5_cl_cockpit_inst=>obj_name( c_log_table_old ) ).
    TRY.
        SELECT timestampl uname app operation event outcome text mcp_client
          FROM (lv_tab) INTO CORRESPONDING FIELDS OF TABLE lt_row
          WHERE timestampl >= lv_from
          ORDER BY timestampl DESCENDING

          UP TO c_max_rows ROWS.

      CATCH cx_root INTO lx.
        result-strip_type = `Warning`.
        result-text = |The agent addon is installed, but its audit log { lv_tab } could not be read: { lx->get_text( ) }|.
        RETURN.
    ENDTRY.

    result = aggregate( it_row  = lt_row
                        days    = days
                        last    = last
                        privacy = z2ui5_cl_cockpit_setup=>check_privacy( ) ).
    result-installed = abap_true.
    result-readable  = abap_true.

    temp2 = boolc( lines( lt_row ) >= c_max_rows ).
    result-check_capped = temp2.

    IF ls_setup-readable = abap_false.
      result-enabled_text = |unknown - settings not readable ({ ls_setup-error })|.
    ELSEIF ls_setup-enabled = abap_true.
      result-enabled_text = |yes - { ls_setup-opted_in } opted-in app(s), { ls_setup-app_rules } app rule(s), | &&
                            |{ ls_setup-admins } administrator(s)|.
    ELSE.
      result-enabled_text = `no - every tool call is refused`.
    ENDIF.


    IF ls_setup-enabled = abap_true.
      temp30 = `Warning`.
    ELSE.
      temp30 = `Success`.
    ENDIF.
    result-strip_type = temp30.

    IF result-check_capped = abap_true.
      temp31 = | - counted over the newest { c_max_rows } calls only|.
    ELSE.
      CLEAR temp31.
    ENDIF.
    result-text = |Agent endpoint enabled: { result-enabled_text }. { result-calls } call(s) in the period, | &&
                  |{ result-policy } refused by policy, { result-validation } refused or failed otherwise| &&
                  |{ temp31 }.|.

  ENDMETHOD.

  METHOD aggregate.

    DATA lv_date TYPE d.
    TYPES temp3 TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_users TYPE temp3.
    DATA lv_max TYPE i.
      DATA temp32 TYPE z2ui5_cl_cockpit_agent=>ty_s_day.
    DATA ls_row LIKE LINE OF it_row.
      DATA lv_kind TYPE string.
      DATA temp33 LIKE LINE OF lt_users.
      DATA lv_day TYPE string.
      DATA lv_day_text TYPE string.
      FIELD-SYMBOLS <day> TYPE z2ui5_cl_cockpit_agent=>ty_s_day.
      DATA temp34 TYPE string.
      DATA temp35 TYPE string.
        DATA temp36 TYPE z2ui5_cl_cockpit_agent=>ty_s_entry.
        DATA temp1 TYPE z2ui5_cl_cockpit_agent=>ty_s_entry-user.
        DATA temp2 TYPE z2ui5_cl_cockpit_agent=>ty_s_entry-state.
    DATA ls_day LIKE LINE OF result-t_day.
      DATA temp37 TYPE z2ui5_cl_cockpit_agent=>ty_s_day-state.

    IF today IS NOT INITIAL.
      lv_date = today.
    ELSE.
      lv_date = z2ui5_cl_cockpit_setup=>day_minus( 0 ).
    ENDIF.
    DO days TIMES.

      CLEAR temp32.
      temp32-day = |{ lv_date(4) }-{ lv_date+4(2) }-{ lv_date+6(2) }|.
      APPEND temp32 TO result-t_day.
      lv_date = lv_date - 1.
    ENDDO.


    LOOP AT it_row INTO ls_row.

      lv_kind = classify( outcome = ls_row-outcome
                                text    = ls_row-text ).
      result-calls = result-calls + 1.
      CASE lv_kind.
        WHEN cs_kind-policy.
          result-policy = result-policy + 1.
        WHEN cs_kind-validation.
          result-validation = result-validation + 1.
      ENDCASE.

      temp33 = ls_row-uname.
      INSERT temp33 INTO TABLE lt_users.


      lv_day = z2ui5_cl_cockpit_setup=>day_of( ls_row-timestampl ).

      lv_day_text = |{ lv_day(4) }-{ lv_day+4(2) }-{ lv_day+6(2) }|.

      READ TABLE result-t_day ASSIGNING <day> WITH KEY day = lv_day_text. "#EC CI_SORTSEQ
      IF sy-subrc = 0.
        <day>-calls = <day>-calls + 1.
        CASE lv_kind.
          WHEN cs_kind-policy.
            <day>-policy = <day>-policy + 1.
          WHEN cs_kind-validation.
            <day>-validation = <day>-validation + 1.
        ENDCASE.
      ENDIF.


      IF ls_row-app IS INITIAL.
        temp34 = `(no app)`.
      ELSE.
        temp34 = ls_row-app.
      ENDIF.
      count_add( EXPORTING name  = temp34
                           kind  = lv_kind
                           time  = ls_row-timestampl
                 CHANGING  count = result-t_app ).

      IF ls_row-mcp_client IS INITIAL.
        temp35 = `(unknown client)`.
      ELSE.
        temp35 = ls_row-mcp_client.
      ENDIF.
      count_add( EXPORTING name  = temp35
                           kind  = lv_kind
                           time  = ls_row-timestampl
                 CHANGING  count = result-t_client ).

      IF lines( result-t_last ) < last.

        CLEAR temp36.
        temp36-time = z2ui5_cl_cockpit_setup=>ts_text( ls_row-timestampl ).

        IF privacy = abap_true.
          temp1 = `(hidden)`.
        ELSE.
          temp1 = ls_row-uname.
        ENDIF.
        temp36-user = temp1.
        temp36-app = ls_row-app.
        temp36-operation = ls_row-operation.
        temp36-event = ls_row-event.
        temp36-kind = lv_kind.

        CASE lv_kind.
          WHEN cs_kind-ok.
            temp2 = `Success`.
          WHEN cs_kind-policy.
            temp2 = `Warning`.
          WHEN OTHERS.
            temp2 = `Error`.
        ENDCASE.
        temp36-state = temp2.
        temp36-text = ls_row-text.
        temp36-client = ls_row-mcp_client.
        APPEND temp36 TO result-t_last.
      ENDIF.
    ENDLOOP.

    result-users = lines( lt_users ).


    LOOP AT result-t_day INTO ls_day.
      IF ls_day-calls > lv_max.
        lv_max = ls_day-calls.
      ENDIF.
    ENDLOOP.
    LOOP AT result-t_day ASSIGNING <day>.
      IF lv_max > 0.
        <day>-bar = <day>-calls * 100 / lv_max.
      ENDIF.

      IF <day>-policy > 0.
        temp37 = `Warning`.
      ELSEIF <day>-validation > 0.
        temp37 = `Error`.
      ELSE.
        temp37 = `Information`.
      ENDIF.
      <day>-state = temp37.
    ENDLOOP.

    SORT result-t_app BY calls DESCENDING name ASCENDING.
    SORT result-t_client BY calls DESCENDING name ASCENDING.

  ENDMETHOD.

  METHOD count_add.

    FIELD-SYMBOLS <count> TYPE z2ui5_cl_cockpit_agent=>ty_s_count.
      DATA temp38 TYPE z2ui5_cl_cockpit_agent=>ty_s_count.
    READ TABLE count ASSIGNING <count> WITH KEY name = name. "#EC CI_SORTSEQ
    IF sy-subrc <> 0.
      " rows come newest first - the first one of a name is its last call

      CLEAR temp38.
      temp38-name = name.
      temp38-last = z2ui5_cl_cockpit_setup=>ts_text( time ).
      APPEND temp38 TO count ASSIGNING <count>.
    ENDIF.
    <count>-calls = <count>-calls + 1.
    CASE kind.
      WHEN cs_kind-policy.
        <count>-policy = <count>-policy + 1.
      WHEN cs_kind-validation.
        <count>-validation = <count>-validation + 1.
    ENDCASE.

  ENDMETHOD.

  METHOD day_start.

    DATA lv_date TYPE d.
    DATA lv_time TYPE t.
    lv_date = day.
    CONVERT DATE lv_date TIME lv_time INTO TIME STAMP result TIME ZONE `UTC`.

  ENDMETHOD.

  METHOD table_name.

    result = current.
    IF z2ui5_cl_cockpit_inst=>check_type_exists( current ) = abap_false
        AND z2ui5_cl_cockpit_inst=>check_type_exists( old ) = abap_true.
      result = old.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
