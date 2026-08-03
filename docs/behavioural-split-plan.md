# Behavioural split: incremental plan for the remaining frontend

Status: **planned, not started** (2026-08-03). This is the work package
that follows the human validation of the Vue 3 migration. No code has
been changed for it yet.

## What "the split" means here

Two reference implementations already exist in the frontend; every step
below repeats their shape rather than inventing a new one:

- `src/core/session/` + the adapter half of `App.vue`
  (commit `10fce7c`): logging in, logging out and kiosk pairing as
  plain functions over injected `SessionGateway` and `Dialogue` ports.
- `src/core/booking/` + `BookingManagementView.vue` and its parts
  (commit `8b5025d`): select/start/save/delete decisions in the core,
  wording and widgets in the view.

The contract, restated:

- **The core owns the what**: intents, guarded decisions, and the
  sequence of steps. It imports domain models and other core modules —
  never Vue, Vuetify, the router, components, views, or the bridge.
- **Ports are injected**, not imported: `PermissionSet`, a per-domain
  store port (the `BookingStore` shape), and `Dialogue`.
- **No user-facing strings in the core.** The core names a question
  (`"delete-booking"`); the adapter phrases it.
- **Adapters phrase and render**: views/components implement the ports,
  translate outcomes into snackbars, dialogs and navigation.
- Core functions return **named outcome objects**
  (`{ status: "saved" | "rejected", reason: … }`), never throw for
  expected refusals, and are tested with fake ports and no mounting.

## Survey: where the split is still missing

Graded by decision density — how many guarded, sequenced or
state-changing decisions the file currently fuses with presentation.

- **Techlog editing** — `views/techlog/TechLogDetailsView.vue`
  (1046 lines). Quality gate on save; three sign-off flows; debounced
  autosave; defect-dialog hand-off. Grade: **high**.
- **Defect reports** —
  `views/defect-reports/DefectReportManagementView.vue` (632),
  `DefectReportView.vue` (278), `parts/FullDisplay.vue` (361). Status
  transitions; **unguarded delete**; save; watch toggle; attachment
  flows. Grade: **high**.
- **Import/export** — `views/xcom/ImportExport.vue` (304). Drop →
  validate → preview → commit sequence; `alert()` literal in a
  handler. Grade: **medium**.
- **Policy editor** — `views/policy/PolicyEditorView.vue` (490).
  Template-overwrite guard (via `ConfirmedButton`); save/test/format.
  Grade: **medium**.
- **Resource CRUD** — six `resource-management/*Table.vue` plus their
  views, and `KioskManagementView.vue`. The same delete-with-confirm,
  copy-pasted; the confirm lives in the table and the bridge call in
  the view, so no unit owns the sequence. Grade: **low each, high in
  aggregate**.
- **Small confirmations** — `NavBar.vue` (logout), `CommentBlock.vue`
  (delete comment). One guarded decision each, fused via
  `ConfirmedButton`. Grade: **low**.

Evidence that the fused pattern is copy-pasted rather than designed:
both the policy editor's *load template* button and CommentBlock's
*delete comment* button carry `data-intent="delete-booking"` — a
pasted attribute naming an unrelated intent.

### Deliberately left fused

Per the guidance that thin CRUD and read-only surfaces have almost no
*what* to separate, these stay as they are; extracting ports for them
would be speculative generality:

- Read-only dashboards: `KpiView`, `SimulatorReportView`,
  `CustomerReportView`, `ChangeLog`.
- Pick-and-navigate lists: `TechlogListView`, `BookingListView`,
  `BookingSelectionView`.
- `UserSettings` (toggle-and-persist), `AnyResource` scaffolding
  beyond the shared delete flow of WP5.

If one of these later grows a guarded decision, it gets its port then —
not before.

## Step 0 — make the boundary mechanical (prerequisite)

Do this first so every later step is checked by the build rather than
by review discipline.

1. **Evict delivery code that already sits inside `src/core/`**, or the
   lint rule below can never be enabled:
   - `core/downloads.ts` — DOM (`document.createElement`) and HTTP
     (`authedFetch`). Move to `src/adapters/downloads.ts` (new
     directory for delivery helpers that are not components).
   - `core/versionChecker.ts` — `window.setInterval` + `fetch`. Same
     destination.
   - `core/graphing.ts` — imports echarts types. Move next to the
     chart components (`src/components/charts/graphing.ts`).
   Update importers; no behaviour change.
2. **Add the ESLint fence** scoped to `src/core/**`:
   `no-restricted-imports` banning `vue`, `vuetify*`, `vue-router`,
   `@/components/*`, `@/views/*`, `@/composables/*`, `@/bridge*`,
   `@/auth/*` (ports only — the session core already talks to auth
   through `SessionGateway`). CI fails on violation.
3. **Document the composition-root convention**: views construct the
   port implementations (as `BookingManagementView` does today) and are
   the only place core and delivery meet.

Size: S. Pure refactor + config; gate stays green.

## Step 1 — shared vocabulary rules (applies to every WP)

- New questions extend `QuestionId` in `core/dialogue.ts`; the existing
  `useConfirmDialog` phrasebook pattern supplies wording per view. No
  new dialog components unless a question genuinely needs a new shape.
- Store ports follow the `BookingStore` convention: narrow, per-domain,
  returning `{ authenticated, authorized }` style facts, implemented
  inline in the consuming view over the bridge.
- Outcomes are discriminated unions; adapters `switch` on `status`.
- Every core function gets a spec under `tests/core/<domain>/` driven
  by fake ports (the doubles in `tests/core/booking/booking.spec.ts`
  are the template). The fakes are the second port implementation that
  keeps the interface honest.

