"! When an error occurrence can be replayed, and how an exception chain is
"! rendered - the replay itself needs the headless frontend and a draft.
CLASS ltcl_repro DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    METHODS possible FOR TESTING.
    METHODS sticky_app FOR TESTING.
    METHODS app_start FOR TESTING.
    METHODS no_event FOR TESTING.
    METHODS other_owner FOR TESTING.
    METHODS chain_of_exceptions FOR TESTING.

ENDCLASS.


CLASS ltcl_repro IMPLEMENTATION.

  METHOD possible.

    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_repro=>check_possible( draft_id_prev = `ABC`
                                                                                 event         = `SAVE`
                                                                                 check_sticky  = abap_false ) ).
    cl_abap_unit_assert=>assert_initial( z2ui5_cl_cockpit_repro=>check_possible(
                                             draft_id_prev = `ABC`
                                             event         = `SAVE`
                                             check_sticky  = abap_false
                                             owner         = z2ui5_cl_cockpit_repro=>cs_owner-you ) ).

  ENDMETHOD.

  METHOD sticky_app.

    cl_abap_unit_assert=>assert_char_cp( exp = `*stateful (sticky)*`
                                         act = z2ui5_cl_cockpit_repro=>check_possible( draft_id_prev = `ABC`
                                                                                       event         = `SAVE`
                                                                                       check_sticky  = abap_true ) ).

  ENDMETHOD.

  METHOD app_start.

    cl_abap_unit_assert=>assert_char_cp( exp = `*app start*`
                                         act = z2ui5_cl_cockpit_repro=>check_possible( draft_id_prev = ``
                                                                                       event         = `SAVE`
                                                                                       check_sticky  = abap_false ) ).

  ENDMETHOD.

  METHOD no_event.

    cl_abap_unit_assert=>assert_char_cp( exp = `*no event*`
                                         act = z2ui5_cl_cockpit_repro=>check_possible( draft_id_prev = `ABC`
                                                                                       event         = ``
                                                                                       check_sticky  = abap_false ) ).

  ENDMETHOD.

  METHOD other_owner.

    cl_abap_unit_assert=>assert_char_cp( exp = `*another user*`
                                         act = z2ui5_cl_cockpit_repro=>check_possible(
                                                   draft_id_prev = `ABC`
                                                   event         = `SAVE`
                                                   check_sticky  = abap_false
                                                   owner         = z2ui5_cl_cockpit_repro=>cs_owner-other ) ).

  ENDMETHOD.

  METHOD chain_of_exceptions.

    DATA lx_inner TYPE REF TO cx_root.
    DATA lx_outer TYPE REF TO cx_root.
    DATA lv_zero TYPE i.
    DATA lv_result TYPE i.

    TRY.
        lv_result = 1 / lv_zero.
      CATCH cx_sy_zerodivide INTO DATA(lx_div).
        lx_inner = lx_div.
    ENDTRY.
    TRY.
        RAISE EXCEPTION TYPE cx_sy_arithmetic_overflow
          EXPORTING
            previous = lx_inner.
      CATCH cx_sy_arithmetic_overflow INTO DATA(lx_itab).
        lx_outer = lx_itab.
    ENDTRY.

    DATA(lv_text) = z2ui5_cl_cockpit_repro=>chain_text( lx_outer ).
    SPLIT lv_text AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_line).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( lt_line ) ).
    cl_abap_unit_assert=>assert_char_cp( exp = `CX_SY_ARITHMETIC_OVERFLOW:*`
                                         act = lt_line[ 1 ] ).
    cl_abap_unit_assert=>assert_char_cp( exp = `CX_SY_ZERODIVIDE:*`
                                         act = lt_line[ 2 ] ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = lv_result ).

  ENDMETHOD.

ENDCLASS.
