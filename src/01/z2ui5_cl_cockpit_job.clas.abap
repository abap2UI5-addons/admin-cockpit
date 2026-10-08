"! <p class="shorttext synchronized">admin cockpit - housekeeping</p>
"!
"! Deletes expired abap2UI5 drafts and the cockpit's own rows past their
"! retention. The cockpit's Drafts tab calls the same methods; a background
"! job calls run( ):
"! - Standard ABAP: a two-line report (REPORT z2ui5_cockpit_job.
"!   z2ui5_cl_cockpit_job=&gt;run( ).) scheduled in SM36
"! - ABAP Cloud: an application job class of your own whose
"!   if_apj_rt_exec_object~execute calls run( )
"! The monitor also purges its own tables once per day on the first recorded
"! roundtrip, so a job is only needed for the drafts - and abap2UI5 deletes
"! expired drafts itself as well, this is the explicit variant.
CLASS z2ui5_cl_cockpit_job DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_s_result,
        drafts_deleted TYPE i,
        log_deleted    TYPE i,
        agg_deleted    TYPE i,
        usr_deleted    TYPE i,
        act_deleted    TYPE i,
        aud_deleted    TYPE i,
        alr_deleted    TYPE i,
        wir_deleted    TYPE i,
        alerts         TYPE z2ui5_cl_cockpit_alert=>ty_s_run,
        message        TYPE string,
      END OF ty_s_result.

    "! Everything: expired drafts, the own tables, and the alert rules -
    "! raised and cleared alerts are kept and notified
    "! (z2ui5_cl_cockpit_alert). Commits. Scheduled every 15 minutes, the job
    "! is the cockpit's alerting.
    CLASS-METHODS run
      RETURNING
        VALUE(result) TYPE ty_s_result.

    "! The cockpit's own tables by their retention settings. No commit -
    "! the monitor commits it with the roundtrip, run( ) commits itself.
    CLASS-METHODS purge_own
      RETURNING
        VALUE(result) TYPE ty_s_result.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.


CLASS z2ui5_cl_cockpit_job IMPLEMENTATION.

  METHOD run.

    result = purge_own( ).
    COMMIT WORK.

    TRY.
        result-drafts_deleted = z2ui5_cl_cockpit_draft=>delete_expired( ).
        result-message = |{ result-drafts_deleted } expired drafts deleted, | &&
                         |{ result-log_deleted } log rows, { result-agg_deleted } aggregate rows, | &&
                         |{ result-usr_deleted } user rows, { result-act_deleted } activity rows, | &&
                         |{ result-wir_deleted } recorded roundtrips past retention|.
      CATCH cx_root INTO DATA(lx).
        result-message = |Drafts not deleted: { lx->get_text( ) }|.
    ENDTRY.

    TRY.
        result-alerts = z2ui5_cl_cockpit_alert=>run( ).
        COMMIT WORK.
        result-message = |{ result-message }; { result-alerts-message }|.
      CATCH cx_root INTO DATA(lx_alert).
        ROLLBACK WORK.                                   "#EC CI_ROLLBACK
        result-message = |{ result-message }; alerts not evaluated: { lx_alert->get_text( ) }|.
    ENDTRY.

  ENDMETHOD.

  METHOD purge_own.

    DATA(ls_set) = z2ui5_cl_cockpit_setup=>get( ).

    DATA(lv_log_ts) = z2ui5_cl_cockpit_setup=>now_minus_seconds( ls_set-retention_days * 86400 ).
    DATA(lv_usr_day) = z2ui5_cl_cockpit_setup=>day_minus( ls_set-retention_days ).
    DATA(lv_agg_day) = z2ui5_cl_cockpit_setup=>day_minus( ls_set-agg_retention_days ).
    " the live table only answers "who is active now" - a day is plenty
    DATA(lv_act_ts) = z2ui5_cl_cockpit_setup=>now_minus_seconds( 86400 ).

    DELETE FROM z2ui5_t_ck_log WHERE timestampl < @lv_log_ts.
    result-log_deleted = sy-dbcnt.
    DELETE FROM z2ui5_t_ck_usr WHERE utc_day < @lv_usr_day.
    result-usr_deleted = sy-dbcnt.
    DELETE FROM z2ui5_t_ck_agg WHERE utc_day < @lv_agg_day.
    result-agg_deleted = sy-dbcnt.
    DELETE FROM z2ui5_t_ck_act WHERE last_seen < @lv_act_ts.
    result-act_deleted = sy-dbcnt.
    " the change log follows the long retention of the aggregates
    DATA(lv_aud_ts) = z2ui5_cl_cockpit_setup=>now_minus_seconds( ls_set-agg_retention_days * 86400 ).
    DELETE FROM z2ui5_t_ck_aud WHERE timestampl < @lv_aud_ts.
    result-aud_deleted = sy-dbcnt.
    " and so does the alert history
    DELETE FROM z2ui5_t_ck_alr WHERE raised < @lv_aud_ts.
    result-alr_deleted = sy-dbcnt.
    " the recorder's raw requests and responses are the biggest and the most
    " sensitive rows - their own, short retention; 0 days deletes them all
    DATA(lv_wir_ts) = z2ui5_cl_cockpit_setup=>now_minus_seconds( ls_set-wire_days * 86400 ).
    DELETE FROM z2ui5_t_ck_wir WHERE timestampl < @lv_wir_ts.
    result-wir_deleted = sy-dbcnt.

  ENDMETHOD.

ENDCLASS.
