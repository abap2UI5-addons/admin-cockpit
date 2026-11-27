"! <p class="shorttext synchronized">admin cockpit - request recorder</p>
"!
"! Records every roundtrip as it went over the wire: the request the browser
"! sent (event, event arguments, the values the user changed) and the
"! response abap2UI5 answered with (message boxes, toasts, popups, the view
"! XML and the model) - unparsed, so every later question can be asked of
"! old recordings too, and a screen can be set up again from them.
"!
"! Opt-in by one line in the HTTP handler class of the installation (SICF,
"! the service's Handler List; not a class of the abap2UI5 repository),
"! method if_http_extension~handle_request, in place of abap2UI5's call:
"!   z2ui5_cl_cockpit_wire=&gt;run( server ).
"! (ABAP Cloud: run( req = request res = response ).) It calls abap2UI5,
"! records the bodies and feeds the roundtrip statistics - the one place
"! the cockpit hooks in. record( server ) after abap2UI5's own call records
"! the bodies only. Like the monitor it
"! then runs on every request - add the line only once the cockpit is active
"! and syntax-clean, a syntax error is a short dump no CATCH stops.
"!
"! The bodies hold all business data the user saw and typed: kept for
"! wire_days (default 2, 0 switches recording off), shown to administrators
"! only, every opened session written to the change log. Only POST
"! roundtrips are recorded, the page request (GET) is not.
CLASS z2ui5_cl_cockpit_wire DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    " a body longer than this is cut - a safety net against a runaway
    " download, far above any ordinary view
    CONSTANTS c_max_body   TYPE i VALUE 2000000.
    " the most recordings a sticky session keeps in the roll area until a
    " roundtrip that may commit
    CONSTANTS c_buffer_max TYPE i VALUE 5.
    " the most recordings a message statistic reads
    CONSTANTS c_max_read   TYPE i VALUE 1000.

    CONSTANTS:
      BEGIN OF cs_kind,
        box     TYPE string VALUE `MESSAGE_BOX`,
        toast   TYPE string VALUE `MESSAGE_TOAST`,
        popup   TYPE string VALUE `POPUP`,
        popover TYPE string VALUE `POPOVER`,
        view    TYPE string VALUE `VIEW`,
      END OF cs_kind.

    TYPES:
      "! Something the user was shown by a response.
      BEGIN OF ty_s_shown,
        kind TYPE string,
        type TYPE string,
        text TYPE string,
      END OF ty_s_shown.
    TYPES ty_t_shown TYPE STANDARD TABLE OF ty_s_shown WITH DEFAULT KEY.

    TYPES:
      "! A recorded roundtrip without its bodies.
      BEGIN OF ty_s_record,
        id            TYPE string,
        timestampl    TYPE timestampl,
        app           TYPE string,
        event         TYPE string,
        draft_id      TYPE string,
        draft_id_prev TYPE string,
        http_status   TYPE i,
        " server time of the roundtrip - run( ) only, 0 from record( )
        ms_total      TYPE i,
        " the user as stored - name or pseudonym, filled by get_variants only
        user          TYPE string,
      END OF ty_s_record.
    TYPES ty_t_record TYPE STANDARD TABLE OF ty_s_record WITH DEFAULT KEY.

    TYPES:
      "! One recorded roundtrip in full, as the recorder view shows it.
      BEGIN OF ty_s_detail,
        error       TYPE string,
        time        TYPE string,
        app         TYPE string,
        event       TYPE string,
        http_status TYPE i,
        ms_total    TYPE i,
        request     TYPE string,
        response    TYPE string,
        " what the response showed, and the values the request sent
        shown       TYPE string,
        input       TYPE string,
        " the view XML the response displayed, per slot
        view_xml    TYPE string,
      END OF ty_s_detail.

    TYPES:
      "! A screen as it was shown, ready to be displayed again: the
      "! namespaces of the recorded view and its content, with the recorded
      "! values in place of the bindings and the event handlers removed.
      BEGIN OF ty_s_screen,
        error     TYPE string,
        title     TYPE string,
        xmlns     TYPE string,
        content   TYPE string,
        " the popup the step's response opened, as a second content - with
        " the namespaces of its own view, declared on the element it is shown
        " in: content_defused checked it against those
        popup     TYPE string,
        popup_title TYPE string,
        popup_xmlns TYPE string,
        " the control of the event passed in is marked - class ckPressed
        marked    TYPE abap_bool,
      END OF ty_s_screen.

    TYPES:
      BEGIN OF ty_s_message,
        app   TYPE string,
        kind  TYPE string,
        type  TYPE string,
        text  TYPE string,
        count TYPE i,
        users TYPE i,
        last  TYPE string,
        state TYPE string,
        " the draft of the last roundtrip that showed it - its session opens there
        example TYPE string,
      END OF ty_s_message.
    TYPES ty_t_message TYPE STANDARD TABLE OF ty_s_message WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_messages,
        error        TYPE string,
        " recorded roundtrips read, and whether there were more
        records      TYPE i,
        check_capped TYPE abap_bool,
        t_message    TYPE ty_t_message,
      END OF ty_s_messages.

    "! The class a pressed control gets in a rebuilt screen.
    CONSTANTS c_pressed TYPE string VALUE `ckPressed`.
    "! The CSS that makes it stand out, for a core:HTML - plain braces, the
    "! attribute it goes into is escaped with xml_escape( ) once.
    CONSTANTS c_pressed_style TYPE string VALUE `<div><style>.ckPressed {outline: 3px solid #e9730c !important; outline-offset: 2px; box-shadow: 0 0 0 6px rgba(233,115,12,0.3) !important;}</style></div>`.

    TYPES:
      "! A process variant: one way through the apps, the events in order.
      BEGIN OF ty_s_variant,
        path     TYPE string,
        runs     TYPE i,
        share    TYPE string,
        users    TYPE i,
        steps    TYPE i,
        failed   TYPE i,
        last     TYPE string,
        last_ts  TYPE timestampl,
        state    TYPE string,
        " the newest run's last draft - its session opens there
        example  TYPE string,
      END OF ty_s_variant.
    TYPES ty_t_variant TYPE STANDARD TABLE OF ty_s_variant WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_variants,
        error        TYPE string,
        records      TYPE i,
        runs         TYPE i,
        failed_runs  TYPE i,
        check_capped TYPE abap_bool,
        t_variant    TYPE ty_t_variant,
      END OF ty_s_variants.

    TYPES:
      "! A roundtrip as input_errors_of takes it.
      BEGIN OF ty_s_exchange,
        app         TYPE string,
        request     TYPE string,
        response    TYPE string,
        http_status TYPE i,
      END OF ty_s_exchange.
    TYPES ty_t_exchange TYPE STANDARD TABLE OF ty_s_exchange WITH DEFAULT KEY.

    TYPES:
      "! A field users typed, and how often an error followed in the same roundtrip.
      BEGIN OF ty_s_input,
        app     TYPE string,
        field   TYPE string,
        typed   TYPE i,
        errors  TYPE i,
        rate    TYPE string,
        message TYPE string,
        samples TYPE string,
        state   TYPE string,
      END OF ty_s_input.
    TYPES ty_t_input TYPE STANDARD TABLE OF ty_s_input WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_inputs,
        error        TYPE string,
        records      TYPE i,
        check_capped TYPE abap_bool,
        t_input      TYPE ty_t_input,
      END OF ty_s_inputs.

    "! The one line for the ICF handler - in place of abap2UI5's own call:
    "! runs abap2UI5, takes the time, records the request and response and
    "! feeds the roundtrip statistics (z2ui5_cl_cockpit_rec) - the monitor
    "! without the monitor hook, on every abap2UI5 release. A monitor class
    "! that recorded the roundtrip already is not counted twice. Only what
    "! abap2UI5 raises leaves it, the cockpit's own part never does.
    "! @parameter server | Standard ABAP: the IF_HTTP_SERVER of the handler
    "! @parameter req    | ABAP Cloud: the IF_WEB_HTTP_REQUEST
    "! @parameter res    | ABAP Cloud: the IF_WEB_HTTP_RESPONSE
    CLASS-METHODS run
      IMPORTING
        server TYPE REF TO object OPTIONAL
        req    TYPE REF TO object OPTIONAL
        res    TYPE REF TO object OPTIONAL.

    "! A roundtrip for the statistics, taken from its request and response:
    "! app, event, drafts, sizes, the browser time of the roundtrip before,
    "! and for a failure the error text and the innermost exception class
    "! of the 500 body. The phases of the monitor hook stay 0.
    "! @parameter request     | the request body
    "! @parameter response    | the response body
    "! @parameter http_status | the HTTP status of the response
    "! @parameter check_sticky | the roundtrip ran in a stateful session
    CLASS-METHODS roundtrip_of
      IMPORTING
        request       TYPE string
        response      TYPE string
        http_status   TYPE i
        check_sticky  TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cockpit_rec=>ty_s_roundtrip.

    "! Milliseconds between two time stamps - by hand, as seconds_between.
    CLASS-METHODS ms_between
      IMPORTING
        ts_from       TYPE timestampl
        ts_to         TYPE timestampl
      RETURNING
        VALUE(result) TYPE i.

    "! Record the roundtrip that just ran - the line for the ICF handler
    "! after abap2UI5's own call, when that one stays: the request and
    "! response only, no statistics (no time to take). Never raises.
    "! @parameter server | Standard ABAP: the IF_HTTP_SERVER of the handler
    "! @parameter req    | ABAP Cloud: the IF_WEB_HTTP_REQUEST
    "! @parameter res    | ABAP Cloud: the IF_WEB_HTTP_RESPONSE
    CLASS-METHODS record
      IMPORTING
        server TYPE REF TO object OPTIONAL
        req    TYPE REF TO object OPTIONAL
        res    TYPE REF TO object OPTIONAL.

    "! Record a roundtrip from its bodies - what record( ) does once it has
    "! read them, and what a host without an ICF server calls. Commits,
    "! unless the session is sticky: then the recording waits in the roll
    "! area for the next roundtrip that is not. Never raises.
    CLASS-METHODS record_bodies
      IMPORTING
        request      TYPE string
        response     TYPE string
        http_status  TYPE i DEFAULT 200
        check_sticky TYPE abap_bool DEFAULT abap_false
        ms_total     TYPE i DEFAULT 0.

    "! The recorded roundtrips that wrote one of the drafts or started from
    "! one - the steps of a session. Never raises.
    CLASS-METHODS get_records
      IMPORTING
        it_id         TYPE z2ui5_cl_cockpit_session=>ty_t_id
      RETURNING
        VALUE(result) TYPE ty_t_record.

    "! The bodies of a recording - request and response as they were sent.
    "! Both empty when it is gone. Never raises.
    CLASS-METHODS get_bodies
      IMPORTING
        id       TYPE clike
      EXPORTING
        request  TYPE string
        response TYPE string.

    "! A recorded roundtrip in full, taken apart. Never raises.
    CLASS-METHODS get_detail
      IMPORTING
        id            TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_detail.

    "! What the responses of the last days showed the users - message boxes,
    "! toasts and popups per app, counted, the most frequent first. Reads at
    "! most c_max_read recordings, the newest. Never raises.
    CLASS-METHODS get_messages
      IMPORTING
        days          TYPE i
      RETURNING
        VALUE(result) TYPE ty_s_messages.

    "! The number of roundtrips recorded since the given number of days.
    CLASS-METHODS count_records
      IMPORTING
        days          TYPE i DEFAULT 1
      RETURNING
        VALUE(result) TYPE i.

    "! A JSON document as path and value of every leaf - object members by
    "! name, array elements by their position from 1, joined with "/".
    "! Raises on a text that is no JSON.
    CLASS-METHODS json_flatten
      IMPORTING
        json          TYPE string
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cockpit_session=>ty_t_value
      RAISING
        cx_static_check.

    "! What a response showed: message boxes (type, text), toasts, popups and
    "! popovers (their title) and a new main view (its title). Empty for a
    "! body that is no abap2UI5 response.
    CLASS-METHODS shown_of
      IMPORTING
        response      TYPE string
      RETURNING
        VALUE(result) TYPE ty_t_shown.

    "! The values a request sent - the model fields the user changed - and
    "! the event arguments, as path and value.
    CLASS-METHODS input_of
      IMPORTING
        request       TYPE string
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cockpit_session=>ty_t_value.

    "! The view XML a response displayed, per slot.
    CLASS-METHODS views_of
      IMPORTING
        response      TYPE string
      RETURNING
        VALUE(result) TYPE z2ui5_if_client=>ty_t_name_value.

    "! The control of a view that fires an event, as "Button "Save"" - its
    "! text, tooltip, icon or id. Empty when the view has no such control.
    CLASS-METHODS control_of
      IMPORTING
        xml           TYPE string
        event         TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! The control of a view bound to a model path, as "Input "Quantity"" -
    "! with the text of the Label right before it. Empty when none is.
    CLASS-METHODS field_control_of
      IMPORTING
        xml           TYPE string
        path          TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! A recorded view made displayable again: its namespaces and its
    "! content, every binding replaced by the value of the model (a table
    "! bound by items repeated per row, at most 50), every event handler
    "! emptied - a press in the copy fires nothing - and nothing that runs
    "! in the browser by itself (content_defused).
    "! @parameter xml        | the view XML of a display action (an mvc:View)
    "! @parameter it_model   | the model as path and value (json_flatten)
    "! @parameter event      | the event pressed next - its control marked (mark_pressed)
    CLASS-METHODS screen_of
      IMPORTING
        xml           TYPE string
        it_model      TYPE z2ui5_cl_cockpit_session=>ty_t_value
        event         TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_screen.

    "! The screen a step showed, rebuilt from the recordings up to it: the
    "! last main view displayed, the model as the responses and requests
    "! left it, and the popup the step's own response opened. Never raises.
    "! @parameter it_id | the recordings that wrote the steps up to this one, oldest first
    "! @parameter event | the event the user raised next on this screen - its control is marked
    CLASS-METHODS get_screen
      IMPORTING
        it_id         TYPE z2ui5_cl_cockpit_session=>ty_t_id
        event         TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_s_screen.

    "! The fields users typed, each with how often the same roundtrip
    "! answered with an error - an error box or a failure (HTTP 500): the
    "! inputs a process stumbles over. Rows of a table count as one field
    "! (MT_ITEM/*/QTY). Only fields followed by an error at least once, the
    "! most errors first, at most 50.
    "! @parameter it_exchange | the roundtrips, newest first
    CLASS-METHODS input_errors_of
      IMPORTING
        it_exchange   TYPE ty_t_exchange
      RETURNING
        VALUE(result) TYPE ty_t_input.

    "! input_errors_of over the recordings of the last days. Never raises.
    CLASS-METHODS get_input_errors
      IMPORTING
        days          TYPE i
      RETURNING
        VALUE(result) TYPE ty_s_inputs.

    "! get_messages and get_input_errors from one read of the recordings -
    "! the Errors tab asks for both. Never raises.
    CLASS-METHODS get_trouble
      IMPORTING
        days     TYPE i
      EXPORTING
        messages TYPE ty_s_messages
        inputs   TYPE ty_s_inputs.

    "! A recorded popup taken apart for showing it inline: what its Dialog
    "! or Popover holds, and its buttons. Its outer element goes, a popup
    "! cannot be shown inside another one.
    "! @parameter popup   | the popup content of a screen (screen_of)
    "! @parameter content | the content aggregation, else all that is not a button
    "! @parameter buttons | the buttons, beginButton and endButton
    CLASS-METHODS popup_parts
      IMPORTING
        popup   TYPE string
      EXPORTING
        content TYPE string
        buttons TYPE string.

    "! The process variants in recordings: every run from the start of a
    "! session to where it ended, as its events in order - a repeated event
    "! once, a failed click in place, an app change named. Runs of the same
    "! path are counted together, the most frequent first.
    "! @parameter it_record | the recordings, any order
    "! @parameter app       | only runs that pass this app, all when empty
    CLASS-METHODS variants_of
      IMPORTING
        it_record     TYPE ty_t_record
        app           TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_variant.

    "! The process variants of the recordings of the last days - see
    "! variants_of. Reads no body. Never raises.
    CLASS-METHODS get_variants
      IMPORTING
        app           TYPE clike OPTIONAL
        days          TYPE i
      RETURNING
        VALUE(result) TYPE ty_s_variants.

    "! Mark the control that raises an event in view XML with the class
    "! ckPressed - the first one, its class attribute extended or added.
    "! @parameter event  | the event as the request named it
    "! @parameter result | whether one was found
    CLASS-METHODS mark_pressed
      IMPORTING
        event         TYPE clike
      CHANGING
        xml           TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! A value made safe for an XML attribute.
    CLASS-METHODS xml_escape
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! The shown items as one line, for a table cell.
    CLASS-METHODS shown_text
      IMPORTING
        it_shown      TYPE ty_t_shown
      RETURNING
        VALUE(result) TYPE string.

    "! Whether a member is named like a password (c_secret_names, case
    "! ignored) - its value is never stored, and never shown.
    CLASS-METHODS check_secret
      IMPORTING
        name          TYPE clike
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! The model members bound to a password input of a view the response
    "! displays - Input type="Password" - by their last name.
    CLASS-METHODS secret_names_of
      IMPORTING
        response      TYPE string
      RETURNING
        VALUE(result) TYPE string_table.

  PROTECTED SECTION.

  PRIVATE SECTION.

    TYPES:
      "! A roundtrip of a sticky session, as it came - the row is built once
      "! the LUW may be written (the pseudonym's salt is a write of its own).
      BEGIN OF ty_s_pending,
        request      TYPE string,
        response     TYPE string,
        http_status  TYPE i,
        check_sticky TYPE abap_bool,
        ms_total     TYPE i,
        timestampl   TYPE timestampl,
      END OF ty_s_pending.

    " member names whose values are never stored: a password, a secret
    " (case ignored)
    CONSTANTS c_secret_names TYPE string VALUE `[A-Z0-9_]*(PASSW|KENNWORT|PWD|SECRET)[A-Z0-9_]*`.

    TYPES ty_t_row TYPE STANDARD TABLE OF z2ui5_t_28 WITH DEFAULT KEY.

    TYPES:
      "! A recording as the message and input statistics read it.
      BEGIN OF ty_s_read,
        app           TYPE c LENGTH 30,
        uname         TYPE c LENGTH 12,
        user_key      TYPE c LENGTH 64,
        timestampl    TYPE timestampl,
        draft_id      TYPE c LENGTH 32,
        draft_id_prev TYPE c LENGTH 32,
        http_status   TYPE i,
        req_body      TYPE string,
        res_body      TYPE string,
      END OF ty_s_read.
    TYPES ty_t_read TYPE STANDARD TABLE OF ty_s_read WITH DEFAULT KEY.

    "! The newest recordings of the last days, at most c_max_read.
    "! @parameter check_request | with the request bodies - else they stay empty
    CLASS-METHODS read_recent
      IMPORTING
        days          TYPE i
        check_request TYPE abap_bool
      RETURNING
        VALUE(result) TYPE ty_t_read
      RAISING
        cx_static_check.

    "! What the responses showed - get_messages over rows read already.
    CLASS-METHODS messages_from
      IMPORTING
        it_row        TYPE ty_t_read
      RETURNING
        VALUE(result) TYPE ty_s_messages.

    "! The inputs before errors - get_input_errors over rows read already.
    CLASS-METHODS inputs_from
      IMPORTING
        it_row        TYPE ty_t_read
      RETURNING
        VALUE(result) TYPE ty_s_inputs.

    CLASS-DATA gt_buffer TYPE STANDARD TABLE OF ty_s_pending WITH DEFAULT KEY.

    "! The secret members of the screen a request comes from. Its password
    "! inputs are in the view of an earlier response - the one that wrote
    "! the draft the request starts from (secret_names_of), or, when that
    "! one displayed no view, the members it masked itself, carried forward.
    "! @parameter draft_id_prev | the draft the request starts from - the key
    "!                            of that recording (row_of)
    "! @parameter it_before     | rows of the same write, not in the table yet
    CLASS-METHODS secret_names_before
      IMPORTING
        draft_id_prev TYPE clike
        it_before     TYPE ty_t_row OPTIONAL
      RETURNING
        VALUE(result) TYPE string_table.

    "! The key of a recording: the draft it wrote, so the next roundtrip of
    "! the session finds it by key (secret_names_before) - a UUID when it
    "! wrote none or the draft has a recording already.
    CLASS-METHODS id_of
      IMPORTING
        draft_id      TYPE clike
        it_before     TYPE ty_t_row OPTIONAL
      RETURNING
        VALUE(result) TYPE z2ui5_t_28-id
      RAISING
        cx_static_check.

    "! A body with the values of secret members replaced by "***": every
    "! member named like a password (c_secret_names) and every member of
    "! it_name. Strings and numbers - objects and arrays stay.
    CLASS-METHODS masked
      IMPORTING
        body          TYPE string
        it_name       TYPE string_table
      RETURNING
        VALUE(result) TYPE string.

    "! The content of a copy without what runs in the browser by itself: a
    "! sap.ui.core.HTML renders its content with the scripts and on...
    "! handlers in it, XHTML and SVG elements carry handlers of their own,
    "! the framework's helper controls (z2ui5.cc) write the local storage,
    "! push the browser history, open a socket, and custom controls of the
    "! addons or a third party load scripts and render HTML - all of it in
    "! the administrator's cockpit. An HTML control is sanitized
    "! (sanitizeContent, whatever the app set); only the elements of an
    "! allowlist of UI5 libraries are kept, every other one is left out.
    "! @parameter xml     | the recorded view - its namespace declarations
    "! @parameter content | the part of it the copy shows
    CLASS-METHODS content_defused
      IMPORTING
        xml           TYPE string
        content       TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! xml without the elements of every prefix not kept, each with all it
    "! contains - an element of the default namespace has the prefix ``.
    "! @parameter it_keep   | the prefixes kept, each with its colon - m:
    "! @parameter it_strict | kept prefixes of which only the controls in
    "!                       it_allow stay, and every aggregation (a name
    "!                       starting in lower case)
    "! @parameter it_allow  | the controls kept of a strict prefix - core:Icon
    CLASS-METHODS elements_dropped
      IMPORTING
        xml           TYPE string
        it_keep       TYPE string_table
        it_strict     TYPE string_table OPTIONAL
        it_allow      TYPE string_table OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

    TYPES:
      BEGIN OF ty_s_bound,
        path  TYPE string,
        value TYPE string,
      END OF ty_s_bound.
    TYPES ty_t_bound TYPE HASHED TABLE OF ty_s_bound WITH UNIQUE KEY path.

    "! text with every binding {open}NAME} whose path prefix &amp;&amp; NAME has a
    "! value in it_bound replaced by that value, which is escaped already -
    "! one pass over the text, the other bindings stay as they are.
    "! @parameter open   | what a binding starts with - {/ for the absolute ones
    "! @parameter prefix | put in front of NAME - the row of a template
    CLASS-METHODS bindings_replaced
      IMPORTING
        text          TYPE string
        open          TYPE string
        prefix        TYPE string
        it_bound      TYPE ty_t_bound
      RETURNING
        VALUE(result) TYPE string.

    "! xml without every attribute of that name - with the blank before it.
    "! @parameter name | the attribute with its prefix - core:require
    CLASS-METHODS attribute_dropped
      IMPORTING
        xml           TYPE string
        name          TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! The request and response of the roundtrip that just ran, read from
    "! the handler's objects by name. False when it was no POST or nothing
    "! could be read.
    CLASS-METHODS read_exchange
      IMPORTING
        server        TYPE REF TO object OPTIONAL
        req           TYPE REF TO object OPTIONAL
        res           TYPE REF TO object OPTIONAL
      EXPORTING
        request       TYPE string
        response      TYPE string
        http_status   TYPE i
        check_sticky  TYPE abap_bool
      RETURNING
        VALUE(result) TYPE abap_bool
      RAISING
        cx_static_check.

    "! The table row of a recorded roundtrip - ids, app and event taken out
    "! of the bodies (roundtrip_of), the user as the privacy setting allows,
    "! the values of password fields masked.
    "! @parameter timestampl | when it ran - now when initial
    "! @parameter it_before  | rows of the same write, not in the table yet
    CLASS-METHODS row_of
      IMPORTING
        request       TYPE string
        response      TYPE string
        http_status   TYPE i
        check_sticky  TYPE abap_bool
        ms_total      TYPE i DEFAULT 0
        timestampl    TYPE timestampl OPTIONAL
        it_before     TYPE ty_t_row OPTIONAL
      RETURNING
        VALUE(result) TYPE z2ui5_t_28
      RAISING
        cx_static_check.

    "! The value of a JSON string member, found by text - "ID":"..." - and
    "! only before the end marker, where the response's own members stand.
    CLASS-METHODS member_before
      IMPORTING
        json          TYPE string
        name          TYPE string
        before        TYPE i
      RETURNING
        VALUE(result) TYPE string.

    "! The value of an XML attribute in the first element that has it -
    "! z2ui5_cl_cockpit_session=&gt;xml_attribute( ).
    CLASS-METHODS xml_attribute
      IMPORTING
        xml           TYPE string
        name          TYPE string
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS z2ui5_cl_cockpit_wire IMPLEMENTATION.

  METHOD run.

    DATA lv_request TYPE string.
    DATA lv_response TYPE string.
    DATA lv_status TYPE i.
    DATA lv_sticky TYPE abap_bool.
    DATA lv_start TYPE timestampl.
    DATA lv_end TYPE timestampl.
    DATA lv_count TYPE i.
        DATA lv_ms TYPE i.
        DATA ls_roundtrip TYPE z2ui5_cl_cockpit_rec=>ty_s_roundtrip.

    GET TIME STAMP FIELD lv_start.

    lv_count = z2ui5_cl_cockpit_rec=>get_count( ).
    IF server IS BOUND.
      z2ui5_cl_ui5_http_handler=>run( server ).
    ELSE.
      z2ui5_cl_ui5_http_handler=>run( req = req
                                      res = res ).
    ENDIF.
    GET TIME STAMP FIELD lv_end.

    TRY.
        IF read_exchange( EXPORTING server       = server
                                    req          = req
                                    res          = res
                          IMPORTING request      = lv_request
                                    response     = lv_response
                                    http_status  = lv_status
                                    check_sticky = lv_sticky ) = abap_false.
          RETURN.
        ENDIF.

        lv_ms = ms_between( ts_from = lv_start
                                  ts_to   = lv_end ).
        record_bodies( request      = lv_request
                       response     = lv_response
                       http_status  = lv_status
                       check_sticky = lv_sticky
                       ms_total     = lv_ms ).

        " a monitor class recorded it already - with its phases
        IF z2ui5_cl_cockpit_rec=>get_count( ) > lv_count.
          RETURN.
        ENDIF.

        ls_roundtrip = roundtrip_of( request      = lv_request
                                           response     = lv_response
                                           http_status  = lv_status
                                           check_sticky = lv_sticky ).
        ls_roundtrip-timestampl = lv_start.
        ls_roundtrip-ms_total   = lv_ms.
        ls_roundtrip-uname      = sy-uname.
        " a failed roundtrip names no app - the draft it started from does
        IF ls_roundtrip-app IS INITIAL AND ls_roundtrip-draft_id_prev IS NOT INITIAL.
          ls_roundtrip-app = z2ui5_cl_cockpit_session=>get_app_of_draft( ls_roundtrip-draft_id_prev ).
        ENDIF.
        z2ui5_cl_cockpit_rec=>record( ls_roundtrip ).
      CATCH cx_root ##NO_HANDLER.
        " never break a roundtrip because of the cockpit
    ENDTRY.

  ENDMETHOD.

  METHOD record.

    DATA lv_request TYPE string.
    DATA lv_response TYPE string.
    DATA lv_status TYPE i.
    DATA lv_sticky TYPE abap_bool.

    TRY.
        IF read_exchange( EXPORTING server       = server
                                    req          = req
                                    res          = res
                          IMPORTING request      = lv_request
                                    response     = lv_response
                                    http_status  = lv_status
                                    check_sticky = lv_sticky ) = abap_false.
          RETURN.
        ENDIF.
        record_bodies( request      = lv_request
                       response     = lv_response
                       http_status  = lv_status
                       check_sticky = lv_sticky ).
      CATCH cx_root ##NO_HANDLER.
        " never break a roundtrip because of the recorder
    ENDTRY.

  ENDMETHOD.

  METHOD read_exchange.

    DATA lo_req TYPE REF TO object.
    DATA lo_res TYPE REF TO object.
    DATA lv_method TYPE string.
    DATA lr_status TYPE REF TO data.
    FIELD-SYMBOLS <any> TYPE any.
    FIELD-SYMBOLS <status> TYPE any.
    FIELD-SYMBOLS <code> TYPE any.
        DATA temp1 TYPE xsdboolean.

    CLEAR request.
    CLEAR response.
    CLEAR http_status.
    CLEAR check_sticky.

    IF server IS BOUND.
      " the same dynamic access abap2UI5 uses - IS ASSIGNED, never sy-subrc
      UNASSIGN <any>.
      ASSIGN server->(`REQUEST`) TO <any>.
      IF <any> IS NOT ASSIGNED.
        RETURN.
      ENDIF.
      lo_req = <any>.
      UNASSIGN <any>.
      ASSIGN server->(`RESPONSE`) TO <any>.
      IF <any> IS NOT ASSIGNED.
        RETURN.
      ENDIF.
      lo_res = <any>.

      CALL METHOD lo_req->(`IF_HTTP_REQUEST~GET_METHOD`)
        RECEIVING
          method = lv_method.
      IF to_upper( lv_method ) <> `POST`.
        RETURN.
      ENDIF.
      CALL METHOD lo_req->(`GET_CDATA`)
        RECEIVING
          data = request.
      CALL METHOD lo_res->(`GET_CDATA`)
        RECEIVING
          data = response.
      TRY.
          CALL METHOD lo_res->(`IF_HTTP_RESPONSE~GET_STATUS`)
            IMPORTING
              code = http_status.
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
      UNASSIGN <any>.
      ASSIGN server->(`STATEFUL`) TO <any>.
      IF <any> IS NOT ASSIGNED.
        " the attribute of if_http_server, where the class has no alias for it
        ASSIGN server->(`IF_HTTP_SERVER~STATEFUL`) TO <any>.
      ENDIF.
      IF <any> IS ASSIGNED.

        temp1 = boolc( <any> = 1 ).
        check_sticky = temp1.
      ENDIF.

    ELSEIF req IS BOUND AND res IS BOUND.
      CALL METHOD req->(`IF_WEB_HTTP_REQUEST~GET_METHOD`)
        RECEIVING
          r_value = lv_method.
      IF to_upper( lv_method ) <> `POST`.
        RETURN.
      ENDIF.
      CALL METHOD req->(`IF_WEB_HTTP_REQUEST~GET_TEXT`)
        RECEIVING
          r_value = request.
      CALL METHOD res->(`IF_WEB_HTTP_RESPONSE~GET_TEXT`)
        RECEIVING
          r_value = response.
      TRY.
          CREATE DATA lr_status TYPE (`IF_WEB_HTTP_RESPONSE=>HTTP_STATUS`).
          ASSIGN lr_status->* TO <status>.
          CALL METHOD res->(`IF_WEB_HTTP_RESPONSE~GET_STATUS`)
            RECEIVING
              r_value = <status>.
          ASSIGN COMPONENT `CODE` OF STRUCTURE <status> TO <code>.
          IF <code> IS ASSIGNED.
            http_status = <code>.
          ENDIF.
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.

    ELSE.
      RETURN.
    ENDIF.

    result = abap_true.

  ENDMETHOD.

  METHOD roundtrip_of.

    DATA lv_root TYPE string.
    DATA temp3 TYPE xsdboolean.
        DATA lt_request TYPE z2ui5_cl_cockpit_session=>ty_t_value.
        DATA temp49 TYPE string.
        DATA temp9 LIKE sy-subrc.
        DATA temp10 LIKE sy-subrc.
        DATA temp1 LIKE sy-subrc.
        DATA temp2 LIKE sy-subrc.
        DATA lv_id_path TYPE string.
        DATA lv_event_path TYPE string.
        DATA lv_client_path TYPE string.
        DATA temp50 TYPE z2ui5_cl_cockpit_rec=>ty_s_roundtrip-draft_id_prev.
        DATA temp51 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
        DATA temp52 TYPE z2ui5_cl_cockpit_rec=>ty_s_roundtrip-event.
        DATA temp53 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
        DATA temp54 TYPE string.
        DATA temp55 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
        DATA lv_client LIKE temp54.
    DATA temp4 TYPE xsdboolean.
      DATA lv_protocol TYPE i.
      DATA lv_model TYPE i.
    DATA lv_at TYPE i.
      DATA lv_close TYPE i.
        DATA lv_class TYPE string.
        DATA lv_end TYPE i.

    result-check_sticky   = check_sticky.
    result-bytes_request  = strlen( request ).
    result-bytes_response = strlen( response ).

    temp3 = boolc( http_status >= 500 ).
    result-check_error    = temp3.

    TRY.

        lt_request = json_flatten( request ).



        temp10 = sy-subrc.
        READ TABLE lt_request WITH KEY path = `value/S_FRONT/ID` TRANSPORTING NO FIELDS.
        temp9 = sy-subrc.
        sy-subrc = temp10.


        temp2 = sy-subrc.
        READ TABLE lt_request WITH KEY path = `value/S_FRONT/EVENT` TRANSPORTING NO FIELDS.
        temp1 = sy-subrc.
        sy-subrc = temp2.
        IF temp9 = 0 OR temp1 = 0.
          temp49 = `value/`.
        ELSE.
          CLEAR temp49.
        ENDIF.
        lv_root = temp49.
        " the keys in variables - a template is no key operand on 7.02

        lv_id_path = |{ lv_root }S_FRONT/ID|.

        lv_event_path = |{ lv_root }S_FRONT/EVENT|.

        lv_client_path = |{ lv_root }S_FRONT/MS_CLIENT_PREV|.

        CLEAR temp50.

        READ TABLE lt_request INTO temp51 WITH KEY path = lv_id_path.
        IF sy-subrc = 0.
          temp50 = temp51-value.
        ENDIF.
        result-draft_id_prev = temp50.

        CLEAR temp52.

        READ TABLE lt_request INTO temp53 WITH KEY path = lv_event_path.
        IF sy-subrc = 0.
          temp52 = temp53-value.
        ENDIF.
        result-event         = temp52.

        CLEAR temp54.

        READ TABLE lt_request INTO temp55 WITH KEY path = lv_client_path.
        IF sy-subrc = 0.
          temp54 = temp55-value.
        ENDIF.

        lv_client = temp54.
        IF lv_client CO `0123456789` AND lv_client IS NOT INITIAL AND strlen( lv_client ) < 10.
          result-ms_client_prev = lv_client.
        ENDIF.
      CATCH cx_root ##NO_HANDLER.
        " no JSON - counted as it came
    ENDTRY.

    temp4 = boolc( result-draft_id_prev IS INITIAL ).
    result-check_start = temp4.

    IF result-check_error = abap_false.
      " id and app stand first in S_FRONT, before PROTOCOL - found by text

      lv_protocol = find( val = response
                                sub = `"PROTOCOL":` ).
      IF lv_protocol > 0.
        result-draft_id = member_before( json   = response
                                         name   = `ID`
                                         before = lv_protocol ).
        result-app      = to_upper( member_before( json   = response
                                                   name   = `APP`
                                                   before = lv_protocol ) ).
      ENDIF.

      lv_model = find( val = response
                             sub = `,"MODEL":` ).
      IF lv_model > 0.
        " up to the closing brace of the response itself
        result-bytes_model = strlen( response ) - lv_model - 10.
      ENDIF.
      RETURN.
    ENDIF.

    " the 500 body: the error text, then the exception chain as lines
    " [1] CLASS ... [n] CLASS - the last one is the root cause
    result-error_text = response.

    lv_at = find( val = response
                        sub = |\n[|
                        occ = -1 ).
    IF lv_at >= 0.

      lv_close = find( val = response
                             sub = `] `
                             off = lv_at ).
      IF lv_close > lv_at.

        lv_class = substring( val = response
                                    off = lv_close + 2 ).

        lv_end = find( val = lv_class
                             regex = `[\s:]` ).
        IF lv_end > 0.
          lv_class = substring( val = lv_class
                                len = lv_end ).
        ENDIF.
        IF strlen( lv_class ) <= 30.
          result-error_class = to_upper( lv_class ).
        ENDIF.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD ms_between.

    " typed, not inline: the fractions are decimals
    DATA lv_frac TYPE p LENGTH 16 DECIMALS 7.

    " whole seconds by hand, then the fractions of both - see seconds_between
    DATA lv_seconds TYPE i.
    lv_seconds = z2ui5_cl_cockpit_session=>seconds_between( ts_from = ts_from
                                                                  ts_to   = ts_to ).
    lv_frac = frac( ts_to ) - frac( ts_from ).
    result = lv_seconds * 1000 + round( val = lv_frac * 1000
                                        dec = 0 ).
    IF result < 0.
      result = 0.
    ENDIF.

  ENDMETHOD.

  METHOD record_bodies.

    DATA ls_row TYPE z2ui5_t_28.
    DATA lt_row TYPE ty_t_row.
        DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
        DATA temp56 TYPE ty_s_pending.
        DATA ls_pending LIKE temp56.
        DATA lv_own TYPE string.
        DATA lt_buffer LIKE gt_buffer.
        DATA ls_buffered LIKE LINE OF lt_buffer.

    TRY.

        ls_set = z2ui5_cl_cockpit_setup=>get( ).
        IF ls_set-wire_days <= 0 OR request IS INITIAL.
          RETURN.
        ENDIF.


        CLEAR temp56.
        temp56-request = request.
        temp56-response = response.
        temp56-http_status = http_status.
        temp56-check_sticky = check_sticky.
        temp56-ms_total = ms_total.
        temp56-timestampl = z2ui5_cl_cockpit_setup=>now( ).

        ls_pending = temp56.

        " a sticky app owns the LUW - its uncommitted work and locks must not
        " be committed by the recorder, and nothing is written into it, not
        " even the salt of a pseudonym: the bodies wait as they came for a
        " roundtrip that is not sticky
        IF check_sticky = abap_true.
          IF lines( gt_buffer ) < c_buffer_max.
            APPEND ls_pending TO gt_buffer.
          ENDIF.
          RETURN.
        ENDIF.

        z2ui5_cl_cockpit_job=>purge_daily( ).

        " the cockpit's own screens are not recorded: they show recordings,
        " sessions and figures of other users - a copy of them per roundtrip

        lv_own = z2ui5_cl_cockpit_inst=>obj_name( `CL_COCKPIT_APP` ).

        lt_buffer = gt_buffer.
        CLEAR gt_buffer.
        APPEND ls_pending TO lt_buffer.

        LOOP AT lt_buffer INTO ls_buffered.
          ls_row = row_of( request      = ls_buffered-request
                           response     = ls_buffered-response
                           http_status  = ls_buffered-http_status
                           check_sticky = ls_buffered-check_sticky
                           ms_total     = ls_buffered-ms_total
                           timestampl   = ls_buffered-timestampl
                           it_before    = lt_row ).
          IF ls_row-app = lv_own.
            CONTINUE.
          ENDIF.
          APPEND ls_row TO lt_row.
        ENDLOOP.
        " a key taken in the meantime costs that one recording, not all
        INSERT z2ui5_t_28 FROM TABLE lt_row ACCEPTING DUPLICATE KEYS.
        COMMIT WORK.
      CATCH cx_root.
        IF check_sticky = abap_false.
          TRY.
              ROLLBACK WORK.                             "#EC CI_ROLLBACK
            CATCH cx_root ##NO_HANDLER.
          ENDTRY.
        ENDIF.
    ENDTRY.

  ENDMETHOD.

  METHOD row_of.

    DATA lt_secret TYPE string_table.
    DATA ls_roundtrip TYPE z2ui5_cl_cockpit_rec=>ty_s_roundtrip.

    result-timestampl   = timestampl.
    IF result-timestampl IS INITIAL.
      result-timestampl = z2ui5_cl_cockpit_setup=>now( ).
    ENDIF.
    result-utc_day      = z2ui5_cl_cockpit_setup=>day_of( result-timestampl ).
    result-http_status  = http_status.
    result-ms_total     = ms_total.
    result-check_sticky = check_sticky.
    result-user_key     = z2ui5_cl_cockpit_setup=>user_key( uname = sy-uname
                                                            day   = result-utc_day ).
    IF z2ui5_cl_cockpit_setup=>check_privacy( ) = abap_false.
      result-uname = sy-uname.
    ENDIF.

    " the draft it started from and its event out of the request, the
    " draft it wrote and the app out of the response - as for the statistics

    ls_roundtrip = roundtrip_of( request      = request
                                       response     = response
                                       http_status  = http_status
                                       check_sticky = check_sticky ).
    result-draft_id_prev = ls_roundtrip-draft_id_prev.
    result-event         = ls_roundtrip-event.
    result-draft_id      = ls_roundtrip-draft_id.
    result-app           = ls_roundtrip-app.
    " a failure names no app - the draft it started from does
    IF result-app IS INITIAL AND result-draft_id_prev IS NOT INITIAL.
      result-app = to_upper( z2ui5_cl_cockpit_session=>get_app_of_draft( result-draft_id_prev ) ).
    ENDIF.
    result-id = id_of( draft_id  = result-draft_id
                       it_before = it_before ).

    " what was typed into a password field is never stored. The field is in
    " the view of the screen the user typed on - an earlier response: abap2UI5
    " sends a view only when the app renders one, so this response may have none
    lt_secret = secret_names_of( response ).
    APPEND LINES OF secret_names_before( draft_id_prev = result-draft_id_prev
                                         it_before     = it_before ) TO lt_secret.
    result-req_body = masked( body    = request
                              it_name = lt_secret ).
    result-res_body = masked( body    = response
                              it_name = lt_secret ).
    IF strlen( result-req_body ) > c_max_body.
      result-req_body = substring( val = result-req_body
                                   len = c_max_body ).
    ENDIF.
    IF strlen( result-res_body ) > c_max_body.
      result-res_body = substring( val = result-res_body
                                   len = c_max_body ).
    ENDIF.

  ENDMETHOD.

  METHOD check_secret.
    DATA temp5 TYPE xsdboolean.

    FIND FIRST OCCURRENCE OF REGEX c_secret_names IN name IGNORING CASE.

    temp5 = boolc( sy-subrc = 0 ).
    result = temp5.

  ENDMETHOD.

  METHOD id_of.

    DATA lv_taken TYPE z2ui5_t_28-id.
      DATA temp57 LIKE sy-subrc.
      DATA temp58 LIKE sy-subrc.

    IF draft_id IS NOT INITIAL AND strlen( draft_id ) <= 32.
      result = draft_id.


      temp58 = sy-subrc.
      READ TABLE it_before WITH KEY id = result TRANSPORTING NO FIELDS.
      temp57 = sy-subrc.
      sy-subrc = temp58.
      IF NOT temp57 = 0.    "#EC CI_SORTSEQ
        SELECT SINGLE id FROM z2ui5_t_28 INTO lv_taken
          WHERE id = result
          .
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
      ENDIF.
    ENDIF.
    result = cl_system_uuid=>create_uuid_c32_static( ).

  ENDMETHOD.

  METHOD secret_names_before.

    DATA lv_id TYPE z2ui5_t_28-id.
    DATA ls_before TYPE z2ui5_t_28.
    DATA lt_match TYPE match_result_tab.
    DATA temp59 TYPE z2ui5_t_28.
    DATA temp60 TYPE z2ui5_t_28.
    DATA ls_match LIKE LINE OF lt_match.

    IF draft_id_prev IS INITIAL OR strlen( draft_id_prev ) > 32.
      RETURN.
    ENDIF.
    lv_id = draft_id_prev.

    CLEAR temp59.

    READ TABLE it_before INTO temp60 WITH KEY id = lv_id.
    IF sy-subrc = 0.
      temp59 = temp60.
    ENDIF.
    ls_before = temp59. "#EC CI_SORTSEQ
    IF ls_before IS INITIAL.
      SELECT SINGLE req_body res_body FROM z2ui5_t_28 INTO CORRESPONDING FIELDS OF ls_before
        WHERE id = lv_id
        .
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
    ENDIF.

    result = secret_names_of( ls_before-res_body ).
    " "NAME":"***" - masked there, so secret here too: a response without a
    " view still sends the model, and the request carries what was typed
    FIND ALL OCCURRENCES OF REGEX `"[A-Za-z0-9_]+":"\*\*\*"` IN ls_before-req_body RESULTS lt_match.

    LOOP AT lt_match INTO ls_match.
      APPEND substring( val = ls_before-req_body
                        off = ls_match-offset + 1
                        len = ls_match-length - 8 ) TO result.
    ENDLOOP.
    FIND ALL OCCURRENCES OF REGEX `"[A-Za-z0-9_]+":"\*\*\*"` IN ls_before-res_body RESULTS lt_match.
    LOOP AT lt_match INTO ls_match.
      APPEND substring( val = ls_before-res_body
                        off = ls_match-offset + 1
                        len = ls_match-length - 8 ) TO result.
    ENDLOOP.
    " a name twice costs one more search in masked( ), nothing else

  ENDMETHOD.

  METHOD secret_names_of.

    DATA lt_match TYPE match_result_tab.
    DATA lv_kind TYPE string.
    DATA lv_name TYPE string.
    DATA ls_match LIKE LINE OF lt_match.
      DATA lv_element TYPE string.
      DATA lv_slash TYPE i.

    " a view in a response is a JSON string - its quotes are escaped
    IF response NS `"Password\"`.
      RETURN.
    ENDIF.
    FIND ALL OCCURRENCES OF REGEX `<[^<>]* type=\\"Password\\"[^<>]*>` IN response
      IGNORING CASE RESULTS lt_match.

    LOOP AT lt_match INTO ls_match.

      lv_element = substring( val = response
                                    off = ls_match-offset
                                    len = ls_match-length ).
      " value="{/XX/NAME}" or value="{path:'/XX/NAME', ...}" - the last name
      CLEAR lv_name.
      FIND FIRST OCCURRENCE OF REGEX ` value=\\"\{(path:')?([^}'\\]*)` IN lv_element
        SUBMATCHES lv_kind lv_name.

      lv_slash = find( val = lv_name
                             sub = `/`
                             occ = -1 ).
      IF lv_slash >= 0.
        lv_name = substring( val = lv_name
                             off = lv_slash + 1 ).
      ENDIF.
      " a name only - it goes into a pattern
      IF lv_name IS NOT INITIAL AND to_upper( lv_name ) CO `ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_`.
        APPEND lv_name TO result.
      ENDIF.
    ENDLOOP.
    SORT result BY table_line.
    DELETE ADJACENT DUPLICATES FROM result COMPARING table_line.

  ENDMETHOD.

  METHOD masked.

    " "NAME":"value" or "NAME":123 - the value becomes "***"
    CONSTANTS lc_value TYPE string VALUE `":\s*("([^"\\]|\\.)*"|-?[0-9][0-9.eE+-]*)`.
    DATA lv_name LIKE LINE OF it_name.

    result = body.
    IF result CS `PASSW` OR result CS `KENNWORT` OR result CS `PWD` OR result CS `SECRET`.
      REPLACE ALL OCCURRENCES OF REGEX |"({ c_secret_names }){ lc_value }| IN result
        WITH `"$1":"***"` IGNORING CASE.
    ENDIF.

    LOOP AT it_name INTO lv_name.
      IF result NS |"{ lv_name }":|.
        CONTINUE.
      ENDIF.
      REPLACE ALL OCCURRENCES OF REGEX |"({ lv_name }){ lc_value }| IN result
        WITH `"$1":"***"`.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_records.

    TYPES:
      BEGIN OF ty_s_row,
        id            TYPE c LENGTH 32,
        timestampl    TYPE timestampl,
        app           TYPE c LENGTH 30,
        event         TYPE c LENGTH 40,
        draft_id      TYPE c LENGTH 32,
        draft_id_prev TYPE c LENGTH 32,
        http_status   TYPE i,
        ms_total      TYPE i,
      END OF ty_s_row.
    TYPES temp1 TYPE STANDARD TABLE OF ty_s_row WITH DEFAULT KEY.
DATA lt_rows TYPE temp1.
        DATA lt_ranges TYPE z2ui5_cl_cockpit_session=>ty_t_id_range.
        DATA lt_range LIKE LINE OF lt_ranges.
    DATA ls_row LIKE LINE OF lt_rows.
      DATA temp61 TYPE z2ui5_cl_cockpit_wire=>ty_s_record.

    TRY.

        lt_ranges = z2ui5_cl_cockpit_session=>id_ranges( it_id ).

        LOOP AT lt_ranges INTO lt_range.
          SELECT id timestampl app event draft_id draft_id_prev http_status ms_total
            FROM z2ui5_t_28 APPENDING CORRESPONDING FIELDS OF TABLE lt_rows
            WHERE draft_id IN lt_range
               OR draft_id_prev IN lt_range
            .
        ENDLOOP.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    SORT lt_rows BY timestampl ASCENDING id ASCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_rows COMPARING id.

    LOOP AT lt_rows INTO ls_row.

      CLEAR temp61.
      temp61-id = ls_row-id.
      temp61-timestampl = ls_row-timestampl.
      temp61-app = ls_row-app.
      temp61-event = ls_row-event.
      temp61-draft_id = ls_row-draft_id.
      temp61-draft_id_prev = ls_row-draft_id_prev.
      temp61-http_status = ls_row-http_status.
      temp61-ms_total = ls_row-ms_total.
      APPEND temp61 TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_bodies.

    DATA lv_id TYPE c LENGTH 32.
    CLEAR request.
    CLEAR response.
    lv_id = id.
    TRY.
        SELECT SINGLE req_body res_body FROM z2ui5_t_28 INTO (request, response)
          WHERE id = lv_id
          .
        IF sy-subrc <> 0.
          CLEAR request.
          CLEAR response.
        ENDIF.
      CATCH cx_root.
        CLEAR request.
        CLEAR response.
    ENDTRY.

  ENDMETHOD.

  METHOD get_detail.

    DATA lv_id TYPE c LENGTH 32.
    DATA ls_row TYPE z2ui5_t_28.
    DATA lv_input TYPE string.
        DATA lx TYPE REF TO cx_root.
    DATA temp62 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_value LIKE LINE OF temp62.
      DATA temp63 TYPE string.
    DATA temp64 TYPE z2ui5_if_client=>ty_t_name_value.
    DATA ls_view LIKE LINE OF temp64.
      DATA temp65 TYPE string.

    lv_id = id.
    TRY.
        SELECT SINGLE * FROM z2ui5_t_28 INTO CORRESPONDING FIELDS OF ls_row
          WHERE id = lv_id
          .
        IF sy-subrc <> 0.
          result-error = `The recording is gone - deleted by its retention.`.
          RETURN.
        ENDIF.

      CATCH cx_root INTO lx.
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.

    result-time        = z2ui5_cl_cockpit_setup=>ts_text( ls_row-timestampl ).
    result-app         = ls_row-app.
    result-event       = ls_row-event.
    result-http_status = ls_row-http_status.
    result-ms_total    = ls_row-ms_total.
    result-request     = ls_row-req_body.
    result-response    = ls_row-res_body.
    result-shown       = shown_text( shown_of( ls_row-res_body ) ).

    temp62 = input_of( ls_row-req_body ).

    LOOP AT temp62 INTO ls_value.

      IF lv_input IS NOT INITIAL.
        temp63 = cl_abap_char_utilities=>newline.
      ELSE.
        CLEAR temp63.
      ENDIF.
      lv_input = |{ lv_input }{ temp63 }| &&
                 |{ ls_value-path } = { ls_value-value }|.
    ENDLOOP.
    result-input = lv_input.

    temp64 = views_of( ls_row-res_body ).

    LOOP AT temp64 INTO ls_view.

      IF result-view_xml IS NOT INITIAL.
        temp65 = cl_abap_char_utilities=>newline.
      ELSE.
        CLEAR temp65.
      ENDIF.
      result-view_xml = |{ result-view_xml }{ temp65 }| &&
                        |<!-- { ls_view-n } -->{ cl_abap_char_utilities=>newline }{ ls_view-v }|.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_messages.
        DATA lx TYPE REF TO cx_root.

    TRY.
        result = messages_from( read_recent( days          = days
                                             check_request = abap_false ) ).

      CATCH cx_root INTO lx.
        result-error = lx->get_text( ).
    ENDTRY.

  ENDMETHOD.

  METHOD get_trouble.
        DATA lt_row TYPE z2ui5_cl_cockpit_wire=>ty_t_read.
        DATA lx TYPE REF TO cx_root.

    CLEAR messages.
    CLEAR inputs.
    TRY.

        lt_row = read_recent( days          = days
                                    check_request = abap_true ).

      CATCH cx_root INTO lx.
        messages-error = lx->get_text( ).
        inputs-error   = messages-error.
        RETURN.
    ENDTRY.
    messages = messages_from( lt_row ).
    inputs   = inputs_from( lt_row ).

  ENDMETHOD.

  METHOD read_recent.

    DATA lv_from TYPE c LENGTH 8.

    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).
    IF check_request = abap_true.
      SELECT app uname user_key timestampl draft_id draft_id_prev http_status req_body res_body
        FROM z2ui5_t_28 UP TO c_max_read ROWS INTO CORRESPONDING FIELDS OF TABLE result
        WHERE utc_day >= lv_from
        ORDER BY timestampl DESCENDING

        .
    ELSE.
      SELECT app uname user_key timestampl draft_id draft_id_prev http_status res_body
        FROM z2ui5_t_28 UP TO c_max_read ROWS INTO CORRESPONDING FIELDS OF TABLE result
        WHERE utc_day >= lv_from
        ORDER BY timestampl DESCENDING

        .
    ENDIF.

  ENDMETHOD.

  METHOD messages_from.

    TYPES:
      BEGIN OF ty_s_user,
        app  TYPE string,
        kind TYPE string,
        type TYPE string,
        text TYPE string,
        user TYPE string,
      END OF ty_s_user.
    TYPES temp2 TYPE HASHED TABLE OF ty_s_user WITH UNIQUE KEY app kind type text user.