## WP1 — techlog core (`src/core/techlog/`)

The largest remaining chokepoint. `TechLogDetailsView.vue` fuses:

- **The quality rule, twice.** "Quality ≤ 3 requires discrepancy
  notes" lives once as a form validator (`maybeRequireNotes`) and
  again as a save guard in `saveTechLog()` — knowledge duplication
  with slightly different thresholds (`> 20 chars` vs `non-empty`).
  The core states it once; both the validator and the save guard call
  it.
- **Three sign-off intents** (discrepancy, instructor, technician).
  `discrepancySignOff()` saves through its own path and **bypasses the
  quality gate** that `saveTechLog()` enforces — almost certainly a
  latent bug. The core gives all three the same
  `signOff(kind, context)` sequence; whether the bypass was intended
  is a question to settle during review, not silently preserved or
  silently fixed.
- **The autosave sequence** (`scheduleSave` → debounce → save →
  sync-back). Becomes an explicit core decision ("is there anything to
  save, is it allowed, what happened"), with the debounce timer
  staying in the adapter (timing is delivery).

Deliverables: `core/techlog/ports.ts` (`TechlogStore`), `techlog.ts`
(`saveTechlog`, `signOff`, `qualityRule`), specs, and the view rewired
as adapter. The view keeps its layout; only handlers change.

Size: L. Highest payoff — the sign-off/quality behaviour becomes
testable without mounting a 1000-line view.

## WP2 — defect-report core (`src/core/defectReport/`)

- **Delete is currently unguarded**: `onDeleteRequested` calls the
  bridge directly — no confirmation anywhere in the chain, unlike every
  resource table. The core models `deleteReport` with a
  `"delete-defect-report"` question; the adapter phrases it. (This is
  a deliberate behaviour change — flag it in the PR.)
- **Status transitions** (`updateStatus`): which transitions are legal,
  and what closing a report requires, become a core decision instead
  of whatever the button row allows.
- **Save + validity**, **watch/unwatch**, and the comment-delete
  intent currently fused in `CommentBlock`'s `ConfirmedButton` (the
  mislabelled one) all route through the same core.
- Attachment upload/download stays adapter-side except the decision
  parts (permission, overwrite/limit rules if any).

Size: M–L. Touches `DefectReportManagementView`, `DefectReportView`,
`FullDisplay`, `CommentBlock`.

## WP3 — import/export core (`src/core/importing/`)

A genuine multi-step sequence with observable intermediate state:
drop file → accept/reject type → build preview → user reviews →
commit → report. Today the type rejection is a bare
`alert("Please drop an Excel file.")` — a user-facing string in a
handler.

- Core: `startImport(file, ports)` returning
  `{ status: "rejected", reason: "not-an-excel-file" }` or a preview
  handle; `commitBookings` / `commitTechlogs` with named outcomes.
- Adapter: the view phrases the rejection (inline `v-alert`, not
  `window.alert`) and renders the preview tables.

Size: M.

## WP4 — policy editor core (`src/core/policy/`)

- The **load-template guard** ("replace the script, changes lost")
  moves from `ConfirmedButton` markup into a core decision with a
  correctly named question (`"overwrite-policy-script"`), asked only
  when the buffer is actually dirty — today it asks unconditionally.
- `save` / `runTest` / `autoFormat` sequences get named outcomes; the
  Ctrl-S key handling stays in the adapter.

Size: S–M.

## WP5 — one shared delete flow for resource CRUD

Not a full split per resource — that would be the over-application the
pattern warns against. Instead, one small core function replaces six
copy-pasted fused flows:

- `core/resources.ts`: `deleteEntity(label, {store, dialogue,
  permissions})` asking a parameterised `"delete-entity"` question.
- Consumers: the six `*Table.vue` components (course, customer,
  instructor, kiosk, policy, simulator), `KioskManagementView`, and
  `NavBar`'s logout confirm (which instead extends the session core:
  `logOut(gateway, dialogue)` asking `"confirm-logout"`).
- End state: **`ConfirmedButton.vue` has no consumers and is
  deleted**, together with its stray `data-intent` attributes. Its
  dialog look already lives on in `ConfirmDialog.vue`.

Size: M (mechanical, wide).

## Sequencing and increment rules

Order: **0 → 1 → WP1 → WP2 → WP3 → WP4 → WP5.** Value order, and each
step leaves the app bootable and the gate green (`task check`: vitest,
vue-tsc, lint, backend tests untouched).

- One work package per branch/PR off `vue3-migration` (or its merge
  target once the migration lands), following the repo's atomic-commit
  and Conventional-Commits rules.
- A WP that changes observable behaviour (the WP2 delete guard, the
  WP1 sign-off bypass) must say so in its PR description and gets a
  decision from the maintainer before merge.
- No new dependencies; no new state stores. Ports stay narrow — if an
  adapter needs the port to grow a delivery-specific parameter, the
  boundary is misplaced; move it instead.
- Update `docs/vue3-migration.md`'s status section (or successor doc)
  as packages land.

## Rough sizing

| Step | Size | Risk |
| --- | --- | --- |
| 0 enforcement + core hygiene | S | none (mechanical) |
| 1 vocabulary rules | — | folded into each WP |
| WP1 techlog | L | sign-off bypass decision |
| WP2 defect reports | M–L | delete becomes guarded |
| WP3 import/export | M | low |
| WP4 policy editor | S–M | low |
| WP5 shared delete + cleanup | M | wide but mechanical |
