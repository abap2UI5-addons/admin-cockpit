"! A customer authorization class: allows what it is told to.
CLASS ltd_auth DEFINITION FINAL FOR TESTING.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_cockpit_auth.

    DATA allowed TYPE string.

ENDCLASS.


CLASS ltd_auth IMPLEMENTATION.

  METHOD z2ui5_if_cockpit_auth~check.

    result = xsdbool( action = allowed ).

  ENDMETHOD.

ENDCLASS.


"! The access decision - secure by default: no administrator means nobody
"! gets in (the app offers the claim instead).
CLASS ltcl_access DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    METHODS no_admin_nobody FOR TESTING.
    METHODS admin_may_all FOR TESTING.
    METHODS admin_case_insensitive FOR TESTING.
    METHODS non_admin_denied FOR TESTING.
    METHODS custom_class_decides FOR TESTING.
    METHODS custom_class_not_created FOR TESTING.
    METHODS unknown_action_denied FOR TESTING.

    METHODS allowed
      IMPORTING
        action        TYPE string
        admins        TYPE z2ui5_cl_cockpit_setup=>ty_t_names OPTIONAL
        uname         TYPE string DEFAULT `ALICE`
      RETURNING
        VALUE(result) TYPE abap_bool.

ENDCLASS.


CLASS ltcl_access IMPLEMENTATION.

  METHOD allowed.

    result = z2ui5_cl_cockpit_auth=>decide( action = action
                                            admins = admins
                                            uname  = uname ).

  ENDMETHOD.

  METHOD no_admin_nobody.

    cl_abap_unit_assert=>assert_false( allowed( z2ui5_if_cockpit_auth=>cs_action-display ) ).
    cl_abap_unit_assert=>assert_false( allowed( z2ui5_if_cockpit_auth=>cs_action-change ) ).

  ENDMETHOD.

  METHOD admin_may_all.

    DATA(lt_admins) = VALUE z2ui5_cl_cockpit_setup=>ty_t_names( ( `ALICE` ) ( `BOB` ) ).
    cl_abap_unit_assert=>assert_true( allowed( action = z2ui5_if_cockpit_auth=>cs_action-display
                                               admins = lt_admins ) ).
    cl_abap_unit_assert=>assert_true( allowed( action = z2ui5_if_cockpit_auth=>cs_action-change
                                               admins = lt_admins ) ).

  ENDMETHOD.

  METHOD admin_case_insensitive.

    DATA(lt_admins) = VALUE z2ui5_cl_cockpit_setup=>ty_t_names( ( `ALICE` ) ).
    cl_abap_unit_assert=>assert_true( allowed( action = z2ui5_if_cockpit_auth=>cs_action-display
                                               admins = lt_admins
                                               uname  = `alice` ) ).

  ENDMETHOD.

  METHOD non_admin_denied.

    DATA(lt_admins) = VALUE z2ui5_cl_cockpit_setup=>ty_t_names( ( `BOB` ) ).
    cl_abap_unit_assert=>assert_false( allowed( action = z2ui5_if_cockpit_auth=>cs_action-display
                                                admins = lt_admins ) ).
    cl_abap_unit_assert=>assert_false( allowed( action = z2ui5_if_cockpit_auth=>cs_action-change
                                                admins = lt_admins ) ).
    cl_abap_unit_assert=>assert_false( allowed( action = z2ui5_if_cockpit_auth=>cs_action-display
                                                admins = lt_admins
                                                uname  = `` ) ).

  ENDMETHOD.

  METHOD custom_class_decides.

    " the customer class decides alone - the administrator list is ignored
    DATA(lo_auth) = NEW ltd_auth( ).
    lo_auth->allowed = z2ui5_if_cockpit_auth=>cs_action-display.
    DATA(lt_admins) = VALUE z2ui5_cl_cockpit_setup=>ty_t_names( ( `ALICE` ) ).

    cl_abap_unit_assert=>assert_true( z2ui5_cl_cockpit_auth=>decide( action       = z2ui5_if_cockpit_auth=>cs_action-display
                                                                     custom_class = `ZCL_MY_COCKPIT_AUTH`
                                                                     io_custom    = lo_auth
                                                                     admins       = lt_admins
                                                                     uname        = `ALICE` ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_cockpit_auth=>decide( action       = z2ui5_if_cockpit_auth=>cs_action-change
                                                                      custom_class = `ZCL_MY_COCKPIT_AUTH`
                                                                      io_custom    = lo_auth
                                                                      admins       = lt_admins
                                                                      uname        = `ALICE` ) ).

  ENDMETHOD.

  METHOD custom_class_not_created.

    " a class that is configured but cannot be created denies - fail closed
    DATA(lt_admins) = VALUE z2ui5_cl_cockpit_setup=>ty_t_names( ( `ALICE` ) ).
    cl_abap_unit_assert=>assert_false( z2ui5_cl_cockpit_auth=>decide( action       = z2ui5_if_cockpit_auth=>cs_action-display
                                                                      custom_class = `ZCL_MY_COCKPIT_AUTH`
                                                                      admins       = lt_admins
                                                                      uname        = `ALICE` ) ).

  ENDMETHOD.

  METHOD unknown_action_denied.

    DATA(lt_admins) = VALUE z2ui5_cl_cockpit_setup=>ty_t_names( ( `ALICE` ) ).
    cl_abap_unit_assert=>assert_false( allowed( action = `DELETE_EVERYTHING`
                                                admins = lt_admins ) ).

  ENDMETHOD.

ENDCLASS.
