"! <p class="shorttext synchronized">admin cockpit - request recorder</p>
"!
"! Records every roundtrip as it went over the wire: the request the browser
"! sent (event, event arguments, the values the user changed) and the
"! response abap2UI5 answered with (message boxes, toasts, popups, the view
"! XML and the model) - unparsed, so every later question can be asked of
"! old recordings too, and a screen can be set up again from them.
"!
"! Opt-in by one line in the ICF handler class of the installation, right
"! after abap2UI5 ran:
"!   z2ui5_cl_ui5_http_handler=&gt;run( server ).
"!   z2ui5_cl_cockpit_wire=&gt;record( server ).
"! (ABAP Cloud: record( req = request res = response ).) Like the monitor it
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
    TYPES ty_t_shown TYPE STANDARD TABLE OF ty_s_shown WITH EMPTY KEY.

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
        " the user as stored - name or pseudonym, filled by get_variants only
        user          TYPE string,
      END OF ty_s_record.
    TYPES ty_t_record TYPE STANDARD TABLE OF ty_s_record WITH EMPTY KEY.

    TYPES:
      "! One recorded roundtrip in full, as the recorder view shows it.
      BEGIN OF ty_s_detail,
        error       TYPE string,
        time        TYPE string,
        app         TYPE string,
        event       TYPE string,
        http_status TYPE i,
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
        " the popup the step's response opened, as a second content
        popup     TYPE string,
        popup_title TYPE string,
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
    TYPES ty_t_message TYPE STANDARD TABLE OF ty_s_message WITH EMPTY KEY.

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
    TYPES ty_t_variant TYPE STANDARD TABLE OF ty_s_variant WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_variants,
        error        TYPE string,
        records      TYPE i,
        runs         TYPE i,
        failed_runs  TYPE i,
        check_capped TYPE abap_bool,
        t_variant    TYPE ty_t_variant,
      END OF ty_s_variants.

    "! Record the roundtrip that just ran - the line for the ICF handler.
    "! Never raises.
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
        check_sticky TYPE abap_bool DEFAULT abap_false.

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
    "! emptied - a press in the copy fires nothing.
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

  PROTECTED SECTION.

  PRIVATE SECTION.

    CLASS-DATA gt_buffer TYPE STANDARD TABLE OF z2ui5_t_ck_wir WITH EMPTY KEY.

    "! The table row of a recorded roundtrip - ids, app and event taken out
    "! of the bodies, the user as the privacy setting allows.
    CLASS-METHODS row_of
      IMPORTING
        request       TYPE string
        response      TYPE string
        http_status   TYPE i
        check_sticky  TYPE abap_bool
      RETURNING
        VALUE(result) TYPE z2ui5_t_ck_wir
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

    "! The value of an XML attribute in the first element that has it.
    CLASS-METHODS xml_attribute
      IMPORTING
        xml           TYPE string
        name          TYPE string
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS to_utf8
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE xstring.

ENDCLASS.


