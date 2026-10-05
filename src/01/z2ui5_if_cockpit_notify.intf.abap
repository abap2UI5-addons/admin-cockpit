"! <p class="shorttext synchronized">admin cockpit - alert notification</p>
"!
"! Implement this interface in a class of your own to be told when an alert
"! of the cockpit is raised or cleared - send a mail, post to a chat, open a
"! ticket, write to your monitoring. The cockpit finds the class by itself
"! (first implementer by name, like the abap2UI5 user exit) and calls it from
"! the housekeeping job z2ui5_cl_cockpit_job=&gt;run( ), which evaluates the
"! alert rules of the Settings tab.
"!
"! notify( ) runs inside the job's LUW: the cockpit commits after it, so a
"! mail queued with cl_bcs_mail_message (ABAP Cloud) or cl_bcs (Standard
"! ABAP) is sent with that commit. Whatever it raises is caught and shown
"! in the alert history - a failing notification never stops the job.
"!
"! Without such a class the alerts are still evaluated, kept and shown on
"! the Overview tab - only nobody is told.
INTERFACE z2ui5_if_cockpit_notify
  PUBLIC.

  CONSTANTS:
    BEGIN OF cs_event,
      " a threshold is exceeded - first evaluation that found it
      raised  TYPE string VALUE `RAISED`,
      " the threshold is kept again - first evaluation that no longer found it
      cleared TYPE string VALUE `CLEARED`,
      " the test button on the Settings tab - nothing is exceeded
      test    TYPE string VALUE `TEST`,
    END OF cs_event.

  CONSTANTS:
    BEGIN OF cs_rule,
      " the share of roundtrips ending in an exception
      error_rate TYPE string VALUE `ERROR_RATE`,
      " the 95th percentile of the server response time
      p95        TYPE string VALUE `P95`,
    END OF cs_rule.

  TYPES:
    BEGIN OF ty_s_alert,
      " cs_event-raised, -cleared or -test
      event      TYPE string,
      " cs_rule-error_rate or -p95
      rule       TYPE string,
      " the app class, empty when the rule fired over all apps
      app        TYPE string,
      " the measured value with its unit, for example 12.5 % or 3400 ms
      value      TYPE string,
      " the threshold with its unit
      limit      TYPE string,
      " roundtrips in the window the value was measured on
      roundtrips TYPE i,
      " when the alert was raised, UTC, YYYY-MM-DD hh:mm:ss
      raised     TYPE string,
      " system and client, for a message that leaves the system
      system     TYPE string,
      " one readable sentence - ready for a mail subject or a chat message
      text       TYPE string,
    END OF ty_s_alert.

  "! @parameter alert | what happened
  "! @raising cx_static_check | the notification failed - noted in the
  "! alert history, the job goes on
  METHODS notify
    IMPORTING
      alert TYPE ty_s_alert
    RAISING
      cx_static_check.

ENDINTERFACE.
