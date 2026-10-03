"! <p class="shorttext synchronized">admin cockpit - roundtrip monitor</p>
"!
"! The one object of the admin cockpit that names the core's monitor hook.
"! abap2UI5 finds it on its own (the first implementer of
"! z2ui5_if_ui5_monitor by name) and calls it once per POST roundtrip, after
"! the response is built. Everything else lives in package 01 - this class
"! only maps the structure and forwards to z2ui5_cl_cockpit_rec, which
"! decides by the settings what is persisted and commits it.
CLASS z2ui5_cl_cockpit_monitor DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_ui5_monitor.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.


CLASS z2ui5_cl_cockpit_monitor IMPLEMENTATION.

  METHOD z2ui5_if_ui5_monitor~on_roundtrip.

    DATA ls_roundtrip TYPE z2ui5_cl_cockpit_rec=>ty_s_roundtrip.

    TRY.
        " by name: a field the core adds or renames does not break this class
        MOVE-CORRESPONDING is_roundtrip TO ls_roundtrip.
        z2ui5_cl_cockpit_rec=>record( ls_roundtrip ).
      CATCH cx_root ##NO_HANDLER.
        " a monitor must never break an app
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
