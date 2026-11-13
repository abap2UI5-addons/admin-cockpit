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
    DATA temp9 TYPE string_table.
    DATA lt_value TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA ls_value LIKE LINE OF lt_value.
    CREATE OBJECT lo_order TYPE ltcl_order.
    lo_order->mv_customer = `ACME & Co`.
    CLEAR lo_order->ms_head.
    lo_order->ms_head-qty = 7.
    lo_order->ms_head-note = `urgent`.

    CLEAR temp9.
    INSERT `first` INTO TABLE temp9.
    INSERT `second` INTO TABLE temp9.
    lo_order->mt_lines = temp9.
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

    DATA temp11 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp12 LIKE LINE OF temp11.
    DATA lt_old LIKE temp11.
    DATA temp13 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp14 LIKE LINE OF temp13.
    DATA lt_new LIKE temp13.
    DATA lt_field TYPE z2ui5_cl_cockpit_session=>ty_t_field.
    DATA temp15 TYPE z2ui5_cl_cockpit_session=>ty_s_field.
    FIELD-SYMBOLS <temp1> LIKE LINE OF lt_field.
    DATA temp2 LIKE sy-tabix.
    DATA temp16 TYPE z2ui5_cl_cockpit_session=>ty_s_field.
    FIELD-SYMBOLS <temp3> LIKE LINE OF lt_field.
    DATA temp4 LIKE sy-tabix.
    FIELD-SYMBOLS <temp17> LIKE LINE OF lt_field.
    DATA temp18 LIKE sy-tabix.
    DATA temp19 TYPE z2ui5_cl_cockpit_session=>ty_s_field.
    FIELD-SYMBOLS <temp5> LIKE LINE OF lt_field.
    DATA temp6 LIKE sy-tabix.
    CLEAR temp11.

    temp12-path = `APP-A`.
    temp12-value = `1`.
    INSERT temp12 INTO TABLE temp11.
    temp12-path = `APP-B`.
    temp12-value = `x`.
    INSERT temp12 INTO TABLE temp11.
    temp12-path = `APP-GONE`.
    temp12-value = `old`.
    INSERT temp12 INTO TABLE temp11.

    lt_old = temp11.

    CLEAR temp13.

    temp14-path = `APP-A`.
    temp14-value = `1`.
    INSERT temp14 INTO TABLE temp13.
    temp14-path = `APP-B`.
    temp14-value = `y`.
    INSERT temp14 INTO TABLE temp13.
    temp14-path = `APP-NEW`.
    temp14-value = `typed`.
    INSERT temp14 INTO TABLE temp13.

    lt_new = temp13.


    lt_field = z2ui5_cl_cockpit_session=>diff( it_new = lt_new
                                                    it_old = lt_old ).

    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = lines( lt_field ) ).

    CLEAR temp15.
    temp15-path = `APP-A`.
    temp15-value = `1`.
    temp15-state = `None`.


    temp2 = sy-tabix.
    READ TABLE lt_field INDEX 1 ASSIGNING <temp1>.
    sy-tabix = temp2.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = temp15
                                        act = <temp1> ).

    CLEAR temp16.
    temp16-path = `APP-B`.
    temp16-value = `y`.
    temp16-prev = `x`.
    temp16-change = z2ui5_cl_cockpit_session=>cs_change-changed.
    temp16-state = `Warning`.


    temp4 = sy-tabix.
    READ TABLE lt_field INDEX 2 ASSIGNING <temp3>.
    sy-tabix = temp4.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = temp16
                                        act = <temp3> ).


    temp18 = sy-tabix.
    READ TABLE lt_field INDEX 3 ASSIGNING <temp17>.
    sy-tabix = temp18.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_session=>cs_change-new
                                        act = <temp17>-change ).

    CLEAR temp19.
    temp19-path = `APP-GONE`.
    temp19-prev = `old`.
    temp19-change = z2ui5_cl_cockpit_session=>cs_change-removed.
    temp19-state = `Error`.


    temp6 = sy-tabix.
    READ TABLE lt_field INDEX 4 ASSIGNING <temp5>.
    sy-tabix = temp6.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = temp19
                                        act = <temp5> ).

  ENDMETHOD.

  METHOD diff_first_step.

    DATA temp20 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp21 LIKE LINE OF temp20.
    DATA lt_new LIKE temp20.
    DATA lt_field TYPE z2ui5_cl_cockpit_session=>ty_t_field.
    FIELD-SYMBOLS <temp22> LIKE LINE OF lt_field.
    DATA temp23 LIKE sy-tabix.
    CLEAR temp20.

    temp21-path = `APP-A`.
    temp21-value = `1`.
    INSERT temp21 INTO TABLE temp20.

    lt_new = temp20.


    lt_field = z2ui5_cl_cockpit_session=>diff( it_new      = lt_new
                                                    check_first = abap_true ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_field ) ).


    temp23 = sy-tabix.
    READ TABLE lt_field INDEX 1 ASSIGNING <temp22>.
    sy-tabix = temp23.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_initial( <temp22>-change ).

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
    FIELD-SYMBOLS <temp24> LIKE LINE OF lt_step.
    DATA temp25 LIKE sy-tabix.
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
    lt_node = nodes( ).

    lt_step = z2ui5_cl_cockpit_session=>steps_of( it_node = lt_node
                                                       it_root = z2ui5_cl_cockpit_session=>roots_of( lt_node )
                                                       id      = `A` ).

    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = lines( lt_step ) ).


    temp25 = sy-tabix.
    READ TABLE lt_step INDEX 1 ASSIGNING <temp24>.
    sy-tabix = temp25.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `app start`
                                        act = <temp24>-note ).


    temp27 = sy-tabix.
    READ TABLE lt_step INDEX 2 ASSIGNING <temp26>.
    sy-tabix = temp27.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `+10 s`
                                        act = <temp26>-delta ).


    temp29 = sy-tabix.
    READ TABLE lt_step INDEX 3 ASSIGNING <temp28>.
    sy-tabix = temp29.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = <temp28>-follows ).


    temp31 = sy-tabix.
    READ TABLE lt_step INDEX 3 ASSIGNING <temp30>.
    sy-tabix = temp31.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_initial( <temp30>-note ).
    " D continues B, not C


    temp33 = sy-tabix.
    READ TABLE lt_step INDEX 4 ASSIGNING <temp32>.
    sy-tabix = temp33.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `D`
                                        act = <temp32>-id ).


    temp35 = sy-tabix.
    READ TABLE lt_step INDEX 4 ASSIGNING <temp34>.
    sy-tabix = temp35.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = <temp34>-follows ).


    temp37 = sy-tabix.
    READ TABLE lt_step INDEX 4 ASSIGNING <temp36>.
    sy-tabix = temp37.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_char_cp( exp = `continues step 2*`
                                         act = <temp36>-note ).


    temp39 = sy-tabix.
    READ TABLE lt_step INDEX 4 ASSIGNING <temp38>.
    sy-tabix = temp39.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `+1 min 10 s`
                                        act = <temp38>-delta ).

    lt_step = z2ui5_cl_cockpit_session=>steps_of( it_node = lt_node
                                                 it_root = z2ui5_cl_cockpit_session=>roots_of( lt_node )
                                                 id      = `F` ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_step ) ).


    temp41 = sy-tabix.
    READ TABLE lt_step INDEX 1 ASSIGNING <temp40>.
    sy-tabix = temp41.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `the steps before it expired`
                                        act = <temp40>-note ).

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

    DATA temp42 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp43 LIKE LINE OF temp42.
    DATA lt_business TYPE z2ui5_cl_cockpit_session=>ty_t_business.
    DATA temp44 TYPE z2ui5_cl_cockpit_session=>ty_t_business.
    DATA temp45 LIKE LINE OF temp44.
    CLEAR temp42.

    temp43-path = `APP-MV_VBELN`.
    temp43-value = `4711`.
    INSERT temp43 INTO TABLE temp42.
    temp43-path = `APP-MS_HEAD-KUNNR`.
    temp43-value = `1000`.
    INSERT temp43 INTO TABLE temp42.
    temp43-path = `APP-MT_ITEMS[1]-MATNR`.
    temp43-value = `M1`.
    INSERT temp43 INTO TABLE temp42.
    temp43-path = `APP-MT_ITEMS[2]-MATNR`.
    temp43-value = `M1`.
    INSERT temp43 INTO TABLE temp42.
    temp43-path = `APP-MV_CUSTOMER`.
    temp43-value = ``.
    INSERT temp43 INTO TABLE temp42.
    temp43-path = `APP-MS_HEAD-WERKS`.
    temp43-value = `0000`.
    INSERT temp43 INTO TABLE temp42.
    temp43-path = `APP-MO_KUNNR`.
    temp43-value = `-> ZCL_X`.
    INSERT temp43 INTO TABLE temp42.
    temp43-path = `APP-MV_TEXT`.
    temp43-value = `4711`.
    INSERT temp43 INTO TABLE temp42.

    lt_business = z2ui5_cl_cockpit_session=>business_of(
        temp42 ).


    CLEAR temp44.

    temp45-object = `Sales document`.
    temp45-value = `4711`.
    temp45-field = `APP-MV_VBELN`.
    INSERT temp45 INTO TABLE temp44.
    temp45-object = `Customer`.
    temp45-value = `1000`.
    temp45-field = `APP-MS_HEAD-KUNNR`.
    INSERT temp45 INTO TABLE temp44.
    temp45-object = `Material`.
    temp45-value = `M1`.
    temp45-field = `APP-MT_ITEMS[1]-MATNR`.
    INSERT temp45 INTO TABLE temp44.
    cl_abap_unit_assert=>assert_equals(
        exp = temp44
        act = lt_business ).

  ENDMETHOD.

  METHOD messages_in_state.

    " a BAPI return with an error and a success, a UI structure whose TYPE
    " is no message type, an error with a TEXT and a warning with MSG
    DATA temp46 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp47 LIKE LINE OF temp46.
    DATA lt_message TYPE z2ui5_cl_cockpit_session=>ty_t_message.
    DATA temp48 TYPE z2ui5_cl_cockpit_session=>ty_t_message.
    DATA temp49 LIKE LINE OF temp48.
    CLEAR temp46.

    temp47-path = `APP-MT_RETURN[1]-TYPE`.
    temp47-value = `E`.
    INSERT temp47 INTO TABLE temp46.
    temp47-path = `APP-MT_RETURN[1]-MESSAGE`.
    temp47-value = `Quantity must be greater than 0`.
    INSERT temp47 INTO TABLE temp46.
    temp47-path = `APP-MT_RETURN[2]-TYPE`.
    temp47-value = `S`.
    INSERT temp47 INTO TABLE temp46.
    temp47-path = `APP-MT_RETURN[2]-MESSAGE`.
    temp47-value = `Saved`.
    INSERT temp47 INTO TABLE temp46.
    temp47-path = `APP-MS_BUTTON-TYPE`.
    temp47-value = `Emphasized`.
    INSERT temp47 INTO TABLE temp46.
    temp47-path = `APP-MS_BUTTON-TEXT`.
    temp47-value = `Save`.
    INSERT temp47 INTO TABLE temp46.
    temp47-path = `APP-MS_LOCK-SEVERITY`.
    temp47-value = `error`.
    INSERT temp47 INTO TABLE temp46.
    temp47-path = `APP-MS_LOCK-TEXT`.
    temp47-value = `Order is locked by USER2`.
    INSERT temp47 INTO TABLE temp46.
    temp47-path = `APP-MS_CHECK-MSGTY`.
    temp47-value = `W`.
    INSERT temp47 INTO TABLE temp46.
    temp47-path = `APP-MS_CHECK-MSG`.
    temp47-value = `Delivery date in the past`.
    INSERT temp47 INTO TABLE temp46.

    lt_message = z2ui5_cl_cockpit_session=>messages_of(
        temp46 ).


    CLEAR temp48.

    temp49-type = `E`.
    temp49-text = `Quantity must be greater than 0`.
    temp49-path = `APP-MT_RETURN[1]`.
    INSERT temp49 INTO TABLE temp48.
    temp49-type = `ERROR`.
    temp49-text = `Order is locked by USER2`.
    temp49-path = `APP-MS_LOCK`.
    INSERT temp49 INTO TABLE temp48.
    temp49-type = `W`.
    temp49-text = `Delivery date in the past`.
    temp49-path = `APP-MS_CHECK`.
    INSERT temp49 INTO TABLE temp48.
    cl_abap_unit_assert=>assert_equals(
        exp = temp48
        act = lt_message ).

  ENDMETHOD.

  METHOD common_values_of_failures.

    " QTY = 0 in all three failing states and in one of four others: the
    " hint. MODE = edit everywhere: no hint. NOTE = x in two of three: too few
    DATA temp50 TYPE z2ui5_cl_cockpit_session=>ty_t_sample.
    DATA temp51 LIKE LINE OF temp50.
    DATA lt_failing LIKE temp50.
    DATA temp52 TYPE z2ui5_cl_cockpit_session=>ty_t_sample.
    DATA temp53 LIKE LINE OF temp52.
    DATA lt_others LIKE temp52.
    DATA lt_common TYPE z2ui5_cl_cockpit_session=>ty_t_common.
    DATA temp54 TYPE z2ui5_cl_cockpit_session=>ty_s_common.
    FIELD-SYMBOLS <temp7> LIKE LINE OF lt_common.
    DATA temp8 LIKE sy-tabix.
    DATA temp55 TYPE z2ui5_cl_cockpit_session=>ty_t_sample.
    CLEAR temp50.

    temp51-sample = 1.
    temp51-path = `APP-QTY`.
    temp51-value = `0`.
    INSERT temp51 INTO TABLE temp50.
    temp51-sample = 1.
    temp51-path = `APP-MODE`.
    temp51-value = `edit`.
    INSERT temp51 INTO TABLE temp50.
    temp51-sample = 1.
    temp51-path = `APP-NOTE`.
    temp51-value = `x`.
    INSERT temp51 INTO TABLE temp50.
    temp51-sample = 2.
    temp51-path = `APP-QTY`.
    temp51-value = `0`.
    INSERT temp51 INTO TABLE temp50.
    temp51-sample = 2.
    temp51-path = `APP-MODE`.
    temp51-value = `edit`.
    INSERT temp51 INTO TABLE temp50.
    temp51-sample = 2.
    temp51-path = `APP-NOTE`.
    temp51-value = `x`.
    INSERT temp51 INTO TABLE temp50.
    temp51-sample = 3.
    temp51-path = `APP-QTY`.
    temp51-value = `0`.
    INSERT temp51 INTO TABLE temp50.
    temp51-sample = 3.
    temp51-path = `APP-MODE`.
    temp51-value = `edit`.
    INSERT temp51 INTO TABLE temp50.
    temp51-sample = 3.
    temp51-path = `APP-NOTE`.
    temp51-value = `y`.
    INSERT temp51 INTO TABLE temp50.

    lt_failing = temp50.

    CLEAR temp52.

    temp53-sample = 1.
    temp53-path = `APP-QTY`.
    temp53-value = `0`.
    INSERT temp53 INTO TABLE temp52.
    temp53-sample = 1.
    temp53-path = `APP-MODE`.
    temp53-value = `edit`.
    INSERT temp53 INTO TABLE temp52.
    temp53-sample = 2.
    temp53-path = `APP-QTY`.
    temp53-value = `5`.
    INSERT temp53 INTO TABLE temp52.
    temp53-sample = 2.
    temp53-path = `APP-MODE`.
    temp53-value = `edit`.
    INSERT temp53 INTO TABLE temp52.
    temp53-sample = 3.
    temp53-path = `APP-QTY`.
    temp53-value = `7`.
    INSERT temp53 INTO TABLE temp52.
    temp53-sample = 3.
    temp53-path = `APP-MODE`.
    temp53-value = `edit`.
    INSERT temp53 INTO TABLE temp52.
    temp53-sample = 4.
    temp53-path = `APP-QTY`.
    temp53-value = `1`.
    INSERT temp53 INTO TABLE temp52.
    temp53-sample = 4.
    temp53-path = `APP-MODE`.
    temp53-value = `edit`.
    INSERT temp53 INTO TABLE temp52.

    lt_others = temp52.


    lt_common = z2ui5_cl_cockpit_session=>common_of( it_failing = lt_failing
                                                          it_others  = lt_others ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_common ) ).

    CLEAR temp54.
    temp54-path = `APP-QTY`.
    temp54-value = `0`.
    temp54-failing = 3.
    temp54-of_failing = 3.
    temp54-others_pct = 25.
    temp54-text = `in 3 of 3 failing, in 25 % of 4 other states`.


    temp8 = sy-tabix.
    READ TABLE lt_common INDEX 1 ASSIGNING <temp7>.
    sy-tabix = temp8.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
        exp = temp54
        act = <temp7> ).

    " no baseline - nothing to tell the failing ones from

    CLEAR temp55.
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_session=>common_of( it_failing = lt_failing
                                                                             it_others  = temp55 ) ).

  ENDMETHOD.

  METHOD outcomes_after_errors.

    " nodes( ): B is continued by C and D, C and G are last steps - C long
    " ago, G "now"; X is no draft at all
    DATA temp56 TYPE z2ui5_cl_cockpit_session=>ty_t_id.
    DATA lt_outcome TYPE z2ui5_cl_cockpit_session=>ty_t_outcome.
    DATA temp58 TYPE z2ui5_cl_cockpit_session=>ty_t_outcome.
    DATA temp59 LIKE LINE OF temp58.
    CLEAR temp56.
    INSERT `B` INTO TABLE temp56.
    INSERT `C` INTO TABLE temp56.
    INSERT `G` INTO TABLE temp56.
    INSERT `X` INTO TABLE temp56.

    lt_outcome = z2ui5_cl_cockpit_session=>outcomes_of( it_node      = nodes( )
                                                              it_id        = temp56
                                                              ended_before = `20261008105000.0` ).


    CLEAR temp58.

    temp59-id = `B`.
    temp59-outcome = z2ui5_cl_cockpit_session=>cs_outcome-continued.
    temp59-state = `Success`.
    INSERT temp59 INTO TABLE temp58.
    temp59-id = `C`.
    temp59-outcome = z2ui5_cl_cockpit_session=>cs_outcome-stopped.
    temp59-state = `Error`.
    INSERT temp59 INTO TABLE temp58.
    temp59-id = `G`.
    temp59-outcome = z2ui5_cl_cockpit_session=>cs_outcome-open.
    temp59-state = `Information`.
    INSERT temp59 INTO TABLE temp58.
    temp59-id = `X`.
    temp59-outcome = z2ui5_cl_cockpit_session=>cs_outcome-unknown.
    temp59-state = `None`.
    INSERT temp59 INTO TABLE temp58.
    cl_abap_unit_assert=>assert_equals(
        exp = temp58
        act = lt_outcome ).

  ENDMETHOD.

  METHOD flows_with_ends.

    " the sessions of flows_between_apps, all over: D's roundtrip failed
    DATA temp60 TYPE z2ui5_cl_cockpit_session=>ty_t_link.
    DATA temp61 LIKE LINE OF temp60.
    DATA temp9 TYPE z2ui5_cl_cockpit_session=>ty_t_id.
    DATA lt_flow TYPE z2ui5_cl_cockpit_session=>ty_t_flow.
    DATA temp62 TYPE z2ui5_cl_cockpit_session=>ty_t_flow.
    DATA temp63 LIKE LINE OF temp62.
    CLEAR temp60.

    CLEAR temp61.
    temp61-id = `A`.
    temp61-app = `X`.
    INSERT temp61 INTO TABLE temp60.
    CLEAR temp61.
    temp61-id = `B`.
    temp61-id_prev = `A`.
    temp61-app = `X`.
    INSERT temp61 INTO TABLE temp60.
    CLEAR temp61.
    temp61-id = `C`.
    temp61-id_prev = `B`.
    temp61-app = `Y`.
    INSERT temp61 INTO TABLE temp60.
    CLEAR temp61.
    temp61-id = `D`.
    temp61-id_prev = `C`.
    temp61-app = `X`.
    INSERT temp61 INTO TABLE temp60.
    CLEAR temp61.
    temp61-id = `E`.
    temp61-id_prev = `GONE`.
    temp61-app = `Z`.
    INSERT temp61 INTO TABLE temp60.
    CLEAR temp61.
    temp61-id = `F`.
    temp61-id_prev = ``.
    temp61-app = `Y`.
    INSERT temp61 INTO TABLE temp60.

    CLEAR temp9.
    INSERT `D` INTO TABLE temp9.

    lt_flow = z2ui5_cl_cockpit_session=>flows_of(
        it_link      = temp60
        it_failed    = temp9
        ended_before = `20991231000000.0` ).


    CLEAR temp62.

    temp63-source = `(start)`.
    temp63-target = `X`.
    temp63-count = 1.
    INSERT temp63 INTO TABLE temp62.
    temp63-source = `(start)`.
    temp63-target = `Y`.
    temp63-count = 1.
    INSERT temp63 INTO TABLE temp62.
    temp63-source = `X`.
    temp63-target = `(end after an error)`.
    temp63-count = 1.
    INSERT temp63 INTO TABLE temp62.
    temp63-source = `X`.
    temp63-target = `Y`.
    temp63-count = 1.
    INSERT temp63 INTO TABLE temp62.
    temp63-source = `Y`.
    temp63-target = `(end)`.
    temp63-count = 1.
    INSERT temp63 INTO TABLE temp62.
    temp63-source = `Y`.
    temp63-target = `X`.
    temp63-count = 1.
    INSERT temp63 INTO TABLE temp62.
    temp63-source = `Z`.
    temp63-target = `(end)`.
    temp63-count = 1.
    INSERT temp63 INTO TABLE temp62.
    cl_abap_unit_assert=>assert_equals(
        exp = temp62
        act = lt_flow ).

  ENDMETHOD.

  METHOD growth_of_tables.

    " MT_LOG grows from 1 to 3 rows, the nested T_SUB of row 1 from 1 to 2,
    " MT_SAME keeps its row
    DATA temp64 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp65 LIKE LINE OF temp64.
    DATA lt_before LIKE temp64.
    DATA temp66 TYPE z2ui5_cl_cockpit_session=>ty_t_value.
    DATA temp67 LIKE LINE OF temp66.
    DATA lt_after LIKE temp66.
    DATA temp68 TYPE z2ui5_cl_cockpit_session=>ty_t_growth.
    DATA temp69 LIKE LINE OF temp68.
    CLEAR temp64.

    temp65-path = `APP-MT_LOG[1]-TEXT`.
    temp65-value = `a`.
    INSERT temp65 INTO TABLE temp64.
    temp65-path = `APP-MT_A[1]-T_SUB[1]-X`.
    temp65-value = `1`.
    INSERT temp65 INTO TABLE temp64.
    temp65-path = `APP-MT_SAME[1]`.
    temp65-value = `s`.
    INSERT temp65 INTO TABLE temp64.

    lt_before = temp64.

    CLEAR temp66.

    temp67-path = `APP-MT_LOG[1]-TEXT`.
    temp67-value = `a`.
    INSERT temp67 INTO TABLE temp66.
    temp67-path = `APP-MT_LOG[1]-NR`.
    temp67-value = `1`.
    INSERT temp67 INTO TABLE temp66.
    temp67-path = `APP-MT_LOG[2]-TEXT`.
    temp67-value = `b`.
    INSERT temp67 INTO TABLE temp66.
    temp67-path = `APP-MT_LOG[3]-TEXT`.
    temp67-value = `c`.
    INSERT temp67 INTO TABLE temp66.
    temp67-path = `APP-MT_A[1]-T_SUB[1]-X`.
    temp67-value = `1`.
    INSERT temp67 INTO TABLE temp66.
    temp67-path = `APP-MT_A[1]-T_SUB[2]-X`.
    temp67-value = `2`.
    INSERT temp67 INTO TABLE temp66.
    temp67-path = `APP-MT_SAME[1]`.
    temp67-value = `t`.
    INSERT temp67 INTO TABLE temp66.

    lt_after = temp66.


    CLEAR temp68.

    temp69-path = `APP-MT_LOG`.
    temp69-rows_before = 1.
    temp69-rows_after = 3.
    INSERT temp69 INTO TABLE temp68.
    temp69-path = `APP-MT_A[1]-T_SUB`.
    temp69-rows_before = 1.
    temp69-rows_after = 2.
    INSERT temp69 INTO TABLE temp68.
    cl_abap_unit_assert=>assert_equals(
        exp = temp68
        act = z2ui5_cl_cockpit_session=>growth_of( it_before = lt_before
                                                   it_after  = lt_after ) ).

  ENDMETHOD.

  METHOD flows_between_apps.

    " two sessions: X -> X -> Y -> X and one starting in Y; E's predecessor
    " is gone, so it is neither a start nor a navigation
    DATA temp70 TYPE z2ui5_cl_cockpit_session=>ty_t_link.
    DATA temp71 LIKE LINE OF temp70.
    DATA lt_flow TYPE z2ui5_cl_cockpit_session=>ty_t_flow.
    DATA temp72 TYPE z2ui5_cl_cockpit_session=>ty_t_flow.
    DATA temp73 LIKE LINE OF temp72.
    CLEAR temp70.

    CLEAR temp71.
    temp71-id = `A`.
    temp71-app = `X`.
    INSERT temp71 INTO TABLE temp70.
    CLEAR temp71.
    temp71-id = `B`.
    temp71-id_prev = `A`.
    temp71-app = `X`.
    INSERT temp71 INTO TABLE temp70.
    CLEAR temp71.
    temp71-id = `C`.
    temp71-id_prev = `B`.
    temp71-app = `Y`.
    INSERT temp71 INTO TABLE temp70.
    CLEAR temp71.
    temp71-id = `D`.
    temp71-id_prev = `C`.
    temp71-app = `X`.
    INSERT temp71 INTO TABLE temp70.
    CLEAR temp71.
    temp71-id = `E`.
    temp71-id_prev = `GONE`.
    temp71-app = `Z`.
    INSERT temp71 INTO TABLE temp70.
    CLEAR temp71.
    temp71-id = `F`.
    temp71-id_prev = ``.
    temp71-app = `Y`.
    INSERT temp71 INTO TABLE temp70.

    lt_flow = z2ui5_cl_cockpit_session=>flows_of( temp70 ).


    CLEAR temp72.

    temp73-source = `(start)`.
    temp73-target = `X`.
    temp73-count = 1.
    INSERT temp73 INTO TABLE temp72.
    temp73-source = `(start)`.
    temp73-target = `Y`.
    temp73-count = 1.
    INSERT temp73 INTO TABLE temp72.
    temp73-source = `X`.
    temp73-target = `Y`.
    temp73-count = 1.
    INSERT temp73 INTO TABLE temp72.
    temp73-source = `Y`.
    temp73-target = `X`.
    temp73-count = 1.
    INSERT temp73 INTO TABLE temp72.
    cl_abap_unit_assert=>assert_equals(
        exp = temp72
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
    DATA temp74 LIKE lt_draft.
    DATA temp75 LIKE LINE OF temp74.
    DATA ls_draft LIKE LINE OF lt_draft.
    DATA temp76 TYPE z2ui5_t_25.
    DATA ls_log LIKE temp76.
    ls_set = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-name.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).


    CLEAR temp74.

    CLEAR temp75.
    temp75-uname = `ZZ_COCKPIT_UT`.
    temp75-id = `ZZCKUT1`.
    temp75-timestampl = `20991231100000.0`.
    temp75-data = order( `` ).
    INSERT temp75 INTO TABLE temp74.
    CLEAR temp75.
    temp75-uname = `ZZ_COCKPIT_UT`.
    temp75-id = `ZZCKUT2`.
    temp75-id_prev = `ZZCKUT1`.
    temp75-timestampl = `20991231100005.0`.
    temp75-data = order( `4711` ).
    INSERT temp75 INTO TABLE temp74.
    CLEAR temp75.
    temp75-uname = `ZZ_COCKPIT_UT`.
    temp75-id = `ZZCKUT3`.
    temp75-id_prev = `ZZCKUT2`.
    temp75-timestampl = `20991231100105.0`.
    temp75-data = order( `4712` ).
    INSERT temp75 INTO TABLE temp74.
    lt_draft = temp74.
    lv_tab = c_table.

    LOOP AT lt_draft INTO ls_draft.
      ls_draft-mandt = sy-mandt.
      INSERT (lv_tab) FROM ls_draft.
    ENDLOOP.

    " what the monitor logged: the slow roundtrip that wrote step 3, and a
    " failed one that started from step 2

    CLEAR temp76.
    temp76-id = `ZZCKUTLOG1`.
    temp76-timestampl = `20991231100105.0`.
    temp76-utc_day = `20991231`.
    temp76-app = c_app.
    temp76-event = `SAVE`.
    temp76-draft_id = `ZZCKUT3`.
    temp76-draft_id_prev = `ZZCKUT2`.
    temp76-check_slow = abap_true.
    temp76-ms_total = 2500.

    ls_log = temp76.
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
    DATA temp77 TYPE z2ui5_t_25-app.
    DATA lv_app LIKE temp77.
    DATA temp78 TYPE z2ui5_t_28-app.
    DATA lv_wire_app LIKE temp78.
    lv_tab = c_table.
    lv_pattern = `ZZCKUT%`.
    DELETE FROM (lv_tab) WHERE id LIKE lv_pattern.

    temp77 = c_app.

    lv_app = temp77.
    DELETE FROM z2ui5_t_25 WHERE app = lv_app.

    temp78 = c_app.

    lv_wire_app = temp78.
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

  METHOD session_listed.

    DATA ls_list TYPE z2ui5_cl_cockpit_session=>ty_s_list.
    DATA ls_session TYPE z2ui5_cl_cockpit_session=>ty_s_session.
    FIELD-SYMBOLS <temp11> LIKE LINE OF ls_list-t_session.
    DATA temp12 LIKE sy-tabix.
    FIELD-SYMBOLS <temp79> LIKE LINE OF ls_list-t_session.
    DATA temp80 LIKE sy-tabix.
    DATA temp1 TYPE xsdboolean.
    ls_list = z2ui5_cl_cockpit_session=>get_sessions( max_sessions = 1 ).

    cl_abap_unit_assert=>assert_true( ls_list-check_readable ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( ls_list-t_session ) ).



    temp12 = sy-tabix.
    READ TABLE ls_list-t_session INDEX 1 ASSIGNING <temp11>.
    sy-tabix = temp12.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    ls_session = <temp11>.
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


    temp80 = sy-tabix.
    READ TABLE ls_list-t_session INDEX 1 ASSIGNING <temp79>.
    sy-tabix = temp80.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUT1`
                                        act = <temp79>-id ).

    " the overview's count: no session listed, none read
    ls_list = z2ui5_cl_cockpit_session=>get_sessions( max_sessions = 0
                                                      check_errors = abap_true ).
    cl_abap_unit_assert=>assert_initial( ls_list-t_session ).

    temp1 = boolc( ls_list-sessions >= 1 ).
    cl_abap_unit_assert=>assert_true( temp1 ).

    ls_list = z2ui5_cl_cockpit_session=>get_sessions( max_sessions = 1
                                                      search       = `no such app` ).
    cl_abap_unit_assert=>assert_initial( ls_list-t_session ).

  ENDMETHOD.

  METHOD steps_and_changes.

    DATA ls_steps TYPE z2ui5_cl_cockpit_session=>ty_s_steps.
    FIELD-SYMBOLS <temp81> LIKE LINE OF ls_steps-t_step.
    DATA temp82 LIKE sy-tabix.
    DATA ls_step LIKE LINE OF ls_steps-t_step.
    FIELD-SYMBOLS <temp83> LIKE LINE OF ls_steps-t_step.
    DATA temp84 LIKE sy-tabix.
    FIELD-SYMBOLS <temp85> LIKE LINE OF ls_steps-t_step.
    DATA temp86 LIKE sy-tabix.
    FIELD-SYMBOLS <temp87> LIKE LINE OF ls_steps-t_step.
    DATA temp88 LIKE sy-tabix.
    DATA temp89 TYPE z2ui5_cl_cockpit_session=>ty_t_business.
    DATA temp90 LIKE LINE OF temp89.
    DATA ls_view TYPE z2ui5_cl_cockpit_session=>ty_s_view.
    DATA temp91 TYPE z2ui5_cl_cockpit_session=>ty_s_field.
    FIELD-SYMBOLS <temp13> LIKE LINE OF ls_view-t_field.
    DATA temp14 LIKE sy-tabix.
    ls_steps = z2ui5_cl_cockpit_session=>get_steps( `ZZCKUT1` ).

    cl_abap_unit_assert=>assert_initial( ls_steps-error ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( ls_steps-t_step ) ).


    temp82 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp81>.
    sy-tabix = temp82.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ZCL_ORDER`
                                        act = <temp81>-app ).
    " nothing recorded for these drafts - the states bound to an ObjectStatus
    " are still a ValueState, an empty one terminates the app

    LOOP AT ls_steps-t_step INTO ls_step.
      cl_abap_unit_assert=>assert_not_initial( ls_step-shown_state ).
      cl_abap_unit_assert=>assert_not_initial( ls_step-monitor_state ).
      cl_abap_unit_assert=>assert_not_initial( ls_step-messages_state ).
    ENDLOOP.


    temp84 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp83>.
    sy-tabix = temp84.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = <temp83>-kb ).


    temp86 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 2 ASSIGNING <temp85>.
    sy-tabix = temp86.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = <temp85>-changes ).


    temp88 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp87>.
    sy-tabix = temp88.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = <temp87>-changes ).

    CLEAR temp89.

    temp90-object = `Customer`.
    temp90-value = `4711`.
    temp90-field = `ZCL_ORDER-MV_CUSTOMER`.
    temp90-step = 2.
    INSERT temp90 INTO TABLE temp89.
    temp90-object = `Customer`.
    temp90-value = `4712`.
    temp90-field = `ZCL_ORDER-MV_CUSTOMER`.
    temp90-step = 3.
    INSERT temp90 INTO TABLE temp89.
    cl_abap_unit_assert=>assert_equals(
        exp = temp89
        act = ls_steps-t_business ).


    ls_view = z2ui5_cl_cockpit_session=>get_view( id            = `ZZCKUT3`
                                                       id_prev       = `ZZCKUT2`
                                                       check_changes = abap_true ).
    cl_abap_unit_assert=>assert_initial( ls_view-error ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_view-fields ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_view-changes ).

    CLEAR temp91.
    temp91-path = `ZCL_ORDER-MV_CUSTOMER`.
    temp91-value = `4712`.
    temp91-prev = `4711`.
    temp91-change = z2ui5_cl_cockpit_session=>cs_change-changed.
    temp91-state = `Warning`.


    temp14 = sy-tabix.
    READ TABLE ls_view-t_field INDEX 1 ASSIGNING <temp13>.
    sy-tabix = temp14.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = temp91
                                        act = <temp13> ).

    ls_view = z2ui5_cl_cockpit_session=>get_view( `ZZCKUT_GONE` ).
    cl_abap_unit_assert=>assert_not_initial( ls_view-error ).

  ENDMETHOD.

  METHOD monitor_marks_steps.

    DATA ls_steps TYPE z2ui5_cl_cockpit_session=>ty_s_steps.
    FIELD-SYMBOLS <temp92> LIKE LINE OF ls_steps-t_step.
    DATA temp93 LIKE sy-tabix.
    FIELD-SYMBOLS <temp94> LIKE LINE OF ls_steps-t_step.
    DATA temp95 LIKE sy-tabix.
    FIELD-SYMBOLS <temp96> LIKE LINE OF ls_steps-t_step.
    DATA temp97 LIKE sy-tabix.
    FIELD-SYMBOLS <temp98> LIKE LINE OF ls_steps-t_step.
    DATA temp99 LIKE sy-tabix.
    FIELD-SYMBOLS <temp100> LIKE LINE OF ls_steps-t_step.
    DATA temp101 LIKE sy-tabix.
    FIELD-SYMBOLS <temp102> LIKE LINE OF ls_steps-t_step.
    DATA temp103 LIKE sy-tabix.
    ls_steps = z2ui5_cl_cockpit_session=>get_steps( `ZZCKUT1` ).



    temp93 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 1 ASSIGNING <temp92>.
    sy-tabix = temp93.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `None`
                                        act = <temp92>-monitor_state ).


    temp95 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 2 ASSIGNING <temp94>.
    sy-tabix = temp95.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = <temp94>-monitor_state ).


    temp97 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 2 ASSIGNING <temp96>.
    sy-tabix = temp97.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_char_cp( exp = `*CX_SY_ZERODIVIDE*event POST*`
                                         act = <temp96>-monitor ).


    temp99 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp98>.
    sy-tabix = temp99.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Warning`
                                        act = <temp98>-monitor_state ).


    temp101 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp100>.
    sy-tabix = temp101.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `SAVE`
                                        act = <temp100>-event ).


    temp103 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp102>.
    sy-tabix = temp103.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `slow: 2500 ms`
                                        act = <temp102>-monitor ).

  ENDMETHOD.

  METHOD history_of_a_field.

    DATA ls_steps TYPE z2ui5_cl_cockpit_session=>ty_s_steps.
    DATA lt_history TYPE z2ui5_cl_cockpit_session=>ty_t_history.
    DATA temp104 TYPE z2ui5_cl_cockpit_session=>ty_s_history.
    FIELD-SYMBOLS <temp15> LIKE LINE OF lt_history.
    DATA temp16 LIKE sy-tabix.
    FIELD-SYMBOLS <temp105> LIKE LINE OF lt_history.
    DATA temp106 LIKE sy-tabix.
    FIELD-SYMBOLS <temp107> LIKE LINE OF lt_history.
    DATA temp108 LIKE sy-tabix.
    FIELD-SYMBOLS <temp109> LIKE LINE OF lt_history.
    DATA temp110 LIKE sy-tabix.
    FIELD-SYMBOLS <temp111> LIKE LINE OF lt_history.
    DATA temp112 LIKE sy-tabix.
    ls_steps = z2ui5_cl_cockpit_session=>get_steps( `ZZCKUT1` ).

    lt_history = z2ui5_cl_cockpit_session=>get_history( it_step = ls_steps-t_step
                                                             path    = `ZCL_ORDER-MV_CUSTOMER` ).

    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( lt_history ) ).

    CLEAR temp104.
    temp104-step = 1.
    temp104-time = `2099-12-31 10:00:00`.
    temp104-state = `None`.


    temp16 = sy-tabix.
    READ TABLE lt_history INDEX 1 ASSIGNING <temp15>.
    sy-tabix = temp16.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = temp104
                                        act = <temp15> ).


    temp106 = sy-tabix.
    READ TABLE lt_history INDEX 2 ASSIGNING <temp105>.
    sy-tabix = temp106.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `4711`
                                        act = <temp105>-value ).


    temp108 = sy-tabix.
    READ TABLE lt_history INDEX 2 ASSIGNING <temp107>.
    sy-tabix = temp108.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Warning`
                                        act = <temp107>-state ).


    temp110 = sy-tabix.
    READ TABLE lt_history INDEX 3 ASSIGNING <temp109>.
    sy-tabix = temp110.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `4712`
                                        act = <temp109>-value ).

    lt_history = z2ui5_cl_cockpit_session=>get_history( it_step = ls_steps-t_step
                                                       path    = `ZCL_ORDER-NO_SUCH_FIELD` ).


    temp112 = sy-tabix.
    READ TABLE lt_history INDEX 3 ASSIGNING <temp111>.
    sy-tabix = temp112.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `(not there)`
                                        act = <temp111>-value ).

  ENDMETHOD.

  METHOD playback_from_recordings.

    DATA lv_res_body TYPE string.
    DATA temp113 TYPE z2ui5_cl_cockpit_session=>ty_t_id.
    DATA lt_wire LIKE temp113.
    DATA temp114 TYPE z2ui5_t_28.
    DATA ls_wire LIKE temp114.
    DATA ls_steps TYPE z2ui5_cl_cockpit_session=>ty_s_steps.
    FIELD-SYMBOLS <temp115> LIKE LINE OF ls_steps-t_step.
    DATA temp116 LIKE sy-tabix.
    FIELD-SYMBOLS <temp117> LIKE LINE OF ls_steps-t_step.
    DATA temp118 LIKE sy-tabix.
    FIELD-SYMBOLS <temp119> LIKE LINE OF ls_steps-t_step.
    DATA temp120 LIKE sy-tabix.
    FIELD-SYMBOLS <temp121> LIKE LINE OF ls_steps-t_step.
    DATA temp122 LIKE sy-tabix.
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

    CLEAR temp113.

    lt_wire = temp113.

    CLEAR temp114.
    temp114-id = `ZZCKUTWS2`.
    temp114-timestampl = `20991231100005.0`.
    temp114-utc_day = `20991231`.
    temp114-app = c_app.
    temp114-draft_id = `ZZCKUT2`.
    temp114-draft_id_prev = `ZZCKUT1`.
    temp114-http_status = 200.
    temp114-req_body = `{"S_FRONT":{"ID":"ZZCKUT1"}}`.
    temp114-res_body = lv_res_body.

    ls_wire = temp114.
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



    temp116 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp115>.
    sy-tabix = temp116.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUTWS3`
                                        act = <temp115>-wire_id ).


    temp118 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp117>.
    sy-tabix = temp118.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `pressed Button "Save" (SAVE), typed Input "Customer" = 4712`
                                        act = <temp117>-did ).


    temp120 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp119>.
    sy-tabix = temp120.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `error box: Customer 4712 is blocked`
                                        act = <temp119>-shown ).


    temp122 = sy-tabix.
    READ TABLE ls_steps-t_step INDEX 3 ASSIGNING <temp121>.
    sy-tabix = temp122.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = <temp121>-shown_state ).

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
    DATA temp123 TYPE z2ui5_cl_cockpit_session=>ty_t_id.
    DATA ls_failures TYPE z2ui5_cl_cockpit_session=>ty_s_failures.
    DATA temp2 TYPE xsdboolean.
    DATA ls_objects TYPE z2ui5_cl_cockpit_session=>ty_s_app_objects.
    DATA temp3 TYPE xsdboolean.
    FIELD-SYMBOLS <temp125> LIKE LINE OF ls_objects-t_object.
    DATA temp126 LIKE sy-tabix.
    CLEAR temp123.
    INSERT `ZZCKUT2` INTO TABLE temp123.
    INSERT `ZZCKUT3` INTO TABLE temp123.

    ls_failures = z2ui5_cl_cockpit_session=>analyze_failures( it_id = temp123
                                                                   app   = `ZCL_ORDER` ).

    cl_abap_unit_assert=>assert_initial( ls_failures-error ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_failures-failing ).

    temp2 = boolc( ls_failures-others >= 1 ).
    cl_abap_unit_assert=>assert_true( temp2 ).
    " MV_MODE = edit is in every state, the customers differ - no hint
    cl_abap_unit_assert=>assert_initial( ls_failures-t_common ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( ls_failures-t_business ) ).


    ls_objects = z2ui5_cl_cockpit_session=>get_app_objects( `ZCL_ORDER` ).
    cl_abap_unit_assert=>assert_initial( ls_objects-error ).

    temp3 = boolc( ls_objects-drafts >= 3 ).
    cl_abap_unit_assert=>assert_true( temp3 ).


    temp126 = sy-tabix.
    READ TABLE ls_objects-t_object INDEX 1 ASSIGNING <temp125>.
    sy-tabix = temp126.
    IF sy-subrc <> 0.
      ASSERT 1 = 0.
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = `Customer`
                                        act = <temp125>-object ).

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
