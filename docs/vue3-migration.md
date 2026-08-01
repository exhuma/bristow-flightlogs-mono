# Vue 3 migration — ground truth and calendar parity checklist

Status snapshot taken 2026-08-01 by codebase exploration. Update this
file as migration work lands; delete it when the migration is done.

## Branch reality

- `develop`, `master`, and the checked-out
  `copilot/prepare-for-upgrade-to-vue3` are all **Vue 2.7 + Vuetify
  2.6**. The checked-out branch adds composition-API refactors and test
  coverage only — no dependency changes.
- `origin/vuejs3` (last commit 2024-07-14, message "WIP") is the only
  real Vue 3 attempt: Vue 3.4, Vuetify 3.6, vue-router 4, Vite 5,
  Vitest 1, `@vue/test-utils` 2. It is roughly two years behind
  `develop`: no defect reports, no KPI view, no charts, no policy
  editor, and it still uses `@azure/msal-browser` instead of
  `oidc-client-ts`. Its calendar view regressed to the Options API,
  its `title` computed literally returns `'TODO'`, `calendarNow` is
  hard-coded to a 2024 date, and its template passes Vuetify-2-only
  props to the labs `VCalendar`.
- **Recommendation: re-fork from `develop`; use `vuejs3` only as
  reference material, never merge it.**
- `origin/vue-3` is misleadingly named — it points at a Vue 2 commit
  (an ancestor of the current branch).

## The calendar today (the parity target)

- View: `frontend/src/views/booking/BookingManagementView.vue`
  (~1100 lines, `<script setup>`), route `/` alias `/calendar`.
- Event tile: `frontend/src/components/CalendarBlock.vue` — customer or
  label, instructor, crew pills, tooltip detail grid, `cancelled` and
  `no-show` CSS overlays.
- Data flow: `BookingBridge.asCalEvent()` in
  `frontend/src/bridge/bookings.ts` maps `Booking` to
  `TVCalendarEvent`; visible-range fetches are driven by the
  calendar's `@change` event.
- User settings persisted via `frontend/src/core/userSettings.ts`:
  `calendarMode`, `date`, `selectedSimulatorId`, `coloriseBy`.

### Feature surface that must be reproduced

1. `<v-calendar>` with `type` = `month` / `week` (toolbar), `day`
   (via day click); `4day` is typed but unused.
2. `event-overlap-mode="column"` with `event-overlap-threshold="30"`.
3. Interval config: `interval-minutes="120"`, `interval-count="12"`,
   `interval-height`, custom `interval-format`.
4. Imperative ref API (typed as `TVCalendar` in
   `frontend/src/types/vuetify.d.ts`): `lastStart`, `lastEnd`,
   `next()`, `prev()`, `timestampToDate()`,
   `scrollToTime({hour: 8, minute: 0})`, `type`. Used for the title,
   range boundaries, navigation and initial scroll. **None of this
   exists on Vuetify 3's labs `VCalendar` — biggest migration risk.**
5. `@change` event driving all backend fetching by visible range.
6. `#interval` scoped slot with `minutesToPixels`: draws the simulator
   **maintenance-window** hatched overlay (base64 pattern, light and
   dark variants).
7. `#event` scoped slot receiving `{ event, timeSummary, timed }`,
   rendering `CalendarBlock`.
8. `@click:event` (edit/select booking, or jump to techlog when
   read-only), `@click:day` (drill into day view), `@click:time`
   (create booking at the clicked slot).
9. Dynamic `event-color` / `event-text-color`: colorise by customer,
   instructor or course, with `getReadableColor()` contrast handling.
10. Deep CSS into Vuetify internals, e.g.
    `.v-calendar-events .v-event-timed:has(.selected)` and
    `.v-calendar-monthly { height: 80vh }`.
11. Toolbar: deferred-defect dialog, customer masking toggle,
    weekly-sheet PDF export (month/week + timezone picker), simulator
    toggle, today/prev/next, horizontal wheel scrolling.

