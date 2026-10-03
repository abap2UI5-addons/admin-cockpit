"! <p class="shorttext synchronized">admin cockpit - reproduce an error</p>
"!
"! "Reproduce" on the Errors tab: resume the draft a failed roundtrip came
"! with and fire the same event again, through the headless frontend
"! (abap2UI5-addons/headless-frontend, z2ui5_cl_frontend_simulator) - the
"! app logic RUNS AGAIN, for real, as the current user.
"!
"! The simulator is optional and never a dependency: it is named in literals
"! only and called dynamically, so the cockpit activates without it and the
"! button simply is not offered.
"!
"! What it can replay, and why:
"! - only draft-based apps - a sticky (stateful) app keeps no draft
"! - only a draft that still exists - drafts expire (4 hours by default)
"! - only the current user's own drafts - abap2UI5 binds a draft to its owner
"! - the event without the values typed in that roundtrip and without its
"!   event arguments - neither is recorded
CLASS z2ui5_cl_cockpit_repro DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS c_simulator TYPE string VALUE `Z2UI5_CL_FRONTEND_SIMULATOR`.

    CONSTANTS:
      BEGIN OF cs_owner,
        you     TYPE string VALUE `YOU`,
        other   TYPE string VALUE `OTHER`,
        unknown TYPE string VALUE `UNKNOWN`,
      END OF cs_owner.

    TYPES:
      BEGIN OF ty_s_message,
        type TYPE string,
        text TYPE string,
      END OF ty_s_message.
    TYPES ty_t_message TYPE STANDARD TABLE OF ty_s_message WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_result,
        " the event was fired (the draft could be resumed)
        check_run   TYPE abap_bool,
        " the replay ended in an exception
        check_error TYPE abap_bool,
        strip_type  TYPE string,
        summary     TYPE string,
        error_text  TYPE string,
        app         TYPE string,
        draft_id    TYPE string,
        view_xml    TYPE string,
        t_message   TYPE ty_t_message,
      END OF ty_s_result.

    "! The headless frontend is installed.
    CLASS-METHODS check_available
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! Why an occurrence cannot be replayed - empty when it can.
    "! @parameter draft_id_prev | the draft the failed request came with
    "! @parameter event         | the event of the failed request
    "! @parameter check_sticky  | the app ran in a stateful session
    "! @parameter owner         | cs_owner: whose draft it is, as far as known
    CLASS-METHODS check_possible
      IMPORTING
        draft_id_prev TYPE clike
        event         TYPE clike
        check_sticky  TYPE abap_bool
        owner         TYPE string DEFAULT cs_owner-unknown
      RETURNING
        VALUE(result) TYPE string.

    "! Resume the draft and fire the event - the app logic runs again.
    "! Never raises; the result says what happened.
    CLASS-METHODS run
      IMPORTING
        draft_id_prev TYPE clike
        event         TYPE clike
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! The exception and every previous one, one line each.
    CLASS-METHODS chain_text
      IMPORTING
        ix            TYPE REF TO cx_root
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.

  PRIVATE SECTION.

    CLASS-METHODS read_simulator
      IMPORTING
        io_sim TYPE REF TO object
      CHANGING
        cs_result TYPE ty_s_result.

    "! A data object of a type of the simulator, created by name.
    CLASS-METHODS create_type
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE REF TO data
      RAISING
        cx_sy_create_data_error.

ENDCLASS.


