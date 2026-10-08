"! <p class="shorttext synchronized">admin cockpit - the app</p>
"!
"! The admin cockpit as an abap2UI5 app: start it with
"! ?app_start=z2ui5_cl_cockpit_app. Its tabs answer what an IT lead asks
"! before abap2UI5 goes to production - is it used, is it fast, is it safely
"! configured. Installation &amp; Security and Drafts &amp; Housekeeping work on
"! every abap2UI5 release; Overview, Apps, Errors, Performance and Live show
"! what the roundtrip monitor (package 02) recorded; Agents what the agent
"! addon's endpoint did, when it is installed.
"!
"! Access is decided by z2ui5_cl_cockpit_auth at the top of main( ) - see
"! z2ui5_if_cockpit_auth. Without any administrator the app shows nothing
"! but the claim screen.
CLASS z2ui5_cl_cockpit_app DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_head,
        version    TYPE string,
        platform   TYPE string,
        user       TYPE string,
        auth_text  TYPE string,
        can_change TYPE abap_bool,
      END OF ty_s_head.

    TYPES:
      BEGIN OF ty_s_admin,
        uname TYPE string,
      END OF ty_s_admin.
    TYPES ty_t_admin TYPE STANDARD TABLE OF ty_s_admin WITH EMPTY KEY.

    DATA tab           TYPE string.
    DATA days          TYPE string.
    DATA s_head        TYPE ty_s_head.
    DATA s_monitor     TYPE z2ui5_cl_cockpit_stats=>ty_s_monitor.
    DATA s_kpi         TYPE z2ui5_cl_cockpit_stats=>ty_s_kpi.
    DATA t_trend       TYPE z2ui5_cl_cockpit_stats=>ty_t_day.
    DATA s_alerts      TYPE z2ui5_cl_cockpit_alert=>ty_s_status.
    DATA t_alert_now   TYPE z2ui5_cl_cockpit_alert=>ty_t_alert.
    DATA t_alert_log   TYPE z2ui5_cl_cockpit_alert=>ty_t_history.
    DATA t_apps        TYPE z2ui5_cl_cockpit_stats=>ty_t_app.
    DATA t_unused      TYPE z2ui5_cl_cockpit_stats=>ty_t_unused.
    DATA unused_title  TYPE string.
    DATA t_errors      TYPE z2ui5_cl_cockpit_stats=>ty_t_error.
    DATA t_hints       TYPE z2ui5_cl_cockpit_stats=>ty_t_hint.
    DATA t_slow        TYPE z2ui5_cl_cockpit_stats=>ty_t_slow.
    DATA s_live        TYPE z2ui5_cl_cockpit_stats=>ty_s_live.
    DATA s_install     TYPE z2ui5_cl_cockpit_inst=>ty_s_install.
    DATA t_checks      TYPE z2ui5_cl_cockpit_inst=>ty_t_check.
    DATA t_addons      TYPE z2ui5_cl_cockpit_inst=>ty_t_addon.
    DATA s_drafts      TYPE z2ui5_cl_cockpit_draft=>ty_s_info.
    DATA drafts_failed TYPE abap_bool.
    DATA s_analysis    TYPE z2ui5_cl_cockpit_draft=>ty_s_analysis.
    DATA analysis_text TYPE string.
    DATA analyzed      TYPE abap_bool.
    DATA s_set         TYPE z2ui5_cl_cockpit_setup=>ty_s_settings.
    DATA t_admins      TYPE ty_t_admin.
    DATA new_admin     TYPE string.
    DATA t_events      TYPE z2ui5_cl_cockpit_stats=>ty_t_event.
    DATA s_error       TYPE z2ui5_cl_cockpit_stats=>ty_s_error.
    DATA t_occurrences TYPE z2ui5_cl_cockpit_stats=>ty_t_occurrence.
    DATA error_text    TYPE string.
    DATA repro_enabled TYPE abap_bool.
    DATA repro_hint    TYPE string.
    DATA s_repro       TYPE z2ui5_cl_cockpit_repro=>ty_s_result.
    DATA s_agent       TYPE z2ui5_cl_cockpit_agent=>ty_s_info.
    DATA t_log         TYPE z2ui5_cl_cockpit_auth=>ty_t_log.
    DATA s_sessions     TYPE z2ui5_cl_cockpit_session=>ty_s_list.
    DATA sessions_text  TYPE string.
    DATA sessions_shown TYPE abap_bool.
    DATA session_search TYPE string.
    DATA t_steps        TYPE z2ui5_cl_cockpit_session=>ty_t_step.
    DATA s_step         TYPE z2ui5_cl_cockpit_session=>ty_s_view.
    DATA step_text      TYPE string.
    DATA step_info      TYPE string.
    DATA step_strip     TYPE string.
    DATA step_can_back  TYPE abap_bool.
    DATA step_can_next  TYPE abap_bool.
    DATA step_changes   TYPE abap_bool.
    DATA step_all       TYPE abap_bool.
    DATA step_search    TYPE string.
    DATA session_enabled TYPE abap_bool.
    DATA session_from_error TYPE abap_bool.

  PROTECTED SECTION.
    DATA client     TYPE REF TO z2ui5_if_client.
    DATA detail_app TYPE string.
    DATA s_occ      TYPE z2ui5_cl_cockpit_stats=>ty_s_occurrence.
    DATA s_session  TYPE z2ui5_cl_cockpit_session=>ty_s_session.
    DATA step_index TYPE i.

    METHODS view_display.
    METHODS view_no_auth.
    METHODS view_claim
      IMPORTING
        message TYPE string OPTIONAL.
    METHODS on_claim.
    METHODS popup_app.
    METHODS popup_error.
    METHODS popup_confirm_delete.
    METHODS popup_confirm_reproduce.
    METHODS popup_reproduce.
    METHODS popup_session.
    METHODS sessions_load.

    "! Open a session in the step viewer - logged, administrators only.
    "! @parameter id    | the session, its first draft
    "! @parameter draft | the step to show first, the newest when empty
    "! @parameter user  | how the user is shown when the list has not got it
    METHODS session_open
      IMPORTING
        id    TYPE clike
        draft TYPE clike OPTIONAL
        user  TYPE clike OPTIONAL.

    "! Show a step of the open session, compared with the step it continues.
    METHODS step_show
      IMPORTING
        step_no TYPE i.
    METHODS occurrence_select
      IMPORTING
        id TYPE clike.
    METHODS on_event.
    METHODS load_head.
    METHODS load_tab.
    METHODS check_change
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS get_days
      RETURNING
        VALUE(result) TYPE i.
    METHODS nav_lock_monitor.
    METHODS model_init.

    "! Enum properties bound to a tab's data, never empty - see there.
    METHODS enum_defaults.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_cockpit_app IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.

    " a fresh installation: no administrator, no customer class - nothing
    " but the claim screen, for everybody, until the first user claims
    IF z2ui5_cl_cockpit_auth=>get_mode( ) = z2ui5_cl_cockpit_auth=>cs_mode-claim.
      on_claim( ).
      RETURN.
    ENDIF.

    IF z2ui5_cl_cockpit_auth=>check( z2ui5_if_cockpit_auth=>cs_action-display ) = abap_false.
      view_no_auth( ).
      RETURN.
    ENDIF.

    IF client->check_on_init( ).
      model_init( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.
    enum_defaults( ).

  ENDMETHOD.

  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title` t = |abap2UI5 Admin Cockpit - abap2UI5 { s_head-version }, { s_head-platform }| ).

    DATA(header) = page->ele( `headerContent` ).

    header->ele( `SegmentedButton`
        )->a( n = `selectedKey`     v = client->_bind( days )
        )->a( n = `selectionChange` v = client->_event( `PERIOD` )
        )->a( n = `tooltip`         v = `Period of Apps, Errors, Performance and Agents`

        )->ele( `items`

            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `1`
                )->a( n = `text` v = `Today`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `7`
                )->a( n = `text` v = `7 days`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `30`
                )->a( n = `text` v = `30 days` ).

    header->tag( `Button`
        )->a( n = `icon`    v = `sap-icon://refresh`
        )->a( n = `tooltip` v = `Refresh`
        )->a( n = `press`   v = client->_event( `REFRESH` ) ).

    DATA(content) = page->ele( `content` ).

    DATA(bar) = content->ele( `IconTabBar`
        )->a( n = `selectedKey`         v = client->_bind( tab )
        )->a( n = `select`              v = client->_event( `TAB` )
        )->a( n = `expandable`          v = `false`
        )->a( n = `applyContentPadding` v = `true`

        )->ele( `items` ).

    " --- Overview -------------------------------------------------------
    DATA(overview) = bar->ele( `IconTabFilter`
        )->a( n = `key`  v = `OVERVIEW`
        )->a( n = `text` v = `Overview`
        )->a( n = `icon` v = `sap-icon://home` ).

    overview->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( s_monitor-text )
        )->a( n = `type`     v = client->_bind( s_monitor-strip_type )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginBottom` ).

    overview->ele( `FlexBox`
        )->a( n = `wrap`    v = `Wrap`
        )->a( n = `visible` v = client->_bind( s_monitor-check_data )

        )->ele( `GenericTile`
            )->a( n = `header`    v = `Active users`
            )->a( n = `subheader` v = `today, UTC`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->a( n = `footer` v = `distinct users or pseudonyms`

                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_kpi-users )
                            )->a( n = `icon`       v = `sap-icon://group`
                            )->a( n = `withMargin` v = `false`

                    )->end(
                )->end(
            )->end(
        )->end(

        )->ele( `GenericTile`
            )->a( n = `header`    v = `Roundtrips`
            )->a( n = `subheader` v = `today, UTC`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->a( n = `footer` v = `server roundtrips of all apps`

                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_kpi-roundtrips )
                            )->a( n = `icon`       v = `sap-icon://action`
                            )->a( n = `withMargin` v = `false`

                    )->end(
                )->end(
            )->end(
        )->end(

        )->ele( `GenericTile`
            )->a( n = `header`    v = `p95 response time`
            )->a( n = `subheader` v = `today, server side`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->a( n = `unit`   v = `ms`
                    )->a( n = `footer` v = `95 % of roundtrips were faster`

                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_kpi-p95_ms )
                            )->a( n = `valueColor` v = client->_bind( s_kpi-p95_state )
                            )->a( n = `withMargin` v = `false`

                    )->end(
                )->end(
            )->end(
        )->end(

        )->ele( `GenericTile`
            )->a( n = `header`    v = `Error rate`
            )->a( n = `subheader` v = `today`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->a( n = `unit`   v = `%`
                    )->a( n = `footer` v = `roundtrips ending in an exception`

                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_kpi-error_rate )
                            )->a( n = `valueColor` v = client->_bind( s_kpi-error_state )
                            )->a( n = `withMargin` v = `false`

                    )->end(
                )->end(
            )->end(
        )->end(

        )->ele( `GenericTile`
            )->a( n = `header`    v = `Draft table`
            )->a( n = `subheader` v = `rows now`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->a( n = `unit`   v = `rows`
                    )->a( n = `footer` v = `serialized app states`

                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_kpi-drafts )
                            )->a( n = `valueColor` v = client->_bind( s_kpi-drafts_state )
                            )->a( n = `icon`       v = `sap-icon://database`
                            )->a( n = `withMargin` v = `false` ).

    overview->ele( `Table`
        )->a( n = `headerText` v = `Last 30 days (UTC)`
        )->a( n = `items`      v = client->_bind( t_trend )
        )->a( n = `visible`    v = client->_bind( s_monitor-check_data )

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Day`
            )->tag( `Column`
                )->a( n = `header` v = `Roundtrips`
                )->a( n = `width`  v = `30%`
            )->tag( `Column`
                )->a( n = `header` v = `Users`
            )->tag( `Column`
                )->a( n = `header` v = `Errors`
            )->tag( `Column`
                )->a( n = `header` v = `Avg ms`
            )->tag( `Column`
                )->a( n = `header` v = `p95 ms`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{DAY}`
                    )->tag( `ProgressIndicator`
                        )->a( n = `percentValue` v = `{BAR}`
                        )->a( n = `displayValue` v = `{BAR_TEXT}`
                        )->a( n = `state`        v = `{STATE}`
                        )->a( n = `showValue`    v = `true`
                    )->tag( `Text`
                        )->a( n = `text` v = `{USERS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{ERRORS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{AVG_MS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{P95_MS}` ).

    overview->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( s_alerts-text )
        )->a( n = `type`     v = client->_bind( s_alerts-strip_type )
        )->a( n = `showIcon` v = `true`
        )->a( n = `visible`  v = client->_bind( s_monitor-check_data )
        )->a( n = `class`    v = `sapUiMediumMarginTop sapUiSmallMarginBottom` ).

    overview->ele( `Table`
        )->a( n = `headerText` v = `Alert thresholds exceeded now`
        )->a( n = `items`      v = client->_bind( t_alert_now )
        )->a( n = `visible`    v = client->_bind( s_alerts-check_now )

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `App`
            )->tag( `Column`
                )->a( n = `header` v = `Value`
            )->tag( `Column`
                )->a( n = `header` v = `Threshold`
            )->tag( `Column`
                )->a( n = `header` v = `Roundtrips`
            )->tag( `Column`
                )->a( n = `header` v = `Details`
                )->a( n = `width`  v = `40%`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{APP}`
                    )->tag( `ObjectStatus`
                        )->a( n = `text`  v = `{VALUE}`
                        )->a( n = `state` v = `Error`
                    )->tag( `Text`
                        )->a( n = `text` v = `{LIMIT}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{ROUNDTRIPS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{TEXT}` ).

    overview->ele( `Table`
        )->a( n = `headerText`       v = `Alert history - raised and cleared by the housekeeping job, open ones first`
        )->a( n = `items`            v = client->_bind( t_alert_log )
        )->a( n = `visible`          v = client->_bind( s_monitor-check_data )
        )->a( n = `noDataText`       v = `No alert so far - or the housekeeping job has not run yet.`
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `10`
        )->a( n = `class`            v = `sapUiSmallMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Status`
            )->tag( `Column`
                )->a( n = `header` v = `Rule`
            )->tag( `Column`
                )->a( n = `header` v = `App`
            )->tag( `Column`
                )->a( n = `header` v = `Value`
            )->tag( `Column`
                )->a( n = `header` v = `Threshold`
            )->tag( `Column`
                )->a( n = `header` v = `Raised (UTC)`
            )->tag( `Column`
                )->a( n = `header` v = `Cleared (UTC)`
            )->tag( `Column`
                )->a( n = `header` v = `Notification`
                )->a( n = `width`  v = `30%`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `ObjectStatus`
                        )->a( n = `text`  v = `{STATUS}`
                        )->a( n = `state` v = `{STATE}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{RULE}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{APP}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{VALUE}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{LIMIT}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{RAISED}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{CLEARED}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{NOTE}` ).

    " --- Apps -----------------------------------------------------------
    DATA(apps) = bar->ele( `IconTabFilter`
        )->a( n = `key`  v = `APPS`
        )->a( n = `text` v = `Apps`
        )->a( n = `icon` v = `sap-icon://product` ).

    apps->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( s_monitor-text )
        )->a( n = `type`     v = client->_bind( s_monitor-strip_type )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginBottom` ).

    apps->ele( `Table`
        )->a( n = `headerText`       v = `Apps in the selected period - select one for its events`
        )->a( n = `items`            v = client->_bind( t_apps )
        )->a( n = `visible`          v = client->_bind( s_monitor-check_data )
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `50`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `App`
            )->tag( `Column`
                )->a( n = `header` v = `Users/day (max)`
            )->tag( `Column`
                )->a( n = `header` v = `Sessions`
            )->tag( `Column`
                )->a( n = `header` v = `Roundtrips`
            )->tag( `Column`
                )->a( n = `header` v = `Avg ms`
            )->tag( `Column`
                )->a( n = `header` v = `p95 ms`
            )->tag( `Column`
                )->a( n = `header` v = `Avg KB`
            )->tag( `Column`
                )->a( n = `header` v = `Model KB (max)`
            )->tag( `Column`
                )->a( n = `header` v = `Errors`
            )->tag( `Column`
                )->a( n = `header` v = `Last used`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->a( n = `type`  v = `Navigation`
                )->a( n = `press` v = client->_event( val = `APP_DETAIL` arg = `${APP}` )

                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{APP}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{USERS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{SESSIONS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{ROUNDTRIPS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{AVG_MS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{P95_MS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{KB_RES_AVG}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{KB_MODEL_MAX}`
                    )->tag( `ObjectStatus`
                        )->a( n = `text`  v = `{ERRORS}`
                        )->a( n = `state` v = `{ERROR_STATE}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{LAST_USED}` ).

    apps->ele( `Table`
        )->a( n = `headerText`       v = client->_bind( unused_title )
        )->a( n = `items`            v = client->_bind( t_unused )
        )->a( n = `visible`          v = client->_bind( s_monitor-check_data )
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `50`
        )->a( n = `class`            v = `sapUiMediumMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `App class (implements z2ui5_if_app)`
            )->tag( `Column`
                )->a( n = `header` v = `Last recorded roundtrip`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{APP}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{LAST_USED}` ).

    " --- Errors ---------------------------------------------------------
    DATA(errors) = bar->ele( `IconTabFilter`
        )->a( n = `key`  v = `ERRORS`
        )->a( n = `text` v = `Errors`
        )->a( n = `icon` v = `sap-icon://error` ).

    errors->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( s_monitor-text )
        )->a( n = `type`     v = client->_bind( s_monitor-strip_type )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginBottom` ).

    errors->ele( `Table`
        )->a( n = `headerText`       v = `Errors grouped by app, event, exception class and first line - select one for the details`
        )->a( n = `items`            v = client->_bind( t_errors )
        )->a( n = `visible`          v = client->_bind( s_monitor-check_data )
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `50`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Count`
                )->a( n = `width`  v = `5rem`
            )->tag( `Column`
                )->a( n = `header` v = `App`
            )->tag( `Column`
                )->a( n = `header` v = `Event`
            )->tag( `Column`
                )->a( n = `header` v = `Exception class`
            )->tag( `Column`
                )->a( n = `header` v = `Message`
                )->a( n = `width`  v = `35%`
            )->tag( `Column`
                )->a( n = `header` v = `First seen (UTC)`
            )->tag( `Column`
                )->a( n = `header` v = `Last seen (UTC)`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->a( n = `type`  v = `Navigation`
                )->a( n = `press` v = client->_event( val = `ERROR_DETAIL` arg = `${KEY}` )

                )->ele( `cells`

                    )->tag( `ObjectNumber`
                        )->a( n = `number` v = `{COUNT}`
                        )->a( n = `state`  v = `Error`
                    )->tag( `Text`
                        )->a( n = `text` v = `{APP}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{EVENT}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{ERROR_CLASS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{ERROR_HEAD}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{FIRST_SEEN}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{LAST_SEEN}` ).

    " --- Performance ----------------------------------------------------
    DATA(perf) = bar->ele( `IconTabFilter`
        )->a( n = `key`  v = `PERF`
        )->a( n = `text` v = `Performance`
        )->a( n = `icon` v = `sap-icon://performance` ).

    perf->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( s_monitor-text )
        )->a( n = `type`     v = client->_bind( s_monitor-strip_type )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginBottom` ).

    perf->ele( `Table`
        )->a( n = `headerText` v = `Runtime hints`
        )->a( n = `items`      v = client->_bind( t_hints )
        )->a( n = `visible`    v = client->_bind( s_monitor-check_data )
        )->a( n = `noDataText` v = `Nothing to report for the selected period.`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Hint`
            )->tag( `Column`
                )->a( n = `header` v = `App`
            )->tag( `Column`
                )->a( n = `header` v = `Value`
            )->tag( `Column`
                )->a( n = `header` v = `What to do`
                )->a( n = `width`  v = `40%`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `ObjectStatus`
                        )->a( n = `text`  v = `{HINT}`
                        )->a( n = `state` v = `{STATE}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{APP}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{VALUE}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{FIX}` ).

    perf->ele( `Table`
        )->a( n = `headerText`       v = `Slowest roundtrips with phase breakdown (ms)`
        )->a( n = `items`            v = client->_bind( t_slow )
        )->a( n = `visible`          v = client->_bind( s_monitor-check_data )
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `20`
        )->a( n = `class`            v = `sapUiMediumMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Time (UTC)`
            )->tag( `Column`
                )->a( n = `header` v = `App`
            )->tag( `Column`
                )->a( n = `header` v = `Event`
            )->tag( `Column`
                )->a( n = `header` v = `Total`
            )->tag( `Column`
                )->a( n = `header` v = `Load`
            )->tag( `Column`
                )->a( n = `header` v = `Main`
            )->tag( `Column`
                )->a( n = `header` v = `Render`
            )->tag( `Column`
                )->a( n = `header` v = `Browser (prev.)`
            )->tag( `Column`
                )->a( n = `header` v = `Response KB`
            )->tag( `Column`
                )->a( n = `header` v = `Model KB`
            )->tag( `Column`
                )->a( n = `header` v = `Dominant phase`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{TIME}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{APP}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{EVENT}`
                    )->tag( `ObjectNumber`
                        )->a( n = `number` v = `{MS_TOTAL}`
                        )->a( n = `state`  v = `Warning`
                    )->tag( `Text`
                        )->a( n = `text` v = `{MS_LOAD}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{MS_MAIN}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{MS_RENDER}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{MS_CLIENT}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{KB_RES}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{KB_MODEL}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{PHASE}` ).

    " --- Drafts & Housekeeping ------------------------------------------
    DATA(drafts) = bar->ele( `IconTabFilter`
        )->a( n = `key`  v = `DRAFTS`
        )->a( n = `text` v = `Drafts & Housekeeping`
        )->a( n = `icon` v = `sap-icon://database` ).

    drafts->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( s_drafts-error )
        )->a( n = `type`     v = `Error`
        )->a( n = `showIcon` v = `true`
        )->a( n = `visible`  v = client->_bind( drafts_failed )
        )->a( n = `class`    v = `sapUiSmallMarginBottom` ).

    drafts->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `abap2UI5 draft table`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->a( n = `editable` v = `false`

        )->ele( n = `content` ns = `form`

            )->tag( `Label`
                )->a( n = `text` v = `Rows`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_drafts-rows )
            )->tag( `Label`
                )->a( n = `text` v = `Expired (older than the expiry)`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_drafts-rows_expired )
            )->tag( `Label`
                )->a( n = `text` v = `Written in the last 5 minutes`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_drafts-rows_active )
            )->tag( `Label`
                )->a( n = `text` v = `Users with drafts`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_drafts-users )
            )->tag( `Label`
                )->a( n = `text` v = `Oldest draft (UTC)`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_drafts-oldest )
            )->tag( `Label`
                )->a( n = `text` v = `Newest draft (UTC)`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_drafts-newest )
            )->tag( `Label`
                )->a( n = `text` v = `Expiry setting (hours)`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_drafts-expiry_hours )
            )->tag( `Label`
                )->a( n = `text` v = `Cutoff (UTC)`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_drafts-cutoff ) ).

    drafts->ele( `OverflowToolbar`

        )->tag( `Button`
            )->a( n = `text`    v = `Delete expired drafts`
            )->a( n = `icon`    v = `sap-icon://delete`
            )->a( n = `type`    v = `Reject`
            )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->a( n = `press`   v = client->_event( `DRAFTS_DELETE` )
        )->tag( `Button`
            )->a( n = `text`  v = `Analyze size per app`
            )->a( n = `icon`  v = `sap-icon://pie-chart`
            )->a( n = `press` v = client->_event( `DRAFTS_ANALYZE` )
        )->tag( `Button`
            )->a( n = `text`    v = `Clean up cockpit log (retention)`
            )->a( n = `icon`    v = `sap-icon://broken-link`
            )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->a( n = `press`   v = client->_event( `LOG_PURGE` )
        )->tag( `Button`
            )->a( n = `text`    v = `Run full housekeeping`
            )->a( n = `icon`    v = `sap-icon://process`
            )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->a( n = `press`   v = client->_event( `JOB_RUN` ) ).

    drafts->tag( `Text`
        )->a( n = `text`  v = `Background job: z2ui5_cl_cockpit_job=>run( ) deletes expired drafts and the cockpit's ` &&
                              `rows past retention - schedule it with a two-line report (SM36) or an ABAP Cloud application job.`
        )->a( n = `class` v = `sapUiSmallMarginTop sapUiSmallMarginBottom` ).

    drafts->ele( `OverflowToolbar`
        )->a( n = `class` v = `sapUiMediumMarginTop`

        )->tag( `Title`
            )->a( n = `text` v = `Sessions - what a user did, step by step`
        )->tag( `ToolbarSpacer`
        )->tag( `SearchField`
            )->a( n = `value`       v = client->_bind( session_search )
            )->a( n = `search`      v = client->_event( `SESSIONS_LOAD` )
            )->a( n = `placeholder` v = `App or user`
            )->a( n = `width`       v = `14rem`
            )->a( n = `enabled`     v = client->_bind( s_head-can_change )
        )->tag( `Button`
            )->a( n = `text`    v = `Show sessions`
            )->a( n = `icon`    v = `sap-icon://history`
            )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->a( n = `press`   v = client->_event( `SESSIONS_LOAD` ) ).

    drafts->tag( `Text`
        )->a( n = `text`  v = `Every roundtrip saves the app as a draft and names the draft it started from - a session is ` &&
                              `that chain. Open one to step through it: the fields of the app after every step and what ` &&
                              `changed since the step before. Drafts hold business data of other users - administrators ` &&
                              `only, and every opened session is written to the change log. A session lasts as long as ` &&
                              `its drafts (the expiry above).`
        )->a( n = `class` v = `sapUiSmallMarginBottom` ).

    drafts->ele( `Table`
        )->a( n = `headerText`       v = client->_bind( sessions_text )
        )->a( n = `items`            v = client->_bind( s_sessions-t_session )
        )->a( n = `visible`          v = client->_bind( sessions_shown )
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `20`
        )->a( n = `noDataText`       v = `No session in the draft table.`
        )->a( n = `class`            v = `sapUiMediumMarginBottom`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `User`
            )->tag( `Column`
                )->a( n = `header` v = `App (newest step)`
            )->tag( `Column`
                )->a( n = `header` v = `Steps`
            )->tag( `Column`
                )->a( n = `header` v = `First step (UTC)`
            )->tag( `Column`
                )->a( n = `header` v = `Last step (UTC)`
            )->tag( `Column`
                )->a( n = `header` v = `Duration`
            )->tag( `Column`
                )->a( n = `header` v = `Note`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->a( n = `type`  v = `Active`
                )->a( n = `press` v = client->_event( val = `SESSION_OPEN` arg = `${ID}` )

                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{USER}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{APP}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{STEPS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{FIRST}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{LAST}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{DURATION}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{NOTE}` ).

    drafts->ele( `Table`
        )->a( n = `headerText`       v = `Drafts per user (pseudonymized unless user tracking is NAME)`
        )->a( n = `items`            v = client->_bind( s_drafts-t_user )
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `20`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `User`
            )->tag( `Column`
                )->a( n = `header` v = `Drafts`
            )->tag( `Column`
                )->a( n = `header` v = `Oldest (UTC)`
            )->tag( `Column`
                )->a( n = `header` v = `Newest (UTC)`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{USER}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{DRAFTS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{OLDEST}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{NEWEST}` ).

    drafts->ele( `Table`
        )->a( n = `headerText` v = client->_bind( analysis_text )
        )->a( n = `items`      v = client->_bind( s_analysis-t_app )
        )->a( n = `visible`    v = client->_bind( analyzed )
        )->a( n = `class`      v = `sapUiMediumMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `App (from the serialized draft, best effort)`
            )->tag( `Column`
                )->a( n = `header` v = `Drafts`
            )->tag( `Column`
                )->a( n = `header` v = `KB total`
            )->tag( `Column`
                )->a( n = `header` v = `KB avg`
            )->tag( `Column`
                )->a( n = `header` v = `KB max`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{APP}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{DRAFTS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{KB}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{KB_AVG}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{KB_MAX}` ).

    " --- Installation & Security ----------------------------------------
    DATA(security) = bar->ele( `IconTabFilter`
        )->a( n = `key`  v = `SECURITY`
        )->a( n = `text` v = `Installation & Security`
        )->a( n = `icon` v = `sap-icon://shield` ).

    security->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `Installation`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->a( n = `editable` v = `false`

        )->ele( n = `content` ns = `form`

            )->tag( `Label`
                )->a( n = `text` v = `abap2UI5 version`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_install-version )
            )->tag( `Label`
                )->a( n = `text` v = `Platform`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_install-platform )
            )->tag( `Label`
                )->a( n = `text` v = `User exit class`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_install-user_exit )
            )->tag( `Label`
                )->a( n = `text` v = `UI5 bootstrap`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_install-ui5_src )
            )->tag( `Label`
                )->a( n = `text` v = `Theme`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_install-ui5_theme )
            )->tag( `Label`
                )->a( n = `text` v = `Draft expiry`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_install-draft_expiry )
            )->tag( `Label`
                )->a( n = `text` v = `Admin cockpit access`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_head-auth_text ) ).

    security->ele( `Table`
        )->a( n = `headerText` v = `Security traffic light - read from the configuration the framework computes`
        )->a( n = `items`      v = client->_bind( t_checks )
        )->a( n = `class`      v = `sapUiMediumMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Check`
            )->tag( `Column`
                )->a( n = `header` v = `Value`
            )->tag( `Column`
                )->a( n = `header` v = `Why it matters`
                )->a( n = `width`  v = `30%`
            )->tag( `Column`
                )->a( n = `header` v = `How to fix`
                )->a( n = `width`  v = `30%`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `ObjectStatus`
                        )->a( n = `text`  v = `{TITLE}`
                        )->a( n = `icon`  v = `{ICON}`
                        )->a( n = `state` v = `{STATUS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{VALUE}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{TEXT}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{FIX}` ).

    security->ele( `Table`
        )->a( n = `headerText` v = `Known addons (detected by class existence)`
        )->a( n = `items`      v = client->_bind( t_addons )
        )->a( n = `class`      v = `sapUiMediumMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Addon`
            )->tag( `Column`
                )->a( n = `header` v = `Kind`
            )->tag( `Column`
                )->a( n = `header` v = `Status`
            )->tag( `Column`
                )->a( n = `header` v = `Marker class`
            )->tag( `Column`
                )->a( n = `header` v = `Note`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Link`
                        )->a( n = `text`   v = `{NAME}`
                        )->a( n = `href`   v = `{URL}`
                        )->a( n = `target` v = `_blank`
                    )->tag( `Text`
                        )->a( n = `text` v = `{KIND}`
                    )->tag( `ObjectStatus`
                        )->a( n = `text`  v = `{STATUS}`
                        )->a( n = `state` v = `{STATE}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{MARKER}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{NOTE}` ).

    security->ele( `Panel`
        )->a( n = `headerText` v = `Effective Content Security Policy and response headers`
        )->a( n = `expandable` v = `true`
        )->a( n = `expanded`   v = `false`
        )->a( n = `class`      v = `sapUiMediumMarginTop`

        )->tag( `TextArea`
            )->a( n = `value`    v = client->_bind( s_install-csp )
            )->a( n = `editable` v = `false`
            )->a( n = `rows`     v = `6`
            )->a( n = `width`    v = `100%`
        )->tag( `TextArea`
            )->a( n = `value`    v = client->_bind( s_install-headers )
            )->a( n = `editable` v = `false`
            )->a( n = `rows`     v = `6`
            )->a( n = `width`    v = `100%` ).

    " --- Live -----------------------------------------------------------
    DATA(live) = bar->ele( `IconTabFilter`
        )->a( n = `key`  v = `LIVE`
        )->a( n = `text` v = `Live`
        )->a( n = `icon` v = `sap-icon://activity-individual` ).

    live->ele( `FlexBox`
        )->a( n = `wrap` v = `Wrap`

        )->ele( `GenericTile`
            )->a( n = `header`    v = `Active sessions`
            )->a( n = `subheader` v = `drafts written in the last 5 minutes`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_live-sessions )
                            )->a( n = `icon`       v = `sap-icon://activity-items`
                            )->a( n = `withMargin` v = `false`

                    )->end(
                )->end(
            )->end(
        )->end(

        )->ele( `GenericTile`
            )->a( n = `header`    v = `Active users`
            )->a( n = `subheader` v = `owners of those drafts`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_live-users )
                            )->a( n = `icon`       v = `sap-icon://group`
                            )->a( n = `withMargin` v = `false`

                    )->end(
                )->end(
            )->end(
        )->end(

        )->ele( `GenericTile`
            )->a( n = `header`    v = `Apps in use`
            )->a( n = `subheader` v = `from the monitor, last 5 minutes`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_live-apps )
                            )->a( n = `icon`       v = `sap-icon://product`
                            )->a( n = `withMargin` v = `false` ).

    live->ele( `Table`
        )->a( n = `headerText` v = `Apps used in the last 5 minutes (roundtrip monitor)`
        )->a( n = `items`      v = client->_bind( s_live-t_app )
        )->a( n = `noDataText` v = `No recorded roundtrip in the last 5 minutes.`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `App`
            )->tag( `Column`
                )->a( n = `header` v = `Users`
            )->tag( `Column`
                )->a( n = `header` v = `Last seen (UTC)`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{APP}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{USERS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{LAST_SEEN}` ).

    live->ele( `OverflowToolbar`
        )->a( n = `visible` v = client->_bind( s_live-check_lock )
        )->a( n = `class`   v = `sapUiSmallMarginTop`

        )->tag( `Text`
            )->a( n = `text` v = `The lock-manager addon is installed - its SM12-like monitor shows the locks held across roundtrips.`
        )->tag( `Button`
            )->a( n = `text`  v = `Open lock monitor`
            )->a( n = `icon`  v = `sap-icon://locked`
            )->a( n = `press` v = client->_event( `LOCKS` ) ).

    " --- Agents ---------------------------------------------------------
    DATA(agents) = bar->ele( `IconTabFilter`
        )->a( n = `key`  v = `AGENTS`
        )->a( n = `text` v = `Agents`
        )->a( n = `icon` v = `sap-icon://chain-link` ).

    agents->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( s_agent-text )
        )->a( n = `type`     v = client->_bind( s_agent-strip_type )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginBottom` ).

    agents->ele( `FlexBox`
        )->a( n = `wrap`    v = `Wrap`
        )->a( n = `visible` v = client->_bind( s_agent-readable )

        )->ele( `GenericTile`
            )->a( n = `header`    v = `Agent calls`
            )->a( n = `subheader` v = `selected period`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->a( n = `footer` v = `tool calls in the audit log`

                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_agent-calls )
                            )->a( n = `icon`       v = `sap-icon://chain-link`
                            )->a( n = `withMargin` v = `false`

                    )->end(
                )->end(
            )->end(
        )->end(

        )->ele( `GenericTile`
            )->a( n = `header`    v = `Refused by policy`
            )->a( n = `subheader` v = `selected period`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->a( n = `footer` v = `disabled, not enabled, forbidden, needs a human`

                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_agent-policy )
                            )->a( n = `valueColor` v = `Critical`
                            )->a( n = `withMargin` v = `false`

                    )->end(
                )->end(
            )->end(
        )->end(

        )->ele( `GenericTile`
            )->a( n = `header`    v = `Refused or failed`
            )->a( n = `subheader` v = `selected period`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->a( n = `footer` v = `validation, session, app errors`

                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_agent-validation )
                            )->a( n = `valueColor` v = `Error`
                            )->a( n = `withMargin` v = `false`

                    )->end(
                )->end(
            )->end(
        )->end(

        )->ele( `GenericTile`
            )->a( n = `header`    v = `Users`
            )->a( n = `subheader` v = `selected period`
            )->a( n = `class`     v = `sapUiTinyMarginEnd sapUiTinyMarginBottom`

            )->ele( `tileContent`
                )->ele( `TileContent`
                    )->a( n = `footer` v = `distinct SAP users behind the calls`

                    )->ele( `content`

                        )->tag( `NumericContent`
                            )->a( n = `value`      v = client->_bind( s_agent-users )
                            )->a( n = `icon`       v = `sap-icon://group`
                            )->a( n = `withMargin` v = `false` ).

    agents->ele( n = `SimpleForm` ns = `form`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->a( n = `editable` v = `false`
        )->a( n = `visible`  v = client->_bind( s_agent-installed )

        )->ele( n = `content` ns = `form`

            )->tag( `Label`
                )->a( n = `text` v = `Endpoint enabled`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_agent-enabled_text ) ).

    agents->ele( `Table`
        )->a( n = `headerText` v = `Agent calls per day (UTC)`
        )->a( n = `items`      v = client->_bind( s_agent-t_day )
        )->a( n = `visible`    v = client->_bind( s_agent-readable )
        )->a( n = `class`      v = `sapUiSmallMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Day`
            )->tag( `Column`
                )->a( n = `header` v = `Calls`
                )->a( n = `width`  v = `30%`
            )->tag( `Column`
                )->a( n = `header` v = `Refused by policy`
            )->tag( `Column`
                )->a( n = `header` v = `Refused or failed`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{DAY}`
                    )->tag( `ProgressIndicator`
                        )->a( n = `percentValue` v = `{BAR}`
                        )->a( n = `displayValue` v = `{CALLS}`
                        )->a( n = `state`        v = `{STATE}`
                        )->a( n = `showValue`    v = `true`
                    )->tag( `Text`
                        )->a( n = `text` v = `{POLICY}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{VALIDATION}` ).

    agents->ele( `Table`
        )->a( n = `headerText` v = `Agent calls per app`
        )->a( n = `items`      v = client->_bind( s_agent-t_app )
        )->a( n = `visible`    v = client->_bind( s_agent-readable )
        )->a( n = `class`      v = `sapUiMediumMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `App`
            )->tag( `Column`
                )->a( n = `header` v = `Calls`
            )->tag( `Column`
                )->a( n = `header` v = `Refused by policy`
            )->tag( `Column`
                )->a( n = `header` v = `Refused or failed`
            )->tag( `Column`
                )->a( n = `header` v = `Last call (UTC)`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{NAME}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{CALLS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{POLICY}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{VALIDATION}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{LAST}` ).

    agents->ele( `Table`
        )->a( n = `headerText` v = `Agent calls per MCP client`
        )->a( n = `items`      v = client->_bind( s_agent-t_client )
        )->a( n = `visible`    v = client->_bind( s_agent-readable )
        )->a( n = `class`      v = `sapUiMediumMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Client (name and version from initialize)`
            )->tag( `Column`
                )->a( n = `header` v = `Calls`
            )->tag( `Column`
                )->a( n = `header` v = `Refused by policy`
            )->tag( `Column`
                )->a( n = `header` v = `Refused or failed`
            )->tag( `Column`
                )->a( n = `header` v = `Last call (UTC)`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{NAME}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{CALLS}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{POLICY}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{VALIDATION}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{LAST}` ).

    agents->ele( `Table`
        )->a( n = `headerText`       v = `Last agent calls (user hidden unless user tracking is NAME)`
        )->a( n = `items`            v = client->_bind( s_agent-t_last )
        )->a( n = `visible`          v = client->_bind( s_agent-readable )
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `20`
        )->a( n = `class`            v = `sapUiMediumMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Time (UTC)`
            )->tag( `Column`
                )->a( n = `header` v = `User`
            )->tag( `Column`
                )->a( n = `header` v = `App`
            )->tag( `Column`
                )->a( n = `header` v = `Operation`
            )->tag( `Column`
                )->a( n = `header` v = `Event`
            )->tag( `Column`
                )->a( n = `header` v = `Outcome`
            )->tag( `Column`
                )->a( n = `header` v = `Text`
                )->a( n = `width`  v = `30%`
            )->tag( `Column`
                )->a( n = `header` v = `Client`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{TIME}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{USER}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{APP}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{OPERATION}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{EVENT}`
                    )->tag( `ObjectStatus`
                        )->a( n = `text`  v = `{KIND}`
                        )->a( n = `state` v = `{STATE}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{TEXT}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{CLIENT}` ).

    " --- Settings -------------------------------------------------------
    DATA(settings) = bar->ele( `IconTabFilter`
        )->a( n = `key`  v = `SETTINGS`
        )->a( n = `text` v = `Settings`
        )->a( n = `icon` v = `sap-icon://action-settings` ).

    settings->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `Roundtrip monitor`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->a( n = `editable` v = `true`

        )->ele( n = `content` ns = `form`

            )->tag( `Label`
                )->a( n = `text` v = `Mode`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( s_set-mode )
                )->a( n = `enabled`     v = client->_bind( s_head-can_change )

                )->ele( `items`

                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `ALL`
                        )->a( n = `text` v = `ALL - every roundtrip`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `SAMPLE`
                        )->a( n = `text` v = `SAMPLE - errors plus a share of the rest`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `ERRORS`
                        )->a( n = `text` v = `ERRORS - only failed roundtrips`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `OFF`
                        )->a( n = `text` v = `OFF - record nothing`

                )->end(
            )->end(

            )->tag( `Label`
                )->a( n = `text` v = `Sample share (%)`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( s_set-sample_pct )
                )->a( n = `type`    v = `Number`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->tag( `Label`
                )->a( n = `text` v = `Slow roundtrip from (ms)`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( s_set-slow_ms )
                )->a( n = `type`    v = `Number`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->tag( `Label`
                )->a( n = `text` v = `Retention log, users, activity (days)`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( s_set-retention_days )
                )->a( n = `type`    v = `Number`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->tag( `Label`
                )->a( n = `text` v = `Retention aggregates (days)`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( s_set-agg_retention_days )
                )->a( n = `type`    v = `Number`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->tag( `Label`
                )->a( n = `text` v = `User tracking`
            )->ele( `Select`
                )->a( n = `selectedKey` v = client->_bind( s_set-user_tracking )
                )->a( n = `enabled`     v = client->_bind( s_head-can_change )

                )->ele( `items`

                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `HASH`
                        )->a( n = `text` v = `HASH - daily pseudonym, no names (default)`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `NONE`
                        )->a( n = `text` v = `NONE - users are not counted`
                    )->tag( n = `Item` ns = `core`
                        )->a( n = `key`  v = `NAME`
                        )->a( n = `text` v = `NAME - store user names (works council!)`

                )->end(
            )->end(

            )->tag( `Label`
                )->a( n = `text` v = `App unused after (days)`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( s_set-unused_days )
                )->a( n = `type`    v = `Number`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->tag( `Label`
                )->a( n = `text` v = `Hint: response larger than (KB)`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( s_set-response_warn_kb )
                )->a( n = `type`    v = `Number`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->tag( `Label`
                )->a( n = `text` v = `Hint: model larger than (KB)`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( s_set-model_warn_kb )
                )->a( n = `type`    v = `Number`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->tag( `Label`
            )->tag( `Button`
                )->a( n = `text`    v = `Save settings`
                )->a( n = `type`    v = `Emphasized`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
                )->a( n = `press`   v = client->_event( `SETTINGS_SAVE` ) ).

    settings->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `Alerts - evaluated by the housekeeping job z2ui5_cl_cockpit_job=>run( )`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->a( n = `editable` v = `true`

        )->ele( n = `content` ns = `form`

            )->tag( `Label`
                )->a( n = `text` v = `Error rate from (%, 0 = off)`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( s_set-alert_err_pct )
                )->a( n = `type`    v = `Number`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->tag( `Label`
                )->a( n = `text` v = `p95 response time from (ms, 0 = off)`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( s_set-alert_p95_ms )
                )->a( n = `type`    v = `Number`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->tag( `Label`
                )->a( n = `text` v = `Only with at least (roundtrips)`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( s_set-alert_min_cnt )
                )->a( n = `type`    v = `Number`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->tag( `Label`
                )->a( n = `text` v = `Window: running UTC hour plus (hours)`
            )->tag( `Input`
                )->a( n = `value`   v = client->_bind( s_set-alert_hours )
                )->a( n = `type`    v = `Number`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
            )->tag( `Label`
                )->a( n = `text` v = `Notification`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_alerts-notifier )
            )->tag( `Label`
            )->tag( `Button`
                )->a( n = `text`    v = `Save settings`
                )->a( n = `type`    v = `Emphasized`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
                )->a( n = `press`   v = client->_event( `SETTINGS_SAVE` )
            )->tag( `Label`
            )->tag( `Button`
                )->a( n = `text`    v = `Send a test notification`
                )->a( n = `icon`    v = `sap-icon://email`
                )->a( n = `enabled` v = client->_bind( s_head-can_change )
                )->a( n = `press`   v = client->_event( `ALERT_TEST` ) ).

    settings->tag( `MessageStrip`
        )->a( n = `text`     v = `Germany and other countries: recording which user used which app and how long ` &&
                                 `it took can be performance and behaviour monitoring subject to works council ` &&
                                 `co-determination (BetrVG section 87 (1) no. 6). HASH and NONE store no user names; ` &&
                                 `agree NAME with your works council and data protection officer first.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginTop sapUiSmallMarginBottom` ).

    settings->ele( `Table`
        )->a( n = `headerText` v = client->_bind( s_head-auth_text )
        )->a( n = `items`      v = client->_bind( t_admins )
        )->a( n = `noDataText` v = `No administrator.`

        )->ele( `headerToolbar`
            )->ele( `OverflowToolbar`

                )->tag( `Title`
                    )->a( n = `text` v = `Administrators`
                )->tag( `ToolbarSpacer`
                )->tag( `Input`
                    )->a( n = `value`       v = client->_bind( new_admin )
                    )->a( n = `placeholder` v = `user name`
                    )->a( n = `width`       v = `12rem`
                    )->a( n = `enabled`     v = client->_bind( s_head-can_change )
                )->tag( `Button`
                    )->a( n = `text`    v = `Add`
                    )->a( n = `icon`    v = `sap-icon://add`
                    )->a( n = `enabled` v = client->_bind( s_head-can_change )
                    )->a( n = `press`   v = client->_event( `ADMIN_ADD` )

            )->end(
        )->end(

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `User`
            )->tag( `Column`
                )->a( n = `header` v = ``
                )->a( n = `width`  v = `5rem`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{UNAME}`
                    )->tag( `Button`
                        )->a( n = `icon`    v = `sap-icon://delete`
                        )->a( n = `type`    v = `Transparent`
                        )->a( n = `tooltip` v = `Remove`
                        )->a( n = `enabled` v = client->_bind( s_head-can_change )
                        )->a( n = `press`   v = client->_event( val = `ADMIN_REMOVE` arg = `${UNAME}` ) ).

    settings->ele( `Table`
        )->a( n = `headerText`       v = `Change log - claims, administrators, settings, deletions, reproductions`
        )->a( n = `items`            v = client->_bind( t_log )
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `20`
        )->a( n = `class`            v = `sapUiMediumMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Time (UTC)`
            )->tag( `Column`
                )->a( n = `header` v = `User`
            )->tag( `Column`
                )->a( n = `header` v = `Action`
            )->tag( `Column`
                )->a( n = `header` v = `Details`
                )->a( n = `width`  v = `50%`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{TIME}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{USER}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{ACTION}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{TEXT}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD view_no_auth.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    view->ele( `Shell`
        )->tag( `MessagePage`
            )->a( n = `title`       v = `abap2UI5 Admin Cockpit`
            )->a( n = `text`        v = `No authorization`
            )->a( n = `description` v = `Ask an administrator of the cockpit to add your user.`
            )->a( n = `icon`        v = `sap-icon://locked` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD on_claim.

    IF client->check_on_event( `CLAIM_ROLE` ).
      IF z2ui5_cl_cockpit_auth=>claim( ) = abap_true.
        model_init( ).
        view_display( ).
        client->message_box_display( text = |{ sy-uname } is the administrator of the admin cockpit now. Add further | &&
                                            |administrators on the Settings tab - the claim is in its change log.|
                                     type = `success` ).
      ELSE.
        view_claim( `Somebody else claimed the administrator role a moment ago - ask that user to add you.` ).
      ENDIF.
      RETURN.
    ENDIF.

    view_claim( ).

  ENDMETHOD.

  METHOD view_claim.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    DATA(content) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title` v = `abap2UI5 Admin Cockpit - claim the administrator role`

            )->ele( `content` ).

    content->tag( `MessageStrip`
        )->a( n = `text`     t = message
        )->a( n = `type`     v = `Error`
        )->a( n = `showIcon` v = `true`
        )->a( n = `visible`  b = xsdbool( message IS NOT INITIAL )
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    content->ele( `VBox`
        )->a( n = `class` v = `sapUiMediumMargin`

        )->tag( `Title`
            )->a( n = `text`  v = `This admin cockpit has no administrator yet`
            )->a( n = `level` v = `H2`
        )->tag( `Text`
            )->a( n = `text`  v = `The cockpit shows usage and configuration of the whole system and can delete ` &&
                                  `drafts, so it shows nothing until it has an administrator. The first user who ` &&
                                  `claims the role becomes that administrator and adds everybody else on the ` &&
                                  `Settings tab. The claim is written to the cockpit's change log.`
            )->a( n = `class` v = `sapUiSmallMarginTop`
        )->tag( `Text`
            )->a( n = `text`  t = |You are logged on as { sy-uname }. If you are not the person who should administer | &&
                                  |abap2UI5 on this system, close this page and tell that person.|
            )->a( n = `class` v = `sapUiSmallMarginTop`
        )->tag( `Button`
            )->a( n = `text`  t = |Claim the administrator role for { sy-uname }|
            )->a( n = `icon`  v = `sap-icon://locked`
            )->a( n = `type`  v = `Emphasized`
            )->a( n = `press` v = client->_event( `CLAIM_ROLE` )
            )->a( n = `class` v = `sapUiMediumMarginTop` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD popup_app.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core` ).

    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title`        t = |Events of { detail_app }|
        )->a( n = `contentWidth` v = `80%`
        )->a( n = `resizable`    v = `true` ).

    dialog->ele( `content`
        )->ele( `Table`
            )->a( n = `items` v = client->_bind( t_events )

            )->ele( `columns`

                )->tag( `Column`
                    )->a( n = `header` v = `Event`
                )->tag( `Column`
                    )->a( n = `header` v = `Roundtrips`
                )->tag( `Column`
                    )->a( n = `header` v = `Avg ms`
                )->tag( `Column`
                    )->a( n = `header` v = `p95 ms`
                )->tag( `Column`
                    )->a( n = `header` v = `Max ms`
                )->tag( `Column`
                    )->a( n = `header` v = `Errors`
                )->tag( `Column`
                    )->a( n = `header` v = `Avg KB`
                )->tag( `Column`
                    )->a( n = `header` v = `Last used`

            )->end(
            )->ele( `items`
                )->ele( `ColumnListItem`
                    )->ele( `cells`

                        )->tag( `Text`
                            )->a( n = `text` v = `{EVENT}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{ROUNDTRIPS}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{AVG_MS}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{P95_MS}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{MAX_MS}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{ERRORS}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{KB_RES_AVG}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{LAST_USED}` ).

    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Close`
            )->a( n = `press` v = client->follow_up_action( z2ui5_if_client=>cs_event-popup_close ) ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD popup_error.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core`
            )->a( n = `xmlns:form` v = `sap.ui.layout.form` ).

    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title`        v = `Error details`
        )->a( n = `contentWidth` v = `85%`
        )->a( n = `resizable`    v = `true` ).

    DATA(content) = dialog->ele( `content` ).

    content->ele( n = `SimpleForm` ns = `form`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->a( n = `editable` v = `false`

        )->ele( n = `content` ns = `form`

            )->tag( `Label`
                )->a( n = `text` v = `App`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_error-app )
            )->tag( `Label`
                )->a( n = `text` v = `Event`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_error-event )
            )->tag( `Label`
                )->a( n = `text` v = `Exception class`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_error-error_class )
            )->tag( `Label`
                )->a( n = `text` v = `Occurrences`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( s_error-count ) ).

    content->ele( `Table`
        )->a( n = `headerText`       v = `Occurrences, newest first - select one for its full exception chain`
        )->a( n = `items`            v = client->_bind( t_occurrences )
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `10`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Time (UTC)`
            )->tag( `Column`
                )->a( n = `header` v = `User`
            )->tag( `Column`
                )->a( n = `header` v = `Draft id`
            )->tag( `Column`
                )->a( n = `header` v = `ms`
            )->tag( `Column`
                )->a( n = `header` v = `Start`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->a( n = `type`  v = `Active`
                )->a( n = `press` v = client->_event( val = `ERROR_OCC` arg = `${ID}` )

                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{TIME}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{USER}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{DRAFT_ID}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{MS_TOTAL}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{START}` ).

    content->tag( `TextArea`
        )->a( n = `value`    v = client->_bind( error_text )
        )->a( n = `editable` v = `false`
        )->a( n = `rows`     v = `12`
        )->a( n = `width`    v = `100%` ).

    content->ele( `OverflowToolbar`

        )->tag( `Text`
            )->a( n = `text` v = client->_bind( repro_hint )
        )->tag( `ToolbarSpacer`
        )->tag( `Button`
            )->a( n = `text`    v = `Reproduce...`
            )->a( n = `icon`    v = `sap-icon://redo`
            )->a( n = `enabled` v = client->_bind( repro_enabled )
            )->a( n = `tooltip` v = `Re-runs the app logic of the selected occurrence - asks first`
            )->a( n = `press`   v = client->_event( `REPRODUCE` )
        )->tag( `Button`
            )->a( n = `text`    v = `Open session`
            )->a( n = `icon`    v = `sap-icon://history`
            )->a( n = `enabled` v = client->_bind( session_enabled )
            )->a( n = `tooltip` v = `The steps of the user up to this error, from the draft table - administrators only`
            )->a( n = `press`   v = client->_event( `SESSION_FROM_ERROR` ) ).

    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Close`
            )->a( n = `press` v = client->follow_up_action( z2ui5_if_client=>cs_event-popup_close ) ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD popup_confirm_delete.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core` ).

    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title`     v = `Delete expired drafts`
        )->a( n = `type`      v = `Message`
        )->a( n = `state`     v = `Warning`
        )->a( n = `draggable` v = `true` ).

    dialog->ele( `content`
        )->tag( `Text`
            )->a( n = `text` t = |{ s_drafts-rows_expired } drafts are older than the expiry of { s_drafts-expiry_hours } | &&
                                 |hours (written before { s_drafts-cutoff } UTC). Users returning to such a session | &&
                                 |start their app anew. Delete them now?| ).

    dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Delete`
            )->a( n = `type`  v = `Reject`
            )->a( n = `press` v = client->_event( `DRAFTS_DELETE_OK` ) ).

    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Cancel`
            )->a( n = `press` v = client->follow_up_action( z2ui5_if_client=>cs_event-popup_close ) ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD popup_confirm_reproduce.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core` ).

    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title`        v = `Reproduce - this runs the app logic again`
        )->a( n = `type`         v = `Message`
        )->a( n = `state`        v = `Warning`
        )->a( n = `contentWidth` v = `40rem` ).

    dialog->ele( `content`
        )->tag( `Text`
            )->a( n = `text` t = |{ s_error-app } is resumed from draft { s_occ-draft_id_prev } and event | &&
                                 |{ s_occ-event } is fired again through the headless frontend. This RE-RUNS the | &&
                                 |app logic for real, as you ({ sy-uname }) and with your authorizations: whatever | &&
                                 |the app writes, posts or sends happens again, and is committed if the app commits. | &&
                                 |It works only for draft-based (not sticky) apps, for your own drafts, and as long | &&
                                 |as the draft has not expired. Values typed in that roundtrip and event arguments | &&
                                 |are not recorded and not replayed. The replay is written to the change log. | &&
                                 |Run it now?| ).

    dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Re-run the app logic`
            )->a( n = `type`  v = `Reject`
            )->a( n = `press` v = client->_event( `REPRODUCE_OK` ) ).

    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Cancel`
            )->a( n = `press` v = client->_event( `REPRODUCE_BACK` ) ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD popup_reproduce.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core` ).

    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title`        v = `Reproduce - result of the replay`
        )->a( n = `contentWidth` v = `85%`
        )->a( n = `resizable`    v = `true` ).

    DATA(content) = dialog->ele( `content` ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( s_repro-summary )
        )->a( n = `type`     v = client->_bind( s_repro-strip_type )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    content->tag( `TextArea`
        )->a( n = `value`       v = client->_bind( s_repro-error_text )
        )->a( n = `editable`    v = `false`
        )->a( n = `rows`        v = `8`
        )->a( n = `width`       v = `100%`
        )->a( n = `placeholder` v = `no exception`
        )->a( n = `class`       v = `sapUiSmallMarginBottom` ).

    content->ele( `Table`
        )->a( n = `headerText` v = `Messages the app showed in the replay`
        )->a( n = `items`      v = client->_bind( s_repro-t_message )
        )->a( n = `noDataText` v = `No message.`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Type`
                )->a( n = `width`  v = `8rem`
            )->tag( `Column`
                )->a( n = `header` v = `Text`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{TYPE}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{TEXT}` ).

    content->tag( `Label`
        )->a( n = `text`  v = `View XML after the replay (every open layer)`
        )->a( n = `class` v = `sapUiSmallMarginTop` ).

    content->tag( `TextArea`
        )->a( n = `value`       v = client->_bind( s_repro-view_xml )
        )->a( n = `editable`    v = `false`
        )->a( n = `rows`        v = `12`
        )->a( n = `width`       v = `100%`
        )->a( n = `placeholder` v = `no view - the replayed roundtrip displayed none (the view before it is not recorded)` ).

    dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Back to the error`
            )->a( n = `press` v = client->_event( `REPRODUCE_BACK` ) ).

    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Close`
            )->a( n = `press` v = client->follow_up_action( z2ui5_if_client=>cs_event-popup_close ) ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD popup_session.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core` ).

    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title`         t = |Session of { s_session-user } - { s_session-app }|
        )->a( n = `contentWidth`  v = `95%`
        )->a( n = `contentHeight` v = `90%`
        )->a( n = `resizable`     v = `true`
        )->a( n = `draggable`     v = `true` ).

    DATA(content) = dialog->ele( `content` ).

    content->ele( `OverflowToolbar`

        )->tag( `Button`
            )->a( n = `icon`    v = `sap-icon://close-command-field`
            )->a( n = `tooltip` v = `First step`
            )->a( n = `enabled` v = client->_bind( step_can_back )
            )->a( n = `press`   v = client->_event( `STEP_FIRST` )
        )->tag( `Button`
            )->a( n = `icon`    v = `sap-icon://navigation-left-arrow`
            )->a( n = `text`    v = `Back`
            )->a( n = `enabled` v = client->_bind( step_can_back )
            )->a( n = `press`   v = client->_event( `STEP_BACK` )
        )->tag( `Title`
            )->a( n = `text`  v = client->_bind( step_text )
            )->a( n = `class` v = `sapUiTinyMarginBeginEnd`
        )->tag( `Button`
            )->a( n = `icon`      v = `sap-icon://navigation-right-arrow`
            )->a( n = `text`      v = `Next`
            )->a( n = `iconFirst` v = `false`
            )->a( n = `enabled`   v = client->_bind( step_can_next )
            )->a( n = `press`     v = client->_event( `STEP_NEXT` )
        )->tag( `Button`
            )->a( n = `icon`    v = `sap-icon://open-command-field`
            )->a( n = `tooltip` v = `Last step`
            )->a( n = `enabled` v = client->_bind( step_can_next )
            )->a( n = `press`   v = client->_event( `STEP_LAST` )
        )->tag( `ToolbarSpacer`
        )->tag( `CheckBox`
            )->a( n = `text`     v = `Only changes`
            )->a( n = `selected` v = client->_bind( step_changes )
            )->a( n = `select`   v = client->_event( `STEP_REFRESH` )
        )->tag( `CheckBox`
            )->a( n = `text`     v = `Framework objects`
            )->a( n = `selected` v = client->_bind( step_all )
            )->a( n = `select`   v = client->_event( `STEP_REFRESH` )
        )->tag( `SearchField`
            )->a( n = `value`       v = client->_bind( step_search )
            )->a( n = `search`      v = client->_event( `STEP_REFRESH` )
            )->a( n = `placeholder` v = `Field or value`
            )->a( n = `width`       v = `14rem` ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( step_info )
        )->a( n = `type`     v = client->_bind( step_strip )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginTopBottom` ).

    content->ele( `ScrollContainer`
        )->a( n = `height`     v = `12rem`
        )->a( n = `vertical`   v = `true`
        )->a( n = `horizontal` v = `false`

        )->ele( `Table`
            )->a( n = `items` v = client->_bind( t_steps )

            )->ele( `columns`

                )->tag( `Column`
                    )->a( n = `header` v = `Step`
                    )->a( n = `width`  v = `4rem`
                )->tag( `Column`
                    )->a( n = `header` v = `Time (UTC)`
                    )->a( n = `width`  v = `11rem`
                )->tag( `Column`
                    )->a( n = `header` v = `After`
                    )->a( n = `width`  v = `7rem`
                )->tag( `Column`
                    )->a( n = `header` v = `App`
                )->tag( `Column`
                    )->a( n = `header` v = `KB`
                    )->a( n = `width`  v = `4rem`
                )->tag( `Column`
                    )->a( n = `header` v = `Note`

            )->end(
            )->ele( `items`
                )->ele( `ColumnListItem`
                    )->a( n = `type`      v = `Active`
                    )->a( n = `highlight` v = `{STATE}`
                    )->a( n = `press`     v = client->_event( val = `STEP_GOTO` arg = `${STEP}` )

                    )->ele( `cells`

                        )->tag( `Text`
                            )->a( n = `text` v = `{STEP}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{TIME}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{DELTA}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{APP}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{KB}`
                        )->tag( `Text`
                            )->a( n = `text` v = `{NOTE}` ).

    content->ele( `Table`
        )->a( n = `headerText`       v = `Fields of the app after this step`
        )->a( n = `items`            v = client->_bind( s_step-t_field )
        )->a( n = `noDataText`       v = `No field - or none that matches the filter.`
        )->a( n = `growing`          v = `true`
        )->a( n = `growingThreshold` v = `200`
        )->a( n = `class`            v = `sapUiSmallMarginTop`

        )->ele( `columns`

            )->tag( `Column`
                )->a( n = `header` v = `Field`
                )->a( n = `width`  v = `30%`
            )->tag( `Column`
                )->a( n = `header` v = `Value`
            )->tag( `Column`
                )->a( n = `header` v = `Before`
            )->tag( `Column`
                )->a( n = `header` v = `Change`
                )->a( n = `width`  v = `7rem`

        )->end(
        )->ele( `items`
            )->ele( `ColumnListItem`
                )->a( n = `highlight` v = `{STATE}`

                )->ele( `cells`

                    )->tag( `Text`
                        )->a( n = `text` v = `{PATH}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{VALUE}`
                    )->tag( `Text`
                        )->a( n = `text` v = `{PREV}`
                    )->tag( `ObjectStatus`
                        )->a( n = `text`  v = `{CHANGE}`
                        )->a( n = `state` v = `{STATE}` ).

    dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text`    v = `Back to the error`
            )->a( n = `visible` v = client->_bind( session_from_error )
            )->a( n = `press`   v = client->_event( `SESSION_BACK` ) ).

    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Close`
            )->a( n = `press` v = client->follow_up_action( z2ui5_if_client=>cs_event-popup_close ) ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD sessions_load.

    s_sessions = z2ui5_cl_cockpit_session=>get_sessions( search = session_search ).
    sessions_shown = abap_true.
    IF s_sessions-check_readable = abap_false.
      sessions_text = |The draft table could not be read: { s_sessions-error }|.
      RETURN.
    ENDIF.
    sessions_text = |Sessions - { lines( s_sessions-t_session ) } shown of { s_sessions-sessions }, newest | &&
                    |activity first{ COND #( WHEN session_search IS NOT INITIAL
                                             THEN |, matching "{ session_search }"| ) }| &&
                    |{ COND #( WHEN s_sessions-check_capped = abap_true
                               THEN | - read from the newest { z2ui5_cl_cockpit_session=>c_max_nodes } drafts| ) }|.

  ENDMETHOD.

  METHOD session_open.

    DATA lv_index TYPE i.

    DATA(ls_steps) = z2ui5_cl_cockpit_session=>get_steps( id ).
    IF ls_steps-error IS NOT INITIAL.
      client->message_box_display( text = |The session could not be read: { ls_steps-error }|
                                   type = `error` ).
      RETURN.
    ENDIF.
    IF ls_steps-t_step IS INITIAL.
      client->message_toast_display( `The drafts of this session are gone - expired and deleted.` ).
      RETURN.
    ENDIF.

    t_steps = ls_steps-t_step.
    s_session = VALUE #( s_sessions-t_session[ id = id ] OPTIONAL ). "#EC CI_SORTSEQ
    IF s_session IS INITIAL.
      s_session = VALUE #( id    = id
                           user  = COND #( WHEN user IS NOT INITIAL THEN user ELSE `(unknown)` )
                           app   = t_steps[ lines( t_steps ) ]-app
                           steps = lines( t_steps ) ).
    ENDIF.

    " the change log first, committed - the session shows other users' data
    z2ui5_cl_cockpit_auth=>log( action = z2ui5_cl_cockpit_auth=>cs_log-session
                                text   = |session { id } opened: { lines( t_steps ) } steps, { s_session-app }, | &&
                                         |user { s_session-user }| ).
    COMMIT WORK.

    lv_index = lines( t_steps ).
    IF draft IS NOT INITIAL.
      LOOP AT t_steps INTO DATA(ls_step) WHERE id = draft. "#EC CI_SORTSEQ
        lv_index = ls_step-step.
      ENDLOOP.
    ENDIF.
    CLEAR step_search.
    step_show( lv_index ).
    IF ls_steps-check_capped = abap_true.
      step_info = |Only the newest { z2ui5_cl_cockpit_session=>c_max_steps } steps are shown. { step_info }|.
    ENDIF.
    popup_session( ).

  ENDMETHOD.

  METHOD step_show.

    DATA lv_prev TYPE string.

    IF t_steps IS INITIAL.
      RETURN.
    ENDIF.
    step_index = step_no.
    IF step_index < 1.
      step_index = 1.
    ELSEIF step_index > lines( t_steps ).
      step_index = lines( t_steps ).
    ENDIF.

    LOOP AT t_steps ASSIGNING FIELD-SYMBOL(<step>).
      <step>-state = COND #( WHEN <step>-step = step_index THEN `Information` ELSE `None` ).
    ENDLOOP.
    DATA(ls_step) = t_steps[ step_index ].
    IF ls_step-follows > 0.
      lv_prev = t_steps[ ls_step-follows ]-id.
    ENDIF.

    " the first step has nothing to compare with - all of it, whatever the filter
    s_step = z2ui5_cl_cockpit_session=>get_view( id            = ls_step-id
                                                id_prev       = lv_prev
                                                check_all     = step_all
                                                check_changes = xsdbool( step_changes = abap_true
                                                                         AND lv_prev IS NOT INITIAL )
                                                search        = step_search ).

    step_text = |Step { step_index } of { lines( t_steps ) } - { ls_step-time } UTC|.
    step_can_back = xsdbool( step_index > 1 ).
    step_can_next = xsdbool( step_index < lines( t_steps ) ).

    IF s_step-error IS NOT INITIAL.
      step_strip = `Error`.
      step_info = s_step-error.
      RETURN.
    ENDIF.
    step_strip = `Information`.
    IF lv_prev IS INITIAL.
      step_info = |{ s_step-app }: { s_step-fields } fields - the state after the first roundtrip of this session | &&
                  |that is still in the draft table.|.
    ELSE.
      step_info = |{ s_step-app }: { s_step-changes } of { s_step-fields } fields changed since step | &&
                  |{ ls_step-follows }{ COND #( WHEN ls_step-delta IS NOT INITIAL
                                                THEN |, { ls_step-delta } later| ) }. The values the user typed | &&
                  |and what the event did to them.|.
    ENDIF.
    IF ls_step-note IS NOT INITIAL.
      step_info = |{ step_info } ({ ls_step-note })|.
    ENDIF.
    IF s_step-check_capped = abap_true.
      step_info = |{ step_info } Showing { z2ui5_cl_cockpit_session=>c_max_fields } of { s_step-shown } fields - | &&
                  |narrow them with the search.|.
    ENDIF.

  ENDMETHOD.

  METHOD occurrence_select.

    DATA lv_owner TYPE string.

    s_occ = VALUE #( t_occurrences[ id = id ] OPTIONAL ). "#EC CI_SORTSEQ
    error_text = z2ui5_cl_cockpit_stats=>get_error_text( s_occ-id ).
    CLEAR repro_enabled.
    session_enabled = xsdbool( s_head-can_change = abap_true
                               AND ( s_occ-draft_id IS NOT INITIAL OR s_occ-draft_id_prev IS NOT INITIAL ) ).

    IF z2ui5_cl_cockpit_repro=>check_available( ) = abap_false.
      repro_hint = `Reproduce needs the headless frontend (github.com/abap2UI5-addons/headless-frontend).`.
      RETURN.
    ENDIF.
    IF s_head-can_change = abap_false.
      repro_hint = `Reproduce re-runs app logic - administrators only.`.
      RETURN.
    ENDIF.
    IF s_occ IS INITIAL.
      repro_hint = `Select an occurrence.`.
      RETURN.
    ENDIF.

    lv_owner = z2ui5_cl_cockpit_stats=>get_occurrence_owner( s_occ-id ).
    repro_hint = z2ui5_cl_cockpit_repro=>check_possible( draft_id_prev = s_occ-draft_id_prev
                                                        event         = s_occ-event
                                                        check_sticky  = s_occ-check_sticky
                                                        owner         = lv_owner ).
    IF repro_hint IS INITIAL.
      repro_enabled = abap_true.
      repro_hint = |Occurrence of { s_occ-time }: draft { s_occ-draft_id_prev }, event { s_occ-event }| &&
                   |{ COND #( WHEN lv_owner = z2ui5_cl_cockpit_repro=>cs_owner-unknown
                              THEN ` - works only if the draft is yours and not expired` ) }|.
    ENDIF.

  ENDMETHOD.

  METHOD on_event.

    TRY.
        CASE client->get_event( ).

          WHEN `TAB` OR `REFRESH` OR `PERIOD`.
            load_tab( ).

          WHEN `APP_DETAIL`.
            detail_app = client->get_event_arg( ).
            t_events = z2ui5_cl_cockpit_stats=>get_app_events( app  = detail_app
                                                              days = get_days( ) ).
            popup_app( ).

          WHEN `ERROR_DETAIL`.
            DATA(lv_key) = client->get_event_arg( ).
            s_error = VALUE #( t_errors[ key = lv_key ] OPTIONAL ). "#EC CI_SORTSEQ
            t_occurrences = z2ui5_cl_cockpit_stats=>get_error_occurrences( is_error = s_error
                                                                          days     = get_days( ) ).
            occurrence_select( VALUE #( t_occurrences[ 1 ]-id OPTIONAL ) ).
            popup_error( ).

          WHEN `ERROR_OCC`.
            occurrence_select( client->get_event_arg( ) ).

          WHEN `REPRODUCE`.
            IF check_change( ) = abap_true AND repro_enabled = abap_true.
              popup_confirm_reproduce( ).
            ENDIF.

          WHEN `REPRODUCE_OK`.
            IF check_change( ) = abap_true AND repro_enabled = abap_true.
              " the change log first, committed: the replayed app may roll back
              z2ui5_cl_cockpit_auth=>log( action = z2ui5_cl_cockpit_auth=>cs_log-repro
                                          text   = |{ s_error-app } event { s_occ-event } from draft | &&
                                                   |{ s_occ-draft_id_prev } (log entry { s_occ-id })| ).
              COMMIT WORK.
              s_repro = z2ui5_cl_cockpit_repro=>run( draft_id_prev = s_occ-draft_id_prev
                                                    event         = s_occ-event ).
              popup_reproduce( ).
            ENDIF.

          WHEN `REPRODUCE_BACK`.
            popup_error( ).

          WHEN `DRAFTS_DELETE`.
            IF check_change( ) = abap_true.
              s_drafts = z2ui5_cl_cockpit_draft=>get_info( ).
              popup_confirm_delete( ).
            ENDIF.

          WHEN `DRAFTS_DELETE_OK`.
            client->popup_destroy( ).
            IF check_change( ) = abap_true.
              z2ui5_cl_cockpit_auth=>log( action = z2ui5_cl_cockpit_auth=>cs_log-drafts
                                          text   = |expired drafts deleted, cutoff { s_drafts-cutoff } UTC| ).
              DATA(lv_deleted) = z2ui5_cl_cockpit_draft=>delete_expired( ).
              client->message_toast_display( |{ lv_deleted } expired drafts deleted| ).
              load_tab( ).
            ENDIF.

          WHEN `DRAFTS_ANALYZE`.
            s_analysis = z2ui5_cl_cockpit_draft=>analyze( ).
            analyzed = abap_true.
            analysis_text = |Draft size per app - { s_analysis-rows_analyzed } drafts, { s_analysis-kb_total } KB| &&
                            |{ COND #( WHEN s_analysis-check_partial = abap_true THEN ` (first rows only)` ) }|.

          WHEN `LOG_PURGE`.
            IF check_change( ) = abap_true.
              DATA(ls_purge) = z2ui5_cl_cockpit_job=>purge_own( ).
              z2ui5_cl_cockpit_auth=>log( action = z2ui5_cl_cockpit_auth=>cs_log-purge
                                          text   = |{ ls_purge-log_deleted } log, { ls_purge-agg_deleted } aggregate, | &&
                                                   |{ ls_purge-usr_deleted } user, { ls_purge-act_deleted } activity rows| ).
              COMMIT WORK.
              client->message_toast_display( |{ ls_purge-log_deleted } log, { ls_purge-agg_deleted } aggregate, | &&
                                             |{ ls_purge-usr_deleted } user, { ls_purge-act_deleted } activity rows deleted| ).
            ENDIF.

          WHEN `JOB_RUN`.
            IF check_change( ) = abap_true.
              z2ui5_cl_cockpit_auth=>log( action = z2ui5_cl_cockpit_auth=>cs_log-job
                                          text   = `full housekeeping run from the cockpit` ).
              client->message_box_display( z2ui5_cl_cockpit_job=>run( )-message ).
              load_tab( ).
            ENDIF.

          WHEN `SETTINGS_SAVE`.
            IF check_change( ) = abap_true.
              z2ui5_cl_cockpit_setup=>save( s_set ).
              z2ui5_cl_cockpit_auth=>log( action = z2ui5_cl_cockpit_auth=>cs_log-settings
                                          text   = |mode { s_set-mode }, user tracking { s_set-user_tracking }, | &&
                                                   |slow { s_set-slow_ms } ms, retention { s_set-retention_days }/| &&
                                                   |{ s_set-agg_retention_days } days, alerts { s_set-alert_err_pct } %/| &&
                                                   |{ s_set-alert_p95_ms } ms from { s_set-alert_min_cnt } roundtrips, | &&
                                                   |window +{ s_set-alert_hours } h| ).
              COMMIT WORK.
              client->message_toast_display( `Settings saved` ).
              load_head( ).
              load_tab( ).
            ENDIF.

          WHEN `ALERT_TEST`.
            IF check_change( ) = abap_true.
              DATA(lv_sent) = z2ui5_cl_cockpit_alert=>send_test( ).
              z2ui5_cl_cockpit_auth=>log( action = z2ui5_cl_cockpit_auth=>cs_log-alert
                                          text   = |test notification: { lv_sent }| ).
              " the commit sends what the notification class queued
              COMMIT WORK.
              client->message_box_display( |Test notification: { lv_sent }| ).
              load_tab( ).
            ENDIF.

          WHEN `ADMIN_ADD`.
            IF check_change( ) = abap_true AND new_admin IS NOT INITIAL.
              z2ui5_cl_cockpit_setup=>add_admin( new_admin ).
              z2ui5_cl_cockpit_auth=>log( action = z2ui5_cl_cockpit_auth=>cs_log-add
                                          text   = |{ to_upper( new_admin ) } added| ).
              COMMIT WORK.
              CLEAR new_admin.
              load_head( ).
              load_tab( ).
            ENDIF.

          WHEN `ADMIN_REMOVE`.
            IF check_change( ) = abap_true.
              IF lines( t_admins ) <= 1.
                client->message_box_display( text = `The last administrator cannot be removed - the next ` &&
                                                    `user to open the cockpit could claim it.`
                                             type = `warning` ).
                RETURN.
              ENDIF.
              DATA(lv_removed) = client->get_event_arg( ).
              z2ui5_cl_cockpit_setup=>remove_admin( lv_removed ).
              z2ui5_cl_cockpit_auth=>log( action = z2ui5_cl_cockpit_auth=>cs_log-remove
                                          text   = |{ lv_removed } removed| ).
              COMMIT WORK.
              load_head( ).
              load_tab( ).
            ENDIF.

          WHEN `LOCKS`.
            nav_lock_monitor( ).

          WHEN `SESSIONS_LOAD`.
            IF check_change( ) = abap_true.
              sessions_load( ).
            ENDIF.

          WHEN `SESSION_OPEN`.
            IF check_change( ) = abap_true.
              session_from_error = abap_false.
              session_open( client->get_event_arg( ) ).
            ENDIF.

          WHEN `SESSION_FROM_ERROR`.
            IF check_change( ) = abap_true.
              " the draft the failing roundtrip wrote, if it got that far,
              " else the one it started from - the screen the user was on
              DATA(lv_draft) = s_occ-draft_id.
              DATA(lv_session) = z2ui5_cl_cockpit_session=>get_session_of( lv_draft ).
              IF lv_session IS INITIAL.
                lv_draft = s_occ-draft_id_prev.
                lv_session = z2ui5_cl_cockpit_session=>get_session_of( lv_draft ).
              ENDIF.
              IF lv_session IS INITIAL.
                client->message_toast_display( `The drafts of this occurrence are gone - expired and deleted.` ).
              ELSE.
                session_from_error = abap_true.
                session_open( id    = lv_session
                              draft = lv_draft
                              user  = s_occ-user ).
              ENDIF.
            ENDIF.

          WHEN `SESSION_BACK`.
            popup_error( ).

          WHEN `STEP_FIRST` OR `STEP_BACK` OR `STEP_NEXT` OR `STEP_LAST` OR `STEP_GOTO` OR `STEP_REFRESH`.
            IF check_change( ) = abap_true.
              CASE client->get_event( ).
                WHEN `STEP_FIRST`.
                  step_show( 1 ).
                WHEN `STEP_BACK`.
                  step_show( step_index - 1 ).
                WHEN `STEP_NEXT`.
                  step_show( step_index + 1 ).
                WHEN `STEP_LAST`.
                  step_show( lines( t_steps ) ).
                WHEN `STEP_GOTO`.
                  step_show( CONV i( client->get_event_arg( ) ) ).
                WHEN OTHERS.
                  step_show( step_index ).
              ENDCASE.
            ENDIF.

        ENDCASE.

      CATCH cx_root INTO DATA(lx).
        client->message_box_display( lx ).
    ENDTRY.

  ENDMETHOD.

  METHOD load_head.

    s_head-version    = z2ui5_if_app=>version.
    s_head-platform   = COND #( WHEN z2ui5_cl_cockpit_inst=>check_cloud( ) = abap_true
                                THEN `ABAP Cloud` ELSE `Standard ABAP` ).
    s_head-user       = sy-uname.
    s_head-auth_text  = |Administrators - access: { z2ui5_cl_cockpit_auth=>get_mode_text( ) }|.
    s_head-can_change = z2ui5_cl_cockpit_auth=>check( z2ui5_if_cockpit_auth=>cs_action-change ).
    s_monitor         = z2ui5_cl_cockpit_stats=>get_monitor( ).

  ENDMETHOD.

  METHOD load_tab.

    DATA(lv_days) = get_days( ).

    CASE tab.
      WHEN `OVERVIEW`.
        s_kpi       = z2ui5_cl_cockpit_stats=>get_kpi( ).
        t_trend     = z2ui5_cl_cockpit_stats=>get_trend( ).
        t_alert_now = z2ui5_cl_cockpit_alert=>check( ).
        s_alerts    = z2ui5_cl_cockpit_alert=>get_status( t_alert_now ).
        t_alert_log = z2ui5_cl_cockpit_alert=>get_history( ).
      WHEN `APPS`.
        t_apps   = z2ui5_cl_cockpit_stats=>get_apps( lv_days ).
        t_unused = z2ui5_cl_cockpit_stats=>get_unused( ).
        unused_title = |Unused apps - implementers of z2ui5_if_app without a roundtrip in | &&
                       |{ z2ui5_cl_cockpit_setup=>get( )-unused_days } days|.
      WHEN `ERRORS`.
        t_errors = z2ui5_cl_cockpit_stats=>get_errors( lv_days ).
      WHEN `PERF`.
        t_hints = z2ui5_cl_cockpit_stats=>get_hints( lv_days ).
        t_slow  = z2ui5_cl_cockpit_stats=>get_slowest( lv_days ).
      WHEN `DRAFTS`.
        s_drafts = z2ui5_cl_cockpit_draft=>get_info( ).
        drafts_failed = xsdbool( s_drafts-check_readable = abap_false ).
        IF sessions_shown = abap_true AND s_head-can_change = abap_true.
          sessions_load( ).
        ENDIF.
      WHEN `SECURITY`.
        s_install = z2ui5_cl_cockpit_inst=>get_install( ).
        t_checks  = z2ui5_cl_cockpit_inst=>get_checks( ).
        t_addons  = z2ui5_cl_cockpit_inst=>get_addons( ).
      WHEN `LIVE`.
        s_live = z2ui5_cl_cockpit_stats=>get_live( ).
      WHEN `AGENTS`.
        s_agent = z2ui5_cl_cockpit_agent=>get_info( lv_days ).
      WHEN `SETTINGS`.
        s_set = z2ui5_cl_cockpit_setup=>get( ).
        s_alerts-notifier = z2ui5_cl_cockpit_alert=>get_notifier_class( ).
        IF s_alerts-notifier IS INITIAL.
          s_alerts-notifier = `none - implement z2ui5_if_cockpit_notify to be told (README, Alerts)`.
        ENDIF.
        CLEAR t_admins.
        LOOP AT z2ui5_cl_cockpit_setup=>get_admins( ) INTO DATA(lv_admin).
          APPEND VALUE #( uname = lv_admin ) TO t_admins.
        ENDLOOP.
        t_log = z2ui5_cl_cockpit_auth=>get_log( ).
    ENDCASE.

  ENDMETHOD.

  METHOD check_change.

    result = z2ui5_cl_cockpit_auth=>check( z2ui5_if_cockpit_auth=>cs_action-change ).
    IF result = abap_false.
      client->message_box_display( text = `You may display the cockpit, but not change anything.`
                                   type = `error` ).
    ENDIF.

  ENDMETHOD.

  METHOD get_days.

    CASE days.
      WHEN `1`.
        result = 1.
      WHEN `30`.
        result = 30.
      WHEN OTHERS.
        result = 7.
    ENDCASE.

  ENDMETHOD.

  METHOD nav_lock_monitor.

    " the lock-manager addon is optional: created by name, never referenced
    DATA lo_app TYPE REF TO z2ui5_if_app.
    TRY.
        CREATE OBJECT lo_app TYPE (`Z2UI5_CL_APP_SM12`).
        client->nav_app_call( lo_app ).
      CATCH cx_root.
        client->message_box_display( text = `The lock monitor of the lock-manager addon could not be started.`
                                     type = `warning` ).
    ENDTRY.

  ENDMETHOD.

  METHOD enum_defaults.

    " Every tab is part of the one view, so UI5 renders a MessageStrip or a
    " NumericContent of a tab whose data is loaded only when the tab is
    " opened. An empty enum value fails the property's type check ("" is
    " of type string, expected sap.ui.core.MessageType) and terminates the
    " app. Set at the end of every roundtrip, so a tab loaded later
    " overwrites the default with its own value.
    IF s_monitor-strip_type IS INITIAL.
      s_monitor-strip_type = `Information`.
    ENDIF.
    IF s_alerts-strip_type IS INITIAL.
      s_alerts-strip_type = `Information`.
    ENDIF.
    IF s_agent-strip_type IS INITIAL.
      s_agent-strip_type = `Information`.
    ENDIF.
    IF s_repro-strip_type IS INITIAL.
      s_repro-strip_type = `Information`.
    ENDIF.
    IF step_strip IS INITIAL.
      step_strip = `Information`.
    ENDIF.
    IF s_kpi-p95_state IS INITIAL.
      s_kpi-p95_state = `Neutral`.
    ENDIF.
    IF s_kpi-error_state IS INITIAL.
      s_kpi-error_state = `Neutral`.
    ENDIF.
    IF s_kpi-drafts_state IS INITIAL.
      s_kpi-drafts_state = `Neutral`.
    ENDIF.

  ENDMETHOD.

  METHOD model_init.

    days = `7`.
    step_changes = abap_true.
    load_head( ).
    " without the monitor the quick win is the security tab
    tab = COND #( WHEN s_monitor-check_data = abap_true THEN `OVERVIEW` ELSE `SECURITY` ).
    load_tab( ).

  ENDMETHOD.

ENDCLASS.