### Known smells to fix rather than port

- `defineExpose({...})` with a TODO admitting it is a smell.
- `@ts-expect-error` on `scrollToTime` typing.
- `refresh()` performing several sequential awaits (TODO in code).
- A `created()` call at the end of `<script setup>`.

## Vue-2-only chokepoints (must be rewritten regardless of approach)

- `frontend/src/types/vuetify.d.ts` — hand-written Vuetify 2 calendar
  types (`TVCalendar`, `TVCalendarTimestamp`, `TCalendarMode`, …).
- `frontend/src/types/shims-vue.d.ts` — `declare module
  "vue/types/vue"` augmentation (Vue 2 only).
- `frontend/src/core/timestamps.ts` — `VuetifyDate` producing
  Vuetify 2 `"YYYY-MM-DD HH:mm"` strings.
- `frontend/src/plugins/localConfig.ts` — installs config onto
  `Vue.prototype`.
- `frontend/src/router/index.ts` (`new VueRouter`),
  `frontend/src/main.ts` (`new Vue`),
  `frontend/src/plugins/vuetify.ts`.
- `frontend/tests/setup.ts` (`Vue.use(Vuetify)`, `vi.mock("vue", …)`)
  and the two calendar specs
  (`tests/views/BookingManagementView.spec.ts`,
  `tests/components/CalendarBlock.spec.ts`) — written against
  `@vue/test-utils` v1 (`createLocalVue`), must be rewritten for v2.

## Unmerged branches worth harvesting before/during migration

- `origin/70-calendar-mouse-support` (2024-10-21) — drag/drop and
  bottom resize marker on calendar blocks; merged with develop at the
  time.
- `origin/70-mouse-context-menu` (2024-10-15, WIP) — context menu.
- `origin/calendar-scrolling` (2024-02-14, WIP).
- `origin/group-event-color` (2023-12-03) — auto event colors.
- `origin/slot-slider` (2023-06-17).

## Calendar decision (2026-08-01)

