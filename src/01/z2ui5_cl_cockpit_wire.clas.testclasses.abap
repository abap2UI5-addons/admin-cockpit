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
    METHODS screen_runs_nothing FOR TESTING RAISING cx_static_check.
    METHODS popup_taken_apart FOR TESTING RAISING cx_static_check.
    METHODS pressed_marked FOR TESTING RAISING cx_static_check.
    METHODS escaped_once FOR TESTING RAISING cx_static_check.
    METHODS roundtrip_from_bodies FOR TESTING RAISING cx_static_check.
    METHODS roundtrip_failed FOR TESTING RAISING cx_static_check.
    METHODS milliseconds FOR TESTING RAISING cx_static_check.
    METHODS inputs_before_errors FOR TESTING RAISING cx_static_check.
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

    DATA lt_value TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    FIELD-SYMBOLS <temp1> LIKE LINE OF lt_value.
    DATA temp2 LIKE sy-tabix.
    FIELD-SYMBOLS <temp3> LIKE LINE OF lt_value.
    DATA temp4 LIKE sy-tabix.
    FIELD-SYMBOLS <temp5> LIKE LINE OF lt_value.
    DATA temp6 LIKE sy-tabix.
    FIELD-SYMBOLS <temp7> LIKE LINE OF lt_value.
    DATA temp8 LIKE sy-tabix.
    lt_value = z2ui5_cl_cockpit_wire=>json_flatten( response( ) ).



    temp2 = sy-tabix.
    READ TABLE lt_value WITH KEY path = `S_FRONT/ID` ASSIGNING <temp1>.
    sy-tabix = temp2.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUTW2`
                                        act = <temp1>-value ).


    temp4 = sy-tabix.
    READ TABLE lt_value WITH KEY path = `S_FRONT/S_ACTION/T_CUSTOM/1/1` ASSIGNING <temp3>.
    sy-tabix = temp4.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `MESSAGE_BOX`
                                        act = <temp3>-value ).


    temp6 = sy-tabix.
    READ TABLE lt_value WITH KEY path = `S_FRONT/S_ACTION/T_CUSTOM/1/4/title` ASSIGNING <temp5>.
    sy-tabix = temp6.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Locked`
                                        act = <temp5>-value ).


    temp8 = sy-tabix.
    READ TABLE lt_value WITH KEY path = `MODEL/MS_HEAD/QTY` ASSIGNING <temp7>.
    sy-tabix = temp8.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `0`
                                        act = <temp7>-value ).

  ENDMETHOD.

  METHOD shown_by_response.

    DATA temp9 TYPE z2ui5_cl_cockpit_wire=>ty_t_shown.
    DATA temp10 LIKE LINE OF temp9.
    CLEAR temp9.

    temp10-kind = z2ui5_cl_cockpit_wire=>cs_kind-view.
    temp10-type = ``.
    temp10-text = `Orders`.
    INSERT temp10 INTO TABLE temp9.
    temp10-kind = z2ui5_cl_cockpit_wire=>cs_kind-popup.
    temp10-type = ``.
    temp10-text = `Confirm & save`.
    INSERT temp10 INTO TABLE temp9.
    temp10-kind = z2ui5_cl_cockpit_wire=>cs_kind-box.
    temp10-type = `error`.
    temp10-text = `Order 4711 is locked by USER2`.
    INSERT temp10 INTO TABLE temp9.
    temp10-kind = z2ui5_cl_cockpit_wire=>cs_kind-toast.
    temp10-type = ``.
    temp10-text = `Saved`.
    INSERT temp10 INTO TABLE temp9.
    cl_abap_unit_assert=>assert_equals(
        exp = temp9
        act = z2ui5_cl_cockpit_wire=>shown_of( response( ) ) ).

    cl_abap_unit_assert=>assert_equals(
        exp = `popup: Confirm & save; error box: Order 4711 is locked by USER2; toast: Saved`
        act = z2ui5_cl_cockpit_wire=>shown_text( z2ui5_cl_cockpit_wire=>shown_of( response( ) ) ) ).

  ENDMETHOD.

  METHOD input_of_request.

    DATA temp11 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp12 LIKE LINE OF temp11.
    CLEAR temp11.

    temp12-path = `event argument 1`.
    temp12-value = `4711`.
    INSERT temp12 INTO TABLE temp11.
    temp12-path = `MS_HEAD/QTY`.
    temp12-value = `0`.
    INSERT temp12 INTO TABLE temp11.
    temp12-path = `MV_NOTE`.
    temp12-value = `urgent`.
    INSERT temp12 INTO TABLE temp11.
    cl_abap_unit_assert=>assert_equals(
        exp = temp11
        act = z2ui5_cl_cockpit_wire=>input_of( request( ) ) ).

  ENDMETHOD.

  METHOD views_of_response.

    DATA lt_view TYPE z2ui5_if_client=>ty_t_name_value.
    FIELD-SYMBOLS <temp13> LIKE LINE OF lt_view.
    DATA temp14 LIKE sy-tabix.
    FIELD-SYMBOLS <temp15> LIKE LINE OF lt_view.
    DATA temp16 LIKE sy-tabix.
    FIELD-SYMBOLS <temp17> LIKE LINE OF lt_view.
    DATA temp18 LIKE sy-tabix.
    lt_view = z2ui5_cl_cockpit_wire=>views_of( response( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_view ) ).


    temp14 = sy-tabix.
    READ TABLE lt_view INDEX 1 ASSIGNING <temp13>.
    sy-tabix = temp14.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `MAIN`
                                        act = <temp13>-n ).


    temp16 = sy-tabix.
    READ TABLE lt_view INDEX 1 ASSIGNING <temp15>.
    sy-tabix = temp16.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_char_cp( exp = `*<Page title="Orders"/>*`
                                         act = <temp15>-v ).


    temp18 = sy-tabix.
    READ TABLE lt_view INDEX 2 ASSIGNING <temp17>.
    sy-tabix = temp18.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `POPUP`
                                        act = <temp17>-n ).

  ENDMETHOD.

  METHOD row_of_bodies.

    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA ls_row TYPE z2ui5_t_28.
    ls_set = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-name.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).


    ls_row = z2ui5_cl_cockpit_wire=>row_of( request      = request( )
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

    DATA lv_xml TYPE string.
    lv_xml = `<mvc:View xmlns="sap.m" xmlns:mvc="sap.ui.core.mvc"><Page title="Orders">` &&
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

    DATA lv_xml TYPE string.
    lv_xml = `<form:SimpleForm><form:content><Label text="Quantity"/><Input value="{/MS_HEAD/QTY}"/>` &&
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

    DATA lv_xml TYPE string.
    DATA lt_model TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_screen TYPE z2ui5_cl_cockpit_wire=>ty_s_screen.
    lv_xml = `<mvc:View xmlns="sap.m" xmlns:mvc="sap.ui.core.mvc" displayBlock="true">` &&
                   `<Page title="Orders"><Input value="{/QTY}"/>` &&
                   `<Button text="Save" press=".eB(['SAVE'])"/>` &&
                   `<Table items="{/MT_ITEM}"><items><ColumnListItem><cells><Text text="{MATNR}"/></cells>` &&
                   `</ColumnListItem></items></Table></Page></mvc:View>`.

    lt_model = z2ui5_cl_cockpit_wire=>json_flatten(
                         `{"QTY":"0","MT_ITEM":[{"MATNR":"M1"},{"MATNR":"M<2>"}]}` ).


    ls_screen = z2ui5_cl_cockpit_wire=>screen_of( xml      = lv_xml
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

  METHOD screen_runs_nothing.

    " what would run in the cockpit by itself: the HTML control sanitized,
    " only the elements of the allowed UI5 libraries kept - XHTML, SVG, the
    " framework's helper controls, an addon's custom control, an undeclared
    " prefix and one declared twice are left out
    DATA lv_xml TYPE string.
    DATA lt_model TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_screen TYPE z2ui5_cl_cockpit_wire=>ty_s_screen.
    DATA temp19 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    lv_xml = `<mvc:View xmlns="sap.m" xmlns:mvc="sap.ui.core.mvc" xmlns:core="sap.ui.core" ` &&
                   `xmlns:html="http://www.w3.org/1999/xhtml" xmlns:z2ui5="z2ui5.cc" xmlns:f="sap.ui.layout.form"` &&
                   ` xmlns:cci='z2ui5_cci.cc'` && |\n| && `xmlns:svg = "http://www.w3.org/2000/svg">` &&
                   `<Page title="T"><core:HTML content="{/HTML}" sanitizeContent="false"/>` &&
                   `<core:HTML sanitizeContent='false' content="b"></core:HTML>` &&
                   `<html:div><html:img src="x" onerror="alert(1)"/><html:div><Text text="in"/></html:div></html:div>` &&
                   `<core:Icon src="sap-icon://accept"/>` &&
                   `<z2ui5:Storage type="local" key="k" value="v"/>` &&
                   `<cci:Script src="https://evil.example/x.js"><cci:content><Text text="a > b"/></cci:content></cci:Script>` &&
                   `<svg:svg><svg:script>alert(1)</svg:script></svg:svg>` &&
                   `<x:Thing/><f:SimpleForm><Label text="L"/></f:SimpleForm>` &&
                   `<VBox xmlns:f="third.party.lib"><f:Widget/></VBox>` &&
                   `<!-- <cci:Script/> --><Text text="out"/></Page></mvc:View>`.

    lt_model = z2ui5_cl_cockpit_wire=>json_flatten( `{"HTML":"<img src=x onerror=alert(1)>"}` ).


    ls_screen = z2ui5_cl_cockpit_wire=>screen_of( xml      = lv_xml
                                                       it_model = lt_model ).

    cl_abap_unit_assert=>assert_equals(
        exp = `<Page title="T"><core:HTML sanitizeContent="true" content="&lt;img src=x onerror=alert(1)&gt;"/>` &&
              `<core:HTML sanitizeContent="true" content="b"></core:HTML>` &&
              `<core:Icon src="sap-icon://accept"/>` &&
              `<VBox xmlns:f="third.party.lib"></VBox>` &&
              `<!-- <cci:Script/> --><Text text="out"/></Page>`
        act = ls_screen-content ).

    " a default namespace that is not allowed: its elements are left out
    lv_xml = `<mvc:View xmlns="z2ui5_cci.cc" xmlns:mvc="sap.ui.core.mvc" xmlns:m="sap.m">` &&
             `<m:Text text="kept"/><Script src="x.js"><m:Text text="in"/></Script><Frame/></mvc:View>`.

    CLEAR temp19.
    ls_screen = z2ui5_cl_cockpit_wire=>screen_of( xml      = lv_xml
                                                 it_model = temp19 ).
    cl_abap_unit_assert=>assert_equals( exp = `<m:Text text="kept"/>`
                                        act = ls_screen-content ).

  ENDMETHOD.

  METHOD roundtrip_from_bodies.

    DATA ls_roundtrip TYPE z2ui5_cl_cockpit_rec=>ty_s_roundtrip.
    ls_roundtrip = z2ui5_cl_cockpit_wire=>roundtrip_of(
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

    DATA lv_nl LIKE cl_abap_char_utilities=>newline.
    DATA lv_body TYPE string.
    DATA ls_roundtrip TYPE z2ui5_cl_cockpit_rec=>ty_s_roundtrip.
    lv_nl = cl_abap_char_utilities=>newline.

    lv_body = |abap2UI5 1.146.0 - unhandled exception in a POST request{ lv_nl }{ lv_nl }| &&
                    |--- error ---{ lv_nl }Division by zero{ lv_nl }{ lv_nl }--- exception chain ---{ lv_nl }| &&
                    |[1] Z2UI5_CX_UI5_UTIL_ERROR{ lv_nl }    Division by zero{ lv_nl }| &&
                    |[2] CX_SY_ZERODIVIDE{ lv_nl }    Division by zero{ lv_nl }|.


    ls_roundtrip = z2ui5_cl_cockpit_wire=>roundtrip_of(
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

  METHOD inputs_before_errors.

    DATA lv_box TYPE string.
    DATA lv_ok TYPE string.
    DATA temp20 TYPE z2ui5_cl_cockpit_wire=>ty_t_exchange.
    DATA temp21 LIKE LINE OF temp20.
    DATA lt_input TYPE z2ui5_cl_cockpit_wire=>ty_t_input.
    DATA ls_qty LIKE LINE OF lt_input.
    FIELD-SYMBOLS <temp1> LIKE LINE OF lt_input.
    DATA temp2 LIKE sy-tabix.
    DATA ls_date LIKE LINE OF lt_input.
    FIELD-SYMBOLS <temp3> LIKE LINE OF lt_input.
    DATA temp4 LIKE sy-tabix.
    lv_box = `{"S_FRONT":{"ID":"N","APP":"ZAPP","PROTOCOL":2,"S_ACTION":{"T_CUSTOM":` &&
                   `[["MESSAGE_BOX","error","Date invalid",{}]]}},"MODEL":{}}`.

    lv_ok = `{"S_FRONT":{"ID":"N","APP":"ZAPP","PROTOCOL":2},"MODEL":{}}`.

    " newest first; every component written out - see variants_counted

    CLEAR temp20.

    temp21-app = `ZAPP`.
    temp21-request = `{"S_FRONT":{"ID":"A","EVENT":"SAVE"},"MODEL":{"XX":{"MS_HEAD":{"DATE":"31.02.2026"},` &&
`"MT_ITEM":[{"QTY":"0"}]}}}`.
    temp21-response = lv_box.
    temp21-http_status = 200.
    INSERT temp21 INTO TABLE temp20.
    temp21-app = `ZAPP`.
    temp21-request = `{"S_FRONT":{"ID":"B","EVENT":"SAVE"},"MODEL":{"XX":{"MS_HEAD":{"DATE":"01.03.2026"}}}}`.
    temp21-response = lv_ok.
    temp21-http_status = 200.
    INSERT temp21 INTO TABLE temp20.
    temp21-app = `ZAPP`.
    temp21-request = `{"S_FRONT":{"ID":"C","EVENT":"SAVE"},"MODEL":{"XX":{"MS_HEAD":{"DATE":"30.02."}}}}`.
    temp21-response = lv_box.
    temp21-http_status = 200.
    INSERT temp21 INTO TABLE temp20.
    temp21-app = `ZAPP`.
    temp21-request = `{"S_FRONT":{"ID":"D","EVENT":"SAVE"},"MODEL":{"XX":{"MT_ITEM":[{"QTY":"5"},{"QTY":"x"}]}}}`.
    temp21-response = `Internal Server Error`.
    temp21-http_status = 500.
    INSERT temp21 INTO TABLE temp20.

    lt_input = z2ui5_cl_cockpit_wire=>input_errors_of( temp20 ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_input ) ).

    " the rows of a table are one field - typed three times, failed three times



    temp2 = sy-tabix.
    READ TABLE lt_input INDEX 1 ASSIGNING <temp1>.
    sy-tabix = temp2.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_qty = <temp1>.
    cl_abap_unit_assert=>assert_equals( exp = `MT_ITEM/*/QTY`
                                        act = ls_qty-field ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = ls_qty-errors ).
    cl_abap_unit_assert=>assert_equals( exp = `100 %`
                                        act = ls_qty-rate ).
    " the newest message
    cl_abap_unit_assert=>assert_equals( exp = `Date invalid`
                                        act = ls_qty-message ).




    temp4 = sy-tabix.
    READ TABLE lt_input WITH KEY field = `MS_HEAD/DATE` ASSIGNING <temp3>.
    sy-tabix = temp4.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_date = <temp3>.
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = ls_date-typed ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_date-errors ).
    cl_abap_unit_assert=>assert_equals( exp = `66 %`
                                        act = ls_date-rate ).
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = ls_date-state ).
    " only the values typed when it failed
    cl_abap_unit_assert=>assert_equals( exp = `"31.02.2026", "30.02."`
                                        act = ls_date-samples ).

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

    DATA lv_xml TYPE string.
    DATA temp22 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_screen TYPE z2ui5_cl_cockpit_wire=>ty_s_screen.
    lv_xml = `<Input value="1"/><Button text="Save" press=".eB(['SAVE'])"/>`.
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

    CLEAR temp22.

    ls_screen = z2ui5_cl_cockpit_wire=>screen_of(
                          xml      = `<mvc:View xmlns="sap.m" xmlns:mvc="sap.ui.core.mvc">` &&
                                     `<Button text="Save" press=".eB(['SAVE'])"/></mvc:View>`
                          it_model = temp22
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
    DATA temp23 TYPE z2ui5_cl_cockpit_wire=>ty_t_record.
    DATA temp24 LIKE LINE OF temp23.
    DATA lt_variant TYPE z2ui5_cl_cockpit_wire=>ty_t_variant.
    FIELD-SYMBOLS <temp25> LIKE LINE OF lt_variant.
    DATA temp26 LIKE sy-tabix.
    FIELD-SYMBOLS <temp27> LIKE LINE OF lt_variant.
    DATA temp28 LIKE sy-tabix.
    FIELD-SYMBOLS <temp29> LIKE LINE OF lt_variant.
    DATA temp30 LIKE sy-tabix.
    FIELD-SYMBOLS <temp31> LIKE LINE OF lt_variant.
    DATA temp32 LIKE sy-tabix.
    FIELD-SYMBOLS <temp33> LIKE LINE OF lt_variant.
    DATA temp34 LIKE sy-tabix.
    DATA ls_retried LIKE LINE OF lt_variant.
    FIELD-SYMBOLS <temp5> LIKE LINE OF lt_variant.
    DATA temp6 LIKE sy-tabix.
    DATA ls_ended LIKE LINE OF lt_variant.
    FIELD-SYMBOLS <temp7> LIKE LINE OF lt_variant.
    DATA temp8 LIKE sy-tabix.
    CLEAR temp23.

    temp24-id = `1`.
    temp24-timestampl = '20261008100001'.
    temp24-app = `ZAPP`.
    temp24-event = ``.
    temp24-draft_id = `A1`.
    temp24-draft_id_prev = ``.
    temp24-http_status = 0.
    temp24-user = `U1`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `2`.
    temp24-timestampl = '20261008100002'.
    temp24-app = `ZAPP`.
    temp24-event = `CREATE`.
    temp24-draft_id = `A2`.
    temp24-draft_id_prev = `A1`.
    temp24-http_status = 0.
    temp24-user = `U1`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `3`.
    temp24-timestampl = '20261008100003'.
    temp24-app = ``.
    temp24-event = `SAVE`.
    temp24-draft_id = ``.
    temp24-draft_id_prev = `A2`.
    temp24-http_status = 500.
    temp24-user = `U1`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `4`.
    temp24-timestampl = '20261008100004'.
    temp24-app = `ZAPP`.
    temp24-event = `SAVE`.
    temp24-draft_id = `A3`.
    temp24-draft_id_prev = `A2`.
    temp24-http_status = 0.
    temp24-user = `U1`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `5`.
    temp24-timestampl = '20261008100005'.
    temp24-app = `ZAPP`.
    temp24-event = ``.
    temp24-draft_id = `B1`.
    temp24-draft_id_prev = ``.
    temp24-http_status = 0.
    temp24-user = `U2`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `6`.
    temp24-timestampl = '20261008100006'.
    temp24-app = `ZAPP`.
    temp24-event = `CREATE`.
    temp24-draft_id = `B2`.
    temp24-draft_id_prev = `B1`.
    temp24-http_status = 0.
    temp24-user = `U2`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `7`.
    temp24-timestampl = '20261008100007'.
    temp24-app = ``.
    temp24-event = `SAVE`.
    temp24-draft_id = ``.
    temp24-draft_id_prev = `B2`.
    temp24-http_status = 500.
    temp24-user = `U2`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `8`.
    temp24-timestampl = '20261008100008'.
    temp24-app = `ZAPP`.
    temp24-event = ``.
    temp24-draft_id = `C1`.
    temp24-draft_id_prev = ``.
    temp24-http_status = 0.
    temp24-user = `U1`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `9`.
    temp24-timestampl = '20261008100009'.
    temp24-app = `ZAPP`.
    temp24-event = `NEXT`.
    temp24-draft_id = `C2`.
    temp24-draft_id_prev = `C1`.
    temp24-http_status = 0.
    temp24-user = `U1`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `10`.
    temp24-timestampl = '20261008100010'.
    temp24-app = `ZAPP`.
    temp24-event = `NEXT`.
    temp24-draft_id = `C3`.
    temp24-draft_id_prev = `C2`.
    temp24-http_status = 0.
    temp24-user = `U1`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `11`.
    temp24-timestampl = '20261008100011'.
    temp24-app = `ZOTHER`.
    temp24-event = `GO`.
    temp24-draft_id = `C4`.
    temp24-draft_id_prev = `C3`.
    temp24-http_status = 0.
    temp24-user = `U1`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `12`.
    temp24-timestampl = '20261008100012'.
    temp24-app = `ZAPP`.
    temp24-event = ``.
    temp24-draft_id = `D1`.
    temp24-draft_id_prev = ``.
    temp24-http_status = 0.
    temp24-user = `U2`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `13`.
    temp24-timestampl = '20261008100013'.
    temp24-app = `ZAPP`.
    temp24-event = `NEXT`.
    temp24-draft_id = `D2`.
    temp24-draft_id_prev = `D1`.
    temp24-http_status = 0.
    temp24-user = `U2`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `14`.
    temp24-timestampl = '20261008100014'.
    temp24-app = `ZAPP`.
    temp24-event = `NEXT`.
    temp24-draft_id = `D3`.
    temp24-draft_id_prev = `D2`.
    temp24-http_status = 0.
    temp24-user = `U2`.
    INSERT temp24 INTO TABLE temp23.
    temp24-id = `15`.
    temp24-timestampl = '20261008100015'.
    temp24-app = `ZOTHER`.
    temp24-event = `GO`.
    temp24-draft_id = `D4`.
    temp24-draft_id_prev = `D3`.
    temp24-http_status = 0.
    temp24-user = `U2`.
    INSERT temp24 INTO TABLE temp23.
    lt_record = temp23.


    lt_variant = z2ui5_cl_cockpit_wire=>variants_of( lt_record ).

    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( lt_variant ) ).
    " the most frequent first


    temp26 = sy-tabix.
    READ TABLE lt_variant INDEX 1 ASSIGNING <temp25>.
    sy-tabix = temp26.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ZAPP: (start) -> NEXT (repeated) -> GO => ZOTHER`
                                        act = <temp25>-path ).


    temp28 = sy-tabix.
    READ TABLE lt_variant INDEX 1 ASSIGNING <temp27>.
    sy-tabix = temp28.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = <temp27>-runs ).


    temp30 = sy-tabix.
    READ TABLE lt_variant INDEX 1 ASSIGNING <temp29>.
    sy-tabix = temp30.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = <temp29>-users ).


    temp32 = sy-tabix.
    READ TABLE lt_variant INDEX 1 ASSIGNING <temp31>.
    sy-tabix = temp32.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `D4`
                                        act = <temp31>-example ).
    " 2 of 4 runs


    temp34 = sy-tabix.
    READ TABLE lt_variant INDEX 1 ASSIGNING <temp33>.
    sy-tabix = temp34.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `50 %`
                                        act = <temp33>-share ).




    temp6 = sy-tabix.
    READ TABLE lt_variant WITH KEY path = `ZAPP: (start) -> CREATE -> SAVE (failed) -> SAVE` ASSIGNING <temp5>.
    sy-tabix = temp6.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_retried = <temp5>.
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = ls_retried-failed ).
    cl_abap_unit_assert=>assert_equals( exp = `Warning`
                                        act = ls_retried-state ).




    temp8 = sy-tabix.
    READ TABLE lt_variant WITH KEY path = `ZAPP: (start) -> CREATE -> SAVE (failed)` ASSIGNING <temp7>.
    sy-tabix = temp8.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_ended = <temp7>.
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

    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA temp35 TYPE z2ui5_t_28.
    DATA ls_row LIKE temp35.
    ls_set = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-name.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).


    CLEAR temp35.
    temp35-id = `ZZCKUTWIRE1`.
    temp35-timestampl = z2ui5_cl_cockpit_setup=>now( ).
    temp35-utc_day = z2ui5_cl_cockpit_setup=>day_minus( 0 ).
    temp35-app = c_app.
    temp35-event = `SAVE`.
    temp35-uname = sy-uname.
    temp35-draft_id = `ZZCKUTW2`.
    temp35-draft_id_prev = `ZZCKUTW1`.
    temp35-http_status = 200.
    temp35-req_body = `{"S_FRONT":{"ID":"ZZCKUTW1","EVENT":"SAVE"},"MODEL":{"QTY":"0"}}`.
    temp35-res_body = `{"S_FRONT":{"ID":"ZZCKUTW2","APP":"ZZ_COCKPIT_UNIT_TEST","PROTOCOL":2,"S_ACTION":` && `{"T_CUSTOM":[["MESSAGE_BOX","error","Quantity must be greater than 0"]]}}}`.

    ls_row = temp35.
    INSERT z2ui5_t_28 FROM ls_row.
    mv_id = ls_row-id.

  ENDMETHOD.

  METHOD teardown.

    DATA temp36 TYPE z2ui5_t_28-app.
    DATA lv_app LIKE temp36.
    temp36 = c_app.

    lv_app = temp36.
    DELETE FROM z2ui5_t_28 WHERE app = lv_app.
    ROLLBACK WORK.                                       "#EC CI_ROLLBACK
    CLEAR z2ui5_cl_cockpit_wire=>gt_buffer.
    z2ui5_cl_cockpit_setup=>reset_buffer( ).

  ENDMETHOD.

  METHOD records_of_drafts.

    " the step it wrote and the step it started from both find it
    DATA temp37 TYPE z2ui5_cl_cockpit_session=>ty_t_id.
    DATA lt_record TYPE z2ui5_cl_cockpit_wire=>ty_t_record.
    FIELD-SYMBOLS <temp39> LIKE LINE OF lt_record.
    DATA temp40 LIKE sy-tabix.
    DATA temp41 TYPE z2ui5_cl_cockpit_session=>ty_t_id.
    CLEAR temp37.
    INSERT `ZZCKUTW2` INTO TABLE temp37.

    lt_record = z2ui5_cl_cockpit_wire=>get_records( temp37 ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_record ) ).


    temp40 = sy-tabix.
    READ TABLE lt_record INDEX 1 ASSIGNING <temp39>.
    sy-tabix = temp40.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `SAVE`
                                        act = <temp39>-event ).

    CLEAR temp41.
    INSERT `ZZCKUTW1` INTO TABLE temp41.
    INSERT `ZZCKUTW2` INTO TABLE temp41.
    lt_record = z2ui5_cl_cockpit_wire=>get_records( temp41 ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_record ) ).

  ENDMETHOD.

  METHOD detail_taken_apart.

    DATA ls_detail TYPE z2ui5_cl_cockpit_wire=>ty_s_detail.
    ls_detail = z2ui5_cl_cockpit_wire=>get_detail( mv_id ).

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

    DATA ls_messages TYPE z2ui5_cl_cockpit_wire=>ty_s_messages.
    DATA ls_message LIKE LINE OF ls_messages-t_message.
    ls_messages = z2ui5_cl_cockpit_wire=>get_messages( 1 ).

    cl_abap_unit_assert=>assert_initial( ls_messages-error ).

    LOOP AT ls_messages-t_message INTO ls_message WHERE app = c_app. "#EC CI_SORTSEQ
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
    DATA temp43 TYPE z2ui5_cl_cockpit_session=>ty_t_id.
    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.

    " a sticky session's recording stays in the roll area - nothing is
    " written into the app's LUW
    z2ui5_cl_cockpit_wire=>record_bodies( request      = `{"S_FRONT":{"ID":"ZZCKUTW9"}}`
                                          response     = `{"S_FRONT":{"ID":"ZZCKUTW10","APP":"X","PROTOCOL":2}}`
                                          check_sticky = abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( z2ui5_cl_cockpit_wire=>gt_buffer ) ).

    CLEAR temp43.
    INSERT `ZZCKUTW10` INTO TABLE temp43.
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_wire=>get_records( temp43 ) ).

    " recording off: nothing at all
    CLEAR z2ui5_cl_cockpit_wire=>gt_buffer.

    ls_set = z2ui5_cl_cockpit_setup=>get( ).
    ls_set-wire_days = 0.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).
    z2ui5_cl_cockpit_wire=>record_bodies( request      = `{"S_FRONT":{"ID":"ZZCKUTW9"}}`
                                          response     = `{}`
                                          check_sticky = abap_true ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_wire=>gt_buffer ).

  ENDMETHOD.

ENDCLASS.