CLASS z2ui5_cl_cockpit_wire IMPLEMENTATION.

  METHOD record.

    DATA lo_req TYPE REF TO object.
    DATA lo_res TYPE REF TO object.
    DATA lv_method TYPE string.
    DATA lv_request TYPE string.
    DATA lv_response TYPE string.
    DATA lv_status TYPE i.
    DATA lv_sticky TYPE abap_bool.
    DATA lr_status TYPE REF TO data.
    FIELD-SYMBOLS <any> TYPE any.
    FIELD-SYMBOLS <status> TYPE any.
    FIELD-SYMBOLS <code> TYPE any.

    TRY.
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
              data = lv_request.
          CALL METHOD lo_res->(`GET_CDATA`)
            RECEIVING
              data = lv_response.
          TRY.
              CALL METHOD lo_res->(`IF_HTTP_RESPONSE~GET_STATUS`)
                IMPORTING
                  code = lv_status.
            CATCH cx_root ##NO_HANDLER.
          ENDTRY.
          UNASSIGN <any>.
          ASSIGN server->(`STATEFUL`) TO <any>.
          IF <any> IS ASSIGNED.
            lv_sticky = xsdbool( <any> = 1 ).
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
              r_value = lv_request.
          CALL METHOD res->(`IF_WEB_HTTP_RESPONSE~GET_TEXT`)
            RECEIVING
              r_value = lv_response.
          TRY.
              CREATE DATA lr_status TYPE (`IF_WEB_HTTP_RESPONSE=>HTTP_STATUS`).
              ASSIGN lr_status->* TO <status>.
              CALL METHOD res->(`IF_WEB_HTTP_RESPONSE~GET_STATUS`)
                RECEIVING
                  r_value = <status>.
              ASSIGN COMPONENT `CODE` OF STRUCTURE <status> TO <code>.
              IF <code> IS ASSIGNED.
                lv_status = <code>.
              ENDIF.
            CATCH cx_root ##NO_HANDLER.
          ENDTRY.

        ELSE.
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

  METHOD record_bodies.

    DATA ls_row TYPE z2ui5_t_ck_wir.

    TRY.
        DATA(ls_set) = z2ui5_cl_cockpit_setup=>get( ).
        IF ls_set-wire_days <= 0 OR request IS INITIAL.
          RETURN.
        ENDIF.

        ls_row = row_of( request      = request
                         response     = response
                         http_status  = http_status
                         check_sticky = check_sticky ).

        " a sticky app owns the LUW - its uncommitted work and locks must not
        " be committed by the recorder: the recording waits for a roundtrip
        " that is not sticky
        IF check_sticky = abap_true.
          IF lines( gt_buffer ) < c_buffer_max.
            APPEND ls_row TO gt_buffer.
          ENDIF.
          RETURN.
        ENDIF.

        IF ls_set-last_purge <> ls_row-utc_day.
          z2ui5_cl_cockpit_setup=>set_last_purge( ls_row-utc_day ).
          z2ui5_cl_cockpit_job=>purge_own( ).
        ENDIF.
        DATA(lt_buffer) = gt_buffer.
        CLEAR gt_buffer.
        APPEND ls_row TO lt_buffer.
        LOOP AT lt_buffer INTO DATA(ls_buffered).
          INSERT z2ui5_t_ck_wir FROM @ls_buffered.
        ENDLOOP.
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

    DATA lv_root TYPE string.

    result-id           = cl_system_uuid=>create_uuid_c32_static( ).
    result-timestampl   = z2ui5_cl_cockpit_setup=>now( ).
    result-utc_day      = z2ui5_cl_cockpit_setup=>day_of( result-timestampl ).
    result-http_status  = http_status.
    result-check_sticky = check_sticky.
    result-user_key     = z2ui5_cl_cockpit_setup=>user_key( uname = sy-uname
                                                            day   = result-utc_day ).
    IF z2ui5_cl_cockpit_setup=>check_privacy( ) = abap_false.
      result-uname = sy-uname.
    ENDIF.

    " the request is small: taken apart for the draft it started from and
    " its event; the request of a first start has no draft
    TRY.
        DATA(lt_request) = json_flatten( request ).
        lv_root = COND #( WHEN line_exists( lt_request[ path = `value/S_FRONT/ID` ] ) THEN `value/` ).
        " the keys in variables - a template is no key operand on 7.02
        DATA(lv_id_path) = |{ lv_root }S_FRONT/ID|.
        DATA(lv_event_path) = |{ lv_root }S_FRONT/EVENT|.
        result-draft_id_prev = VALUE #( lt_request[ path = lv_id_path ]-value OPTIONAL ).
        result-event         = VALUE #( lt_request[ path = lv_event_path ]-value OPTIONAL ).
      CATCH cx_root ##NO_HANDLER.
        " no JSON - recorded as it came
    ENDTRY.

    " the response can be large - its id and app stand first in S_FRONT,
    " before PROTOCOL and the actions, and are found by text
    DATA(lv_protocol) = find( val = response
                              sub = `"PROTOCOL":` ).
    IF lv_protocol > 0.
      result-draft_id = member_before( json   = response
                                       name   = `ID`
                                       before = lv_protocol ).
      result-app      = to_upper( member_before( json   = response
                                                 name   = `APP`
                                                 before = lv_protocol ) ).
    ENDIF.

    result-req_body = request.
    result-res_body = response.
    IF strlen( result-req_body ) > c_max_body.
      result-req_body = substring( val = result-req_body
                                   len = c_max_body ).
    ENDIF.
    IF strlen( result-res_body ) > c_max_body.
      result-res_body = substring( val = result-res_body
                                   len = c_max_body ).
    ENDIF.

  ENDMETHOD.

  METHOD get_records.

    TYPES ty_id TYPE c LENGTH 32.
    TYPES ty_r_id TYPE RANGE OF ty_id.
    TYPES:
      BEGIN OF ty_s_row,
        id            TYPE c LENGTH 32,
        timestampl    TYPE timestampl,
        app           TYPE c LENGTH 30,
        event         TYPE c LENGTH 40,
        draft_id      TYPE c LENGTH 32,
        draft_id_prev TYPE c LENGTH 32,
        http_status   TYPE i,
      END OF ty_s_row.
    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    DATA lt_range TYPE ty_r_id.
    DATA lv_done TYPE i.

    TRY.
        LOOP AT it_id INTO DATA(lv_id).
          lv_done = lv_done + 1.
          IF lv_id IS NOT INITIAL.
            APPEND VALUE #( sign   = `I`
                            option = `EQ`
                            low    = lv_id ) TO lt_range.
          ENDIF.
          IF lines( lt_range ) < 50 AND lv_done < lines( it_id ).
            CONTINUE.
          ENDIF.
          IF lt_range IS INITIAL.
            CONTINUE.
          ENDIF.
          SELECT id, timestampl, app, event, draft_id, draft_id_prev, http_status
            FROM z2ui5_t_ck_wir
            WHERE draft_id IN @lt_range
               OR draft_id_prev IN @lt_range
            APPENDING CORRESPONDING FIELDS OF TABLE @lt_rows.
          CLEAR lt_range.
        ENDLOOP.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    SORT lt_rows BY timestampl ASCENDING id ASCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_rows COMPARING id.
    LOOP AT lt_rows INTO DATA(ls_row).
      APPEND VALUE #( id            = ls_row-id
                      timestampl    = ls_row-timestampl
                      app           = ls_row-app
                      event         = ls_row-event
                      draft_id      = ls_row-draft_id
                      draft_id_prev = ls_row-draft_id_prev
                      http_status   = ls_row-http_status ) TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_bodies.

    DATA lv_id TYPE c LENGTH 32.
    CLEAR request.
    CLEAR response.
    lv_id = id.
    TRY.
        SELECT SINGLE req_body, res_body FROM z2ui5_t_ck_wir
          WHERE id = @lv_id
          INTO (@request, @response).
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
    DATA ls_row TYPE z2ui5_t_ck_wir.
    DATA lv_input TYPE string.

    lv_id = id.
    TRY.
        SELECT SINGLE * FROM z2ui5_t_ck_wir
          WHERE id = @lv_id
          INTO @ls_row.
        IF sy-subrc <> 0.
          result-error = `The recording is gone - deleted by its retention.`.
          RETURN.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.

    result-time        = z2ui5_cl_cockpit_setup=>ts_text( ls_row-timestampl ).
    result-app         = ls_row-app.
    result-event       = ls_row-event.
    result-http_status = ls_row-http_status.
    result-request     = ls_row-req_body.
    result-response    = ls_row-res_body.
    result-shown       = shown_text( shown_of( ls_row-res_body ) ).
    LOOP AT input_of( ls_row-req_body ) INTO DATA(ls_value).
      lv_input = |{ lv_input }{ COND #( WHEN lv_input IS NOT INITIAL THEN cl_abap_char_utilities=>newline ) }| &&
                 |{ ls_value-path } = { ls_value-value }|.
    ENDLOOP.
    result-input = lv_input.
    LOOP AT views_of( ls_row-res_body ) INTO DATA(ls_view).
      result-view_xml = |{ result-view_xml }{ COND #( WHEN result-view_xml IS NOT INITIAL
                                                       THEN cl_abap_char_utilities=>newline ) }| &&
                        |<!-- { ls_view-n } -->{ cl_abap_char_utilities=>newline }{ ls_view-v }|.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_messages.

    TYPES:
      BEGIN OF ty_s_row,
        app           TYPE c LENGTH 30,
        uname         TYPE c LENGTH 12,
        user_key      TYPE c LENGTH 64,
        timestampl    TYPE timestampl,
        draft_id      TYPE c LENGTH 32,
        draft_id_prev TYPE c LENGTH 32,
        res_body      TYPE string,
      END OF ty_s_row.
    TYPES:
      BEGIN OF ty_s_user,
        app  TYPE string,
        kind TYPE string,
        type TYPE string,
        text TYPE string,
        user TYPE string,
      END OF ty_s_user.
    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    DATA lt_users TYPE HASHED TABLE OF ty_s_user WITH UNIQUE KEY app kind type text user.
    DATA lv_from TYPE c LENGTH 8.

    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).
    TRY.
        SELECT app, uname, user_key, timestampl, draft_id, draft_id_prev, res_body FROM z2ui5_t_ck_wir
          WHERE utc_day >= @lv_from
          ORDER BY timestampl DESCENDING
          INTO CORRESPONDING FIELDS OF TABLE @lt_rows
          UP TO @c_max_read ROWS.
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.
    result-records = lines( lt_rows ).
    result-check_capped = xsdbool( result-records >= c_max_read ).

    LOOP AT lt_rows INTO DATA(ls_row).
      DATA(lv_user) = COND string( WHEN ls_row-uname IS NOT INITIAL THEN ls_row-uname ELSE ls_row-user_key ).
      LOOP AT shown_of( ls_row-res_body ) INTO DATA(ls_shown).
        IF ls_shown-kind = cs_kind-view.
          CONTINUE.
        ENDIF.
        READ TABLE result-t_message ASSIGNING FIELD-SYMBOL(<message>)
             WITH KEY app = ls_row-app kind = ls_shown-kind type = ls_shown-type text = ls_shown-text. "#EC CI_SORTSEQ
        IF sy-subrc <> 0.
          " a variable, not to_lower( ) in the SWITCH - no CASE operand on 7.02
          DATA(lv_type) = to_lower( ls_shown-type ).
          " rows come newest first - the first one is the last time it was shown
          " a failed roundtrip wrote no draft - its session opens where it started
          APPEND VALUE #( app     = ls_row-app
                          kind    = ls_shown-kind
                          type    = ls_shown-type
                          text    = ls_shown-text
                          example = COND #( WHEN ls_row-draft_id IS NOT INITIAL THEN ls_row-draft_id
                                            ELSE ls_row-draft_id_prev )
                          last    = z2ui5_cl_cockpit_setup=>ts_text( ls_row-timestampl )
                          state = SWITCH #( lv_type
                                            WHEN `error` THEN `Error`
                                            WHEN `warning` THEN `Warning`
                                            WHEN `success` THEN `Success`
                                            ELSE `None` ) ) TO result-t_message ASSIGNING <message>.
        ENDIF.
        <message>-count = <message>-count + 1.
        IF lv_user IS NOT INITIAL.
          INSERT VALUE #( app  = ls_row-app
                          kind = ls_shown-kind
                          type = ls_shown-type
                          text = ls_shown-text
                          user = lv_user ) INTO TABLE lt_users.
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
        SELECT COUNT( * ) FROM z2ui5_t_ck_wir
          WHERE utc_day >= @lv_from
          INTO @result.
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
    DATA lt_stack TYPE STANDARD TABLE OF ty_s_open WITH EMPTY KEY.
    DATA lo_open TYPE REF TO if_sxml_open_element.
    DATA lo_value TYPE REF TO if_sxml_value_node.
    DATA lv_name TYPE string.
    DATA lv_leaf_path TYPE string.
    FIELD-SYMBOLS <top> TYPE ty_s_open.

    IF json IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lo_reader) = cl_sxml_string_reader=>create( to_utf8( json ) ).

    DO.
      DATA(lo_node) = lo_reader->read_next_node( ).
      IF lo_node IS NOT BOUND.
        EXIT.
      ENDIF.

      CASE lo_node->type.
        WHEN if_sxml_node=>co_nt_element_open.
          lo_open ?= lo_node.
          CLEAR lv_name.
          UNASSIGN <top>.
          IF lt_stack IS NOT INITIAL.
            ASSIGN lt_stack[ lines( lt_stack ) ] TO <top>.
            <top>-children = <top>-children + 1.
            IF <top>-type = `array`.
              lv_name = |{ <top>-children }|.
            ELSE.
              LOOP AT lo_open->get_attributes( ) INTO DATA(lo_attribute).
                lv_name = lo_attribute->get_value( ).
                EXIT.
              ENDLOOP.
            ENDIF.
          ENDIF.
          APPEND VALUE #( type = lo_open->qname-name
                          name = lv_name
                          path = COND #( WHEN <top> IS NOT ASSIGNED THEN ``
                                         WHEN <top>-path IS INITIAL THEN lv_name
                                         ELSE |{ <top>-path }/{ lv_name }| ) ) TO lt_stack.

        WHEN if_sxml_node=>co_nt_value.
          lo_value ?= lo_node.
          IF lt_stack IS NOT INITIAL.
            ASSIGN lt_stack[ lines( lt_stack ) ] TO <top>.
            lv_leaf_path = <top>-path.
            APPEND VALUE #( path  = lv_leaf_path
                            value = lo_value->get_value( ) ) TO result.
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
    DATA lt_action TYPE STANDARD TABLE OF ty_s_action WITH EMPTY KEY.
    DATA lt_values TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA lv_rest TYPE string.
    DATA lv_nr TYPE string.

    TRY.
        lt_values = json_flatten( response ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    " one action is one array - S_FRONT/S_ACTION/T_CUSTOM/<n>/<position>
    LOOP AT lt_values INTO DATA(ls_value).
      IF ls_value-path NP `S_FRONT/S_ACTION/T_*`.
        CONTINUE.
      ENDIF.
      lv_rest = substring_after( val = ls_value-path
                                 sub = `S_FRONT/S_ACTION/` ).
      " the queue and the number of the action: T_CUSTOM/3
      DATA(lv_slash) = find( val = lv_rest
                             sub = `/` ).
      IF lv_slash < 0.
        CONTINUE.
      ENDIF.
      DATA(lv_after) = substring( val = lv_rest
                                  off = lv_slash + 1 ).
      DATA(lv_slash2) = find( val = lv_after
                              sub = `/` ).
      IF lv_slash2 < 0.
        CONTINUE.
      ENDIF.
      lv_nr = substring( val = lv_rest
                         len = lv_slash + 1 + lv_slash2 ).
      READ TABLE lt_action ASSIGNING FIELD-SYMBOL(<action>) WITH KEY nr = lv_nr. "#EC CI_SORTSEQ
      IF sy-subrc <> 0.
        APPEND VALUE #( nr = lv_nr ) TO lt_action ASSIGNING <action>.
      ENDIF.
      APPEND VALUE #( path  = substring( val = lv_after
                                         off = lv_slash2 + 1 )
                      value = ls_value-value ) TO <action>-values.
    ENDLOOP.

    LOOP AT lt_action INTO DATA(ls_action).
      DATA(lv_1) = VALUE #( ls_action-values[ path = `1` ]-value OPTIONAL ).
      DATA(lv_2) = VALUE #( ls_action-values[ path = `2` ]-value OPTIONAL ).
      DATA(lv_3) = VALUE #( ls_action-values[ path = `3` ]-value OPTIONAL ).
      DATA(lv_4) = VALUE #( ls_action-values[ path = `4` ]-value OPTIONAL ).
      CASE lv_1.
        WHEN cs_kind-box.
          APPEND VALUE #( kind = cs_kind-box
                          type = lv_2
                          text = lv_3 ) TO result.
        WHEN cs_kind-toast.
          APPEND VALUE #( kind = cs_kind-toast
                          text = lv_3 ) TO result.
        WHEN `VIEW_SLOTS`.
          IF lv_2 <> `display`.
            CONTINUE.
          ENDIF.
          CASE lv_3.
            WHEN cs_kind-popup OR cs_kind-popover.
              APPEND VALUE #( kind = lv_3
                              text = xml_attribute( xml  = lv_4
                                                    name = `title` ) ) TO result.
            WHEN `MAIN`.
              APPEND VALUE #( kind = cs_kind-view
                              text = xml_attribute( xml  = lv_4
                                                    name = `title` ) ) TO result.
          ENDCASE.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.

  METHOD input_of.

    DATA lt_values TYPE z2ui5_cl_cockpit_session=>ty_t_value.

    TRY.
        lt_values = json_flatten( request ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
    LOOP AT lt_values INTO DATA(ls_value).
      DATA(lv_path) = ls_value-path.
      IF lv_path CP `value/*`.
        lv_path = substring( val = lv_path
                             off = 6 ).
      ENDIF.
      IF lv_path CP `MODEL/*`.
        APPEND VALUE #( path  = substring( val = lv_path
                                           off = 6 )
                        value = ls_value-value ) TO result.
      ELSEIF lv_path CP `S_FRONT/T_EVENT_ARG/*`.
        APPEND VALUE #( path  = |event argument { substring( val = lv_path
                                                              off = 20 ) }|
                        value = ls_value-value ) TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD views_of.

    DATA lt_values TYPE z2ui5_cl_cockpit_session=>ty_t_value.

    TRY.
        lt_values = json_flatten( response ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
    " a display action: ["VIEW_SLOTS","display","<slot>","<xml>",{...}]
    LOOP AT lt_values INTO DATA(ls_value) WHERE value = `display`. "#EC CI_SORTSEQ
      IF ls_value-path NP `S_FRONT/S_ACTION/T_SYSTEM/*/2`.
        CONTINUE.
      ENDIF.
      DATA(lv_base) = substring( val = ls_value-path
                                 len = strlen( ls_value-path ) - 1 ).
      " the keys in variables - a template is no key operand on 7.02
      DATA(lv_slot_path) = |{ lv_base }3|.
      DATA(lv_xml_path) = |{ lv_base }4|.
      DATA(lv_slot) = VALUE #( lt_values[ path = lv_slot_path ]-value OPTIONAL ).
      DATA(lv_xml) = VALUE #( lt_values[ path = lv_xml_path ]-value OPTIONAL ).
      IF lv_xml IS NOT INITIAL.
        APPEND VALUE #( n = lv_slot
                        v = lv_xml ) TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD control_of.

    DATA lv_open TYPE i.

    IF event IS INITIAL OR xml IS INITIAL.
      RETURN.
    ENDIF.
    " an event wire is .eB(['NAME'... in an attribute of the control
    DATA(lv_hit) = find( val = xml
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
    DATA(lv_close) = find( val = xml
                           sub = `>`
                           off = lv_hit ).
    IF lv_close < 0.
      RETURN.
    ENDIF.
    DATA(lv_element) = substring( val = xml
                                  off = lv_open
                                  len = lv_close - lv_open + 1 ).
    DATA(lv_name) = substring( val = lv_element
                               off = 1 ).
    IF lv_name CS ` `.
      lv_name = substring_before( val = lv_name
                                  sub = ` ` ).
    ENDIF.
    IF lv_name CS `:`.
      lv_name = substring_after( val = lv_name
                                 sub = `:` ).
    ENDIF.

    DATA(lv_label) = xml_attribute( xml  = lv_element
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
    result = |{ lv_name }{ COND #( WHEN lv_label IS NOT INITIAL THEN | "{ lv_label }"| ) }|.

  ENDMETHOD.

  METHOD field_control_of.

    DATA lv_open TYPE i.

    IF path IS INITIAL OR xml IS INITIAL.
      RETURN.
    ENDIF.
    " {/PATH} or path:'/PATH'
    DATA(lv_hit) = find( val = xml
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
    DATA(lv_name) = substring( val = xml
                               off = lv_open + 1 ).
    lv_name = substring_before( val = lv_name
                                sub = ` ` ).
    IF lv_name CS `:`.
      lv_name = substring_after( val = lv_name
                                 sub = `:` ).
    ENDIF.

    " a form puts the Label right before its field
    DATA(lv_before) = substring( val = xml
                                 len = lv_open ).
    DATA(lv_label_at) = find( val = lv_before
                              sub = `<Label `
                              occ = -1 ).
    DATA(lv_text) = ``.
    IF lv_label_at >= 0 AND lv_open - lv_label_at < 400.
      lv_text = xml_attribute( xml  = substring( val = lv_before
                                                 off = lv_label_at )
                               name = `text` ).
    ENDIF.
    result = |{ lv_name }{ COND #( WHEN lv_text IS NOT INITIAL THEN | "{ lv_text }"| ) }|.

  ENDMETHOD.

  METHOD screen_of.

    DATA lv_pos TYPE i.
    DATA lv_out TYPE string.

    " the root element: <mvc:View xmlns="sap.m" xmlns:mvc="..." ...>
    DATA(lv_start) = find( val = xml
                           sub = `<` ).
    WHILE lv_start >= 0 AND substring( val = xml
                                       off = lv_start + 1
                                       len = 1 ) = `?`.
      lv_start = find( val = xml
                       sub = `<`
                       off = lv_start + 1 ).
    ENDWHILE.
    IF lv_start < 0.
      result-error = `The recorded view is no XML.`.
      RETURN.
    ENDIF.
    DATA(lv_root_end) = find( val = xml
                              sub = `>`
                              off = lv_start ).
    DATA(lv_last) = find( val = xml
                          sub = `</`
                          occ = -1 ).
    IF lv_root_end < 0 OR lv_last <= lv_root_end.
      result-error = `The recorded view is empty.`.
      RETURN.
    ENDIF.
    DATA(lv_root) = substring( val = xml
                               off = lv_start
                               len = lv_root_end - lv_start ).

    " its namespace declarations move to the element the copy is shown in
    lv_pos = 0.
    DO.
      DATA(lv_ns) = find( val = lv_root
                          sub = ` xmlns`
                          off = lv_pos ).
      IF lv_ns < 0.
        EXIT.
      ENDIF.
      DATA(lv_eq) = find( val = lv_root
                          sub = `="`
                          off = lv_ns ).
      DATA(lv_end) = find( val = lv_root
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

    DATA(lv_content) = substring( val = xml
                                  off = lv_root_end + 1
                                  len = lv_last - lv_root_end - 1 ).

    IF event IS NOT INITIAL.
      result-marked = mark_pressed( EXPORTING event = event
                                    CHANGING  xml   = lv_content ).
    ENDIF.

    " event handlers emptied: .eB( .eBP( .eF( are the framework's wires
    lv_pos = 0.
    DO.
      DATA(lv_wire) = find( val = lv_content
                            sub = `=".e`
                            off = lv_pos ).
      IF lv_wire < 0.
        EXIT.
      ENDIF.
      DATA(lv_quote) = find( val = lv_content
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
      DATA(lv_items) = find( val = lv_content
                             sub = ` items="{/`
                             off = lv_pos ).
      IF lv_items < 0.
        EXIT.
      ENDIF.
      DATA(lv_path_end) = find( val = lv_content
                                sub = `}"`
                                off = lv_items ).
      IF lv_path_end < 0.
        EXIT.
      ENDIF.
      DATA(lv_list) = substring( val = lv_content
                                 off = lv_items + 10
                                 len = lv_path_end - lv_items - 10 ).
      DATA(lv_tmpl_open) = find( val = lv_content
                                 sub = `<items>`
                                 off = lv_path_end ).
      DATA(lv_tmpl_close) = find( val = lv_content
                                  sub = `</items>`
                                  off = lv_path_end ).
      IF lv_tmpl_open < 0 OR lv_tmpl_close < lv_tmpl_open.
        lv_pos = lv_path_end.
        CONTINUE.
      ENDIF.
      DATA(lv_template) = substring( val = lv_content
                                     off = lv_tmpl_open + 7
                                     len = lv_tmpl_close - lv_tmpl_open - 7 ).
      CLEAR lv_out.
      DO 50 TIMES.
        DATA(lv_row) = sy-index.
        " keys and patterns in variables - no template there on 7.02
        DATA(lv_prefix) = |{ lv_list }/{ lv_row }/|.
        DATA(lv_row_path) = |{ lv_list }/{ lv_row }|.
        DATA(lv_pattern) = |{ lv_prefix }*|.
        IF NOT line_exists( it_model[ path = lv_row_path ] ).
          DATA(lv_found) = abap_false.
          LOOP AT it_model INTO DATA(ls_model) WHERE path CP lv_pattern. "#EC CI_SORTSEQ
            lv_found = abap_true.
            EXIT.
          ENDLOOP.
          IF lv_found = abap_false.
            EXIT.
          ENDIF.
        ENDIF.
        " the relative bindings of the template, {COL}, from this row
        DATA(lv_copy) = lv_template.
        LOOP AT it_model INTO ls_model WHERE path CP lv_pattern. "#EC CI_SORTSEQ
          DATA(lv_col) = substring( val = ls_model-path
                                    off = strlen( lv_prefix ) ).
          REPLACE ALL OCCURRENCES OF |\{{ lv_col }\}| IN lv_copy WITH xml_escape( ls_model-value ).
        ENDLOOP.
        lv_out = lv_out && lv_copy.
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
    LOOP AT it_model INTO ls_model.
      REPLACE ALL OCCURRENCES OF |\{/{ ls_model-path }\}| IN lv_content WITH xml_escape( ls_model-value ).
    ENDLOOP.

    result-content = lv_content.

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
    DATA lt_model TYPE SORTED TABLE OF ty_s_model WITH UNIQUE KEY path.
    DATA lt_values TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_row TYPE ty_s_row.
    DATA lv_id TYPE c LENGTH 32.
    DATA lv_main TYPE string.
    DATA lv_popup TYPE string.
    DATA lv_first TYPE i VALUE 1.

    " the model the client held is rebuilt from the last 30 recordings - the
    " responses push what changed, the requests carry what the user typed
    IF lines( it_id ) > 30.
      lv_first = lines( it_id ) - 29.
    ENDIF.

    TRY.
        LOOP AT it_id INTO DATA(lv_rec) FROM lv_first.
          DATA(lv_index) = sy-tabix.
          lv_id = lv_rec.
          CLEAR ls_row.
          SELECT SINGLE id, req_body, res_body FROM z2ui5_t_ck_wir
            WHERE id = @lv_id
            INTO CORRESPONDING FIELDS OF @ls_row.
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.

          LOOP AT input_of( ls_row-req_body ) INTO DATA(ls_input).
            IF ls_input-path CP `event argument*`.
              CONTINUE.
            ENDIF.
            INSERT VALUE #( path  = ls_input-path
                            value = ls_input-value ) INTO TABLE lt_model.
            IF sy-subrc <> 0.
              lt_model[ path = ls_input-path ]-value = ls_input-value.
            ENDIF.
          ENDLOOP.

          DATA(lv_model_at) = find( val = ls_row-res_body
                                    sub = `,"MODEL":` ).
          IF lv_model_at > 0.
            DATA(lv_model) = substring( val = ls_row-res_body
                                        off = lv_model_at + 9
                                        len = strlen( ls_row-res_body ) - lv_model_at - 10 ).
            TRY.
                lt_values = json_flatten( lv_model ).
              CATCH cx_root.
                CLEAR lt_values.
            ENDTRY.
            LOOP AT lt_values INTO DATA(ls_value).
              INSERT VALUE #( path  = ls_value-path
                              value = ls_value-value ) INTO TABLE lt_model.
              IF sy-subrc <> 0.
                lt_model[ path = ls_value-path ]-value = ls_value-value.
              ENDIF.
            ENDLOOP.
          ENDIF.

          CLEAR lv_popup.
          LOOP AT views_of( ls_row-res_body ) INTO DATA(ls_view).
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
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.

    IF lv_main IS INITIAL.
      result-error = `No recorded response up to this step displayed a view - the recording began later.`.
      RETURN.
    ENDIF.

    CLEAR lt_values.
    LOOP AT lt_model INTO DATA(ls_model).
      APPEND VALUE #( path  = ls_model-path
                      value = ls_model-value ) TO lt_values.
    ENDLOOP.
    " a popup on top takes the click - the screen below it cannot
    IF lv_popup IS INITIAL.
      result = screen_of( xml      = lv_main
                          it_model = lt_values
                          event    = event ).
    ELSE.
      result = screen_of( xml      = lv_main
                          it_model = lt_values ).
      DATA(ls_popup) = screen_of( xml      = lv_popup
                                  it_model = lt_values
                                  event    = event ).
      result-marked      = ls_popup-marked.
      result-popup       = ls_popup-content.
      result-popup_title = ls_popup-title.
      " a prefix declared twice on one element breaks the XML
      SPLIT ls_popup-xmlns AT ` xmlns` INTO TABLE DATA(lt_ns).
      LOOP AT lt_ns INTO DATA(lv_ns) WHERE table_line IS NOT INITIAL.
        DATA(lv_declared) = | xmlns{ substring_before( val = lv_ns
                                                       sub = `=` ) }=|.
        IF find( val = result-xmlns
                 sub = lv_declared ) < 0.
          result-xmlns = |{ result-xmlns } xmlns{ lv_ns }|.
        ENDIF.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD popup_parts.

    DATA lt_name TYPE string_table.

    CLEAR content.
    CLEAR buttons.
    DATA(lv_open) = find( val = popup
                          sub = `>` ).
    DATA(lv_close) = find( val = popup
                           sub = `</`
                           occ = -1 ).
    IF lv_open < 0 OR lv_close <= lv_open.
      RETURN.
    ENDIF.
    DATA(lv_rest) = substring( val = popup
                               off = lv_open + 1
                               len = lv_close - lv_open - 1 ).

    lt_name = VALUE #( ( `buttons` ) ( `beginButton` ) ( `endButton` ) ).
    LOOP AT lt_name INTO DATA(lv_name).
      DATA(lv_from) = find( val = lv_rest
                            sub = |<{ lv_name }>| ).
      DATA(lv_to) = find( val = lv_rest
                          sub = |</{ lv_name }>| ).
      IF lv_from < 0 OR lv_to < lv_from.
        CONTINUE.
      ENDIF.
      DATA(lv_len) = strlen( lv_name ) + 2.
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
    DATA lt_by_draft TYPE HASHED TABLE OF ty_s_by_draft WITH UNIQUE KEY draft_id.
    DATA lt_parent TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lt_succeeded TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lt_fail TYPE SORTED TABLE OF ty_s_fail WITH NON-UNIQUE KEY draft_id_prev timestampl.
    DATA lt_users TYPE HASHED TABLE OF ty_s_user WITH UNIQUE KEY path user.
    DATA lt_run TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA lt_token TYPE STANDARD TABLE OF ty_s_token WITH EMPTY KEY.
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

    LOOP AT it_record INTO ls_record.
      lv_index = sy-tabix.
      IF ls_record-draft_id IS NOT INITIAL.
        INSERT VALUE #( draft_id = ls_record-draft_id
                        index    = lv_index ) INTO TABLE lt_by_draft.
      ENDIF.
      IF ls_record-draft_id_prev IS NOT INITIAL.
        INSERT ls_record-draft_id_prev INTO TABLE lt_parent.
        IF ls_record-draft_id IS NOT INITIAL.
          INSERT ls_record-draft_id_prev INTO TABLE lt_succeeded.
        ELSE.
          INSERT VALUE #( draft_id_prev = ls_record-draft_id_prev
                          timestampl    = ls_record-timestampl
                          event         = ls_record-event ) INTO TABLE lt_fail.
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
      lv_check_leaf = xsdbool( sy-subrc <> 0 ).
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
          LOOP AT lt_fail INTO DATA(ls_fail) WHERE draft_id_prev = ls_on-draft_id_prev.
            IF ls_fail-timestampl < ls_on-timestampl.
              APPEND VALUE #( app  = lv_screen_app
                              text = |{ COND #( WHEN ls_fail-event IS INITIAL THEN `(start)`
                                                ELSE ls_fail-event ) } (failed)| ) TO lt_token.
            ENDIF.
          ENDLOOP.
        ENDIF.
        lv_text = COND #( WHEN ls_on-event IS INITIAL THEN `(start)` ELSE ls_on-event ).
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
          READ TABLE lt_token ASSIGNING FIELD-SYMBOL(<token>) INDEX lv_last.
          IF <token>-app = lv_screen_app AND ( <token>-text = lv_text OR <token>-text = |{ lv_text } (repeated)| ).
            <token>-text = |{ lv_text } (repeated)|.
            lv_check_repeated = abap_true.
          ENDIF.
        ENDIF.
        IF lv_check_repeated = abap_false.
          APPEND VALUE #( app  = lv_screen_app
                          text = lv_text ) TO lt_token.
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
          APPEND VALUE #( app = lv_answered ) TO lt_token.
        ENDIF.
      ENDIF.
      IF app IS NOT INITIAL AND lv_check_app = abap_false.
        CONTINUE.
      ENDIF.

      CLEAR lv_path.
      CLEAR lv_app.
      LOOP AT lt_token INTO DATA(ls_token).
        IF sy-tabix > 30.
          lv_path = |{ lv_path } -> ... ({ lines( lt_token ) - 30 } more)|.
          EXIT.
        ENDIF.
        IF ls_token-app <> lv_app.
          lv_path = |{ lv_path }{ COND #( WHEN lv_path IS NOT INITIAL THEN ` => ` ) }{ ls_token-app }| &&
                    |{ COND #( WHEN ls_token-text IS NOT INITIAL THEN |: { ls_token-text }| ) }|.
          lv_app = ls_token-app.
        ELSE.
          lv_path = |{ lv_path } -> { ls_token-text }|.
        ENDIF.
      ENDLOOP.

      lv_total = lv_total + 1.
      READ TABLE result ASSIGNING FIELD-SYMBOL(<variant>) WITH KEY path = lv_path. "#EC CI_SORTSEQ
      IF sy-subrc <> 0.
        APPEND VALUE #( path  = lv_path
                        steps = lines( lt_run ) ) TO result ASSIGNING <variant>.
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
        <variant>-example = COND #( WHEN ls_record-draft_id IS NOT INITIAL THEN ls_record-draft_id
                                    ELSE ls_record-draft_id_prev ).
      ENDIF.
      READ TABLE lt_run INTO lv_at INDEX 1.
      READ TABLE it_record INTO ls_on INDEX lv_at.
      IF ls_on-user IS NOT INITIAL.
        INSERT VALUE #( path = lv_path
                        user = ls_on-user ) INTO TABLE lt_users.
        IF sy-subrc = 0.
          <variant>-users = <variant>-users + 1.
        ENDIF.
      ENDIF.
    ENDLOOP.

    LOOP AT result ASSIGNING <variant>.
      <variant>-share = |{ <variant>-runs * 100 / lv_total } %|.
      <variant>-state = COND #( WHEN <variant>-failed > 0 THEN `Error`
                                WHEN <variant>-path CS `(failed)` THEN `Warning`
                                ELSE `None` ).
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
    DATA lt_rows TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.
    DATA lt_record TYPE ty_t_record.
    DATA lv_from TYPE c LENGTH 8.

    lv_from = z2ui5_cl_cockpit_setup=>day_minus( days - 1 ).
    TRY.
        " no body - ids, app and event are columns of their own
        SELECT id, timestampl, app, event, uname, user_key, draft_id, draft_id_prev, http_status
          FROM z2ui5_t_ck_wir
          WHERE utc_day >= @lv_from
          ORDER BY timestampl DESCENDING
          INTO CORRESPONDING FIELDS OF TABLE @lt_rows
          UP TO 20000 ROWS.
      CATCH cx_root INTO DATA(lx).
        result-error = lx->get_text( ).
        RETURN.
    ENDTRY.
    result-records = lines( lt_rows ).
    result-check_capped = xsdbool( result-records >= 20000 ).

    LOOP AT lt_rows INTO DATA(ls_row).
      APPEND VALUE #( id            = ls_row-id
                      timestampl    = ls_row-timestampl
                      app           = ls_row-app
                      event         = ls_row-event
                      draft_id      = ls_row-draft_id
                      draft_id_prev = ls_row-draft_id_prev
                      http_status   = ls_row-http_status
                      user          = COND #( WHEN ls_row-uname IS NOT INITIAL THEN ls_row-uname
                                              ELSE ls_row-user_key ) ) TO lt_record.
    ENDLOOP.
    result-t_variant = variants_of( it_record = lt_record
                                    app       = app ).
    LOOP AT result-t_variant INTO DATA(ls_variant).
      result-runs = result-runs + ls_variant-runs.
      result-failed_runs = result-failed_runs + ls_variant-failed.
    ENDLOOP.

  ENDMETHOD.

  METHOD mark_pressed.

    DATA(lv_wire) = |['{ event }'|.
    DATA(lv_at) = find( val = xml
                        sub = lv_wire ).
    IF lv_at < 0.
      RETURN.
    ENDIF.
    " the element around it: the last < before, the first > after
    DATA(lv_open) = find( val = substring( val = xml
                                           len = lv_at )
                          sub = `<`
                          occ = -1 ).
    DATA(lv_close) = find( val = xml
                           sub = `>`
                           off = lv_at ).
    DATA(lv_name_end) = find( val = xml
                              sub = ` `
                              off = lv_open ).
    IF lv_open < 0 OR lv_close < 0 OR lv_name_end < 0 OR lv_name_end > lv_close.
      RETURN.
    ENDIF.
    DATA(lv_tag) = substring( val = xml
                              off = lv_open
                              len = lv_close - lv_open ).
    DATA(lv_class) = find( val = lv_tag
                           sub = ` class="` ).
    IF lv_class >= 0.
      DATA(lv_insert) = lv_open + lv_class + 8.
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

    result = val.
    REPLACE ALL OCCURRENCES OF `&` IN result WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN result WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN result WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF `"` IN result WITH `&quot;`.
    " a brace would be read as a binding by UI5
    REPLACE ALL OCCURRENCES OF `{` IN result WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN result WITH `\}`.

  ENDMETHOD.

  METHOD shown_text.

    LOOP AT it_shown INTO DATA(ls_shown).
      IF ls_shown-kind = cs_kind-view.
        CONTINUE.
      ENDIF.
      result = |{ result }{ COND #( WHEN result IS NOT INITIAL THEN `; ` ) }| &&
               |{ SWITCH string( ls_shown-kind
                                 WHEN cs_kind-box     THEN |{ ls_shown-type } box|
                                 WHEN cs_kind-toast   THEN `toast`
                                 WHEN cs_kind-popup   THEN `popup`
                                 ELSE `popover` ) }: { ls_shown-text }|.
    ENDLOOP.

  ENDMETHOD.

  METHOD member_before.

    DATA(lv_key) = |"{ name }":"|.
    DATA(lv_off) = find( val = json
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

    DATA(lv_key) = | { name }="|.
    DATA(lv_off) = find( val = xml
                         sub = lv_key ).
    IF lv_off < 0.
      RETURN.
    ENDIF.
    result = substring( val = xml
                        off = lv_off + strlen( lv_key ) ).
    IF result CS `"`.
      result = substring_before( val = result
                                 sub = `"` ).
    ENDIF.
    result = z2ui5_cl_cockpit_session=>decode( result ).

  ENDMETHOD.

  METHOD to_utf8.

    DATA lo_conv TYPE REF TO object.
    DATA lv_class TYPE c LENGTH 30.

    " by name, as in z2ui5_cl_cockpit_session=>to_base64
    TRY.
        lv_class = `CL_ABAP_CONV_CODEPAGE`.
        CALL METHOD (lv_class)=>create_out
          RECEIVING
            instance = lo_conv.
        CALL METHOD lo_conv->(`IF_ABAP_CONV_OUT~CONVERT`)
          EXPORTING
            source = val
          RECEIVING
            result = result.
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
                buffer = result.
          CATCH cx_root.
            CLEAR result.
        ENDTRY.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
