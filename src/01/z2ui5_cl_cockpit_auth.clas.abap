"! <p class="shorttext synchronized">admin cockpit - default authorization</p>
"!
"! The default implementation of z2ui5_if_cockpit_auth (the administrator
"! list on the Settings tab), the lookup of a customer implementation, the
"! claim of the administrator role on a fresh installation and the
"! cockpit's change log (Z2UI5_T_CK_AUD).
"!
"! Secure by default: with no customer class and no administrator, nobody
"! may display or change anything - the app shows only the claim screen,
"! and the first user who claims becomes the administrator.
CLASS z2ui5_cl_cockpit_auth DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_cockpit_auth.

    CONSTANTS:
      BEGIN OF cs_mode,
        " a customer class implementing z2ui5_if_cockpit_auth decides
        custom TYPE string VALUE `CUSTOM`,
        " the administrator list decides
        admins TYPE string VALUE `ADMINS`,
        " no administrator yet - only the claim screen is shown
        claim  TYPE string VALUE `CLAIM`,
      END OF cs_mode.

    CONSTANTS:
      BEGIN OF cs_log,
        claim    TYPE string VALUE `ADMIN_CLAIM`,
        reset    TYPE string VALUE `ADMIN_RESET`,
        add      TYPE string VALUE `ADMIN_ADD`,
        remove   TYPE string VALUE `ADMIN_REMOVE`,
        settings TYPE string VALUE `SETTINGS_SAVE`,
        drafts   TYPE string VALUE `DRAFTS_DELETE`,
        purge    TYPE string VALUE `LOG_PURGE`,
        job      TYPE string VALUE `HOUSEKEEPING`,
        repro    TYPE string VALUE `ERROR_REPRODUCE`,
        alert    TYPE string VALUE `ALERT_TEST`,
        session  TYPE string VALUE `SESSION_VIEW`,
      END OF cs_log.

    TYPES:
      BEGIN OF ty_s_log,
        time   TYPE string,
        user   TYPE string,
        action TYPE string,
        text   TYPE string,
      END OF ty_s_log.
    TYPES ty_t_log TYPE STANDARD TABLE OF ty_s_log WITH EMPTY KEY.

    "! abap_true when the current user may do the action.
    CLASS-METHODS check
      IMPORTING
        action        TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! The access decision itself, without any lookup - what check( ) does
    "! with the facts it collected.
    "! @parameter action       | z2ui5_if_cockpit_auth=&gt;cs_action-display or -change
    "! @parameter custom_class | the customer class found, empty when none
    "! @parameter io_custom    | its instance; not bound when it could not be created
    "! @parameter admins       | the administrator list
    "! @parameter uname        | the user asking
    CLASS-METHODS decide
      IMPORTING
        action        TYPE string
        custom_class  TYPE string OPTIONAL
        io_custom     TYPE REF TO z2ui5_if_cockpit_auth OPTIONAL
        admins        TYPE z2ui5_cl_cockpit_setup=>ty_t_names
        uname         TYPE clike
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

    "! Make the current user the first administrator - only while there is
    "! no administrator and no customer class. Lock-free and race-safe: the
    "! claim is a row with a fixed key in Z2UI5_T_CK_SET, so of two users
    "! claiming at the same moment exactly one INSERT succeeds. Logged and
    "! committed.
    "! @parameter result | abap_true when the current user is administrator now
    CLASS-METHODS claim
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Start over when the administrator has left: deletes every
    "! administrator and the claim. With uname, that user is the only
    "! administrator afterwards; without, the next user who opens the
    "! cockpit can claim it. Logged and committed - run it from a report, a
    "! console class or the class test environment.
    CLASS-METHODS reset_admins
      IMPORTING
        uname TYPE clike OPTIONAL.

    "! One row of the change log: who changed what in the cockpit. Not
    "! committed - the change it records commits it.
    CLASS-METHODS log
      IMPORTING
        action TYPE clike
        text   TYPE clike OPTIONAL.

    "! The change log, newest first.
    CLASS-METHODS get_log
      IMPORTING
        max_rows      TYPE i DEFAULT 200
      RETURNING
        VALUE(result) TYPE ty_t_log.

  PROTECTED SECTION.

  PRIVATE SECTION.

    CONSTANTS c_claim_row TYPE string VALUE `ADMIN_CLAIM`.

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
        CATCH cx_root.
          " a configured check that cannot run denies - fail closed
          CLEAR lo_auth.
      ENDTRY.
    ENDIF.

    result = decide( action       = action
                     custom_class = lv_class
                     io_custom    = lo_auth
                     admins       = z2ui5_cl_cockpit_setup=>get_admins( )
                     uname        = sy-uname ).

  ENDMETHOD.

  METHOD decide.

    DATA lv_uname TYPE string.

    IF action <> z2ui5_if_cockpit_auth=>cs_action-display AND action <> z2ui5_if_cockpit_auth=>cs_action-change.
      RETURN.
    ENDIF.

    IF custom_class IS NOT INITIAL.
      IF io_custom IS NOT BOUND.
        RETURN.
      ENDIF.
      TRY.
          result = io_custom->check( action ).
        CATCH cx_root.
          result = abap_false.
      ENDTRY.
      RETURN.
    ENDIF.

    " no administrator: nobody gets in - the app offers the claim instead
    lv_uname = to_upper( uname ).
    result = xsdbool( lv_uname IS NOT INITIAL AND line_exists( admins[ table_line = lv_uname ] ) ). "#EC CI_SORTSEQ

  ENDMETHOD.

  METHOD z2ui5_if_cockpit_auth~check.

    result = decide( action = action
                     admins = z2ui5_cl_cockpit_setup=>get_admins( )
                     uname  = sy-uname ).

  ENDMETHOD.

  METHOD get_mode.

    IF get_custom_class( ) IS NOT INITIAL.
      result = cs_mode-custom.
    ELSEIF z2ui5_cl_cockpit_setup=>get_admins( ) IS INITIAL.
      result = cs_mode-claim.
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
        result = `not claimed - the first user who opens the cockpit can claim the administrator role`.
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

  METHOD claim.

    DATA ls_row TYPE z2ui5_t_ck_set.
    DATA lv_value TYPE z2ui5_t_ck_set-value.

    IF get_mode( ) <> cs_mode-claim.
      RETURN.
    ENDIF.

    ls_row-name  = c_claim_row.
    ls_row-value = sy-uname.
    INSERT z2ui5_t_ck_set FROM @ls_row.
    IF sy-subrc <> 0.
      " a claim row without an administrator is stale (the list was
      " emptied in the database) - drop it and claim once more
      SELECT SINGLE value FROM z2ui5_t_ck_set
        WHERE name = @c_claim_row
        INTO @lv_value.
      IF sy-subrc = 0 AND z2ui5_cl_cockpit_setup=>get_admins( ) IS INITIAL.
        DELETE FROM z2ui5_t_ck_set WHERE name = @c_claim_row AND value = @lv_value.
        INSERT z2ui5_t_ck_set FROM @ls_row.
      ENDIF.
      IF sy-subrc <> 0.
        " somebody else was faster
        ROLLBACK WORK.                                   "#EC CI_ROLLBACK
        RETURN.
      ENDIF.
    ENDIF.

    z2ui5_cl_cockpit_setup=>add_admin( sy-uname ).
    log( action = cs_log-claim
         text   = |{ sy-uname } claimed the administrator role of a cockpit without administrators| ).
    COMMIT WORK.
    result = abap_true.

  ENDMETHOD.

  METHOD reset_admins.

    DATA(lt_admins) = z2ui5_cl_cockpit_setup=>get_admins( ).
    LOOP AT lt_admins INTO DATA(lv_admin).
      z2ui5_cl_cockpit_setup=>remove_admin( lv_admin ).
    ENDLOOP.
    DELETE FROM z2ui5_t_ck_set WHERE name = @c_claim_row.

    DATA(lv_new) = to_upper( condense( uname ) ).
    IF lv_new IS NOT INITIAL.
      z2ui5_cl_cockpit_setup=>add_admin( lv_new ).
      DATA(ls_row) = VALUE z2ui5_t_ck_set( name  = c_claim_row
                                           value = lv_new ).
      INSERT z2ui5_t_ck_set FROM @ls_row.
    ENDIF.

    log( action = cs_log-reset
         text   = |administrators reset by { sy-uname } ({ lines( lt_admins ) } removed)| &&
                  |{ COND #( WHEN lv_new IS NOT INITIAL THEN |, { lv_new } is the administrator now|
                             ELSE `, open for a new claim` ) }| ).
    COMMIT WORK.

  ENDMETHOD.

  METHOD log.

    DATA ls_row TYPE z2ui5_t_ck_aud.
    TRY.
        ls_row-id         = cl_system_uuid=>create_uuid_c32_static( ).
        ls_row-timestampl = z2ui5_cl_cockpit_setup=>now( ).
        ls_row-uname      = sy-uname.
        ls_row-action     = action.
        ls_row-text       = text.
        INSERT z2ui5_t_ck_aud FROM @ls_row.
      CATCH cx_root ##NO_HANDLER.
        " the change log must never block the change it records
    ENDTRY.

  ENDMETHOD.

  METHOD get_log.

    DATA lt_rows TYPE STANDARD TABLE OF z2ui5_t_ck_aud WITH EMPTY KEY.
    TRY.
        SELECT timestampl, uname, action, text FROM z2ui5_t_ck_aud
          ORDER BY timestampl DESCENDING
          INTO CORRESPONDING FIELDS OF TABLE @lt_rows
          UP TO @max_rows ROWS.                         "#EC CI_NOWHERE
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    LOOP AT lt_rows INTO DATA(ls_row).
      APPEND VALUE #( time   = z2ui5_cl_cockpit_setup=>ts_text( ls_row-timestampl )
                      user   = ls_row-uname
                      action = ls_row-action
                      text   = ls_row-text ) TO result.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
