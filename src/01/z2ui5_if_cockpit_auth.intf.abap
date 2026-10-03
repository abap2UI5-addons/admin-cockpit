"! <p class="shorttext synchronized">admin cockpit - authorization</p>
"!
"! Implement this interface in a class of your own to decide who may use the
"! admin cockpit - an AUTHORITY-CHECK against your role concept, a check on
"! a business role, a user group. The cockpit finds the class by itself
"! (first implementer by name, like the abap2UI5 user exit) and asks it
"! instead of its own administrator list.
"!
"! Without such a class the cockpit allows the users maintained on its
"! Settings tab (table Z2UI5_T_CK_ADM). As long as that list is empty, the
"! cockpit shows nothing but a "claim the administrator role" screen: the
"! first user who presses its button becomes the administrator (logged in
"! the cockpit's change log), everybody after that needs to be on the list.
"! z2ui5_cl_cockpit_auth=&gt;reset_admins( ) starts over.
INTERFACE z2ui5_if_cockpit_auth
  PUBLIC.

  CONSTANTS:
    BEGIN OF cs_action,
      " open the cockpit and read every tab
      display TYPE string VALUE `DISPLAY`,
      " delete drafts, purge logs, change settings and administrators
      change  TYPE string VALUE `CHANGE`,
    END OF cs_action.

  "! @parameter action | cs_action-display or cs_action-change
  "! @parameter result | abap_true when the current user may do it
  METHODS check
    IMPORTING
      action        TYPE string
    RETURNING
      VALUE(result) TYPE abap_bool.

ENDINTERFACE.
