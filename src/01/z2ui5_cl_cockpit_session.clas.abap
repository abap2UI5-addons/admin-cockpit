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
    TYPES ty_t_node TYPE STANDARD TABLE OF ty_s_node WITH DEFAULT KEY.

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
        " signs that the user struggled, from the recorder - signals_of
        signals      TYPE string,
        signal_state TYPE string,
      END OF ty_s_session.
    TYPES ty_t_session TYPE STANDARD TABLE OF ty_s_session WITH DEFAULT KEY.

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
        timestampl TYPE timestampl,
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
        " what the step cost, from the recorder (run( ) only): the server's
        " time for the roundtrip that wrote it, the time the user waited for
        " it in the browser (sent with the next request)
        ms_server      TYPE i,
        ms_browser     TYPE i,
        ms_text        TYPE string,
        ms_state       TYPE string,
        " the highlight of the row: Information for the step shown
        state   TYPE string,
      END OF ty_s_step.
    TYPES ty_t_step TYPE STANDARD TABLE OF ty_s_step WITH DEFAULT KEY.

    TYPES:
      "! One click of a session as signals_of reads it.
      BEGIN OF ty_s_signal,
        timestampl  TYPE timestampl,
        event       TYPE string,
        http_status TYPE i,
        " how long the user waited for this roundtrip in the browser
        ms_browser  TYPE i,
        " the error box it answered with
        error_text  TYPE string,
      END OF ty_s_signal.
    TYPES ty_t_signal TYPE STANDARD TABLE OF ty_s_signal WITH DEFAULT KEY.

    TYPES:
      "! Signs that a user struggled - a score, the reasons, a ValueState.
      BEGIN OF ty_s_signals,
        score TYPE i,
        text  TYPE string,
        state TYPE string,
      END OF ty_s_signals.

    TYPES:
      "! A business object a session worked on, found by its field name.
      BEGIN OF ty_s_business,
        object TYPE string,
        value  TYPE string,
        field  TYPE string,
        " the step it first appears in
        step   TYPE i,
      END OF ty_s_business.
    TYPES ty_t_business TYPE STANDARD TABLE OF ty_s_business WITH DEFAULT KEY.

    TYPES:
      "! A message the app holds in its state.
      BEGIN OF ty_s_message,
        type TYPE string,
        text TYPE string,
        path TYPE string,
      END OF ty_s_message.
    TYPES ty_t_message TYPE STANDARD TABLE OF ty_s_message WITH DEFAULT KEY.

    TYPES ty_t_id TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    TYPES:
      "! A field of one sample - a draft - for common_of.
      BEGIN OF ty_s_sample,
        sample TYPE i,
        path   TYPE string,
        value  TYPE string,
      END OF ty_s_sample.
    TYPES ty_t_sample TYPE STANDARD TABLE OF ty_s_sample WITH DEFAULT KEY.

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
    TYPES ty_t_common TYPE STANDARD TABLE OF ty_s_common WITH DEFAULT KEY.

    TYPES:
      "! A business object value and in how many drafts it occurs.
      BEGIN OF ty_s_object_count,
        object TYPE string,
        value  TYPE string,
        drafts TYPE i,
        field  TYPE string,
      END OF ty_s_object_count.
    TYPES ty_t_object_count TYPE STANDARD TABLE OF ty_s_object_count WITH DEFAULT KEY.

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
    TYPES ty_t_outcome TYPE STANDARD TABLE OF ty_s_outcome WITH DEFAULT KEY.

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
    TYPES ty_t_value TYPE STANDARD TABLE OF ty_s_value WITH DEFAULT KEY.

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
    TYPES ty_t_field TYPE STANDARD TABLE OF ty_s_field WITH DEFAULT KEY.

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
    TYPES ty_t_history TYPE STANDARD TABLE OF ty_s_history WITH DEFAULT KEY.

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
    TYPES ty_t_hit TYPE STANDARD TABLE OF ty_s_hit WITH DEFAULT KEY.

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
    TYPES ty_t_flow TYPE STANDARD TABLE OF ty_s_flow WITH DEFAULT KEY.

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
    TYPES ty_t_growth TYPE STANDARD TABLE OF ty_s_growth WITH DEFAULT KEY.

    TYPES:
      "! A draft, its predecessor and its app - the input of flows_of.
      BEGIN OF ty_s_link,
        id         TYPE c LENGTH 32,
        id_prev    TYPE c LENGTH 32,
        app        TYPE string,
        timestampl TYPE timestampl,
      END OF ty_s_link.
    TYPES ty_t_link TYPE STANDARD TABLE OF ty_s_link WITH DEFAULT KEY.

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

    "! Signs that a user struggled, from the clicks of a session in order:
    "! the same button three times within seconds, the same error box again,
    "! a failed click, the same button again after a long wait, a session
    "! that ended on an error. Each adds to the score; state Error from 5.
    "! @parameter it_signal | the clicks, oldest first
    CLASS-METHODS signals_of
      IMPORTING
        it_signal     TYPE ty_t_signal
      RETURNING
        VALUE(result) TYPE ty_s_signals.

    "! signals_of over the steps of a session - with what the recorder knows
    "! of them (events, error boxes, waits, failed clicks).
    CLASS-METHODS signals_of_steps
      IMPORTING
        it_step       TYPE ty_t_step
      RETURNING
        VALUE(result) TYPE ty_s_signals.

    "! The session told as a story, one line per step: when, in which app,
    "! what the user did, what was shown, how long it took - text for a
    "! ticket. Steps without a recording tell their event.
    CLASS-METHODS story_of
      IMPORTING
        it_step       TYPE ty_t_step
      RETURNING
        VALUE(result) TYPE string.

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

    "! A duration for a person: 850 ms, 1.2 s.
    CLASS-METHODS ms_text
      IMPORTING
        ms            TYPE i
      RETURNING
        VALUE(result) TYPE string.

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
    TYPES ty_t_leaf TYPE STANDARD TABLE OF ty_s_leaf WITH DEFAULT KEY.

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
    TYPES:
      BEGIN OF ty_s_wire_row,
        draft_id      TYPE c LENGTH 32,
        draft_id_prev TYPE c LENGTH 32,
        event         TYPE c LENGTH 40,
        http_status   TYPE i,
        timestampl    TYPE timestampl,
      END OF ty_s_wire_row.
    TYPES:
      BEGIN OF ty_s_wire,
        root        TYPE c LENGTH 32,
        timestampl  TYPE timestampl,
        event       TYPE string,
        http_status TYPE i,
      END OF ty_s_wire.
    TYPES temp1 TYPE HASHED TABLE OF ty_s_agg WITH UNIQUE KEY root.
DATA lt_agg TYPE temp1.
    TYPES temp2 TYPE STANDARD TABLE OF ty_s_agg WITH DEFAULT KEY.
DATA lt_sorted TYPE temp2.
    DATA lt_node TYPE ty_t_node.
    TYPES temp3 TYPE STANDARD TABLE OF ty_id WITH DEFAULT KEY.
DATA lt_failed TYPE temp3.
    DATA lv_oldest TYPE timestampl.
    TYPES temp4 TYPE STANDARD TABLE OF ty_s_wire_row WITH DEFAULT KEY.
DATA lt_wire_row TYPE temp4.
    TYPES temp5 TYPE SORTED TABLE OF ty_s_wire WITH NON-UNIQUE KEY root timestampl.
