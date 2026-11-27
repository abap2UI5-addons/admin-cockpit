CLASS ltcl_session DEFINITION DEFERRED.
CLASS z2ui5_cl_cockpit_session DEFINITION LOCAL FRIENDS ltcl_session.

"! An object graph as CALL TRANSFORMATION id writes it - the round trip
"! test serializes one of these instead of a hand-written document.
CLASS ltcl_item DEFINITION FINAL.

  PUBLIC SECTION.
    INTERFACES if_serializable_object.

    DATA mv_text TYPE string.

ENDCLASS.


CLASS ltcl_item IMPLEMENTATION.
ENDCLASS.


CLASS ltcl_order DEFINITION FINAL.

  PUBLIC SECTION.
    INTERFACES if_serializable_object.

    TYPES:
      BEGIN OF ty_s_head,
        qty  TYPE i,
        note TYPE string,
      END OF ty_s_head.

    DATA mv_customer TYPE string.
    DATA ms_head     TYPE ty_s_head.
    DATA mt_lines    TYPE string_table.
    DATA mo_item     TYPE REF TO ltcl_item.

ENDCLASS.


CLASS ltcl_order IMPLEMENTATION.
ENDCLASS.


"! The fields of a serialized draft, the diff of two steps, the sessions of
"! a set of draft rows - nothing is read from the database.
CLASS ltcl_session DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    METHODS flatten_app_only FOR TESTING.
    METHODS flatten_masks_secrets FOR TESTING.
    METHODS ms_as_text FOR TESTING.
    METHODS signs_of_trouble FOR TESTING.
    METHODS story_told FOR TESTING.
    METHODS flatten_all FOR TESTING.
    METHODS flatten_same_class_twice FOR TESTING.
    METHODS flatten_round_trip FOR TESTING.
    METHODS diff_marks_changes FOR TESTING.
    METHODS diff_first_step FOR TESTING.
    METHODS roots_follow_the_chain FOR TESTING.
    METHODS steps_in_order FOR TESTING.
    METHODS steps_trimmed FOR TESTING.
    METHODS decode_entities FOR TESTING.
    METHODS app_is_first_own_object FOR TESTING.
    METHODS base64_of_utf8 FOR TESTING.
    METHODS flows_between_apps FOR TESTING.
    METHODS growth_of_tables FOR TESTING.
    METHODS business_objects FOR TESTING.
    METHODS messages_in_state FOR TESTING.
    METHODS flows_with_ends FOR TESTING.
    METHODS outcomes_after_errors FOR TESTING.
    METHODS common_values_of_failures FOR TESTING.
    METHODS seconds_across_midnight FOR TESTING.

    METHODS draft
      RETURNING
        VALUE(result) TYPE string.

    METHODS nodes
      RETURNING
        VALUE(result) TYPE z2ui5_cl_cockpit_session=>ty_t_node.

    METHODS value_of
      IMPORTING
        it_value      TYPE z2ui5_cl_cockpit_session=>ty_t_value
        path          TYPE string
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS ltcl_session IMPLEMENTATION.

  METHOD draft.

    " the framework's container first, the app, a popup the app holds, a
    " string the app references and a table only the framework references
    result = `<?xml version="1.0" encoding="utf-16"?>` &&
             `<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">` &&
             `<asx:values><DATA href="#o1"/></asx:values>` &&
             `<asx:heap xmlns:cls="http://www.sap.com/abapxml/classes/global">` &&
             `<cls:Z2UI5_CL_UI5_APP_CONT id="o1"><local.Z2UI5_CL_UI5_APP_CONT>` &&
             `<MT_ATTRI href="#d1"/><MO_APP href="#o2"/><MV_NAV_MODE/>` &&
             `</local.Z2UI5_CL_UI5_APP_CONT></cls:Z2UI5_CL_UI5_APP_CONT>` &&
             `<cls:ZCL_ORDER id="o2"><local.ZCL_ORDER>` &&
             `<MV_CUSTOMER>4711</MV_CUSTOMER>` &&
             `<MS_HEAD><QTY>3</QTY><NOTE>a &lt;b&gt; &amp; c</NOTE></MS_HEAD>` &&
             `<MT_ITEMS><item><MATNR>M1</MATNR></item><item><MATNR>M2</MATNR></item></MT_ITEMS>` &&
             `<MO_POPUP href="#o3"/><MR_DATA href="#d2"/>` &&
             `</local.ZCL_ORDER></cls:ZCL_ORDER>` &&
             `<cls:ZCL_POPUP id="o3"><local.ZCL_POPUP><MV_TEXT>Sure?</MV_TEXT></local.ZCL_POPUP></cls:ZCL_POPUP>` &&
             `<abap:string xmlns:abap="http://www.sap.com/abapxml/types/built-in" id="d2">referenced</abap:string>` &&
             `<prg:TY_T_ATTRI xmlns:prg="http://www.sap.com/abapxml/classes/class-pool/X" id="d1">` &&
             `<item><NAME>MV_X</NAME></item></prg:TY_T_ATTRI>` &&
             `</asx:heap></asx:abap>`.

  ENDMETHOD.

  METHOD nodes.

    " A -> B -> C, and D continues B after C (the browser's back button);
    " F starts a second session after a draft that is gone
    DATA temp1 TYPE z2ui5_cl_cockpit_session=>ty_t_node.
    DATA temp2 LIKE LINE OF temp1.
    CLEAR temp1.

    CLEAR temp2.
    temp2-id = `A`.
    temp2-timestampl = `20261008100000.0`.
    INSERT temp2 INTO TABLE temp1.
    CLEAR temp2.
    temp2-id = `B`.
    temp2-id_prev = `A`.
    temp2-timestampl = `20261008100010.0`.
    INSERT temp2 INTO TABLE temp1.
    CLEAR temp2.
    temp2-id = `C`.
    temp2-id_prev = `B`.
    temp2-timestampl = `20261008100020.0`.
    INSERT temp2 INTO TABLE temp1.
    CLEAR temp2.
    temp2-id = `D`.
    temp2-id_prev = `B`.
    temp2-timestampl = `20261008100130.0`.
    INSERT temp2 INTO TABLE temp1.
    CLEAR temp2.
    temp2-id = `F`.
    temp2-id_prev = `GONE`.
    temp2-timestampl = `20261008110000.0`.
    INSERT temp2 INTO TABLE temp1.
    CLEAR temp2.
    temp2-id = `G`.
    temp2-id_prev = `F`.
    temp2-timestampl = `20261008110005.0`.
    INSERT temp2 INTO TABLE temp1.
    result = temp1.

  ENDMETHOD.

  METHOD value_of.
    DATA ls_value LIKE LINE OF it_value.

    result = `(missing)`.

    LOOP AT it_value INTO ls_value WHERE path = path. "#EC CI_SORTSEQ
      result = ls_value-value.
      RETURN.
    ENDLOOP.

  ENDMETHOD.

  METHOD signs_of_trouble.

    " every component written out - the downport the unit build runs carries
    " an omitted one over from the row before (see the wire tests)
    DATA temp3 TYPE z2ui5_cl_cockpit_session=>ty_t_signal.
    DATA temp4 LIKE LINE OF temp3.
    DATA ls_signals TYPE z2ui5_cl_cockpit_session=>ty_s_signals.
    DATA temp5 TYPE z2ui5_cl_cockpit_session=>ty_t_signal.
    DATA temp6 LIKE LINE OF temp5.
    CLEAR temp3.

    temp4-timestampl = '20261008100000'.
    temp4-event = `SAVE`.
    temp4-http_status = 0.
    temp4-ms_browser = 0.
    temp4-error_text = `Date invalid`.
    INSERT temp4 INTO TABLE temp3.
    temp4-timestampl = '20261008100003'.
    temp4-event = `SAVE`.
    temp4-http_status = 0.
    temp4-ms_browser = 0.
    temp4-error_text = `Date invalid`.
    INSERT temp4 INTO TABLE temp3.
    temp4-timestampl = '20261008100006'.
    temp4-event = `SAVE`.
    temp4-http_status = 0.
    temp4-ms_browser = 0.
    temp4-error_text = ``.
    INSERT temp4 INTO TABLE temp3.
    temp4-timestampl = '20261008100100'.
    temp4-event = `NEXT`.
    temp4-http_status = 0.
    temp4-ms_browser = 6000.
    temp4-error_text = ``.
    INSERT temp4 INTO TABLE temp3.
    temp4-timestampl = '20261008100110'.
    temp4-event = `NEXT`.
    temp4-http_status = 0.
    temp4-ms_browser = 0.
    temp4-error_text = ``.
    INSERT temp4 INTO TABLE temp3.
    temp4-timestampl = '20261008100200'.
    temp4-event = `POST`.
    temp4-http_status = 500.
    temp4-ms_browser = 0.
    temp4-error_text = ``.
    INSERT temp4 INTO TABLE temp3.

    ls_signals = z2ui5_cl_cockpit_session=>signals_of( temp3 ).

    cl_abap_unit_assert=>assert_equals(
        exp = `pressed SAVE 3 times in 6 s; error "Date invalid" 2 times; 1 failed click; ` &&
              `pressed NEXT again after waiting 6 s; ended on an error`
        act = ls_signals-text ).
    cl_abap_unit_assert=>assert_equals( exp = 11
                                        act = ls_signals-score ).
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = ls_signals-state ).

    " a quiet session: different buttons, no error

    CLEAR temp5.

    temp6-timestampl = '20261008100000'.
    temp6-event = `SEARCH`.
    temp6-http_status = 0.
    temp6-ms_browser = 0.
    temp6-error_text = ``.
    INSERT temp6 INTO TABLE temp5.
    temp6-timestampl = '20261008100002'.
    temp6-event = `SAVE`.
    temp6-http_status = 0.
    temp6-ms_browser = 0.
    temp6-error_text = ``.
    INSERT temp6 INTO TABLE temp5.
    ls_signals = z2ui5_cl_cockpit_session=>signals_of( temp5 ).
    cl_abap_unit_assert=>assert_initial( ls_signals-text ).
    cl_abap_unit_assert=>assert_equals( exp = `None`
                                        act = ls_signals-state ).

  ENDMETHOD.

  METHOD story_told.

    DATA lv_nl LIKE cl_abap_char_utilities=>newline.
    DATA temp7 TYPE z2ui5_cl_cockpit_session=>ty_t_step.
    DATA temp8 LIKE LINE OF temp7.
    DATA lv_story TYPE string.
    lv_nl = cl_abap_char_utilities=>newline.

    CLEAR temp7.

    temp8-step = 1.
    temp8-time = `2026-10-08 10:02:11`.
    temp8-app = `ZORDER`.
    temp8-did = ``.
    temp8-event = ``.
    temp8-shown = ``.
    temp8-ms_text = ``.
    temp8-note = ``.
    INSERT temp8 INTO TABLE temp7.
    temp8-step = 2.
    temp8-time = `2026-10-08 10:02:40`.
    temp8-app = `ZORDER`.
    temp8-did = `pressed Button "Save" (SAVE)`.
    temp8-event = `SAVE`.
    temp8-shown = `error box: Date invalid`.
    temp8-ms_text = `1.2 s server, 6.2 s waited`.
    temp8-note = ``.
    INSERT temp8 INTO TABLE temp7.
    temp8-step = 3.
    temp8-time = `2026-10-08 10:03:20`.
    temp8-app = `ZDELIVERY`.
    temp8-did = ``.
    temp8-event = `GO`.
    temp8-shown = ``.
    temp8-ms_text = ``.
    temp8-note = `next click failed: event SHIP`.
    INSERT temp8 INTO TABLE temp7.

    lv_story = z2ui5_cl_cockpit_session=>story_of( temp7 ).

    cl_abap_unit_assert=>assert_equals(
        exp = |10:02:11  [ZORDER] started{ lv_nl }| &&
              |10:02:40  pressed Button "Save" (SAVE) -> error box: Date invalid | &&
              |(1.2 s server, 6.2 s waited){ lv_nl }| &&
              |10:03:20  [ZDELIVERY] event GO - next click failed: event SHIP{ lv_nl }|
        act = lv_story ).

  ENDMETHOD.

  METHOD ms_as_text.

    cl_abap_unit_assert=>assert_equals( exp = `850 ms`
                                        act = z2ui5_cl_cockpit_session=>ms_text( 850 ) ).
    cl_abap_unit_assert=>assert_equals( exp = `1.2 s`
                                        act = z2ui5_cl_cockpit_session=>ms_text( 1250 ) ).
    cl_abap_unit_assert=>assert_equals( exp = `12.0 s`
                                        act = z2ui5_cl_cockpit_session=>ms_text( 12040 ) ).

  ENDMETHOD.

  METHOD flatten_app_only.

    DATA lt_value TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    lt_value = z2ui5_cl_cockpit_session=>flatten( draft( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 9
                                        act = lines( lt_value ) ).
    cl_abap_unit_assert=>assert_equals( exp = `4711`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_ORDER-MV_CUSTOMER` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `3`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_ORDER-MS_HEAD-QTY` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `a <b> & c`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_ORDER-MS_HEAD-NOTE` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `M2`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_ORDER-MT_ITEMS[2]-MATNR` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `-> ZCL_POPUP`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_ORDER-MO_POPUP` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `-> string`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_ORDER-MR_DATA` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Sure?`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_POPUP-MV_TEXT` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `referenced`
                                        act = value_of( it_value = lt_value
                                                        path     = `string` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `(missing)`
                                        act = value_of( it_value = lt_value
                                                        path     = `TY_T_ATTRI[1]-NAME` ) ).

  ENDMETHOD.

  METHOD flatten_masks_secrets.

    " named like a password, bound to a password input (MV_PIN), and empty
    DATA lv_xml TYPE string.
    DATA temp9 TYPE string_table.
    DATA lt_value TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    lv_xml = `<?xml version="1.0" encoding="utf-16"?>` &&
                   `<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">` &&
                   `<asx:values><DATA href="#o1"/></asx:values>` &&
                   `<asx:heap xmlns:cls="http://www.sap.com/abapxml/classes/global">` &&
                   `<cls:ZCL_LOGIN id="o1"><local.ZCL_LOGIN>` &&
                   `<MV_USER>ALICE</MV_USER><MV_PIN>4711</MV_PIN><MS_LOGIN><PASSWORD>se&amp;cret</PASSWORD>` &&
                   `<NEW_PWD/></MS_LOGIN><MT_SECRET><item>s1</item></MT_SECRET>` &&
                   `</local.ZCL_LOGIN></cls:ZCL_LOGIN>` &&
                   `</asx:heap></asx:abap>`.


    CLEAR temp9.
    INSERT `MV_PIN` INTO TABLE temp9.

    lt_value = z2ui5_cl_cockpit_session=>flatten( xml       = lv_xml
                                                        it_secret = temp9 ).

    cl_abap_unit_assert=>assert_equals( exp = `ALICE`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_LOGIN-MV_USER` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `***`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_LOGIN-MV_PIN` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `***`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_LOGIN-MS_LOGIN-PASSWORD` ) ).
    cl_abap_unit_assert=>assert_equals( exp = ``
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_LOGIN-MS_LOGIN-NEW_PWD` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `***`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_LOGIN-MT_SECRET[1]` ) ).

    " without the names of the password inputs only the names give it away
    lt_value = z2ui5_cl_cockpit_session=>flatten( lv_xml ).
    cl_abap_unit_assert=>assert_equals( exp = `4711`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_LOGIN-MV_PIN` ) ).

  ENDMETHOD.

  METHOD flatten_all.

    DATA lt_value TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    lt_value = z2ui5_cl_cockpit_session=>flatten( xml       = draft( )
                                                       check_all = abap_true ).

    cl_abap_unit_assert=>assert_equals( exp = 13
                                        act = lines( lt_value ) ).
    cl_abap_unit_assert=>assert_equals( exp = `-> ZCL_ORDER`
                                        act = value_of( it_value = lt_value
                                                        path     = `Z2UI5_CL_UI5_APP_CONT-MO_APP` ) ).
    cl_abap_unit_assert=>assert_equals( exp = ``
                                        act = value_of( it_value = lt_value
                                                        path     = `Z2UI5_CL_UI5_APP_CONT-MV_NAV_MODE` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `MV_X`
                                        act = value_of( it_value = lt_value
                                                        path     = `TY_T_ATTRI[1]-NAME` ) ).

  ENDMETHOD.

  METHOD flatten_same_class_twice.

    DATA lv_xml TYPE string.
    DATA lt_value TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    lv_xml = `<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">` &&
                   `<asx:values><DATA href="#o1"/></asx:values><asx:heap>` &&
                   `<cls:ZCL_A id="o1"><local.ZCL_A><MO_X href="#o2"/><MO_Y href="#o3"/></local.ZCL_A></cls:ZCL_A>` &&
                   `<cls:ZCL_B id="o2"><local.ZCL_B><V>1</V></local.ZCL_B></cls:ZCL_B>` &&
                   `<cls:ZCL_B id="o3"><local.ZCL_B><V>2</V></local.ZCL_B></cls:ZCL_B>` &&
                   `</asx:heap></asx:abap>`.


    lt_value = z2ui5_cl_cockpit_session=>flatten( lv_xml ).

    cl_abap_unit_assert=>assert_equals( exp = `-> ZCL_B#2`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_A-MO_Y` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `1`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_B-V` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `2`
                                        act = value_of( it_value = lt_value
                                                        path     = `ZCL_B#2-V` ) ).

  ENDMETHOD.

  METHOD flatten_round_trip.

    DATA lv_xml TYPE string.
    DATA lv_found TYPE i.

    DATA lo_order TYPE REF TO ltcl_order.
    DATA temp11 TYPE string_table.
    DATA lt_value TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_value LIKE LINE OF lt_value.
    CREATE OBJECT lo_order TYPE ltcl_order.
    lo_order->mv_customer = `ACME & Co`.
    CLEAR lo_order->ms_head.
    lo_order->ms_head-qty = 7.
    lo_order->ms_head-note = `urgent`.

    CLEAR temp11.
    INSERT `first` INTO TABLE temp11.
    INSERT `second` INTO TABLE temp11.
    lo_order->mt_lines = temp11.
    CREATE OBJECT lo_order->mo_item TYPE ltcl_item.
    lo_order->mo_item->mv_text = `inner`.

    CALL TRANSFORMATION id SOURCE data = lo_order RESULT XML lv_xml.

    lt_value = z2ui5_cl_cockpit_session=>flatten( lv_xml ).

    " the label of a local class differs between systems - the paths below it do not

    LOOP AT lt_value INTO ls_value.
      IF ls_value-path CP `*-MV_CUSTOMER` AND ls_value-value = `ACME & Co`.
        lv_found = lv_found + 1.
      ELSEIF ls_value-path CP `*-MS_HEAD-QTY` AND ls_value-value = `7`.
        lv_found = lv_found + 1.
      ELSEIF ls_value-path CP `*-MT_LINES[2]` AND ls_value-value = `second`.
        lv_found = lv_found + 1.
      ELSEIF ls_value-path CP `*-MO_ITEM` AND ls_value-value CP `-> *ITEM*`.
        lv_found = lv_found + 1.
      ELSEIF ls_value-path CP `*-MV_TEXT` AND ls_value-value = `inner`.
        lv_found = lv_found + 1.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( exp = 5
                                        act = lv_found
                                        msg = lv_xml ).

  ENDMETHOD.

  METHOD diff_marks_changes.

    DATA temp13 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp14 LIKE LINE OF temp13.
    DATA lt_old LIKE temp13.
    DATA temp15 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp16 LIKE LINE OF temp15.
    DATA lt_new LIKE temp15.
    DATA lt_field TYPE z2ui5_cl_cockpit_session=>ty_t_field.
    DATA temp17 TYPE z2ui5_cl_cockpit_session=>ty_s_field.
    FIELD-SYMBOLS <temp1> LIKE LINE OF lt_field.
    DATA temp2 LIKE sy-tabix.
    DATA temp18 TYPE z2ui5_cl_cockpit_session=>ty_s_field.
    FIELD-SYMBOLS <temp3> LIKE LINE OF lt_field.
    DATA temp4 LIKE sy-tabix.
    FIELD-SYMBOLS <temp19> LIKE LINE OF lt_field.
    DATA temp20 LIKE sy-tabix.
    DATA temp21 TYPE z2ui5_cl_cockpit_session=>ty_s_field.
    FIELD-SYMBOLS <temp5> LIKE LINE OF lt_field.
    DATA temp6 LIKE sy-tabix.
    CLEAR temp13.

    temp14-path = `APP-A`.
    temp14-value = `1`.
    INSERT temp14 INTO TABLE temp13.
    temp14-path = `APP-B`.
    temp14-value = `x`.
    INSERT temp14 INTO TABLE temp13.
    temp14-path = `APP-GONE`.
    temp14-value = `old`.
    INSERT temp14 INTO TABLE temp13.

    lt_old = temp13.

    CLEAR temp15.

    temp16-path = `APP-A`.
    temp16-value = `1`.
    INSERT temp16 INTO TABLE temp15.
    temp16-path = `APP-B`.
    temp16-value = `y`.
    INSERT temp16 INTO TABLE temp15.
    temp16-path = `APP-NEW`.
    temp16-value = `typed`.
    INSERT temp16 INTO TABLE temp15.

    lt_new = temp15.


    lt_field = z2ui5_cl_cockpit_session=>diff( it_new = lt_new
                                                    it_old = lt_old ).

    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = lines( lt_field ) ).

    CLEAR temp17.
    temp17-path = `APP-A`.
    temp17-value = `1`.
    temp17-state = `None`.


    temp2 = sy-tabix.
    READ TABLE lt_field INDEX 1 ASSIGNING <temp1>.
    sy-tabix = temp2.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = temp17
                                        act = <temp1> ).

    CLEAR temp18.
    temp18-path = `APP-B`.
    temp18-value = `y`.
    temp18-prev = `x`.
    temp18-change = z2ui5_cl_cockpit_session=>cs_change-changed.
    temp18-state = `Warning`.


    temp4 = sy-tabix.
    READ TABLE lt_field INDEX 2 ASSIGNING <temp3>.
    sy-tabix = temp4.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = temp18
                                        act = <temp3> ).


    temp20 = sy-tabix.
    READ TABLE lt_field INDEX 3 ASSIGNING <temp19>.
    sy-tabix = temp20.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_session=>cs_change-new
                                        act = <temp19>-change ).

    CLEAR temp21.
    temp21-path = `APP-GONE`.
    temp21-prev = `old`.
    temp21-change = z2ui5_cl_cockpit_session=>cs_change-removed.
    temp21-state = `Error`.


    temp6 = sy-tabix.
    READ TABLE lt_field INDEX 4 ASSIGNING <temp5>.
    sy-tabix = temp6.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = temp21
                                        act = <temp5> ).

  ENDMETHOD.

  METHOD diff_first_step.

    DATA temp22 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp23 LIKE LINE OF temp22.
    DATA lt_new LIKE temp22.
    DATA lt_field TYPE z2ui5_cl_cockpit_session=>ty_t_field.
    FIELD-SYMBOLS <temp24> LIKE LINE OF lt_field.
    DATA temp25 LIKE sy-tabix.
    CLEAR temp22.

    temp23-path = `APP-A`.
    temp23-value = `1`.
    INSERT temp23 INTO TABLE temp22.

    lt_new = temp22.


    lt_field = z2ui5_cl_cockpit_session=>diff( it_new      = lt_new
                                                    check_first = abap_true ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_field ) ).


    temp25 = sy-tabix.
    READ TABLE lt_field INDEX 1 ASSIGNING <temp24>.
    sy-tabix = temp25.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_initial( <temp24>-change ).

  ENDMETHOD.

  METHOD roots_follow_the_chain.

    DATA lt_root TYPE z2ui5_cl_cockpit_session=>ty_t_root.
    DATA ls_root LIKE LINE OF lt_root.
    lt_root = z2ui5_cl_cockpit_session=>roots_of( nodes( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 6
                                        act = lines( lt_root ) ).

    LOOP AT lt_root INTO ls_root.
      CASE ls_root-id.
        WHEN `A` OR `B` OR `C` OR `D`.
          cl_abap_unit_assert=>assert_equals( exp = `A`
                                              act = ls_root-root
                                              msg = |root of { ls_root-id }| ).
        WHEN OTHERS.
          cl_abap_unit_assert=>assert_equals( exp = `F`
                                              act = ls_root-root
                                              msg = |root of { ls_root-id }| ).
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.

  METHOD steps_in_order.

    DATA lt_node TYPE z2ui5_cl_cockpit_session=>ty_t_node.
    DATA lt_step TYPE z2ui5_cl_cockpit_session=>ty_t_step.
    FIELD-SYMBOLS <temp26> LIKE LINE OF lt_step.
    DATA temp27 LIKE sy-tabix.
    FIELD-SYMBOLS <temp28> LIKE LINE OF lt_step.
    DATA temp29 LIKE sy-tabix.
    FIELD-SYMBOLS <temp30> LIKE LINE OF lt_step.
    DATA temp31 LIKE sy-tabix.
    FIELD-SYMBOLS <temp32> LIKE LINE OF lt_step.
    DATA temp33 LIKE sy-tabix.
    FIELD-SYMBOLS <temp34> LIKE LINE OF lt_step.
    DATA temp35 LIKE sy-tabix.
    FIELD-SYMBOLS <temp36> LIKE LINE OF lt_step.
    DATA temp37 LIKE sy-tabix.
    FIELD-SYMBOLS <temp38> LIKE LINE OF lt_step.
    DATA temp39 LIKE sy-tabix.
    FIELD-SYMBOLS <temp40> LIKE LINE OF lt_step.
    DATA temp41 LIKE sy-tabix.
    FIELD-SYMBOLS <temp42> LIKE LINE OF lt_step.
    DATA temp43 LIKE sy-tabix.
    lt_node = nodes( ).

    lt_step = z2ui5_cl_cockpit_session=>steps_of( it_node = lt_node
                                                       it_root = z2ui5_cl_cockpit_session=>roots_of( lt_node )
                                                       id      = `A` ).

    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = lines( lt_step ) ).


    temp27 = sy-tabix.
    READ TABLE lt_step INDEX 1 ASSIGNING <temp26>.
    sy-tabix = temp27.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `app start`
                                        act = <temp26>-note ).


    temp29 = sy-tabix.
    READ TABLE lt_step INDEX 2 ASSIGNING <temp28>.
    sy-tabix = temp29.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `+10 s`
                                        act = <temp28>-delta ).


    temp31 = sy-tabix.
    READ TABLE lt_step INDEX 3 ASSIGNING <temp30>.
    sy-tabix = temp31.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = <temp30>-follows ).


    temp33 = sy-tabix.
    READ TABLE lt_step INDEX 3 ASSIGNING <temp32>.
    sy-tabix = temp33.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_initial( <temp32>-note ).
    " D continues B, not C


    temp35 = sy-tabix.
    READ TABLE lt_step INDEX 4 ASSIGNING <temp34>.
    sy-tabix = temp35.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `D`
                                        act = <temp34>-id ).


    temp37 = sy-tabix.
    READ TABLE lt_step INDEX 4 ASSIGNING <temp36>.
    sy-tabix = temp37.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = <temp36>-follows ).


    temp39 = sy-tabix.
    READ TABLE lt_step INDEX 4 ASSIGNING <temp38>.
    sy-tabix = temp39.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_char_cp( exp = `continues step 2*`
                                         act = <temp38>-note ).


    temp41 = sy-tabix.
    READ TABLE lt_step INDEX 4 ASSIGNING <temp40>.
    sy-tabix = temp41.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `+1 min 10 s`
                                        act = <temp40>-delta ).

    lt_step = z2ui5_cl_cockpit_session=>steps_of( it_node = lt_node
                                                 it_root = z2ui5_cl_cockpit_session=>roots_of( lt_node )
                                                 id      = `F` ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_step ) ).


    temp43 = sy-tabix.
    READ TABLE lt_step INDEX 1 ASSIGNING <temp42>.
    sy-tabix = temp43.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `the steps before it expired`
                                        act = <temp42>-note ).

  ENDMETHOD.

  METHOD steps_trimmed.

    " more steps than shown: the newest stay, numbered from 1 again, and a
    " step still names the step it continues by its line
    DATA ls_steps TYPE z2ui5_cl_cockpit_session=>ty_s_steps.
    DATA lv_total TYPE i.
      DATA temp44 TYPE z2ui5_cl_cockpit_session=>ty_s_step.
      DATA temp7 TYPE z2ui5_cl_cockpit_session=>ty_s_step-follows.
    DATA ls_first TYPE z2ui5_cl_cockpit_session=>ty_s_step.
    FIELD-SYMBOLS <temp8> LIKE LINE OF ls_steps-t_step.
    DATA temp9 LIKE sy-tabix.
    FIELD-SYMBOLS <temp45> LIKE LINE OF ls_steps-t_step.
    DATA temp46 LIKE sy-tabix.
    DATA ls_last TYPE z2ui5_cl_cockpit_session=>ty_s_step.
    FIELD-SYMBOLS <temp10> LIKE LINE OF ls_steps-t_step.
    DATA temp11 LIKE sy-tabix.
    FIELD-SYMBOLS <temp47> LIKE LINE OF ls_steps-t_step.
    DATA temp48 LIKE sy-tabix.
    lv_total = z2ui5_cl_cockpit_session=>c_max_steps + 3.
    " each continues the one before, the last one the third step from the
    " end - browser back
    DO lv_total TIMES.

      CLEAR temp44.
      temp44-step = sy-index.
      temp44-id = |S{ sy-index }|.

      IF sy-index = lv_total.
        temp7 = lv_total - 3.
      ELSE.
        temp7 = sy-index - 1.
      ENDIF.
      temp44-follows = temp7.
      APPEND temp44
             TO ls_steps-t_step.
    ENDDO.

    z2ui5_cl_cockpit_session=>trim_steps( CHANGING cs_steps = ls_steps ).

    cl_abap_unit_assert=>assert_true( ls_steps-check_capped ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_session=>c_max_steps
                                        act = lines( ls_steps-t_step ) ).



    temp9 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 1 ASSIGNING <temp8>.
    sy-tabix = temp9.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_first = <temp8>.
    cl_abap_unit_assert=>assert_equals( exp = `S4`
                                        act = ls_first-id ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_first-step ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = ls_first-follows ).
    cl_abap_unit_assert=>assert_char_cp( exp = `continues a step before*`
                                         act = ls_first-note ).


    temp46 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 2 ASSIGNING <temp45>.
    sy-tabix = temp46.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = <temp45>-follows ).



    temp11 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX z2ui5_cl_cockpit_session=>c_max_steps ASSIGNING <temp10>.
    sy-tabix = temp11.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_last = <temp10>.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_session=>c_max_steps
                                        act = ls_last-step ).


    temp48 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX ls_last-follows ASSIGNING <temp47>.
    sy-tabix = temp48.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = |S{ lv_total - 3 }|
                                        act = <temp47>-id ).
    cl_abap_unit_assert=>assert_char_cp( exp = |continues step { ls_last-follows }*|
                                         act = ls_last-note ).

    " within the limit nothing changes
    CLEAR ls_steps-check_capped.
    z2ui5_cl_cockpit_session=>trim_steps( CHANGING cs_steps = ls_steps ).
    cl_abap_unit_assert=>assert_false( ls_steps-check_capped ).

  ENDMETHOD.

  METHOD decode_entities.

    cl_abap_unit_assert=>assert_equals( exp = `<a href="x">it's &amp;</a>`
                                        act = z2ui5_cl_cockpit_session=>decode(
                                                  `&lt;a href=&quot;x&quot;&gt;it&apos;s &amp;amp;&lt;/a&gt;` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `plain`
                                        act = z2ui5_cl_cockpit_session=>decode( `plain` ) ).

  ENDMETHOD.

  METHOD app_is_first_own_object.

    cl_abap_unit_assert=>assert_equals( exp = `ZCL_ORDER`
                                        act = z2ui5_cl_cockpit_session=>app_of( draft( ) ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = `/ACME/CL_APP`
        act = z2ui5_cl_cockpit_session=>app_of(
                  `<asx:heap><cls:_-ACME_-CL_APP xmlns:cls="http://www.sap.com/abapxml/classes/global" id="o1"/>` ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_session=>app_of( `<asx:abap/>` ) ).

  ENDMETHOD.

  METHOD business_objects.

    DATA temp49 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp50 LIKE LINE OF temp49.
    DATA lt_business TYPE z2ui5_cl_cockpit_session=>ty_t_business.
    DATA temp51 TYPE z2ui5_cl_cockpit_session=>ty_t_business.
    DATA temp52 LIKE LINE OF temp51.
    CLEAR temp49.

    temp50-path = `APP-MV_VBELN`.
    temp50-value = `4711`.
    INSERT temp50 INTO TABLE temp49.
    temp50-path = `APP-MS_HEAD-KUNNR`.
    temp50-value = `1000`.
    INSERT temp50 INTO TABLE temp49.
    temp50-path = `APP-MT_ITEMS[1]-MATNR`.
    temp50-value = `M1`.
    INSERT temp50 INTO TABLE temp49.
    temp50-path = `APP-MT_ITEMS[2]-MATNR`.
    temp50-value = `M1`.
    INSERT temp50 INTO TABLE temp49.
    temp50-path = `APP-MV_CUSTOMER`.
    temp50-value = ``.
    INSERT temp50 INTO TABLE temp49.
    temp50-path = `APP-MS_HEAD-WERKS`.
    temp50-value = `0000`.
    INSERT temp50 INTO TABLE temp49.
    temp50-path = `APP-MO_KUNNR`.
    temp50-value = `-> ZCL_X`.
    INSERT temp50 INTO TABLE temp49.
    temp50-path = `APP-MV_TEXT`.
    temp50-value = `4711`.
    INSERT temp50 INTO TABLE temp49.

    lt_business = z2ui5_cl_cockpit_session=>business_of(
        temp49 ).


    CLEAR temp51.

    temp52-object = `Sales document`.
    temp52-value = `4711`.
    temp52-field = `APP-MV_VBELN`.
    INSERT temp52 INTO TABLE temp51.
    temp52-object = `Customer`.
    temp52-value = `1000`.
    temp52-field = `APP-MS_HEAD-KUNNR`.
    INSERT temp52 INTO TABLE temp51.
    temp52-object = `Material`.
    temp52-value = `M1`.
    temp52-field = `APP-MT_ITEMS[1]-MATNR`.
    INSERT temp52 INTO TABLE temp51.
    cl_abap_unit_assert=>assert_equals(
        exp = temp51
        act = lt_business ).

  ENDMETHOD.

  METHOD messages_in_state.

    " a BAPI return with an error and a success, a UI structure whose TYPE
    " is no message type, an error with a TEXT and a warning with MSG
    DATA temp53 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp54 LIKE LINE OF temp53.
    DATA lt_message TYPE z2ui5_cl_cockpit_session=>ty_t_message.
    DATA temp55 TYPE z2ui5_cl_cockpit_session=>ty_t_message.
    DATA temp56 LIKE LINE OF temp55.
    CLEAR temp53.

    temp54-path = `APP-MT_RETURN[1]-TYPE`.
    temp54-value = `E`.
    INSERT temp54 INTO TABLE temp53.
    temp54-path = `APP-MT_RETURN[1]-MESSAGE`.
    temp54-value = `Quantity must be greater than 0`.
    INSERT temp54 INTO TABLE temp53.
    temp54-path = `APP-MT_RETURN[2]-TYPE`.
    temp54-value = `S`.
    INSERT temp54 INTO TABLE temp53.
    temp54-path = `APP-MT_RETURN[2]-MESSAGE`.
    temp54-value = `Saved`.
    INSERT temp54 INTO TABLE temp53.
    temp54-path = `APP-MS_BUTTON-TYPE`.
    temp54-value = `Emphasized`.
    INSERT temp54 INTO TABLE temp53.
    temp54-path = `APP-MS_BUTTON-TEXT`.
    temp54-value = `Save`.
    INSERT temp54 INTO TABLE temp53.
    temp54-path = `APP-MS_LOCK-SEVERITY`.
    temp54-value = `error`.
    INSERT temp54 INTO TABLE temp53.
    temp54-path = `APP-MS_LOCK-TEXT`.
    temp54-value = `Order is locked by USER2`.
    INSERT temp54 INTO TABLE temp53.
    temp54-path = `APP-MS_CHECK-MSGTY`.
    temp54-value = `W`.
    INSERT temp54 INTO TABLE temp53.
    temp54-path = `APP-MS_CHECK-MSG`.
    temp54-value = `Delivery date in the past`.
    INSERT temp54 INTO TABLE temp53.

    lt_message = z2ui5_cl_cockpit_session=>messages_of(
        temp53 ).


    CLEAR temp55.

    temp56-type = `E`.
    temp56-text = `Quantity must be greater than 0`.
    temp56-path = `APP-MT_RETURN[1]`.
    INSERT temp56 INTO TABLE temp55.
    temp56-type = `ERROR`.
    temp56-text = `Order is locked by USER2`.
    temp56-path = `APP-MS_LOCK`.
    INSERT temp56 INTO TABLE temp55.
    temp56-type = `W`.
    temp56-text = `Delivery date in the past`.
    temp56-path = `APP-MS_CHECK`.
    INSERT temp56 INTO TABLE temp55.
    cl_abap_unit_assert=>assert_equals(
        exp = temp55
        act = lt_message ).

  ENDMETHOD.

  METHOD common_values_of_failures.

    " QTY = 0 in all three failing states and in one of four others: the
    " hint. MODE = edit everywhere: no hint. NOTE = x in two of three: too few
    DATA temp57 TYPE z2ui5_cl_cockpit_session=>ty_t_sample.
    DATA temp58 LIKE LINE OF temp57.
    DATA lt_failing LIKE temp57.
    DATA temp59 TYPE z2ui5_cl_cockpit_session=>ty_t_sample.
    DATA temp60 LIKE LINE OF temp59.
    DATA lt_others LIKE temp59.
    DATA lt_common TYPE z2ui5_cl_cockpit_session=>ty_t_common.
    DATA temp61 TYPE z2ui5_cl_cockpit_session=>ty_s_common.
    FIELD-SYMBOLS <temp12> LIKE LINE OF lt_common.
    DATA temp13 LIKE sy-tabix.
    DATA temp62 TYPE z2ui5_cl_cockpit_session=>ty_t_sample.
    CLEAR temp57.

    temp58-sample = 1.
    temp58-path = `APP-QTY`.
    temp58-value = `0`.
    INSERT temp58 INTO TABLE temp57.
    temp58-sample = 1.
    temp58-path = `APP-MODE`.
    temp58-value = `edit`.
    INSERT temp58 INTO TABLE temp57.
    temp58-sample = 1.
    temp58-path = `APP-NOTE`.
    temp58-value = `x`.
    INSERT temp58 INTO TABLE temp57.
    temp58-sample = 2.
    temp58-path = `APP-QTY`.
    temp58-value = `0`.
    INSERT temp58 INTO TABLE temp57.
    temp58-sample = 2.
    temp58-path = `APP-MODE`.
    temp58-value = `edit`.
    INSERT temp58 INTO TABLE temp57.
    temp58-sample = 2.
    temp58-path = `APP-NOTE`.
    temp58-value = `x`.
    INSERT temp58 INTO TABLE temp57.
    temp58-sample = 3.
    temp58-path = `APP-QTY`.
    temp58-value = `0`.
    INSERT temp58 INTO TABLE temp57.
    temp58-sample = 3.
    temp58-path = `APP-MODE`.
    temp58-value = `edit`.
    INSERT temp58 INTO TABLE temp57.
    temp58-sample = 3.
    temp58-path = `APP-NOTE`.
    temp58-value = `y`.
    INSERT temp58 INTO TABLE temp57.

    lt_failing = temp57.

    CLEAR temp59.

    temp60-sample = 1.
    temp60-path = `APP-QTY`.
    temp60-value = `0`.
    INSERT temp60 INTO TABLE temp59.
    temp60-sample = 1.
    temp60-path = `APP-MODE`.
    temp60-value = `edit`.
    INSERT temp60 INTO TABLE temp59.
    temp60-sample = 2.
    temp60-path = `APP-QTY`.
    temp60-value = `5`.
    INSERT temp60 INTO TABLE temp59.
    temp60-sample = 2.
    temp60-path = `APP-MODE`.
    temp60-value = `edit`.
    INSERT temp60 INTO TABLE temp59.
    temp60-sample = 3.
    temp60-path = `APP-QTY`.
    temp60-value = `7`.
    INSERT temp60 INTO TABLE temp59.
    temp60-sample = 3.
    temp60-path = `APP-MODE`.
    temp60-value = `edit`.
    INSERT temp60 INTO TABLE temp59.
    temp60-sample = 4.
    temp60-path = `APP-QTY`.
    temp60-value = `1`.
    INSERT temp60 INTO TABLE temp59.
    temp60-sample = 4.
    temp60-path = `APP-MODE`.
    temp60-value = `edit`.
    INSERT temp60 INTO TABLE temp59.

    lt_others = temp59.


    lt_common = z2ui5_cl_cockpit_session=>common_of( it_failing = lt_failing
                                                          it_others  = lt_others ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_common ) ).

    CLEAR temp61.
    temp61-path = `APP-QTY`.
    temp61-value = `0`.
    temp61-failing = 3.
    temp61-of_failing = 3.
    temp61-others_pct = 25.
    temp61-text = `in 3 of 3 failing, in 25 % of 4 other states`.


    temp13 = sy-tabix.
    READ TABLE lt_common INDEX 1 ASSIGNING <temp12>.
    sy-tabix = temp13.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
        exp = temp61
        act = <temp12> ).

    " no baseline - nothing to tell the failing ones from

    CLEAR temp62.
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_session=>common_of( it_failing = lt_failing
                                                                             it_others  = temp62 ) ).

  ENDMETHOD.

  METHOD outcomes_after_errors.

    " nodes( ): B is continued by C and D, C and G are last steps - C long
    " ago, G "now"; X is no draft at all
    DATA temp63 TYPE z2ui5_cl_cockpit_session=>ty_t_id.
    DATA lt_outcome TYPE z2ui5_cl_cockpit_session=>ty_t_outcome.
    DATA temp65 TYPE z2ui5_cl_cockpit_session=>ty_t_outcome.
    DATA temp66 LIKE LINE OF temp65.
    CLEAR temp63.
    INSERT `B` INTO TABLE temp63.
    INSERT `C` INTO TABLE temp63.
    INSERT `G` INTO TABLE temp63.
    INSERT `X` INTO TABLE temp63.

    lt_outcome = z2ui5_cl_cockpit_session=>outcomes_of( it_node      = nodes( )
                                                              it_id        = temp63
                                                              ended_before = `20261008105000.0` ).


    CLEAR temp65.

    temp66-id = `B`.
    temp66-outcome = z2ui5_cl_cockpit_session=>cs_outcome-continued.
    temp66-state = `Success`.
    INSERT temp66 INTO TABLE temp65.
    temp66-id = `C`.
    temp66-outcome = z2ui5_cl_cockpit_session=>cs_outcome-stopped.
    temp66-state = `Error`.
    INSERT temp66 INTO TABLE temp65.
    temp66-id = `G`.
    temp66-outcome = z2ui5_cl_cockpit_session=>cs_outcome-open.
    temp66-state = `Information`.
    INSERT temp66 INTO TABLE temp65.
    temp66-id = `X`.
    temp66-outcome = z2ui5_cl_cockpit_session=>cs_outcome-unknown.
    temp66-state = `None`.
    INSERT temp66 INTO TABLE temp65.
    cl_abap_unit_assert=>assert_equals(
        exp = temp65
        act = lt_outcome ).

  ENDMETHOD.

  METHOD flows_with_ends.

    " the sessions of flows_between_apps, all over: D's roundtrip failed
    DATA temp67 TYPE z2ui5_cl_cockpit_session=>ty_t_link.
    DATA temp68 LIKE LINE OF temp67.
    DATA temp14 TYPE z2ui5_cl_cockpit_session=>ty_t_id.
    DATA lt_flow TYPE z2ui5_cl_cockpit_session=>ty_t_flow.
    DATA temp69 TYPE z2ui5_cl_cockpit_session=>ty_t_flow.
    DATA temp70 LIKE LINE OF temp69.
    CLEAR temp67.

    CLEAR temp68.
    temp68-id = `A`.
    temp68-app = `X`.
    INSERT temp68 INTO TABLE temp67.
    CLEAR temp68.
    temp68-id = `B`.
    temp68-id_prev = `A`.
    temp68-app = `X`.
    INSERT temp68 INTO TABLE temp67.
    CLEAR temp68.
    temp68-id = `C`.
    temp68-id_prev = `B`.
    temp68-app = `Y`.
    INSERT temp68 INTO TABLE temp67.
    CLEAR temp68.
    temp68-id = `D`.
    temp68-id_prev = `C`.
    temp68-app = `X`.
    INSERT temp68 INTO TABLE temp67.
    CLEAR temp68.
    temp68-id = `E`.
    temp68-id_prev = `GONE`.
    temp68-app = `Z`.
    INSERT temp68 INTO TABLE temp67.
    CLEAR temp68.
    temp68-id = `F`.
    temp68-id_prev = ``.
    temp68-app = `Y`.
    INSERT temp68 INTO TABLE temp67.

    CLEAR temp14.
    INSERT `D` INTO TABLE temp14.

    lt_flow = z2ui5_cl_cockpit_session=>flows_of(
        it_link      = temp67
        it_failed    = temp14
        ended_before = `20991231000000.0` ).


    CLEAR temp69.

    temp70-source = `(start)`.
    temp70-target = `X`.
    temp70-count = 1.
    INSERT temp70 INTO TABLE temp69.
    temp70-source = `(start)`.
    temp70-target = `Y`.
    temp70-count = 1.
    INSERT temp70 INTO TABLE temp69.
    temp70-source = `X`.
    temp70-target = `(end after an error)`.
    temp70-count = 1.
    INSERT temp70 INTO TABLE temp69.
    temp70-source = `X`.
    temp70-target = `Y`.
    temp70-count = 1.
    INSERT temp70 INTO TABLE temp69.
    temp70-source = `Y`.
    temp70-target = `(end)`.
    temp70-count = 1.
    INSERT temp70 INTO TABLE temp69.
    temp70-source = `Y`.
    temp70-target = `X`.
    temp70-count = 1.
    INSERT temp70 INTO TABLE temp69.
    temp70-source = `Z`.
    temp70-target = `(end)`.
    temp70-count = 1.
    INSERT temp70 INTO TABLE temp69.
    cl_abap_unit_assert=>assert_equals(
        exp = temp69
        act = lt_flow ).

  ENDMETHOD.

  METHOD growth_of_tables.

    " MT_LOG grows from 1 to 3 rows, the nested T_SUB of row 1 from 1 to 2,
    " MT_SAME keeps its row
    DATA temp71 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp72 LIKE LINE OF temp71.
    DATA lt_before LIKE temp71.
    DATA temp73 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp74 LIKE LINE OF temp73.
    DATA lt_after LIKE temp73.
    DATA temp75 TYPE z2ui5_cl_cockpit_session=>ty_t_growth.
    DATA temp76 LIKE LINE OF temp75.
    CLEAR temp71.

    temp72-path = `APP-MT_LOG[1]-TEXT`.
    temp72-value = `a`.
    INSERT temp72 INTO TABLE temp71.
    temp72-path = `APP-MT_A[1]-T_SUB[1]-X`.
    temp72-value = `1`.
    INSERT temp72 INTO TABLE temp71.
    temp72-path = `APP-MT_SAME[1]`.
    temp72-value = `s`.
    INSERT temp72 INTO TABLE temp71.

    lt_before = temp71.

    CLEAR temp73.

    temp74-path = `APP-MT_LOG[1]-TEXT`.
    temp74-value = `a`.
    INSERT temp74 INTO TABLE temp73.
    temp74-path = `APP-MT_LOG[1]-NR`.
    temp74-value = `1`.
    INSERT temp74 INTO TABLE temp73.
    temp74-path = `APP-MT_LOG[2]-TEXT`.
    temp74-value = `b`.
    INSERT temp74 INTO TABLE temp73.
    temp74-path = `APP-MT_LOG[3]-TEXT`.
    temp74-value = `c`.
    INSERT temp74 INTO TABLE temp73.
    temp74-path = `APP-MT_A[1]-T_SUB[1]-X`.
    temp74-value = `1`.
    INSERT temp74 INTO TABLE temp73.
    temp74-path = `APP-MT_A[1]-T_SUB[2]-X`.
    temp74-value = `2`.
    INSERT temp74 INTO TABLE temp73.
    temp74-path = `APP-MT_SAME[1]`.
    temp74-value = `t`.
    INSERT temp74 INTO TABLE temp73.

    lt_after = temp73.


    CLEAR temp75.

    temp76-path = `APP-MT_LOG`.
    temp76-rows_before = 1.
    temp76-rows_after = 3.
    INSERT temp76 INTO TABLE temp75.
    temp76-path = `APP-MT_A[1]-T_SUB`.
    temp76-rows_before = 1.
    temp76-rows_after = 2.
    INSERT temp76 INTO TABLE temp75.
    cl_abap_unit_assert=>assert_equals(
        exp = temp75
        act = z2ui5_cl_cockpit_session=>growth_of( it_before = lt_before
                                                   it_after  = lt_after ) ).

  ENDMETHOD.

  METHOD flows_between_apps.

    " two sessions: X -> X -> Y -> X and one starting in Y; E's predecessor
    " is gone, so it is neither a start nor a navigation
    DATA temp77 TYPE z2ui5_cl_cockpit_session=>ty_t_link.
    DATA temp78 LIKE LINE OF temp77.
    DATA lt_flow TYPE z2ui5_cl_cockpit_session=>ty_t_flow.
    DATA temp79 TYPE z2ui5_cl_cockpit_session=>ty_t_flow.
    DATA temp80 LIKE LINE OF temp79.
    CLEAR temp77.

    CLEAR temp78.
    temp78-id = `A`.
    temp78-app = `X`.
    INSERT temp78 INTO TABLE temp77.
    CLEAR temp78.
    temp78-id = `B`.
    temp78-id_prev = `A`.
    temp78-app = `X`.
    INSERT temp78 INTO TABLE temp77.
    CLEAR temp78.
    temp78-id = `C`.
    temp78-id_prev = `B`.
    temp78-app = `Y`.
    INSERT temp78 INTO TABLE temp77.
    CLEAR temp78.
    temp78-id = `D`.
    temp78-id_prev = `C`.
    temp78-app = `X`.
    INSERT temp78 INTO TABLE temp77.
    CLEAR temp78.
    temp78-id = `E`.
    temp78-id_prev = `GONE`.
    temp78-app = `Z`.
    INSERT temp78 INTO TABLE temp77.
    CLEAR temp78.
    temp78-id = `F`.
    temp78-id_prev = ``.
    temp78-app = `Y`.
    INSERT temp78 INTO TABLE temp77.

    lt_flow = z2ui5_cl_cockpit_session=>flows_of( temp77 ).


    CLEAR temp79.

    temp80-source = `(start)`.
    temp80-target = `X`.
    temp80-count = 1.
    INSERT temp80 INTO TABLE temp79.
    temp80-source = `(start)`.
    temp80-target = `Y`.
    temp80-count = 1.
    INSERT temp80 INTO TABLE temp79.
    temp80-source = `X`.
    temp80-target = `Y`.
    temp80-count = 1.
    INSERT temp80 INTO TABLE temp79.
    temp80-source = `Y`.
    temp80-target = `X`.
    temp80-count = 1.
    INSERT temp80 INTO TABLE temp79.
    cl_abap_unit_assert=>assert_equals(
        exp = temp79
        act = lt_flow ).

  ENDMETHOD.

  METHOD base64_of_utf8.

    cl_abap_unit_assert=>assert_equals( exp = `YWJj`
                                        act = z2ui5_cl_cockpit_session=>to_base64( `abc` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `YWI=`
                                        act = z2ui5_cl_cockpit_session=>to_base64( `ab` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `YQ==`
                                        act = z2ui5_cl_cockpit_session=>to_base64( `a` ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_session=>to_base64( `` ) ).

  ENDMETHOD.

  METHOD seconds_across_midnight.

    cl_abap_unit_assert=>assert_equals( exp = 70
                                        act = z2ui5_cl_cockpit_session=>seconds_between(
                                                  ts_from = `20261008235930.0`
                                                  ts_to   = `20261009000040.0` ) ).

  ENDMETHOD.

ENDCLASS.


"! The draft table read for real: three drafts of one session in 2099, so
"! they are the newest rows, deleted again in teardown. The table is a
"! framework internal - named in a literal here as everywhere else.
CLASS ltcl_session_db DEFINITION FINAL FOR TESTING RISK LEVEL DANGEROUS DURATION SHORT.

  PRIVATE SECTION.

    CONSTANTS c_table TYPE string VALUE `Z2UI5_T_01`.
    CONSTANTS c_app   TYPE string VALUE `ZZ_COCKPIT_UNIT_TEST`.

    TYPES:
      BEGIN OF ty_s_draft,
        mandt             TYPE mandt,
        id                TYPE c LENGTH 32,
        id_prev           TYPE c LENGTH 32,
        id_prev_app       TYPE c LENGTH 32,
        id_prev_app_stack TYPE c LENGTH 32,
        uname             TYPE c LENGTH 32,
        timestampl        TYPE timestampl,
        data              TYPE string,
      END OF ty_s_draft.

    METHODS setup.
    METHODS teardown.

    METHODS session_listed FOR TESTING.
    METHODS steps_and_changes FOR TESTING.
    METHODS session_of_a_draft FOR TESTING.
    METHODS monitor_marks_steps FOR TESTING.
    METHODS export_as_text FOR TESTING.
    METHODS history_of_a_field FOR TESTING.
    METHODS search_in_drafts FOR TESTING.
    METHODS failures_and_app_objects FOR TESTING.
    METHODS playback_from_recordings FOR TESTING.
    METHODS search_reads_newest_only FOR TESTING.

    METHODS order
      IMPORTING
        customer      TYPE string
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS ltcl_session_db IMPLEMENTATION.

  METHOD setup.

    TYPES temp1 TYPE STANDARD TABLE OF ty_s_draft WITH DEFAULT KEY.
DATA lt_draft TYPE temp1.
    DATA lv_tab TYPE string.

    DATA ls_set TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA temp81 LIKE lt_draft.
    DATA temp82 LIKE LINE OF temp81.
    FIELD-SYMBOLS <draft> LIKE LINE OF lt_draft.
    DATA temp83 TYPE z2ui5_t_25.
    DATA ls_log LIKE temp83.
    ls_set = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-name.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).


    CLEAR temp81.

    CLEAR temp82.
    temp82-uname = `ZZ_COCKPIT_UT`.
    temp82-id = `ZZCKUT1`.
    temp82-timestampl = `20991231100000.0`.
    temp82-data = order( `` ).
    INSERT temp82 INTO TABLE temp81.
    CLEAR temp82.
    temp82-uname = `ZZ_COCKPIT_UT`.
    temp82-id = `ZZCKUT2`.
    temp82-id_prev = `ZZCKUT1`.
    temp82-timestampl = `20991231100005.0`.
    temp82-data = order( `4711` ).
    INSERT temp82 INTO TABLE temp81.
    CLEAR temp82.
    temp82-uname = `ZZ_COCKPIT_UT`.
    temp82-id = `ZZCKUT3`.
    temp82-id_prev = `ZZCKUT2`.
    temp82-timestampl = `20991231100105.0`.
    temp82-data = order( `4712` ).
    INSERT temp82 INTO TABLE temp81.
    lt_draft = temp81.
    lv_tab = c_table.

    LOOP AT lt_draft ASSIGNING <draft>.
      <draft>-mandt = sy-mandt.
    ENDLOOP.
    INSERT (lv_tab) FROM TABLE lt_draft.

    " what the monitor logged: the slow roundtrip that wrote step 3, and a
    " failed one that started from step 2

    CLEAR temp83.
    temp83-id = `ZZCKUTLOG1`.
    temp83-timestampl = `20991231100105.0`.
    temp83-utc_day = `20991231`.
    temp83-app = c_app.
    temp83-event = `SAVE`.
    temp83-draft_id = `ZZCKUT3`.
    temp83-draft_id_prev = `ZZCKUT2`.
    temp83-check_slow = abap_true.
    temp83-ms_total = 2500.

    ls_log = temp83.
    INSERT z2ui5_t_25 FROM ls_log.
    CLEAR ls_log.
    ls_log-id = `ZZCKUTLOG2`.
    ls_log-timestampl = `20991231100030.0`.
    ls_log-utc_day = `20991231`.
    ls_log-app = c_app.
    ls_log-event = `POST`.
    ls_log-draft_id_prev = `ZZCKUT2`.
    ls_log-check_error = abap_true.
    ls_log-error_class = `CX_SY_ZERODIVIDE`.
    ls_log-error_head = `Division by zero`.
    INSERT z2ui5_t_25 FROM ls_log.

  ENDMETHOD.

  METHOD teardown.

    DATA lv_tab TYPE string.
    DATA lv_pattern TYPE string.
    DATA temp84 TYPE z2ui5_t_25-app.
    DATA lv_app LIKE temp84.
    DATA temp85 TYPE z2ui5_t_28-app.
    DATA lv_wire_app LIKE temp85.
    lv_tab = c_table.
    lv_pattern = `ZZCKUT%`.
    DELETE FROM (lv_tab) WHERE id LIKE lv_pattern.

    temp84 = c_app.

    lv_app = temp84.
    DELETE FROM z2ui5_t_25 WHERE app = lv_app.

    temp85 = c_app.

    lv_wire_app = temp85.
    DELETE FROM z2ui5_t_28 WHERE app = lv_wire_app.
    ROLLBACK WORK.                                       "#EC CI_ROLLBACK
    z2ui5_cl_cockpit_setup=>reset_buffer( ).

  ENDMETHOD.

  METHOD order.

    result = `<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">` &&
             `<asx:values><DATA href="#o1"/></asx:values><asx:heap>` &&
             `<cls:ZCL_ORDER id="o1"><local.ZCL_ORDER>` &&
             |<MV_CUSTOMER>{ customer }</MV_CUSTOMER><MV_MODE>edit</MV_MODE>| &&
             `</local.ZCL_ORDER></cls:ZCL_ORDER></asx:heap></asx:abap>`.

  ENDMETHOD.

  METHOD search_reads_newest_only.

    TYPES temp2 TYPE STANDARD TABLE OF ty_s_draft WITH DEFAULT KEY.
DATA lt_draft TYPE temp2.
    DATA lv_tab TYPE string.
    DATA lv_ts TYPE timestampl.
    DATA lv_end TYPE timestampl.
      DATA temp86 TYPE ltcl_session_db=>ty_s_draft.
    DATA temp87 TYPE ltcl_session_db=>ty_s_draft.
    DATA ls_list TYPE z2ui5_cl_cockpit_session=>ty_s_list.
    DATA temp1 TYPE xsdboolean.
    FIELD-SYMBOLS <temp88> LIKE LINE OF ls_list-t_session.
    DATA temp89 LIKE sy-tabix.

    " 300 sessions of one user, all newer than the one session of another
    lv_end = '20991231120000'.
    DO 300 TIMES.
      lv_ts = z2ui5_cl_cockpit_setup=>ts_minus_seconds( ts      = lv_end
                                                        seconds = sy-index ).

      CLEAR temp86.
      temp86-mandt = sy-mandt.
      temp86-id = |ZZCKUTS{ sy-index }|.
      temp86-uname = `ZZ_COCKPIT_UT`.
      temp86-timestampl = lv_ts.
      temp86-data = order( `` ).
      APPEND temp86 TO lt_draft.
    ENDDO.

    CLEAR temp87.
    temp87-mandt = sy-mandt.
    temp87-id = `ZZCKUTOLD`.
    temp87-uname = `ZZ_COCKPIT_OLD`.
    temp87-timestampl = '20991231090000'.
    temp87-data = order( `` ).
    APPEND temp87 TO lt_draft.
    lv_tab = c_table.
    INSERT (lv_tab) FROM TABLE lt_draft.

    " the default reads 300 sessions at most - the match is older

    ls_list = z2ui5_cl_cockpit_session=>get_sessions( search = `ZZ_COCKPIT_OLD` ).
    cl_abap_unit_assert=>assert_initial( ls_list-t_session ).
    cl_abap_unit_assert=>assert_equals( exp = 300
                                        act = ls_list-searched ).
    cl_abap_unit_assert=>assert_true( ls_list-check_more ).

    temp1 = boolc( ls_list-sessions >= 302 ).
    cl_abap_unit_assert=>assert_true( temp1 ).

    " a larger budget reaches it
    ls_list = z2ui5_cl_cockpit_session=>get_sessions( max_sessions = 200
                                                      search       = `ZZ_COCKPIT_OLD` ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( ls_list-t_session ) ).


    temp89 = sy-tabix.
    READ TABLE ls_list-t_session INDEX 1 ASSIGNING <temp88>.
    sy-tabix = temp89.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUTOLD`
                                        act = <temp88>-id ).

  ENDMETHOD.

  METHOD session_listed.

    DATA ls_list TYPE z2ui5_cl_cockpit_session=>ty_s_list.
    DATA ls_session TYPE z2ui5_cl_cockpit_session=>ty_s_session.
    FIELD-SYMBOLS <temp16> LIKE LINE OF ls_list-t_session.
    DATA temp17 LIKE sy-tabix.
    FIELD-SYMBOLS <temp90> LIKE LINE OF ls_list-t_session.
    DATA temp91 LIKE sy-tabix.
    DATA temp2 TYPE xsdboolean.
    ls_list = z2ui5_cl_cockpit_session=>get_sessions( max_sessions = 1 ).

    cl_abap_unit_assert=>assert_true( ls_list-check_readable ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( ls_list-t_session ) ).



    temp17 = sy-tabix.
    READ TABLE ls_list-t_session INDEX 1 ASSIGNING <temp16>.
    sy-tabix = temp17.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_session = <temp16>.
    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUT1`
                                        act = ls_session-id ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = ls_session-steps ).
    cl_abap_unit_assert=>assert_equals( exp = `ZCL_ORDER`
                                        act = ls_session-app ).
    cl_abap_unit_assert=>assert_equals( exp = `ZZ_COCKPIT_UT`
                                        act = ls_session-user ).
    cl_abap_unit_assert=>assert_equals( exp = `1 min 5 s`
                                        act = ls_session-duration ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_session-errors ).
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = ls_session-state ).

    ls_list = z2ui5_cl_cockpit_session=>get_sessions( max_sessions = 1
                                                      check_errors = abap_true ).


    temp91 = sy-tabix.
    READ TABLE ls_list-t_session INDEX 1 ASSIGNING <temp90>.
    sy-tabix = temp91.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUT1`
                                        act = <temp90>-id ).

    " the overview's count: no session listed, none read
    ls_list = z2ui5_cl_cockpit_session=>get_sessions( max_sessions = 0
                                                      check_errors = abap_true ).
    cl_abap_unit_assert=>assert_initial( ls_list-t_session ).

    temp2 = boolc( ls_list-sessions >= 1 ).
    cl_abap_unit_assert=>assert_true( temp2 ).

    ls_list = z2ui5_cl_cockpit_session=>get_sessions( max_sessions = 1
                                                      search       = `no such app` ).
    cl_abap_unit_assert=>assert_initial( ls_list-t_session ).

  ENDMETHOD.

  METHOD steps_and_changes.

    DATA ls_steps TYPE z2ui5_cl_cockpit_session=>ty_s_steps.
    FIELD-SYMBOLS <temp92> LIKE LINE OF ls_steps-t_step.
    DATA temp93 LIKE sy-tabix.
    DATA ls_step LIKE LINE OF ls_steps-t_step.
    FIELD-SYMBOLS <temp94> LIKE LINE OF ls_steps-t_step.
    DATA temp95 LIKE sy-tabix.
    FIELD-SYMBOLS <temp96> LIKE LINE OF ls_steps-t_step.
    DATA temp97 LIKE sy-tabix.
    FIELD-SYMBOLS <temp98> LIKE LINE OF ls_steps-t_step.
    DATA temp99 LIKE sy-tabix.
    DATA temp100 TYPE z2ui5_cl_cockpit_session=>ty_t_business.
    DATA temp101 LIKE LINE OF temp100.
    DATA ls_view TYPE z2ui5_cl_cockpit_session=>ty_s_view.
    DATA temp102 TYPE z2ui5_cl_cockpit_session=>ty_s_field.
    FIELD-SYMBOLS <temp18> LIKE LINE OF ls_view-t_field.
    DATA temp19 LIKE sy-tabix.
    ls_steps = z2ui5_cl_cockpit_session=>get_steps( `ZZCKUT1` ).

    cl_abap_unit_assert=>assert_initial( ls_steps-error ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( ls_steps-t_step ) ).


    temp93 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp92>.
    sy-tabix = temp93.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ZCL_ORDER`
                                        act = <temp92>-app ).
    " nothing recorded for these drafts - the states bound to an ObjectStatus
    " are still a ValueState, an empty one terminates the app

    LOOP AT ls_steps-t_step INTO ls_step.
      cl_abap_unit_assert=>assert_not_initial( ls_step-shown_state ).
      cl_abap_unit_assert=>assert_not_initial( ls_step-monitor_state ).
      cl_abap_unit_assert=>assert_not_initial( ls_step-messages_state ).
    ENDLOOP.


    temp95 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp94>.
    sy-tabix = temp95.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = <temp94>-kb ).


    temp97 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 2 ASSIGNING <temp96>.
    sy-tabix = temp97.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = <temp96>-changes ).


    temp99 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp98>.
    sy-tabix = temp99.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = <temp98>-changes ).

    CLEAR temp100.

    temp101-object = `Customer`.
    temp101-value = `4711`.
    temp101-field = `ZCL_ORDER-MV_CUSTOMER`.
    temp101-step = 2.
    INSERT temp101 INTO TABLE temp100.
    temp101-object = `Customer`.
    temp101-value = `4712`.
    temp101-field = `ZCL_ORDER-MV_CUSTOMER`.
    temp101-step = 3.
    INSERT temp101 INTO TABLE temp100.
    cl_abap_unit_assert=>assert_equals(
        exp = temp100
        act = ls_steps-t_business ).


    ls_view = z2ui5_cl_cockpit_session=>get_view( id            = `ZZCKUT3`
                                                       id_prev       = `ZZCKUT2`
                                                       check_changes = abap_true ).
    cl_abap_unit_assert=>assert_initial( ls_view-error ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_view-fields ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_view-changes ).

    CLEAR temp102.
    temp102-path = `ZCL_ORDER-MV_CUSTOMER`.
    temp102-value = `4712`.
    temp102-prev = `4711`.
    temp102-change = z2ui5_cl_cockpit_session=>cs_change-changed.
    temp102-state = `Warning`.


    temp19 = sy-tabix.
    READ TABLE ls_view-t_field INDEX 1 ASSIGNING <temp18>.
    sy-tabix = temp19.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = temp102
                                        act = <temp18> ).

    ls_view = z2ui5_cl_cockpit_session=>get_view( `ZZCKUT_GONE` ).
    cl_abap_unit_assert=>assert_not_initial( ls_view-error ).

  ENDMETHOD.

  METHOD monitor_marks_steps.

    DATA ls_steps TYPE z2ui5_cl_cockpit_session=>ty_s_steps.
    FIELD-SYMBOLS <temp103> LIKE LINE OF ls_steps-t_step.
    DATA temp104 LIKE sy-tabix.
    FIELD-SYMBOLS <temp105> LIKE LINE OF ls_steps-t_step.
    DATA temp106 LIKE sy-tabix.
    FIELD-SYMBOLS <temp107> LIKE LINE OF ls_steps-t_step.
    DATA temp108 LIKE sy-tabix.
    FIELD-SYMBOLS <temp109> LIKE LINE OF ls_steps-t_step.
    DATA temp110 LIKE sy-tabix.
    FIELD-SYMBOLS <temp111> LIKE LINE OF ls_steps-t_step.
    DATA temp112 LIKE sy-tabix.
    FIELD-SYMBOLS <temp113> LIKE LINE OF ls_steps-t_step.
    DATA temp114 LIKE sy-tabix.
    ls_steps = z2ui5_cl_cockpit_session=>get_steps( `ZZCKUT1` ).



    temp104 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 1 ASSIGNING <temp103>.
    sy-tabix = temp104.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `None`
                                        act = <temp103>-monitor_state ).


    temp106 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 2 ASSIGNING <temp105>.
    sy-tabix = temp106.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = <temp105>-monitor_state ).


    temp108 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 2 ASSIGNING <temp107>.
    sy-tabix = temp108.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_char_cp( exp = `*CX_SY_ZERODIVIDE*event POST*`
                                         act = <temp107>-monitor ).


    temp110 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp109>.
    sy-tabix = temp110.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Warning`
                                        act = <temp109>-monitor_state ).


    temp112 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp111>.
    sy-tabix = temp112.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `SAVE`
                                        act = <temp111>-event ).


    temp114 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp113>.
    sy-tabix = temp114.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `slow: 2500 ms`
                                        act = <temp113>-monitor ).

  ENDMETHOD.

  METHOD history_of_a_field.

    DATA ls_steps TYPE z2ui5_cl_cockpit_session=>ty_s_steps.
    DATA lt_history TYPE z2ui5_cl_cockpit_session=>ty_t_history.
    DATA temp115 TYPE z2ui5_cl_cockpit_session=>ty_s_history.
    FIELD-SYMBOLS <temp20> LIKE LINE OF lt_history.
    DATA temp21 LIKE sy-tabix.
    FIELD-SYMBOLS <temp116> LIKE LINE OF lt_history.
    DATA temp117 LIKE sy-tabix.
    FIELD-SYMBOLS <temp118> LIKE LINE OF lt_history.
    DATA temp119 LIKE sy-tabix.
    FIELD-SYMBOLS <temp120> LIKE LINE OF lt_history.
    DATA temp121 LIKE sy-tabix.
    FIELD-SYMBOLS <temp122> LIKE LINE OF lt_history.
    DATA temp123 LIKE sy-tabix.
    ls_steps = z2ui5_cl_cockpit_session=>get_steps( `ZZCKUT1` ).

    lt_history = z2ui5_cl_cockpit_session=>get_history( it_step = ls_steps-t_step
                                                             path    = `ZCL_ORDER-MV_CUSTOMER` ).

    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( lt_history ) ).

    CLEAR temp115.
    temp115-step = 1.
    temp115-time = `2099-12-31 10:00:00`.
    temp115-state = `None`.


    temp21 = sy-tabix.
    READ TABLE lt_history INDEX 1 ASSIGNING <temp20>.
    sy-tabix = temp21.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = temp115
                                        act = <temp20> ).


    temp117 = sy-tabix.
    READ TABLE lt_history INDEX 2 ASSIGNING <temp116>.
    sy-tabix = temp117.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `4711`
                                        act = <temp116>-value ).


    temp119 = sy-tabix.
    READ TABLE lt_history INDEX 2 ASSIGNING <temp118>.
    sy-tabix = temp119.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Warning`
                                        act = <temp118>-state ).


    temp121 = sy-tabix.
    READ TABLE lt_history INDEX 3 ASSIGNING <temp120>.
    sy-tabix = temp121.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `4712`
                                        act = <temp120>-value ).

    lt_history = z2ui5_cl_cockpit_session=>get_history( it_step = ls_steps-t_step
                                                       path    = `ZCL_ORDER-NO_SUCH_FIELD` ).


    temp123 = sy-tabix.
    READ TABLE lt_history INDEX 3 ASSIGNING <temp122>.
    sy-tabix = temp123.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `(not there)`
                                        act = <temp122>-value ).

  ENDMETHOD.

  METHOD playback_from_recordings.

    DATA lv_res_body TYPE string.
    DATA temp124 TYPE z2ui5_cl_cockpit_session=>ty_t_id.
    DATA lt_wire LIKE temp124.
    DATA temp125 TYPE z2ui5_t_28.
    DATA ls_wire LIKE temp125.
    DATA ls_steps TYPE z2ui5_cl_cockpit_session=>ty_s_steps.
    FIELD-SYMBOLS <temp126> LIKE LINE OF ls_steps-t_step.
    DATA temp127 LIKE sy-tabix.
    FIELD-SYMBOLS <temp128> LIKE LINE OF ls_steps-t_step.
    DATA temp129 LIKE sy-tabix.
    FIELD-SYMBOLS <temp130> LIKE LINE OF ls_steps-t_step.
    DATA temp131 LIKE sy-tabix.
    FIELD-SYMBOLS <temp132> LIKE LINE OF ls_steps-t_step.
    DATA temp133 LIKE sy-tabix.
    DATA ls_screen TYPE z2ui5_cl_cockpit_wire=>ty_s_screen.

    " the body built ahead of the VALUE: inside it the 7.02 downport writes
    " the whole concatenation on one line, longer than 255 characters
    lv_res_body = `{"S_FRONT":{"ID":"ZZCKUT2","APP":"ZCL_ORDER","PROTOCOL":2,"S_ACTION":{"T_SYSTEM":` &&
                  `[["VIEW_SLOTS","display","MAIN","<mvc:View xmlns=\"sap.m\" xmlns:mvc=\"sap.ui.core.mvc\">` &&
                  `<Page title=\"Order\"><Label text=\"Customer\"/><Input value=\"{/MV_CUSTOMER}\"/>` &&
                  `<Button text=\"Save\" press=\".eB(['SAVE'])\"/></Page></mvc:View>"]]}},` &&
                  `"MODEL":{"MV_CUSTOMER":"4711"}}`.

    " the recorder saw step 2 display the screen and step 3 come from a
    " press on Save with a customer typed - and answer with an error

    CLEAR temp124.

    lt_wire = temp124.

    CLEAR temp125.
    temp125-id = `ZZCKUTWS2`.
    temp125-timestampl = `20991231100005.0`.
    temp125-utc_day = `20991231`.
    temp125-app = c_app.
    temp125-draft_id = `ZZCKUT2`.
    temp125-draft_id_prev = `ZZCKUT1`.
    temp125-http_status = 200.
    temp125-req_body = `{"S_FRONT":{"ID":"ZZCKUT1"}}`.
    temp125-res_body = lv_res_body.

    ls_wire = temp125.
    INSERT z2ui5_t_28 FROM ls_wire.
    APPEND ls_wire-id TO lt_wire.
    CLEAR ls_wire.
    ls_wire-id = `ZZCKUTWS3`.
    ls_wire-timestampl = `20991231100105.0`.
    ls_wire-utc_day = `20991231`.
    ls_wire-app = c_app.
    ls_wire-event = `SAVE`.
    ls_wire-draft_id = `ZZCKUT3`.
    ls_wire-draft_id_prev = `ZZCKUT2`.
    ls_wire-http_status = 200.
    ls_wire-req_body = `{"S_FRONT":{"ID":"ZZCKUT2","EVENT":"SAVE"},"MODEL":{"MV_CUSTOMER":"4712"}}`.
    ls_wire-res_body = `{"S_FRONT":{"ID":"ZZCKUT3","APP":"ZCL_ORDER","PROTOCOL":2,"S_ACTION":` &&
