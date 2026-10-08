# abap2UI5 Admin Cockpit

**Is abap2UI5 used? Is it fast? Is it safely configured?** The three questions
an IT lead asks before abap2UI5 goes to production - answered by an abap2UI5
app, installed with abapGit next to abap2UI5.

```
?app_start=z2ui5_cl_cockpit_app
```

| Tab | What it shows | Needs |
|---|---|---|
| **Overview** | Tiles: active users today, roundtrips today, p95 response time, error rate, draft table size, sessions with errors in the draft table (select it to step through them) - the last 30 days, one row per day - and the **alerts**: thresholds exceeded right now and the alert history (see [Alerts](#alerts)) | monitor |
| **Apps** | Per app class: users, sessions, roundtrips, avg/p95 ms, response and model size, errors, last used - select one for its events, its sessions in the draft table and the **business objects it works with** (from its drafts, types only). Plus the **unused apps**: implementers of `z2ui5_if_app` without a roundtrip in N days | monitor |
| **Errors** | Grouped by app, event, exception class and first line, with count and first/last seen; the detail shows every occurrence, the full exception chain, the draft id and the user (pseudonymized by default), and **what the user did afterwards** - continued from the same screen, stopped there, still open (from the drafts) - **Analyze failures**: the values the failing cases share and other states of the app rarely have, and the business objects they concern - **Open session**: the user's steps up to the error (see [Sessions](#sessions---step-through-what-a-user-did)) - and **Reproduce**: re-run the failed event on its draft (see [Reproduce an error](#reproduce-an-error)) | monitor (Reproduce: headless-frontend) |
| **Performance** | The slowest roundtrips with their phase breakdown (load / main / render, plus the browser's own measure), and runtime hints: model larger than 1 MB, large responses, slow p95, growing app state, dominant phases, expired drafts nobody deletes | monitor |
| **Drafts & Housekeeping** | Rows, age, owners and expiry of the abap2UI5 draft table, size per app on demand; the **sessions** in it - step through what a user did, roundtrip by roundtrip (see [Sessions](#sessions---step-through-what-a-user-did)); **find a value** (an order number, a customer) in all drafts; the **navigation** between apps; delete expired drafts (with confirmation), purge the cockpit's own log by retention - the same as a class for a background job | - |
| **Installation & Security** | abap2UI5 version, platform, user exit, UI5 bootstrap and theme, the installed addons - and a **security traffic light**: CSRF origin check, hidden error details, CSP without `'unsafe-eval'`/`'unsafe-inline'`, security headers, reachable developer addons, the cockpit's own access. Every check with status, why it matters and how to fix it | - |
| **Live** | Who is active now: drafts written in the last 5 minutes, apps in use from the monitor, the **sessions active right now** - open one to see what the user is doing - and a pointer to the lock-manager addon's monitor when it is installed | (monitor) |
| **Agents** | What AI agents did through the [agent addon](https://github.com/abap2UI5-addons/agent)'s MCP endpoint: calls per day, per app and per MCP client, refusals by policy and by validation, the last calls, endpoint enabled yes/no (see [Agents](#agents)) | agent addon |
| **Settings** | Monitor mode, slow threshold, retention, privacy mode, alert thresholds with a test notification, administrators, and the change log (claims, administrators, settings, deletions, reproductions, opened and exported sessions, draft searches, failure analyses, test notifications) | - |

The tabs marked *-* work **without any logging** - install, open, read the
traffic light. That is the quick win.

## Screenshots

*Placeholder - screenshots of the Overview, Errors and Installation & Security
tabs follow with the first release.*

## Installation

1. **abap2UI5** first - <https://github.com/abap2UI5/abap2UI5>.
2. **This repository** with abapGit, into a package of its own (for example
   `Z2UI5_COCKPIT`; the folder logic is PREFIX, so `src/01` and `src/02` become
   `Z2UI5_COCKPIT_01` and `Z2UI5_COCKPIT_02`). Pick the branch by your
   abap2UI5 release:

   | Your abap2UI5 | Branch | What you get |
   |---|---|---|
   | has `z2ui5_if_ui5_monitor` (the release after 1.146.0) | `main` | everything |
   | 1.146.0 or later without the monitor hook | `standalone` | Installation & Security, Drafts & Housekeeping, Settings - the monitor tabs say what they need |

3. Start `z2ui5_cl_cockpit_app` right away: a cockpit without an
   administrator shows nothing but a **Claim the administrator role** screen -
   the first user who presses its button becomes the administrator (see
   [Security of the cockpit itself](#security-of-the-cockpit-itself)).

4. **Switch the monitor on** in your user exit, once the pull is complete and
   every object is active. abap2UI5 calls no monitor until the exit says so,
   so a cockpit that does not activate cannot break your apps:

   ```abap
   METHOD z2ui5_if_ui5_exit~set_config_http_post.
     cs_config-check_monitor_active = abap_true.
   ENDMETHOD.
   ```

   Until then the usage, error and performance tabs stay empty. Setting it
   back to `abap_false` stops the recording on the next roundtrip. The field
   exists in abap2UI5 releases that ship the opt-in. On an abap2UI5 that has
   the monitor hook but not the field yet, the monitor runs as soon as the
   cockpit is installed.

Once your abap2UI5 has the monitor hook, switch the abapGit repository from
`standalone` to `main` and pull. Then switch the monitor on (step 4).

### Two packages, two branches

| Package | Content | Activates on |
|---|---|---|
| `src/01` | The app, every tab, the tables, settings, authorization, housekeeping, the recorder `z2ui5_cl_cockpit_rec`, the request recorder `z2ui5_cl_cockpit_wire` | every abap2UI5 release with `z2ui5_cl_ui5_view_builder` |
| `src/02` | `z2ui5_cl_cockpit_monitor` - the one class that implements the core's `z2ui5_if_ui5_monitor` and forwards to the recorder | abap2UI5 with the monitor hook |

The split sits exactly at the dependency: nothing in `src/01` names the
monitor interface or the monitor class (the app checks for both by name, at
run time, and shows a "requires abap2UI5 with z2ui5_if_ui5_monitor" message
where they are missing). Even the screens of Overview, Apps, Errors and
Performance live in `src/01` - they only read the cockpit's own tables.

**Why a second branch instead of "just install `src/01`":** abapGit always
pulls a whole repository. On an abap2UI5 without the monitor interface the
one class in `src/02` would fail to activate - abapGit reports the error,
leaves the class inactive and shows it as a diff on every pull. The
`standalone` branch is `main` without `src/02`, generated by
`.github/workflows/publish-standalone.yaml` on every push to `main`, after
linting `src/01` against the released abap2UI5 (the tag `1.146.0`, pinned:
`main` of abap2UI5 already carries the hook).

## How the monitor works

Once the user exit switches it on (`check_monitor_active`, installation step
4), abap2UI5 finds `z2ui5_cl_cockpit_monitor` on its own - the first class
implementing `z2ui5_if_ui5_monitor` by name, looked up once per roll area,
the way it finds the user exit - and calls `on_roundtrip` once per POST
roundtrip, after the response is built, on success and on failure. The class
maps the structure by name (`MOVE-CORRESPONDING`, so a field the core adds or
renames never breaks the activation) and hands it to `z2ui5_cl_cockpit_rec`,
which decides by the settings what is persisted:

| Table | Written | Content |
|---|---|---|
| `Z2UI5_T_CK_AGG` | every recorded roundtrip, updated in place, lock-free | per UTC day, hour, app and event: count, app starts, errors, slow ones, sum and max of the total and of each phase, request/response KB, largest response and model, browser time, and a latency histogram of nine buckets (the p95 is interpolated from it) |
| `Z2UI5_T_CK_USR` | once per user, day and app | the user key (see privacy) - distinct users per day |
| `Z2UI5_T_CK_ACT` | every recorded roundtrip | user key and app with the last-seen time - the Live tab |
| `Z2UI5_T_CK_LOG` | errors and slow roundtrips only | one raw row: timings per phase, sizes, draft ids, exception class, first line and full chain |
| `Z2UI5_T_CK_SET` | settings | name/value |
| `Z2UI5_T_CK_ADM` | administrators | user names |
| `Z2UI5_T_CK_AUD` | every change made in the cockpit | change log: time, user, action, details - kept as long as the aggregates |
| `Z2UI5_T_CK_ALR` | by the housekeeping job, per raised or cleared alert | alert history: rule, app, value, threshold, raised and cleared, what the notification answered - kept as long as the aggregates |

**Lock-free and overflow-safe.** A roundtrip is added to the row of its hour
with one `UPDATE ... SET cnt = cnt + 1, ms_sum = ms_sum + n, ...` - atomic on
every database, so two work processes never lose each other's counts and
nobody waits for a row lock (no `SELECT ... FOR UPDATE`, the same statement on
ABAP Cloud). No row yet: `INSERT`; lost the race for it: the `UPDATE` once
more. The maxima are conditional `UPDATE`s (`... WHERE ms_max < n`). The sum
columns (milliseconds, KB) are `DEC 15` - an `INT4` overflows at 2.1 billion,
which a busy hour of one app can reach in milliseconds; `INT8` does not exist
below 7.50, `DEC 15` exists on every release and on ABAP Cloud. The increments
are saturated at the largest `DEC 15` before they are written, the counts stay
`INT4` per hour row, the read side adds days up in packed numbers and shows
them saturated at the largest `INT4` - and whatever a database still refuses,
`record( )` catches: the monitor never dumps.

**It never breaks an app.** Everything is caught; the core swallows anything a
monitor raises anyway. A syntax error is the one thing no `CATCH` stops - a
class that does not activate dumps whoever calls it - which is why the core
calls no monitor until the exit switches it on. **Commit semantics** follow the interface: for an app
that is not sticky the LUW is empty when the monitor runs (the framework
committed its draft save, or rolled back a failed roundtrip right before the
call), so the recorder writes its rows and issues `COMMIT WORK` itself - the
core offers no commit helper. For a sticky (stateful) app the LUW belongs to
the app (uncommitted work, update tasks, locks), so the recorder writes
**nothing** then: the entry waits in the roll area, which a sticky session
keeps, and is written with the first roundtrip of that roll area that is not
sticky (at most 500 entries are buffered). A session that ends while still
sticky loses its buffered entries - the price of never touching the app's
LUW; a secondary database connection would avoid it, but exists on Standard
ABAP only.

**What it costs:** a handful of single-row statements per roundtrip
(settings and the daily salt are read once per roll area). Mode `SAMPLE`
records errors fully and only a share of the rest - decided on the
milliseconds of the start time - weighted so counts stay estimates of the
totals; `ERRORS` records failed roundtrips only; `OFF` stops
recording without uninstalling. The own tables purge themselves once per day
on the first recorded roundtrip.

**Only one monitor is called.** If your installation has a monitor of its own
that sorts before `Z2UI5_CL_COCKPIT_MONITOR`, the cockpit says so; call
`z2ui5_cl_cockpit_rec=>record( )` from your monitor to feed both.

## Settings

| Setting | Default | |
|---|---|---|
| Mode | `ALL` | `ALL`, `SAMPLE`, `ERRORS`, `OFF` |
| Sample share | 10 % | `SAMPLE` only |
| Slow roundtrip from | 2000 ms | lands in the raw log with its phases |
| Retention log, users, activity | 30 days | |
| Retention aggregates | 400 days | |
| User tracking | `HASH` | `HASH`, `NONE`, `NAME` - see below |
| App unused after | 90 days | Apps tab |
| Hint thresholds | 500 KB response, 1024 KB model | Performance tab |
| Alert: error rate from | 5 % | `0` switches the rule off - see [Alerts](#alerts) |
| Alert: p95 from | 2000 ms | `0` switches the rule off |
| Alert: only with at least | 20 roundtrips | per app, and over all apps |
| Alert: window | running UTC hour plus 1 | `0` to `23` hours before the running one |
| Recorder retention | 2 days | `0` stops the [recorder](#recorder---replay-what-the-user-saw) |

## Privacy and the works council

**Privacy mode is on by default: no user names are stored.**

- `HASH` (default) - users are counted under a SHA-256 pseudonym of a random
  salt and the user name. The salt is created per UTC day and the previous
  day's salt is deleted, so a pseudonym can neither be traced back to a name
  nor linked to the same user on another day - not even by an administrator
  with database access. Hence "users per day", never "users per month".
- `NONE` - users are not counted at all; Live shows apps, not users.
- `NAME` - user names are stored (raw log, user and activity tables) and shown
  in the error details.

The draft table of abap2UI5 itself carries the user name (the framework binds
a draft to its owner). The cockpit shows its per-user statistics as "User 1,
User 2, ..." unless user tracking is `NAME`, and the session list under
today's pseudonym. The *content* of a session - the app's data after every
step - is business data of that user: administrators only, every opened
session in the change log (see [Sessions](#sessions---step-through-what-a-user-did)).
The [recorder](#recorder---replay-what-the-user-saw), once added to the handler,
stores even more: what users typed and saw, for 2 days by default.

**Germany (and similar elsewhere):** recording which employee used which
application, when and how fast, is a technical device suitable for monitoring
behaviour or performance - introducing it is subject to works council
co-determination (§ 87 (1) no. 6 BetrVG), regardless of whether anybody
intends to evaluate individuals. `HASH` and `NONE` are designed to keep the
cockpit on the side of aggregate system monitoring; agree `NAME` with your
works council and your data protection officer before switching it on, and
document the retention. This is not legal advice.

## Security of the cockpit itself

The cockpit shows usage and configuration of the whole system and can delete
drafts - it must be restricted. Like every abap2UI5 app it can be started by
anybody who reaches the abap2UI5 ICF node, so it checks access itself, at the
top of `main( )`:

1. **A class of your own implementing `z2ui5_if_cockpit_auth`** decides, if
   there is one (found like the user exit, first implementer by name):

   ```abap
   CLASS zcl_my_cockpit_auth DEFINITION PUBLIC FINAL CREATE PUBLIC.
     PUBLIC SECTION.
       INTERFACES z2ui5_if_cockpit_auth.
   ENDCLASS.

   CLASS zcl_my_cockpit_auth IMPLEMENTATION.
     METHOD z2ui5_if_cockpit_auth~check.
       " standard ABAP, for example: basis administrators only
       AUTHORITY-CHECK OBJECT 'S_ADMI_FCD' ID 'S_ADMI_FCD' FIELD 'ST0R'.
       result = xsdbool( sy-subrc = 0 ).
     ENDMETHOD.
   ENDCLASS.
   ```

   `action` is `DISPLAY` (open the cockpit) or `CHANGE` (delete drafts, purge
   logs, change settings and administrators, reproduce errors). A class that
   cannot be created denies.
2. **Otherwise the administrator list** on the Settings tab (`Z2UI5_T_CK_ADM`).
   Only the users on it get in; everybody else sees "No authorization".
3. **As long as that list is empty, the cockpit shows only the claim
   screen** - one button, *Claim the administrator role for <you>*, and nothing
   of the system. The first user who presses it becomes the administrator; the
   claim is a row with a fixed key, so of two users claiming at the same moment
   exactly one wins. The claim is written to the change log (Settings tab).
   Claim it right after the installation; the traffic light shows the
   unclaimed cockpit in red. The last administrator cannot be removed on the
   Settings tab.

**The administrator has left?** Reset the list with one class method - in a
two-line report, an ABAP Cloud console class (`if_oo_adt_classrun`) or the
test environment of SE24/ADT:

```abap
" hand the cockpit to a named user ...
z2ui5_cl_cockpit_auth=>reset_admins( 'NEW_ADMIN' ).
" ... or empty the list, so the next user who opens the cockpit can claim it
z2ui5_cl_cockpit_auth=>reset_admins( ).
```

Both commit and both are written to the change log.

The cockpit reads framework internals - the draft table `Z2UI5_T_01`, the user
exit instance, the draft store, the class lookup - only by name, with dynamic
SQL and dynamic calls, and read-only except for the draft cleanup. A later
abap2UI5 release that renames one of them costs the cockpit that number, never
its activation.

## Reproduce an error

The detail of an error group offers **Reproduce...** for the selected
occurrence when the [headless frontend](https://github.com/abap2UI5-addons/headless-frontend)
(`z2ui5_cl_frontend_simulator`) is installed. It resumes the draft the failed
request came with (`draft_id_prev` of the log entry) and fires the same event
again, through the simulator - the app runs exactly as it ran for the user,
and the cockpit shows the exception chain, the messages the app showed and the
view XML the roundtrip displayed.

**It re-runs the app logic for real.** Whatever the event writes, posts or
sends happens again - as the administrator, with the administrator's
authorizations, and committed if the app commits. The cockpit therefore asks
first, offers it to administrators only (`CHANGE`) and writes every replay to
the change log before it starts. Limits, all shown in the dialog:

- **draft-based apps only** - a sticky (stateful) app keeps no draft;
- **only drafts that still exist** - drafts expire (4 hours by default);
- **only your own drafts** - abap2UI5 binds a draft to its owner. The cockpit
  knows the owner from the user name (user tracking `NAME`) or from today's
  pseudonym (`HASH`, same UTC day only); otherwise it tries, and the simulator
  says "no draft" when the draft is somebody else's;
- **the event, not the values** - what the user typed in that roundtrip and
  the event's arguments are not recorded, so they are not replayed.

The simulator is called dynamically and named only in literals: the cockpit
activates without it and simply does not offer the button.

## Sessions - step through what a user did

Every POST roundtrip of abap2UI5 saves the app as it is afterwards into a new
draft and names the draft it started from (`ID_PREV`), across app navigations
too. Followed backwards, the drafts of one browser session form a chain - the
**session**. The Drafts & Housekeeping tab lists the sessions in the draft
table (**Show sessions**, newest activity first, searchable by app or user):
user, app, number of steps, **failed roundtrips** the monitor logged in the
session (*With errors only* keeps just those), first and last step, duration.
The same list, limited to the last 5 minutes, is on the **Live** tab - who is
working right now, and on what - and the app detail of the **Apps** tab opens
it filtered to that app.

Open one and the viewer shows it **step by step**:

- **First / Back / Next / Last**, or select any step in the list - time,
  seconds since the step before, app, size, and notes such as *navigated to
  ZCL_...*, *continues step 3* (browser back or a second window) or *the steps
  before it expired*;
- how many **fields changed** in the step - a step that changed nothing is
  marked *no field changed*, and when that happens twice or more in a row the
  viewer warns: the user pressed something again and again without effect (a
  button that does nothing, a check that refuses without a message);
- the **messages the app holds** in its state when they appear - a BAPI return
  or a message table: a structure or row with a type `E`/`A`/`X`/`W` (`TYPE`,
  `MSGTY`, `SEVERITY`) and a text (`MESSAGE`, `MSG`, `TEXT` for errors). These
  are the business errors the user saw, which are no exception and never reach
  the Errors tab;
- the **business objects** of the session - an order, a customer, a material -
  recognized by the field name (`VBELN`, `KUNNR`, `MATNR`, `EBELN`, `BELNR`,
  `AUFNR`, the flight and RAP demo keys, `ORDER_ID`, `CUSTOMER`, ..., also as
  the end of a name like `MV_VBELN`), each with the step it first appears in;
- what the **roundtrip monitor** logged about a step, when it is active: the
  roundtrip that started from this step and **failed** (exception class,
  first line, event - the row is red), and the slow roundtrip that wrote it
  (event, milliseconds). The monitor logs only failed and slow roundtrips, so
  the event of an ordinary step stays empty;
- the **fields of the app** after that step - every attribute of the app
  object and the objects it references, nested structures and table rows as
  paths (`ZCL_ORDER-MT_ITEMS[2]-MATNR`), references as an arrow to the class;
- **what changed** since the step it continues - new, changed (with the value
  before) and removed, highlighted; *Only changes* (default) hides the rest,
  *Framework objects* adds abap2UI5's own container, the search narrows by
  field or value;
- **Compare with this step** pins a step: every other step is then compared
  with it instead of with the step before - what differs between the screen
  that worked and the one that failed;
- select a field for its **history** - its value in every step of the
  session, the steps where it changed highlighted, each one a jump target:
  *when did the quantity become 0?*
- a warning when the **app state grows**: when the last step is twice the size
  of the first and above 20 KB, the viewer names the tables that grew most
  (`ZCL_APP-MT_LOG 3 -> 1200 rows`) - state that is serialized and read back
  on every roundtrip, and makes each one slower.

**Analyze failures** in the error detail looks for the cause in the data: it
takes the states the failed roundtrips started from (as long as their drafts
exist) and compares them with up to 300 other states of the same app. A value
in at least 80 % of the failing states and at most 30 % of the others is
listed - *`ZCL_ORDER-MS_HEAD-QTY = 0`: in 5 of 5 failing, in 3 % of 120
other states* - a correlation to check first, not a proof. Next to it the
business objects of the failing states, counted: *Customer 1000 in 4 of 5* -
a data problem, not a code problem. Needs two failing states with drafts;
written to the change log (`ERROR_ANALYSIS`).

The app detail of the **Apps** tab shows the **business objects an app works
with** - per object type the number of its drafts it appears in. Types only,
no values: an app understood in business terms without reading its code.

**Find a value in all drafts** answers the question a support call starts
with - *"I had a problem with order 4711"*: it searches every field of every
draft (case-insensitive, at least 3 characters) and lists user, time, app,
field and value; a hit opens its session at that step, the fields filtered to
the value. Every search is written to the change log (`DRAFTS_SEARCH`), with
the term.

**Analyze navigation** counts how users move between apps - the business
process as users walk it: per pair of apps the navigations in the draft
table, per app the sessions that start in it (`(start)`), and where sessions
end - `(end)` after 30 minutes without a step, `(end after an error)` when a
failed roundtrip started from the last step: where users give up. Only class
names are read, no content.

**Export** writes the whole session into a text file - every field of the
first step, then per step what changed, with events and monitor notes - to
attach to a ticket for the app's developer. Every export is written to the
change log.

From an error, **Open session** in the error detail jumps straight to the step
the failing roundtrip started from - the screen the user was on, with the
values the user had typed. That complements [Reproduce](#reproduce-an-error),
which replays the event but not the values.

What it is and is not:

- **The state after each roundtrip, not the event.** A step is the app's
  attributes once the roundtrip finished; the event the user pressed is not in
  the draft (the Errors tab has it for failed roundtrips; the
  [recorder](#recorder---replay-what-the-user-saw) adds it to every step).
- **As long as the drafts live** - 4 hours by default, see the expiry on the
  tab. Sticky (stateful) apps write no drafts while sticky.
- **Read as text.** The serialized state (asXML) is taken apart without
  loading a class from it - an app class that no longer activates cannot break
  the cockpit. Generic data references of an app are kept in the framework's
  own objects; *Framework objects* shows them.
- **Limits:** the newest 50,000 drafts, 100 sessions per list, the newest 500
  steps of a session, 1,000 fields per step (narrow them with the search).

**Drafts hold business data of other users.** The sessions are offered to
administrators only (`CHANGE`), and every opened or exported session is
written to the change log (`SESSION_VIEW`, `SESSION_EXPORT`), with the
session's first draft, its app and the user as the list shows it; so is every
search in the drafts (`DRAFTS_SEARCH`) and every failure analysis
(`ERROR_ANALYSIS`). Agree it with your works council like the rest of the monitoring
(see [Privacy](#privacy-and-the-works-council)).

## Recorder - replay what the user saw

The drafts show what an app *held* after each step. What the user *saw* and
*did* - the screen, the button, the error box - never reaches a draft. The
recorder takes it where it passes anyway: the HTTP handler. One line after
the framework's own call stores the complete request and response of every
roundtrip, untouched:

```abap
" Standard ABAP - your ICF handler
z2ui5_cl_ui5_http_handler=>run( server ).
z2ui5_cl_cockpit_wire=>record( server ).

" ABAP Cloud - your if_http_service_extension~handle_request
z2ui5_cl_ui5_http_handler=>run( req = request res = response ).
z2ui5_cl_cockpit_wire=>record( req = request res = response ).
```

It needs no abap2UI5 API beyond the handler (the bodies are read as they
went over the wire, and taken apart only when someone looks), never raises,
records only POST roundtrips, and never commits inside a sticky app's LUW -
those wait in the roll area like the monitor's entries.

What it gives you, in the session viewer:

- **"User did" per step** - the control pressed, by its label (`pressed
  Button "Save" (SAVE)`), and the fields typed before it (`typed Input
  "Customer" = 4712`).
- **"Shown" per step** - the message boxes, toasts and popups the response
  opened, error boxes highlighted.
- **Screen** - the screen of the step rebuilt from the recorded view XML and
  the model as the responses and inputs left it: the values in the fields,
  the rows of the tables (50 each), the popup on top with its buttons. Every
  event handler is emptied, a press in the copy fires nothing. The control
  the user pressed next is **outlined in orange** - on the popup when one
  was open. *Previous screen* / *Next screen* step through the session like
  a film, each screen with what the user did on it next - or that the next
  click failed.
- **Request / Response** - the raw bodies, the inputs, the view XML, and for
  a step whose next click ended in an HTTP 500 the failed request itself.

The Errors tab adds **"Messages users saw"**: the error and warning boxes and
toasts of the last days, per app and text, how often and for how many users.
Search it for the text from a ticket ("Material not found") - selecting a
message opens the session where it was shown last, at that step.

**Process variants** (Drafts & Housekeeping, and per app in the Apps tab
detail) - process mining on the recordings: every run from the start of a
session to where nothing continued it, written as its events in order and
counted. Runs of the same way are one variant:

```
ZORDER: (start) -> CREATE -> SAVE (failed) -> SAVE => ZDELIVERY: SHIP   12 runs  40 %
ZORDER: (start) -> CREATE -> SAVE (failed)                               5 runs  red
ZORDER: (start) -> SEARCH -> NEXT (repeated) -> DISPLAY                  9 runs
```

- an event is counted on the app whose screen it was pressed on, `=>` is an
  app change;
- a click that failed and was tried again stands in place (orange row), a
  run that ended in a failed click is red - the ways into an error, with
  how often each happens;
- `(repeated)` is the same event several times in a row, so paging through
  ten pages and through two is one way;
- reads no body, only ids and event names - up to 20,000 recordings;
- selecting a variant opens its newest run in the session viewer
  (administrators).

**Retention:** 2 days by default (Settings, *Recorder retention*; `0` stops
recording, the line in the handler can stay). The Installation tab shows
whether it records and warns above 7 days. Housekeeping purges it.

**Privacy:** the bodies are the business data the user typed and saw -
everything a screen shows. Recordings are read by administrators only and only
inside a session that is already written to the change log; the user is
stored under the pseudonym unless user tracking is `NAME`. Keep the retention
short and agree it with your works council like the rest of the monitoring.

## Agents

When the [agent addon](https://github.com/abap2UI5-addons/agent) is installed
(detected by its class `z2ui5_cl_agent_settings` or its audit table
`Z2UI5_T_AG_LOG`), the Agents tab reads its audit log and settings - with
dynamic SQL inside `TRY`, so there is no dependency either way:

- endpoint enabled yes/no, with the opted-in apps (implementers of
  `z2ui5_if_agent_app`), the APP rules and the agent administrators;
- calls per day, per app and per MCP client (name and version from
  `initialize`), each split into refused by **policy** (endpoint disabled, app
  not enabled for agents, event forbidden or reserved for a human) and refused
  or failed otherwise (**validation** - wrong field or value, unknown or
  expired session, the app raised);
- the last calls with operation, event, outcome and text; the user only with
  user tracking `NAME`.

The traffic light gets an agent line: disabled is green; enabled without an
agent administrator is red; enabled with an `APP *` allow rule (every app
class, not only the opted-in ones) or with no reachable app at all is yellow.

## Alerts

Two rules, both on the Settings tab: an **error rate** and a **p95 response
time**, each "from" a threshold. They are evaluated on the aggregates of the
monitor, in a window of the UTC hour running now plus a number of full hours
before it (default: 1, so 60 to 120 minutes), per app and over all apps:

- an app with fewer roundtrips in the window than the minimum (default 20)
  raises nothing - three failures out of four are no alert;
- the line over all apps raises a rule only when no single app raises it
  already - it is there for the many small apps that stay below the minimum
  one by one, and one broken app is not reported twice.

The Overview tab evaluates the rules live: what is exceeded right now, and the
history. The **housekeeping job** `z2ui5_cl_cockpit_job=>run( )` keeps that
history in `Z2UI5_T_CK_ALR`: an alert is *raised* by the first run that finds
the threshold exceeded and *cleared* by the first run that no longer finds it -
so a broken app costs one notification when it breaks and one when it is fine
again, not one per run. Schedule the job every 15 minutes (see
[Housekeeping and background jobs](#housekeeping-and-background-jobs)); without
it the Overview still shows what is exceeded, but nothing is kept or sent.

**Notifications** go to a class of your own implementing
`z2ui5_if_cockpit_notify` (found like the user exit, first implementer by
name). It gets one structure per raised or cleared alert - rule, app, value,
threshold, roundtrips, time, `<SID>/<client>` and a ready sentence - and is
called inside the job's LUW: the job commits after it, so a mail queued with
the released mail API is sent with that commit.

```abap
CLASS zcl_my_cockpit_notify DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_cockpit_notify.
ENDCLASS.

CLASS zcl_my_cockpit_notify IMPLEMENTATION.
  METHOD z2ui5_if_cockpit_notify~notify.
    " ABAP Cloud - on Standard ABAP cl_bcs, or your chat webhook, or a ticket.
    " notify( ) may raise any cx_static_check: the cockpit notes it in the
    " alert history and goes on.
    DATA(lo_mail) = cl_bcs_mail_message=>create_instance( ).
    lo_mail->set_sender( 'abap2ui5@example.com' ).
    lo_mail->add_recipient( 'basis-team@example.com' ).
    lo_mail->set_subject( CONV #( |[{ alert-system }] { alert-event }: { alert-text }| ) ).
    lo_mail->set_main( cl_bcs_mail_textpart=>create_instance(
      iv_content      = alert-text
      iv_content_type = 'text/plain' ) ).
    lo_mail->send( ).
  ENDMETHOD.
ENDCLASS.
```

Whatever the class raises is caught and noted in the alert history
("Notification" column) - a failing notification never stops the job. The
button **Send a test notification** on the Settings tab calls the class with
event `TEST` (administrators only, written to the change log). Without a
class, alerts are still evaluated, kept and shown - only nobody is told, and
the Overview says so.

## Housekeeping and background jobs

The Drafts & Housekeeping tab deletes expired drafts (older than the expiry the
framework computes - 4 hours by default, or what your user exit sets) through
the framework's own draft store, and purges the cockpit's rows past their
retention. For a job, call `z2ui5_cl_cockpit_job=>run( )` - it also evaluates
the [alerts](#alerts), so schedule it every 15 minutes when you want to be
notified:

- **Standard ABAP** - a two-line report, scheduled in SM36:

  ```abap
  REPORT z2ui5_cockpit_job.
  z2ui5_cl_cockpit_job=>run( ).
  ```

- **ABAP Cloud** - an application job: a class of your own implementing
  `if_apj_dt_exec_object` / `if_apj_rt_exec_object` whose `execute` calls
  `z2ui5_cl_cockpit_job=>run( )`, plus the job catalog entry and template.

## Platforms

ABAP Cloud and Standard ABAP from 7.50, released APIs only; the 7.02 downport
is linted in CI (`ABAP_702`). The UI runs on UI5 1.71 and later (OpenUI5 and
SAPUI5): IconTabBar, GenericTile, sap.m tables - no SAPUI5-only micro charts.

## Development

```
npm ci
npm run lint            # abaplint, Standard ABAP 7.50, both packages
npm run lint:cloud      # ABAP Cloud
npm run lint:standalone # package 01 against the released abap2UI5
npm run lint:702        # after npm run downport (rewrites src/ - CI only)
npm run check:abap2ui5  # the abap2UI5 linter: views, bindings, chain layout
npm run unit            # the ABAP Unit tests on abap2UI5's transpiled runtime
```

**Unit tests.** The pure logic has ABAP Unit tests (`*.clas.testclasses.abap`):
p95 from the histogram, the runtime hint rules, error grouping, unused apps,
the privacy modes and the daily salt rotation, the recorder's aggregation,
the security traffic light and the agent check from given structures, the
access decision, the Agents figures, when an error can be reproduced, and the
alert rules with what a run raises and clears. The
classes that touch the database (`ltcl_salt`, `ltcl_rec`) are `RISK LEVEL
DANGEROUS`: they write rows of the test app `ZZ_COCKPIT_UNIT_TEST` on days in
2099, never commit, and delete and roll back in `teardown`. Without a system
they run on abap2UI5's transpiled runtime (SQLite behind the database
statements, so the `DANGEROUS` classes run too): `npm run unit` runs every
`Z2UI5_CL_COCKPIT*` test, `UNIT_FILTER=ltcl_rec npm run unit` only those whose
`OBJECT: class->method` contains the text. `.github/scripts/unit.mjs` is the
whole recipe, and the `ABAP_UNIT` workflow runs the same script on every push
and pull request: a checkout of abap2UI5 (the branch with
`z2ui5_if_ui5_monitor`) in `.unit/abap2UI5` (git-ignored; cloned on the first
run, refreshed on every later one), `npm ci` there, `src/01` and `src/02`
copied in as one more package, `npm run downport && npm run auto_transpile`,
then the generated tests - each one printed, exit code 1 on any failure or
when none ran. The first run takes a few minutes.

**Temporary state:** until `@abap2ui5/linter` releases its list with the
monitor interface (abap2UI5/linter#140, merged), `abap2ui5lint.jsonc` waives
`non-released-api` for the monitor class.

See [AGENTS.md](AGENTS.md) for the conventions of this repository.

## Roadmap

- **Export** of the aggregates to OpenTelemetry / SAP Cloud ALM, so abap2UI5
  shows up next to the rest of the landscape.
- **Reproduce with the user's input** - record the model delta and the event
  arguments of a failed roundtrip (opt-in, privacy!) so the replay sends them
  too.
- Per-app authorization overview: which roles may start which app classes.

## License

MIT