DATA lt_wire TYPE temp5.
    DATA lt_signal TYPE ty_t_signal.
    DATA lv_key TYPE c LENGTH 32.
        DATA lx TYPE REF TO cx_root.
    DATA temp6 TYPE xsdboolean.
    DATA lt_root TYPE z2ui5_cl_cockpit_session=>ty_t_root.
    DATA ls_node LIKE LINE OF lt_node.
      DATA ls_root TYPE z2ui5_cl_cockpit_session=>ty_s_root.
      FIELD-SYMBOLS <agg> TYPE ty_s_agg.
        DATA temp127 TYPE ty_s_agg.
    DATA lv_failed LIKE LINE OF lt_failed.
    DATA ls_wire_row LIKE LINE OF lt_wire_row.
      DATA temp128 LIKE lv_key.
        DATA temp129 TYPE ty_s_wire.
      DATA lv_since TYPE timestampl.
    DATA lv_reads TYPE i.
    DATA ls_agg LIKE LINE OF lt_sorted.
      DATA temp130 TYPE ty_s_session.
      DATA temp17 TYPE z2ui5_cl_cockpit_session=>ty_s_session-state.
      DATA ls_session LIKE temp130.
      DATA ls_wire LIKE LINE OF lt_wire.
        DATA temp131 TYPE z2ui5_cl_cockpit_session=>ty_s_signal.
      DATA ls_signals TYPE z2ui5_cl_cockpit_session=>ty_s_signals.

    TRY.
        lt_node = read_nodes( ).

      CATCH cx_root INTO lx.
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.
    result-check_readable = abap_true.

    temp6 = boolc( lines( lt_node ) >= c_max_nodes ).
    result-check_capped = temp6.


    lt_root = roots_of( lt_node ).

    LOOP AT lt_node INTO ls_node.

      READ TABLE lt_root INTO ls_root WITH TABLE KEY id = ls_node-id.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      READ TABLE lt_agg ASSIGNING <agg> WITH TABLE KEY root = ls_root-root.
      IF sy-subrc <> 0.

        CLEAR temp127.
        temp127-root = ls_root-root.
        temp127-first = ls_node-timestampl.
        temp127-last = ls_node-timestampl.
        INSERT temp127 INTO TABLE lt_agg ASSIGNING <agg>.
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
        SELECT draft_id_prev FROM z2ui5_t_25 INTO TABLE lt_failed
          WHERE check_error = abap_true
            AND timestampl >= lv_oldest
          .
      CATCH cx_root ##NO_HANDLER.
        " no monitor log - no error counts
    ENDTRY.

    LOOP AT lt_failed INTO lv_failed.
      READ TABLE lt_root INTO ls_root WITH TABLE KEY id = lv_failed.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_agg ASSIGNING <agg> WITH TABLE KEY root = ls_root-root.
      IF sy-subrc = 0.
        <agg>-errors = <agg>-errors + 1.
      ENDIF.
    ENDLOOP.

    " the clicks the recorder kept since the oldest draft - ids and events,
    " no body - each for the session of the draft it started from
    TRY.
        " ORDER BY as in z2ui5_cl_cockpit_wire=>get_variants - without it the
        " 7.02 downport leaves this SELECT half converted
        SELECT draft_id draft_id_prev event http_status timestampl FROM z2ui5_t_28 INTO CORRESPONDING FIELDS OF TABLE lt_wire_row
          WHERE timestampl >= lv_oldest
          ORDER BY timestampl DESCENDING

          UP TO 20000 ROWS.
      CATCH cx_root ##NO_HANDLER.
        " no recorder - no signals
    ENDTRY.

    LOOP AT lt_wire_row INTO ls_wire_row.

      IF ls_wire_row-draft_id_prev IS NOT INITIAL.
        temp128 = ls_wire_row-draft_id_prev.
      ELSE.
        temp128 = ls_wire_row-draft_id.
      ENDIF.
      lv_key = temp128.
      READ TABLE lt_root INTO ls_root WITH TABLE KEY id = lv_key.
      IF sy-subrc = 0.

        CLEAR temp129.
        temp129-root = ls_root-root.
        temp129-timestampl = ls_wire_row-timestampl.
        temp129-event = ls_wire_row-event.
        temp129-http_status = ls_wire_row-http_status.
        INSERT temp129 INTO TABLE lt_wire.
      ENDIF.
    ENDLOOP.

    lt_sorted = lt_agg.
    IF active_minutes > 0.

      lv_since = z2ui5_cl_cockpit_setup=>now_minus_seconds( active_minutes * 60 ).
      DELETE lt_sorted WHERE last < lv_since.
    ENDIF.
    IF check_errors = abap_true.
      DELETE lt_sorted WHERE errors = 0.
    ENDIF.
    SORT lt_sorted BY last DESCENDING root ASCENDING.
    result-sessions = lines( lt_sorted ).

    " the app of a session is in its newest draft - read for as many
    " sessions as are listed, and a few more when a filter skips some

    lv_reads = 0.

    LOOP AT lt_sorted INTO ls_agg.
      IF lines( result-t_session ) >= max_sessions OR lv_reads >= max_sessions * 3.
        EXIT.
      ENDIF.
      lv_reads = lv_reads + 1.


      CLEAR temp130.
      temp130-id = ls_agg-root.
      temp130-user = user_text( ls_agg-uname ).
      temp130-steps = ls_agg-steps.
      temp130-errors = ls_agg-errors.

      IF ls_agg-errors > 0.
        temp17 = `Error`.
      ELSE.
        temp17 = `None`.
      ENDIF.
      temp130-state = temp17.
      temp130-signal_state = `None`.
      temp130-first = z2ui5_cl_cockpit_setup=>ts_text( ls_agg-first ).
      temp130-last = z2ui5_cl_cockpit_setup=>ts_text( ls_agg-last ).
      temp130-duration = duration_text( seconds_between( ts_from = ls_agg-first ts_to = ls_agg-last ) ).

      ls_session = temp130.
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
      CLEAR lt_signal.

      LOOP AT lt_wire INTO ls_wire WHERE root = ls_agg-root.

        CLEAR temp131.
        temp131-timestampl = ls_wire-timestampl.
        temp131-event = ls_wire-event.
        temp131-http_status = ls_wire-http_status.
        APPEND temp131 TO lt_signal.
      ENDLOOP.

      ls_signals = signals_of( lt_signal ).
      ls_session-signals      = ls_signals-text.
      ls_session-signal_state = ls_signals-state.

      IF search IS NOT INITIAL
          AND NOT ( ls_session-app CS search OR ls_session-user CS search ).
        CONTINUE.
      ENDIF.
      APPEND ls_session TO result-t_session.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_steps.

    DATA lt_node TYPE ty_t_node.
        DATA lv_over TYPE i.
        DATA lx TYPE REF TO cx_root.

    TRY.
        lt_node = read_nodes( ).
        result-t_step = steps_of( it_node = lt_node
                                  it_root = roots_of( lt_node )
                                  id      = id ).

        lv_over = lines( result-t_step ) - c_max_steps.
        IF lv_over > 0.
          result-check_capped = abap_true.
          DELETE result-t_step TO lv_over.
        ENDIF.
        fill_steps( CHANGING cs_steps = result ).

      CATCH cx_root INTO lx.
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
    DATA lt_root TYPE z2ui5_cl_cockpit_session=>ty_t_root.
    DATA temp132 TYPE ty_s_root-id.
    DATA lv_id LIKE temp132.
    DATA ls_root TYPE z2ui5_cl_cockpit_session=>ty_s_root.

    TRY.
        lt_node = read_nodes( ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    lt_root = roots_of( lt_node ).

    temp132 = draft_id.

    lv_id = temp132.

    READ TABLE lt_root INTO ls_root WITH TABLE KEY id = lv_id.
    IF sy-subrc = 0.
      result = ls_root-root.
    ENDIF.

  ENDMETHOD.

  METHOD get_view.

    DATA lv_new TYPE string.
    DATA lv_old TYPE string.
    DATA lt_old TYPE ty_t_value.
        DATA lx TYPE REF TO cx_root.
    DATA lt_new TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA lt_field TYPE z2ui5_cl_cockpit_session=>ty_t_field.
    DATA temp7 TYPE xsdboolean.
    DATA ls_field LIKE LINE OF lt_field.

    TRY.
        lv_new = read_data( id ).
        IF id_prev IS NOT INITIAL.
          lv_old = read_data( id_prev ).
        ENDIF.

      CATCH cx_root INTO lx.
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.
    IF lv_new IS INITIAL.
      result-error = `The draft of this step is gone - expired and deleted since the session was opened.`.
      RETURN.
    ENDIF.

    result-app = app_of( lv_new ).

    lt_new = flatten( xml       = lv_new
                            check_all = check_all ).
    IF id_prev IS NOT INITIAL.
      lt_old = flatten( xml       = lv_old
                        check_all = check_all ).
    ENDIF.


    temp7 = boolc( id_prev IS INITIAL ).
    lt_field = diff( it_new      = lt_new
                           it_old      = lt_old
                           check_first = temp7 ).

    result-fields = lines( lt_field ).

    LOOP AT lt_field INTO ls_field.
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

    DATA ls_steps TYPE z2ui5_cl_cockpit_session=>ty_s_steps.
    DATA lv_nl LIKE cl_abap_char_utilities=>newline.
    DATA temp133 LIKE LINE OF lt_lines.
    DATA temp134 LIKE LINE OF lt_lines.
      DATA temp135 LIKE LINE OF lt_lines.
      DATA temp136 LIKE LINE OF lt_lines.
    DATA temp137 TYPE string.
    DATA temp18 LIKE LINE OF lt_lines.
    DATA ls_business LIKE LINE OF ls_steps-t_business.
      DATA temp138 LIKE LINE OF lt_lines.
    DATA ls_step LIKE LINE OF ls_steps-t_step.
      DATA temp139 TYPE string.
      DATA temp19 TYPE string.
      DATA temp1 LIKE LINE OF lt_lines.
        DATA temp140 LIKE LINE OF lt_lines.
        DATA temp141 LIKE LINE OF lt_lines.
        DATA temp142 LIKE LINE OF lt_lines.
        FIELD-SYMBOLS <temp143> LIKE LINE OF ls_steps-t_step.
        DATA temp144 LIKE sy-tabix.
          DATA lv_xml TYPE string.
          DATA lx TYPE REF TO cx_root.
          DATA temp145 LIKE LINE OF lt_lines.
      DATA lt_field TYPE z2ui5_cl_cockpit_session=>ty_t_field.
      DATA temp8 TYPE xsdboolean.
      DATA lv_changes TYPE i.
      DATA ls_field LIKE LINE OF lt_field.
            DATA temp146 LIKE LINE OF lt_lines.
            DATA temp147 LIKE LINE OF lt_lines.
            DATA temp148 LIKE LINE OF lt_lines.
              DATA temp149 LIKE LINE OF lt_lines.
    ls_steps = get_steps( id ).

    lv_nl = cl_abap_char_utilities=>newline.

    temp133 = |abap2UI5 session { id }|.
    APPEND temp133 TO lt_lines.

    temp134 = |exported { z2ui5_cl_cockpit_setup=>ts_text( z2ui5_cl_cockpit_setup=>now( ) ) } UTC by { sy-uname }|.
    APPEND temp134 TO lt_lines.
    IF user IS NOT INITIAL.

      temp135 = |user: { user }|.
      APPEND temp135 TO lt_lines.
    ENDIF.
    IF ls_steps-error IS NOT INITIAL.

      temp136 = |The session could not be read: { ls_steps-error }|.
      APPEND temp136 TO lt_lines.
    ENDIF.

    IF ls_steps-check_capped = abap_true.
      temp137 = | (the newest { c_max_steps })|.
    ELSE.
      CLEAR temp137.
    ENDIF.

    temp18 = |{ lines( ls_steps-t_step ) } steps{ temp137 }|.
    APPEND temp18 TO lt_lines.

    LOOP AT ls_steps-t_business INTO ls_business.
      IF sy-tabix = 1.
        APPEND `business objects:` TO lt_lines.
      ENDIF.

      temp138 = |   { ls_business-object } { ls_business-value } (step { ls_business-step }, { ls_business-field })|.
      APPEND temp138 TO lt_lines.
    ENDLOOP.


    LOOP AT ls_steps-t_step INTO ls_step.
      APPEND `` TO lt_lines.

      IF ls_step-delta IS NOT INITIAL.
        temp139 = | ({ ls_step-delta })|.
      ELSE.
        CLEAR temp139.
      ENDIF.

      IF ls_step-event IS NOT INITIAL.
        temp19 = | - event { ls_step-event }|.
      ELSE.
        CLEAR temp19.
      ENDIF.

      temp1 = |== Step { ls_step-step } - { ls_step-time } UTC{ temp139 }| && | - { ls_step-app }{ temp19 }|.
      APPEND temp1 TO lt_lines.
      IF ls_step-note IS NOT INITIAL.

        temp140 = |   { ls_step-note }|.
        APPEND temp140 TO lt_lines.
      ENDIF.
      IF ls_step-monitor IS NOT INITIAL.

        temp141 = |   monitor: { ls_step-monitor }|.
        APPEND temp141 TO lt_lines.
      ENDIF.
      IF ls_step-messages IS NOT INITIAL.

        temp142 = |   messages in the app: { ls_step-messages }|.
        APPEND temp142 TO lt_lines.
      ENDIF.

      CLEAR lt_old.
      CLEAR lv_prev.
      IF ls_step-follows > 0.


        temp144 = sy-tabix.
        READ TABLE ls_steps-t_step INDEX ls_step-follows ASSIGNING <temp143>.
        sy-tabix = temp144.
        IF sy-subrc <> 0.
          ASSERT 1 = 0.
        ENDIF.
        lv_prev = <temp143>-id.
      ENDIF.
      TRY.

          lv_xml = read_data( ls_step-id ).
          IF lv_prev IS NOT INITIAL.
            lt_old = flatten( read_data( lv_prev ) ).
          ENDIF.

        CATCH cx_root INTO lx.

          temp145 = |   not readable: { lx->get_text( ) }|.
          APPEND temp145 TO lt_lines.
          CONTINUE.
      ENDTRY.
      IF lv_xml IS INITIAL.
        APPEND `   the draft is gone` TO lt_lines.
        CONTINUE.
      ENDIF.



      temp8 = boolc( lv_prev IS INITIAL ).
      lt_field = diff( it_new      = flatten( lv_xml )
                             it_old      = lt_old
                             check_first = temp8 ).

      lv_changes = 0.

      LOOP AT lt_field INTO ls_field.
        CASE ls_field-change.
          WHEN cs_change-changed.

            temp146 = |   changed  { ls_field-path } = { cut( ls_field-value ) }   (before: { cut( ls_field-prev ) })|.
            APPEND temp146 TO lt_lines.
          WHEN cs_change-new.

            temp147 = |   new      { ls_field-path } = { cut( ls_field-value ) }|.
            APPEND temp147 TO lt_lines.
          WHEN cs_change-removed.

            temp148 = |   removed  { ls_field-path }   (was: { cut( ls_field-prev ) })|.
            APPEND temp148 TO lt_lines.
          WHEN OTHERS.
            IF lv_prev IS INITIAL.

              temp149 = |   { ls_field-path } = { cut( ls_field-value ) }|.
              APPEND temp149 TO lt_lines.
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

    DATA ls_step LIKE LINE OF it_step.
          DATA lv_xml TYPE string.
      DATA temp150 TYPE ty_s_history.
      DATA ls_history LIKE temp150.
      DATA temp151 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
      DATA ls_value LIKE LINE OF temp151.
    LOOP AT it_step INTO ls_step.
      TRY.

          lv_xml = read_data( ls_step-id ).
        CATCH cx_root.
          CONTINUE.
      ENDTRY.
      IF lv_xml IS INITIAL.
        CONTINUE.
      ENDIF.


      CLEAR temp150.
      temp150-step = ls_step-step.
      temp150-time = ls_step-time.
      temp150-value = `(not there)`.
      temp150-state = `None`.

      ls_history = temp150.

      temp151 = flatten( xml = lv_xml check_all = check_all ).

      LOOP AT temp151 INTO ls_value WHERE path = path. "#EC CI_SORTSEQ
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
    TYPES temp6 TYPE STANDARD TABLE OF ty_s_row WITH DEFAULT KEY.
DATA lt_rows TYPE temp6.
    TYPES temp7 TYPE HASHED TABLE OF ty_s_meta WITH UNIQUE KEY id.
DATA lt_meta TYPE temp7.
    DATA lt_node TYPE ty_t_node.
    DATA lv_last TYPE c LENGTH 32.
    DATA lv_tab TYPE string.
    DATA lv_search TYPE string.
        DATA lx TYPE REF TO cx_root.
    DATA lt_root TYPE z2ui5_cl_cockpit_session=>ty_t_root.
    DATA ls_node LIKE LINE OF lt_node.
      DATA temp152 TYPE ty_s_meta.
    DATA lv_prefilter TYPE abap_bool.
    DATA temp9 TYPE xsdboolean.
      DATA ls_row LIKE LINE OF lt_rows.
        DATA lv_matched LIKE abap_false.
        DATA temp153 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
        DATA ls_value LIKE LINE OF temp153.
          DATA ls_meta TYPE ty_s_meta.
          DATA ls_root TYPE z2ui5_cl_cockpit_session=>ty_s_root.
          DATA temp154 TYPE z2ui5_cl_cockpit_session=>ty_s_hit.
          DATA temp20 TYPE z2ui5_cl_cockpit_session=>ty_s_hit-session.

    lv_search = condense( search ).
    IF strlen( lv_search ) < c_min_search.
      result-error = |Enter at least { c_min_search } characters.|.
      RETURN.
    ENDIF.

    TRY.
        lt_node = read_nodes( ).

      CATCH cx_root INTO lx.
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.

    lt_root = roots_of( lt_node ).

    LOOP AT lt_node INTO ls_node.

      CLEAR temp152.
      temp152-id = ls_node-id.
      temp152-uname = ls_node-uname.
      temp152-timestampl = ls_node-timestampl.
      INSERT temp152 INTO TABLE lt_meta.
    ENDLOOP.

    " the serialized text escapes <, > and &, so a term with one of them
    " is only found in the decoded fields - every draft is taken apart then


    temp9 = boolc( lv_search NA `<>&"'` ).
    lv_prefilter = temp9.
    lv_tab = z2ui5_cl_cockpit_inst=>obj_name( z2ui5_cl_cockpit_draft=>c_table ).
    DO.
      CLEAR lt_rows.
      TRY.
          SELECT id data FROM (lv_tab) INTO CORRESPONDING FIELDS OF TABLE lt_rows
            WHERE id > lv_last
            ORDER BY id

            UP TO 200 ROWS.
        CATCH cx_root INTO lx.
          result-error = lx->get_text( ).
          RETURN.
      ENDTRY.
      IF lt_rows IS INITIAL.
        EXIT.
      ENDIF.


      LOOP AT lt_rows INTO ls_row.
        lv_last = ls_row-id.
        result-drafts = result-drafts + 1.
        IF lv_prefilter = abap_true AND ls_row-data NS lv_search.
          CONTINUE.
        ENDIF.

        lv_matched = abap_false.

        temp153 = flatten( ls_row-data ).

        LOOP AT temp153 INTO ls_value.
          IF ls_value-value NS lv_search.
            CONTINUE.
          ENDIF.
          lv_matched = abap_true.
          IF lines( result-t_hit ) >= c_max_hits.
            result-check_capped = abap_true.
            EXIT.
          ENDIF.

          READ TABLE lt_meta INTO ls_meta WITH TABLE KEY id = ls_row-id.

          READ TABLE lt_root INTO ls_root WITH TABLE KEY id = ls_row-id.

          CLEAR temp154.
          temp154-nr = lines( result-t_hit ) + 1.

          IF ls_root-root IS NOT INITIAL.
            temp20 = ls_root-root.
          ELSE.
            temp20 = ls_row-id.
          ENDIF.
          temp154-session = temp20.
          temp154-id = ls_row-id.
          temp154-time = z2ui5_cl_cockpit_setup=>ts_text( ls_meta-timestampl ).
          temp154-user = user_text( ls_meta-uname ).
          temp154-app = app_of( ls_row-data ).
          temp154-path = ls_value-path.
          temp154-value = cut( ls_value-value ).
          APPEND temp154 TO result-t_hit.
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
    TYPES temp8 TYPE STANDARD TABLE OF ty_s_row WITH DEFAULT KEY.
DATA lt_rows TYPE temp8.
    DATA lt_link TYPE ty_t_link.
    TYPES temp9 TYPE STANDARD TABLE OF ty_id WITH DEFAULT KEY.
DATA lt_ids TYPE temp9.
    DATA lt_failed TYPE ty_t_id.
    DATA lv_oldest TYPE timestampl.
    DATA lv_last TYPE c LENGTH 32.
    DATA lv_tab TYPE string.
          DATA lx TYPE REF TO cx_root.
      DATA ls_row LIKE LINE OF lt_rows.
        DATA temp155 TYPE z2ui5_cl_cockpit_session=>ty_s_link.
    DATA lv_id LIKE LINE OF lt_ids.
      DATA temp156 LIKE LINE OF lt_failed.

    lv_tab = z2ui5_cl_cockpit_inst=>obj_name( z2ui5_cl_cockpit_draft=>c_table ).
    DO.
      CLEAR lt_rows.
      TRY.
          SELECT id id_prev timestampl data FROM (lv_tab) INTO CORRESPONDING FIELDS OF TABLE lt_rows
            WHERE id > lv_last
            ORDER BY id

            UP TO 200 ROWS.

        CATCH cx_root INTO lx.
          result-error = lx->get_text( ).
          RETURN.
      ENDTRY.
      IF lt_rows IS INITIAL.
        EXIT.
      ENDIF.

      LOOP AT lt_rows INTO ls_row.
        lv_last = ls_row-id.

        CLEAR temp155.
        temp155-id = ls_row-id.
        temp155-id_prev = ls_row-id_prev.
        temp155-timestampl = ls_row-timestampl.
        temp155-app = app_of( ls_row-data ).
        APPEND temp155 TO lt_link.
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
        SELECT draft_id_prev FROM z2ui5_t_25 INTO TABLE lt_ids
          WHERE check_error = abap_true
            AND timestampl >= lv_oldest
          .
      CATCH cx_root ##NO_HANDLER.
        " no monitor log - every end is a plain end
    ENDTRY.

    LOOP AT lt_ids INTO lv_id.

      temp156 = lv_id.
      APPEND temp156 TO lt_failed.
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
    TYPES temp10 TYPE HASHED TABLE OF ty_s_app WITH UNIQUE KEY id.
DATA lt_app TYPE temp10.
    TYPES temp11 TYPE HASHED TABLE OF ty_s_count WITH UNIQUE KEY source target.
DATA lt_count TYPE temp11.
    TYPES temp12 TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_prev TYPE temp12.
    TYPES temp13 TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_failed TYPE temp13.
    DATA lv_source TYPE string.
    DATA lv_target TYPE string.

    DATA ls_link LIKE LINE OF it_link.
      DATA temp157 TYPE ty_s_app.
      DATA temp21 TYPE ty_s_app-app.
        DATA temp158 LIKE LINE OF lt_prev.
    DATA lv_failed LIKE LINE OF it_failed.
      DATA temp159 TYPE string.
      DATA lv_link_id LIKE temp159.
      DATA temp160 LIKE sy-subrc.
      DATA temp161 LIKE sy-subrc.
        DATA temp162 TYPE string.
        DATA temp163 TYPE string.
        DATA temp22 LIKE sy-subrc.
        DATA temp23 LIKE sy-subrc.
        FIELD-SYMBOLS <end> TYPE ty_s_count.
          DATA temp164 TYPE ty_s_count.
      DATA temp165 TYPE string.
        DATA ls_prev TYPE ty_s_app.
      FIELD-SYMBOLS <count> TYPE ty_s_count.
        DATA temp166 TYPE ty_s_count.
    DATA ls_count LIKE LINE OF lt_count.
      DATA temp167 TYPE z2ui5_cl_cockpit_session=>ty_s_flow.
    LOOP AT it_link INTO ls_link.

      CLEAR temp157.
      temp157-id = ls_link-id.

      IF ls_link-app IS NOT INITIAL.
        temp21 = ls_link-app.
      ELSE.
        temp21 = `(unknown)`.
      ENDIF.
      temp157-app = temp21.
      INSERT temp157
             INTO TABLE lt_app.
      IF ls_link-id_prev IS NOT INITIAL.

        temp158 = ls_link-id_prev.
        INSERT temp158 INTO TABLE lt_prev.
      ENDIF.
    ENDLOOP.

    LOOP AT it_failed INTO lv_failed.
      INSERT lv_failed INTO TABLE lt_failed.
    ENDLOOP.

    LOOP AT it_link INTO ls_link.

      temp159 = ls_link-id.

      lv_link_id = temp159.
      " the last step of a session that is over: where the user left


      temp161 = sy-subrc.
      READ TABLE lt_prev WITH KEY table_line = lv_link_id TRANSPORTING NO FIELDS.
      temp160 = sy-subrc.
      sy-subrc = temp161.
      IF ended_before IS NOT INITIAL
          AND ls_link-timestampl < ended_before
          AND NOT temp160 = 0.

        IF ls_link-app IS NOT INITIAL.
          temp162 = ls_link-app.
        ELSE.
          temp162 = `(unknown)`.
        ENDIF.
        lv_source = temp162.



        temp23 = sy-subrc.
        READ TABLE lt_failed WITH KEY table_line = lv_link_id TRANSPORTING NO FIELDS.
        temp22 = sy-subrc.
        sy-subrc = temp23.
        IF temp22 = 0.
          temp163 = `(end after an error)`.
        ELSE.
          temp163 = `(end)`.
        ENDIF.
        lv_target = temp163.

        READ TABLE lt_count ASSIGNING <end> WITH TABLE KEY source = lv_source target = lv_target.
        IF sy-subrc <> 0.

          CLEAR temp164.
          temp164-source = lv_source.
          temp164-target = lv_target.
          INSERT temp164 INTO TABLE lt_count ASSIGNING <end>.
        ENDIF.
        <end>-count = <end>-count + 1.
      ENDIF.


      IF ls_link-app IS NOT INITIAL.
        temp165 = ls_link-app.
      ELSE.
        temp165 = `(unknown)`.
      ENDIF.
      lv_target = temp165.
      IF ls_link-id_prev IS INITIAL.
        lv_source = `(start)`.
      ELSE.

        READ TABLE lt_app INTO ls_prev WITH TABLE KEY id = ls_link-id_prev.
        IF sy-subrc <> 0.
          " the predecessor expired - neither a start nor a known navigation
          CONTINUE.
        ENDIF.
        IF ls_prev-app = lv_target.
          CONTINUE.
        ENDIF.
        lv_source = ls_prev-app.
      ENDIF.

      READ TABLE lt_count ASSIGNING <count> WITH TABLE KEY source = lv_source target = lv_target.
      IF sy-subrc <> 0.

        CLEAR temp166.
        temp166-source = lv_source.
        temp166-target = lv_target.
        INSERT temp166 INTO TABLE lt_count ASSIGNING <count>.
      ENDIF.
      <count>-count = <count>-count + 1.
    ENDLOOP.


    LOOP AT lt_count INTO ls_count.

      CLEAR temp167.
      temp167-source = ls_count-source.
      temp167-target = ls_count-target.
      temp167-count = ls_count-count.
      APPEND temp167 TO result.
    ENDLOOP.
    SORT result BY count DESCENDING source ASCENDING target ASCENDING.

  ENDMETHOD.

  METHOD get_growth.
        DATA lv_before TYPE string.
        DATA lv_after TYPE string.

    TRY.

        lv_before = read_data( id_before ).

        lv_after = read_data( id_after ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
    IF lv_before IS INITIAL OR lv_after IS INITIAL.
      RETURN.
    ENDIF.
    result = growth_of( it_before = flatten( lv_before )
                        it_after  = flatten( lv_after ) ).

  ENDMETHOD.

  METHOD signals_of.

    TYPES:
      BEGIN OF ty_s_count,
        text  TYPE string,
        count TYPE i,
      END OF ty_s_count.
    TYPES temp14 TYPE HASHED TABLE OF ty_s_count WITH UNIQUE KEY text.
DATA lt_error TYPE temp14.
    DATA lv_run TYPE i.
    DATA lv_run_from TYPE timestampl.
    DATA lv_failed TYPE i.
    DATA lv_rage TYPE string.
    DATA lv_again TYPE string.
    DATA ls_prev TYPE ty_s_signal.
    DATA lt_reason TYPE string_table.

    DATA ls_signal LIKE LINE OF it_signal.
      DATA lv_index LIKE sy-tabix.
        DATA temp168 TYPE ty_s_count.
        FIELD-SYMBOLS <error> TYPE ty_s_count.
    DATA ls_error LIKE LINE OF lt_error.
      DATA temp169 LIKE LINE OF lt_reason.
      DATA temp170 TYPE string.
      DATA temp24 LIKE LINE OF lt_reason.
    DATA lv_reason LIKE LINE OF lt_reason.
      DATA temp171 TYPE string.
    DATA temp172 TYPE z2ui5_cl_cockpit_session=>ty_s_signals-state.
    LOOP AT it_signal INTO ls_signal.

      lv_index = sy-tabix.

      " the same button again and again, each within 10 seconds
      IF lv_index > 1 AND ls_signal-event IS NOT INITIAL AND ls_signal-event = ls_prev-event
          AND seconds_between( ts_from = ls_prev-timestampl
                               ts_to   = ls_signal-timestampl ) <= 10.
        lv_run = lv_run + 1.
        " the run as it grows - the longest one stays
        IF lv_run >= 3.
          lv_rage = |pressed { ls_signal-event } { lv_run } times in | &&
                    |{ seconds_between( ts_from = lv_run_from
                                        ts_to   = ls_signal-timestampl ) } s|.
        ENDIF.
      ELSE.
        lv_run = 1.
        lv_run_from = ls_signal-timestampl.
      ENDIF.

      " the same button again right after a long wait - impatience
      IF lv_index > 1 AND lv_again IS INITIAL AND ls_signal-event IS NOT INITIAL
          AND ls_signal-event = ls_prev-event AND ls_prev-ms_browser >= 5000.
        lv_again = |pressed { ls_signal-event } again after waiting { ls_prev-ms_browser DIV 1000 } s|.
      ENDIF.

      IF ls_signal-http_status >= 500.
        lv_failed = lv_failed + 1.
      ENDIF.
      IF ls_signal-error_text IS NOT INITIAL.

        CLEAR temp168.
        temp168-text = ls_signal-error_text.
        INSERT temp168 INTO TABLE lt_error.

        READ TABLE lt_error ASSIGNING <error> WITH TABLE KEY text = ls_signal-error_text.
        <error>-count = <error>-count + 1.
      ENDIF.
      ls_prev = ls_signal.
    ENDLOOP.

    IF lv_rage IS NOT INITIAL.
      APPEND lv_rage TO lt_reason.
      result-score = result-score + 3.
    ENDIF.

    LOOP AT lt_error INTO ls_error WHERE count >= 2.

      temp169 = |error "{ ls_error-text }" { ls_error-count } times|.
      APPEND temp169 TO lt_reason.
      result-score = result-score + 2.
    ENDLOOP.
    IF lv_failed > 0.

      IF lv_failed > 1.
        temp170 = `s`.
      ELSE.
        CLEAR temp170.
      ENDIF.

      temp24 = |{ lv_failed } failed click{ temp170 }|.
      APPEND temp24 TO lt_reason.
      result-score = result-score + 2 * lv_failed.
    ENDIF.
    IF lv_again IS NOT INITIAL.
      APPEND lv_again TO lt_reason.
      result-score = result-score + 1.
    ENDIF.
    IF ls_prev-http_status >= 500 OR ls_prev-error_text IS NOT INITIAL.
      APPEND `ended on an error` TO lt_reason.
      result-score = result-score + 3.
    ENDIF.


    LOOP AT lt_reason INTO lv_reason.

      IF result-text IS NOT INITIAL.
        temp171 = `; `.
      ELSE.
        CLEAR temp171.
      ENDIF.
      result-text = |{ result-text }{ temp171 }{ lv_reason }|.
    ENDLOOP.

    IF result-score >= 5.
      temp172 = `Error`.
    ELSEIF result-score > 0.
      temp172 = `Warning`.
    ELSE.
      temp172 = `None`.
    ENDIF.
    result-state = temp172.

  ENDMETHOD.

  METHOD signals_of_steps.

    DATA lt_signal TYPE ty_t_signal.

    DATA ls_step LIKE LINE OF it_step.
        DATA temp173 TYPE z2ui5_cl_cockpit_session=>ty_s_signal.
        DATA temp25 TYPE z2ui5_cl_cockpit_session=>ty_s_signal-error_text.
        DATA temp174 TYPE z2ui5_cl_cockpit_session=>ty_s_signal.
    LOOP AT it_step INTO ls_step.
      IF sy-tabix > 1 OR ls_step-wire_id IS NOT INITIAL.

        CLEAR temp173.
        temp173-timestampl = ls_step-timestampl.
        temp173-event = ls_step-event.
        temp173-ms_browser = ls_step-ms_browser.

        IF ls_step-shown_state = `Error`.
          temp25 = ls_step-shown.
        ELSE.
          CLEAR temp25.
        ENDIF.
        temp173-error_text = temp25.
        APPEND temp173 TO lt_signal.
      ENDIF.
      " the click that failed after it wrote no step of its own
      IF ls_step-wire_fail_id IS NOT INITIAL.

        CLEAR temp174.
        temp174-timestampl = ls_step-timestampl.
        temp174-event = ls_step-wire_fail_event.
        temp174-http_status = 500.
        APPEND temp174 TO lt_signal.
      ENDIF.
    ENDLOOP.
    result = signals_of( lt_signal ).

  ENDMETHOD.

  METHOD story_of.

    DATA lv_app TYPE string.
    DATA lv_nl LIKE cl_abap_char_utilities=>newline.
    DATA ls_step LIKE LINE OF it_step.
      DATA lv_index LIKE sy-tabix.
      DATA lv_time LIKE ls_step-time.
      DATA lv_line TYPE string.
      DATA temp175 TYPE string.
    lv_nl = cl_abap_char_utilities=>newline.


    LOOP AT it_step INTO ls_step.

      lv_index = sy-tabix.

      lv_time = ls_step-time.
      IF strlen( lv_time ) >= 19.
        lv_time = substring( val = lv_time
                             off = 11
                             len = 8 ).
      ENDIF.

      lv_line = |{ lv_time }  |.
      IF ls_step-app <> lv_app.
        lv_line = |{ lv_line }[{ ls_step-app }] |.
        lv_app = ls_step-app.
      ENDIF.

      IF ls_step-did IS NOT INITIAL.
        temp175 = ls_step-did.
      ELSEIF ls_step-event IS NOT INITIAL.
        temp175 = |event { ls_step-event }|.
      ELSEIF lv_index = 1.
        temp175 = `started`.
      ELSE.
        temp175 = `(no event recorded)`.
      ENDIF.
      lv_line = lv_line && temp175.
      IF ls_step-shown IS NOT INITIAL.
        lv_line = |{ lv_line } -> { ls_step-shown }|.
      ENDIF.
      IF ls_step-ms_text IS NOT INITIAL.
        lv_line = |{ lv_line } ({ ls_step-ms_text })|.
      ENDIF.
      IF ls_step-note IS NOT INITIAL.
        lv_line = |{ lv_line } - { ls_step-note }|.
      ENDIF.
      result = |{ result }{ lv_line }{ lv_nl }|.
    ENDLOOP.

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
    TYPES temp15 TYPE HASHED TABLE OF ty_s_row WITH UNIQUE KEY tab row.
DATA lt_row TYPE temp15.
    TYPES temp16 TYPE HASHED TABLE OF ty_s_count WITH UNIQUE KEY tab.
DATA lt_count TYPE temp16.
    DATA lt_values TYPE ty_t_value.
    DATA lv_pos TYPE i.
      DATA lv_pass LIKE sy-index.
      DATA temp176 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
      DATA ls_value LIKE LINE OF lt_values.
          DATA lv_close TYPE i.
          DATA lv_prefix TYPE string.
          DATA lv_open TYPE i.
          DATA temp177 TYPE ty_s_row.
      DATA ls_row LIKE LINE OF lt_row.
        FIELD-SYMBOLS <count> TYPE ty_s_count.
          DATA temp178 TYPE ty_s_count.
    DATA ls_count LIKE LINE OF lt_count.
      DATA temp179 TYPE z2ui5_cl_cockpit_session=>ty_s_growth.

    DO 2 TIMES.

      lv_pass = sy-index.
      CLEAR lt_row.

      IF lv_pass = 1.
        temp176 = it_before.
      ELSE.
        temp176 = it_after.
      ENDIF.
      lt_values = temp176.

      LOOP AT lt_values INTO ls_value.
        " every [n] of the path is a row of the table the path names up to it
        lv_pos = 0.
        DO.

          lv_close = find( val = ls_value-path
                                 sub = `]`
                                 off = lv_pos ).
          IF lv_close < 0.
            EXIT.
          ENDIF.

          lv_prefix = substring( val = ls_value-path
                                       len = lv_close + 1 ).

          lv_open = find( val = lv_prefix
                                sub = `[`
                                occ = -1 ).
          lv_pos = lv_close + 1.
          IF lv_open <= 0.
            CONTINUE.
          ENDIF.

          CLEAR temp177.
          temp177-tab = substring( val = lv_prefix len = lv_open ).
          temp177-row = lv_prefix.
          INSERT temp177 INTO TABLE lt_row.
        ENDDO.
      ENDLOOP.


      LOOP AT lt_row INTO ls_row.

        READ TABLE lt_count ASSIGNING <count> WITH TABLE KEY tab = ls_row-tab.
        IF sy-subrc <> 0.

          CLEAR temp178.
          temp178-tab = ls_row-tab.
          INSERT temp178 INTO TABLE lt_count ASSIGNING <count>.
        ENDIF.
        IF lv_pass = 1.
          <count>-before = <count>-before + 1.
        ELSE.
          <count>-after = <count>-after + 1.
        ENDIF.
      ENDLOOP.
    ENDDO.


    LOOP AT lt_count INTO ls_count.
      IF ls_count-after <= ls_count-before.
        CONTINUE.
      ENDIF.

      CLEAR temp179.
      temp179-path = ls_count-tab.
      temp179-rows_before = ls_count-before.
      temp179-rows_after = ls_count-after.
      APPEND temp179 TO result.
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
    TYPES temp17 TYPE HASHED TABLE OF ty_s_meta WITH UNIQUE KEY id.
DATA lt_meta TYPE temp17.
    TYPES temp18 TYPE HASHED TABLE OF ty_id WITH UNIQUE KEY table_line.
DATA lt_prev TYPE temp18.
    DATA lv_key TYPE ty_id.

    DATA ls_node LIKE LINE OF it_node.
      DATA temp180 TYPE ty_s_meta.
    DATA lv_id LIKE LINE OF it_id.
      DATA temp181 TYPE ty_s_outcome.
      DATA ls_outcome LIKE temp181.
      DATA ls_meta TYPE ty_s_meta.
      DATA lv_found TYPE abap_bool.
      DATA temp10 TYPE xsdboolean.
      DATA temp182 LIKE sy-subrc.
      DATA temp183 LIKE sy-subrc.
    LOOP AT it_node INTO ls_node.

      CLEAR temp180.
      temp180-id = ls_node-id.
      temp180-timestampl = ls_node-timestampl.
      INSERT temp180 INTO TABLE lt_meta.
      IF ls_node-id_prev IS NOT INITIAL.
        INSERT ls_node-id_prev INTO TABLE lt_prev.
      ENDIF.
    ENDLOOP.


    LOOP AT it_id INTO lv_id.
      lv_key = lv_id.

      CLEAR temp181.
      temp181-id = lv_id.

      ls_outcome = temp181.

      READ TABLE lt_meta INTO ls_meta WITH TABLE KEY id = lv_key.
      " kept at once: the downport turns the line_exists( ) below into a READ
      " TABLE in front of this IF, which would overwrite sy-subrc


      temp10 = boolc( sy-subrc = 0 ).
      lv_found = temp10.


      temp183 = sy-subrc.
      READ TABLE lt_prev WITH KEY table_line = lv_key TRANSPORTING NO FIELDS.
      temp182 = sy-subrc.
      sy-subrc = temp183.
      IF lv_key IS INITIAL OR lv_found = abap_false.
        ls_outcome-outcome = cs_outcome-unknown.
        ls_outcome-state   = `None`.
      ELSEIF temp182 = 0.
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
    TYPES temp19 TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_done TYPE temp19.
    TYPES temp20 TYPE HASHED TABLE OF ty_s_seen WITH UNIQUE KEY object value.
DATA lt_seen TYPE temp20.
    DATA lv_xml TYPE string.
        DATA lv_id LIKE LINE OF it_id.
          DATA temp184 TYPE z2ui5_cl_cockpit_session=>ty_t_business.
          DATA ls_business LIKE LINE OF temp184.
            DATA temp185 TYPE ty_s_seen.
            FIELD-SYMBOLS <object> TYPE z2ui5_cl_cockpit_session=>ty_s_object_count.
              DATA temp186 TYPE z2ui5_cl_cockpit_session=>ty_s_object_count.
        DATA lt_other_ids TYPE z2ui5_cl_cockpit_session=>ty_t_id.
        DATA lx TYPE REF TO cx_root.

    TRY.

        LOOP AT it_id INTO lv_id.
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

          temp184 = business_of( flatten( lv_xml ) ).

          LOOP AT temp184 INTO ls_business.

            CLEAR temp185.
            temp185-object = ls_business-object.
            temp185-value = ls_business-value.
            INSERT temp185 INTO TABLE lt_seen.
            IF sy-subrc <> 0.
              CONTINUE.
            ENDIF.

            READ TABLE result-t_business ASSIGNING <object>
                 WITH KEY object = ls_business-object value = ls_business-value. "#EC CI_SORTSEQ
            IF sy-subrc <> 0.

              CLEAR temp186.
              temp186-object = ls_business-object.
              temp186-value = ls_business-value.
              temp186-field = ls_business-field.
              APPEND temp186 TO result-t_business ASSIGNING <object>.
            ENDIF.
            <object>-drafts = <object>-drafts + 1.
          ENDLOOP.
        ENDLOOP.
        SORT result-t_business BY drafts DESCENDING object ASCENDING value ASCENDING.

        IF result-failing < 2.
          RETURN.
        ENDIF.


        lt_other_ids = scan_app( app      = app
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

      CATCH cx_root INTO lx.
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
    TYPES temp21 TYPE HASHED TABLE OF ty_s_count WITH UNIQUE KEY path value.
DATA lt_failing TYPE temp21.
    TYPES temp22 TYPE HASHED TABLE OF ty_s_count WITH UNIQUE KEY path value.
DATA lt_others TYPE temp22.
    TYPES temp23 TYPE HASHED TABLE OF ty_s_key WITH UNIQUE KEY sample path value.
DATA lt_once TYPE temp23.
    TYPES temp24 TYPE STANDARD TABLE OF ty_s_rank WITH DEFAULT KEY.
DATA lt_rank TYPE temp24.
    DATA lv_failing TYPE i.
    DATA lv_others TYPE i.
    DATA lv_pct TYPE i.

    DATA ls_sample LIKE LINE OF it_failing.
      DATA temp187 TYPE ty_s_key.
      FIELD-SYMBOLS <count> TYPE ty_s_count.
        DATA temp188 TYPE ty_s_count.
      DATA temp189 TYPE ty_s_key.
        DATA temp190 TYPE ty_s_count.
    DATA ls_count LIKE LINE OF lt_failing.
      DATA ls_other TYPE ty_s_count.
      DATA temp191 TYPE ty_s_rank.
    DATA ls_rank LIKE LINE OF lt_rank.
    LOOP AT it_failing INTO ls_sample.
      IF ls_sample-sample > lv_failing.
        lv_failing = ls_sample-sample.
      ENDIF.

      CLEAR temp187.
      temp187-sample = ls_sample-sample.
      temp187-path = ls_sample-path.
      temp187-value = ls_sample-value.
      INSERT temp187 INTO TABLE lt_once.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      READ TABLE lt_failing ASSIGNING <count> WITH TABLE KEY path = ls_sample-path value = ls_sample-value.
      IF sy-subrc <> 0.

        CLEAR temp188.
        temp188-path = ls_sample-path.
        temp188-value = ls_sample-value.
        INSERT temp188 INTO TABLE lt_failing ASSIGNING <count>.
      ENDIF.
      <count>-count = <count>-count + 1.
    ENDLOOP.

    CLEAR lt_once.
    LOOP AT it_others INTO ls_sample.
      IF ls_sample-sample > lv_others.
        lv_others = ls_sample-sample.
      ENDIF.

      CLEAR temp189.
      temp189-sample = ls_sample-sample.
      temp189-path = ls_sample-path.
      temp189-value = ls_sample-value.
      INSERT temp189 INTO TABLE lt_once.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_others ASSIGNING <count> WITH TABLE KEY path = ls_sample-path value = ls_sample-value.
      IF sy-subrc <> 0.

        CLEAR temp190.
        temp190-path = ls_sample-path.
        temp190-value = ls_sample-value.
        INSERT temp190 INTO TABLE lt_others ASSIGNING <count>.
      ENDIF.
      <count>-count = <count>-count + 1.
    ENDLOOP.

    IF lv_failing < 2 OR lv_others < 1.
      RETURN.
    ENDIF.


    LOOP AT lt_failing INTO ls_count.
      IF ls_count-count * 100 < lv_failing * 80.
        CONTINUE.
      ENDIF.

      READ TABLE lt_others INTO ls_other WITH TABLE KEY path = ls_count-path value = ls_count-value.
      IF sy-subrc <> 0.
        CLEAR ls_other.
      ENDIF.
      lv_pct = ls_other-count * 100 / lv_others.
      IF lv_pct > 30.
        CONTINUE.
      ENDIF.

      CLEAR temp191.
      temp191-f_pct = ls_count-count * 100 / lv_failing.
      CLEAR temp191-common.
      temp191-common-path = ls_count-path.
      temp191-common-value = ls_count-value.
      temp191-common-failing = ls_count-count.
      temp191-common-of_failing = lv_failing.
      temp191-common-others_pct = lv_pct.
      temp191-common-text = |in { ls_count-count } of { lv_failing } failing, | && |in { lv_pct } % of { lv_others } other states|.
      APPEND temp191
             TO lt_rank.
    ENDLOOP.

    SORT lt_rank BY f_pct DESCENDING common-others_pct ASCENDING common-path ASCENDING.

    LOOP AT lt_rank INTO ls_rank TO 20.
      APPEND ls_rank-common TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD samples_of.

    DATA temp192 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_value LIKE LINE OF temp192.
      DATA temp193 TYPE z2ui5_cl_cockpit_session=>ty_s_sample.
    temp192 = flatten( xml ).

    LOOP AT temp192 INTO ls_value.
      " a reference or a long text tells nothing about a cause
      IF ls_value-value CP `->*` OR strlen( ls_value-value ) > 100.
        CONTINUE.
      ENDIF.

      CLEAR temp193.
      temp193-sample = sample.
      temp193-path = ls_value-path.
      temp193-value = ls_value-value.
      APPEND temp193 TO ct_sample.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_app_objects.

    TYPES:
      BEGIN OF ty_s_seen,
        object TYPE string,
      END OF ty_s_seen.
    TYPES temp25 TYPE HASHED TABLE OF ty_s_seen WITH UNIQUE KEY object.
DATA lt_seen TYPE temp25.
    DATA lv_xml TYPE string.
        DATA lt_ids TYPE z2ui5_cl_cockpit_session=>ty_t_id.
        DATA lv_id LIKE LINE OF lt_ids.
          DATA temp194 TYPE z2ui5_cl_cockpit_session=>ty_t_business.
          DATA ls_business LIKE LINE OF temp194.
            DATA temp195 TYPE ty_s_seen.
            FIELD-SYMBOLS <object> TYPE z2ui5_cl_cockpit_session=>ty_s_object_count.
              DATA temp196 TYPE z2ui5_cl_cockpit_session=>ty_s_object_count.
        DATA lx TYPE REF TO cx_root.

    TRY.

        lt_ids = scan_app( app      = app
                                 max_hits = 300 ).

        LOOP AT lt_ids INTO lv_id.
          lv_xml = read_data( lv_id ).
          IF lv_xml IS INITIAL.
            CONTINUE.
          ENDIF.
          result-drafts = result-drafts + 1.
          CLEAR lt_seen.

          temp194 = business_of( flatten( lv_xml ) ).

          LOOP AT temp194 INTO ls_business.

            CLEAR temp195.
            temp195-object = ls_business-object.
            INSERT temp195 INTO TABLE lt_seen.
            IF sy-subrc <> 0.
              CONTINUE.
            ENDIF.

            READ TABLE result-t_object ASSIGNING <object>
                 WITH KEY object = ls_business-object. "#EC CI_SORTSEQ
            IF sy-subrc <> 0.

              CLEAR temp196.
              temp196-object = ls_business-object.
              temp196-field = ls_business-field.
              APPEND temp196 TO result-t_object ASSIGNING <object>.
            ENDIF.
            <object>-drafts = <object>-drafts + 1.
          ENDLOOP.
        ENDLOOP.

      CATCH cx_root INTO lx.
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
    TYPES temp26 TYPE STANDARD TABLE OF ty_s_row WITH DEFAULT KEY.
DATA lt_rows TYPE temp26.
    TYPES temp27 TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_skip TYPE temp27.
    DATA lv_last TYPE c LENGTH 32.
    DATA lv_tab TYPE string.
    DATA lv_scanned TYPE i.

    DATA lv_app TYPE string.
    DATA lv_skip LIKE LINE OF it_skip.
      DATA ls_row LIKE LINE OF lt_rows.
        DATA temp197 TYPE string.
        DATA lv_id LIKE temp197.
        DATA temp198 LIKE sy-subrc.
    lv_app = to_upper( condense( app ) ).

    LOOP AT it_skip INTO lv_skip.
      INSERT lv_skip INTO TABLE lt_skip.
    ENDLOOP.
    lv_tab = z2ui5_cl_cockpit_inst=>obj_name( z2ui5_cl_cockpit_draft=>c_table ).
    DO.
      CLEAR lt_rows.
      SELECT id data FROM (lv_tab) INTO CORRESPONDING FIELDS OF TABLE lt_rows
        WHERE id > lv_last
        ORDER BY id

        UP TO 200 ROWS.
      IF lt_rows IS INITIAL.
        RETURN.
      ENDIF.

      LOOP AT lt_rows INTO ls_row.
        lv_last = ls_row-id.
        lv_scanned = lv_scanned + 1.

        temp197 = ls_row-id.

        lv_id = temp197.

        READ TABLE lt_skip WITH KEY table_line = lv_id TRANSPORTING NO FIELDS.
        temp198 = sy-subrc.
        IF temp198 = 0.
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
    DATA lv_len TYPE i.

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


    lv_len = xstrlen( lv_utf8 ).
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
    TYPES temp28 TYPE HASHED TABLE OF ty_s_link WITH UNIQUE KEY id.
DATA lt_link TYPE temp28.
    TYPES temp29 TYPE HASHED TABLE OF ty_id WITH UNIQUE KEY table_line.
DATA lt_path TYPE temp29.
    DATA lv_cur TYPE ty_id.
    DATA lv_root TYPE ty_id.

    DATA ls_node LIKE LINE OF it_node.
      DATA temp199 TYPE ty_s_link.
      DATA temp200 LIKE sy-subrc.
      DATA temp201 LIKE sy-subrc.
        DATA ls_known TYPE z2ui5_cl_cockpit_session=>ty_s_root.
        DATA ls_link TYPE ty_s_link.
        DATA temp202 LIKE sy-subrc.
        DATA temp203 LIKE sy-subrc.
        DATA temp204 LIKE sy-subrc.
        DATA temp205 LIKE sy-subrc.
      DATA lv_id LIKE LINE OF lt_path.
        DATA temp206 TYPE z2ui5_cl_cockpit_session=>ty_s_root.
    LOOP AT it_node INTO ls_node.

      CLEAR temp199.
      temp199-id = ls_node-id.
      temp199-prev = ls_node-id_prev.
      INSERT temp199 INTO TABLE lt_link.
    ENDLOOP.

    LOOP AT it_node INTO ls_node.


      temp201 = sy-subrc.
      READ TABLE result WITH KEY id = ls_node-id TRANSPORTING NO FIELDS.
      temp200 = sy-subrc.
      sy-subrc = temp201.
      IF temp200 = 0.
        CONTINUE.
      ENDIF.

      CLEAR lt_path.
      CLEAR lv_root.
      lv_cur = ls_node-id.
      DO.

        READ TABLE result INTO ls_known WITH TABLE KEY id = lv_cur.
        IF sy-subrc = 0.
          lv_root = ls_known-root.
          EXIT.
        ENDIF.
        INSERT lv_cur INTO TABLE lt_path.

        READ TABLE lt_link INTO ls_link WITH TABLE KEY id = lv_cur.
        IF sy-subrc <> 0 OR ls_link-prev IS INITIAL.
          lv_root = lv_cur.
          EXIT.
        ENDIF.


        temp203 = sy-subrc.
        READ TABLE lt_link WITH KEY id = ls_link-prev TRANSPORTING NO FIELDS.
        temp202 = sy-subrc.
        sy-subrc = temp203.
        IF NOT temp202 = 0.
          " the predecessor expired - the session starts here now
          lv_root = lv_cur.
          EXIT.
        ENDIF.


        temp205 = sy-subrc.
        READ TABLE lt_path WITH KEY table_line = ls_link-prev TRANSPORTING NO FIELDS.
        temp204 = sy-subrc.
        sy-subrc = temp205.
        IF temp204 = 0.
          " a cycle no framework writes - end it where it closes
          lv_root = lv_cur.
          EXIT.
        ENDIF.
        lv_cur = ls_link-prev.
      ENDDO.


      LOOP AT lt_path INTO lv_id.

        CLEAR temp206.
        temp206-id = lv_id.
        temp206-root = lv_root.
        INSERT temp206 INTO TABLE result.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD steps_of.

    TYPES:
      BEGIN OF ty_s_index,
        id   TYPE c LENGTH 32,
        step TYPE i,
      END OF ty_s_index.
    TYPES temp30 TYPE HASHED TABLE OF ty_s_index WITH UNIQUE KEY id.
DATA lt_index TYPE temp30.
    DATA lt_mine TYPE ty_t_node.
    DATA lv_last TYPE timestampl.

    DATA temp207 TYPE ty_s_root-root.
    DATA lv_root LIKE temp207.
    DATA ls_node LIKE LINE OF it_node.
      DATA ls_root TYPE z2ui5_cl_cockpit_session=>ty_s_root.
      DATA temp208 TYPE ty_s_step.
      DATA ls_step LIKE temp208.
      DATA temp209 TYPE ty_s_index.
      DATA ls_index TYPE ty_s_index.
    temp207 = id.

    lv_root = temp207.

    LOOP AT it_node INTO ls_node.

      READ TABLE it_root INTO ls_root WITH TABLE KEY id = ls_node-id.
      IF sy-subrc = 0 AND ls_root-root = lv_root.
        APPEND ls_node TO lt_mine.
      ENDIF.
    ENDLOOP.
    SORT lt_mine BY timestampl ASCENDING id ASCENDING.

    LOOP AT lt_mine INTO ls_node.

      CLEAR temp208.
      temp208-step = sy-tabix.
      temp208-id = ls_node-id.
      temp208-time = z2ui5_cl_cockpit_setup=>ts_text( ls_node-timestampl ).
      temp208-timestampl = ls_node-timestampl.
      temp208-state = `None`.
      temp208-monitor_state = `None`.
      temp208-shown_state = `None`.
      temp208-messages_state = `None`.
      temp208-ms_state = `None`.

      ls_step = temp208.

      CLEAR temp209.
      temp209-id = ls_node-id.
      temp209-step = ls_step-step.
      INSERT temp209 INTO TABLE lt_index.

      IF ls_step-step > 1.
        ls_step-delta = |+{ duration_text( seconds_between( ts_from = lv_last
                                                            ts_to   = ls_node-timestampl ) ) }|.
      ENDIF.
      lv_last = ls_node-timestampl.


      READ TABLE lt_index INTO ls_index WITH TABLE KEY id = ls_node-id_prev.
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
    TYPES temp32 TYPE HASHED TABLE OF ty_s_row WITH UNIQUE KEY id.
DATA lt_data TYPE temp32.
    TYPES temp33 TYPE HASHED TABLE OF ty_s_seen WITH UNIQUE KEY object value.
DATA lt_seen TYPE temp33.
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
    DATA ls_step LIKE LINE OF cs_steps-t_step.
      DATA temp210 LIKE LINE OF lt_range.
      FIELD-SYMBOLS <step> LIKE LINE OF cs_steps-t_step.
        DATA temp211 TYPE ty_id.
        DATA lv_key LIKE temp211.
        DATA ls_row TYPE ty_s_row.
        DATA lt_values TYPE z2ui5_cl_cockpit_session=>ty_t_value.
          DATA lv_follows TYPE z2ui5_cl_cockpit_session=>ty_s_step-id.
          FIELD-SYMBOLS <temp26> LIKE LINE OF cs_steps-t_step.
          DATA temp27 LIKE sy-tabix.
          DATA temp212 TYPE z2ui5_cl_cockpit_session=>ty_t_field.
            DATA temp213 TYPE string.
            DATA temp28 TYPE string.
        DATA lt_message TYPE z2ui5_cl_cockpit_session=>ty_t_message.
        DATA ls_message LIKE LINE OF lt_message.
          DATA temp214 TYPE string.
          DATA temp215 TYPE z2ui5_cl_cockpit_session=>ty_s_step-messages_state.
          DATA temp29 LIKE sy-subrc.
          DATA temp30 LIKE sy-subrc.
          DATA temp31 LIKE sy-tabix.
          DATA temp2 LIKE sy-subrc.
          DATA temp3 LIKE sy-subrc.
          DATA temp4 LIKE sy-tabix.
          DATA temp5 LIKE sy-subrc.
          DATA temp6 LIKE sy-subrc.
          DATA temp7 LIKE sy-tabix.
          DATA temp1 LIKE sy-subrc.
          DATA temp8 LIKE sy-subrc.
          DATA temp9 LIKE sy-tabix.
        DATA temp216 TYPE z2ui5_cl_cockpit_session=>ty_t_business.
        DATA ls_business LIKE LINE OF temp216.
          DATA temp217 TYPE ty_s_seen.
        DATA temp218 TYPE string.

    lv_tab = z2ui5_cl_cockpit_inst=>obj_name( z2ui5_cl_cockpit_draft=>c_table ).

    LOOP AT cs_steps-t_step INTO ls_step.
      lv_done = lv_done + 1.

      CLEAR temp210.
      temp210-sign = `I`.
      temp210-option = `EQ`.
      temp210-low = ls_step-id.
      APPEND temp210 TO lt_range.
      IF lines( lt_range ) < 50 AND lv_done < lines( cs_steps-t_step ).
        CONTINUE.
      ENDIF.

      CLEAR lt_data.
      SELECT id data FROM (lv_tab) INTO CORRESPONDING FIELDS OF TABLE lt_data
        WHERE id IN lt_range
        .
      CLEAR lt_range.

      " the steps of this batch in their order - each compared with the
      " step it continues, which is the one before it unless the user went
      " back in the browser

      LOOP AT cs_steps-t_step ASSIGNING <step> FROM lv_from TO lv_done.

        temp211 = <step>-id.

        lv_key = temp211.

        READ TABLE lt_data INTO ls_row WITH TABLE KEY id = lv_key.
        IF sy-subrc <> 0.
          CLEAR lt_prev.
          CLEAR lv_prev_id.
          CONTINUE.
        ENDIF.
        <step>-app = app_of( ls_row-data ).
        <step>-kb  = ( strlen( ls_row-data ) + 1023 ) DIV 1024.

        lt_values = flatten( ls_row-data ).

        IF <step>-follows > 0.



          temp27 = sy-tabix.
          READ TABLE cs_steps-t_step INDEX <step>-follows ASSIGNING <temp26>.
          sy-tabix = temp27.
          IF sy-subrc <> 0.
            ASSERT 1 = 0.
          ENDIF.
          lv_follows = <temp26>-id.
          IF lv_follows <> lv_prev_id.
            lt_prev = flatten( read_data( lv_follows ) ).
          ENDIF.
          <step>-changes = 0.

          temp212 = diff( it_new = lt_values it_old = lt_prev ).
          LOOP AT temp212 TRANSPORTING NO FIELDS WHERE change IS NOT INITIAL. "#EC CI_SORTSEQ
            <step>-changes = <step>-changes + 1.
          ENDLOOP.
          IF <step>-changes = 0.
            lv_idle = lv_idle + 1.

            IF <step>-note IS NOT INITIAL.
              temp213 = `, `.
            ELSE.
              CLEAR temp213.
            ENDIF.

            IF lv_idle > 1.
              temp28 = |no field changed - { lv_idle } times in a row|.
            ELSE.
              temp28 = `no field changed`.
            ENDIF.
            <step>-note = |{ <step>-note }{ temp213 }| &&
                          |{ temp28 }|.
          ELSE.
            lv_idle = 0.
          ENDIF.
        ELSE.
          lv_idle = 0.
        ENDIF.

        " a message is shown where it appears, not on every step that keeps it
        CLEAR lv_messages.

        lt_message = messages_of( lt_values ).

        LOOP AT lt_message INTO ls_message.
          IF sy-tabix > 2.
            lv_messages = |{ lv_messages } (+{ lines( lt_message ) - 2 } more)|.
            EXIT.
          ENDIF.

          IF lv_messages IS NOT INITIAL.
            temp214 = `; `.
          ELSE.
            CLEAR temp214.
          ENDIF.
          lv_messages = |{ lv_messages }{ temp214 }| &&
                        |{ ls_message-type }: { ls_message-text }|.
        ENDLOOP.
        IF lv_messages <> lv_prev_messages.
          <step>-messages = lv_messages.




          temp30 = sy-subrc.
          temp31 = sy-tabix.
          READ TABLE lt_message WITH KEY type = `E` TRANSPORTING NO FIELDS.
          temp29 = sy-subrc.
          sy-subrc = temp30.
          sy-tabix = temp31.



          temp3 = sy-subrc.
          temp4 = sy-tabix.
          READ TABLE lt_message WITH KEY type = `A` TRANSPORTING NO FIELDS.
          temp2 = sy-subrc.
          sy-subrc = temp3.
          sy-tabix = temp4.



          temp6 = sy-subrc.
          temp7 = sy-tabix.
          READ TABLE lt_message WITH KEY type = `X` TRANSPORTING NO FIELDS.
          temp5 = sy-subrc.
          sy-subrc = temp6.
          sy-tabix = temp7.



          temp8 = sy-subrc.
          temp9 = sy-tabix.
          READ TABLE lt_message WITH KEY type = `ERROR` TRANSPORTING NO FIELDS.
          temp1 = sy-subrc.
          sy-subrc = temp8.
          sy-tabix = temp9.
          IF temp29 = 0 OR temp2 = 0 OR temp5 = 0 OR temp1 = 0.
            temp215 = `Error`.
          ELSEIF lt_message IS NOT INITIAL.
            temp215 = `Warning`.
          ELSE.
            temp215 = `None`.
          ENDIF.
          <step>-messages_state = temp215.
        ELSE.
          <step>-messages_state = `None`.
        ENDIF.
        lv_prev_messages = lv_messages.


        temp216 = business_of( lt_values ).

        LOOP AT temp216 INTO ls_business.

          CLEAR temp217.
          temp217-object = ls_business-object.
          temp217-value = ls_business-value.
          INSERT temp217 INTO TABLE lt_seen.
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

        IF <step>-note IS NOT INITIAL.
          temp218 = `, `.
        ELSE.
          CLEAR temp218.
        ENDIF.
        <step>-note = |{ <step>-note }{ temp218 }| &&
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
    DATA temp219 TYPE z2ui5_if_client=>ty_t_name_value.
    DATA temp220 LIKE LINE OF temp219.
    CLEAR temp219.

    temp220-n = `VBELN`.
    temp220-v = `Sales document`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `KUNNR`.
    temp220-v = `Customer`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `KUNAG`.
    temp220-v = `Sold-to party`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `LIFNR`.
    temp220-v = `Supplier`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `PARTNER`.
    temp220-v = `Business partner`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `MATNR`.
    temp220-v = `Material`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `EBELN`.
    temp220-v = `Purchase order`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `BANFN`.
    temp220-v = `Purchase requisition`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `BELNR`.
    temp220-v = `Accounting document`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `MBLNR`.
    temp220-v = `Material document`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `AUFNR`.
    temp220-v = `Order`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `QMNUM`.
    temp220-v = `Notification`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `EQUNR`.
    temp220-v = `Equipment`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `TPLNR`.
    temp220-v = `Functional location`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `PERNR`.
    temp220-v = `Personnel number`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `BUKRS`.
    temp220-v = `Company code`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `WERKS`.
    temp220-v = `Plant`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `LGORT`.
    temp220-v = `Storage location`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `VKORG`.
    temp220-v = `Sales organization`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `EKORG`.
    temp220-v = `Purchasing organization`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `KOSTL`.
    temp220-v = `Cost center`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `PRCTR`.
    temp220-v = `Profit center`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `POSID`.
    temp220-v = `WBS element`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `ANLN1`.
    temp220-v = `Asset`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `CHARG`.
    temp220-v = `Batch`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `CARRID`.
    temp220-v = `Airline`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `CONNID`.
    temp220-v = `Flight connection`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `TRAVEL_ID`.
    temp220-v = `Travel`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `BOOKING_ID`.
    temp220-v = `Booking`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `ORDER_ID`.
    temp220-v = `Order`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `CUSTOMER`.
    temp220-v = `Customer`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `CUSTOMER_ID`.
    temp220-v = `Customer`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `SUPPLIER`.
    temp220-v = `Supplier`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `PRODUCT`.
    temp220-v = `Product`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `PRODUCT_ID`.
    temp220-v = `Product`.
    INSERT temp220 INTO TABLE temp219.
    temp220-n = `INVOICE`.
    temp220-v = `Invoice`.
    INSERT temp220 INTO TABLE temp219.
    result = temp219.

  ENDMETHOD.

  METHOD business_of.

    TYPES:
      BEGIN OF ty_s_seen,
        object TYPE string,
        value  TYPE string,
      END OF ty_s_seen.
    TYPES temp34 TYPE HASHED TABLE OF ty_s_seen WITH UNIQUE KEY object value.
DATA lt_seen TYPE temp34.
    DATA lv_name TYPE string.

    DATA lt_catalogue TYPE z2ui5_if_client=>ty_t_name_value.
    DATA ls_value LIKE LINE OF it_value.
      DATA lv_value TYPE string.
      DATA lv_dash TYPE i.
      DATA ls_entry LIKE LINE OF lt_catalogue.
        DATA temp221 TYPE ty_s_seen.
          DATA temp222 TYPE z2ui5_cl_cockpit_session=>ty_s_business.
    lt_catalogue = business_catalogue( ).

    LOOP AT it_value INTO ls_value.

      lv_value = condense( ls_value-value ).
      " empty, or an initial number or date
      IF lv_value CO ` 0.:-` OR lv_value CP `->*`.
        CONTINUE.
      ENDIF.
      " the last component of the path, without the row of an elementary table
      " find( occ = -1 ) and not substring_after( occ = -1 ): the transpiled
      " runtime ignores occ there and cuts at the first dash
      lv_name = ls_value-path.

      lv_dash = find( val = lv_name
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


      LOOP AT lt_catalogue INTO ls_entry.
        IF lv_name <> ls_entry-n AND lv_name NP |*_{ ls_entry-n }|.
          CONTINUE.
        ENDIF.

        CLEAR temp221.
        temp221-object = ls_entry-v.
        temp221-value = lv_value.
        INSERT temp221 INTO TABLE lt_seen.
        IF sy-subrc = 0.

          CLEAR temp222.
          temp222-object = ls_entry-v.
          temp222-value = lv_value.
          temp222-field = ls_value-path.
          APPEND temp222 TO result.
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
    TYPES temp35 TYPE STANDARD TABLE OF ty_s_row WITH DEFAULT KEY.
DATA lt_row TYPE temp35.
    DATA lv_prefix TYPE string.
    DATA lv_comp TYPE string.

    DATA ls_value LIKE LINE OF it_value.
      DATA lv_dash TYPE i.
      FIELD-SYMBOLS <row> TYPE ty_s_row.
        DATA temp223 TYPE ty_s_row.
    DATA ls_row LIKE LINE OF lt_row.
      DATA lv_error TYPE abap_bool.
      DATA temp11 TYPE xsdboolean.
      DATA temp224 TYPE z2ui5_cl_cockpit_session=>ty_s_message.
    LOOP AT it_value INTO ls_value.
      " find( occ = -1 ), see business_of

      lv_dash = find( val = ls_value-path
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

      READ TABLE lt_row ASSIGNING <row> WITH KEY prefix = lv_prefix. "#EC CI_SORTSEQ
      IF sy-subrc <> 0.

        CLEAR temp223.
        temp223-prefix = lv_prefix.
        APPEND temp223 TO lt_row ASSIGNING <row>.
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


    LOOP AT lt_row INTO ls_row.


      temp11 = boolc( ls_row-type = `E` OR ls_row-type = `A` OR ls_row-type = `X` OR ls_row-type = `ERROR` ).
      lv_error = temp11.
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

      CLEAR temp224.
      temp224-type = ls_row-type.
      temp224-text = ls_row-text.
      temp224-path = ls_row-prefix.
      APPEND temp224 TO result.
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
    TYPES temp36 TYPE STANDARD TABLE OF ty_s_log WITH DEFAULT KEY.
DATA lt_log TYPE temp36.
    DATA lt_range TYPE ty_r_id.
    DATA lv_done TYPE i.

    DATA ls_step LIKE LINE OF ct_step.
      DATA temp225 LIKE LINE OF lt_range.
    DATA ls_log LIKE LINE OF lt_log.
        FIELD-SYMBOLS <step> TYPE z2ui5_cl_cockpit_session=>ty_s_step.
    LOOP AT ct_step INTO ls_step.
      lv_done = lv_done + 1.

      CLEAR temp225.
      temp225-sign = `I`.
      temp225-option = `EQ`.
      temp225-low = ls_step-id.
      APPEND temp225 TO lt_range.
      IF lines( lt_range ) < 50 AND lv_done < lines( ct_step ).
        CONTINUE.
      ENDIF.
      SELECT draft_id draft_id_prev event check_error check_slow ms_total error_class error_head
        FROM z2ui5_t_25 APPENDING CORRESPONDING FIELDS OF TABLE lt_log
        WHERE draft_id IN lt_range
           OR draft_id_prev IN lt_range
        .
      CLEAR lt_range.
    ENDLOOP.


    LOOP AT lt_log INTO ls_log.
      IF ls_log-check_error = abap_true.
        " the roundtrip started from this step and failed - its own draft,
        " if it wrote one, is not where the user saw the screen

        READ TABLE ct_step ASSIGNING <step> WITH KEY id = ls_log-draft_id_prev. "#EC CI_SORTSEQ
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
    TYPES temp37 TYPE HASHED TABLE OF ty_s_screen WITH UNIQUE KEY step.
DATA lt_screen TYPE temp37.
    DATA lv_screen TYPE string.
    DATA lv_request TYPE string.
    DATA lv_response TYPE string.

    DATA ls_step LIKE LINE OF ct_step.
    DATA lt_record TYPE z2ui5_cl_cockpit_wire=>ty_t_record.
    FIELD-SYMBOLS <step> LIKE LINE OF ct_step.
        DATA ls_screen TYPE ty_s_screen.
      DATA ls_record TYPE z2ui5_cl_cockpit_wire=>ty_s_record.
        DATA lv_browser TYPE z2ui5_cl_cockpit_rec=>ty_s_roundtrip-ms_client_prev.
          FIELD-SYMBOLS <before> TYPE z2ui5_cl_cockpit_session=>ty_s_step.
        DATA lt_shown TYPE z2ui5_cl_cockpit_wire=>ty_t_shown.
        DATA ls_shown LIKE LINE OF lt_shown.
          DATA lv_type TYPE string.
          DATA temp226 TYPE z2ui5_cl_cockpit_session=>ty_s_step-shown_state.
        DATA temp227 TYPE z2ui5_if_client=>ty_t_name_value.
        DATA ls_view LIKE LINE OF temp227.
      DATA temp228 TYPE ty_s_screen.
        DATA temp229 TYPE string.
    DATA lv_slow TYPE z2ui5_cl_cockpit_setup=>ty_s_settings-slow_ms.
      DATA temp230 TYPE string.
      DATA temp231 TYPE z2ui5_cl_cockpit_session=>ty_s_step-ms_state.
    LOOP AT ct_step INTO ls_step.
      APPEND ls_step-id TO lt_id.
    ENDLOOP.

    lt_record = z2ui5_cl_cockpit_wire=>get_records( lt_id ).
    IF lt_record IS INITIAL.
      RETURN.
    ENDIF.


    LOOP AT ct_step ASSIGNING <step>.
      " the screen the user saw before this step: the one of the step it continues
      CLEAR lv_screen.
      IF <step>-follows > 0.

        READ TABLE lt_screen INTO ls_screen WITH TABLE KEY step = <step>-follows.
        IF sy-subrc = 0.
          lv_screen = ls_screen-xml.
        ENDIF.
      ENDIF.


      READ TABLE lt_record INTO ls_record WITH KEY draft_id = <step>-id. "#EC CI_SORTSEQ
      IF sy-subrc = 0.
        <step>-wire_id = ls_record-id.
        " the monitor may be off - the recording names the event too
        IF <step>-event IS INITIAL.
          <step>-event = ls_record-event.
        ENDIF.
        z2ui5_cl_cockpit_wire=>get_bodies( EXPORTING id       = ls_record-id
                                           IMPORTING request  = lv_request
                                                     response = lv_response ).
        <step>-ms_server = ls_record-ms_total.
        " the browser sends the time it waited for the roundtrip before -
        " the one that wrote the step this one continues

        lv_browser = z2ui5_cl_cockpit_wire=>roundtrip_of( request     = lv_request
                                                               response    = ``
                                                               http_status = 200 )-ms_client_prev.
        IF lv_browser > 0 AND <step>-follows > 0.

          READ TABLE ct_step ASSIGNING <before> INDEX <step>-follows.
          IF sy-subrc = 0.
            <before>-ms_browser = lv_browser.
          ENDIF.
        ENDIF.
        <step>-did = did_of( screen  = lv_screen
                             event   = ls_record-event
                             request = lv_request ).

        lt_shown = z2ui5_cl_cockpit_wire=>shown_of( lv_response ).
        <step>-shown = z2ui5_cl_cockpit_wire=>shown_text( lt_shown ).

        LOOP AT lt_shown INTO ls_shown WHERE kind = z2ui5_cl_cockpit_wire=>cs_kind-box. "#EC CI_SORTSEQ

          lv_type = to_lower( ls_shown-type ).

          CASE lv_type.
            WHEN `error`.
              temp226 = `Error`.
            WHEN `warning`.
              temp226 = `Warning`.
            WHEN OTHERS.
              temp226 = <step>-shown_state.
          ENDCASE.
          <step>-shown_state = temp226.
        ENDLOOP.

        temp227 = z2ui5_cl_cockpit_wire=>views_of( lv_response ).

        LOOP AT temp227 INTO ls_view WHERE n = `MAIN`. "#EC CI_SORTSEQ
          lv_screen = ls_view-v.
        ENDLOOP.
      ENDIF.

      CLEAR temp228.
      temp228-step = <step>-step.
      temp228-xml = lv_screen.
      INSERT temp228 INTO TABLE lt_screen.

      " a roundtrip that started here and failed wrote no step - its request
      " is the user's last attempt
      LOOP AT lt_record INTO ls_record WHERE draft_id_prev = <step>-id AND http_status >= 500. "#EC CI_SORTSEQ
        <step>-wire_fail_id = ls_record-id.
        <step>-wire_fail_event = ls_record-event.
        z2ui5_cl_cockpit_wire=>get_bodies( EXPORTING id      = ls_record-id
                                           IMPORTING request = lv_request ).

        IF <step>-note IS NOT INITIAL.
          temp229 = `, `.
        ELSE.
          CLEAR temp229.
        ENDIF.
        <step>-note = |{ <step>-note }{ temp229 }| &&
                      |next click failed: { did_of( screen  = lv_screen
                                                    event   = ls_record-event
                                                    request = lv_request ) }|.
      ENDLOOP.
    ENDLOOP.

    " slow as the settings define it - on the server, or for the user

    lv_slow = z2ui5_cl_cockpit_setup=>get( )-slow_ms.
    LOOP AT ct_step ASSIGNING <step> WHERE ms_server > 0 OR ms_browser > 0. "#EC CI_SORTSEQ

      IF <step>-ms_browser > 0.
        temp230 = |, { ms_text( <step>-ms_browser ) } waited|.
      ELSE.
        CLEAR temp230.
      ENDIF.
      <step>-ms_text = |{ ms_text( <step>-ms_server ) } server| &&
                       |{ temp230 }|.

      IF lv_slow > 0 AND ( <step>-ms_server >= lv_slow OR <step>-ms_browser >= lv_slow ).
        temp231 = `Warning`.
      ELSE.
        temp231 = `None`.
      ENDIF.
      <step>-ms_state = temp231.
    ENDLOOP.

  ENDMETHOD.

  METHOD ms_text.

    IF ms < 1000.
      result = |{ ms } ms|.
    ELSE.
      " one decimal, by hand - no decimals formatting on every release
      result = |{ ms DIV 1000 }.{ ( ms MOD 1000 ) DIV 100 } s|.
    ENDIF.

  ENDMETHOD.

  METHOD did_of.

    DATA lv_typed TYPE string.
    DATA lv_count TYPE i.
      DATA lv_control TYPE string.
      DATA temp232 TYPE string.
    DATA temp233 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_input LIKE LINE OF temp233.
      DATA lv_field TYPE string.
      DATA temp234 TYPE string.
      DATA temp32 TYPE string.
      DATA temp235 TYPE string.

    IF event IS NOT INITIAL.

      lv_control = z2ui5_cl_cockpit_wire=>control_of( xml   = screen
                                                           event = event ).

      IF lv_control IS NOT INITIAL.
        temp232 = |pressed { lv_control } ({ event })|.
      ELSE.
        temp232 = |event { event }|.
      ENDIF.
      result = temp232.
    ENDIF.

    temp233 = z2ui5_cl_cockpit_wire=>input_of( request ).

    LOOP AT temp233 INTO ls_input.
      IF ls_input-path CP `event argument*`.
        CONTINUE.
      ENDIF.
      lv_count = lv_count + 1.
      IF lv_count > 3.
        CONTINUE.
      ENDIF.

      lv_field = z2ui5_cl_cockpit_wire=>field_control_of( xml  = screen
                                                               path = ls_input-path ).

      IF lv_typed IS NOT INITIAL.
        temp234 = `, `.
      ELSE.
        CLEAR temp234.
      ENDIF.

      IF lv_field IS NOT INITIAL.
        temp32 = lv_field.
      ELSE.
        temp32 = ls_input-path.
      ENDIF.
      lv_typed = |{ lv_typed }{ temp234 }| &&
                 |{ temp32 } = { cut( ls_input-value ) }|.
    ENDLOOP.
    IF lv_count > 3.
      lv_typed = |{ lv_typed } (+{ lv_count - 3 } more)|.
    ENDIF.
    IF lv_typed IS NOT INITIAL.

      IF result IS NOT INITIAL.
        temp235 = `, `.
      ELSE.
        CLEAR temp235.
      ENDIF.
      result = |{ result }{ temp235 }typed { lv_typed }|.
    ENDIF.

  ENDMETHOD.

  METHOD monitor_add.

    DATA temp236 TYPE string.
    IF cs_step-monitor IS NOT INITIAL.
      temp236 = `; `.
    ELSE.
      CLEAR temp236.
    ENDIF.
    cs_step-monitor = |{ cs_step-monitor }{ temp236 }{ text }|.
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
    TYPES temp38 TYPE STANDARD TABLE OF ty_s_open WITH DEFAULT KEY.
DATA lt_stack TYPE temp38.
    TYPES temp39 TYPE HASHED TABLE OF ty_s_count WITH UNIQUE KEY label.
DATA lt_count TYPE temp39.
    DATA lt_entry TYPE ty_t_entry.
    DATA lt_leaf TYPE ty_t_leaf.
    TYPES temp40 TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_visible TYPE temp40.
    DATA ls_open TYPE ty_s_open.
    DATA lv_pos TYPE i.
    DATA lv_attributes TYPE string.
    DATA lv_close TYPE abap_bool.
    DATA lv_self TYPE abap_bool.
    FIELD-SYMBOLS <top> TYPE ty_s_open.
    FIELD-SYMBOLS <parent> TYPE ty_s_open.

    DATA lv_len TYPE i.
      DATA lv_lt TYPE i.
      DATA lv_gt TYPE i.
      DATA lv_tag TYPE string.
      DATA lv_first TYPE string.
      DATA temp12 TYPE xsdboolean.
        DATA lv_blank TYPE i.
          DATA lv_id TYPE string.
          DATA lv_label LIKE ls_open-name.
          FIELD-SYMBOLS <count> TYPE ty_s_count.
            DATA temp237 TYPE ty_s_count.
          DATA temp238 TYPE z2ui5_cl_cockpit_session=>ty_s_entry.
          DATA temp13 TYPE xsdboolean.
            DATA lv_name LIKE ls_open-name.
        DATA lv_top TYPE i.
          DATA temp239 TYPE z2ui5_cl_cockpit_session=>ty_s_leaf.
          DATA temp33 TYPE z2ui5_cl_cockpit_session=>ty_s_leaf-value.
      DATA ls_entry LIKE LINE OF lt_entry.
        DATA lv_added LIKE abap_false.
        DATA ls_leaf LIKE LINE OF lt_leaf.
          DATA temp240 LIKE sy-subrc.
          DATA temp241 LIKE sy-subrc.
      DATA temp242 LIKE sy-subrc.
      DATA temp243 LIKE sy-subrc.
        DATA temp244 TYPE z2ui5_cl_cockpit_session=>ty_s_leaf-value.
      DATA temp245 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
    lv_len = strlen( xml ).
    WHILE lv_pos < lv_len.


      lv_lt = find( val = xml
                          sub = `<`
                          off = lv_pos ).
      IF lv_lt < 0.
        EXIT.
      ENDIF.
      IF lv_lt > lv_pos AND lt_stack IS NOT INITIAL.
        READ TABLE lt_stack INDEX lines( lt_stack ) ASSIGNING <top>.
        <top>-text = <top>-text && substring( val = xml
                                              off = lv_pos
                                              len = lv_lt - lv_pos ).
      ENDIF.

      lv_gt = find( val = xml
                          sub = `>`
                          off = lv_lt ).
      IF lv_gt < 0.
        EXIT.
      ENDIF.

      lv_tag = substring( val = xml
                                off = lv_lt + 1
                                len = lv_gt - lv_lt - 1 ).
      lv_pos = lv_gt + 1.
      IF lv_tag IS INITIAL.
        CONTINUE.
      ENDIF.

      lv_first = substring( val = lv_tag
                                  len = 1 ).
      IF lv_first = `?` OR lv_first = `!`.
        CONTINUE.
      ENDIF.


      temp12 = boolc( lv_first = `/` ).
      lv_close = temp12.
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

        lv_blank = find( val = lv_tag
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
          READ TABLE lt_stack INDEX lines( lt_stack ) ASSIGNING <parent>.
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

          lv_id = attribute( attributes = lv_attributes
                                   name       = `id` ).

          lv_label = ls_open-name.
          IF lv_label CS `:`.
            lv_label = substring_after( val = lv_label
                                        sub = `:` ).
          ENDIF.
          REPLACE ALL OCCURRENCES OF `_-` IN lv_label WITH `/`.

          READ TABLE lt_count ASSIGNING <count> WITH TABLE KEY label = lv_label.
          IF sy-subrc <> 0.

            CLEAR temp237.
            temp237-label = lv_label.
            INSERT temp237 INTO TABLE lt_count ASSIGNING <count>.
          ENDIF.
          <count>-count = <count>-count + 1.
          IF <count>-count > 1.
            lv_label = |{ lv_label }#{ <count>-count }|.
          ENDIF.
          ls_open-path = lv_label.
          ls_open-root = lv_id.

          CLEAR temp238.
          temp238-id = lv_id.
          temp238-label = lv_label.

          temp13 = boolc( lv_id CP `o*` ).
          temp238-check_object = temp13.
          INSERT temp238 INTO TABLE lt_entry.
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

            lv_name = ls_open-name.
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

        lv_top = lines( lt_stack ).
        READ TABLE lt_stack INDEX lv_top ASSIGNING <top>.
        IF ( <top>-kind = `N` OR ( <top>-kind = `E` AND <top>-root NP `o*` ) )
            AND <top>-children = abap_false.

          CLEAR temp239.
          temp239-path = <top>-path.

          IF <top>-href IS INITIAL.
            temp33 = decode( <top>-text ).
          ELSE.
            CLEAR temp33.
          ENDIF.
          temp239-value = temp33.
          temp239-root = <top>-root.
          temp239-href = <top>-href.
          APPEND temp239 TO lt_leaf.
        ENDIF.
        DELETE lt_stack INDEX lv_top.
      ENDIF.

    ENDWHILE.

    IF check_all = abap_true.

      LOOP AT lt_entry INTO ls_entry.
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

        lv_added = abap_false.

        LOOP AT lt_leaf INTO ls_leaf WHERE href IS NOT INITIAL. "#EC CI_SORTSEQ


          temp241 = sy-subrc.
          READ TABLE lt_visible WITH KEY table_line = ls_leaf-root TRANSPORTING NO FIELDS.
          temp240 = sy-subrc.
          sy-subrc = temp241.
          IF NOT temp240 = 0.
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


      temp243 = sy-subrc.
      READ TABLE lt_visible WITH KEY table_line = ls_leaf-root TRANSPORTING NO FIELDS.
      temp242 = sy-subrc.
      sy-subrc = temp243.
      IF ls_leaf-root IS NOT INITIAL AND NOT temp242 = 0.
        CONTINUE.
      ENDIF.
      IF ls_leaf-href IS NOT INITIAL.
        READ TABLE lt_entry INTO ls_entry WITH TABLE KEY id = ls_leaf-href.

        IF sy-subrc = 0.
          temp244 = |-> { ls_entry-label }|.
        ELSE.
          temp244 = |-> #{ ls_leaf-href }|.
        ENDIF.
        ls_leaf-value = temp244.
      ENDIF.

      CLEAR temp245.
      temp245-path = ls_leaf-path.
      temp245-value = ls_leaf-value.
      APPEND temp245 TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD diff.

    TYPES temp41 TYPE HASHED TABLE OF ty_s_value WITH UNIQUE KEY path.
DATA lt_old TYPE temp41.
    TYPES temp42 TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_seen TYPE temp42.

    DATA ls_old LIKE LINE OF it_old.
    DATA ls_new LIKE LINE OF it_new.
      DATA temp246 TYPE ty_s_field.
      DATA ls_field LIKE temp246.
      DATA temp247 TYPE z2ui5_cl_cockpit_session=>ty_s_field.
    LOOP AT it_old INTO ls_old.
      INSERT ls_old INTO TABLE lt_old.
    ENDLOOP.


    LOOP AT it_new INTO ls_new.
      INSERT ls_new-path INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      CLEAR temp246.
      temp246-path = ls_new-path.
      temp246-value = ls_new-value.
      temp246-state = `None`.

      ls_field = temp246.
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

      CLEAR temp247.
      temp247-path = ls_old-path.
      temp247-prev = ls_old-value.
      temp247-change = cs_change-removed.
      temp247-state = `Error`.
      APPEND temp247 TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD app_of.

    DATA lv_pos TYPE i.
      DATA lv_hit TYPE i.
      DATA lv_open TYPE i.
      DATA lv_name TYPE string.

    DO.

      lv_hit = find( val = xml
                           sub = ` id="o`
                           off = lv_pos ).
      IF lv_hit < 0.
        RETURN.
      ENDIF.
      lv_pos = lv_hit + 1.

      lv_open = find( val = substring( val = xml
                                             len = lv_hit )
                            sub = `<`
                            occ = -1 ).
      IF lv_open < 0.
        CONTINUE.
      ENDIF.

      lv_name = substring( val = xml
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
    lv_tab = z2ui5_cl_cockpit_inst=>obj_name( z2ui5_cl_cockpit_draft=>c_table ).
    SELECT id id_prev uname timestampl FROM (lv_tab)
      ORDER BY timestampl DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE result
      UP TO c_max_nodes ROWS.                        "#EC CI_NOWHERE

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
    lv_tab = z2ui5_cl_cockpit_inst=>obj_name( z2ui5_cl_cockpit_draft=>c_table ).
    lv_id = id.
    SELECT SINGLE data FROM (lv_tab) INTO result
      WHERE id = lv_id
      .
    IF sy-subrc <> 0.
      CLEAR result.
    ENDIF.

  ENDMETHOD.

  METHOD user_text.
    DATA lv_key TYPE string.

    IF z2ui5_cl_cockpit_setup=>check_privacy( ) = abap_false.
      result = uname.
      RETURN.
    ENDIF.
    " the pseudonym of today - the one the Errors tab shows for today's
    " occurrences, so a session can be matched with an error

    lv_key = z2ui5_cl_cockpit_setup=>user_key( uname = uname
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

    DATA lv_off TYPE i.
    lv_off = find( val = attributes
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

    DATA temp14 TYPE xsdboolean.
    temp14 = boolc( label CP `Z2UI5_CL_UI5_*` OR label CP `Z2UI5_CL_SRT_*` OR label CP `Z2UI5_CL_AJSON*` ).
    result = temp14.

  ENDMETHOD.

  METHOD cut.

    DATA lv_len TYPE i.
    lv_len = strlen( val ).
    IF lv_len <= c_max_value.
      result = val.
      RETURN.
    ENDIF.
    result = |{ substring( val = val
                           len = c_max_value ) }... ({ lv_len } characters)|.

  ENDMETHOD.

ENDCLASS.
