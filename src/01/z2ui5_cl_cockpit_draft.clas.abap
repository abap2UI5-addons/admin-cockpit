"! <p class="shorttext synchronized">admin cockpit - draft table</p>
"!
"! Size, age and owners of the abap2UI5 draft table, and its cleanup.
"!
"! The draft table and the draft service are framework internals, not
"! released API - so they are only ever named in literals and reached with
"! dynamic SQL and dynamic calls. If a later abap2UI5 release renames them,
"! this class reports "not readable" instead of the whole cockpit failing to
"! activate after a pull.
CLASS z2ui5_cl_cockpit_draft DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS c_table TYPE string VALUE `Z2UI5_T_01`.

    TYPES:
      BEGIN OF ty_s_user,
        user    TYPE string,
        drafts  TYPE i,
        oldest  TYPE string,
        newest  TYPE string,
      END OF ty_s_user.
    TYPES ty_t_user TYPE STANDARD TABLE OF ty_s_user WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_app,
        app    TYPE string,
        drafts TYPE i,
        kb     TYPE i,
        kb_avg TYPE i,
        kb_max TYPE i,
      END OF ty_s_app.
    TYPES ty_t_app TYPE STANDARD TABLE OF ty_s_app WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_info,
        check_readable TYPE abap_bool,
        error          TYPE string,
        rows           TYPE i,
        rows_expired   TYPE i,
        rows_active    TYPE i,
        users_active   TYPE i,
        users          TYPE i,
        oldest         TYPE string,
        newest         TYPE string,
        expiry_hours   TYPE i,
        cutoff         TYPE string,
        check_backlog  TYPE abap_bool,
        t_user         TYPE ty_t_user,
      END OF ty_s_info.

    TYPES:
      BEGIN OF ty_s_analysis,
        rows_analyzed TYPE i,
        check_partial TYPE abap_bool,
        kb_total      TYPE i,
        t_app         TYPE ty_t_app,
      END OF ty_s_analysis.

    "! Counts, ages and owners. Never raises - check_readable / error say
    "! whether the table could be read.
    "! @parameter active_minutes | a draft written within this many minutes
    "! counts as an active session
    CLASS-METHODS get_info
      IMPORTING
        active_minutes TYPE i DEFAULT 5
      RETURNING
        VALUE(result)  TYPE ty_s_info.

    "! Reads the serialized state of up to max_rows drafts and reports size
    "! per app. The app is taken from the serialized object graph - an
    "! estimate, see app_of_draft. Reads every owner's drafts, reports sizes
    "! and class names only, never content.
    CLASS-METHODS analyze
      IMPORTING
        max_rows      TYPE i DEFAULT 20000
      RETURNING
        VALUE(result) TYPE ty_s_analysis
      RAISING
        cx_static_check.

    "! Deletes the drafts older than the expiry the framework computes, via
    "! the framework's own draft store (which honours a host-installed
    "! store), with a direct DELETE as fallback. Commits.
    "! @parameter result | the number of drafts that are gone
    CLASS-METHODS delete_expired
      RETURNING
        VALUE(result) TYPE i
      RAISING
        cx_static_check.

    "! The draft expiry in hours, as the framework computes it (default 4,
    "! or what the user exit sets).
    CLASS-METHODS get_expiry_hours
      RETURNING
        VALUE(result) TYPE i.

    "! The app class of a serialized draft - the first global class in the
    "! asXML object graph that is not part of the framework itself.
    CLASS-METHODS app_of_draft
      IMPORTING
        data          TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.

  PRIVATE SECTION.

    CLASS-METHODS count_rows
      IMPORTING
        before        TYPE timestampl OPTIONAL
      RETURNING
        VALUE(result) TYPE i
      RAISING
        cx_static_check.

    CLASS-METHODS cutoff
      RETURNING
        VALUE(result) TYPE timestampl.

ENDCLASS.


