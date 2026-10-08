CLASS ltcl_wire DEFINITION DEFERRED.
CLASS ltcl_wire_db DEFINITION DEFERRED.
CLASS z2ui5_cl_cockpit_wire DEFINITION LOCAL FRIENDS ltcl_wire ltcl_wire_db.

"! Request and response taken apart - nothing is read from the database.
CLASS ltcl_wire DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    METHODS response
      RETURNING
        VALUE(result) TYPE string.

    METHODS request
      RETURNING
        VALUE(result) TYPE string.

    METHODS flatten_json FOR TESTING RAISING cx_static_check.
    METHODS shown_by_response FOR TESTING.
    METHODS input_of_request FOR TESTING.
    METHODS views_of_response FOR TESTING.
    METHODS row_of_bodies FOR TESTING RAISING cx_static_check.
    METHODS no_json FOR TESTING.
    METHODS control_pressed FOR TESTING.
    METHODS control_of_field FOR TESTING.
    METHODS screen_rebuilt FOR TESTING RAISING cx_static_check.
    METHODS popup_taken_apart FOR TESTING RAISING cx_static_check.
    METHODS pressed_marked FOR TESTING RAISING cx_static_check.
    METHODS escaped_once FOR TESTING RAISING cx_static_check.
    METHODS roundtrip_from_bodies FOR TESTING RAISING cx_static_check.
    METHODS roundtrip_failed FOR TESTING RAISING cx_static_check.
    METHODS milliseconds FOR TESTING RAISING cx_static_check.
    METHODS variants_counted FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_wire IMPLEMENTATION.

  METHOD response.

    " the shape z2ui5_cl_ui5_handler writes: id and app first, then the
    " action queues, then the model
    result = `{"S_FRONT":{"ID":"ZZCKUTW2","APP":"ZCL_ORDER","PROTOCOL":2,"S_ACTION":{` &&
             `"T_SYSTEM":[["VIEW_SLOTS","display","MAIN","<mvc:View><Page title=\"Orders\"/></mvc:View>"],` &&
             `["VIEW_SLOTS","display","POPUP","<Dialog title=\"Confirm &amp; save\"/>"]],` &&
             `"T_CUSTOM":[["MESSAGE_BOX","error","Order 4711 is locked by USER2",{"title":"Locked"}],` &&
             `["MESSAGE_TOAST","show","Saved"]]}},"MODEL":{"MS_HEAD":{"QTY":"0"},"ID":"not the draft"}}`.

  ENDMETHOD.

  METHOD request.

    result = `{"S_FRONT":{"ID":"ZZCKUTW1","EVENT":"SAVE","T_EVENT_ARG":["4711"]},` &&
             `"MODEL":{"MS_HEAD":{"QTY":"0"},"MV_NOTE":"urgent"}}`.

  ENDMETHOD.

  METHOD flatten_json.

    DATA(lt_value) = z2ui5_cl_cockpit_wire=>json_flatten( response( ) ).

    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUTW2`
                                        act = lt_value[ path = `S_FRONT/ID` ]-value ).
    cl_abap_unit_assert=>assert_equals( exp = `MESSAGE_BOX`
                                        act = lt_value[ path = `S_FRONT/S_ACTION/T_CUSTOM/1/1` ]-value ).
    cl_abap_unit_assert=>assert_equals( exp = `Locked`
                                        act = lt_value[ path = `S_FRONT/S_ACTION/T_CUSTOM/1/4/title` ]-value ).
    cl_abap_unit_assert=>assert_equals( exp = `0`
                                        act = lt_value[ path = `MODEL/MS_HEAD/QTY` ]-value ).

  ENDMETHOD.

  METHOD shown_by_response.

    cl_abap_unit_assert=>assert_equals(
        exp = VALUE z2ui5_cl_cockpit_wire=>ty_t_shown(
                  ( kind = z2ui5_cl_cockpit_wire=>cs_kind-view  type = `` text = `Orders` )
                  ( kind = z2ui5_cl_cockpit_wire=>cs_kind-popup type = `` text = `Confirm & save` )
                  ( kind = z2ui5_cl_cockpit_wire=>cs_kind-box   type = `error` text = `Order 4711 is locked by USER2` )
                  ( kind = z2ui5_cl_cockpit_wire=>cs_kind-toast type = `` text = `Saved` ) )
        act = z2ui5_cl_cockpit_wire=>shown_of( response( ) ) ).

    cl_abap_unit_assert=>assert_equals(
        exp = `popup: Confirm & save; error box: Order 4711 is locked by USER2; toast: Saved`
        act = z2ui5_cl_cockpit_wire=>shown_text( z2ui5_cl_cockpit_wire=>shown_of( response( ) ) ) ).

  ENDMETHOD.

  METHOD input_of_request.

    cl_abap_unit_assert=>assert_equals(
        exp = VALUE z2ui5_cl_cockpit_session=>ty_t_value( ( path = `event argument 1` value = `4711` )
                                                          ( path = `MS_HEAD/QTY` value = `0` )
                                                          ( path = `MV_NOTE` value = `urgent` ) )
        act = z2ui5_cl_cockpit_wire=>input_of( request( ) ) ).

  ENDMETHOD.

  METHOD views_of_response.

    DATA(lt_view) = z2ui5_cl_cockpit_wire=>views_of( response( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_view ) ).
    cl_abap_unit_assert=>assert_equals( exp = `MAIN`
                                        act = lt_view[ 1 ]-n ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*<Page title="Orders"/>*`
                                         act = lt_view[ 1 ]-v ).
    cl_abap_unit_assert=>assert_equals( exp = `POPUP`
                                        act = lt_view[ 2 ]-n ).

  ENDMETHOD.

  METHOD row_of_bodies.

    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-name.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).

    DATA(ls_row) = z2ui5_cl_cockpit_wire=>row_of( request      = request( )
                                                 response     = response( )
                                                 http_status  = 200
                                                 check_sticky = abap_false ).
    z2ui5_cl_cockpit_setup=>reset_buffer( ).

    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUTW2`
                                        act = ls_row-draft_id ).
    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUTW1`
                                        act = ls_row-draft_id_prev ).
    cl_abap_unit_assert=>assert_equals( exp = `ZCL_ORDER`
                                        act = ls_row-app ).
    cl_abap_unit_assert=>assert_equals( exp = `SAVE`
                                        act = ls_row-event ).
    cl_abap_unit_assert=>assert_equals( exp = request( )
                                        act = ls_row-req_body ).
    cl_abap_unit_assert=>assert_equals( exp = response( )
                                        act = ls_row-res_body ).
    cl_abap_unit_assert=>assert_equals( exp = sy-uname
                                        act = ls_row-uname ).

  ENDMETHOD.

  METHOD control_pressed.

    DATA(lv_xml) = `<mvc:View xmlns="sap.m" xmlns:mvc="sap.ui.core.mvc"><Page title="Orders">` &&
                   `<Button text="Save" type="Emphasized" press=".eB(['SAVE'])"/>` &&
                   `<Button icon="sap-icon://delete" press=".eB(['DELETE'],'$&#123;ID&#125;')"/>` &&
                   `</Page></mvc:View>`.

    cl_abap_unit_assert=>assert_equals( exp = `Button "Save"`
                                        act = z2ui5_cl_cockpit_wire=>control_of( xml   = lv_xml
                                                                                 event = `SAVE` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Button "delete"`
                                        act = z2ui5_cl_cockpit_wire=>control_of( xml   = lv_xml
                                                                                 event = `DELETE` ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_wire=>control_of( xml   = lv_xml
                                                                           event = `NOPE` ) ).

  ENDMETHOD.

  METHOD control_of_field.

    DATA(lv_xml) = `<form:SimpleForm><form:content><Label text="Quantity"/><Input value="{/MS_HEAD/QTY}"/>` &&
                   `<Label text="Date"/><DatePicker value="{path:'/MS_HEAD/DATE',type:'x'}"/>` &&
                   `</form:content></form:SimpleForm>`.

    cl_abap_unit_assert=>assert_equals( exp = `Input "Quantity"`
                                        act = z2ui5_cl_cockpit_wire=>field_control_of( xml  = lv_xml
                                                                                       path = `MS_HEAD/QTY` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `DatePicker "Date"`
                                        act = z2ui5_cl_cockpit_wire=>field_control_of( xml  = lv_xml
                                                                                       path = `MS_HEAD/DATE` ) ).

  ENDMETHOD.

  METHOD screen_rebuilt.

    DATA(lv_xml) = `<mvc:View xmlns="sap.m" xmlns:mvc="sap.ui.core.mvc" displayBlock="true">` &&
                   `<Page title="Orders"><Input value="{/QTY}"/>` &&
                   `<Button text="Save" press=".eB(['SAVE'])"/>` &&
                   `<Table items="{/MT_ITEM}"><items><ColumnListItem><cells><Text text="{MATNR}"/></cells>` &&
                   `</ColumnListItem></items></Table></Page></mvc:View>`.
    DATA(lt_model) = z2ui5_cl_cockpit_wire=>json_flatten(
                         `{"QTY":"0","MT_ITEM":[{"MATNR":"M1"},{"MATNR":"M<2>"}]}` ).

    DATA(ls_screen) = z2ui5_cl_cockpit_wire=>screen_of( xml      = lv_xml
                                                       it_model = lt_model ).

    cl_abap_unit_assert=>assert_initial( ls_screen-error ).
    cl_abap_unit_assert=>assert_equals( exp = ` xmlns="sap.m" xmlns:mvc="sap.ui.core.mvc"`
                                        act = ls_screen-xmlns ).
    cl_abap_unit_assert=>assert_equals( exp = `Orders`
                                        act = ls_screen-title ).
    cl_abap_unit_assert=>assert_equals(
        exp = `<Page title="Orders"><Input value="0"/><Button text="Save" press=""/>` &&
              `<Table><items><ColumnListItem><cells><Text text="M1"/></cells></ColumnListItem>` &&
              `<ColumnListItem><cells><Text text="M&lt;2&gt;"/></cells></ColumnListItem></items></Table></Page>`
        act = ls_screen-content ).

  ENDMETHOD.

  METHOD roundtrip_from_bodies.

    DATA(ls_roundtrip) = z2ui5_cl_cockpit_wire=>roundtrip_of(
        request     = `{"value":{"S_FRONT":{"ID":"OLD","EVENT":"SAVE","MS_CLIENT_PREV":420},"MODEL":{}}}`
        response    = `{"S_FRONT":{"ID":"NEW","APP":"zcl_app","PROTOCOL":2},"MODEL":{"QTY":"5"}}`
        http_status = 200 ).

    cl_abap_unit_assert=>assert_equals( exp = `ZCL_APP`
                                        act = ls_roundtrip-app ).
    cl_abap_unit_assert=>assert_equals( exp = `SAVE`
                                        act = ls_roundtrip-event ).
    cl_abap_unit_assert=>assert_equals( exp = `NEW`
                                        act = ls_roundtrip-draft_id ).
    cl_abap_unit_assert=>assert_equals( exp = `OLD`
                                        act = ls_roundtrip-draft_id_prev ).
    cl_abap_unit_assert=>assert_equals( exp = 420
                                        act = ls_roundtrip-ms_client_prev ).
    cl_abap_unit_assert=>assert_false( ls_roundtrip-check_start ).
    cl_abap_unit_assert=>assert_false( ls_roundtrip-check_error ).
    cl_abap_unit_assert=>assert_equals( exp = strlen( `{"QTY":"5"}` )
                                        act = ls_roundtrip-bytes_model ).
    cl_abap_unit_assert=>assert_equals( exp = 73
                                        act = ls_roundtrip-bytes_response ).

    " the first request of an app start carries no draft
    ls_roundtrip = z2ui5_cl_cockpit_wire=>roundtrip_of(
        request     = `{"S_FRONT":{"EVENT":""}}`
        response    = `{"S_FRONT":{"ID":"FIRST","APP":"ZCL_APP","PROTOCOL":2},"MODEL":{}}`
        http_status = 200 ).
    cl_abap_unit_assert=>assert_true( ls_roundtrip-check_start ).

  ENDMETHOD.

  METHOD roundtrip_failed.

    DATA(lv_nl) = cl_abap_char_utilities=>newline.
    DATA(lv_body) = |abap2UI5 1.146.0 - unhandled exception in a POST request{ lv_nl }{ lv_nl }| &&
                    |--- error ---{ lv_nl }Division by zero{ lv_nl }{ lv_nl }--- exception chain ---{ lv_nl }| &&
                    |[1] Z2UI5_CX_UI5_UTIL_ERROR{ lv_nl }    Division by zero{ lv_nl }| &&
                    |[2] CX_SY_ZERODIVIDE{ lv_nl }    Division by zero{ lv_nl }|.

    DATA(ls_roundtrip) = z2ui5_cl_cockpit_wire=>roundtrip_of(
        request     = `{"S_FRONT":{"ID":"OLD","EVENT":"CALC"}}`
        response    = lv_body
        http_status = 500 ).

    cl_abap_unit_assert=>assert_true( ls_roundtrip-check_error ).
    " the root cause - the last of the chain
    cl_abap_unit_assert=>assert_equals( exp = `CX_SY_ZERODIVIDE`
                                        act = ls_roundtrip-error_class ).
    cl_abap_unit_assert=>assert_equals( exp = lv_body
                                        act = ls_roundtrip-error_text ).
    cl_abap_unit_assert=>assert_equals( exp = `CALC`
                                        act = ls_roundtrip-event ).
    " no app in a 500 body - run( ) takes it from the draft it started from
    cl_abap_unit_assert=>assert_initial( ls_roundtrip-app ).
    cl_abap_unit_assert=>assert_initial( ls_roundtrip-draft_id ).

    " details hidden by the exit: no chain, no class
    ls_roundtrip = z2ui5_cl_cockpit_wire=>roundtrip_of( request     = `{"S_FRONT":{"ID":"OLD"}}`
                                                        response    = `Internal Server Error`
                                                        http_status = 500 ).
    cl_abap_unit_assert=>assert_initial( ls_roundtrip-error_class ).

  ENDMETHOD.

  METHOD milliseconds.

    cl_abap_unit_assert=>assert_equals(
        exp = 1250
        act = z2ui5_cl_cockpit_wire=>ms_between( ts_from = '20261008235959.5000000'
                                                 ts_to   = '20261009000000.7500000' ) ).
    " fractions a double holds exactly: the transpiled runtime computes the
    " packed time stamp as a JS number, about 4 ms apart at this size - the
    " system is exact
    cl_abap_unit_assert=>assert_equals(
        exp = 125
        act = z2ui5_cl_cockpit_wire=>ms_between( ts_from = '20261008120000.1250000'
                                                 ts_to   = '20261008120000.2500000' ) ).
    " never negative
    cl_abap_unit_assert=>assert_equals(
        exp = 0
        act = z2ui5_cl_cockpit_wire=>ms_between( ts_from = '20261008120001'
                                                 ts_to   = '20261008120000' ) ).

  ENDMETHOD.

  METHOD escaped_once.

    " the CSS of the playback goes into an attribute escaped once: a brace
    " that arrives as \\{ is read by UI5 as a backslash and a binding - the
    " Screen popup failed with "Expected ',' instead of 'p'" (3px)
    cl_abap_unit_assert=>assert_equals(
        exp = `&lt;div&gt;&lt;style&gt;.ckPressed \{outline: 3px solid #e9730c !important; outline-offset: 2px; ` &&
              `box-shadow: 0 0 0 6px rgba(233,115,12,0.3) !important;\}&lt;/style&gt;&lt;/div&gt;`
        act = z2ui5_cl_cockpit_wire=>xml_escape( z2ui5_cl_cockpit_wire=>c_pressed_style ) ).

    " a recorded value: the backslash first, then the brace - UI5 shows C:\{x}
    cl_abap_unit_assert=>assert_equals( exp = `C:\\\{x\}`
                                        act = z2ui5_cl_cockpit_wire=>xml_escape( `C:\{x}` ) ).

  ENDMETHOD.

  METHOD pressed_marked.

    DATA(lv_xml) = `<Input value="1"/><Button text="Save" press=".eB(['SAVE'])"/>`.
    cl_abap_unit_assert=>assert_true( z2ui5_cl_cockpit_wire=>mark_pressed( EXPORTING event = `SAVE`
                                                                          CHANGING  xml   = lv_xml ) ).
    cl_abap_unit_assert=>assert_equals( exp = `<Input value="1"/><Button class="ckPressed" text="Save" ` &&
                                              `press=".eB(['SAVE'])"/>`
                                        act = lv_xml ).

    " a class of its own is kept
    lv_xml = `<Button class="sapUiTinyMargin" press=".eB(['GO'])"/>`.
    z2ui5_cl_cockpit_wire=>mark_pressed( EXPORTING event = `GO`
                                         CHANGING  xml   = lv_xml ).
    cl_abap_unit_assert=>assert_equals( exp = `<Button class="ckPressed sapUiTinyMargin" press=".eB(['GO'])"/>`
                                        act = lv_xml ).

    " an event no control raises
    cl_abap_unit_assert=>assert_false( z2ui5_cl_cockpit_wire=>mark_pressed( EXPORTING event = `NONE`
                                                                           CHANGING  xml   = lv_xml ) ).

    " a rebuilt screen: marked before the handler is emptied
    DATA(ls_screen) = z2ui5_cl_cockpit_wire=>screen_of(
                          xml      = `<mvc:View xmlns="sap.m" xmlns:mvc="sap.ui.core.mvc">` &&
                                     `<Button text="Save" press=".eB(['SAVE'])"/></mvc:View>`
                          it_model = VALUE #( )
                          event    = `SAVE` ).
    cl_abap_unit_assert=>assert_true( ls_screen-marked ).
    cl_abap_unit_assert=>assert_equals( exp = `<Button class="ckPressed" text="Save" press=""/>`
                                        act = ls_screen-content ).

  ENDMETHOD.

  METHOD variants_counted.

    DATA lt_record TYPE z2ui5_cl_cockpit_wire=>ty_t_record.

    " every component written out: the 702 downport the unit build runs
    " before transpiling carries an omitted component over from the row
    " before (abap2UI5 backlog abaplint-downport-value-row-not-cleared,
    " fixed in abaplint 2.120.70)
    lt_record = VALUE #(
    " run 1: a failed save, tried again from the same screen
      ( id = `1` timestampl = '20261008100001' app = `ZAPP` event = `` draft_id = `A1`
        draft_id_prev = `` http_status = 0 user = `U1` )
      ( id = `2` timestampl = '20261008100002' app = `ZAPP` event = `CREATE` draft_id = `A2`
        draft_id_prev = `A1` http_status = 0 user = `U1` )
      ( id = `3` timestampl = '20261008100003' app = `` event = `SAVE` draft_id = ``
        draft_id_prev = `A2` http_status = 500 user = `U1` )
      ( id = `4` timestampl = '20261008100004' app = `ZAPP` event = `SAVE` draft_id = `A3`
        draft_id_prev = `A2` http_status = 0 user = `U1` )
    " run 2: the failed save is where it ended
      ( id = `5` timestampl = '20261008100005' app = `ZAPP` event = `` draft_id = `B1`
        draft_id_prev = `` http_status = 0 user = `U2` )
      ( id = `6` timestampl = '20261008100006' app = `ZAPP` event = `CREATE` draft_id = `B2`
        draft_id_prev = `B1` http_status = 0 user = `U2` )
      ( id = `7` timestampl = '20261008100007' app = `` event = `SAVE` draft_id = ``
        draft_id_prev = `B2` http_status = 500 user = `U2` )
    " runs 3 and 4: paging, the same way twice, into another app
      ( id = `8` timestampl = '20261008100008' app = `ZAPP` event = `` draft_id = `C1`
        draft_id_prev = `` http_status = 0 user = `U1` )
      ( id = `9` timestampl = '20261008100009' app = `ZAPP` event = `NEXT` draft_id = `C2`
        draft_id_prev = `C1` http_status = 0 user = `U1` )
      ( id = `10` timestampl = '20261008100010' app = `ZAPP` event = `NEXT` draft_id = `C3`
        draft_id_prev = `C2` http_status = 0 user = `U1` )
      ( id = `11` timestampl = '20261008100011' app = `ZOTHER` event = `GO` draft_id = `C4`
        draft_id_prev = `C3` http_status = 0 user = `U1` )
      ( id = `12` timestampl = '20261008100012' app = `ZAPP` event = `` draft_id = `D1`
        draft_id_prev = `` http_status = 0 user = `U2` )
      ( id = `13` timestampl = '20261008100013' app = `ZAPP` event = `NEXT` draft_id = `D2`
        draft_id_prev = `D1` http_status = 0 user = `U2` )
      ( id = `14` timestampl = '20261008100014' app = `ZAPP` event = `NEXT` draft_id = `D3`
        draft_id_prev = `D2` http_status = 0 user = `U2` )
      ( id = `15` timestampl = '20261008100015' app = `ZOTHER` event = `GO` draft_id = `D4`
        draft_id_prev = `D3` http_status = 0 user = `U2` ) ).

    DATA(lt_variant) = z2ui5_cl_cockpit_wire=>variants_of( lt_record ).

    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( lt_variant ) ).
    " the most frequent first
    cl_abap_unit_assert=>assert_equals( exp = `ZAPP: (start) -> NEXT (repeated) -> GO => ZOTHER`
                                        act = lt_variant[ 1 ]-path ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lt_variant[ 1 ]-runs ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lt_variant[ 1 ]-users ).
    cl_abap_unit_assert=>assert_equals( exp = `D4`
                                        act = lt_variant[ 1 ]-example ).

    DATA(ls_retried) = lt_variant[ path = `ZAPP: (start) -> CREATE -> SAVE (failed) -> SAVE` ].
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = ls_retried-failed ).
    cl_abap_unit_assert=>assert_equals( exp = `Warning`
                                        act = ls_retried-state ).

    DATA(ls_ended) = lt_variant[ path = `ZAPP: (start) -> CREATE -> SAVE (failed)` ].
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_ended-failed ).
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = ls_ended-state ).
    " a failed click wrote no draft - its run opens where it started
    cl_abap_unit_assert=>assert_equals( exp = `B2`
                                        act = ls_ended-example ).

    " only the runs that pass an app
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( z2ui5_cl_cockpit_wire=>variants_of( it_record = lt_record
                                                                                         app       = `ZOTHER` ) ) ).

  ENDMETHOD.

  METHOD popup_taken_apart.

    DATA lv_content TYPE string.
    DATA lv_buttons TYPE string.

    z2ui5_cl_cockpit_wire=>popup_parts(
      EXPORTING
        popup   = `<Dialog title="Delete?"><content><Text text="Really?"/></content>` &&
                  `<beginButton><Button text="Yes" press=""/></beginButton>` &&
                  `<endButton><Button text="No" press=""/></endButton></Dialog>`
      IMPORTING
        content = lv_content
        buttons = lv_buttons ).

    cl_abap_unit_assert=>assert_equals( exp = `<Text text="Really?"/>`
                                        act = lv_content ).
    cl_abap_unit_assert=>assert_equals( exp = `<Button text="Yes" press=""/><Button text="No" press=""/>`
                                        act = lv_buttons ).

    " the default aggregation, no content element written out
    z2ui5_cl_cockpit_wire=>popup_parts(
      EXPORTING
        popup   = `<Popover><List/><buttons><Button text="OK"/></buttons></Popover>`
      IMPORTING
        content = lv_content
        buttons = lv_buttons ).

    cl_abap_unit_assert=>assert_equals( exp = `<List/>`
                                        act = lv_content ).
    cl_abap_unit_assert=>assert_equals( exp = `<Button text="OK"/>`
                                        act = lv_buttons ).

  ENDMETHOD.

  METHOD no_json.

    " a 500 answers with the error text, not with JSON
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_wire=>shown_of( `Internal error - see the log` ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_wire=>input_of( `` ) ).

  ENDMETHOD.