DATA lt_users TYPE temp2.
    DATA temp6 TYPE xsdboolean.
    DATA ls_row LIKE LINE OF it_row.
      DATA temp66 TYPE string.
      DATA lv_user LIKE temp66.
      DATA temp67 TYPE z2ui5_cl_cockpit_wire=>ty_t_shown.
      DATA ls_shown LIKE LINE OF temp67.
        FIELD-SYMBOLS <message> TYPE z2ui5_cl_cockpit_wire=>ty_s_message.
          DATA lv_type TYPE string.
          DATA temp68 TYPE z2ui5_cl_cockpit_wire=>ty_s_message.
          DATA temp11 TYPE z2ui5_cl_cockpit_wire=>ty_s_message-example.
          DATA temp12 TYPE z2ui5_cl_cockpit_wire=>ty_s_message-state.
          DATA temp69 TYPE ty_s_user.

    result-records = lines( it_row ).

    temp6 = boolc( result-records >= c_max_read ).
    result-check_capped = temp6.


    LOOP AT it_row INTO ls_row.

      IF ls_row-uname IS NOT INITIAL.
        temp66 = ls_row-uname.
      ELSE.
        temp66 = ls_row-user_key.
      ENDIF.

      lv_user = temp66.

      temp67 = shown_of( ls_row-res_body ).

      LOOP AT temp67 INTO ls_shown.
        IF ls_shown-kind = cs_kind-view.
          CONTINUE.
        ENDIF.

        READ TABLE result-t_message ASSIGNING <message>
             WITH KEY app = ls_row-app kind = ls_shown-kind type = ls_shown-type text = ls_shown-text. "#EC CI_SORTSEQ
        IF sy-subrc <> 0.
          " a variable, not to_lower( ) in the SWITCH - no CASE operand on 7.02

          lv_type = to_lower( ls_shown-type ).
          " rows come newest first - the first one is the last time it was shown
          " a failed roundtrip wrote no draft - its session opens where it started

          CLEAR temp68.
          temp68-app = ls_row-app.
          temp68-kind = ls_shown-kind.
          temp68-type = ls_shown-type.
          temp68-text = ls_shown-text.

          IF ls_row-draft_id IS NOT INITIAL.
            temp11 = ls_row-draft_id.
          ELSE.
            temp11 = ls_row-draft_id_prev.
          ENDIF.
          temp68-example = temp11.
          temp68-last = z2ui5_cl_cockpit_setup=>ts_text( ls_row-timestampl ).

          CASE lv_type.
            WHEN `error`.
              temp12 = `Error`.
            WHEN `warning`.
              temp12 = `Warning`.
            WHEN `success`.
              temp12 = `Success`.
            WHEN OTHERS.
              temp12 = `None`.
          ENDCASE.
          temp68-state = temp12.
          APPEND temp68 TO result-t_message ASSIGNING <message>.
        ENDIF.
        <message>-count = <message>-count + 1.
        IF lv_user IS NOT INITIAL.

          CLEAR temp69.
          temp69-app = ls_row-app.
          temp69-kind = ls_shown-kind.
          temp69-type = ls_shown-type.
          temp69-text = ls_shown-text.
          temp69-user = lv_user.
          INSERT temp69 INTO TABLE lt_users.
          IF sy-subrc = 0.
            <message>-users = <message>-users + 1.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    SORT result-t_message BY count DESCENDING app ASCENDING text ASCENDING.

  ENDMETHOD.

  METHOD count_records.

    DATA lv_from TYPE c LENGTH 8.
    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).
    TRY.
        SELECT COUNT( * ) FROM z2ui5_t_28 INTO result
          WHERE utc_day >= lv_from
          .
      CATCH cx_root.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.

  METHOD json_flatten.

    TYPES:
      BEGIN OF ty_s_open,
        type     TYPE string,
        path     TYPE string,
        children TYPE i,
        name     TYPE string,
      END OF ty_s_open.
    TYPES temp3 TYPE STANDARD TABLE OF ty_s_open WITH DEFAULT KEY.