CLASS z2ui5_cl_cockpit_repro IMPLEMENTATION.

  METHOD check_available.

    result = z2ui5_cl_cockpit_inst=>check_class_exists( c_simulator ).

  ENDMETHOD.

  METHOD check_possible.

    IF check_sticky = abap_true.
      result = `The app ran in a stateful (sticky) session - it keeps no draft that could be resumed.`.
    ELSEIF draft_id_prev IS INITIAL.
      result = `The failed request carried no draft - it was an app start, there is no state to resume.`.
    ELSEIF event IS INITIAL.
      result = `The failed request carried no event (a start or a navigation) - there is nothing to fire again.`.
    ELSEIF owner = cs_owner-other.
      result = `The draft belongs to another user - abap2UI5 binds a draft to its owner, ` &&
               `only that user can resume it.`.
    ENDIF.

  ENDMETHOD.

  METHOD run.

    DATA lo_sim TYPE REF TO object.
    DATA lv_id TYPE string.
    DATA lv_event TYPE string.

    lv_id = draft_id_prev.
    lv_event = event.

    TRY.
        CALL METHOD (c_simulator)=>(`RESUME`)
          EXPORTING
            id     = lv_id
          RECEIVING
            result = lo_sim.
      CATCH cx_root INTO DATA(lx_resume).
        result-strip_type = `Warning`.
        result-summary    = `Not replayed - the draft could not be resumed. It expired, belongs to another user, ` &&
                            `or the headless frontend is not compatible with this cockpit.`.
        result-error_text = chain_text( lx_resume ).
        RETURN.
    ENDTRY.

    result-check_run = abap_true.
    TRY.
        CALL METHOD lo_sim->(`CLICK`)
          EXPORTING
            event  = lv_event
          RECEIVING
            result = lo_sim.
        result-strip_type = `Success`.
        result-summary    = |Replayed: event { lv_event } ran without an exception this time. The cause may depend | &&
                            |on values typed in that roundtrip, on the data at that time or on the original user.|.
      CATCH cx_root INTO DATA(lx_click).
        result-check_error = abap_true.
        result-strip_type  = `Error`.
        result-summary     = |Reproduced: event { lv_event } ends in an exception again.|.
        result-error_text  = chain_text( lx_click ).
    ENDTRY.

    read_simulator( EXPORTING io_sim    = lo_sim
                    CHANGING  cs_result = result ).

  ENDMETHOD.

  METHOD read_simulator.

    DATA lr_messages TYPE REF TO data.
    DATA lr_layers TYPE REF TO data.
    FIELD-SYMBOLS <messages> TYPE ANY TABLE.
    FIELD-SYMBOLS <layers> TYPE ANY TABLE.
    FIELD-SYMBOLS <row> TYPE any.
    FIELD-SYMBOLS <type> TYPE any.
    FIELD-SYMBOLS <text> TYPE any.
    FIELD-SYMBOLS <xml> TYPE any.
    FIELD-SYMBOLS <layer> TYPE any.

    TRY.
        CALL METHOD io_sim->(`GET_APP`)
          RECEIVING
            result = cs_result-app.
        CALL METHOD io_sim->(`GET_ID`)
          RECEIVING
            result = cs_result-draft_id.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    " the simulator's own table types, created by name - their components
    " are read by name, so a component it adds does not matter here
    TRY.
        lr_messages = create_type( `TY_T_MESSAGE` ).
        ASSIGN lr_messages->* TO <messages>.
        CALL METHOD io_sim->(`GET_MESSAGES`)
          RECEIVING
            result = <messages>.
        LOOP AT <messages> ASSIGNING <row>.
          UNASSIGN <type>.
          UNASSIGN <text>.
          ASSIGN COMPONENT `TYPE` OF STRUCTURE <row> TO <type>.
          ASSIGN COMPONENT `TEXT` OF STRUCTURE <row> TO <text>.
          IF <text> IS ASSIGNED.
            APPEND VALUE #( text = <text> ) TO cs_result-t_message ASSIGNING FIELD-SYMBOL(<message>).
            IF <type> IS ASSIGNED.
              <message>-type = <type>.
            ENDIF.
          ENDIF.
        ENDLOOP.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    TRY.
        lr_layers = create_type( `TY_T_LAYER` ).
        ASSIGN lr_layers->* TO <layers>.
        CALL METHOD io_sim->(`GET_LAYERS`)
          RECEIVING
            result = <layers>.
        LOOP AT <layers> ASSIGNING <row>.
          UNASSIGN <layer>.
          UNASSIGN <xml>.
          ASSIGN COMPONENT `LAYER` OF STRUCTURE <row> TO <layer>.
          ASSIGN COMPONENT `XML` OF STRUCTURE <row> TO <xml>.
          IF <xml> IS ASSIGNED AND <xml> IS NOT INITIAL.
            IF <layer> IS ASSIGNED.
              cs_result-view_xml = |{ cs_result-view_xml }<!-- layer { <layer> } -->{ cl_abap_char_utilities=>newline }|.
            ENDIF.
            cs_result-view_xml = |{ cs_result-view_xml }{ <xml> }{ cl_abap_char_utilities=>newline }|.
          ENDIF.
        ENDLOOP.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

  ENDMETHOD.

  METHOD create_type.

    " the relative name first, the absolute one where a runtime knows only that
    DATA(lv_relative) = |{ c_simulator }=>{ name }|.
    TRY.
        CREATE DATA result TYPE (lv_relative).
      CATCH cx_sy_create_data_error.
        DATA(lv_absolute) = |\\CLASS={ c_simulator }\\TYPE={ name }|.
        CREATE DATA result TYPE (lv_absolute).
    ENDTRY.

  ENDMETHOD.

  METHOD chain_text.

    DATA lx TYPE REF TO cx_root.
    lx = ix.
    DO 20 TIMES.
      IF lx IS NOT BOUND.
        RETURN.
      ENDIF.
      DATA(lv_class) = cl_abap_typedescr=>describe_by_object_ref( lx )->get_relative_name( ).
      result = |{ result }{ COND #( WHEN result IS NOT INITIAL THEN cl_abap_char_utilities=>newline ) }| &&
               |{ lv_class }: { lx->get_text( ) }|.
      lx = lx->previous.
    ENDDO.

  ENDMETHOD.

ENDCLASS.