ENDCLASS.


"! The recordings table read for real. Rows are inserted here, never
"! through record_bodies( ), which commits; teardown deletes them.
CLASS ltcl_wire_db DEFINITION FINAL FOR TESTING RISK LEVEL DANGEROUS DURATION SHORT.

  PRIVATE SECTION.

    CONSTANTS c_app TYPE string VALUE `ZZ_COCKPIT_UNIT_TEST`.

    DATA mv_id TYPE string.

    METHODS setup.
    METHODS teardown.

    METHODS records_of_drafts FOR TESTING.
    METHODS detail_taken_apart FOR TESTING.
    METHODS messages_counted FOR TESTING.
    METHODS sticky_waits FOR TESTING.

ENDCLASS.


CLASS ltcl_wire_db IMPLEMENTATION.

  METHOD setup.

    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-name.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).

    DATA(ls_row) = VALUE z2ui5_t_ck_wir(
        id            = `ZZCKUTWIRE1`
        timestampl    = z2ui5_cl_cockpit_setup=>now( )
        utc_day       = z2ui5_cl_cockpit_setup=>day_minus( 0 )
        app           = c_app
        event         = `SAVE`
        uname         = sy-uname
        draft_id      = `ZZCKUTW2`
        draft_id_prev = `ZZCKUTW1`
        http_status   = 200
        req_body      = `{"S_FRONT":{"ID":"ZZCKUTW1","EVENT":"SAVE"},"MODEL":{"QTY":"0"}}`
        res_body      = `{"S_FRONT":{"ID":"ZZCKUTW2","APP":"ZZ_COCKPIT_UNIT_TEST","PROTOCOL":2,"S_ACTION":` &&
                        `{"T_CUSTOM":[["MESSAGE_BOX","error","Quantity must be greater than 0"]]}}}` ).
    INSERT z2ui5_t_ck_wir FROM @ls_row.
    mv_id = ls_row-id.

  ENDMETHOD.

  METHOD teardown.

    DATA(lv_app) = CONV z2ui5_t_ck_wir-app( c_app ).
    DELETE FROM z2ui5_t_ck_wir WHERE app = @lv_app.
    ROLLBACK WORK.                                       "#EC CI_ROLLBACK
    CLEAR z2ui5_cl_cockpit_wire=>gt_buffer.
    z2ui5_cl_cockpit_setup=>reset_buffer( ).

  ENDMETHOD.

  METHOD records_of_drafts.

    " the step it wrote and the step it started from both find it
    DATA(lt_record) = z2ui5_cl_cockpit_wire=>get_records( VALUE #( ( `ZZCKUTW2` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_record ) ).
    cl_abap_unit_assert=>assert_equals( exp = `SAVE`
                                        act = lt_record[ 1 ]-event ).
    lt_record = z2ui5_cl_cockpit_wire=>get_records( VALUE #( ( `ZZCKUTW1` ) ( `ZZCKUTW2` ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_record ) ).

  ENDMETHOD.

  METHOD detail_taken_apart.

    DATA(ls_detail) = z2ui5_cl_cockpit_wire=>get_detail( mv_id ).

    cl_abap_unit_assert=>assert_initial( ls_detail-error ).
    cl_abap_unit_assert=>assert_equals( exp = `error box: Quantity must be greater than 0`
                                        act = ls_detail-shown ).
    cl_abap_unit_assert=>assert_equals( exp = `QTY = 0`
                                        act = ls_detail-input ).
    cl_abap_unit_assert=>assert_char_cp( exp = `{"S_FRONT"*`
                                         act = ls_detail-response ).

    ls_detail = z2ui5_cl_cockpit_wire=>get_detail( `ZZCKUT_GONE` ).
    cl_abap_unit_assert=>assert_not_initial( ls_detail-error ).

  ENDMETHOD.

  METHOD messages_counted.

    DATA lv_found TYPE abap_bool.

    DATA(ls_messages) = z2ui5_cl_cockpit_wire=>get_messages( 1 ).

    cl_abap_unit_assert=>assert_initial( ls_messages-error ).
    LOOP AT ls_messages-t_message INTO DATA(ls_message) WHERE app = c_app. "#EC CI_SORTSEQ
      cl_abap_unit_assert=>assert_equals( exp = `Quantity must be greater than 0`
                                          act = ls_message-text ).
      cl_abap_unit_assert=>assert_equals( exp = `Error`
                                          act = ls_message-state ).
      cl_abap_unit_assert=>assert_equals( exp = 1
                                          act = ls_message-users ).
      lv_found = abap_true.
    ENDLOOP.
    cl_abap_unit_assert=>assert_true( lv_found ).

  ENDMETHOD.

  METHOD sticky_waits.

    " a sticky session's recording stays in the roll area - nothing is
    " written into the app's LUW
    z2ui5_cl_cockpit_wire=>record_bodies( request      = `{"S_FRONT":{"ID":"ZZCKUTW9"}}`
                                          response     = `{"S_FRONT":{"ID":"ZZCKUTW10","APP":"X","PROTOCOL":2}}`
                                          check_sticky = abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( z2ui5_cl_cockpit_wire=>gt_buffer ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_wire=>get_records( VALUE #( ( `ZZCKUTW10` ) ) ) ).

    " recording off: nothing at all
    CLEAR z2ui5_cl_cockpit_wire=>gt_buffer.
    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get( ).
    ls_set-wire_days = 0.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).
    z2ui5_cl_cockpit_wire=>record_bodies( request      = `{"S_FRONT":{"ID":"ZZCKUTW9"}}`
                                          response     = `{}`
                                          check_sticky = abap_true ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_wire=>gt_buffer ).

  ENDMETHOD.

ENDCLASS.
