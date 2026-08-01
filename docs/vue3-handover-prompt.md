# Handover prompt for the Vue 3 migration session

Copy the block below into a fresh AI session started in the
`flightlogs-mono` repository root.

---

Migrate the frontend of this project from Vue 2.7 + Vuetify 2 to
Vue 3 + Vuetify 3, aiming for close visual parity with the current
version — the booking calendar is the critical piece.

Read these before writing any code:

1. `AGENTS.md` — repo layout (two git submodules), conventions,
   dev commands (root `Taskfile.yaml`), Quartermaster usage.
2. `docs/vue3-migration.md` — the prepared ground truth: branch
   reality, the full calendar parity checklist, the Vue-2-only
   chokepoint files, the decided calendar approach, the milestone
   plan, and the parity verification recipe.
3. The Vue 2 reference screenshots in
   `docs/screenshots/vue2-calendar/` — these are the acceptance
   criterion for the calendar.

Key decisions already made (do not relitigate without new evidence):

- Work in the `frontend/` submodule on a new branch `vue3-migration`
  forked from `origin/develop`. Never merge or cherry-pick
  `origin/vuejs3` (a stale 2024 WIP); consult it only as reference.
  `origin/vue-3` is misleadingly named and is NOT a Vue 3 branch.
- Vuetify 3's labs VCalendar is ruled out (broken slots/click events,
  no imperative API). The calendar is rebuilt on **vue-cal v5**
  (MIT, no paid tier), wrapped in a project-owned
  `BookingCalendar.vue` + `useCalendar()` composable so the library
  stays swappable. FullCalendar (MIT plugins only) is the documented
  fallback if vue-cal cannot deliver a parity feature.
- Keep `<script setup lang="ts">` everywhere; no Options API.
- Follow the milestone order in `docs/vue3-migration.md` (toolchain →
  bootstrap → mechanical component port → calendar rebuild → tests →
  parity check), keeping the app bootable and `npm run type-check` +
  `npm run test:unit -- --run` green at every milestone.

Environment notes:

- Use the root Taskfile: `task setup`, `task db:up`, `task dev`,
  `task test:frontend`, `task typecheck:frontend`. Ports and OIDC
  settings come from a gitignored root `.env` (see `.env.sample`);
  this is a shared host, so check the port-collision notes in
  AGENTS.md.
- Seed demo bookings with `python3 dev-utilities/seed-calendar-demo.py`
  after the dev-auth user workaround described in
  `docs/vue3-migration.md` ("Parity verification recipe"), and log in
  to the browser via the local Keycloak recipe in the same section.
- Commit with Conventional Commits, atomic, inside the submodule;
  disable GPG signing per commit (`git -c commit.gpgsign=false ...`)
  and identify yourself as an AI agent in the author field.

Deliverable: the `vue3-migration` branch in `frontend/` with the app
fully on Vue 3 + Vuetify 3, green type-check and unit tests, and a set
of screenshots (same three calendar states as the reference set) added
under `docs/screenshots/vue3-calendar/` in the umbrella repo proving
visual parity. List any deliberate visual deviations explicitly.

---