DATA lt_stack TYPE temp3.
    DATA lo_open TYPE REF TO if_sxml_open_element.
    DATA lo_value TYPE REF TO if_sxml_value_node.
    DATA lv_name TYPE string.
    DATA lv_leaf_path TYPE string.
    FIELD-SYMBOLS <top> TYPE ty_s_open.
    DATA lo_reader TYPE REF TO if_sxml_reader.
      DATA lo_node TYPE REF TO if_sxml_node.
              DATA temp70 TYPE if_sxml_attribute=>attributes.
              DATA lo_attribute LIKE LINE OF temp70.
          DATA temp71 TYPE ty_s_open.
          DATA temp13 TYPE ty_s_open-path.
            DATA temp72 TYPE z2ui5_cl_cockpit_session=>ty_s_value.

    IF json IS INITIAL.
      RETURN.
    ENDIF.

    lo_reader = cl_sxml_string_reader=>create( z2ui5_cl_cockpit_session=>to_utf8( json ) ).

    DO.

      lo_node = lo_reader->read_next_node( ).
      IF lo_node IS NOT BOUND.
        EXIT.
      ENDIF.

      CASE lo_node->type.
        WHEN if_sxml_node=>co_nt_element_open.
          lo_open ?= lo_node.
          CLEAR lv_name.
          UNASSIGN <top>.
          IF lt_stack IS NOT INITIAL.
            READ TABLE lt_stack INDEX lines( lt_stack ) ASSIGNING <top>.
            <top>-children = <top>-children + 1.
            IF <top>-type = `array`.
              lv_name = |{ <top>-children }|.
            ELSE.

              temp70 = lo_open->get_attributes( ).

              LOOP AT temp70 INTO lo_attribute.
                lv_name = lo_attribute->get_value( ).
                EXIT.
              ENDLOOP.
            ENDIF.
          ENDIF.

          CLEAR temp71.
          temp71-type = lo_open->qname-name.
          temp71-name = lv_name.

          IF <top> IS NOT ASSIGNED.
            temp13 = ``.
          ELSEIF <top>-path IS INITIAL.
            temp13 = lv_name.
          ELSE.
            temp13 = |{ <top>-path }/{ lv_name }|.
          ENDIF.
          temp71-path = temp13.
          APPEND temp71 TO lt_stack.

        WHEN if_sxml_node=>co_nt_value.
          lo_value ?= lo_node.
          IF lt_stack IS NOT INITIAL.
            READ TABLE lt_stack INDEX lines( lt_stack ) ASSIGNING <top>.
            lv_leaf_path = <top>-path.

            CLEAR temp72.
            temp72-path = lv_leaf_path.
            temp72-value = lo_value->get_value( ).
            APPEND temp72 TO result.
          ENDIF.

        WHEN if_sxml_node=>co_nt_element_close.
          IF lt_stack IS NOT INITIAL.
            DELETE lt_stack INDEX lines( lt_stack ).
          ENDIF.
      ENDCASE.
    ENDDO.

  ENDMETHOD.

  METHOD shown_of.

    TYPES:
      BEGIN OF ty_s_action,
        nr     TYPE string,
        values TYPE z2ui5_cl_cockpit_session=>ty_t_value,
      END OF ty_s_action.
    TYPES temp4 TYPE STANDARD TABLE OF ty_s_action WITH DEFAULT KEY.