CLASS z2ui5_cl_cockpit_draft IMPLEMENTATION.

  METHOD get_info.

    TYPES:
      BEGIN OF ty_s_grp,
        uname  TYPE c LENGTH 32,
        cnt    TYPE i,
        oldest TYPE timestampl,
        newest TYPE timestampl,
      END OF ty_s_grp.
    DATA lt_grp TYPE STANDARD TABLE OF ty_s_grp WITH EMPTY KEY.
    DATA lv_min TYPE timestampl.
    DATA lv_max TYPE timestampl.
    DATA lv_tab TYPE string.

    lv_tab = c_table.
    result-expiry_hours = get_expiry_hours( ).
    DATA(lv_cutoff) = cutoff( ).
    result-cutoff = z2ui5_cl_cockpit_setup=>ts_text( lv_cutoff ).
    DATA(lv_active) = z2ui5_cl_cockpit_setup=>now_minus_seconds( active_minutes * 60 ).

    TRY.
        result-rows = count_rows( ).
        result-rows_expired = count_rows( lv_cutoff ).
        result-rows_active = result-rows - count_rows( lv_active ).

        SELECT MIN( timestampl ), MAX( timestampl ) FROM (lv_tab)
          INTO (@lv_min, @lv_max).                      "#EC CI_NOWHERE

        SELECT uname, COUNT( * ) AS cnt, MIN( timestampl ) AS oldest, MAX( timestampl ) AS newest
          FROM (lv_tab)
          GROUP BY uname
          INTO CORRESPONDING FIELDS OF TABLE @lt_grp.   "#EC CI_NOWHERE
        result-check_readable = abap_true.
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.

    result-oldest = z2ui5_cl_cockpit_setup=>ts_text( lv_min ).
    result-newest = z2ui5_cl_cockpit_setup=>ts_text( lv_max ).
    result-users  = lines( lt_grp ).
    " expired rows that are still there mean nobody deletes them - the
    " framework cleans up on its own, so a backlog of more than a day's
    " worth points at a failing cleanup
    result-check_backlog = xsdbool( result-rows_expired > 0
        AND lv_min < z2ui5_cl_cockpit_setup=>now_minus_seconds( ( result-expiry_hours + 24 ) * 3600 ) ).

    LOOP AT lt_grp INTO DATA(ls_grp).
      IF ls_grp-newest >= lv_active.
        result-users_active = result-users_active + 1.
      ENDIF.
    ENDLOOP.

    SORT lt_grp BY cnt DESCENDING.
    DATA(lv_privacy) = z2ui5_cl_cockpit_setup=>check_privacy( ).
    LOOP AT lt_grp INTO ls_grp.
      DATA(ls_user) = VALUE ty_s_user( drafts = ls_grp-cnt
                                       oldest = z2ui5_cl_cockpit_setup=>ts_text( ls_grp-oldest )
                                       newest = z2ui5_cl_cockpit_setup=>ts_text( ls_grp-newest ) ).
      IF lv_privacy = abap_true.
        ls_user-user = |User { sy-tabix }|.
      ELSE.
        ls_user-user = ls_grp-uname.
      ENDIF.
      APPEND ls_user TO result-t_user.
    ENDLOOP.

  ENDMETHOD.

  METHOD analyze.

    TYPES:
      BEGIN OF ty_s_row,
        id   TYPE c LENGTH 32,
        data TYPE string,
      END OF ty_s_row.
    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    DATA lv_last TYPE c LENGTH 32.
    DATA lv_tab TYPE string.
    DATA lt_app TYPE SORTED TABLE OF ty_s_app WITH UNIQUE KEY app.
    DATA lv_bytes_total TYPE p LENGTH 16 DECIMALS 0.

    lv_tab = c_table.

    DO.
      CLEAR lt_rows.
      SELECT id, data FROM (lv_tab)
        WHERE id > @lv_last
        ORDER BY id
        INTO CORRESPONDING FIELDS OF TABLE @lt_rows
        UP TO 200 ROWS.
      IF lt_rows IS INITIAL.
        EXIT.
      ENDIF.

      LOOP AT lt_rows INTO DATA(ls_row).
        DATA(lv_len) = strlen( ls_row-data ).
        lv_bytes_total = lv_bytes_total + lv_len.
        DATA(lv_app) = app_of_draft( ls_row-data ).
        IF lv_app IS INITIAL.
          lv_app = `(unknown)`.
        ENDIF.
        READ TABLE lt_app WITH TABLE KEY app = lv_app ASSIGNING FIELD-SYMBOL(<app>).
        IF sy-subrc <> 0.
          INSERT VALUE #( app = lv_app ) INTO TABLE lt_app ASSIGNING <app>.
        ENDIF.
        <app>-drafts = <app>-drafts + 1.
        <app>-kb = <app>-kb + lv_len DIV 1024.
        IF lv_len DIV 1024 > <app>-kb_max.
          <app>-kb_max = lv_len DIV 1024.
        ENDIF.
        result-rows_analyzed = result-rows_analyzed + 1.
        lv_last = ls_row-id.
      ENDLOOP.

      IF result-rows_analyzed >= max_rows.
        result-check_partial = abap_true.
        EXIT.
      ENDIF.
    ENDDO.

    result-kb_total = lv_bytes_total / 1024.
    LOOP AT lt_app ASSIGNING <app>.
      IF <app>-drafts > 0.
        <app>-kb_avg = <app>-kb / <app>-drafts.
      ENDIF.
    ENDLOOP.
    result-t_app = lt_app.
    SORT result-t_app BY kb DESCENDING.

  ENDMETHOD.

  METHOD app_of_draft.

    " asXML writes every object of the graph as an element in the namespace
    " of global classes - <x:CLASSNAME xmlns:x="...classes/global" id="o2">.
    " The framework's own container comes first; the app is the first class
    " that is not the framework's.
    CONSTANTS lc_marker TYPE string VALUE `/classes/global"`.
    DATA lv_offset TYPE i.

    DO 20 TIMES.
      DATA(lv_rest) = substring( val = data
                                 off = lv_offset ).
      DATA(lv_hit) = find( val = lv_rest
                           sub = lc_marker ).
      IF lv_hit < 0.
        RETURN.
      ENDIF.
      DATA(lv_head) = substring( val = lv_rest
                                 len = lv_hit ).
      lv_offset = lv_offset + lv_hit + strlen( lc_marker ).

      DATA(lv_open) = find( val  = lv_head
                            sub  = `<`
                            occ  = -1 ).
      IF lv_open < 0.
        CONTINUE.
      ENDIF.
      DATA(lv_tag) = substring( val = lv_head
                                off = lv_open + 1 ).
      lv_tag = substring_before( val = lv_tag
                                 sub = ` ` ).
      IF lv_tag CS `:`.
        lv_tag = substring_after( val = lv_tag
                                  sub = `:` ).
      ENDIF.
      " a namespace slash is written as _- in an XML name
      REPLACE ALL OCCURRENCES OF `_-` IN lv_tag WITH `/`.
      lv_tag = to_upper( lv_tag ).

      IF lv_tag IS INITIAL
          OR lv_tag CP `Z2UI5_CL_UI5_*`
          OR lv_tag CP `Z2UI5_CL_SRT_*`
          OR lv_tag CP `Z2UI5_CL_AJSON*`.
        CONTINUE.
      ENDIF.
      result = lv_tag.
      RETURN.
    ENDDO.

  ENDMETHOD.

  METHOD delete_expired.

    DATA lv_tab TYPE string.
    DATA(lv_cutoff) = cutoff( ).
    DATA(lv_before) = count_rows( lv_cutoff ).

    DATA lo_store TYPE REF TO object.
    TRY.
        CALL METHOD (`Z2UI5_CL_UI5_SRV_DRAFT`)=>(`GET_INSTANCE`)
          RECEIVING
            result = lo_store.
        CALL METHOD lo_store->(`Z2UI5_IF_UI5_DRAFT_STORE~CLEANUP`).
      CATCH cx_root.
        " the framework's store is not reachable under that name - delete
        " directly, with the same cutoff
        lv_tab = c_table.
        DELETE FROM (lv_tab) WHERE timestampl < @lv_cutoff.
        COMMIT WORK.
    ENDTRY.

    result = lv_before - count_rows( lv_cutoff ).
    IF result < 0.
      result = 0.
    ENDIF.

  ENDMETHOD.

  METHOD get_expiry_hours.

    result = z2ui5_cl_cockpit_inst=>get_config_post( )-draft_exp_time_in_hours.
    IF result <= 0.
      result = 4.
    ENDIF.

  ENDMETHOD.

  METHOD count_rows.

    DATA lv_tab TYPE string.
    lv_tab = c_table.
    IF before IS SUPPLIED.
      SELECT COUNT( * ) FROM (lv_tab)
        WHERE timestampl < @before
        INTO @result.
    ELSE.
      SELECT COUNT( * ) FROM (lv_tab)
        INTO @result.                                   "#EC CI_NOWHERE
    ENDIF.

  ENDMETHOD.

  METHOD cutoff.

    result = z2ui5_cl_cockpit_setup=>now_minus_seconds( get_expiry_hours( ) * 3600 ).

  ENDMETHOD.

ENDCLASS.