Vuetify 3's `VCalendar` is ruled out: it is still a labs component with
broken slots and click events, no imperative API, no overlap column
mode and no `#interval` slot (confirmed via upstream issues, e.g.
vuetifyjs/vuetify#21783). The port stalled after the Vuetify 2 calendar
author left the project.

**Chosen replacement: vue-cal v5** (https://antoniandre.github.io/vue-cal
— MIT, no paid tier, zero dependencies, Vue-3-native). Constraint from
the project owner: the component must be entirely free. Mapping to the
parity checklist:

- Week/day/month views; view switching and navigation are prop-driven
  (no imperative ref API needed).
- Custom event rendering via Vue slots — `CalendarBlock.vue` drops in
  mostly unchanged.
- Overlapping events render side by side; per-event CSS classes/colors
  cover the colorise-by feature.
- Cell/event click and view-change events cover `@click:time`,
  `@click:event` and `@change`-driven fetching.
- Built-in drag/drop and resize future-proofs the shelved
  `70-calendar-mouse-support` work.
- Scroll-to-hour is supported declaratively.
- The maintenance-window hatch overlay is the one feature needing hand
  work (vue-cal "special hours" backgrounds or a custom cell slot).

**Fallback if vue-cal hits a wall:** FullCalendar (`@fullcalendar/vue3`
with `daygrid`, `timegrid`, `interaction`) — those plugins are MIT/free;
only unneeded resource-timeline views are premium. More complete
(native background events, `scrollToTime`, `datesSet`) but a heavier
bundle and non-Vue-native rendering bridge.

Wrap whichever library in a project-owned `BookingCalendar.vue` so the
rest of the app never imports the library directly; a `useCalendar()`
composable owns range/navigation/colorise state. This keeps the library
swappable and the view component small.

## Migration plan (for the dedicated migration session)

Work happens inside the `frontend/` submodule on a new branch off
`develop` (suggested name: `vue3-migration`). Milestones, each leaving
the app bootable:

1. **Toolchain**: vue 3.5+, vuetify 3.8+, vue-router 4, vite (current),
   `@vitejs/plugin-vue`, current `vue-tsc`, `@vue/test-utils` v2,
   `vite-plugin-vuetify`. Drop `@vitejs/plugin-vue2`,
   `vue-template-compiler`, `@vitejs/plugin-legacy` (re-evaluate need).
2. **Bootstrap**: rewrite `src/main.ts` (`createApp`),
   `src/router/index.ts` (`createRouter`/`createWebHistory`),
   `src/plugins/vuetify.ts` (Vuetify 3 theme from the same colors),
   `src/plugins/localConfig.ts` (provide/inject instead of
   `Vue.prototype`), delete `src/types/shims-vue.d.ts` Vue-2
   augmentations, port `tests/setup.ts`.
3. **Mechanical component port**: 94/98 SFCs are already
   `<script setup lang="ts">`; the work is Vuetify 2→3 API renames
   (v-list/v-select/v-data-table APIs, theme class names) and the four
   template-only components. Port view by view, keeping `npm run
   type-check` green.
4. **Calendar rebuild**: new `BookingCalendar.vue` (vue-cal v5) +
   `useCalendar()` composable replacing the `TVCalendar` ref API usage
   in `BookingManagementView.vue`; port `CalendarBlock.vue` into the
   event slot; re-implement the maintenance hatch overlay; wire
   colorise-by, click-to-create, day drill-down, week/month toggle and
   the toolbar. Delete `src/types/vuetify.d.ts` and the `VuetifyDate`
   Vuetify-2 date strings in `src/core/timestamps.ts`.
5. **Tests**: port the 25 specs to `@vue/test-utils` v2 (no
   `createLocalVue`), rewrite the two calendar specs against the new
   wrapper, keep `npm run test:unit -- --run` green.
6. **Parity check**: seed data, screenshot the same three states as the
   Vue 2 reference and compare side by side (see below).

Do not merge or cherry-pick `origin/vuejs3`; use it only to look up how
individual API translations were attempted.

## Parity verification recipe

The Vue 2 reference screenshots live in
`docs/screenshots/vue2-calendar/` (week by customer, week by
instructor, week B737, month A320; taken 2026-08-01 with the seed data
below). To reproduce the same state on any branch:

1. `task db:up && task dev` (root Taskfile; ports/config via `.env`,
   see `.env.sample`).
2. Seed: `python3 dev-utilities/seed-calendar-demo.py` (uses dev-auth
   admin over HTTP; set `BACKEND_PORT` if overridden). Two backend
   quirks make naive seeding fail — the script works around the fixed
   `TechLog.empty()` UUID, but you must first create the dev-auth user
   row: `curl -u admin:x localhost:8210/auth/me`, then
   `INSERT INTO users (id, issuer, display_name) SELECT
   'admin@dev-auth', issuer, display_name FROM users WHERE
   id='admin@dev-auth@dev-auth';` (upstream bug: dev-auth persists a
   double-suffixed id while writes look up the single-suffixed one).
3. Browser login needs OIDC (the SPA has no dev-auth login): run
   Keycloak 26 (`quay.io/keycloak/keycloak:26.2 start-dev`, port 8214,
   admin/admin), run an adapted `backend/.devcontainer/init-keycloak.py`
   (Keycloak URL → localhost:8214, web-client redirect →
   `http://localhost:8211/*`), set `sslRequired=NONE` on the master and
   test-app realms via kcadm (podman-forwarded traffic looks external),
   and put the three `FLIGHTLOGS_OIDC_*`/`FLIGHTLOGS_ADMIN_EMAIL` vars
   in the root `.env` (see `.env.sample`). Log in as `user`/`pass`.
4. Select a simulator toggle — the calendar only renders bookings once
   one is active.

## No e2e safety net

There are no Playwright/Cypress tests. Parity verification is manual:
run the app (`task dev`), seed as above, and compare month/week/day
views, event tiles, overlays and toolbar behaviour against the
reference screenshots.
