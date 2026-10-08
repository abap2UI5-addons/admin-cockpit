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
    " the most hits a search in the drafts lists
    CONSTANTS c_max_hits   TYPE i VALUE 200.
    " a shorter search term would match nearly every draft
    CONSTANTS c_min_search TYPE i VALUE 3.
    " the most drafts a scan for the drafts of one app reads
    CONSTANTS c_max_scan   TYPE i VALUE 5000.

    CONSTANTS:
      "! What a user did after a failed roundtrip, read from the drafts.
      BEGIN OF cs_outcome,
        continued TYPE string VALUE `continued`,
        stopped   TYPE string VALUE `stopped here`,
        open      TYPE string VALUE `still open`,
        unknown   TYPE string VALUE `unknown - draft expired`,
      END OF cs_outcome.

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
        " failed roundtrips the monitor logged in the session, and the
        " highlight of the row: Error when there is one
        errors    TYPE i,
        state     TYPE string,
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
        " what the roundtrip monitor logged: the event that led to this
        " step (slow roundtrips), the failure of the next one (errors)
        event         TYPE string,
        monitor       TYPE string,
        monitor_state TYPE string,
        " fields that differ from the step it continues - 0 means the
        " roundtrip changed nothing the app keeps
        changes        TYPE i,
        " messages the app holds in its state (a BAPI return, a message
        " table) that were not there in the step before, and their highlight
        messages       TYPE string,
        messages_state TYPE string,
        " from the recorder (z2ui5_cl_cockpit_wire), when it is active: what
        " the user pressed and typed for this step, what the response showed,
        " the recording that wrote the step and one that failed from it
        did            TYPE string,
        shown          TYPE string,
        shown_state    TYPE string,
        wire_id        TYPE string,
        wire_fail_id   TYPE string,
        " the event of the failed click after this step
        wire_fail_event TYPE string,
        " the highlight of the row: Information for the step shown
        state   TYPE string,
      END OF ty_s_step.
    TYPES ty_t_step TYPE STANDARD TABLE OF ty_s_step WITH EMPTY KEY.

    TYPES:
      "! A business object a session worked on, found by its field name.
      BEGIN OF ty_s_business,
        object TYPE string,
        value  TYPE string,
        field  TYPE string,
        " the step it first appears in
        step   TYPE i,
      END OF ty_s_business.
    TYPES ty_t_business TYPE STANDARD TABLE OF ty_s_business WITH EMPTY KEY.

    TYPES:
      "! A message the app holds in its state.
      BEGIN OF ty_s_message,
        type TYPE string,
        text TYPE string,
        path TYPE string,
      END OF ty_s_message.
    TYPES ty_t_message TYPE STANDARD TABLE OF ty_s_message WITH EMPTY KEY.

    TYPES ty_t_id TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    TYPES:
      "! A field of one sample - a draft - for common_of.
      BEGIN OF ty_s_sample,
        sample TYPE i,
        path   TYPE string,
        value  TYPE string,
      END OF ty_s_sample.
    TYPES ty_t_sample TYPE STANDARD TABLE OF ty_s_sample WITH EMPTY KEY.

    TYPES:
      "! A value most failing cases share and the other states rarely have.
      BEGIN OF ty_s_common,
        path       TYPE string,
        value      TYPE string,
        failing    TYPE i,
        of_failing TYPE i,
        others_pct TYPE i,
        text       TYPE string,
      END OF ty_s_common.
    TYPES ty_t_common TYPE STANDARD TABLE OF ty_s_common WITH EMPTY KEY.

    TYPES:
      "! A business object value and in how many drafts it occurs.
      BEGIN OF ty_s_object_count,
        object TYPE string,
        value  TYPE string,
        drafts TYPE i,
        field  TYPE string,
      END OF ty_s_object_count.
    TYPES ty_t_object_count TYPE STANDARD TABLE OF ty_s_object_count WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_failures,
        error      TYPE string,
        " the failing cases whose draft still exists, of all given
        failing    TYPE i,
        given      TYPE i,
        " other states of the same app, the baseline
        others     TYPE i,
        t_common   TYPE ty_t_common,
        t_business TYPE ty_t_object_count,
      END OF ty_s_failures.

    TYPES:
      BEGIN OF ty_s_app_objects,
        error     TYPE string,
        drafts    TYPE i,
        t_object  TYPE ty_t_object_count,
      END OF ty_s_app_objects.

    TYPES:
      BEGIN OF ty_s_outcome,
        id      TYPE string,
        outcome TYPE string,
        state   TYPE string,
      END OF ty_s_outcome.
    TYPES ty_t_outcome TYPE STANDARD TABLE OF ty_s_outcome WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_steps,
        error        TYPE string,
        check_capped TYPE abap_bool,
        t_step       TYPE ty_t_step,
        " the business objects of the session, in the order they appear
        t_business   TYPE ty_t_business,
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

    TYPES:
      "! The value of one field in every step of a session.
      BEGIN OF ty_s_history,
        step   TYPE i,
        time   TYPE string,
        value  TYPE string,
        change TYPE string,
        state  TYPE string,
      END OF ty_s_history.
    TYPES ty_t_history TYPE STANDARD TABLE OF ty_s_history WITH EMPTY KEY.

    TYPES:
      "! A field of a draft that contains a searched value.
      BEGIN OF ty_s_hit,
        nr      TYPE i,
        session TYPE string,
        id      TYPE string,
        time    TYPE string,
        user    TYPE string,
        app     TYPE string,
        path    TYPE string,
        value   TYPE string,
      END OF ty_s_hit.
    TYPES ty_t_hit TYPE STANDARD TABLE OF ty_s_hit WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_find,
        error        TYPE string,
        drafts       TYPE i,
        matched      TYPE i,
        check_capped TYPE abap_bool,
        t_hit        TYPE ty_t_hit,
      END OF ty_s_find.

    TYPES:
      "! A navigation between two apps - or the start of a session in one.
      BEGIN OF ty_s_flow,
        source TYPE string,
        target TYPE string,
        count  TYPE i,
      END OF ty_s_flow.
    TYPES ty_t_flow TYPE STANDARD TABLE OF ty_s_flow WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_flows,
        error   TYPE string,
        drafts  TYPE i,
        t_flow  TYPE ty_t_flow,
      END OF ty_s_flows.

    TYPES:
      "! A table of the app and its rows in two steps.
      BEGIN OF ty_s_growth,
        path        TYPE string,
        rows_before TYPE i,
        rows_after  TYPE i,
      END OF ty_s_growth.
    TYPES ty_t_growth TYPE STANDARD TABLE OF ty_s_growth WITH EMPTY KEY.

    TYPES:
      "! A draft, its predecessor and its app - the input of flows_of.
      BEGIN OF ty_s_link,
        id         TYPE c LENGTH 32,
        id_prev    TYPE c LENGTH 32,
        app        TYPE string,
        timestampl TYPE timestampl,
      END OF ty_s_link.
    TYPES ty_t_link TYPE STANDARD TABLE OF ty_s_link WITH EMPTY KEY.

    "! The sessions in the draft table, newest activity first. Never
    "! raises - check_readable / error say whether the table could be read.
    "! @parameter max_sessions   | the most sessions listed
    "! @parameter search         | only sessions whose app or user contains it
    "! @parameter active_minutes | only sessions with a step in the last minutes, 0 for all
    "! @parameter check_errors   | only sessions in which the monitor logged a failed roundtrip
    CLASS-METHODS get_sessions
      IMPORTING
        max_sessions   TYPE i DEFAULT 100
        search         TYPE clike OPTIONAL
        active_minutes TYPE i DEFAULT 0
        check_errors   TYPE abap_bool DEFAULT abap_false
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

    "! A session as text, to attach to a ticket: every field of its first
    "! step, then per step what changed, with event and monitor notes.
    "! Never raises - a session that cannot be read says so in the text.
    "! @parameter id   | the session - its first draft
    "! @parameter user | how the user is shown in the header
    CLASS-METHODS export
      IMPORTING
        id            TYPE clike
        user          TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

    "! The value of one field in every step of a session, oldest first;
    "! a step whose value differs from the step before is marked. Never
    "! raises - a step that cannot be read is skipped.
    "! @parameter it_step   | the steps of the session, as get_steps returns them
    "! @parameter path      | the field, as flatten names it
    "! @parameter check_all | also the objects of the framework itself
    CLASS-METHODS get_history
      IMPORTING
        it_step       TYPE ty_t_step
        path          TYPE string
        check_all     TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE ty_t_history.

    "! The fields of all drafts that contain a value - an order number, a
    "! customer, a text the user typed - with their session and step. Never
    "! raises. The search ignores case and needs c_min_search characters.
    CLASS-METHODS search_drafts
      IMPORTING
        search        TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_find.

    "! How users move between apps: per pair of apps the navigations in the
    "! draft table, and per app the sessions that start in it. Never raises.
    CLASS-METHODS get_flows
      RETURNING
        VALUE(result) TYPE ty_s_flows.

    "! The navigations of a set of drafts - a draft whose app differs from
    "! its predecessor's - the session starts, source "(start)", and the
    "! session ends, target "(end)" or "(end after an error)" when a failed
    "! roundtrip started from the last step. Sorted by count.
    "! @parameter it_failed    | drafts a failed roundtrip started from
    "! @parameter ended_before | a last step written later is a session still going on
    CLASS-METHODS flows_of
      IMPORTING
        it_link       TYPE ty_t_link
        it_failed     TYPE ty_t_id OPTIONAL
        ended_before  TYPE timestampl OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_flow.

    "! The business objects among a step's fields - an order, a customer, a
    "! material - recognized by the field name (VBELN, KUNNR, MATNR, ...,
    "! also as the end of a name like MV_VBELN). Initial values are skipped.
    CLASS-METHODS business_of
      IMPORTING
        it_value      TYPE ty_t_value
      RETURNING
        VALUE(result) TYPE ty_t_business.

    "! The error and warning messages among a step's fields: a structure or
    "! row with a type (TYPE, MSGTY, SEVERITY) of E, A, X or W and a text
    "! (MESSAGE, MSG; TEXT for errors only) - a BAPI return, a message table.
    CLASS-METHODS messages_of
      IMPORTING
        it_value      TYPE ty_t_value
      RETURNING
        VALUE(result) TYPE ty_t_message.

    "! The tables of the app that have more rows in the later of two steps,
    "! the most grown first. Never raises - empty when a step is gone.
    CLASS-METHODS get_growth
      IMPORTING
        id_before     TYPE clike
        id_after      TYPE clike
      RETURNING
        VALUE(result) TYPE ty_t_growth.

    "! The tables of two sets of fields and their rows - a table is a path
    "! up to a [n], a nested table counts per row of its parent. Only those
    "! that grew, the most grown first.
    CLASS-METHODS growth_of
      IMPORTING
        it_before     TYPE ty_t_value
        it_after      TYPE ty_t_value
      RETURNING
        VALUE(result) TYPE ty_t_growth.

    "! What users did after failed roundtrips: for the draft each one
    "! started from, whether a later draft continues it (continued), the
    "! session went quiet there for 30 minutes (stopped here - gave up, or
    "! started over in a new session), it is younger (still open) or gone.
    "! Never raises.
    CLASS-METHODS get_outcomes
      IMPORTING
        it_id         TYPE ty_t_id
      RETURNING
        VALUE(result) TYPE ty_t_outcome.

    "! get_outcomes on given draft rows - one result row per id, in order.
    CLASS-METHODS outcomes_of
      IMPORTING
        it_node       TYPE ty_t_node
        it_id         TYPE ty_t_id
        ended_before  TYPE timestampl
      RETURNING
        VALUE(result) TYPE ty_t_outcome.

    "! What failing cases have in common: the states the failed roundtrips
    "! started from, against other states of the same app. A value in at
    "! least 80 % of the failing states and at most 30 % of the others is a
    "! hint at the cause - "MS_HEAD-QTY = 0 in 5 of 5, in 3 % of the
    "! others". Also the business objects of the failing states, counted.
    "! Never raises.
    "! @parameter it_id | the drafts the failed roundtrips started from
    "! @parameter app   | the app, for the baseline
    CLASS-METHODS analyze_failures
      IMPORTING
        it_id         TYPE ty_t_id
        app           TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_failures.

    "! The values that tell failing samples from the others - see
    "! analyze_failures. Needs 2 failing samples and 1 other; the most
    "! telling first, at most 20.
    CLASS-METHODS common_of
      IMPORTING
        it_failing    TYPE ty_t_sample
        it_others     TYPE ty_t_sample
      RETURNING
        VALUE(result) TYPE ty_t_common.

    "! The business objects an app works with, from its drafts: per object
    "! type the number of drafts it appears in - types only, no values.
    "! Never raises.
    CLASS-METHODS get_app_objects
      IMPORTING
        app           TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_app_objects.

    "! A text as UTF-8, base64 encoded - the payload of a data: URL.
    CLASS-METHODS to_base64
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

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

    "! The app a draft belongs to, read from the draft table - empty when
    "! the draft is gone. Never raises.
    CLASS-METHODS get_app_of_draft
      IMPORTING
        id            TYPE clike
      RETURNING
        VALUE(result) TYPE string.

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

    "! App, size, changes, messages and business objects of the steps.
    CLASS-METHODS fill_steps
      CHANGING
        cs_steps TYPE ty_s_steps
      RAISING
        cx_static_check.

    "! Field names of business objects and how they are called.
    CLASS-METHODS business_catalogue
      RETURNING
        VALUE(result) TYPE z2ui5_if_client=>ty_t_name_value.

    "! What the roundtrip monitor logged about the steps - only errors and
    "! slow roundtrips are in its log.
    CLASS-METHODS fill_monitor
      CHANGING
        ct_step TYPE ty_t_step
      RAISING
        cx_static_check.

    "! What the recorder has for the steps: per step what the user pressed
    "! and typed - read against the screen the step continues - and what the
    "! response showed.
    CLASS-METHODS fill_wire
      CHANGING
        ct_step TYPE ty_t_step.

    "! The user's part of a roundtrip as one line: the control pressed and
    "! the fields typed, named after the controls of the screen.
    CLASS-METHODS did_of
      IMPORTING
        screen        TYPE string
        event         TYPE string
        request       TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! Add a monitor note to a step, an error outranks a slow roundtrip.
    CLASS-METHODS monitor_add
      IMPORTING
        text  TYPE string
        state TYPE string
      CHANGING
        cs_step TYPE ty_s_step.

    "! Drafts of an app, in the order of their ids - at most c_max_scan
    "! drafts are read to find them.
    "! @parameter max_hits  | the most drafts returned
    "! @parameter it_skip   | drafts not to return
    CLASS-METHODS scan_app
      IMPORTING
        app           TYPE clike
        max_hits      TYPE i
        it_skip       TYPE ty_t_id OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_id
      RAISING
        cx_static_check.

    "! The fields of a draft as samples for common_of.
    CLASS-METHODS samples_of
      IMPORTING
        sample        TYPE i
        xml           TYPE string
      CHANGING
        ct_sample     TYPE ty_t_sample.

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
        errors  TYPE i,
      END OF ty_s_agg.
    TYPES ty_id TYPE c LENGTH 32.
    DATA lt_agg TYPE HASHED TABLE OF ty_s_agg WITH UNIQUE KEY root.
    DATA lt_sorted TYPE STANDARD TABLE OF ty_s_agg WITH EMPTY KEY.
    DATA lt_node TYPE ty_t_node.
    DATA lt_failed TYPE STANDARD TABLE OF ty_id WITH EMPTY KEY.
    DATA lv_oldest TYPE timestampl.

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
      IF lv_oldest IS INITIAL OR ls_node-timestampl < lv_oldest.
        lv_oldest = ls_node-timestampl.
      ENDIF.
    ENDLOOP.

    " the failed roundtrips the monitor logged since the oldest draft, each
    " counted for the session of the draft it started from
    TRY.
        SELECT draft_id_prev FROM z2ui5_t_ck_log
          WHERE check_error = @abap_true
            AND timestampl >= @lv_oldest
          INTO TABLE @lt_failed.
      CATCH cx_root ##NO_HANDLER.
        " no monitor log - no error counts
    ENDTRY.
    LOOP AT lt_failed INTO DATA(lv_failed).
      READ TABLE lt_root INTO ls_root WITH TABLE KEY id = lv_failed.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_agg ASSIGNING <agg> WITH TABLE KEY root = ls_root-root.
      IF sy-subrc = 0.
        <agg>-errors = <agg>-errors + 1.
      ENDIF.
    ENDLOOP.

    lt_sorted = lt_agg.
    IF active_minutes > 0.
      DATA(lv_since) = z2ui5_cl_cockpit_setup=>now_minus_seconds( active_minutes * 60 ).
      DELETE lt_sorted WHERE last < lv_since.
    ENDIF.
    IF check_errors = abap_true.
      DELETE lt_sorted WHERE errors = 0.
    ENDIF.
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
                                             errors   = ls_agg-errors
                                             state    = COND #( WHEN ls_agg-errors > 0 THEN `Error` ELSE `None` )
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
        fill_steps( CHANGING cs_steps = result ).
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.
    TRY.
        fill_monitor( CHANGING ct_step = result-t_step ).
      CATCH cx_root ##NO_HANDLER.
        " the monitor's log is an extra - the steps stand without it
    ENDTRY.
    TRY.
        fill_wire( CHANGING ct_step = result-t_step ).
      CATCH cx_root ##NO_HANDLER.
        " so are the recordings
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

  METHOD export.

    DATA lt_lines TYPE string_table.
    DATA lt_old TYPE ty_t_value.
    DATA lv_prev TYPE string.

    DATA(ls_steps) = get_steps( id ).
    DATA(lv_nl) = cl_abap_char_utilities=>newline.
    APPEND |abap2UI5 session { id }| TO lt_lines.
    APPEND |exported { z2ui5_cl_cockpit_setup=>ts_text( z2ui5_cl_cockpit_setup=>now( ) ) } UTC by { sy-uname }| TO lt_lines.
    IF user IS NOT INITIAL.
      APPEND |user: { user }| TO lt_lines.
    ENDIF.
    IF ls_steps-error IS NOT INITIAL.
      APPEND |The session could not be read: { ls_steps-error }| TO lt_lines.
    ENDIF.
    APPEND |{ lines( ls_steps-t_step ) } steps{ COND #( WHEN ls_steps-check_capped = abap_true
                                                         THEN | (the newest { c_max_steps })| ) }| TO lt_lines.
    LOOP AT ls_steps-t_business INTO DATA(ls_business).
      IF sy-tabix = 1.
        APPEND `business objects:` TO lt_lines.
      ENDIF.
      APPEND |   { ls_business-object } { ls_business-value } (step { ls_business-step }, { ls_business-field })| TO lt_lines.
    ENDLOOP.

    LOOP AT ls_steps-t_step INTO DATA(ls_step).
      APPEND `` TO lt_lines.
      APPEND |== Step { ls_step-step } - { ls_step-time } UTC{ COND #( WHEN ls_step-delta IS NOT INITIAL
                                                                      THEN | ({ ls_step-delta })| ) }| &&
             | - { ls_step-app }{ COND #( WHEN ls_step-event IS NOT INITIAL THEN | - event { ls_step-event }| ) }| TO lt_lines.
      IF ls_step-note IS NOT INITIAL.
        APPEND |   { ls_step-note }| TO lt_lines.
      ENDIF.
      IF ls_step-monitor IS NOT INITIAL.
        APPEND |   monitor: { ls_step-monitor }| TO lt_lines.
      ENDIF.
      IF ls_step-messages IS NOT INITIAL.
        APPEND |   messages in the app: { ls_step-messages }| TO lt_lines.
      ENDIF.

      CLEAR lt_old.
      CLEAR lv_prev.
      IF ls_step-follows > 0.
        lv_prev = ls_steps-t_step[ ls_step-follows ]-id.
      ENDIF.
      TRY.
          DATA(lv_xml) = read_data( ls_step-id ).
          IF lv_prev IS NOT INITIAL.
            lt_old = flatten( read_data( lv_prev ) ).
          ENDIF.
        CATCH cx_root INTO DATA(lx).
          APPEND |   not readable: { lx->get_text( ) }| TO lt_lines.
          CONTINUE.
      ENDTRY.
      IF lv_xml IS INITIAL.
        APPEND `   the draft is gone` TO lt_lines.
        CONTINUE.
      ENDIF.

      DATA(lt_field) = diff( it_new      = flatten( lv_xml )
                             it_old      = lt_old
                             check_first = xsdbool( lv_prev IS INITIAL ) ).
      DATA(lv_changes) = 0.
      LOOP AT lt_field INTO DATA(ls_field).
        CASE ls_field-change.
          WHEN cs_change-changed.
            APPEND |   changed  { ls_field-path } = { cut( ls_field-value ) }   (before: { cut( ls_field-prev ) })| TO lt_lines.
          WHEN cs_change-new.
            APPEND |   new      { ls_field-path } = { cut( ls_field-value ) }| TO lt_lines.
          WHEN cs_change-removed.
            APPEND |   removed  { ls_field-path }   (was: { cut( ls_field-prev ) })| TO lt_lines.
          WHEN OTHERS.
            IF lv_prev IS INITIAL.
              APPEND |   { ls_field-path } = { cut( ls_field-value ) }| TO lt_lines.
            ENDIF.
            CONTINUE.
        ENDCASE.
        lv_changes = lv_changes + 1.
      ENDLOOP.
      IF lv_prev IS NOT INITIAL AND lv_changes = 0.
        APPEND `   no field changed` TO lt_lines.
      ENDIF.
    ENDLOOP.

    result = concat_lines_of( table = lt_lines
                              sep   = lv_nl ).

  ENDMETHOD.

  METHOD get_history.

    DATA lv_last TYPE string.

    LOOP AT it_step INTO DATA(ls_step).
      TRY.
          DATA(lv_xml) = read_data( ls_step-id ).
        CATCH cx_root.
          CONTINUE.
      ENDTRY.
      IF lv_xml IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(ls_history) = VALUE ty_s_history( step  = ls_step-step
                                             time  = ls_step-time
                                             value = `(not there)`
                                             state = `None` ).
      LOOP AT flatten( xml       = lv_xml
                       check_all = check_all ) INTO DATA(ls_value) WHERE path = path. "#EC CI_SORTSEQ
        ls_history-value = ls_value-value.
        EXIT.
      ENDLOOP.
      IF result IS NOT INITIAL AND ls_history-value <> lv_last.
        ls_history-change = cs_change-changed.
        ls_history-state  = `Warning`.
      ENDIF.
      lv_last = ls_history-value.
      ls_history-value = cut( ls_history-value ).
      APPEND ls_history TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD search_drafts.

    TYPES:
      BEGIN OF ty_s_row,
        id   TYPE c LENGTH 32,
        data TYPE string,
      END OF ty_s_row.
    TYPES:
      BEGIN OF ty_s_meta,
        id         TYPE c LENGTH 32,
        uname      TYPE c LENGTH 32,
        timestampl TYPE timestampl,
      END OF ty_s_meta.
    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    DATA lt_meta TYPE HASHED TABLE OF ty_s_meta WITH UNIQUE KEY id.
    DATA lt_node TYPE ty_t_node.
    DATA lv_last TYPE c LENGTH 32.
    DATA lv_tab TYPE string.
    DATA lv_search TYPE string.

    lv_search = condense( search ).
    IF strlen( lv_search ) < c_min_search.
      result-error = |Enter at least { c_min_search } characters.|.
      RETURN.
    ENDIF.

    TRY.
        lt_node = read_nodes( ).
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.
    DATA(lt_root) = roots_of( lt_node ).
    LOOP AT lt_node INTO DATA(ls_node).
      INSERT VALUE #( id         = ls_node-id
                      uname      = ls_node-uname
                      timestampl = ls_node-timestampl ) INTO TABLE lt_meta.
    ENDLOOP.

    " the serialized text escapes <, > and &, so a term with one of them
    " is only found in the decoded fields - every draft is taken apart then
    DATA(lv_prefilter) = xsdbool( lv_search NA `<>&"'` ).
    lv_tab = z2ui5_cl_cockpit_draft=>c_table.
    DO.
      CLEAR lt_rows.
      TRY.
          SELECT id, data FROM (lv_tab)
            WHERE id > @lv_last
            ORDER BY id
            INTO CORRESPONDING FIELDS OF TABLE @lt_rows
            UP TO 200 ROWS.
        CATCH cx_root INTO lx.
          result-error = lx->get_text( ).
          RETURN.
      ENDTRY.
      IF lt_rows IS INITIAL.
        EXIT.
      ENDIF.

      LOOP AT lt_rows INTO DATA(ls_row).
        lv_last = ls_row-id.
        result-drafts = result-drafts + 1.
        IF lv_prefilter = abap_true AND ls_row-data NS lv_search.
          CONTINUE.
        ENDIF.
        DATA(lv_matched) = abap_false.
        LOOP AT flatten( ls_row-data ) INTO DATA(ls_value).
          IF ls_value-value NS lv_search.
            CONTINUE.
          ENDIF.
          lv_matched = abap_true.
          IF lines( result-t_hit ) >= c_max_hits.
            result-check_capped = abap_true.
            EXIT.
          ENDIF.
          READ TABLE lt_meta INTO DATA(ls_meta) WITH TABLE KEY id = ls_row-id.
          READ TABLE lt_root INTO DATA(ls_root) WITH TABLE KEY id = ls_row-id.
          APPEND VALUE #( nr      = lines( result-t_hit ) + 1
                          session = COND #( WHEN ls_root-root IS NOT INITIAL THEN ls_root-root ELSE ls_row-id )
                          id      = ls_row-id
                          time    = z2ui5_cl_cockpit_setup=>ts_text( ls_meta-timestampl )
                          user    = user_text( ls_meta-uname )
                          app     = app_of( ls_row-data )
                          path    = ls_value-path
                          value   = cut( ls_value-value ) ) TO result-t_hit.
          CLEAR ls_meta.
          CLEAR ls_root.
        ENDLOOP.
        IF lv_matched = abap_true.
          result-matched = result-matched + 1.
        ENDIF.
      ENDLOOP.

      IF result-drafts >= c_max_nodes.
        result-check_capped = abap_true.
        EXIT.
      ENDIF.
    ENDDO.

  ENDMETHOD.

  METHOD get_flows.

    TYPES:
      BEGIN OF ty_s_row,
        id         TYPE c LENGTH 32,
        id_prev    TYPE c LENGTH 32,
        timestampl TYPE timestampl,
        data       TYPE string,
      END OF ty_s_row.
    TYPES ty_id TYPE c LENGTH 32.
    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    DATA lt_link TYPE ty_t_link.
    DATA lt_ids TYPE STANDARD TABLE OF ty_id WITH EMPTY KEY.
    DATA lt_failed TYPE ty_t_id.
    DATA lv_oldest TYPE timestampl.
    DATA lv_last TYPE c LENGTH 32.
    DATA lv_tab TYPE string.

    lv_tab = z2ui5_cl_cockpit_draft=>c_table.
    DO.
      CLEAR lt_rows.
      TRY.
          SELECT id, id_prev, timestampl, data FROM (lv_tab)
            WHERE id > @lv_last
            ORDER BY id
            INTO CORRESPONDING FIELDS OF TABLE @lt_rows
            UP TO 200 ROWS.
        CATCH cx_root INTO DATA(lx).
          result-error = lx->get_text( ).
          RETURN.
      ENDTRY.
      IF lt_rows IS INITIAL.
        EXIT.
      ENDIF.
      LOOP AT lt_rows INTO DATA(ls_row).
        lv_last = ls_row-id.
        APPEND VALUE #( id         = ls_row-id
                        id_prev    = ls_row-id_prev
                        timestampl = ls_row-timestampl
                        app        = app_of( ls_row-data ) ) TO lt_link.
        IF lv_oldest IS INITIAL OR ls_row-timestampl < lv_oldest.
          lv_oldest = ls_row-timestampl.
        ENDIF.
      ENDLOOP.
      IF lines( lt_link ) >= c_max_nodes.
        EXIT.
      ENDIF.
    ENDDO.

    " the drafts a failed roundtrip started from - a session ending there
    " ended in an error
    TRY.
        SELECT draft_id_prev FROM z2ui5_t_ck_log
          WHERE check_error = @abap_true
            AND timestampl >= @lv_oldest
          INTO TABLE @lt_ids.
      CATCH cx_root ##NO_HANDLER.
        " no monitor log - every end is a plain end
    ENDTRY.
    LOOP AT lt_ids INTO DATA(lv_id).
      APPEND CONV string( lv_id ) TO lt_failed.
    ENDLOOP.

    result-drafts = lines( lt_link ).
    " a session without a step for half an hour is over
    result-t_flow = flows_of( it_link      = lt_link
                              it_failed    = lt_failed
                              ended_before = z2ui5_cl_cockpit_setup=>now_minus_seconds( 1800 ) ).

  ENDMETHOD.

  METHOD flows_of.

    TYPES:
      BEGIN OF ty_s_app,
        id  TYPE c LENGTH 32,
        app TYPE string,
      END OF ty_s_app.
    TYPES:
      BEGIN OF ty_s_count,
        source TYPE string,
        target TYPE string,
        count  TYPE i,
      END OF ty_s_count.
    DATA lt_app TYPE HASHED TABLE OF ty_s_app WITH UNIQUE KEY id.
    DATA lt_count TYPE HASHED TABLE OF ty_s_count WITH UNIQUE KEY source target.
    DATA lt_prev TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lt_failed TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lv_source TYPE string.
    DATA lv_target TYPE string.

    LOOP AT it_link INTO DATA(ls_link).
      INSERT VALUE #( id  = ls_link-id
                      app = COND #( WHEN ls_link-app IS NOT INITIAL THEN ls_link-app ELSE `(unknown)` ) )
             INTO TABLE lt_app.
      IF ls_link-id_prev IS NOT INITIAL.
        INSERT CONV string( ls_link-id_prev ) INTO TABLE lt_prev.
      ENDIF.
    ENDLOOP.
    LOOP AT it_failed INTO DATA(lv_failed).
      INSERT lv_failed INTO TABLE lt_failed.
    ENDLOOP.

    LOOP AT it_link INTO ls_link.
      DATA(lv_link_id) = CONV string( ls_link-id ).
      " the last step of a session that is over: where the user left
      IF ended_before IS NOT INITIAL
          AND ls_link-timestampl < ended_before
          AND NOT line_exists( lt_prev[ table_line = lv_link_id ] ).
        lv_source = COND #( WHEN ls_link-app IS NOT INITIAL THEN ls_link-app ELSE `(unknown)` ).
        lv_target = COND #( WHEN line_exists( lt_failed[ table_line = lv_link_id ] )
                            THEN `(end after an error)` ELSE `(end)` ).
        READ TABLE lt_count ASSIGNING FIELD-SYMBOL(<end>) WITH TABLE KEY source = lv_source target = lv_target.
        IF sy-subrc <> 0.
          INSERT VALUE #( source = lv_source
                          target = lv_target ) INTO TABLE lt_count ASSIGNING <end>.
        ENDIF.
        <end>-count = <end>-count + 1.
      ENDIF.

      lv_target = COND string( WHEN ls_link-app IS NOT INITIAL THEN ls_link-app ELSE `(unknown)` ).
      IF ls_link-id_prev IS INITIAL.
        lv_source = `(start)`.
      ELSE.
        READ TABLE lt_app INTO DATA(ls_prev) WITH TABLE KEY id = ls_link-id_prev.
        IF sy-subrc <> 0.
          " the predecessor expired - neither a start nor a known navigation
          CONTINUE.
        ENDIF.
        IF ls_prev-app = lv_target.
          CONTINUE.
        ENDIF.
        lv_source = ls_prev-app.
      ENDIF.
      READ TABLE lt_count ASSIGNING FIELD-SYMBOL(<count>) WITH TABLE KEY source = lv_source target = lv_target.
      IF sy-subrc <> 0.
        INSERT VALUE #( source = lv_source
                        target = lv_target ) INTO TABLE lt_count ASSIGNING <count>.
      ENDIF.
      <count>-count = <count>-count + 1.
    ENDLOOP.

    LOOP AT lt_count INTO DATA(ls_count).
      APPEND VALUE #( source = ls_count-source
                      target = ls_count-target
                      count  = ls_count-count ) TO result.
    ENDLOOP.
    SORT result BY count DESCENDING source ASCENDING target ASCENDING.

  ENDMETHOD.

  METHOD get_growth.

    TRY.
        DATA(lv_before) = read_data( id_before ).
        DATA(lv_after) = read_data( id_after ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
    IF lv_before IS INITIAL OR lv_after IS INITIAL.
      RETURN.
    ENDIF.
    result = growth_of( it_before = flatten( lv_before )
                        it_after  = flatten( lv_after ) ).

  ENDMETHOD.

  METHOD growth_of.

    TYPES:
      BEGIN OF ty_s_row,
        tab TYPE string,
        row TYPE string,
      END OF ty_s_row.
    TYPES:
      BEGIN OF ty_s_count,
        tab    TYPE string,
        before TYPE i,
        after  TYPE i,
      END OF ty_s_count.
    DATA lt_row TYPE HASHED TABLE OF ty_s_row WITH UNIQUE KEY tab row.
    DATA lt_count TYPE HASHED TABLE OF ty_s_count WITH UNIQUE KEY tab.
    DATA lt_values TYPE ty_t_value.
    DATA lv_pos TYPE i.

    DO 2 TIMES.
      DATA(lv_pass) = sy-index.
      CLEAR lt_row.
      lt_values = COND #( WHEN lv_pass = 1 THEN it_before ELSE it_after ).
      LOOP AT lt_values INTO DATA(ls_value).
        " every [n] of the path is a row of the table the path names up to it
        lv_pos = 0.
        DO.
          DATA(lv_close) = find( val = ls_value-path
                                 sub = `]`
                                 off = lv_pos ).
          IF lv_close < 0.
            EXIT.
          ENDIF.
          DATA(lv_prefix) = substring( val = ls_value-path
                                       len = lv_close + 1 ).
          DATA(lv_open) = find( val = lv_prefix
                                sub = `[`
                                occ = -1 ).
          lv_pos = lv_close + 1.
          IF lv_open <= 0.
            CONTINUE.
          ENDIF.
          INSERT VALUE #( tab = substring( val = lv_prefix
                                           len = lv_open )
                          row = lv_prefix ) INTO TABLE lt_row.
        ENDDO.
      ENDLOOP.

      LOOP AT lt_row INTO DATA(ls_row).
        READ TABLE lt_count ASSIGNING FIELD-SYMBOL(<count>) WITH TABLE KEY tab = ls_row-tab.
        IF sy-subrc <> 0.
          INSERT VALUE #( tab = ls_row-tab ) INTO TABLE lt_count ASSIGNING <count>.
        ENDIF.
        IF lv_pass = 1.
          <count>-before = <count>-before + 1.
        ELSE.
          <count>-after = <count>-after + 1.
        ENDIF.
      ENDLOOP.
    ENDDO.

    LOOP AT lt_count INTO DATA(ls_count).
      IF ls_count-after <= ls_count-before.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( path        = ls_count-tab
                      rows_before = ls_count-before
                      rows_after  = ls_count-after ) TO result.
    ENDLOOP.
    SORT result BY rows_after DESCENDING path ASCENDING.

  ENDMETHOD.

  METHOD get_outcomes.

    DATA lt_node TYPE ty_t_node.

    TRY.
        lt_node = read_nodes( ).
      CATCH cx_root ##NO_HANDLER.
        " no draft table - every outcome is unknown
    ENDTRY.
    result = outcomes_of( it_node      = lt_node
                          it_id        = it_id
                          ended_before = z2ui5_cl_cockpit_setup=>now_minus_seconds( 1800 ) ).

  ENDMETHOD.

  METHOD outcomes_of.

    TYPES:
      BEGIN OF ty_s_meta,
        id         TYPE c LENGTH 32,
        timestampl TYPE timestampl,
      END OF ty_s_meta.
    TYPES ty_id TYPE c LENGTH 32.
    DATA lt_meta TYPE HASHED TABLE OF ty_s_meta WITH UNIQUE KEY id.
    DATA lt_prev TYPE HASHED TABLE OF ty_id WITH UNIQUE KEY table_line.
    DATA lv_key TYPE ty_id.

    LOOP AT it_node INTO DATA(ls_node).
      INSERT VALUE #( id         = ls_node-id
                      timestampl = ls_node-timestampl ) INTO TABLE lt_meta.
      IF ls_node-id_prev IS NOT INITIAL.
        INSERT ls_node-id_prev INTO TABLE lt_prev.
      ENDIF.
    ENDLOOP.

    LOOP AT it_id INTO DATA(lv_id).
      lv_key = lv_id.
      DATA(ls_outcome) = VALUE ty_s_outcome( id = lv_id ).
      READ TABLE lt_meta INTO DATA(ls_meta) WITH TABLE KEY id = lv_key.
      " kept at once: the downport turns the line_exists( ) below into a READ
      " TABLE in front of this IF, which would overwrite sy-subrc
      DATA(lv_found) = xsdbool( sy-subrc = 0 ).
      IF lv_key IS INITIAL OR lv_found = abap_false.
        ls_outcome-outcome = cs_outcome-unknown.
        ls_outcome-state   = `None`.
      ELSEIF line_exists( lt_prev[ table_line = lv_key ] ).
        ls_outcome-outcome = cs_outcome-continued.
        ls_outcome-state   = `Success`.
      ELSEIF ls_meta-timestampl >= ended_before.
        ls_outcome-outcome = cs_outcome-open.
        ls_outcome-state   = `Information`.
      ELSE.
        ls_outcome-outcome = cs_outcome-stopped.
        ls_outcome-state   = `Error`.
      ENDIF.
      APPEND ls_outcome TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD analyze_failures.

    TYPES:
      BEGIN OF ty_s_seen,
        object TYPE string,
        value  TYPE string,
      END OF ty_s_seen.
    DATA lt_failing TYPE ty_t_sample.
    DATA lt_others TYPE ty_t_sample.
    DATA lt_done TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lt_seen TYPE HASHED TABLE OF ty_s_seen WITH UNIQUE KEY object value.
    DATA lv_xml TYPE string.

    TRY.
        LOOP AT it_id INTO DATA(lv_id).
          IF lv_id IS INITIAL.
            CONTINUE.
          ENDIF.
          result-given = result-given + 1.
          " one failing state counts once, however often it failed
          INSERT lv_id INTO TABLE lt_done.
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.
          lv_xml = read_data( lv_id ).
          IF lv_xml IS INITIAL.
            CONTINUE.
          ENDIF.
          result-failing = result-failing + 1.
          samples_of( EXPORTING sample    = result-failing
                                xml       = lv_xml
                      CHANGING  ct_sample = lt_failing ).

          CLEAR lt_seen.
          LOOP AT business_of( flatten( lv_xml ) ) INTO DATA(ls_business).
            INSERT VALUE #( object = ls_business-object
                            value  = ls_business-value ) INTO TABLE lt_seen.
            IF sy-subrc <> 0.
              CONTINUE.
            ENDIF.
            READ TABLE result-t_business ASSIGNING FIELD-SYMBOL(<object>)
                 WITH KEY object = ls_business-object value = ls_business-value. "#EC CI_SORTSEQ
            IF sy-subrc <> 0.
              APPEND VALUE #( object = ls_business-object
                              value  = ls_business-value
                              field  = ls_business-field ) TO result-t_business ASSIGNING <object>.
            ENDIF.
            <object>-drafts = <object>-drafts + 1.
          ENDLOOP.
        ENDLOOP.
        SORT result-t_business BY drafts DESCENDING object ASCENDING value ASCENDING.

        IF result-failing < 2.
          RETURN.
        ENDIF.

        DATA(lt_other_ids) = scan_app( app      = app
                                       max_hits = 300
                                       it_skip  = it_id ).
        LOOP AT lt_other_ids INTO lv_id.
          lv_xml = read_data( lv_id ).
          IF lv_xml IS INITIAL.
            CONTINUE.
          ENDIF.
          result-others = result-others + 1.
          samples_of( EXPORTING sample    = result-others
                                xml       = lv_xml
                      CHANGING  ct_sample = lt_others ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.

    result-t_common = common_of( it_failing = lt_failing
                                 it_others  = lt_others ).

  ENDMETHOD.

  METHOD common_of.

    TYPES:
      BEGIN OF ty_s_count,
        path    TYPE string,
        value   TYPE string,
        count   TYPE i,
      END OF ty_s_count.
    TYPES:
      BEGIN OF ty_s_key,
        sample TYPE i,
        path   TYPE string,
        value  TYPE string,
      END OF ty_s_key.
    TYPES:
      BEGIN OF ty_s_rank,
        common TYPE ty_s_common,
        f_pct  TYPE i,
      END OF ty_s_rank.
    DATA lt_failing TYPE HASHED TABLE OF ty_s_count WITH UNIQUE KEY path value.
    DATA lt_others TYPE HASHED TABLE OF ty_s_count WITH UNIQUE KEY path value.
    DATA lt_once TYPE HASHED TABLE OF ty_s_key WITH UNIQUE KEY sample path value.
    DATA lt_rank TYPE STANDARD TABLE OF ty_s_rank WITH EMPTY KEY.
    DATA lv_failing TYPE i.
    DATA lv_others TYPE i.
    DATA lv_pct TYPE i.

    LOOP AT it_failing INTO DATA(ls_sample).
      IF ls_sample-sample > lv_failing.
        lv_failing = ls_sample-sample.
      ENDIF.
      INSERT VALUE #( sample = ls_sample-sample
                      path   = ls_sample-path
                      value  = ls_sample-value ) INTO TABLE lt_once.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_failing ASSIGNING FIELD-SYMBOL(<count>) WITH TABLE KEY path = ls_sample-path value = ls_sample-value.
      IF sy-subrc <> 0.
        INSERT VALUE #( path  = ls_sample-path
                        value = ls_sample-value ) INTO TABLE lt_failing ASSIGNING <count>.
      ENDIF.
      <count>-count = <count>-count + 1.
    ENDLOOP.

    CLEAR lt_once.
    LOOP AT it_others INTO ls_sample.
      IF ls_sample-sample > lv_others.
        lv_others = ls_sample-sample.
      ENDIF.
      INSERT VALUE #( sample = ls_sample-sample
                      path   = ls_sample-path
                      value  = ls_sample-value ) INTO TABLE lt_once.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_others ASSIGNING <count> WITH TABLE KEY path = ls_sample-path value = ls_sample-value.
      IF sy-subrc <> 0.
        INSERT VALUE #( path  = ls_sample-path
                        value = ls_sample-value ) INTO TABLE lt_others ASSIGNING <count>.
      ENDIF.
      <count>-count = <count>-count + 1.
    ENDLOOP.

    IF lv_failing < 2 OR lv_others < 1.
      RETURN.
    ENDIF.

    LOOP AT lt_failing INTO DATA(ls_count).
      IF ls_count-count * 100 < lv_failing * 80.
        CONTINUE.
      ENDIF.
      READ TABLE lt_others INTO DATA(ls_other) WITH TABLE KEY path = ls_count-path value = ls_count-value.
      IF sy-subrc <> 0.
        CLEAR ls_other.
      ENDIF.
      lv_pct = ls_other-count * 100 / lv_others.
      IF lv_pct > 30.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( f_pct  = ls_count-count * 100 / lv_failing
                      common = VALUE #( path       = ls_count-path
                                        value      = ls_count-value
                                        failing    = ls_count-count
                                        of_failing = lv_failing
                                        others_pct = lv_pct
                                        text       = |in { ls_count-count } of { lv_failing } failing, | &&
                                                     |in { lv_pct } % of { lv_others } other states| ) )
             TO lt_rank.
    ENDLOOP.

    SORT lt_rank BY f_pct DESCENDING common-others_pct ASCENDING common-path ASCENDING.
    LOOP AT lt_rank INTO DATA(ls_rank) TO 20.
      APPEND ls_rank-common TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD samples_of.

    LOOP AT flatten( xml ) INTO DATA(ls_value).
      " a reference or a long text tells nothing about a cause
      IF ls_value-value CP `->*` OR strlen( ls_value-value ) > 100.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( sample = sample
                      path   = ls_value-path
                      value  = ls_value-value ) TO ct_sample.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_app_objects.

    TYPES:
      BEGIN OF ty_s_seen,
        object TYPE string,
      END OF ty_s_seen.
    DATA lt_seen TYPE HASHED TABLE OF ty_s_seen WITH UNIQUE KEY object.
    DATA lv_xml TYPE string.

    TRY.
        DATA(lt_ids) = scan_app( app      = app
                                 max_hits = 300 ).
        LOOP AT lt_ids INTO DATA(lv_id).
          lv_xml = read_data( lv_id ).
          IF lv_xml IS INITIAL.
            CONTINUE.
          ENDIF.
          result-drafts = result-drafts + 1.
          CLEAR lt_seen.
          LOOP AT business_of( flatten( lv_xml ) ) INTO DATA(ls_business).
            INSERT VALUE #( object = ls_business-object ) INTO TABLE lt_seen.
            IF sy-subrc <> 0.
              CONTINUE.
            ENDIF.
            READ TABLE result-t_object ASSIGNING FIELD-SYMBOL(<object>)
                 WITH KEY object = ls_business-object. "#EC CI_SORTSEQ
            IF sy-subrc <> 0.
              APPEND VALUE #( object = ls_business-object
                              field  = ls_business-field ) TO result-t_object ASSIGNING <object>.
            ENDIF.
            <object>-drafts = <object>-drafts + 1.
          ENDLOOP.
        ENDLOOP.
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.
    SORT result-t_object BY drafts DESCENDING object ASCENDING.

  ENDMETHOD.

  METHOD scan_app.

    TYPES:
      BEGIN OF ty_s_row,
        id   TYPE c LENGTH 32,
        data TYPE string,
      END OF ty_s_row.
    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    DATA lt_skip TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lv_last TYPE c LENGTH 32.
    DATA lv_tab TYPE string.
    DATA lv_scanned TYPE i.

    DATA(lv_app) = to_upper( condense( app ) ).
    LOOP AT it_skip INTO DATA(lv_skip).
      INSERT lv_skip INTO TABLE lt_skip.
    ENDLOOP.
    lv_tab = z2ui5_cl_cockpit_draft=>c_table.
    DO.
      CLEAR lt_rows.
      SELECT id, data FROM (lv_tab)
        WHERE id > @lv_last
        ORDER BY id
        INTO CORRESPONDING FIELDS OF TABLE @lt_rows
        UP TO 200 ROWS.
      IF lt_rows IS INITIAL.
        RETURN.
      ENDIF.
      LOOP AT lt_rows INTO DATA(ls_row).
        lv_last = ls_row-id.
        lv_scanned = lv_scanned + 1.
        DATA(lv_id) = CONV string( ls_row-id ).
        IF line_exists( lt_skip[ table_line = lv_id ] ).
          CONTINUE.
        ENDIF.
        IF app_of( ls_row-data ) <> lv_app.
          CONTINUE.
        ENDIF.
        APPEND lv_id TO result.
        IF lines( result ) >= max_hits.
          RETURN.
        ENDIF.
      ENDLOOP.
      IF lv_scanned >= c_max_scan.
        RETURN.
      ENDIF.
    ENDDO.

  ENDMETHOD.

  METHOD to_base64.

    CONSTANTS lc_alphabet TYPE string VALUE `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/`.
    DATA lt_part TYPE string_table.
    DATA lv_utf8 TYPE xstring.
    DATA lv_byte TYPE x LENGTH 1.
    DATA lv_off TYPE i.
    DATA lv_rest TYPE i.
    DATA lv_value TYPE i.
    DATA lv_triple TYPE i.
    DATA lv_part TYPE string.
    DATA lo_conv TYPE REF TO object.
    DATA lv_class TYPE c LENGTH 30.

    " UTF-8 through whichever converter the release has - by name, as the
    " modern one is missing on 7.02 and the classic one is not released in
    " ABAP Cloud
    TRY.
        lv_class = `CL_ABAP_CONV_CODEPAGE`.
        CALL METHOD (lv_class)=>create_out
          RECEIVING
            instance = lo_conv.
        CALL METHOD lo_conv->(`IF_ABAP_CONV_OUT~CONVERT`)
          EXPORTING
            source = val
          RECEIVING
            result = lv_utf8.
      CATCH cx_root.
        TRY.
            lv_class = `CL_ABAP_CONV_OUT_CE`.
            CALL METHOD (lv_class)=>create
              EXPORTING
                encoding = `UTF-8`
              RECEIVING
                conv     = lo_conv.
            CALL METHOD lo_conv->(`CONVERT`)
              EXPORTING
                data   = val
              IMPORTING
                buffer = lv_utf8.
          CATCH cx_root.
            RETURN.
        ENDTRY.
    ENDTRY.

    DATA(lv_len) = xstrlen( lv_utf8 ).
    WHILE lv_off < lv_len.
      lv_rest = lv_len - lv_off.
      lv_triple = 0.
      DO 3 TIMES.
        lv_triple = lv_triple * 256.
        IF sy-index <= lv_rest.
          lv_byte = lv_utf8+lv_off(1).
          lv_value = lv_byte.
          lv_triple = lv_triple + lv_value.
          lv_off = lv_off + 1.
        ENDIF.
      ENDDO.
      lv_part = substring( val = lc_alphabet
                           off = lv_triple DIV 262144
                           len = 1 ) &&
                substring( val = lc_alphabet
                           off = ( lv_triple DIV 4096 ) MOD 64
                           len = 1 ).
      IF lv_rest > 1.
        lv_part = lv_part && substring( val = lc_alphabet
                                        off = ( lv_triple DIV 64 ) MOD 64
                                        len = 1 ).
      ELSE.
        lv_part = lv_part && `=`.
      ENDIF.
      IF lv_rest > 2.
        lv_part = lv_part && substring( val = lc_alphabet
                                        off = lv_triple MOD 64
                                        len = 1 ).
      ELSE.
        lv_part = lv_part && `=`.
      ENDIF.
      APPEND lv_part TO lt_part.
    ENDWHILE.
    result = concat_lines_of( lt_part ).

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
                                       time          = z2ui5_cl_cockpit_setup=>ts_text( ls_node-timestampl )
                                       state         = `None`
                                       " never empty: UI5 rejects "" as a ValueState
                                       " and terminates the app - with no recording
                                       " fill_wire leaves these untouched
                                       monitor_state  = `None`
                                       shown_state    = `None`
                                       messages_state = `None` ).
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
    TYPES:
      BEGIN OF ty_s_seen,
        object TYPE string,
        value  TYPE string,
      END OF ty_s_seen.
    DATA lt_data TYPE HASHED TABLE OF ty_s_row WITH UNIQUE KEY id.
    DATA lt_seen TYPE HASHED TABLE OF ty_s_seen WITH UNIQUE KEY object value.
    DATA lt_range TYPE ty_r_id.
    DATA lt_prev TYPE ty_t_value.
    DATA lv_prev_id TYPE string.
    DATA lv_prev_messages TYPE string.
    DATA lv_tab TYPE string.
    DATA lv_app TYPE string.
    DATA lv_done TYPE i.
    DATA lv_from TYPE i VALUE 1.
    DATA lv_idle TYPE i.
    DATA lv_messages TYPE string.

    lv_tab = z2ui5_cl_cockpit_draft=>c_table.
    LOOP AT cs_steps-t_step INTO DATA(ls_step).
      lv_done = lv_done + 1.
      APPEND VALUE #( sign   = `I`
                      option = `EQ`
                      low    = ls_step-id ) TO lt_range.
      IF lines( lt_range ) < 50 AND lv_done < lines( cs_steps-t_step ).
        CONTINUE.
      ENDIF.

      CLEAR lt_data.
      SELECT id, data FROM (lv_tab)
        WHERE id IN @lt_range
        INTO CORRESPONDING FIELDS OF TABLE @lt_data.
      CLEAR lt_range.

      " the steps of this batch in their order - each compared with the
      " step it continues, which is the one before it unless the user went
      " back in the browser
      LOOP AT cs_steps-t_step ASSIGNING FIELD-SYMBOL(<step>) FROM lv_from TO lv_done.
        DATA(lv_key) = CONV ty_id( <step>-id ).
        READ TABLE lt_data INTO DATA(ls_row) WITH TABLE KEY id = lv_key.
        IF sy-subrc <> 0.
          CLEAR lt_prev.
          CLEAR lv_prev_id.
          CONTINUE.
        ENDIF.
        <step>-app = app_of( ls_row-data ).
        <step>-kb  = ( strlen( ls_row-data ) + 1023 ) DIV 1024.
        DATA(lt_values) = flatten( ls_row-data ).

        IF <step>-follows > 0.
          DATA(lv_follows) = cs_steps-t_step[ <step>-follows ]-id.
          IF lv_follows <> lv_prev_id.
            lt_prev = flatten( read_data( lv_follows ) ).
          ENDIF.
          <step>-changes = 0.
          LOOP AT diff( it_new = lt_values
                        it_old = lt_prev ) TRANSPORTING NO FIELDS WHERE change IS NOT INITIAL. "#EC CI_SORTSEQ
            <step>-changes = <step>-changes + 1.
          ENDLOOP.
          IF <step>-changes = 0.
            lv_idle = lv_idle + 1.
            <step>-note = |{ <step>-note }{ COND #( WHEN <step>-note IS NOT INITIAL THEN `, ` ) }| &&
                          |{ COND #( WHEN lv_idle > 1 THEN |no field changed - { lv_idle } times in a row|
                                     ELSE `no field changed` ) }|.
          ELSE.
            lv_idle = 0.
          ENDIF.
        ELSE.
          lv_idle = 0.
        ENDIF.

        " a message is shown where it appears, not on every step that keeps it
        CLEAR lv_messages.
        DATA(lt_message) = messages_of( lt_values ).
        LOOP AT lt_message INTO DATA(ls_message).
          IF sy-tabix > 2.
            lv_messages = |{ lv_messages } (+{ lines( lt_message ) - 2 } more)|.
            EXIT.
          ENDIF.
          lv_messages = |{ lv_messages }{ COND #( WHEN lv_messages IS NOT INITIAL THEN `; ` ) }| &&
                        |{ ls_message-type }: { ls_message-text }|.
        ENDLOOP.
        IF lv_messages <> lv_prev_messages.
          <step>-messages = lv_messages.
          <step>-messages_state = COND #( WHEN line_exists( lt_message[ type = `E` ] )
                                            OR line_exists( lt_message[ type = `A` ] )
                                            OR line_exists( lt_message[ type = `X` ] )
                                            OR line_exists( lt_message[ type = `ERROR` ] ) THEN `Error`
                                          WHEN lt_message IS NOT INITIAL THEN `Warning`
                                          ELSE `None` ).
        ELSE.
          <step>-messages_state = `None`.
        ENDIF.
        lv_prev_messages = lv_messages.

        LOOP AT business_of( lt_values ) INTO DATA(ls_business).
          INSERT VALUE #( object = ls_business-object
                          value  = ls_business-value ) INTO TABLE lt_seen.
          IF sy-subrc = 0 AND lines( cs_steps-t_business ) < 50.
            ls_business-step = <step>-step.
            APPEND ls_business TO cs_steps-t_business.
          ENDIF.
        ENDLOOP.

        lt_prev = lt_values.
        lv_prev_id = <step>-id.
      ENDLOOP.
      lv_from = lv_done + 1.
    ENDLOOP.

    LOOP AT cs_steps-t_step ASSIGNING <step>.
      IF <step>-messages_state IS INITIAL.
        <step>-messages_state = `None`.
      ENDIF.
      IF <step>-step > 1 AND <step>-app <> lv_app AND <step>-app IS NOT INITIAL.
        <step>-note = |{ <step>-note }{ COND #( WHEN <step>-note IS NOT INITIAL THEN `, ` ) }| &&
                      |navigated to { <step>-app }|.
      ENDIF.
      IF <step>-app IS NOT INITIAL.
        lv_app = <step>-app.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD business_catalogue.

    " the classic field names of the SAP data model, the names of the ABAP
    " flight and RAP demo models, and plain English ones
    result = VALUE #( ( n = `VBELN`       v = `Sales document` )
                      ( n = `KUNNR`       v = `Customer` )
                      ( n = `KUNAG`       v = `Sold-to party` )
                      ( n = `LIFNR`       v = `Supplier` )
                      ( n = `PARTNER`     v = `Business partner` )
                      ( n = `MATNR`       v = `Material` )
                      ( n = `EBELN`       v = `Purchase order` )
                      ( n = `BANFN`       v = `Purchase requisition` )
                      ( n = `BELNR`       v = `Accounting document` )
                      ( n = `MBLNR`       v = `Material document` )
                      ( n = `AUFNR`       v = `Order` )
                      ( n = `QMNUM`       v = `Notification` )
                      ( n = `EQUNR`       v = `Equipment` )
                      ( n = `TPLNR`       v = `Functional location` )
                      ( n = `PERNR`       v = `Personnel number` )
                      ( n = `BUKRS`       v = `Company code` )
                      ( n = `WERKS`       v = `Plant` )
                      ( n = `LGORT`       v = `Storage location` )
                      ( n = `VKORG`       v = `Sales organization` )
                      ( n = `EKORG`       v = `Purchasing organization` )
                      ( n = `KOSTL`       v = `Cost center` )
                      ( n = `PRCTR`       v = `Profit center` )
                      ( n = `POSID`       v = `WBS element` )
                      ( n = `ANLN1`       v = `Asset` )
                      ( n = `CHARG`       v = `Batch` )
                      ( n = `CARRID`      v = `Airline` )
                      ( n = `CONNID`      v = `Flight connection` )
                      ( n = `TRAVEL_ID`   v = `Travel` )
                      ( n = `BOOKING_ID`  v = `Booking` )
                      ( n = `ORDER_ID`    v = `Order` )
                      ( n = `CUSTOMER`    v = `Customer` )
                      ( n = `CUSTOMER_ID` v = `Customer` )
                      ( n = `SUPPLIER`    v = `Supplier` )
                      ( n = `PRODUCT`     v = `Product` )
                      ( n = `PRODUCT_ID`  v = `Product` )
                      ( n = `INVOICE`     v = `Invoice` ) ).

  ENDMETHOD.

  METHOD business_of.

    TYPES:
      BEGIN OF ty_s_seen,
        object TYPE string,
        value  TYPE string,
      END OF ty_s_seen.
    DATA lt_seen TYPE HASHED TABLE OF ty_s_seen WITH UNIQUE KEY object value.
    DATA lv_name TYPE string.

    DATA(lt_catalogue) = business_catalogue( ).
    LOOP AT it_value INTO DATA(ls_value).
      DATA(lv_value) = condense( ls_value-value ).
      " empty, or an initial number or date
      IF lv_value CO ` 0.:-` OR lv_value CP `->*`.
        CONTINUE.
      ENDIF.
      " the last component of the path, without the row of an elementary table
      " find( occ = -1 ) and not substring_after( occ = -1 ): the transpiled
      " runtime ignores occ there and cuts at the first dash
      lv_name = ls_value-path.
      DATA(lv_dash) = find( val = lv_name
                            sub = `-`
                            occ = -1 ).
      IF lv_dash >= 0.
        lv_name = substring( val = lv_name
                             off = lv_dash + 1 ).
      ENDIF.
      IF lv_name CS `[`.
        lv_name = substring_before( val = lv_name
                                    sub = `[` ).
      ENDIF.
      lv_name = to_upper( lv_name ).

      LOOP AT lt_catalogue INTO DATA(ls_entry).
        IF lv_name <> ls_entry-n AND lv_name NP |*_{ ls_entry-n }|.
          CONTINUE.
        ENDIF.
        INSERT VALUE #( object = ls_entry-v
                        value  = lv_value ) INTO TABLE lt_seen.
        IF sy-subrc = 0.
          APPEND VALUE #( object = ls_entry-v
                          value  = lv_value
                          field  = ls_value-path ) TO result.
        ENDIF.
        EXIT.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD messages_of.

    TYPES:
      BEGIN OF ty_s_row,
        prefix TYPE string,
        type   TYPE string,
        text   TYPE string,
        weak   TYPE string,
      END OF ty_s_row.
    DATA lt_row TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    DATA lv_prefix TYPE string.
    DATA lv_comp TYPE string.

    LOOP AT it_value INTO DATA(ls_value).
      " find( occ = -1 ), see business_of
      DATA(lv_dash) = find( val = ls_value-path
                            sub = `-`
                            occ = -1 ).
      IF lv_dash < 0.
        CONTINUE.
      ENDIF.
      lv_prefix = substring( val = ls_value-path
                             len = lv_dash ).
      lv_comp = to_upper( substring( val = ls_value-path
                                     off = lv_dash + 1 ) ).
      IF lv_comp <> `TYPE` AND lv_comp <> `MSGTY` AND lv_comp <> `SEVERITY`
          AND lv_comp <> `MESSAGE` AND lv_comp <> `MSG` AND lv_comp <> `TEXT`.
        CONTINUE.
      ENDIF.
      READ TABLE lt_row ASSIGNING FIELD-SYMBOL(<row>) WITH KEY prefix = lv_prefix. "#EC CI_SORTSEQ
      IF sy-subrc <> 0.
        APPEND VALUE #( prefix = lv_prefix ) TO lt_row ASSIGNING <row>.
      ENDIF.
      CASE lv_comp.
        WHEN `TYPE` OR `MSGTY` OR `SEVERITY`.
          <row>-type = to_upper( condense( ls_value-value ) ).
        WHEN `MESSAGE` OR `MSG`.
          <row>-text = ls_value-value.
        WHEN OTHERS.
          <row>-weak = ls_value-value.
      ENDCASE.
    ENDLOOP.

    LOOP AT lt_row INTO DATA(ls_row).
      DATA(lv_error) = xsdbool( ls_row-type = `E` OR ls_row-type = `A` OR ls_row-type = `X`
                                OR ls_row-type = `ERROR` ).
      " TEXT is too common a name - it counts only next to an error type
      IF ls_row-text IS INITIAL AND lv_error = abap_true.
        ls_row-text = ls_row-weak.
      ENDIF.
      IF ls_row-text IS INITIAL.
        CONTINUE.
      ENDIF.
      IF lv_error = abap_false AND ls_row-type <> `W` AND ls_row-type <> `WARNING`.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( type = ls_row-type
                      text = ls_row-text
                      path = ls_row-prefix ) TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD fill_monitor.

    TYPES ty_id TYPE c LENGTH 32.
    TYPES ty_r_id TYPE RANGE OF ty_id.
    TYPES:
      BEGIN OF ty_s_log,
        draft_id      TYPE c LENGTH 32,
        draft_id_prev TYPE c LENGTH 32,
        event         TYPE c LENGTH 40,
        check_error   TYPE abap_bool,
        check_slow    TYPE abap_bool,
        ms_total      TYPE i,
        error_class   TYPE c LENGTH 30,
        error_head    TYPE c LENGTH 200,
      END OF ty_s_log.
    DATA lt_log TYPE STANDARD TABLE OF ty_s_log WITH EMPTY KEY.
    DATA lt_range TYPE ty_r_id.
    DATA lv_done TYPE i.

    LOOP AT ct_step INTO DATA(ls_step).
      lv_done = lv_done + 1.
      APPEND VALUE #( sign   = `I`
                      option = `EQ`
                      low    = ls_step-id ) TO lt_range.
      IF lines( lt_range ) < 50 AND lv_done < lines( ct_step ).
        CONTINUE.
      ENDIF.
      SELECT draft_id, draft_id_prev, event, check_error, check_slow, ms_total, error_class, error_head
        FROM z2ui5_t_ck_log
        WHERE draft_id IN @lt_range
           OR draft_id_prev IN @lt_range
        APPENDING CORRESPONDING FIELDS OF TABLE @lt_log.
      CLEAR lt_range.
    ENDLOOP.

    LOOP AT lt_log INTO DATA(ls_log).
      IF ls_log-check_error = abap_true.
        " the roundtrip started from this step and failed - its own draft,
        " if it wrote one, is not where the user saw the screen
        READ TABLE ct_step ASSIGNING FIELD-SYMBOL(<step>) WITH KEY id = ls_log-draft_id_prev. "#EC CI_SORTSEQ
        IF sy-subrc = 0.
          monitor_add( EXPORTING text  = |next roundtrip failed: { ls_log-error_class } { ls_log-error_head } | &&
                                         |(event { ls_log-event })|
                                 state = `Error`
                       CHANGING  cs_step = <step> ).
        ENDIF.
        CONTINUE.
      ENDIF.
      READ TABLE ct_step ASSIGNING <step> WITH KEY id = ls_log-draft_id. "#EC CI_SORTSEQ
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      <step>-event = ls_log-event.
      IF ls_log-check_slow = abap_true.
        monitor_add( EXPORTING text  = |slow: { ls_log-ms_total } ms|
                               state = `Warning`
                     CHANGING  cs_step = <step> ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD fill_wire.

    TYPES:
      BEGIN OF ty_s_screen,
        step TYPE i,
        xml  TYPE string,
      END OF ty_s_screen.
    DATA lt_id TYPE ty_t_id.
    DATA lt_screen TYPE HASHED TABLE OF ty_s_screen WITH UNIQUE KEY step.
    DATA lv_screen TYPE string.
    DATA lv_request TYPE string.
    DATA lv_response TYPE string.

    LOOP AT ct_step INTO DATA(ls_step).
      APPEND ls_step-id TO lt_id.
    ENDLOOP.
    DATA(lt_record) = z2ui5_cl_cockpit_wire=>get_records( lt_id ).
    IF lt_record IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT ct_step ASSIGNING FIELD-SYMBOL(<step>).
      " the screen the user saw before this step: the one of the step it continues
      CLEAR lv_screen.
      IF <step>-follows > 0.
        READ TABLE lt_screen INTO DATA(ls_screen) WITH TABLE KEY step = <step>-follows.
        IF sy-subrc = 0.
          lv_screen = ls_screen-xml.
        ENDIF.
      ENDIF.

      READ TABLE lt_record INTO DATA(ls_record) WITH KEY draft_id = <step>-id. "#EC CI_SORTSEQ
      IF sy-subrc = 0.
        <step>-wire_id = ls_record-id.
        " the monitor may be off - the recording names the event too
        IF <step>-event IS INITIAL.
          <step>-event = ls_record-event.
        ENDIF.
        z2ui5_cl_cockpit_wire=>get_bodies( EXPORTING id       = ls_record-id
                                           IMPORTING request  = lv_request
                                                     response = lv_response ).
        <step>-did = did_of( screen  = lv_screen
                             event   = ls_record-event
                             request = lv_request ).
        DATA(lt_shown) = z2ui5_cl_cockpit_wire=>shown_of( lv_response ).
        <step>-shown = z2ui5_cl_cockpit_wire=>shown_text( lt_shown ).
        LOOP AT lt_shown INTO DATA(ls_shown) WHERE kind = z2ui5_cl_cockpit_wire=>cs_kind-box. "#EC CI_SORTSEQ
          DATA(lv_type) = to_lower( ls_shown-type ).
          <step>-shown_state = SWITCH #( lv_type
                                         WHEN `error` THEN `Error`
                                         WHEN `warning` THEN `Warning`
                                         ELSE <step>-shown_state ).
        ENDLOOP.
        LOOP AT z2ui5_cl_cockpit_wire=>views_of( lv_response ) INTO DATA(ls_view) WHERE n = `MAIN`. "#EC CI_SORTSEQ
          lv_screen = ls_view-v.
        ENDLOOP.
      ENDIF.
      INSERT VALUE #( step = <step>-step
                      xml  = lv_screen ) INTO TABLE lt_screen.

      " a roundtrip that started here and failed wrote no step - its request
      " is the user's last attempt
      LOOP AT lt_record INTO ls_record WHERE draft_id_prev = <step>-id AND http_status >= 500. "#EC CI_SORTSEQ
        <step>-wire_fail_id = ls_record-id.
        <step>-wire_fail_event = ls_record-event.
        z2ui5_cl_cockpit_wire=>get_bodies( EXPORTING id      = ls_record-id
                                           IMPORTING request = lv_request ).
        <step>-note = |{ <step>-note }{ COND #( WHEN <step>-note IS NOT INITIAL THEN `, ` ) }| &&
                      |next click failed: { did_of( screen  = lv_screen
                                                    event   = ls_record-event
                                                    request = lv_request ) }|.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD did_of.

    DATA lv_typed TYPE string.
    DATA lv_count TYPE i.

    IF event IS NOT INITIAL.
      DATA(lv_control) = z2ui5_cl_cockpit_wire=>control_of( xml   = screen
                                                           event = event ).
      result = COND #( WHEN lv_control IS NOT INITIAL THEN |pressed { lv_control } ({ event })|
                       ELSE |event { event }| ).
    ENDIF.
    LOOP AT z2ui5_cl_cockpit_wire=>input_of( request ) INTO DATA(ls_input).
      IF ls_input-path CP `event argument*`.
        CONTINUE.
      ENDIF.
      lv_count = lv_count + 1.
      IF lv_count > 3.
        CONTINUE.
      ENDIF.
      DATA(lv_field) = z2ui5_cl_cockpit_wire=>field_control_of( xml  = screen
                                                               path = ls_input-path ).
      lv_typed = |{ lv_typed }{ COND #( WHEN lv_typed IS NOT INITIAL THEN `, ` ) }| &&
                 |{ COND #( WHEN lv_field IS NOT INITIAL THEN lv_field ELSE ls_input-path ) } = { cut( ls_input-value ) }|.
    ENDLOOP.
    IF lv_count > 3.
      lv_typed = |{ lv_typed } (+{ lv_count - 3 } more)|.
    ENDIF.
    IF lv_typed IS NOT INITIAL.
      result = |{ result }{ COND #( WHEN result IS NOT INITIAL THEN `, ` ) }typed { lv_typed }|.
    ENDIF.

  ENDMETHOD.

  METHOD monitor_add.

    cs_step-monitor = |{ cs_step-monitor }{ COND #( WHEN cs_step-monitor IS NOT INITIAL THEN `; ` ) }{ text }|.
    IF cs_step-monitor_state <> `Error`.
      cs_step-monitor_state = state.
    ENDIF.

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

  METHOD get_app_of_draft.

    TRY.
        result = app_of( read_data( id ) ).
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

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