`{"T_CUSTOM":[["MESSAGE_BOX","error","Customer 4712 is blocked"]]}}}`.
    INSERT z2ui5_t_28 FROM ls_wire.
    APPEND ls_wire-id TO lt_wire.


    ls_steps = z2ui5_cl_cockpit_session=>get_steps( `ZZCKUT1` ).



    temp127 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp126>.
    sy-tabix = temp127.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUTWS3`
                                        act = <temp126>-wire_id ).


    temp129 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp128>.
    sy-tabix = temp129.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `pressed Button "Save" (SAVE), typed Input "Customer" = 4712`
                                        act = <temp128>-did ).


    temp131 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp130>.
    sy-tabix = temp131.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `error box: Customer 4712 is blocked`
                                        act = <temp130>-shown ).


    temp133 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp132>.
    sy-tabix = temp133.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = <temp132>-shown_state ).

    " the screen of step 3: the view of step 2 with the customer the user typed

    ls_screen = z2ui5_cl_cockpit_wire=>get_screen( lt_wire ).
    cl_abap_unit_assert=>assert_initial( ls_screen-error ).
    cl_abap_unit_assert=>assert_equals( exp = `Order`
                                        act = ls_screen-title ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*<Input value="4712"/>*<Button text="Save" press=""/>*`
                                         act = ls_screen-content ).

  ENDMETHOD.

  METHOD failures_and_app_objects.

    " steps 2 and 3 as the failing states: step 1 is a baseline of the app
    DATA temp134 TYPE z2ui5_cl_cockpit_session=>ty_t_id.
    DATA ls_failures TYPE z2ui5_cl_cockpit_session=>ty_s_failures.
    DATA temp3 TYPE xsdboolean.
    DATA ls_objects TYPE z2ui5_cl_cockpit_session=>ty_s_app_objects.
    DATA temp4 TYPE xsdboolean.
    FIELD-SYMBOLS <temp136> LIKE LINE OF ls_objects-t_object.
    DATA temp137 LIKE sy-tabix.
    CLEAR temp134.
    INSERT `ZZCKUT2` INTO TABLE temp134.
    INSERT `ZZCKUT3` INTO TABLE temp134.

    ls_failures = z2ui5_cl_cockpit_session=>analyze_failures( it_id = temp134
                                                                   app   = `ZCL_ORDER` ).

    cl_abap_unit_assert=>assert_initial( ls_failures-error ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_failures-failing ).

    temp3 = boolc( ls_failures-others >= 1 ).
    cl_abap_unit_assert=>assert_true( temp3 ).
    " MV_MODE = edit is in every state, the customers differ - no hint
    cl_abap_unit_assert=>assert_initial( ls_failures-t_common ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( ls_failures-t_business ) ).


    ls_objects = z2ui5_cl_cockpit_session=>get_app_objects( `ZCL_ORDER` ).
    cl_abap_unit_assert=>assert_initial( ls_objects-error ).

    temp4 = boolc( ls_objects-drafts >= 3 ).
    cl_abap_unit_assert=>assert_true( temp4 ).


    temp137 = sy-tabix.
    READ TABLE ls_objects-t_object INDEX 1 ASSIGNING <temp136>.
    sy-tabix = temp137.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Customer`
                                        act = <temp136>-object ).

  ENDMETHOD.

  METHOD search_in_drafts.

    DATA lv_found TYPE abap_bool.

    DATA ls_find TYPE z2ui5_cl_cockpit_session=>ty_s_find.
    DATA ls_hit LIKE LINE OF ls_find-t_hit.
    ls_find = z2ui5_cl_cockpit_session=>search_drafts( `4711` ).

    cl_abap_unit_assert=>assert_initial( ls_find-error ).

    LOOP AT ls_find-t_hit INTO ls_hit WHERE id = `ZZCKUT2`. "#EC CI_SORTSEQ
      cl_abap_unit_assert=>assert_equals( exp = `ZZCKUT1`
                                          act = ls_hit-session ).
      cl_abap_unit_assert=>assert_equals( exp = `ZCL_ORDER-MV_CUSTOMER`
                                          act = ls_hit-path ).
      cl_abap_unit_assert=>assert_equals( exp = `ZCL_ORDER`
                                          act = ls_hit-app ).
      lv_found = abap_true.
    ENDLOOP.
    cl_abap_unit_assert=>assert_true( lv_found ).

    ls_find = z2ui5_cl_cockpit_session=>search_drafts( `47` ).
    cl_abap_unit_assert=>assert_not_initial( ls_find-error ).

  ENDMETHOD.

  METHOD export_as_text.

    DATA lv_text TYPE string.
    lv_text = z2ui5_cl_cockpit_session=>export( id   = `ZZCKUT1`
                                                     user = `ZZ_COCKPIT_UT` ).

    cl_abap_unit_assert=>assert_char_cp( exp = `abap2UI5 session ZZCKUT1*user: ZZ_COCKPIT_UT*3 steps*`
                                         act = lv_text ).
    " the first step in full, then only what changed
    cl_abap_unit_assert=>assert_char_cp( exp = `*== Step 1*ZCL_ORDER-MV_MODE = edit*== Step 2*`
                                         act = lv_text ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*== Step 3*event SAVE*slow: 2500 ms*changed  ZCL_ORDER-MV_CUSTOMER = 4712*(before: 4711)*`
                                         act = lv_text ).
    cl_abap_unit_assert=>assert_char_np( exp = `*== Step 3*MV_MODE*`
                                         act = lv_text ).

  ENDMETHOD.

  METHOD session_of_a_draft.

    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUT1`
                                        act = z2ui5_cl_cockpit_session=>get_session_of( `ZZCKUT3` ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_session=>get_session_of( `ZZCKUT_GONE` ) ).

  ENDMETHOD.

ENDCLASS.