DATA lt_action TYPE temp4.
    DATA lt_values TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA lv_rest TYPE string.
    DATA lv_nr TYPE string.
    DATA ls_value LIKE LINE OF lt_values.
      DATA lv_slash TYPE i.
      DATA lv_after TYPE string.
      DATA lv_slash2 TYPE i.
      FIELD-SYMBOLS <action> TYPE ty_s_action.
        DATA temp73 TYPE ty_s_action.
      DATA temp74 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
    DATA ls_action LIKE LINE OF lt_action.
      DATA temp75 TYPE z2ui5_cl_cockpit_session=>ty_s_value-value.
      DATA temp76 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
      DATA lv_1 LIKE temp75.
      DATA temp77 TYPE z2ui5_cl_cockpit_session=>ty_s_value-value.
      DATA temp78 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
      DATA lv_2 LIKE temp77.
      DATA temp79 TYPE z2ui5_cl_cockpit_session=>ty_s_value-value.
      DATA temp80 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
      DATA lv_3 LIKE temp79.
      DATA temp81 TYPE z2ui5_cl_cockpit_session=>ty_s_value-value.
      DATA temp82 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
      DATA lv_4 LIKE temp81.
          DATA temp83 TYPE z2ui5_cl_cockpit_wire=>ty_s_shown.
          DATA temp84 TYPE z2ui5_cl_cockpit_wire=>ty_s_shown.
              DATA temp85 TYPE z2ui5_cl_cockpit_wire=>ty_s_shown.
              DATA temp86 TYPE z2ui5_cl_cockpit_wire=>ty_s_shown.

    TRY.
        lt_values = json_flatten( response ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    " one action is one array - S_FRONT/S_ACTION/T_CUSTOM/<n>/<position>

    LOOP AT lt_values INTO ls_value.
      IF ls_value-path NP `S_FRONT/S_ACTION/T_*`.
        CONTINUE.
      ENDIF.
      lv_rest = substring_after( val = ls_value-path
                                 sub = `S_FRONT/S_ACTION/` ).
      " the queue and the number of the action: T_CUSTOM/3

      lv_slash = find( val = lv_rest
                             sub = `/` ).
      IF lv_slash < 0.
        CONTINUE.
      ENDIF.

      lv_after = substring( val = lv_rest
                                  off = lv_slash + 1 ).

      lv_slash2 = find( val = lv_after
                              sub = `/` ).
      IF lv_slash2 < 0.
        CONTINUE.
      ENDIF.
      lv_nr = substring( val = lv_rest
                         len = lv_slash + 1 + lv_slash2 ).

      READ TABLE lt_action ASSIGNING <action> WITH KEY nr = lv_nr. "#EC CI_SORTSEQ
      IF sy-subrc <> 0.

        CLEAR temp73.
        temp73-nr = lv_nr.
        APPEND temp73 TO lt_action ASSIGNING <action>.
      ENDIF.

      CLEAR temp74.
      temp74-path = substring( val = lv_after off = lv_slash2 + 1 ).
      temp74-value = ls_value-value.
      APPEND temp74 TO <action>-values.
    ENDLOOP.


    LOOP AT lt_action INTO ls_action.

      CLEAR temp75.

      READ TABLE ls_action-values INTO temp76 WITH KEY path = `1`.
      IF sy-subrc = 0.
        temp75 = temp76-value.
      ENDIF.

      lv_1 = temp75.

      CLEAR temp77.

      READ TABLE ls_action-values INTO temp78 WITH KEY path = `2`.
      IF sy-subrc = 0.
        temp77 = temp78-value.
      ENDIF.

      lv_2 = temp77.

      CLEAR temp79.

      READ TABLE ls_action-values INTO temp80 WITH KEY path = `3`.
      IF sy-subrc = 0.
        temp79 = temp80-value.
      ENDIF.

      lv_3 = temp79.

      CLEAR temp81.

      READ TABLE ls_action-values INTO temp82 WITH KEY path = `4`.
      IF sy-subrc = 0.
        temp81 = temp82-value.
      ENDIF.

      lv_4 = temp81.
      CASE lv_1.
        WHEN cs_kind-box.

          CLEAR temp83.
          temp83-kind = cs_kind-box.
          temp83-type = lv_2.
          temp83-text = lv_3.
          APPEND temp83 TO result.
        WHEN cs_kind-toast.

          CLEAR temp84.
          temp84-kind = cs_kind-toast.
          temp84-text = lv_3.
          APPEND temp84 TO result.
        WHEN `VIEW_SLOTS`.
          IF lv_2 <> `display`.
            CONTINUE.
          ENDIF.
          CASE lv_3.
            WHEN cs_kind-popup OR cs_kind-popover.

              CLEAR temp85.
              temp85-kind = lv_3.
              temp85-text = xml_attribute( xml = lv_4 name = `title` ).
              APPEND temp85 TO result.
            WHEN `MAIN`.

              CLEAR temp86.
              temp86-kind = cs_kind-view.
              temp86-text = xml_attribute( xml = lv_4 name = `title` ).
              APPEND temp86 TO result.
          ENDCASE.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.

  METHOD input_of.

    DATA lt_values TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_value LIKE LINE OF lt_values.
      DATA lv_path LIKE ls_value-path.
        DATA temp87 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
        DATA temp88 TYPE z2ui5_cl_cockpit_session=>ty_s_value.

    TRY.
        lt_values = json_flatten( request ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    LOOP AT lt_values INTO ls_value.

      lv_path = ls_value-path.
      IF lv_path CP `value/*`.
        lv_path = substring( val = lv_path
                             off = 6 ).
      ENDIF.
      IF lv_path CP `MODEL/*`.

        CLEAR temp87.
        temp87-path = substring( val = lv_path off = 6 ).
        temp87-value = ls_value-value.
        APPEND temp87 TO result.
      ELSEIF lv_path CP `S_FRONT/T_EVENT_ARG/*`.

        CLEAR temp88.
        temp88-path = |event argument { substring( val = lv_path off = 20 ) }|.
        temp88-value = ls_value-value.
        APPEND temp88 TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD views_of.

    DATA lt_values TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_value LIKE LINE OF lt_values.
      DATA lv_base TYPE string.
      DATA lv_slot_path TYPE string.
      DATA lv_xml_path TYPE string.
      DATA temp89 TYPE z2ui5_cl_cockpit_session=>ty_s_value-value.
      DATA temp90 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
      DATA lv_slot LIKE temp89.
      DATA temp91 TYPE z2ui5_cl_cockpit_session=>ty_s_value-value.
      DATA temp92 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
      DATA lv_xml LIKE temp91.
        DATA temp93 TYPE z2ui5_if_client=>ty_s_name_value.

    TRY.
        lt_values = json_flatten( response ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
    " a display action: ["VIEW_SLOTS","display","<slot>","<xml>",{...}]

    LOOP AT lt_values INTO ls_value WHERE value = `display`. "#EC CI_SORTSEQ
      IF ls_value-path NP `S_FRONT/S_ACTION/T_SYSTEM/*/2`.
        CONTINUE.
      ENDIF.

      lv_base = substring( val = ls_value-path
                                 len = strlen( ls_value-path ) - 1 ).
      " the keys in variables - a template is no key operand on 7.02

      lv_slot_path = |{ lv_base }3|.

      lv_xml_path = |{ lv_base }4|.

      CLEAR temp89.

      READ TABLE lt_values INTO temp90 WITH KEY path = lv_slot_path.
      IF sy-subrc = 0.
        temp89 = temp90-value.
      ENDIF.

      lv_slot = temp89.

      CLEAR temp91.

      READ TABLE lt_values INTO temp92 WITH KEY path = lv_xml_path.
      IF sy-subrc = 0.
        temp91 = temp92-value.
      ENDIF.

      lv_xml = temp91.
      IF lv_xml IS NOT INITIAL.

        CLEAR temp93.
        temp93-n = lv_slot.
        temp93-v = lv_xml.
        APPEND temp93 TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD control_of.

    DATA lv_open TYPE i.
    DATA lv_hit TYPE i.
    DATA lv_close TYPE i.
    DATA lv_element TYPE string.
    DATA lv_name TYPE string.
    DATA lv_label TYPE string.
    DATA temp94 TYPE string.

    IF event IS INITIAL OR xml IS INITIAL.
      RETURN.
    ENDIF.
    " an event wire is .eB(['NAME'... in an attribute of the control

    lv_hit = find( val = xml
                         sub = |['{ event }'| ).
    IF lv_hit < 0.
      RETURN.
    ENDIF.
    lv_open = find( val = substring( val = xml
                                     len = lv_hit )
                    sub = `<`
                    occ = -1 ).
    IF lv_open < 0.
      RETURN.
    ENDIF.

    lv_close = find( val = xml
                           sub = `>`
                           off = lv_hit ).
    IF lv_close < 0.
      RETURN.
    ENDIF.

    lv_element = substring( val = xml
                                  off = lv_open
                                  len = lv_close - lv_open + 1 ).

    lv_name = substring( val = lv_element
                               off = 1 ).
    IF lv_name CS ` `.
      lv_name = substring_before( val = lv_name
                                  sub = ` ` ).
    ENDIF.
    IF lv_name CS `:`.
      lv_name = substring_after( val = lv_name
                                 sub = `:` ).
    ENDIF.


    lv_label = xml_attribute( xml  = lv_element
                                    name = `text` ).
    IF lv_label IS INITIAL.
      lv_label = xml_attribute( xml  = lv_element
                                name = `tooltip` ).
    ENDIF.
    IF lv_label IS INITIAL.
      lv_label = xml_attribute( xml  = lv_element
                                name = `icon` ).
      REPLACE `sap-icon://` IN lv_label WITH ``.
    ENDIF.
    IF lv_label IS INITIAL.
      lv_label = xml_attribute( xml  = lv_element
                                name = `id` ).
    ENDIF.

    IF lv_label IS NOT INITIAL.
      temp94 = | "{ lv_label }"|.
    ELSE.
      CLEAR temp94.
    ENDIF.
    result = |{ lv_name }{ temp94 }|.

  ENDMETHOD.

  METHOD field_control_of.

    DATA lv_open TYPE i.
    DATA lv_hit TYPE i.
    DATA lv_name TYPE string.
    DATA lv_before TYPE string.
    DATA lv_label_at TYPE i.
    DATA lv_text TYPE string.
    DATA temp95 TYPE string.

    IF path IS INITIAL OR xml IS INITIAL.
      RETURN.
    ENDIF.
    " {/PATH} or path:'/PATH'

    lv_hit = find( val = xml
                         sub = |\{/{ path }\}| ).
    IF lv_hit < 0.
      lv_hit = find( val = xml
                     sub = |'/{ path }'| ).
    ENDIF.
    IF lv_hit < 0.
      RETURN.
    ENDIF.
    lv_open = find( val = substring( val = xml
                                     len = lv_hit )
                    sub = `<`
                    occ = -1 ).
    IF lv_open < 0.
      RETURN.
    ENDIF.

    lv_name = substring( val = xml
                               off = lv_open + 1 ).
    lv_name = substring_before( val = lv_name
                                sub = ` ` ).
    IF lv_name CS `:`.
      lv_name = substring_after( val = lv_name
                                 sub = `:` ).
    ENDIF.

    " a form puts the Label right before its field

    lv_before = substring( val = xml
                                 len = lv_open ).

    lv_label_at = find( val = lv_before
                              sub = `<Label `
                              occ = -1 ).

    lv_text = ``.
    IF lv_label_at >= 0 AND lv_open - lv_label_at < 400.
      lv_text = xml_attribute( xml  = substring( val = lv_before
                                                 off = lv_label_at )
                               name = `text` ).
    ENDIF.

    IF lv_text IS NOT INITIAL.
      temp95 = | "{ lv_text }"|.
    ELSE.
      CLEAR temp95.
    ENDIF.
    result = |{ lv_name }{ temp95 }|.

  ENDMETHOD.

  METHOD screen_of.

    DATA lv_pos TYPE i.
    DATA lv_out TYPE string.
    " the model by path, every value escaped once - and the rows that have one
    DATA lt_bound TYPE ty_t_bound.
    TYPES temp5 TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_row TYPE temp5.

    " the root element: <mvc:View xmlns="sap.m" xmlns:mvc="..." ...>
    DATA lv_start TYPE i.
    DATA lv_root_end TYPE i.
    DATA lv_last TYPE i.
    DATA lv_root TYPE string.
      DATA lv_ns TYPE i.
      DATA lv_eq TYPE i.
      DATA lv_end TYPE i.
    DATA lv_content TYPE string.
    DATA ls_model LIKE LINE OF it_model.
      DATA temp96 TYPE z2ui5_cl_cockpit_wire=>ty_s_bound.
      DATA lv_slash TYPE i.
        DATA temp1 TYPE string.
      DATA lv_wire TYPE i.
      DATA lv_quote TYPE i.
      DATA lv_items TYPE i.
      DATA lv_path_end TYPE i.
      DATA lv_list TYPE string.
      DATA lv_tmpl_open TYPE i.
      DATA lv_tmpl_close TYPE i.
      DATA lv_template TYPE string.
        DATA lv_row LIKE sy-index.
        DATA lv_prefix TYPE string.
        DATA lv_row_path TYPE string.
        DATA temp97 LIKE sy-subrc.
        DATA temp14 LIKE sy-subrc.
        DATA temp15 LIKE sy-subrc.
    lv_start = find( val = xml
                           sub = `<` ).
    WHILE lv_start >= 0 AND substring( val = xml
                                       off = lv_start + 1
                                       len = 1 ) = `?`.
      lv_start = find( val = xml
                       sub = `<`
                       off = lv_start + 1 ).
    ENDWHILE.
    IF lv_start < 0.
      result-error = `The recorded view is not XML.`.
      RETURN.
    ENDIF.

    lv_root_end = find( val = xml
                              sub = `>`
                              off = lv_start ).

    lv_last = find( val = xml
                          sub = `</`
                          occ = -1 ).
    IF lv_root_end < 0 OR lv_last <= lv_root_end.
      result-error = `The recorded view is empty.`.
      RETURN.
    ENDIF.

    lv_root = substring( val = xml
                               off = lv_start
                               len = lv_root_end - lv_start ).

    " its namespace declarations move to the element the copy is shown in
    lv_pos = 0.
    DO.

      lv_ns = find( val = lv_root
                          sub = ` xmlns`
                          off = lv_pos ).
      IF lv_ns < 0.
        EXIT.
      ENDIF.

      lv_eq = find( val = lv_root
                          sub = `="`
                          off = lv_ns ).

      lv_end = find( val = lv_root
                           sub = `"`
                           off = lv_eq + 2 ).
      IF lv_eq < 0 OR lv_end < 0.
        EXIT.
      ENDIF.
      result-xmlns = result-xmlns && substring( val = lv_root
                                                off = lv_ns
                                                len = lv_end - lv_ns + 1 ).
      lv_pos = lv_end + 1.
    ENDDO.
    result-title = xml_attribute( xml  = xml
                                  name = `title` ).


    lv_content = substring( val = xml
                                  off = lv_root_end + 1
                                  len = lv_last - lv_root_end - 1 ).


    LOOP AT it_model INTO ls_model.

      CLEAR temp96.
      temp96-path = ls_model-path.
      temp96-value = xml_escape( ls_model-value ).
      INSERT temp96 INTO TABLE lt_bound.
      " every path a value lies below: LIST/1/COL is below LIST/1 and LIST

      lv_slash = find( val = ls_model-path
                             sub = `/` ).
      WHILE lv_slash > 0.

        temp1 = substring( val = ls_model-path len = lv_slash ).
        INSERT temp1 INTO TABLE lt_row.
        lv_slash = find( val = ls_model-path
                         sub = `/`
                         off = lv_slash + 1 ).
      ENDWHILE.
    ENDLOOP.

    IF event IS NOT INITIAL.
      result-marked = mark_pressed( EXPORTING event = event
                                    CHANGING  xml   = lv_content ).
    ENDIF.

    " event handlers emptied: .eB( .eBP( .eF( are the framework's wires
    lv_pos = 0.
    DO.

      lv_wire = find( val = lv_content
                            sub = `=".e`
                            off = lv_pos ).
      IF lv_wire < 0.
        EXIT.
      ENDIF.

      lv_quote = find( val = lv_content
                             sub = `"`
                             off = lv_wire + 2 ).
      IF lv_quote < 0.
        EXIT.
      ENDIF.
      lv_content = substring( val = lv_content
                              len = lv_wire + 2 ) && substring( val = lv_content
                                                                off = lv_quote ).
      lv_pos = lv_wire + 3.
    ENDDO.

    " a table: items="{/PATH}" and its <items> template, repeated per row
    lv_pos = 0.
    DO.

      lv_items = find( val = lv_content
                             sub = ` items="{/`
                             off = lv_pos ).
      IF lv_items < 0.
        EXIT.
      ENDIF.

      lv_path_end = find( val = lv_content
                                sub = `}"`
                                off = lv_items ).
      IF lv_path_end < 0.
        EXIT.
      ENDIF.

      lv_list = substring( val = lv_content
                                 off = lv_items + 10
                                 len = lv_path_end - lv_items - 10 ).

      lv_tmpl_open = find( val = lv_content
                                 sub = `<items>`
                                 off = lv_path_end ).

      lv_tmpl_close = find( val = lv_content
                                  sub = `</items>`
                                  off = lv_path_end ).
      IF lv_tmpl_open < 0 OR lv_tmpl_close < lv_tmpl_open.
        lv_pos = lv_path_end.
        CONTINUE.
      ENDIF.

      lv_template = substring( val = lv_content
                                     off = lv_tmpl_open + 7
                                     len = lv_tmpl_close - lv_tmpl_open - 7 ).
      CLEAR lv_out.
      DO 50 TIMES.

        lv_row = sy-index.
        " keys in variables - no template there on 7.02

        lv_prefix = |{ lv_list }/{ lv_row }/|.

        lv_row_path = |{ lv_list }/{ lv_row }|.

        READ TABLE lt_bound WITH KEY path = lv_row_path TRANSPORTING NO FIELDS.
        temp97 = sy-subrc.


        temp15 = sy-subrc.
        READ TABLE lt_row WITH KEY table_line = lv_row_path TRANSPORTING NO FIELDS.
        temp14 = sy-subrc.
        sy-subrc = temp15.
        IF NOT temp97 = 0 AND NOT temp14 = 0.
          EXIT.
        ENDIF.
        " the relative bindings of the template, {COL}, from this row
        lv_out = lv_out && bindings_replaced( text     = lv_template
                                              open     = `{`
                                              prefix   = lv_prefix
                                              it_bound = lt_bound ).
      ENDDO.
      lv_content = substring( val = lv_content
                              len = lv_items ) &&
                   substring( val = lv_content
                              off = lv_path_end + 2
                              len = lv_tmpl_open + 7 - lv_path_end - 2 ) &&
                   lv_out &&
                   substring( val = lv_content
                              off = lv_tmpl_close ).
      lv_pos = lv_items + 1.
    ENDDO.

    " the absolute bindings {/PATH} by their value
    lv_content = bindings_replaced( text     = lv_content
                                    open     = `{/`
                                    prefix   = ``
                                    it_bound = lt_bound ).

    result-content = content_defused( xml     = xml
                                      content = lv_content ).

  ENDMETHOD.

  METHOD content_defused.

    DATA lt_html TYPE string_table.
    DATA lt_keep TYPE string_table.
    DATA lt_lib TYPE string_table.
    DATA lt_strict TYPE string_table.
    DATA lt_allow TYPE string_table.
    DATA lt_control TYPE string_table.
    TYPES temp6 TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_ok TYPE temp6.
    TYPES temp7 TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_bad TYPE temp7.
    DATA lv_prefix TYPE string.
    DATA lv_pos TYPE i.
    DATA lv_at TYPE i.
    DATA lv_end TYPE i.
    DATA lv_ws TYPE string.
    DATA temp98 TYPE string_table.
        DATA lv_char TYPE string.
      DATA lv_name TYPE string.
      DATA lv_delim TYPE string.
      DATA lv_uri TYPE string.
      DATA temp100 LIKE sy-subrc.
      DATA temp101 LIKE sy-subrc.
    DATA temp102 TYPE string_table.
      DATA lv_control LIKE LINE OF lt_control.
        DATA temp104 LIKE LINE OF lt_allow.
      DATA lv_tag TYPE string.
        DATA lv_after TYPE i.
        DATA lv_next TYPE string.
        DATA lv_attrs TYPE string.
          DATA lv_san TYPE i.
          DATA lv_quote TYPE string.
          DATA lv_close TYPE i.

    result = content.
    lv_ws = | \t\n\r|.

    " an allowlist: the UI5 libraries whose controls show what their
    " properties say and run nothing of their own - sap.ui.core for its
    " HTML control sanitized below. Everything else is left out: XHTML, SVG,
    " the framework's helper controls (z2ui5.cc), the addons' custom
    " controls (z2ui5_cci.cc, ...), any third-party library

    CLEAR temp98.
    INSERT `sap.m` INTO TABLE temp98.
    INSERT `sap.f` INTO TABLE temp98.
    INSERT `sap.ui.core` INTO TABLE temp98.
    INSERT `sap.ui.core.mvc` INTO TABLE temp98.
    INSERT `sap.ui.layout` INTO TABLE temp98.
    INSERT `sap.ui.layout.form` INTO TABLE temp98.
    INSERT `sap.ui.table` INTO TABLE temp98.
    INSERT `sap.ui.unified` INTO TABLE temp98.
    INSERT `sap.uxap` INTO TABLE temp98.
    INSERT `sap.tnt` INTO TABLE temp98.
    INSERT `sap.suite.ui.microchart` INTO TABLE temp98.
    lt_lib = temp98.

    " the prefixes, from every declaration - xmlns:p="uri" or xmlns='uri';
    " a prefix (or the default namespace) declared once with another uri
    " is left out wherever it is used
    DO.
      lv_at = find( val = xml
                    sub = `xmlns`
                    off = lv_pos ).
      IF lv_at < 0.
        EXIT.
      ENDIF.
      lv_pos = lv_at + 5.
      IF lv_at = 0.
        CONTINUE.
      ENDIF.
      IF find( val = lv_ws
               sub = substring( val = xml
                                off = lv_at - 1
                                len = 1 ) ) < 0.
        CONTINUE.
      ENDIF.
      " the name up to a blank or the = (find( ) with off and regex is not
      " transpiled, the unit tests could not run it)
      lv_end = lv_pos.
      WHILE lv_end < strlen( xml ).

        lv_char = substring( val = xml
                                   off = lv_end
                                   len = 1 ).
        IF lv_char = `=` OR find( val = lv_ws
                                  sub = lv_char ) >= 0.
          EXIT.
        ENDIF.
        lv_end = lv_end + 1.
      ENDWHILE.
      IF lv_end >= strlen( xml ).
        EXIT.
      ENDIF.

      lv_name = substring( val = xml
                                 off = lv_pos
                                 len = lv_end - lv_pos ).
      " the = and the quote, blanks allowed around the =
      lv_pos = lv_end.
      WHILE lv_pos < strlen( xml ) AND find( val = lv_ws
                                             sub = substring( val = xml
                                                              off = lv_pos
                                                              len = 1 ) ) >= 0.
        lv_pos = lv_pos + 1.
      ENDWHILE.
      IF lv_pos >= strlen( xml ).
        EXIT.
      ENDIF.
      IF substring( val = xml
                    off = lv_pos
                    len = 1 ) <> `=`.
        CONTINUE.
      ENDIF.
      lv_pos = lv_pos + 1.
      WHILE lv_pos < strlen( xml ) AND find( val = lv_ws
                                             sub = substring( val = xml
                                                              off = lv_pos
                                                              len = 1 ) ) >= 0.
        lv_pos = lv_pos + 1.
      ENDWHILE.
      IF lv_pos >= strlen( xml ).
        EXIT.
      ENDIF.

      lv_delim = substring( val = xml
                                  off = lv_pos
                                  len = 1 ).
      IF lv_delim <> `"` AND lv_delim <> `'`.
        CONTINUE.
      ENDIF.
      lv_end = find( val = xml
                     sub = lv_delim
                     off = lv_pos + 1 ).
      IF lv_end < 0.
        EXIT.
      ENDIF.

      lv_uri = substring( val = xml
                                off = lv_pos + 1
                                len = lv_end - lv_pos - 1 ).
      lv_pos = lv_end + 1.
      CLEAR lv_prefix.
      IF lv_name IS NOT INITIAL.
        IF substring( val = lv_name
                      len = 1 ) <> `:`.
          CONTINUE.
        ENDIF.
        lv_prefix = |{ substring( val = lv_name
                                  off = 1 ) }:|.
      ENDIF.

      READ TABLE lt_lib WITH KEY table_line = lv_uri TRANSPORTING NO FIELDS.
      temp100 = sy-subrc.
      IF temp100 = 0.               "#EC CI_SORTSEQ
        INSERT lv_prefix INTO TABLE lt_ok.
        IF lv_uri = `sap.ui.core`.
          INSERT lv_prefix INTO TABLE lt_html.
        ENDIF.
        IF lv_uri = `sap.ui.core` OR lv_uri = `sap.ui.core.mvc`.
          INSERT lv_prefix INTO TABLE lt_strict.
        ENDIF.
      ELSE.
        INSERT lv_prefix INTO TABLE lt_bad.
      ENDIF.
    ENDDO.

    LOOP AT lt_ok INTO lv_prefix.

      READ TABLE lt_bad WITH KEY table_line = lv_prefix TRANSPORTING NO FIELDS.
      temp101 = sy-subrc.
      IF NOT temp101 = 0.
        INSERT lv_prefix INTO TABLE lt_keep.
      ENDIF.
    ENDLOOP.

    " sap.ui.core and sap.ui.core.mvc also hold what loads and runs code - a
    " Fragment, a ComponentContainer, an ExtensionPoint, a nested view by
    " viewName: of them only the controls that show what they are told stay

    CLEAR temp102.
    INSERT `Icon` INTO TABLE temp102.
    INSERT `Item` INTO TABLE temp102.
    INSERT `ListItem` INTO TABLE temp102.
    INSERT `SeparatorItem` INTO TABLE temp102.
    INSERT `HTML` INTO TABLE temp102.
    INSERT `CustomData` INTO TABLE temp102.
    INSERT `Title` INTO TABLE temp102.
    INSERT `InvisibleText` INTO TABLE temp102.
    INSERT `VariantLayoutData` INTO TABLE temp102.
    lt_control = temp102.
    LOOP AT lt_html INTO lv_prefix.

      LOOP AT lt_control INTO lv_control.

        temp104 = |{ lv_prefix }{ lv_control }|.
        APPEND temp104 TO lt_allow.
      ENDLOOP.
    ENDLOOP.
    result = elements_dropped( xml       = result
                               it_keep   = lt_keep
                               it_strict = lt_strict
                               it_allow  = lt_allow ).

    " core:require loads modules - wherever it stands
    LOOP AT lt_html INTO lv_prefix WHERE table_line IS NOT INITIAL.
      result = attribute_dropped( xml  = result
                                  name = |{ lv_prefix }require| ).
    ENDLOOP.

    " every HTML control: its own sanitizeContent goes, true comes in
    LOOP AT lt_html INTO lv_prefix.

      lv_tag = |<{ lv_prefix }HTML|.
      lv_pos = 0.
      DO.
        lv_at = find( val = result
                      sub = lv_tag
                      off = lv_pos ).
        IF lv_at < 0.
          EXIT.
        ENDIF.

        lv_after = lv_at + strlen( lv_tag ).
        lv_pos = lv_after.
        lv_end = find( val = result
                       sub = `>`
                       off = lv_after ).
        IF lv_end < 0.
          EXIT.
        ENDIF.
        " <core:HTMLx is another control

        lv_next = substring( val = result
                                   off = lv_after
                                   len = 1 ).
        IF lv_next <> ` ` AND lv_next <> `/` AND lv_next <> `>`
            AND lv_next <> cl_abap_char_utilities=>newline AND lv_next <> cl_abap_char_utilities=>horizontal_tab.
          CONTINUE.
        ENDIF.

        lv_attrs = substring( val = result
                                    off = lv_after
                                    len = lv_end - lv_after ).
        DO.

          lv_san = find( val = lv_attrs
                               sub = `sanitizeContent=` ).
          IF lv_san < 0 OR lv_san + 17 > strlen( lv_attrs ).
            EXIT.
          ENDIF.

          lv_quote = substring( val = lv_attrs
                                      off = lv_san + 16
                                      len = 1 ).

          lv_close = find( val = lv_attrs
                                 sub = lv_quote
                                 off = lv_san + 17 ).
          IF lv_close < 0.
            lv_close = strlen( lv_attrs ) - 1.
          ENDIF.
          " with the blank in front of it
          IF lv_san > 0 AND substring( val = lv_attrs
                                       off = lv_san - 1
                                       len = 1 ) = ` `.
            lv_san = lv_san - 1.
          ENDIF.
          lv_attrs = substring( val = lv_attrs
                                len = lv_san ) && substring( val = lv_attrs
                                                             off = lv_close + 1 ).
        ENDDO.
        result = substring( val = result
                            len = lv_after ) && ` sanitizeContent="true"` && lv_attrs && substring( val = result
                                                                                                    off = lv_end ).
        lv_pos = lv_after + 1.
      ENDDO.
    ENDLOOP.

  ENDMETHOD.

  METHOD bindings_replaced.

    DATA lv_pos TYPE i.
    DATA lv_from TYPE i.

    DATA lv_len TYPE i.
      DATA lv_at TYPE i.
      DATA lv_name_at TYPE i.
      DATA lv_close TYPE i.
      DATA lv_path TYPE string.
      DATA ls_bound TYPE z2ui5_cl_cockpit_wire=>ty_s_bound.
    lv_len = strlen( text ).
    DO.

      lv_at = find( val = text
                          sub = open
                          off = lv_pos ).
      IF lv_at < 0.
        EXIT.
      ENDIF.

      lv_name_at = lv_at + strlen( open ).

      lv_close = find( val = text
                             sub = `}`
                             off = lv_name_at ).
      IF lv_close < 0.
        EXIT.
      ENDIF.
      " the value, by its path - substrings and keys in variables, none in
      " an expression: the 7.02 downport

      lv_path = prefix && substring( val = text
                                           off = lv_name_at
                                           len = lv_close - lv_name_at ).

      READ TABLE it_bound INTO ls_bound WITH TABLE KEY path = lv_path.
      IF sy-subrc = 0.
        result = result && substring( val = text
                                      off = lv_from
                                      len = lv_at - lv_from ) && ls_bound-value.
        lv_from = lv_close + 1.
        lv_pos = lv_close + 1.
      ELSE.
        lv_pos = lv_at + 1.
      ENDIF.
      IF lv_pos >= lv_len.
        EXIT.
      ENDIF.
    ENDDO.
    result = result && substring( val = text
                                  off = lv_from ).

  ENDMETHOD.

  METHOD attribute_dropped.

    DATA lv_pos TYPE i.
    DATA lv_ws TYPE string.
      DATA lv_at TYPE i.
      DATA lv_end TYPE i.
      DATA lv_delim TYPE string.
      DATA lv_close TYPE i.

    result = xml.
    lv_ws = | \t\n\r|.
    DO.

      lv_at = find( val = result
                          sub = name
                          off = lv_pos ).
      IF lv_at < 0.
        EXIT.
      ENDIF.
      lv_pos = lv_at + 1.
      IF lv_at = 0.
        CONTINUE.
      ENDIF.
      IF find( val = lv_ws
               sub = substring( val = result
                                off = lv_at - 1
                                len = 1 ) ) < 0.
        CONTINUE.
      ENDIF.
      " the =, blanks allowed around it, and the quoted value

      lv_end = lv_at + strlen( name ).
      WHILE lv_end < strlen( result ) AND find( val = lv_ws
                                                sub = substring( val = result
                                                                 off = lv_end
                                                                 len = 1 ) ) >= 0.
        lv_end = lv_end + 1.
      ENDWHILE.
      IF lv_end >= strlen( result ) OR substring( val = result
                                                  off = lv_end
                                                  len = 1 ) <> `=`.
        CONTINUE.
      ENDIF.
      lv_end = lv_end + 1.
      WHILE lv_end < strlen( result ) AND find( val = lv_ws
                                                sub = substring( val = result
                                                                 off = lv_end
                                                                 len = 1 ) ) >= 0.
        lv_end = lv_end + 1.
      ENDWHILE.
      IF lv_end >= strlen( result ).
        EXIT.
      ENDIF.

      lv_delim = substring( val = result
                                  off = lv_end
                                  len = 1 ).
      IF lv_delim <> `"` AND lv_delim <> `'`.
        CONTINUE.
      ENDIF.

      lv_close = find( val = result
                             sub = lv_delim
                             off = lv_end + 1 ).
      IF lv_close < 0.
        EXIT.
      ENDIF.
      result = substring( val = result
                          len = lv_at - 1 ) && substring( val = result
                                                          off = lv_close + 1 ).
      lv_pos = lv_at - 1.
    ENDDO.

  ENDMETHOD.

  METHOD elements_dropped.

    DATA lv_pos TYPE i.
    DATA lv_from TYPE i.
    DATA lv_depth TYPE i.
    DATA lv_end TYPE i.
    DATA lv_prefix TYPE string.
    DATA lv_ws TYPE string.
    DATA lv_next_dq TYPE i VALUE -2.
    DATA lv_next_sq TYPE i VALUE -2.
    DATA lv_next_gt TYPE i VALUE -2.

    DATA lv_len TYPE i.
      DATA lv_lt TYPE i.
      DATA lv_next TYPE string.
      DATA lv_gt TYPE i.
      DATA lv_scan TYPE i.
        DATA lv_hit LIKE lv_next_gt.
        DATA lv_char TYPE string.
      DATA lv_closing TYPE abap_bool.
      DATA temp7 TYPE xsdboolean.
      DATA lv_empty TYPE abap_bool.
      DATA temp8 TYPE xsdboolean.
      DATA lv_name TYPE string.
      DATA lv_colon TYPE i.
      DATA temp105 LIKE sy-subrc.
        DATA temp106 LIKE sy-subrc.
        DATA lv_local TYPE string.
          DATA temp107 LIKE sy-subrc.
    lv_len = strlen( xml ).
    lv_ws = | \t\n\r|.

    DO.

      lv_lt = find( val = xml
                          sub = `<`
                          off = lv_pos ).
      IF lv_lt < 0 OR lv_lt + 1 >= lv_len.
        EXIT.
      ENDIF.

      lv_next = substring( val = xml
                                 off = lv_lt + 1
                                 len = 1 ).

      " a comment, CDATA or a processing instruction is no element
      IF lv_next = `!` OR lv_next = `?`.
        lv_end = find( val = xml
                       sub = `>`
                       off = lv_lt ).
        IF find( val = xml
                 sub = `<!--`
                 off = lv_lt ) = lv_lt.
          lv_end = find( val = xml
                         sub = `-->`
                         off = lv_lt + 4 ).
        ENDIF.
        IF find( val = xml
                 sub = `<![CDATA[`
                 off = lv_lt ) = lv_lt.
          lv_end = find( val = xml
                         sub = `]]>`
                         off = lv_lt + 9 ).
        ENDIF.
        IF lv_end < 0.
          lv_pos = lv_len.
          EXIT.
        ENDIF.
        lv_pos = find( val = xml
                       sub = `>`
                       off = lv_end ) + 1.
        CONTINUE.
      ENDIF.

      " the end of the tag - a > inside a quoted value does not end it; the
      " next ", ' and > are kept until passed, the scan stays linear

      lv_gt = -1.

      lv_scan = lv_lt + 1.
      DO.
        IF lv_next_dq <> -1 AND lv_next_dq < lv_scan.
          lv_next_dq = find( val = xml
                             sub = `"`
                             off = lv_scan ).
        ENDIF.
        IF lv_next_sq <> -1 AND lv_next_sq < lv_scan.
          lv_next_sq = find( val = xml
                             sub = `'`
                             off = lv_scan ).
        ENDIF.
        IF lv_next_gt <> -1 AND lv_next_gt < lv_scan.
          lv_next_gt = find( val = xml
                             sub = `>`
                             off = lv_scan ).
        ENDIF.

        lv_hit = lv_next_gt.
        IF lv_next_dq >= 0 AND ( lv_hit < 0 OR lv_next_dq < lv_hit ).
          lv_hit = lv_next_dq.
        ENDIF.
        IF lv_next_sq >= 0 AND ( lv_hit < 0 OR lv_next_sq < lv_hit ).
          lv_hit = lv_next_sq.
        ENDIF.
        IF lv_hit < 0.
          EXIT.
        ENDIF.

        lv_char = substring( val = xml
                                   off = lv_hit
                                   len = 1 ).
        IF lv_char = `>`.
          lv_gt = lv_hit.
          EXIT.
        ENDIF.
        lv_end = find( val = xml
                       sub = lv_char
                       off = lv_hit + 1 ).
        IF lv_end < 0.
          EXIT.
        ENDIF.
        lv_scan = lv_end + 1.
      ENDDO.
      " a tag without its end: the rest goes
      IF lv_gt < 0.
        IF lv_depth = 0.
          result = result && substring( val = xml
                                        off = lv_from
                                        len = lv_lt - lv_from ).
        ENDIF.
        RETURN.
      ENDIF.
      lv_pos = lv_gt + 1.



      temp7 = boolc( lv_next = `/` ).
      lv_closing = temp7.


      temp8 = boolc( lv_closing = abap_false AND substring( val = xml off = lv_gt - 1 len = 1 ) = `/` ).
      lv_empty = temp8.
      IF lv_depth > 0.
        IF lv_closing = abap_true.
          lv_depth = lv_depth - 1.
          IF lv_depth = 0.
            lv_from = lv_pos.
          ENDIF.
        ELSEIF lv_empty = abap_false.
          lv_depth = lv_depth + 1.
        ENDIF.
        CONTINUE.
      ENDIF.
      IF lv_closing = abap_true.
        CONTINUE.
      ENDIF.

      " the prefix of the element - empty for the default namespace
      lv_end = lv_lt + 1.
      WHILE lv_end < lv_gt.
        lv_char = substring( val = xml
                             off = lv_end
                             len = 1 ).
        IF lv_char = `/` OR find( val = lv_ws
                                  sub = lv_char ) >= 0.
          EXIT.
        ENDIF.
        lv_end = lv_end + 1.
      ENDWHILE.

      lv_name = substring( val = xml
                                 off = lv_lt + 1
                                 len = lv_end - lv_lt - 1 ).
      CLEAR lv_prefix.

      lv_colon = find( val = lv_name
                             sub = `:` ).
      IF lv_colon >= 0.
        lv_prefix = substring( val = lv_name
                               len = lv_colon + 1 ).
      ENDIF.

      READ TABLE it_keep WITH KEY table_line = lv_prefix TRANSPORTING NO FIELDS.
      temp105 = sy-subrc.
      IF temp105 = 0.            "#EC CI_SORTSEQ

        READ TABLE it_strict WITH KEY table_line = lv_prefix TRANSPORTING NO FIELDS.
        temp106 = sy-subrc.
        IF NOT temp106 = 0.    "#EC CI_SORTSEQ
          CONTINUE.
        ENDIF.
        " an aggregation, or a control of the strict prefix that is allowed

        lv_local = substring( val = lv_name
                                    off = strlen( lv_prefix ) ).
        IF lv_local IS NOT INITIAL.

          READ TABLE it_allow WITH KEY table_line = lv_name TRANSPORTING NO FIELDS.
          temp107 = sy-subrc.
          IF substring( val = lv_local
                        len = 1 ) CA `abcdefghijklmnopqrstuvwxyz`
              OR temp107 = 0.      "#EC CI_SORTSEQ
            CONTINUE.
          ENDIF.
        ENDIF.
      ENDIF.

      " left out with all it contains
      result = result && substring( val = xml
                                    off = lv_from
                                    len = lv_lt - lv_from ).
      IF lv_empty = abap_true.
        lv_from = lv_pos.
      ELSE.
        lv_depth = 1.
      ENDIF.
    ENDDO.

    " an element without its end: the rest goes with it
    IF lv_depth = 0.
      result = result && substring( val = xml
                                    off = lv_from ).
    ENDIF.

  ENDMETHOD.

  METHOD get_screen.

    TYPES:
      BEGIN OF ty_s_row,
        id       TYPE c LENGTH 32,
        req_body TYPE string,
        res_body TYPE string,
      END OF ty_s_row.
    TYPES:
      BEGIN OF ty_s_model,
        path  TYPE string,
        value TYPE string,
      END OF ty_s_model.
    TYPES temp8 TYPE SORTED TABLE OF ty_s_model WITH UNIQUE KEY path.
DATA lt_model TYPE temp8.
    DATA lt_values TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_row TYPE ty_s_row.
    TYPES temp9 TYPE HASHED TABLE OF ty_s_row WITH UNIQUE KEY id.
DATA lt_row TYPE temp9.
    DATA lt_range TYPE z2ui5_cl_cockpit_session=>ty_r_draft_id.
    DATA lv_id TYPE c LENGTH 32.
    DATA lv_main TYPE string.
    DATA lv_popup TYPE string.
    DATA lv_first TYPE i VALUE 1.
        DATA lv_rec LIKE LINE OF it_id.
            DATA temp108 LIKE LINE OF lt_range.
          DATA lv_index LIKE sy-tabix.
          DATA temp109 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
          DATA ls_input LIKE LINE OF temp109.
            DATA temp110 TYPE ty_s_model.
              FIELD-SYMBOLS <temp111> LIKE LINE OF lt_model.
              DATA temp112 LIKE sy-tabix.
          DATA lv_model_at TYPE i.
            DATA lv_model TYPE string.
            DATA ls_value LIKE LINE OF lt_values.
              DATA temp113 TYPE ty_s_model.
                FIELD-SYMBOLS <temp114> LIKE LINE OF lt_model.
                DATA temp115 LIKE sy-tabix.
          DATA temp116 TYPE z2ui5_if_client=>ty_t_name_value.
          DATA ls_view LIKE LINE OF temp116.
        DATA lx TYPE REF TO cx_root.
    DATA ls_model LIKE LINE OF lt_model.
      DATA temp117 TYPE z2ui5_cl_cockpit_session=>ty_s_value.
      DATA ls_popup TYPE z2ui5_cl_cockpit_wire=>ty_s_screen.

    " the model the client held is rebuilt from the last 30 recordings - the
    " responses push what changed, the requests carry what the user typed
    IF lines( it_id ) > 30.
      lv_first = lines( it_id ) - 29.
    ENDIF.

    TRY.
        " the recordings in one read - at most 30, one IN list

        LOOP AT it_id INTO lv_rec FROM lv_first.
          IF lv_rec IS NOT INITIAL.

            CLEAR temp108.
            temp108-sign = `I`.
            temp108-option = `EQ`.
            temp108-low = lv_rec.
            APPEND temp108 TO lt_range.
          ENDIF.
        ENDLOOP.
        IF lt_range IS NOT INITIAL.
          SELECT id req_body res_body FROM z2ui5_t_28 INTO CORRESPONDING FIELDS OF TABLE lt_row
            WHERE id IN lt_range
            .
        ENDIF.

        LOOP AT it_id INTO lv_rec FROM lv_first.

          lv_index = sy-tabix.
          lv_id = lv_rec.
          READ TABLE lt_row INTO ls_row WITH TABLE KEY id = lv_id.
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.


          temp109 = input_of( ls_row-req_body ).

          LOOP AT temp109 INTO ls_input.
            IF ls_input-path CP `event argument*`.
              CONTINUE.
            ENDIF.

            CLEAR temp110.
            temp110-path = ls_input-path.
            temp110-value = ls_input-value.
            INSERT temp110 INTO TABLE lt_model.
            IF sy-subrc <> 0.


              temp112 = sy-tabix.
              READ TABLE lt_model WITH KEY path = ls_input-path ASSIGNING <temp111>.
              sy-tabix = temp112.
              IF sy-subrc <> 0.
                ASSERT 1 = 0.
              ENDIF.
              <temp111>-value = ls_input-value.
            ENDIF.
          ENDLOOP.


          lv_model_at = find( val = ls_row-res_body
                                    sub = `,"MODEL":` ).
          IF lv_model_at > 0.

            lv_model = substring( val = ls_row-res_body
                                        off = lv_model_at + 9
                                        len = strlen( ls_row-res_body ) - lv_model_at - 10 ).
            TRY.
                lt_values = json_flatten( lv_model ).
              CATCH cx_root.
                CLEAR lt_values.
            ENDTRY.

            LOOP AT lt_values INTO ls_value.

              CLEAR temp113.
              temp113-path = ls_value-path.
              temp113-value = ls_value-value.
              INSERT temp113 INTO TABLE lt_model.
              IF sy-subrc <> 0.


                temp115 = sy-tabix.
                READ TABLE lt_model WITH KEY path = ls_value-path ASSIGNING <temp114>.
                sy-tabix = temp115.
                IF sy-subrc <> 0.
                  ASSERT 1 = 0.
                ENDIF.
                <temp114>-value = ls_value-value.
              ENDIF.
            ENDLOOP.
          ENDIF.

          CLEAR lv_popup.

          temp116 = views_of( ls_row-res_body ).

          LOOP AT temp116 INTO ls_view.
            CASE ls_view-n.
              WHEN `MAIN`.
                lv_main = ls_view-v.
              WHEN cs_kind-popup OR cs_kind-popover.
                " only the step's own response - an older popup may be closed
                IF lv_index = lines( it_id ).
                  lv_popup = ls_view-v.
                ENDIF.
            ENDCASE.
          ENDLOOP.
        ENDLOOP.

      CATCH cx_root INTO lx.
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.

    IF lv_main IS INITIAL.
      result-error = `No recorded response up to this step displayed a view - the recording began later.`.
      RETURN.
    ENDIF.

    CLEAR lt_values.

    LOOP AT lt_model INTO ls_model.

      CLEAR temp117.
      temp117-path = ls_model-path.
      temp117-value = ls_model-value.
      APPEND temp117 TO lt_values.
    ENDLOOP.
    " a popup on top takes the click - the screen below it cannot
    IF lv_popup IS INITIAL.
      result = screen_of( xml      = lv_main
                          it_model = lt_values
                          event    = event ).
    ELSE.
      result = screen_of( xml      = lv_main
                          it_model = lt_values ).

      ls_popup = screen_of( xml      = lv_popup
                                  it_model = lt_values
                                  event    = event ).
      result-marked      = ls_popup-marked.
      result-popup       = ls_popup-content.
      result-popup_title = ls_popup-title.
      " not merged into the main view's: a prefix both declare would resolve
      " the popup's elements against the main view's uri
      result-popup_xmlns = ls_popup-xmlns.
    ENDIF.

  ENDMETHOD.

  METHOD input_errors_of.

    TYPES:
      BEGIN OF ty_s_sample,
        app   TYPE string,
        field TYPE string,
        value TYPE string,
      END OF ty_s_sample.
    TYPES temp10 TYPE HASHED TABLE OF ty_s_sample WITH UNIQUE KEY app field value.
DATA lt_sample TYPE temp10.
    DATA lv_message TYPE string.
    DATA lv_field TYPE string.
    DATA lv_part TYPE string.
    DATA lt_part TYPE string_table.
    DATA lv_rate TYPE i.

    DATA ls_exchange LIKE LINE OF it_exchange.
        DATA temp118 TYPE z2ui5_cl_cockpit_wire=>ty_t_shown.
        DATA ls_shown LIKE LINE OF temp118.
          DATA lv_type TYPE string.
      DATA temp119 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
      DATA ls_input LIKE LINE OF temp119.
          DATA temp120 TYPE string.
        FIELD-SYMBOLS <input> TYPE z2ui5_cl_cockpit_wire=>ty_s_input.
          DATA temp121 TYPE z2ui5_cl_cockpit_wire=>ty_s_input.
        DATA lv_value LIKE ls_input-value.
          DATA temp122 TYPE ty_s_sample.
            DATA temp123 TYPE string.
      DATA temp124 TYPE z2ui5_cl_cockpit_wire=>ty_s_input-state.
    LOOP AT it_exchange INTO ls_exchange.
      " the error the same roundtrip answered with - a failure or an error box
      CLEAR lv_message.
      IF ls_exchange-http_status >= 500.
        lv_message = |failed (HTTP { ls_exchange-http_status })|.
      ELSE.

        temp118 = shown_of( ls_exchange-response ).

        LOOP AT temp118 INTO ls_shown WHERE kind = cs_kind-box. "#EC CI_SORTSEQ

          lv_type = to_lower( ls_shown-type ).
          IF lv_type = `error`.
            lv_message = ls_shown-text.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.


      temp119 = input_of( ls_exchange-request ).

      LOOP AT temp119 INTO ls_input.
        IF ls_input-path CP `event argument*`.
          CONTINUE.
        ENDIF.
        " XX/ is the framework's two-way prefix; a row number is any row
        lv_field = ls_input-path.
        IF lv_field CP `XX/*`.
          lv_field = substring( val = lv_field
                                off = 3 ).
        ENDIF.
        SPLIT lv_field AT `/` INTO TABLE lt_part.
        CLEAR lv_field.
        LOOP AT lt_part INTO lv_part.
          IF lv_part CO `0123456789`.
            lv_part = `*`.
          ENDIF.

          IF lv_field IS NOT INITIAL.
            temp120 = `/`.
          ELSE.
            CLEAR temp120.
          ENDIF.
          lv_field = |{ lv_field }{ temp120 }{ lv_part }|.
        ENDLOOP.


        READ TABLE result ASSIGNING <input>
             WITH KEY app = ls_exchange-app field = lv_field. "#EC CI_SORTSEQ
        IF sy-subrc <> 0.

          CLEAR temp121.
          temp121-app = ls_exchange-app.
          temp121-field = lv_field.
          APPEND temp121 TO result ASSIGNING <input>.
        ENDIF.
        <input>-typed = <input>-typed + 1.
        IF lv_message IS INITIAL.
          CONTINUE.
        ENDIF.
        <input>-errors = <input>-errors + 1.
        " newest first: the first message is the last one shown
        IF <input>-message IS INITIAL.
          <input>-message = lv_message.
        ENDIF.

        lv_value = ls_input-value.
        IF strlen( lv_value ) > 30.
          lv_value = |{ substring( val = lv_value
                                   len = 30 ) }...|.
        ENDIF.
        IF lines( lt_sample ) < 10000.

          CLEAR temp122.
          temp122-app = ls_exchange-app.
          temp122-field = lv_field.
          temp122-value = lv_value.
          INSERT temp122 INTO TABLE lt_sample.
          IF sy-subrc = 0 AND count( val = <input>-samples
                                     sub = `"` ) < 6.

            IF <input>-samples IS NOT INITIAL.
              temp123 = `, `.
            ELSE.
              CLEAR temp123.
            ENDIF.
            <input>-samples = |{ <input>-samples }{ temp123 }| &&
                              |"{ lv_value }"|.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    DELETE result WHERE errors = 0.
    LOOP AT result ASSIGNING <input>.
      " DIV into an integer: a division in a template is i on a system (rounded)
      " and a float on the transpiled runtime
      lv_rate = <input>-errors * 100 DIV <input>-typed.
      <input>-rate = |{ lv_rate } %|.

      IF lv_rate >= 30.
        temp124 = `Error`.
      ELSE.
        temp124 = `Warning`.
      ENDIF.
      <input>-state = temp124.
    ENDLOOP.
    SORT result BY errors DESCENDING typed ASCENDING field ASCENDING.
    IF lines( result ) > 50.
      DELETE result FROM 51 TO lines( result ).
    ENDIF.

  ENDMETHOD.

  METHOD get_input_errors.
        DATA lx TYPE REF TO cx_root.

    TRY.
        result = inputs_from( read_recent( days          = days
                                           check_request = abap_true ) ).

      CATCH cx_root INTO lx.
        result-error = lx->get_text( ).
    ENDTRY.

  ENDMETHOD.

  METHOD inputs_from.

    DATA lt_exchange TYPE ty_t_exchange.
    DATA temp9 TYPE xsdboolean.
    DATA ls_row LIKE LINE OF it_row.
      DATA temp125 TYPE z2ui5_cl_cockpit_wire=>ty_s_exchange.

    result-records = lines( it_row ).

    temp9 = boolc( result-records >= c_max_read ).
    result-check_capped = temp9.

    LOOP AT it_row INTO ls_row.

      CLEAR temp125.
      temp125-app = ls_row-app.
      temp125-request = ls_row-req_body.
      temp125-response = ls_row-res_body.
      temp125-http_status = ls_row-http_status.
      APPEND temp125 TO lt_exchange.
    ENDLOOP.
    result-t_input = input_errors_of( lt_exchange ).

  ENDMETHOD.

  METHOD popup_parts.

    DATA lt_name TYPE string_table.
    DATA lv_open TYPE i.
    DATA lv_close TYPE i.
    DATA lv_rest TYPE string.
    DATA temp126 TYPE string_table.
    DATA lv_name LIKE LINE OF lt_name.
      DATA lv_from TYPE i.
      DATA lv_to TYPE i.
      DATA lv_len TYPE i.

    CLEAR content.
    CLEAR buttons.

    lv_open = find( val = popup
                          sub = `>` ).

    lv_close = find( val = popup
                           sub = `</`
                           occ = -1 ).
    IF lv_open < 0 OR lv_close <= lv_open.
      RETURN.
    ENDIF.

    lv_rest = substring( val = popup
                               off = lv_open + 1
                               len = lv_close - lv_open - 1 ).


    CLEAR temp126.
    INSERT `buttons` INTO TABLE temp126.
    INSERT `beginButton` INTO TABLE temp126.
    INSERT `endButton` INTO TABLE temp126.
    lt_name = temp126.

    LOOP AT lt_name INTO lv_name.

      lv_from = find( val = lv_rest
                            sub = |<{ lv_name }>| ).

      lv_to = find( val = lv_rest
                          sub = |</{ lv_name }>| ).
      IF lv_from < 0 OR lv_to < lv_from.
        CONTINUE.
      ENDIF.

      lv_len = strlen( lv_name ) + 2.
      buttons = buttons && substring( val = lv_rest
                                      off = lv_from + lv_len
                                      len = lv_to - lv_from - lv_len ).
      lv_rest = substring( val = lv_rest
                           len = lv_from ) && substring( val = lv_rest
                                                         off = lv_to + lv_len + 1 ).
    ENDLOOP.

    " the content aggregation when it is written out, else all that is left
    lv_from = find( val = lv_rest
                    sub = `<content>` ).
    lv_to = find( val = lv_rest
                  sub = `</content>`
                  occ = -1 ).
    IF lv_from >= 0 AND lv_to > lv_from.
      content = substring( val = lv_rest
                           off = lv_from + 9
                           len = lv_to - lv_from - 9 ).
    ELSE.
      content = lv_rest.
    ENDIF.

  ENDMETHOD.

  METHOD variants_of.

    TYPES:
      BEGIN OF ty_s_by_draft,
        draft_id TYPE string,
        index    TYPE i,
      END OF ty_s_by_draft.
    TYPES:
      BEGIN OF ty_s_fail,
        draft_id_prev TYPE string,
        timestampl    TYPE timestampl,
        event         TYPE string,
      END OF ty_s_fail.
    TYPES:
      BEGIN OF ty_s_token,
        app  TYPE string,
        text TYPE string,
      END OF ty_s_token.
    TYPES:
      BEGIN OF ty_s_user,
        path TYPE string,
        user TYPE string,
      END OF ty_s_user.
    TYPES temp11 TYPE HASHED TABLE OF ty_s_by_draft WITH UNIQUE KEY draft_id.
DATA lt_by_draft TYPE temp11.
    TYPES temp12 TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_parent TYPE temp12.
    TYPES temp13 TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
DATA lt_succeeded TYPE temp13.
    TYPES temp14 TYPE SORTED TABLE OF ty_s_fail WITH NON-UNIQUE KEY draft_id_prev timestampl.
DATA lt_fail TYPE temp14.
    TYPES temp15 TYPE HASHED TABLE OF ty_s_user WITH UNIQUE KEY path user.
DATA lt_users TYPE temp15.
    TYPES temp18 TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
DATA lt_run TYPE temp18.
    TYPES temp19 TYPE STANDARD TABLE OF ty_s_token WITH DEFAULT KEY.
DATA lt_token TYPE temp19.
    DATA ls_record TYPE ty_s_record.
    DATA ls_on TYPE ty_s_record.
    DATA ls_by TYPE ty_s_by_draft.
    DATA lv_index TYPE i.
    DATA lv_at TYPE i.
    DATA lv_total TYPE i.
    DATA lv_path TYPE string.
    DATA lv_app TYPE string.
    DATA lv_text TYPE string.
    DATA lv_screen_app TYPE string.
    DATA lv_answered TYPE string.
    DATA lv_last TYPE i.
    DATA lv_check_app TYPE abap_bool.
    DATA lv_failed TYPE abap_bool.
    DATA lv_check_leaf TYPE abap_bool.
    DATA lv_check_repeated TYPE abap_bool.
    DATA lv_share TYPE i.
        DATA temp128 TYPE ty_s_by_draft.
          DATA temp129 TYPE ty_s_fail.
      DATA temp10 TYPE xsdboolean.
          DATA ls_fail LIKE LINE OF lt_fail.
              DATA temp130 TYPE ty_s_token.
              DATA temp16 TYPE string.
        DATA temp131 TYPE string.
          FIELD-SYMBOLS <token> TYPE ty_s_token.
          DATA temp132 TYPE ty_s_token.
          DATA temp133 TYPE ty_s_token.
      DATA ls_token LIKE LINE OF lt_token.
          DATA temp134 TYPE string.
          DATA temp17 TYPE string.
      FIELD-SYMBOLS <variant> TYPE z2ui5_cl_cockpit_wire=>ty_s_variant.
        DATA temp135 TYPE z2ui5_cl_cockpit_wire=>ty_s_variant.
        DATA temp136 TYPE z2ui5_cl_cockpit_wire=>ty_s_variant-example.
        DATA temp137 TYPE ty_s_user.
      DATA temp138 TYPE z2ui5_cl_cockpit_wire=>ty_s_variant-state.

    LOOP AT it_record INTO ls_record.
      lv_index = sy-tabix.
      IF ls_record-draft_id IS NOT INITIAL.

        CLEAR temp128.
        temp128-draft_id = ls_record-draft_id.
        temp128-index = lv_index.
        INSERT temp128 INTO TABLE lt_by_draft.
      ENDIF.
      IF ls_record-draft_id_prev IS NOT INITIAL.
        INSERT ls_record-draft_id_prev INTO TABLE lt_parent.
        IF ls_record-draft_id IS NOT INITIAL.
          INSERT ls_record-draft_id_prev INTO TABLE lt_succeeded.
        ELSE.

          CLEAR temp129.
          temp129-draft_id_prev = ls_record-draft_id_prev.
          temp129-timestampl = ls_record-timestampl.
          temp129-event = ls_record-event.
          INSERT temp129 INTO TABLE lt_fail.
        ENDIF.
      ENDIF.
    ENDLOOP.

    LOOP AT it_record INTO ls_record.
      lv_index = sy-tabix.
      " a run ends where nothing continues it: a draft no roundtrip started
      " from, or a failed click the user did not try again from that screen
      IF ls_record-draft_id IS NOT INITIAL.
        READ TABLE lt_parent TRANSPORTING NO FIELDS WITH TABLE KEY table_line = ls_record-draft_id.
      ELSE.
        READ TABLE lt_succeeded TRANSPORTING NO FIELDS WITH TABLE KEY table_line = ls_record-draft_id_prev.
      ENDIF.

      temp10 = boolc( sy-subrc <> 0 ).
      lv_check_leaf = temp10.
      IF lv_check_leaf = abap_false.
        CONTINUE.
      ENDIF.

      " back to the start of the session
      CLEAR lt_run.
      lv_at = lv_index.
      DO 500 TIMES.
        INSERT lv_at INTO lt_run INDEX 1.
        READ TABLE it_record INTO ls_on INDEX lv_at.
        READ TABLE lt_by_draft INTO ls_by WITH TABLE KEY draft_id = ls_on-draft_id_prev.
        IF sy-subrc <> 0 OR ls_by-index = lv_at.
          EXIT.
        ENDIF.
        lv_at = ls_by-index.
      ENDDO.

      " the clicks that failed on the way - in place, before the one that
      " worked. An event belongs to the app whose screen it was pressed on:
      " the one the roundtrip before answered with
      CLEAR lt_token.
      CLEAR lv_check_app.
      CLEAR lv_failed.
      CLEAR lv_screen_app.
      CLEAR lv_answered.
      LOOP AT lt_run INTO lv_at.
        READ TABLE it_record INTO ls_on INDEX lv_at.
        IF lv_screen_app IS INITIAL.
          lv_screen_app = ls_on-app.
        ENDIF.
        IF app IS NOT INITIAL AND ls_on-app = app.
          lv_check_app = abap_true.
        ENDIF.
        IF ls_on-draft_id IS NOT INITIAL AND ls_on-draft_id_prev IS NOT INITIAL.

          LOOP AT lt_fail INTO ls_fail WHERE draft_id_prev = ls_on-draft_id_prev.
            IF ls_fail-timestampl < ls_on-timestampl.

              CLEAR temp130.
              temp130-app = lv_screen_app.

              IF ls_fail-event IS INITIAL.
                temp16 = `(start)`.
              ELSE.
                temp16 = ls_fail-event.
              ENDIF.
              temp130-text = |{ temp16 } (failed)|.
              APPEND temp130 TO lt_token.
            ENDIF.
          ENDLOOP.
        ENDIF.

        IF ls_on-event IS INITIAL.
          temp131 = `(start)`.
        ELSE.
          temp131 = ls_on-event.
        ENDIF.
        lv_text = temp131.
        IF ls_on-draft_id IS INITIAL.
          lv_text = |{ lv_text } (failed)|.
          lv_failed = abap_true.
        ELSEIF ls_on-app IS NOT INITIAL.
          lv_answered = ls_on-app.
        ENDIF.
        " a repeated event once - NEXT, NEXT, NEXT is one way, not three
        CLEAR lv_check_repeated.
        lv_last = lines( lt_token ).
        IF lv_last > 0.

          READ TABLE lt_token ASSIGNING <token> INDEX lv_last.
          IF <token>-app = lv_screen_app AND ( <token>-text = lv_text OR <token>-text = |{ lv_text } (repeated)| ).
            <token>-text = |{ lv_text } (repeated)|.
            lv_check_repeated = abap_true.
          ENDIF.
        ENDIF.
        IF lv_check_repeated = abap_false.

          CLEAR temp132.
          temp132-app = lv_screen_app.
          temp132-text = lv_text.
          APPEND temp132 TO lt_token.
        ENDIF.
        IF ls_on-draft_id IS NOT INITIAL AND ls_on-app IS NOT INITIAL.
          lv_screen_app = ls_on-app.
        ENDIF.
      ENDLOOP.
      " where the run arrived, when its last event led into another app
      lv_last = lines( lt_token ).
      IF lv_failed = abap_false AND lv_answered IS NOT INITIAL AND lv_last > 0.
        READ TABLE lt_token ASSIGNING <token> INDEX lv_last.
        IF <token>-app <> lv_answered.

          CLEAR temp133.
          temp133-app = lv_answered.
          APPEND temp133 TO lt_token.
        ENDIF.
      ENDIF.
      IF app IS NOT INITIAL AND lv_check_app = abap_false.
        CONTINUE.
      ENDIF.

      CLEAR lv_path.
      CLEAR lv_app.

      LOOP AT lt_token INTO ls_token.
        IF sy-tabix > 30.
          lv_path = |{ lv_path } -> ... ({ lines( lt_token ) - 30 } more)|.
          EXIT.
        ENDIF.
        IF ls_token-app <> lv_app.

          IF lv_path IS NOT INITIAL.
            temp134 = ` => `.
          ELSE.
            CLEAR temp134.
          ENDIF.

          IF ls_token-text IS NOT INITIAL.
            temp17 = |: { ls_token-text }|.
          ELSE.
            CLEAR temp17.
          ENDIF.
          lv_path = |{ lv_path }{ temp134 }{ ls_token-app }| &&
                    |{ temp17 }|.
          lv_app = ls_token-app.
        ELSE.
          lv_path = |{ lv_path } -> { ls_token-text }|.
        ENDIF.
      ENDLOOP.

      lv_total = lv_total + 1.

      READ TABLE result ASSIGNING <variant> WITH KEY path = lv_path. "#EC CI_SORTSEQ
      IF sy-subrc <> 0.

        CLEAR temp135.
        temp135-path = lv_path.
        temp135-steps = lines( lt_run ).
        APPEND temp135 TO result ASSIGNING <variant>.
      ENDIF.
      <variant>-runs = <variant>-runs + 1.
      IF lv_failed = abap_true.
        <variant>-failed = <variant>-failed + 1.
      ENDIF.
      " the newest run is the example - a failed click wrote no draft, its
      " run opens where it started
      IF <variant>-example IS INITIAL OR <variant>-last_ts < ls_record-timestampl.
        <variant>-last_ts = ls_record-timestampl.
        <variant>-last = z2ui5_cl_cockpit_setup=>ts_text( ls_record-timestampl ).

        IF ls_record-draft_id IS NOT INITIAL.
          temp136 = ls_record-draft_id.
        ELSE.
          temp136 = ls_record-draft_id_prev.
        ENDIF.
        <variant>-example = temp136.
      ENDIF.
      READ TABLE lt_run INTO lv_at INDEX 1.
      READ TABLE it_record INTO ls_on INDEX lv_at.
      IF ls_on-user IS NOT INITIAL.

        CLEAR temp137.
        temp137-path = lv_path.
        temp137-user = ls_on-user.
        INSERT temp137 INTO TABLE lt_users.
        IF sy-subrc = 0.
          <variant>-users = <variant>-users + 1.
        ENDIF.
      ENDIF.
    ENDLOOP.

    LOOP AT result ASSIGNING <variant>.
      " DIV into an integer - see input_errors_of
      lv_share = <variant>-runs * 100 DIV lv_total.
      <variant>-share = |{ lv_share } %|.

      IF <variant>-failed > 0.
        temp138 = `Error`.
      ELSEIF <variant>-path CS `(failed)`.
        temp138 = `Warning`.
      ELSE.
        temp138 = `None`.
      ENDIF.
      <variant>-state = temp138.
    ENDLOOP.
    SORT result BY runs DESCENDING path ASCENDING.

  ENDMETHOD.

  METHOD get_variants.

    TYPES:
      BEGIN OF ty_s_row,
        id            TYPE c LENGTH 32,
        timestampl    TYPE timestampl,
        app           TYPE c LENGTH 30,
        event         TYPE c LENGTH 40,
        uname         TYPE c LENGTH 12,
        user_key      TYPE c LENGTH 64,
        draft_id      TYPE c LENGTH 32,
        draft_id_prev TYPE c LENGTH 32,
        http_status   TYPE i,
      END OF ty_s_row.
    TYPES temp20 TYPE STANDARD TABLE OF ty_s_row WITH DEFAULT KEY.
DATA lt_rows TYPE temp20.
    DATA lt_record TYPE ty_t_record.
    DATA lv_from TYPE c LENGTH 8.
        DATA lx TYPE REF TO cx_root.
    DATA temp11 TYPE xsdboolean.
    DATA ls_row LIKE LINE OF lt_rows.
      DATA temp139 TYPE z2ui5_cl_cockpit_wire=>ty_s_record.
      DATA temp18 TYPE z2ui5_cl_cockpit_wire=>ty_s_record-user.
    DATA ls_variant LIKE LINE OF result-t_variant.

    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).
    TRY.
        " no body - ids, app and event are columns of their own
        SELECT id timestampl app event uname user_key draft_id draft_id_prev http_status
          FROM z2ui5_t_28 UP TO 20000 ROWS INTO CORRESPONDING FIELDS OF TABLE lt_rows
          WHERE utc_day >= lv_from
          ORDER BY timestampl DESCENDING

          .

      CATCH cx_root INTO lx.
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.
    result-records = lines( lt_rows ).

    temp11 = boolc( result-records >= 20000 ).
    result-check_capped = temp11.


    LOOP AT lt_rows INTO ls_row.

      CLEAR temp139.
      temp139-id = ls_row-id.
      temp139-timestampl = ls_row-timestampl.
      temp139-app = ls_row-app.
      temp139-event = ls_row-event.
      temp139-draft_id = ls_row-draft_id.
      temp139-draft_id_prev = ls_row-draft_id_prev.
      temp139-http_status = ls_row-http_status.

      IF ls_row-uname IS NOT INITIAL.
        temp18 = ls_row-uname.
      ELSE.
        temp18 = ls_row-user_key.
      ENDIF.
      temp139-user = temp18.
      APPEND temp139 TO lt_record.
    ENDLOOP.
    result-t_variant = variants_of( it_record = lt_record
                                    app       = app ).

    LOOP AT result-t_variant INTO ls_variant.
      result-runs = result-runs + ls_variant-runs.
      result-failed_runs = result-failed_runs + ls_variant-failed.
    ENDLOOP.

  ENDMETHOD.

  METHOD mark_pressed.

    DATA lv_wire TYPE string.
    DATA lv_at TYPE i.
    DATA lv_open TYPE i.
    DATA lv_close TYPE i.
    DATA lv_name_end TYPE i.
    DATA lv_tag TYPE string.
    DATA lv_class TYPE i.
      DATA lv_insert TYPE i.
    lv_wire = |['{ event }'|.

    lv_at = find( val = xml
                        sub = lv_wire ).
    IF lv_at < 0.
      RETURN.
    ENDIF.
    " the element around it: the last < before, the first > after

    lv_open = find( val = substring( val = xml
                                           len = lv_at )
                          sub = `<`
                          occ = -1 ).

    lv_close = find( val = xml
                           sub = `>`
                           off = lv_at ).

    lv_name_end = find( val = xml
                              sub = ` `
                              off = lv_open ).
    IF lv_open < 0 OR lv_close < 0 OR lv_name_end < 0 OR lv_name_end > lv_close.
      RETURN.
    ENDIF.

    lv_tag = substring( val = xml
                              off = lv_open
                              len = lv_close - lv_open ).

    lv_class = find( val = lv_tag
                           sub = ` class="` ).
    IF lv_class >= 0.

      lv_insert = lv_open + lv_class + 8.
      xml = |{ substring( val = xml
                          len = lv_insert ) }{ c_pressed } { substring( val = xml
                                                                        off = lv_insert ) }|.
    ELSE.
      xml = |{ substring( val = xml
                          len = lv_name_end ) } class="{ c_pressed }"{ substring( val = xml
                                                                                  off = lv_name_end ) }|.
    ENDIF.
    result = abap_true.

  ENDMETHOD.

  METHOD xml_escape.

    " replace( ), not REPLACE ... WITH: the transpiled REPLACE reads its
    " WITH text like a regex replacement and drops the backslash of \{
    " (abap2UI5 backlog runtime-replace-with-literal) - the unit tests would
    " not see what the system does. The backslash first: UI5 unescapes \\ to
    " one, and a backslash in front of an escaped brace would otherwise turn
    " it back into a binding
    result = replace( val  = val
                      sub  = `\`
                      with = `\\`
                      occ  = 0 ).
    result = replace( val  = result
                      sub  = `&`
                      with = `&amp;`
                      occ  = 0 ).
    result = replace( val  = result
                      sub  = `<`
                      with = `&lt;`
                      occ  = 0 ).
    result = replace( val  = result
                      sub  = `>`
                      with = `&gt;`
                      occ  = 0 ).
    result = replace( val  = result
                      sub  = `"`
                      with = `&quot;`
                      occ  = 0 ).
    " the braces last - they would start a binding
    result = replace( val  = result
                      sub  = `{`
                      with = `\{`
                      occ  = 0 ).
    result = replace( val  = result
                      sub  = `}`
                      with = `\}`
                      occ  = 0 ).

  ENDMETHOD.

  METHOD shown_text.

    DATA ls_shown LIKE LINE OF it_shown.
      DATA temp140 TYPE string.
      DATA temp19 TYPE string.
    LOOP AT it_shown INTO ls_shown.
      IF ls_shown-kind = cs_kind-view.
        CONTINUE.
      ENDIF.

      CASE ls_shown-kind.
        WHEN cs_kind-box.
          temp140 = |{ ls_shown-type } box|.
        WHEN cs_kind-toast.
          temp140 = `toast`.
        WHEN cs_kind-popup.
          temp140 = `popup`.
        WHEN OTHERS.
          temp140 = `popover`.
      ENDCASE.

      IF result IS NOT INITIAL.
        temp19 = `; `.
      ELSE.
        CLEAR temp19.
      ENDIF.
      result = |{ result }{ temp19 }| &&
               |{ temp140 }: { ls_shown-text }|.
    ENDLOOP.

  ENDMETHOD.

  METHOD member_before.

    DATA lv_key TYPE string.
    DATA lv_off TYPE i.
    lv_key = |"{ name }":"|.

    lv_off = find( val = json
                         sub = lv_key ).
    IF lv_off < 0 OR lv_off >= before.
      RETURN.
    ENDIF.
    result = substring( val = json
                        off = lv_off + strlen( lv_key ) ).
    IF result CS `"`.
      result = substring_before( val = result
                                 sub = `"` ).
    ENDIF.

  ENDMETHOD.

  METHOD xml_attribute.

    result = z2ui5_cl_cockpit_session=>xml_attribute( xml  = xml
                                                      name = name ).

  ENDMETHOD.

ENDCLASS.
