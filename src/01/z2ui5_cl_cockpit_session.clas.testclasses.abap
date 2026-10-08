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
    result = VALUE #( ( id = `A` timestampl = `20261008100000.0` )
                      ( id = `B` id_prev = `A` timestampl = `20261008100010.0` )
                      ( id = `C` id_prev = `B` timestampl = `20261008100020.0` )
                      ( id = `D` id_prev = `B` timestampl = `20261008100130.0` )
                      ( id = `F` id_prev = `GONE` timestampl = `20261008110000.0` )
                      ( id = `G` id_prev = `F` timestampl = `20261008110005.0` ) ).

  ENDMETHOD.

  METHOD value_of.

    result = `(missing)`.
    LOOP AT it_value INTO DATA(ls_value) WHERE path = path. "#EC CI_SORTSEQ
      result = ls_value-value.
      RETURN.
    ENDLOOP.

  ENDMETHOD.

  METHOD signs_of_trouble.

    " every component written out - the downport the unit build runs carries
    " an omitted one over from the row before (see the wire tests)
    DATA(ls_signals) = z2ui5_cl_cockpit_session=>signals_of( VALUE #(
        ( timestampl = '20261008100000' event = `SAVE` http_status = 0 ms_browser = 0 error_text = `Date invalid` )
        ( timestampl = '20261008100003' event = `SAVE` http_status = 0 ms_browser = 0 error_text = `Date invalid` )
        ( timestampl = '20261008100006' event = `SAVE` http_status = 0 ms_browser = 0 error_text = `` )
        ( timestampl = '20261008100100' event = `NEXT` http_status = 0 ms_browser = 6000 error_text = `` )
        ( timestampl = '20261008100110' event = `NEXT` http_status = 0 ms_browser = 0 error_text = `` )
        ( timestampl = '20261008100200' event = `POST` http_status = 500 ms_browser = 0 error_text = `` ) ) ).

    cl_abap_unit_assert=>assert_equals(
        exp = `pressed SAVE 3 times in 6 s; error "Date invalid" 2 times; 1 failed click; ` &&
              `pressed NEXT again after waiting 6 s; ended on an error`
        act = ls_signals-text ).
    cl_abap_unit_assert=>assert_equals( exp = 11
                                        act = ls_signals-score ).
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = ls_signals-state ).

    " a quiet session: different buttons, no error
    ls_signals = z2ui5_cl_cockpit_session=>signals_of( VALUE #(
        ( timestampl = '20261008100000' event = `SEARCH` http_status = 0 ms_browser = 0 error_text = `` )
        ( timestampl = '20261008100002' event = `SAVE` http_status = 0 ms_browser = 0 error_text = `` ) ) ).
    cl_abap_unit_assert=>assert_initial( ls_signals-text ).
    cl_abap_unit_assert=>assert_equals( exp = `None`
                                        act = ls_signals-state ).

  ENDMETHOD.

  METHOD story_told.

    DATA(lv_nl) = cl_abap_char_utilities=>newline.
    DATA(lv_story) = z2ui5_cl_cockpit_session=>story_of( VALUE #(
        ( step = 1 time = `2026-10-08 10:02:11` app = `ZORDER` did = `` event = `` shown = ``
          ms_text = `` note = `` )
        ( step = 2 time = `2026-10-08 10:02:40` app = `ZORDER` did = `pressed Button "Save" (SAVE)`
          event = `SAVE` shown = `error box: Date invalid` ms_text = `1.2 s server, 6.2 s waited` note = `` )
        ( step = 3 time = `2026-10-08 10:03:20` app = `ZDELIVERY` did = `` event = `GO` shown = ``
          ms_text = `` note = `next click failed: event SHIP` ) ) ).

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

    DATA(lt_value) = z2ui5_cl_cockpit_session=>flatten( draft( ) ).

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

    DATA(lt_value) = z2ui5_cl_cockpit_session=>flatten( xml       = draft( )
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

    DATA(lv_xml) = `<asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">` &&
                   `<asx:values><DATA href="#o1"/></asx:values><asx:heap>` &&
                   `<cls:ZCL_A id="o1"><local.ZCL_A><MO_X href="#o2"/><MO_Y href="#o3"/></local.ZCL_A></cls:ZCL_A>` &&
                   `<cls:ZCL_B id="o2"><local.ZCL_B><V>1</V></local.ZCL_B></cls:ZCL_B>` &&
                   `<cls:ZCL_B id="o3"><local.ZCL_B><V>2</V></local.ZCL_B></cls:ZCL_B>` &&
                   `</asx:heap></asx:abap>`.

    DATA(lt_value) = z2ui5_cl_cockpit_session=>flatten( lv_xml ).

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

    DATA(lo_order) = NEW ltcl_order( ).
    lo_order->mv_customer = `ACME & Co`.
    lo_order->ms_head = VALUE #( qty  = 7
                                 note = `urgent` ).
    lo_order->mt_lines = VALUE #( ( `first` ) ( `second` ) ).
    lo_order->mo_item = NEW ltcl_item( ).
    lo_order->mo_item->mv_text = `inner`.

    CALL TRANSFORMATION id SOURCE data = lo_order RESULT XML lv_xml.
    DATA(lt_value) = z2ui5_cl_cockpit_session=>flatten( lv_xml ).

    " the label of a local class differs between systems - the paths below it do not
    LOOP AT lt_value INTO DATA(ls_value).
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

    DATA(lt_old) = VALUE z2ui5_cl_cockpit_session=>ty_t_value( ( path = `APP-A` value = `1` )
                                                                ( path = `APP-B` value = `x` )
                                                                ( path = `APP-GONE` value = `old` ) ).
    DATA(lt_new) = VALUE z2ui5_cl_cockpit_session=>ty_t_value( ( path = `APP-A` value = `1` )
                                                                ( path = `APP-B` value = `y` )
                                                                ( path = `APP-NEW` value = `typed` ) ).

    DATA(lt_field) = z2ui5_cl_cockpit_session=>diff( it_new = lt_new
                                                    it_old = lt_old ).

    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = lines( lt_field ) ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE z2ui5_cl_cockpit_session=>ty_s_field( path  = `APP-A`
                                                                                          value = `1`
                                                                                          state = `None` )
                                        act = lt_field[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE z2ui5_cl_cockpit_session=>ty_s_field(
                                                  path   = `APP-B`
                                                  value  = `y`
                                                  prev   = `x`
                                                  change = z2ui5_cl_cockpit_session=>cs_change-changed
                                                  state  = `Warning` )
                                        act = lt_field[ 2 ] ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_cl_cockpit_session=>cs_change-new
                                        act = lt_field[ 3 ]-change ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE z2ui5_cl_cockpit_session=>ty_s_field(
                                                  path   = `APP-GONE`
                                                  prev   = `old`
                                                  change = z2ui5_cl_cockpit_session=>cs_change-removed
                                                  state  = `Error` )
                                        act = lt_field[ 4 ] ).

  ENDMETHOD.

  METHOD diff_first_step.

    DATA(lt_new) = VALUE z2ui5_cl_cockpit_session=>ty_t_value( ( path = `APP-A` value = `1` ) ).

    DATA(lt_field) = z2ui5_cl_cockpit_session=>diff( it_new      = lt_new
                                                    check_first = abap_true ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_field ) ).
    cl_abap_unit_assert=>assert_initial( lt_field[ 1 ]-change ).

  ENDMETHOD.

  METHOD roots_follow_the_chain.

    DATA(lt_root) = z2ui5_cl_cockpit_session=>roots_of( nodes( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 6
                                        act = lines( lt_root ) ).
    LOOP AT lt_root INTO DATA(ls_root).
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

    DATA(lt_node) = nodes( ).
    DATA(lt_step) = z2ui5_cl_cockpit_session=>steps_of( it_node = lt_node
                                                       it_root = z2ui5_cl_cockpit_session=>roots_of( lt_node )
                                                       id      = `A` ).

    cl_abap_unit_assert=>assert_equals( exp = 4
                                        act = lines( lt_step ) ).
    cl_abap_unit_assert=>assert_equals( exp = `app start`
                                        act = lt_step[ 1 ]-note ).
    cl_abap_unit_assert=>assert_equals( exp = `+10 s`
                                        act = lt_step[ 2 ]-delta ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lt_step[ 3 ]-follows ).
    cl_abap_unit_assert=>assert_initial( lt_step[ 3 ]-note ).
    " D continues B, not C
    cl_abap_unit_assert=>assert_equals( exp = `D`
                                        act = lt_step[ 4 ]-id ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lt_step[ 4 ]-follows ).
    cl_abap_unit_assert=>assert_char_cp( exp = `continues step 2*`
                                         act = lt_step[ 4 ]-note ).
    cl_abap_unit_assert=>assert_equals( exp = `+1 min 10 s`
                                        act = lt_step[ 4 ]-delta ).

    lt_step = z2ui5_cl_cockpit_session=>steps_of( it_node = lt_node
                                                 it_root = z2ui5_cl_cockpit_session=>roots_of( lt_node )
                                                 id      = `F` ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_step ) ).
    cl_abap_unit_assert=>assert_equals( exp = `the steps before it expired`
                                        act = lt_step[ 1 ]-note ).

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

    DATA(lt_business) = z2ui5_cl_cockpit_session=>business_of(
        VALUE #( ( path = `APP-MV_VBELN` value = `4711` )
                 ( path = `APP-MS_HEAD-KUNNR` value = `1000` )
                 ( path = `APP-MT_ITEMS[1]-MATNR` value = `M1` )
                 ( path = `APP-MT_ITEMS[2]-MATNR` value = `M1` )
                 ( path = `APP-MV_CUSTOMER` value = `` )
                 ( path = `APP-MS_HEAD-WERKS` value = `0000` )
                 ( path = `APP-MO_KUNNR` value = `-> ZCL_X` )
                 ( path = `APP-MV_TEXT` value = `4711` ) ) ).

    cl_abap_unit_assert=>assert_equals(
        exp = VALUE z2ui5_cl_cockpit_session=>ty_t_business(
                  ( object = `Sales document` value = `4711` field = `APP-MV_VBELN` )
                  ( object = `Customer` value = `1000` field = `APP-MS_HEAD-KUNNR` )
                  ( object = `Material` value = `M1` field = `APP-MT_ITEMS[1]-MATNR` ) )
        act = lt_business ).

  ENDMETHOD.

  METHOD messages_in_state.

    " a BAPI return with an error and a success, a UI structure whose TYPE
    " is no message type, an error with a TEXT and a warning with MSG
    DATA(lt_message) = z2ui5_cl_cockpit_session=>messages_of(
        VALUE #( ( path = `APP-MT_RETURN[1]-TYPE` value = `E` )
                 ( path = `APP-MT_RETURN[1]-MESSAGE` value = `Quantity must be greater than 0` )
                 ( path = `APP-MT_RETURN[2]-TYPE` value = `S` )
                 ( path = `APP-MT_RETURN[2]-MESSAGE` value = `Saved` )
                 ( path = `APP-MS_BUTTON-TYPE` value = `Emphasized` )
                 ( path = `APP-MS_BUTTON-TEXT` value = `Save` )
                 ( path = `APP-MS_LOCK-SEVERITY` value = `error` )
                 ( path = `APP-MS_LOCK-TEXT` value = `Order is locked by USER2` )
                 ( path = `APP-MS_CHECK-MSGTY` value = `W` )
                 ( path = `APP-MS_CHECK-MSG` value = `Delivery date in the past` ) ) ).

    cl_abap_unit_assert=>assert_equals(
        exp = VALUE z2ui5_cl_cockpit_session=>ty_t_message(
                  ( type = `E` text = `Quantity must be greater than 0` path = `APP-MT_RETURN[1]` )
                  ( type = `ERROR` text = `Order is locked by USER2` path = `APP-MS_LOCK` )
                  ( type = `W` text = `Delivery date in the past` path = `APP-MS_CHECK` ) )
        act = lt_message ).

  ENDMETHOD.

  METHOD common_values_of_failures.

    " QTY = 0 in all three failing states and in one of four others: the
    " hint. MODE = edit everywhere: no hint. NOTE = x in two of three: too few
    DATA(lt_failing) = VALUE z2ui5_cl_cockpit_session=>ty_t_sample(
        ( sample = 1 path = `APP-QTY` value = `0` )
        ( sample = 1 path = `APP-MODE` value = `edit` )
        ( sample = 1 path = `APP-NOTE` value = `x` )
        ( sample = 2 path = `APP-QTY` value = `0` )
        ( sample = 2 path = `APP-MODE` value = `edit` )
        ( sample = 2 path = `APP-NOTE` value = `x` )
        ( sample = 3 path = `APP-QTY` value = `0` )
        ( sample = 3 path = `APP-MODE` value = `edit` )
        ( sample = 3 path = `APP-NOTE` value = `y` ) ).
    DATA(lt_others) = VALUE z2ui5_cl_cockpit_session=>ty_t_sample(
        ( sample = 1 path = `APP-QTY` value = `0` )
        ( sample = 1 path = `APP-MODE` value = `edit` )
        ( sample = 2 path = `APP-QTY` value = `5` )
        ( sample = 2 path = `APP-MODE` value = `edit` )
        ( sample = 3 path = `APP-QTY` value = `7` )
        ( sample = 3 path = `APP-MODE` value = `edit` )
        ( sample = 4 path = `APP-QTY` value = `1` )
        ( sample = 4 path = `APP-MODE` value = `edit` ) ).

    DATA(lt_common) = z2ui5_cl_cockpit_session=>common_of( it_failing = lt_failing
                                                          it_others  = lt_others ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( lt_common ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = VALUE z2ui5_cl_cockpit_session=>ty_s_common( path       = `APP-QTY`
                                                           value      = `0`
                                                           failing    = 3
                                                           of_failing = 3
                                                           others_pct = 25
                                                           text       = `in 3 of 3 failing, in 25 % of 4 other states` )
        act = lt_common[ 1 ] ).

    " no baseline - nothing to tell the failing ones from
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_session=>common_of( it_failing = lt_failing
                                                                             it_others  = VALUE #( ) ) ).

  ENDMETHOD.

  METHOD outcomes_after_errors.

    " nodes( ): B is continued by C and D, C and G are last steps - C long
    " ago, G "now"; X is no draft at all
    DATA(lt_outcome) = z2ui5_cl_cockpit_session=>outcomes_of( it_node      = nodes( )
                                                              it_id        = VALUE #( ( `B` ) ( `C` ) ( `G` ) ( `X` ) )
                                                              ended_before = `20261008105000.0` ).

    cl_abap_unit_assert=>assert_equals(
        exp = VALUE z2ui5_cl_cockpit_session=>ty_t_outcome(
                  ( id = `B` outcome = z2ui5_cl_cockpit_session=>cs_outcome-continued state = `Success` )
                  ( id = `C` outcome = z2ui5_cl_cockpit_session=>cs_outcome-stopped state = `Error` )
                  ( id = `G` outcome = z2ui5_cl_cockpit_session=>cs_outcome-open state = `Information` )
                  ( id = `X` outcome = z2ui5_cl_cockpit_session=>cs_outcome-unknown state = `None` ) )
        act = lt_outcome ).

  ENDMETHOD.

  METHOD flows_with_ends.

    " the sessions of flows_between_apps, all over: D's roundtrip failed
    DATA(lt_flow) = z2ui5_cl_cockpit_session=>flows_of(
        it_link      = VALUE #( ( id = `A` app = `X` )
                                ( id = `B` id_prev = `A` app = `X` )
                                ( id = `C` id_prev = `B` app = `Y` )
                                ( id = `D` id_prev = `C` app = `X` )
                                ( id = `E` id_prev = `GONE` app = `Z` )
                                ( id = `F` id_prev = `` app = `Y` ) )
        it_failed    = VALUE #( ( `D` ) )
        ended_before = `20991231000000.0` ).

    cl_abap_unit_assert=>assert_equals(
        exp = VALUE z2ui5_cl_cockpit_session=>ty_t_flow( ( source = `(start)` target = `X` count = 1 )
                                                         ( source = `(start)` target = `Y` count = 1 )
                                                         ( source = `X` target = `(end after an error)` count = 1 )
                                                         ( source = `X` target = `Y` count = 1 )
                                                         ( source = `Y` target = `(end)` count = 1 )
                                                         ( source = `Y` target = `X` count = 1 )
                                                         ( source = `Z` target = `(end)` count = 1 ) )
        act = lt_flow ).

  ENDMETHOD.

  METHOD growth_of_tables.

    " MT_LOG grows from 1 to 3 rows, the nested T_SUB of row 1 from 1 to 2,
    " MT_SAME keeps its row
    DATA(lt_before) = VALUE z2ui5_cl_cockpit_session=>ty_t_value( ( path = `APP-MT_LOG[1]-TEXT` value = `a` )
                                                                  ( path = `APP-MT_A[1]-T_SUB[1]-X` value = `1` )
                                                                  ( path = `APP-MT_SAME[1]` value = `s` ) ).
    DATA(lt_after) = VALUE z2ui5_cl_cockpit_session=>ty_t_value( ( path = `APP-MT_LOG[1]-TEXT` value = `a` )
                                                                 ( path = `APP-MT_LOG[1]-NR` value = `1` )
                                                                 ( path = `APP-MT_LOG[2]-TEXT` value = `b` )
                                                                 ( path = `APP-MT_LOG[3]-TEXT` value = `c` )
                                                                 ( path = `APP-MT_A[1]-T_SUB[1]-X` value = `1` )
                                                                 ( path = `APP-MT_A[1]-T_SUB[2]-X` value = `2` )
                                                                 ( path = `APP-MT_SAME[1]` value = `t` ) ).

    cl_abap_unit_assert=>assert_equals(
        exp = VALUE z2ui5_cl_cockpit_session=>ty_t_growth( ( path = `APP-MT_LOG` rows_before = 1 rows_after = 3 )
                                                           ( path        = `APP-MT_A[1]-T_SUB`
                                                             rows_before = 1
                                                             rows_after  = 2 ) )
        act = z2ui5_cl_cockpit_session=>growth_of( it_before = lt_before
                                                   it_after  = lt_after ) ).

  ENDMETHOD.

  METHOD flows_between_apps.

    " two sessions: X -> X -> Y -> X and one starting in Y; E's predecessor
    " is gone, so it is neither a start nor a navigation
    DATA(lt_flow) = z2ui5_cl_cockpit_session=>flows_of( VALUE #( ( id = `A` app = `X` )
                                                                 ( id = `B` id_prev = `A` app = `X` )
                                                                 ( id = `C` id_prev = `B` app = `Y` )
                                                                 ( id = `D` id_prev = `C` app = `X` )
                                                                 ( id = `E` id_prev = `GONE` app = `Z` )
                                                                 ( id = `F` id_prev = `` app = `Y` ) ) ).

    cl_abap_unit_assert=>assert_equals(
        exp = VALUE z2ui5_cl_cockpit_session=>ty_t_flow( ( source = `(start)` target = `X` count = 1 )
                                                         ( source = `(start)` target = `Y` count = 1 )
                                                         ( source = `X` target = `Y` count = 1 )
                                                         ( source = `Y` target = `X` count = 1 ) )
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

    DATA lt_draft TYPE STANDARD TABLE OF ty_s_draft WITH EMPTY KEY.
    DATA lv_tab TYPE string.

    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get_default( ).
    ls_set-user_tracking = z2ui5_cl_cockpit_setup=>cs_users-name.
    z2ui5_cl_cockpit_setup=>set_buffer( ls_set ).

    lt_draft = VALUE #( uname = `ZZ_COCKPIT_UT`
                        ( id = `ZZCKUT1` timestampl = `20991231100000.0` data = order( `` ) )
                        ( id = `ZZCKUT2` id_prev = `ZZCKUT1` timestampl = `20991231100005.0` data = order( `4711` ) )
                        ( id = `ZZCKUT3` id_prev = `ZZCKUT2` timestampl = `20991231100105.0` data = order( `4712` ) ) ).
    lv_tab = c_table.
    LOOP AT lt_draft INTO DATA(ls_draft).
      ls_draft-mandt = sy-mandt.
      INSERT (lv_tab) FROM @ls_draft.
    ENDLOOP.

    " what the monitor logged: the slow roundtrip that wrote step 3, and a
    " failed one that started from step 2
    DATA(ls_log) = VALUE z2ui5_t_ck_log( id            = `ZZCKUTLOG1`
                                         timestampl    = `20991231100105.0`
                                         utc_day       = `20991231`
                                         app           = c_app
                                         event         = `SAVE`
                                         draft_id      = `ZZCKUT3`
                                         draft_id_prev = `ZZCKUT2`
                                         check_slow    = abap_true
                                         ms_total      = 2500 ).
    INSERT z2ui5_t_ck_log FROM @ls_log.
    ls_log = VALUE #( id            = `ZZCKUTLOG2`
                      timestampl    = `20991231100030.0`
                      utc_day       = `20991231`
                      app           = c_app
                      event         = `POST`
                      draft_id_prev = `ZZCKUT2`
                      check_error   = abap_true
                      error_class   = `CX_SY_ZERODIVIDE`
                      error_head    = `Division by zero` ).
    INSERT z2ui5_t_ck_log FROM @ls_log.

  ENDMETHOD.

  METHOD teardown.

    DATA lv_tab TYPE string.
    DATA lv_pattern TYPE string.
    lv_tab = c_table.
    lv_pattern = `ZZCKUT%`.
    DELETE FROM (lv_tab) WHERE id LIKE @lv_pattern.
    DATA(lv_app) = CONV z2ui5_t_ck_log-app( c_app ).
    DELETE FROM z2ui5_t_ck_log WHERE app = @lv_app.
    DATA(lv_wire_app) = CONV z2ui5_t_ck_wir-app( c_app ).
    DELETE FROM z2ui5_t_ck_wir WHERE app = @lv_wire_app.
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

    DATA(ls_list) = z2ui5_cl_cockpit_session=>get_sessions( max_sessions = 1 ).

    cl_abap_unit_assert=>assert_true( ls_list-check_readable ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( ls_list-t_session ) ).
    DATA(ls_session) = ls_list-t_session[ 1 ].
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
    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUT1`
                                        act = ls_list-t_session[ 1 ]-id ).

    " the overview's count: no session listed, none read
    ls_list = z2ui5_cl_cockpit_session=>get_sessions( max_sessions = 0
                                                      check_errors = abap_true ).
    cl_abap_unit_assert=>assert_initial( ls_list-t_session ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_list-sessions >= 1 ) ).

    ls_list = z2ui5_cl_cockpit_session=>get_sessions( max_sessions = 1
                                                      search       = `no such app` ).
    cl_abap_unit_assert=>assert_initial( ls_list-t_session ).

  ENDMETHOD.

  METHOD steps_and_changes.

    DATA(ls_steps) = z2ui5_cl_cockpit_session=>get_steps( `ZZCKUT1` ).

    cl_abap_unit_assert=>assert_initial( ls_steps-error ).
    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( ls_steps-t_step ) ).
    cl_abap_unit_assert=>assert_equals( exp = `ZCL_ORDER`
                                        act = ls_steps-t_step[ 3 ]-app ).
    " nothing recorded for these drafts - the states bound to an ObjectStatus
    " are still a ValueState, an empty one terminates the app
    LOOP AT ls_steps-t_step INTO DATA(ls_step).
      cl_abap_unit_assert=>assert_not_initial( ls_step-shown_state ).
      cl_abap_unit_assert=>assert_not_initial( ls_step-monitor_state ).
      cl_abap_unit_assert=>assert_not_initial( ls_step-messages_state ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_steps-t_step[ 3 ]-kb ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_steps-t_step[ 2 ]-changes ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_steps-t_step[ 3 ]-changes ).
    cl_abap_unit_assert=>assert_equals(
        exp = VALUE z2ui5_cl_cockpit_session=>ty_t_business(
                  ( object = `Customer` value = `4711` field = `ZCL_ORDER-MV_CUSTOMER` step = 2 )
                  ( object = `Customer` value = `4712` field = `ZCL_ORDER-MV_CUSTOMER` step = 3 ) )
        act = ls_steps-t_business ).

    DATA(ls_view) = z2ui5_cl_cockpit_session=>get_view( id            = `ZZCKUT3`
                                                       id_prev       = `ZZCKUT2`
                                                       check_changes = abap_true ).
    cl_abap_unit_assert=>assert_initial( ls_view-error ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_view-fields ).
    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = ls_view-changes ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE z2ui5_cl_cockpit_session=>ty_s_field(
                                                  path   = `ZCL_ORDER-MV_CUSTOMER`
                                                  value  = `4712`
                                                  prev   = `4711`
                                                  change = z2ui5_cl_cockpit_session=>cs_change-changed
                                                  state  = `Warning` )
                                        act = ls_view-t_field[ 1 ] ).

    ls_view = z2ui5_cl_cockpit_session=>get_view( `ZZCKUT_GONE` ).
    cl_abap_unit_assert=>assert_not_initial( ls_view-error ).

  ENDMETHOD.

  METHOD monitor_marks_steps.

    DATA(ls_steps) = z2ui5_cl_cockpit_session=>get_steps( `ZZCKUT1` ).

    cl_abap_unit_assert=>assert_equals( exp = `None`
                                        act = ls_steps-t_step[ 1 ]-monitor_state ).
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = ls_steps-t_step[ 2 ]-monitor_state ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*CX_SY_ZERODIVIDE*event POST*`
                                         act = ls_steps-t_step[ 2 ]-monitor ).
    cl_abap_unit_assert=>assert_equals( exp = `Warning`
                                        act = ls_steps-t_step[ 3 ]-monitor_state ).
    cl_abap_unit_assert=>assert_equals( exp = `SAVE`
                                        act = ls_steps-t_step[ 3 ]-event ).
    cl_abap_unit_assert=>assert_equals( exp = `slow: 2500 ms`
                                        act = ls_steps-t_step[ 3 ]-monitor ).

  ENDMETHOD.

  METHOD history_of_a_field.

    DATA(ls_steps) = z2ui5_cl_cockpit_session=>get_steps( `ZZCKUT1` ).
    DATA(lt_history) = z2ui5_cl_cockpit_session=>get_history( it_step = ls_steps-t_step
                                                             path    = `ZCL_ORDER-MV_CUSTOMER` ).

    cl_abap_unit_assert=>assert_equals( exp = 3
                                        act = lines( lt_history ) ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE z2ui5_cl_cockpit_session=>ty_s_history( step  = 1
                                                                                            time  = `2099-12-31 10:00:00`
                                                                                            state = `None` )
                                        act = lt_history[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( exp = `4711`
                                        act = lt_history[ 2 ]-value ).
    cl_abap_unit_assert=>assert_equals( exp = `Warning`
                                        act = lt_history[ 2 ]-state ).
    cl_abap_unit_assert=>assert_equals( exp = `4712`
                                        act = lt_history[ 3 ]-value ).

    lt_history = z2ui5_cl_cockpit_session=>get_history( it_step = ls_steps-t_step
                                                       path    = `ZCL_ORDER-NO_SUCH_FIELD` ).
    cl_abap_unit_assert=>assert_equals( exp = `(not there)`
                                        act = lt_history[ 3 ]-value ).

  ENDMETHOD.

  METHOD playback_from_recordings.

    " the recorder saw step 2 display the screen and step 3 come from a
    " press on Save with a customer typed - and answer with an error
    DATA(lt_wire) = VALUE z2ui5_cl_cockpit_session=>ty_t_id( ).
    DATA(ls_wire) = VALUE z2ui5_t_ck_wir(
        id            = `ZZCKUTWS2`
        timestampl    = `20991231100005.0`
        utc_day       = `20991231`
        app           = c_app
        draft_id      = `ZZCKUT2`
        draft_id_prev = `ZZCKUT1`
        http_status   = 200
        req_body      = `{"S_FRONT":{"ID":"ZZCKUT1"}}`
        res_body      = `{"S_FRONT":{"ID":"ZZCKUT2","APP":"ZCL_ORDER","PROTOCOL":2,"S_ACTION":{"T_SYSTEM":` &&
                        `[["VIEW_SLOTS","display","MAIN","<mvc:View xmlns=\"sap.m\" xmlns:mvc=\"sap.ui.core.mvc\">` &&
                        `<Page title=\"Order\"><Label text=\"Customer\"/><Input value=\"{/MV_CUSTOMER}\"/>` &&
                        `<Button text=\"Save\" press=\".eB(['SAVE'])\"/></Page></mvc:View>"]]}},` &&
                        `"MODEL":{"MV_CUSTOMER":"4711"}}` ).
    INSERT z2ui5_t_ck_wir FROM @ls_wire.
    APPEND ls_wire-id TO lt_wire.
    ls_wire = VALUE #( id            = `ZZCKUTWS3`
                       timestampl    = `20991231100105.0`
                       utc_day       = `20991231`
                       app           = c_app
                       event         = `SAVE`
                       draft_id      = `ZZCKUT3`
                       draft_id_prev = `ZZCKUT2`
                       http_status   = 200
                       req_body      = `{"S_FRONT":{"ID":"ZZCKUT2","EVENT":"SAVE"},"MODEL":{"MV_CUSTOMER":"4712"}}`
                       res_body      = `{"S_FRONT":{"ID":"ZZCKUT3","APP":"ZCL_ORDER","PROTOCOL":2,"S_ACTION":` &&
                                       `{"T_CUSTOM":[["MESSAGE_BOX","error","Customer 4712 is blocked"]]}}}` ).
    INSERT z2ui5_t_ck_wir FROM @ls_wire.
    APPEND ls_wire-id TO lt_wire.

    DATA(ls_steps) = z2ui5_cl_cockpit_session=>get_steps( `ZZCKUT1` ).

    cl_abap_unit_assert=>assert_equals( exp = `ZZCKUTWS3`
                                        act = ls_steps-t_step[ 3 ]-wire_id ).
    cl_abap_unit_assert=>assert_equals( exp = `pressed Button "Save" (SAVE), typed Input "Customer" = 4712`
                                        act = ls_steps-t_step[ 3 ]-did ).
    cl_abap_unit_assert=>assert_equals( exp = `error box: Customer 4712 is blocked`
                                        act = ls_steps-t_step[ 3 ]-shown ).
    cl_abap_unit_assert=>assert_equals( exp = `Error`
                                        act = ls_steps-t_step[ 3 ]-shown_state ).

    " the screen of step 3: the view of step 2 with the customer the user typed
    DATA(ls_screen) = z2ui5_cl_cockpit_wire=>get_screen( lt_wire ).
    cl_abap_unit_assert=>assert_initial( ls_screen-error ).
    cl_abap_unit_assert=>assert_equals( exp = `Order`
                                        act = ls_screen-title ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*<Input value="4712"/>*<Button text="Save" press=""/>*`
                                         act = ls_screen-content ).

  ENDMETHOD.

  METHOD failures_and_app_objects.

    " steps 2 and 3 as the failing states: step 1 is a baseline of the app
    DATA(ls_failures) = z2ui5_cl_cockpit_session=>analyze_failures( it_id = VALUE #( ( `ZZCKUT2` ) ( `ZZCKUT3` ) )
                                                                   app   = `ZCL_ORDER` ).

    cl_abap_unit_assert=>assert_initial( ls_failures-error ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = ls_failures-failing ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_failures-others >= 1 ) ).
    " MV_MODE = edit is in every state, the customers differ - no hint
    cl_abap_unit_assert=>assert_initial( ls_failures-t_common ).
    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( ls_failures-t_business ) ).

    DATA(ls_objects) = z2ui5_cl_cockpit_session=>get_app_objects( `ZCL_ORDER` ).
    cl_abap_unit_assert=>assert_initial( ls_objects-error ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_objects-drafts >= 3 ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Customer`
                                        act = ls_objects-t_object[ 1 ]-object ).

  ENDMETHOD.

  METHOD search_in_drafts.

    DATA lv_found TYPE abap_bool.

    DATA(ls_find) = z2ui5_cl_cockpit_session=>search_drafts( `4711` ).

    cl_abap_unit_assert=>assert_initial( ls_find-error ).
    LOOP AT ls_find-t_hit INTO DATA(ls_hit) WHERE id = `ZZCKUT2`. "#EC CI_SORTSEQ
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

    DATA(lv_text) = z2ui5_cl_cockpit_session=>export( id   = `ZZCKUT1`
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
