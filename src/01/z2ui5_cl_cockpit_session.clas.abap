"! <p class="shorttext synchronized">admin cockpit - sessions</p>
"!
"! What a user did, roundtrip by roundtrip, read from the draft table.
"!
"! Every POST roundtrip of abap2UI5 writes the app as it is afterwards into
"! a new draft, and names the draft it started from in ID_PREV - across app
"! navigations too. Followed backwards, the drafts of one browser session
"! form a chain: the session. A step is one draft, its fields are the
"! attributes of the app in the serialized object graph, and the change of a
"! step is what differs from the step before - the values the user typed,
"! the state the event changed.
"!
"! The draft table is a framework internal (see z2ui5_cl_cockpit_draft): it
"! is only named in a literal and read with dynamic SQL. The serialized state
"! is read as text and taken apart here, no class of it is loaded - an app
"! class that does not activate any more cannot break the cockpit.
"!
"! Drafts hold business data of other users. The app shows them to
"! administrators only and writes every opened session to the change log.
CLASS z2ui5_cl_cockpit_session DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    " the most draft rows one session list reads, newest first
    CONSTANTS c_max_nodes  TYPE i VALUE 50000.
    " the most steps a session shows - the newest ones
    CONSTANTS c_max_steps  TYPE i VALUE 500.
    " the most fields a step shows
    CONSTANTS c_max_fields TYPE i VALUE 1000.
    " a longer value is shown cut, with its length
    CONSTANTS c_max_value  TYPE i VALUE 300.

    CONSTANTS:
      BEGIN OF cs_change,
        new     TYPE string VALUE `new`,
        changed TYPE string VALUE `changed`,
        removed TYPE string VALUE `removed`,
      END OF cs_change.

    TYPES:
      "! A row of the draft table without its content.
      BEGIN OF ty_s_node,
        id         TYPE c LENGTH 32,
        id_prev    TYPE c LENGTH 32,
        uname      TYPE c LENGTH 32,
        timestampl TYPE timestampl,
      END OF ty_s_node.
    TYPES ty_t_node TYPE STANDARD TABLE OF ty_s_node WITH EMPTY KEY.

    TYPES:
      "! The session a draft belongs to: the first draft of its chain.
      BEGIN OF ty_s_root,
        id   TYPE c LENGTH 32,
        root TYPE c LENGTH 32,
      END OF ty_s_root.
    TYPES ty_t_root TYPE HASHED TABLE OF ty_s_root WITH UNIQUE KEY id.

    TYPES:
      BEGIN OF ty_s_session,
        " the first draft of the session - its key
        id        TYPE string,
        user      TYPE string,
        app       TYPE string,
        steps     TYPE i,
        first     TYPE string,
        last      TYPE string,
        duration  TYPE string,
        note      TYPE string,
      END OF ty_s_session.
    TYPES ty_t_session TYPE STANDARD TABLE OF ty_s_session WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_list,
        check_readable TYPE abap_bool,
        error          TYPE string,
        sessions       TYPE i,
        check_capped   TYPE abap_bool,
        t_session      TYPE ty_t_session,
      END OF ty_s_list.

    TYPES:
      BEGIN OF ty_s_step,
        step    TYPE i,
        id      TYPE string,
        time    TYPE string,
        delta   TYPE string,
        app     TYPE string,
        kb      TYPE i,
        " the step this one continues - the one before it, unless the
        " user went back in the browser or worked in a second window
        follows TYPE i,
        note    TYPE string,
        " the highlight of the row: Information for the step shown
        state   TYPE string,
      END OF ty_s_step.
    TYPES ty_t_step TYPE STANDARD TABLE OF ty_s_step WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_steps,
        error        TYPE string,
        check_capped TYPE abap_bool,
        t_step       TYPE ty_t_step,
      END OF ty_s_steps.

    TYPES:
      "! One field of a serialized app: its path and its value as text.
      BEGIN OF ty_s_value,
        path  TYPE string,
        value TYPE string,
      END OF ty_s_value.
    TYPES ty_t_value TYPE STANDARD TABLE OF ty_s_value WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_field,
        path   TYPE string,
        value  TYPE string,
        prev   TYPE string,
        change TYPE string,
        " the highlight of the row: Success new, Warning changed, Error
        " removed, None unchanged
        state  TYPE string,
      END OF ty_s_field.
    TYPES ty_t_field TYPE STANDARD TABLE OF ty_s_field WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_view,
        error        TYPE string,
        app          TYPE string,
        fields       TYPE i,
        changes      TYPE i,
        shown        TYPE i,
        check_capped TYPE abap_bool,
        t_field      TYPE ty_t_field,
      END OF ty_s_view.

    "! The sessions in the draft table, newest activity first. Never
    "! raises - check_readable / error say whether the table could be read.
    "! @parameter max_sessions | the most sessions listed
    "! @parameter search       | only sessions whose app or user contains it
    CLASS-METHODS get_sessions
      IMPORTING
        max_sessions  TYPE i DEFAULT 100
        search        TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_list.

    "! The steps of a session, oldest first. Never raises.
    "! @parameter id | the session - its first draft
    CLASS-METHODS get_steps
      IMPORTING
        id            TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_steps.

    "! The session a draft belongs to, empty when the draft is gone.
    CLASS-METHODS get_session_of
      IMPORTING
        draft_id      TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    "! The fields of a step and what changed since the step before. Never
    "! raises - error says why the step could not be read.
    "! @parameter id            | the draft of the step
    "! @parameter id_prev       | the draft of the step before, empty for the first
    "! @parameter check_all     | also the objects of the framework itself
    "! @parameter check_changes | only the fields that changed
    "! @parameter search        | only the fields whose path or value contains it
    CLASS-METHODS get_view
      IMPORTING
        id            TYPE clike
        id_prev       TYPE clike OPTIONAL
        check_all     TYPE abap_bool DEFAULT abap_false
        check_changes TYPE abap_bool DEFAULT abap_false
        search        TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_view.

    "! The session of every draft - the first draft of its chain. A chain
    "! ends at a draft without predecessor or whose predecessor is gone.
    CLASS-METHODS roots_of
      IMPORTING
        it_node       TYPE ty_t_node
      RETURNING
        VALUE(result) TYPE ty_t_root.

    "! The steps of one session, oldest first, without app and size.
    CLASS-METHODS steps_of
      IMPORTING
        it_node       TYPE ty_t_node
        it_root       TYPE ty_t_root
        id            TYPE clike
      RETURNING
        VALUE(result) TYPE ty_t_step.

    "! The fields of a serialized draft (asXML of CALL TRANSFORMATION id):
    "! every leaf of the object graph as path and value, a reference as an
    "! arrow to the class it points to. Without check_all only the objects
    "! that are not the framework's and the data they reference.
    CLASS-METHODS flatten
      IMPORTING
        xml           TYPE string
        check_all     TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE ty_t_value.

    "! The fields of a step compared with the step before - new, changed,
    "! removed. check_first marks nothing.
    CLASS-METHODS diff
      IMPORTING
        it_new        TYPE ty_t_value
        it_old        TYPE ty_t_value OPTIONAL
        check_first   TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE ty_t_field.

    "! The app of a serialized draft: the first object of the heap that is
    "! not the framework's. Reads only the heap entries - an object is the
    "! one element with an id starting with o - wherever the document
    "! declares its namespaces.
    CLASS-METHODS app_of
      IMPORTING
        xml           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! Text of an XML text node or attribute with its entities resolved.
    CLASS-METHODS decode
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! Seconds from one timestamp to a later one, whole seconds.
    CLASS-METHODS seconds_between
      IMPORTING
        ts_from       TYPE timestampl
        ts_to         TYPE timestampl
      RETURNING
        VALUE(result) TYPE i.

  PROTECTED SECTION.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_s_entry,
        id    TYPE string,
        label TYPE string,
        " an object (id o...), not data (id d...)
        check_object TYPE abap_bool,
      END OF ty_s_entry.
    TYPES ty_t_entry TYPE HASHED TABLE OF ty_s_entry WITH UNIQUE KEY id.

    TYPES:
      BEGIN OF ty_s_leaf,
        path  TYPE string,
        value TYPE string,
        " the heap entry the field belongs to, and the one it references
        root  TYPE string,
        href  TYPE string,
      END OF ty_s_leaf.
    TYPES ty_t_leaf TYPE STANDARD TABLE OF ty_s_leaf WITH EMPTY KEY.

    CLASS-METHODS read_nodes
      RETURNING
        VALUE(result) TYPE ty_t_node
      RAISING
        cx_static_check.

    "! The serialized state of a draft, empty when it is gone.
    CLASS-METHODS read_data
      IMPORTING
        id            TYPE clike
      RETURNING
        VALUE(result) TYPE string
      RAISING
        cx_static_check.

    CLASS-METHODS fill_steps
      CHANGING
        ct_step TYPE ty_t_step
      RAISING
        cx_static_check.

    CLASS-METHODS user_text
      IMPORTING
        uname         TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS duration_text
      IMPORTING
        seconds       TYPE i
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS attribute
      IMPORTING
        attributes    TYPE string
        name          TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS check_framework
      IMPORTING
        label         TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS cut
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS z2ui5_cl_cockpit_session IMPLEMENTATION.

  METHOD get_sessions.

    TYPES:
      BEGIN OF ty_s_agg,
        root    TYPE c LENGTH 32,
        id_prev TYPE c LENGTH 32,
        uname   TYPE c LENGTH 32,
        steps   TYPE i,
        first   TYPE timestampl,
        last    TYPE timestampl,
        last_id TYPE c LENGTH 32,
      END OF ty_s_agg.
    DATA lt_agg TYPE HASHED TABLE OF ty_s_agg WITH UNIQUE KEY root.
    DATA lt_sorted TYPE STANDARD TABLE OF ty_s_agg WITH EMPTY KEY.
    DATA lt_node TYPE ty_t_node.

    TRY.
        lt_node = read_nodes( ).
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.
    result-check_readable = abap_true.
    result-check_capped = xsdbool( lines( lt_node ) >= c_max_nodes ).

    DATA(lt_root) = roots_of( lt_node ).
    LOOP AT lt_node INTO DATA(ls_node).
      READ TABLE lt_root INTO DATA(ls_root) WITH TABLE KEY id = ls_node-id.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_agg ASSIGNING FIELD-SYMBOL(<agg>) WITH TABLE KEY root = ls_root-root.
      IF sy-subrc <> 0.
        INSERT VALUE #( root  = ls_root-root
                        first = ls_node-timestampl
                        last  = ls_node-timestampl ) INTO TABLE lt_agg ASSIGNING <agg>.
      ENDIF.
      <agg>-steps = <agg>-steps + 1.
      IF ls_node-id = ls_root-root.
        <agg>-id_prev = ls_node-id_prev.
        <agg>-uname   = ls_node-uname.
      ENDIF.
      IF ls_node-timestampl <= <agg>-first.
        <agg>-first = ls_node-timestampl.
      ENDIF.
      IF ls_node-timestampl >= <agg>-last.
        <agg>-last    = ls_node-timestampl.
        <agg>-last_id = ls_node-id.
      ENDIF.
    ENDLOOP.

    lt_sorted = lt_agg.
    SORT lt_sorted BY last DESCENDING root ASCENDING.
    result-sessions = lines( lt_sorted ).

    " the app of a session is in its newest draft - read for as many
    " sessions as are listed, and a few more when a filter skips some
    DATA(lv_reads) = 0.
    LOOP AT lt_sorted INTO DATA(ls_agg).
      IF lines( result-t_session ) >= max_sessions OR lv_reads >= max_sessions * 3.
        EXIT.
      ENDIF.
      lv_reads = lv_reads + 1.

      DATA(ls_session) = VALUE ty_s_session( id       = ls_agg-root
                                             user     = user_text( ls_agg-uname )
                                             steps    = ls_agg-steps
                                             first    = z2ui5_cl_cockpit_setup=>ts_text( ls_agg-first )
                                             last     = z2ui5_cl_cockpit_setup=>ts_text( ls_agg-last )
                                             duration = duration_text( seconds_between( ts_from = ls_agg-first
                                                                                        ts_to   = ls_agg-last ) ) ).
      TRY.
          ls_session-app = app_of( read_data( ls_agg-last_id ) ).
        CATCH cx_root ##NO_HANDLER.
          " gone since the list was read - the app stays empty
      ENDTRY.
      IF ls_session-app IS INITIAL.
        ls_session-app = `(unknown)`.
      ENDIF.
      IF ls_agg-id_prev IS NOT INITIAL.
        ls_session-note = `earlier steps expired`.
      ENDIF.

      IF search IS NOT INITIAL
          AND NOT ( ls_session-app CS search OR ls_session-user CS search ).
        CONTINUE.
      ENDIF.
      APPEND ls_session TO result-t_session.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_steps.

    DATA lt_node TYPE ty_t_node.

    TRY.
        lt_node = read_nodes( ).
        result-t_step = steps_of( it_node = lt_node
                                  it_root = roots_of( lt_node )
                                  id      = id ).
        DATA(lv_over) = lines( result-t_step ) - c_max_steps.
        IF lv_over > 0.
          result-check_capped = abap_true.
          DELETE result-t_step TO lv_over.
        ENDIF.
        fill_steps( CHANGING ct_step = result-t_step ).
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
    ENDTRY.

  ENDMETHOD.

  METHOD get_session_of.

    DATA lt_node TYPE ty_t_node.

    TRY.
        lt_node = read_nodes( ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
    DATA(lt_root) = roots_of( lt_node ).
    DATA(lv_id) = CONV ty_s_root-id( draft_id ).
    READ TABLE lt_root INTO DATA(ls_root) WITH TABLE KEY id = lv_id.
    IF sy-subrc = 0.
      result = ls_root-root.
    ENDIF.

  ENDMETHOD.

  METHOD get_view.

    DATA lv_new TYPE string.
    DATA lv_old TYPE string.
    DATA lt_old TYPE ty_t_value.

    TRY.
        lv_new = read_data( id ).
        IF id_prev IS NOT INITIAL.
          lv_old = read_data( id_prev ).
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.
    IF lv_new IS INITIAL.
      result-error = `The draft of this step is gone - expired and deleted since the session was opened.`.
      RETURN.
    ENDIF.

    result-app = app_of( lv_new ).
    DATA(lt_new) = flatten( xml       = lv_new
                            check_all = check_all ).
    IF id_prev IS NOT INITIAL.
      lt_old = flatten( xml       = lv_old
                        check_all = check_all ).
    ENDIF.
    DATA(lt_field) = diff( it_new      = lt_new
                           it_old      = lt_old
                           check_first = xsdbool( id_prev IS INITIAL ) ).

    result-fields = lines( lt_field ).
    LOOP AT lt_field INTO DATA(ls_field).
      IF ls_field-change IS NOT INITIAL.
        result-changes = result-changes + 1.
      ELSEIF check_changes = abap_true.
        CONTINUE.
      ENDIF.
      IF search IS NOT INITIAL
          AND NOT ( ls_field-path CS search OR ls_field-value CS search OR ls_field-prev CS search ).
        CONTINUE.
      ENDIF.
      result-shown = result-shown + 1.
      IF lines( result-t_field ) >= c_max_fields.
        result-check_capped = abap_true.
        CONTINUE.
      ENDIF.
      ls_field-value = cut( ls_field-value ).
      ls_field-prev  = cut( ls_field-prev ).
      APPEND ls_field TO result-t_field.
    ENDLOOP.

  ENDMETHOD.

  METHOD roots_of.

    TYPES:
      BEGIN OF ty_s_link,
        id   TYPE c LENGTH 32,
        prev TYPE c LENGTH 32,
      END OF ty_s_link.
    TYPES ty_id TYPE c LENGTH 32.
    DATA lt_link TYPE HASHED TABLE OF ty_s_link WITH UNIQUE KEY id.
    DATA lt_path TYPE HASHED TABLE OF ty_id WITH UNIQUE KEY table_line.
    DATA lv_cur TYPE ty_id.
    DATA lv_root TYPE ty_id.

    LOOP AT it_node INTO DATA(ls_node).
      INSERT VALUE #( id   = ls_node-id
                      prev = ls_node-id_prev ) INTO TABLE lt_link.
    ENDLOOP.

    LOOP AT it_node INTO ls_node.
      IF line_exists( result[ id = ls_node-id ] ).
        CONTINUE.
      ENDIF.

      CLEAR lt_path.
      CLEAR lv_root.
      lv_cur = ls_node-id.
      DO.
        READ TABLE result INTO DATA(ls_known) WITH TABLE KEY id = lv_cur.
        IF sy-subrc = 0.
          lv_root = ls_known-root.
          EXIT.
        ENDIF.
        INSERT lv_cur INTO TABLE lt_path.
        READ TABLE lt_link INTO DATA(ls_link) WITH TABLE KEY id = lv_cur.
        IF sy-subrc <> 0 OR ls_link-prev IS INITIAL.
          lv_root = lv_cur.
          EXIT.
        ENDIF.
        IF NOT line_exists( lt_link[ id = ls_link-prev ] ).
          " the predecessor expired - the session starts here now
          lv_root = lv_cur.
          EXIT.
        ENDIF.
        IF line_exists( lt_path[ table_line = ls_link-prev ] ).
          " a cycle no framework writes - end it where it closes
          lv_root = lv_cur.
          EXIT.
        ENDIF.
        lv_cur = ls_link-prev.
      ENDDO.

      LOOP AT lt_path INTO DATA(lv_id).
        INSERT VALUE #( id   = lv_id
                        root = lv_root ) INTO TABLE result.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD steps_of.

    TYPES:
      BEGIN OF ty_s_index,
        id   TYPE c LENGTH 32,
        step TYPE i,
      END OF ty_s_index.
    DATA lt_index TYPE HASHED TABLE OF ty_s_index WITH UNIQUE KEY id.
    DATA lt_mine TYPE ty_t_node.
    DATA lv_last TYPE timestampl.

    DATA(lv_root) = CONV ty_s_root-root( id ).
    LOOP AT it_node INTO DATA(ls_node).
      READ TABLE it_root INTO DATA(ls_root) WITH TABLE KEY id = ls_node-id.
      IF sy-subrc = 0 AND ls_root-root = lv_root.
        APPEND ls_node TO lt_mine.
      ENDIF.
    ENDLOOP.
    SORT lt_mine BY timestampl ASCENDING id ASCENDING.

    LOOP AT lt_mine INTO ls_node.
      DATA(ls_step) = VALUE ty_s_step( step  = sy-tabix
                                       id    = ls_node-id
                                       time  = z2ui5_cl_cockpit_setup=>ts_text( ls_node-timestampl )
                                       state = `None` ).
      INSERT VALUE #( id   = ls_node-id
                      step = ls_step-step ) INTO TABLE lt_index.

      IF ls_step-step > 1.
        ls_step-delta = |+{ duration_text( seconds_between( ts_from = lv_last
                                                            ts_to   = ls_node-timestampl ) ) }|.
      ENDIF.
      lv_last = ls_node-timestampl.

      READ TABLE lt_index INTO DATA(ls_index) WITH TABLE KEY id = ls_node-id_prev.
      IF sy-subrc = 0.
        ls_step-follows = ls_index-step.
        IF ls_step-follows <> ls_step-step - 1.
          ls_step-note = |continues step { ls_step-follows } (browser back or a second window)|.
        ENDIF.
      ELSEIF ls_node-id_prev IS NOT INITIAL.
        ls_step-note = `the steps before it expired`.
      ELSE.
        ls_step-note = `app start`.
      ENDIF.
      APPEND ls_step TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD fill_steps.

    TYPES ty_id TYPE c LENGTH 32.
    TYPES ty_r_id TYPE RANGE OF ty_id.
    TYPES:
      BEGIN OF ty_s_row,
        id   TYPE c LENGTH 32,
        data TYPE string,
      END OF ty_s_row.
    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    DATA lt_range TYPE ty_r_id.
    DATA lv_tab TYPE string.
    DATA lv_app TYPE string.
    DATA lv_done TYPE i.

    lv_tab = z2ui5_cl_cockpit_draft=>c_table.
    LOOP AT ct_step INTO DATA(ls_step).
      lv_done = lv_done + 1.
      APPEND VALUE #( sign   = `I`
                      option = `EQ`
                      low    = ls_step-id ) TO lt_range.
      IF lines( lt_range ) < 50 AND lv_done < lines( ct_step ).
        CONTINUE.
      ENDIF.

      CLEAR lt_rows.
      SELECT id, data FROM (lv_tab)
        WHERE id IN @lt_range
        INTO CORRESPONDING FIELDS OF TABLE @lt_rows.
      CLEAR lt_range.

      LOOP AT lt_rows INTO DATA(ls_row).
        READ TABLE ct_step ASSIGNING FIELD-SYMBOL(<step>) WITH KEY id = ls_row-id. "#EC CI_SORTSEQ
        IF sy-subrc = 0.
          <step>-app = app_of( ls_row-data ).
          <step>-kb  = ( strlen( ls_row-data ) + 1023 ) DIV 1024.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    LOOP AT ct_step ASSIGNING <step>.
      IF <step>-step > 1 AND <step>-app <> lv_app AND <step>-app IS NOT INITIAL.
        <step>-note = |{ <step>-note }{ COND #( WHEN <step>-note IS NOT INITIAL THEN `, ` ) }| &&
                      |navigated to { <step>-app }|.
      ENDIF.
      IF <step>-app IS NOT INITIAL.
        lv_app = <step>-app.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD flatten.

    TYPES:
      BEGIN OF ty_s_open,
        name     TYPE string,
        " S structure of the document, V the root values, E an entry of
        " the heap, P a class part of an object, N a node below them
        kind     TYPE c LENGTH 1,
        path     TYPE string,
        root     TYPE string,
        children TYPE abap_bool,
        items    TYPE i,
        href     TYPE string,
        text     TYPE string,
      END OF ty_s_open.
    TYPES:
      BEGIN OF ty_s_count,
        label TYPE string,
        count TYPE i,
      END OF ty_s_count.
    DATA lt_stack TYPE STANDARD TABLE OF ty_s_open WITH EMPTY KEY.
    DATA lt_count TYPE HASHED TABLE OF ty_s_count WITH UNIQUE KEY label.
    DATA lt_entry TYPE ty_t_entry.
    DATA lt_leaf TYPE ty_t_leaf.
    DATA lt_visible TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA ls_open TYPE ty_s_open.
    DATA lv_pos TYPE i.
    DATA lv_attributes TYPE string.
    DATA lv_close TYPE abap_bool.
    DATA lv_self TYPE abap_bool.
    FIELD-SYMBOLS <top> TYPE ty_s_open.
    FIELD-SYMBOLS <parent> TYPE ty_s_open.

    DATA(lv_len) = strlen( xml ).
    WHILE lv_pos < lv_len.

      DATA(lv_lt) = find( val = xml
                          sub = `<`
                          off = lv_pos ).
      IF lv_lt < 0.
        EXIT.
      ENDIF.
      IF lv_lt > lv_pos AND lt_stack IS NOT INITIAL.
        ASSIGN lt_stack[ lines( lt_stack ) ] TO <top>.
        <top>-text = <top>-text && substring( val = xml
                                              off = lv_pos
                                              len = lv_lt - lv_pos ).
      ENDIF.
      DATA(lv_gt) = find( val = xml
                          sub = `>`
                          off = lv_lt ).
      IF lv_gt < 0.
        EXIT.
      ENDIF.
      DATA(lv_tag) = substring( val = xml
                                off = lv_lt + 1
                                len = lv_gt - lv_lt - 1 ).
      lv_pos = lv_gt + 1.
      IF lv_tag IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_first) = substring( val = lv_tag
                                  len = 1 ).
      IF lv_first = `?` OR lv_first = `!`.
        CONTINUE.
      ENDIF.

      lv_close = xsdbool( lv_first = `/` ).
      lv_self = abap_false.
      IF lv_close = abap_false.
        IF substring( val = lv_tag
                      off = strlen( lv_tag ) - 1 ) = `/`.
          lv_self = abap_true.
          lv_tag = substring( val = lv_tag
                              len = strlen( lv_tag ) - 1 ).
        ENDIF.

        CLEAR ls_open.
        CLEAR lv_attributes.
        DATA(lv_blank) = find( val = lv_tag
                               sub = ` ` ).
        IF lv_blank >= 0.
          ls_open-name = substring( val = lv_tag
                                    len = lv_blank ).
          lv_attributes = substring( val = lv_tag
                                     off = lv_blank ).
        ELSE.
          ls_open-name = lv_tag.
        ENDIF.
        ls_open-href = attribute( attributes = lv_attributes
                                  name       = `href` ).
        IF ls_open-href IS NOT INITIAL.
          IF substring( val = ls_open-href
                        len = 1 ) = `#`.
            ls_open-href = substring( val = ls_open-href
                                      off = 1 ).
          ENDIF.
        ENDIF.

        UNASSIGN <parent>.
        IF lt_stack IS NOT INITIAL.
          ASSIGN lt_stack[ lines( lt_stack ) ] TO <parent>.
        ENDIF.

        IF ls_open-name = `asx:abap` OR ls_open-name = `asx:values` OR ls_open-name = `asx:heap`.
          ls_open-kind = `S`.
        ELSEIF <parent> IS NOT ASSIGNED.
          ls_open-kind = `N`.
          ls_open-path = ls_open-name.
        ELSEIF <parent>-kind = `V` OR ( <parent>-kind = `S` AND <parent>-name = `asx:values` ).
          " the references of the document root - the heap holds the rest
          ls_open-kind = `V`.
        ELSEIF <parent>-kind = `S` AND <parent>-name = `asx:heap`.
          ls_open-kind = `E`.
          DATA(lv_id) = attribute( attributes = lv_attributes
                                   name       = `id` ).
          DATA(lv_label) = ls_open-name.
          IF lv_label CS `:`.
            lv_label = substring_after( val = lv_label
                                        sub = `:` ).
          ENDIF.
          REPLACE ALL OCCURRENCES OF `_-` IN lv_label WITH `/`.
          READ TABLE lt_count ASSIGNING FIELD-SYMBOL(<count>) WITH TABLE KEY label = lv_label.
          IF sy-subrc <> 0.
            INSERT VALUE #( label = lv_label ) INTO TABLE lt_count ASSIGNING <count>.
          ENDIF.
          <count>-count = <count>-count + 1.
          IF <count>-count > 1.
            lv_label = |{ lv_label }#{ <count>-count }|.
          ENDIF.
          ls_open-path = lv_label.
          ls_open-root = lv_id.
          INSERT VALUE #( id           = lv_id
                          label        = lv_label
                          check_object = xsdbool( lv_id CP `o*` ) ) INTO TABLE lt_entry.
        ELSEIF <parent>-kind = `E` AND <parent>-root CP `o*`.
          " a class part of an object: its attributes belong to the object
          ls_open-kind = `P`.
          ls_open-path = <parent>-path.
          ls_open-root = <parent>-root.
        ELSE.
          ls_open-kind = `N`.
          ls_open-root = <parent>-root.
          IF ls_open-name = `item`.
            <parent>-items = <parent>-items + 1.
            ls_open-path = |{ <parent>-path }[{ <parent>-items }]|.
          ELSE.
            DATA(lv_name) = ls_open-name.
            REPLACE ALL OCCURRENCES OF `_-` IN lv_name WITH `/`.
            ls_open-path = |{ <parent>-path }-{ lv_name }|.
          ENDIF.
        ENDIF.
        IF <parent> IS ASSIGNED.
          <parent>-children = abap_true.
        ENDIF.
        APPEND ls_open TO lt_stack.
      ENDIF.

      IF lv_close = abap_true OR lv_self = abap_true.
        IF lt_stack IS INITIAL.
          CONTINUE.
        ENDIF.
        DATA(lv_top) = lines( lt_stack ).
        ASSIGN lt_stack[ lv_top ] TO <top>.
        IF ( <top>-kind = `N` OR ( <top>-kind = `E` AND <top>-root NP `o*` ) )
            AND <top>-children = abap_false.
          APPEND VALUE #( path  = <top>-path
                          value = COND #( WHEN <top>-href IS INITIAL THEN decode( <top>-text ) )
                          root  = <top>-root
                          href  = <top>-href ) TO lt_leaf.
        ENDIF.
        DELETE lt_stack INDEX lv_top.
      ENDIF.

    ENDWHILE.

    IF check_all = abap_true.
      LOOP AT lt_entry INTO DATA(ls_entry).
        INSERT ls_entry-id INTO TABLE lt_visible.
      ENDLOOP.
    ELSE.
      " the objects of the app, and what they reference - the framework's
      " own objects and the data only they reference stay out
      LOOP AT lt_entry INTO ls_entry WHERE check_object = abap_true. "#EC CI_SORTSEQ
        IF check_framework( ls_entry-label ) = abap_false.
          INSERT ls_entry-id INTO TABLE lt_visible.
        ENDIF.
      ENDLOOP.
      DO.
        DATA(lv_added) = abap_false.
        LOOP AT lt_leaf INTO DATA(ls_leaf) WHERE href IS NOT INITIAL. "#EC CI_SORTSEQ
          IF NOT line_exists( lt_visible[ table_line = ls_leaf-root ] ).
            CONTINUE.
          ENDIF.
          READ TABLE lt_entry INTO ls_entry WITH TABLE KEY id = ls_leaf-href.
          IF sy-subrc <> 0 OR check_framework( ls_entry-label ) = abap_true.
            CONTINUE.
          ENDIF.
          INSERT ls_entry-id INTO TABLE lt_visible.
          IF sy-subrc = 0.
            lv_added = abap_true.
          ENDIF.
        ENDLOOP.
        IF lv_added = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
    ENDIF.

    LOOP AT lt_leaf INTO ls_leaf.
      IF ls_leaf-root IS NOT INITIAL.
        IF NOT line_exists( lt_visible[ table_line = ls_leaf-root ] ).
          CONTINUE.
        ENDIF.
      ENDIF.
      IF ls_leaf-href IS NOT INITIAL.
        READ TABLE lt_entry INTO ls_entry WITH TABLE KEY id = ls_leaf-href.
        ls_leaf-value = COND #( WHEN sy-subrc = 0 THEN |-> { ls_entry-label }|
                                ELSE |-> #{ ls_leaf-href }| ).
      ENDIF.
      APPEND VALUE #( path  = ls_leaf-path
                      value = ls_leaf-value ) TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD diff.

    DATA lt_old TYPE HASHED TABLE OF ty_s_value WITH UNIQUE KEY path.
    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT it_old INTO DATA(ls_old).
      INSERT ls_old INTO TABLE lt_old.
    ENDLOOP.

    LOOP AT it_new INTO DATA(ls_new).
      INSERT ls_new-path INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(ls_field) = VALUE ty_s_field( path  = ls_new-path
                                         value = ls_new-value
                                         state = `None` ).
      IF check_first = abap_false.
        READ TABLE lt_old INTO ls_old WITH TABLE KEY path = ls_new-path.
        IF sy-subrc <> 0.
          ls_field-change = cs_change-new.
          ls_field-state  = `Success`.
        ELSEIF ls_old-value <> ls_new-value.
          ls_field-change = cs_change-changed.
          ls_field-prev   = ls_old-value.
          ls_field-state  = `Warning`.
        ENDIF.
      ENDIF.
      APPEND ls_field TO result.
    ENDLOOP.

    IF check_first = abap_true.
      RETURN.
    ENDIF.
    LOOP AT it_old INTO ls_old.
      INSERT ls_old-path INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( path   = ls_old-path
                      prev   = ls_old-value
                      change = cs_change-removed
                      state  = `Error` ) TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD app_of.

    DATA lv_pos TYPE i.

    DO.
      DATA(lv_hit) = find( val = xml
                           sub = ` id="o`
                           off = lv_pos ).
      IF lv_hit < 0.
        RETURN.
      ENDIF.
      lv_pos = lv_hit + 1.
      DATA(lv_open) = find( val = substring( val = xml
                                             len = lv_hit )
                            sub = `<`
                            occ = -1 ).
      IF lv_open < 0.
        CONTINUE.
      ENDIF.
      DATA(lv_name) = substring( val = xml
                                 off = lv_open + 1
                                 len = lv_hit - lv_open - 1 ).
      IF lv_name CS ` `.
        lv_name = substring_before( val = lv_name
                                    sub = ` ` ).
      ENDIF.
      IF lv_name CS `:`.
        lv_name = substring_after( val = lv_name
                                   sub = `:` ).
      ENDIF.
      REPLACE ALL OCCURRENCES OF `_-` IN lv_name WITH `/`.
      lv_name = to_upper( lv_name ).
      IF lv_name IS NOT INITIAL AND check_framework( lv_name ) = abap_false.
        result = lv_name.
        RETURN.
      ENDIF.
    ENDDO.

  ENDMETHOD.

  METHOD decode.

    result = val.
    IF result NS `&`.
      RETURN.
    ENDIF.
    REPLACE ALL OCCURRENCES OF `&lt;` IN result WITH `<`.
    REPLACE ALL OCCURRENCES OF `&gt;` IN result WITH `>`.
    REPLACE ALL OCCURRENCES OF `&quot;` IN result WITH `"`.
    REPLACE ALL OCCURRENCES OF `&apos;` IN result WITH `'`.
    " a line break is shown as one, whether written as CR LF or LF alone
    REPLACE ALL OCCURRENCES OF `&#xD;&#xA;` IN result WITH cl_abap_char_utilities=>newline.
    REPLACE ALL OCCURRENCES OF `&#13;&#10;` IN result WITH cl_abap_char_utilities=>newline.
    REPLACE ALL OCCURRENCES OF `&#xD;` IN result WITH cl_abap_char_utilities=>newline.
    REPLACE ALL OCCURRENCES OF `&#13;` IN result WITH cl_abap_char_utilities=>newline.
    REPLACE ALL OCCURRENCES OF `&#xA;` IN result WITH cl_abap_char_utilities=>newline.
    REPLACE ALL OCCURRENCES OF `&#x9;` IN result WITH cl_abap_char_utilities=>horizontal_tab.
    REPLACE ALL OCCURRENCES OF `&#10;` IN result WITH cl_abap_char_utilities=>newline.
    REPLACE ALL OCCURRENCES OF `&#9;` IN result WITH cl_abap_char_utilities=>horizontal_tab.
    " last, so an escaped entity stays what it was: &amp;lt; is &lt;
    REPLACE ALL OCCURRENCES OF `&amp;` IN result WITH `&`.

  ENDMETHOD.

  METHOD seconds_between.

    DATA lv_date_from TYPE d.
    DATA lv_time_from TYPE t.
    DATA lv_date_to TYPE d.
    DATA lv_time_to TYPE t.
    DATA lv_secs_from TYPE i.
    DATA lv_secs_to TYPE i.

    " by hand, not with cl_abap_tstmp - see z2ui5_cl_cockpit_setup=>ts_minus_seconds.
    " The seconds of the day from hours, minutes and seconds: a time assigned
    " to an integer is its seconds on a system, but hhmmss on the transpiled
    " runtime the unit tests run on
    CONVERT TIME STAMP ts_from TIME ZONE `UTC` INTO DATE lv_date_from TIME lv_time_from.
    CONVERT TIME STAMP ts_to TIME ZONE `UTC` INTO DATE lv_date_to TIME lv_time_to.
    lv_secs_from = lv_time_from(2) * 3600 + lv_time_from+2(2) * 60 + lv_time_from+4(2).
    lv_secs_to = lv_time_to(2) * 3600 + lv_time_to+2(2) * 60 + lv_time_to+4(2).
    result = ( lv_date_to - lv_date_from ) * 86400 + lv_secs_to - lv_secs_from.

  ENDMETHOD.

  METHOD read_nodes.

    DATA lv_tab TYPE string.
    lv_tab = z2ui5_cl_cockpit_draft=>c_table.
    SELECT id, id_prev, uname, timestampl FROM (lv_tab)
      ORDER BY timestampl DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @result
      UP TO @c_max_nodes ROWS.                        "#EC CI_NOWHERE

  ENDMETHOD.

  METHOD read_data.

    DATA lv_tab TYPE string.
    DATA lv_id TYPE c LENGTH 32.
    lv_tab = z2ui5_cl_cockpit_draft=>c_table.
    lv_id = id.
    SELECT SINGLE data FROM (lv_tab)
      WHERE id = @lv_id
      INTO @result.
    IF sy-subrc <> 0.
      CLEAR result.
    ENDIF.

  ENDMETHOD.

  METHOD user_text.

    IF z2ui5_cl_cockpit_setup=>check_privacy( ) = abap_false.
      result = uname.
      RETURN.
    ENDIF.
    " the pseudonym of today - the one the Errors tab shows for today's
    " occurrences, so a session can be matched with an error
    DATA(lv_key) = z2ui5_cl_cockpit_setup=>user_key( uname = uname
                                                     day   = z2ui5_cl_cockpit_setup=>day_minus( 0 ) ).
    IF strlen( lv_key ) >= 8.
      result = |pseudonym { substring( val = lv_key
                                       len = 8 ) }|.
    ELSE.
      result = `not recorded`.
    ENDIF.

  ENDMETHOD.

  METHOD duration_text.

    IF seconds < 60.
      result = |{ seconds } s|.
    ELSEIF seconds < 3600.
      result = |{ seconds DIV 60 } min { seconds MOD 60 } s|.
    ELSE.
      result = |{ seconds DIV 3600 } h { ( seconds MOD 3600 ) DIV 60 } min|.
    ENDIF.

  ENDMETHOD.

  METHOD attribute.

    DATA(lv_off) = find( val = attributes
                         sub = | { name }="| ).
    IF lv_off < 0.
      RETURN.
    ENDIF.
    result = substring( val = attributes
                        off = lv_off + strlen( name ) + 3 ).
    IF result CS `"`.
      result = substring_before( val = result
                                 sub = `"` ).
    ENDIF.

  ENDMETHOD.

  METHOD check_framework.

    result = xsdbool( label CP `Z2UI5_CL_UI5_*`
                      OR label CP `Z2UI5_CL_SRT_*`
                      OR label CP `Z2UI5_CL_AJSON*` ).

  ENDMETHOD.

  METHOD cut.

    DATA(lv_len) = strlen( val ).
    IF lv_len <= c_max_value.
      result = val.
      RETURN.
    ENDIF.
    result = |{ substring( val = val
                           len = c_max_value ) }... ({ lv_len } characters)|.

  ENDMETHOD.

ENDCLASS.
