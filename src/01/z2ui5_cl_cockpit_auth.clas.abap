"! <p class="shorttext synchronized">admin cockpit - default authorization</p>
"!
"! The default implementation of z2ui5_if_cockpit_auth (the administrator
"! list on the Settings tab) and the lookup of a customer implementation.
CLASS z2ui5_cl_cockpit_auth DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_cockpit_auth.

    CONSTANTS:
      BEGIN OF cs_mode,
        " a customer class implementing z2ui5_if_cockpit_auth decides
        custom TYPE string VALUE `CUSTOM`,
        " the administrator list decides
        admins TYPE string VALUE `ADMINS`,
        " no administrator maintained yet - open to everybody
        open   TYPE string VALUE `OPEN`,
      END OF cs_mode.

    "! abap_true when the current user may do the action.
    CLASS-METHODS check
      IMPORTING
        action        TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS get_mode
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS get_mode_text
      RETURNING
        VALUE(result) TYPE string.

    "! The customer class implementing z2ui5_if_cockpit_auth, if any.
    CLASS-METHODS get_custom_class
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.

  PRIVATE SECTION.

    CLASS-DATA gv_custom_class TYPE string.
    CLASS-DATA gv_custom_known TYPE abap_bool.

ENDCLASS.


CLASS z2ui5_cl_cockpit_auth IMPLEMENTATION.

  METHOD check.

    DATA lo_auth TYPE REF TO z2ui5_if_cockpit_auth.
    DATA(lv_class) = get_custom_class( ).
    IF lv_class IS NOT INITIAL.
      TRY.
          CREATE OBJECT lo_auth TYPE (lv_class).
          result = lo_auth->check( action ).
        CATCH cx_root.
          " a configured check that cannot run denies - fail closed
          result = abap_false.
      ENDTRY.
      RETURN.
    ENDIF.

    result = NEW z2ui5_cl_cockpit_auth( )->z2ui5_if_cockpit_auth~check( action ).

  ENDMETHOD.

  METHOD z2ui5_if_cockpit_auth~check.

    DATA(lt_admins) = z2ui5_cl_cockpit_setup=>get_admins( ).
    IF lt_admins IS INITIAL.
      " not restricted yet - the red status on every tab says so
      result = abap_true.
      RETURN.
    ENDIF.
    result = xsdbool( line_exists( lt_admins[ table_line = sy-uname ] ) ). "#EC CI_SORTSEQ

  ENDMETHOD.

  METHOD get_mode.

    IF get_custom_class( ) IS NOT INITIAL.
      result = cs_mode-custom.
    ELSEIF z2ui5_cl_cockpit_setup=>get_admins( ) IS INITIAL.
      result = cs_mode-open.
    ELSE.
      result = cs_mode-admins.
    ENDIF.

  ENDMETHOD.

  METHOD get_mode_text.

    CASE get_mode( ).
      WHEN cs_mode-custom.
        result = |restricted by { get_custom_class( ) }|.
      WHEN cs_mode-admins.
        result = |restricted to { lines( z2ui5_cl_cockpit_setup=>get_admins( ) ) } administrator(s)|.
      WHEN OTHERS.
        result = `OPEN - no administrator maintained`.
    ENDCASE.

  ENDMETHOD.

  METHOD get_custom_class.

    IF gv_custom_known = abap_true.
      result = gv_custom_class.
      RETURN.
    ENDIF.

    DATA(lt_classes) = z2ui5_cl_cockpit_inst=>get_implementers( `Z2UI5_IF_COCKPIT_AUTH` ).
    DELETE lt_classes WHERE table_line = `Z2UI5_CL_COCKPIT_AUTH`.
    gv_custom_class = VALUE #( lt_classes[ 1 ] OPTIONAL ).
    gv_custom_known = abap_true.
    result = gv_custom_class.

  ENDMETHOD.

ENDCLASS.
