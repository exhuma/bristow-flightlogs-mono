# Behavioural split: incremental plan for the remaining frontend

Status: **in progress** (last reconciled 2026-08-06). Originally
written 2026-08-03 as the work package that follows the human
validation of the Vue 3 migration. Since then, other work landed
ahead of this plan and drifted from it — this doc was reconciled
against the actual tree on 2026-08-06 rather than rewritten from
scratch, so the per-WP sections below note what's actually done.

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
  (1046 lines). Quality gate on save; three sign-off flows;
  defect-dialog hand-off. Grade: **high**. (Correction from the
  original survey: there is no debounce anywhere in this file.
  `scheduleSave()` only flips a dirty flag that gates the save FAB;
  saving itself is a manual button click, not a timed autosave.)
- **Defect reports** —
  `views/defect-reports/DefectReportManagementView.vue` (632),
  `DefectReportView.vue` (278), `parts/FullDisplay.vue` (361). Status
  transitions; **unguarded delete**; save; watch toggle; attachment
  flows. Grade: **high**. **Partially done** (commit `69ee3fe`,
  2026-08-06): `core/defectReport/` exists with tests; the
  management view's delete is now guarded and its status change goes
  through the core (permission-gated only — transition *legality*
  beyond permission is still not encoded). Still fused:
  `DefectReportView.vue` (untouched), `FullDisplay.vue`'s
  `updateStatus`/`deleteComment`, and `CommentBlock.vue`'s mislabelled
  `ConfirmedButton`.
- **Import/export** — ~~`views/xcom/ImportExport.vue` (304)~~
  **removed.** The whole feature (view, bridge, table components,
  route, permission) was deleted in commit `db5404b` (2026-08-03,
  "feat!: remove the import/export (xcom) feature") — the backend
  dropped xcom and the client confirmed the feature was obsolete.
  Nothing is left to split; WP3 below is struck.
- **Policy editor** — `views/policy/PolicyEditorView.vue` (490).
  Template-overwrite guard (via `ConfirmedButton`); save/test/format.
  Grade: **medium**. Untouched.
- **Resource CRUD** — the six `resource-management/*Table.vue` this
  survey originally counted (course, customer, instructor, kiosk,
  policy, simulator) plus `KioskManagementView.vue`, `NavBar.vue`'s
  logout, `CommentBlock.vue`'s delete-comment, and
  `PolicyEditorView.vue`'s load-template guard: **9** current
  `ConfirmedButton` consumers, not 8. There is also a **10th,
  previously unnoticed fused-delete pattern**: `UserTable.vue` has its
  own hand-rolled `v-dialog` + `dialogDelete`/`deleteItem` flow that
  doesn't go through `ConfirmedButton` at all — add it to WP5's
  consumer list when that WP is picked up. Grade: **low each, high in
  aggregate**. Untouched.
- **Small confirmations** — `NavBar.vue` (logout), `CommentBlock.vue`
  (delete comment). One guarded decision each, fused via
  `ConfirmedButton`. Grade: **low**. Untouched.

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

**Done** (2026-08-06). What actually happened, vs. the original plan:

1. **Evicted delivery code that sat inside `src/core/`:**
   - `core/downloads.ts` → `src/adapters/downloads.ts`, as planned.
   - `core/graphing.ts` → `src/components/charts/graphing.ts`, as
     planned.
   - `core/versionChecker.ts` had **zero importers anywhere in the
     tree** (dead code) — it was deleted instead of relocated, rather
     than moving unreachable code into the new `src/adapters/`
     directory.
2. **Added the ESLint fence** scoped to `src/core/**/*.ts`, via an
   `overrides` block in `.eslintrc.cjs` (the config is legacy
   `.eslintrc`, not flat config). Uses
   `@typescript-eslint/no-restricted-imports` rather than the base
   `no-restricted-imports`, because it supports `allowTypeImports` —
   needed for `core/permissions.ts`'s type-only
   `import type { Permission } from "@/auth/permissions"`, the one
   sanctioned exception below. Bans value imports of `vue`,
   `vuetify*`, `vue-router`, `@/components/*`, `@/views/*`,
   `@/composables/*`, `@/bridge*`, `@/auth/*`. Fixing this up also
   caught `core/session/ports.ts` importing `Permission` value-style
   instead of `import type` — a one-line fix.
3. **Composition-root convention** (documented here, since
   `docs/vue3-migration.md` referenced by the original plan does not
   exist, and `main.ts`'s own "composition root" comment refers to
   app bootstrap, a different sense of the term):

   > A view that pairs with a `src/core/<domain>/` module constructs
   > the concrete port implementations it needs — a `<Domain>Store`
   > wrapping the relevant bridge calls, `useConfirmDialog()`'s
   > `Dialogue` — and passes them into the core's functions. This is
   > the *only* place core and delivery are allowed to meet.
   > `BookingManagementView.vue` and `App.vue` (for `SessionGateway`)
   > are the reference shape. Core modules never construct or import
   > their own port implementations; ports are always injected by the
   > caller.
4. Session core test gap closed: `src/core/booking/` and
   `src/core/defectReport/` already had specs under `tests/core/`;
   `src/core/session/` did not. Added
   `tests/core/session/session.spec.ts` (fake `SessionGateway` /
   `Dialogue`, mirroring `tests/core/booking/booking.spec.ts`'s
   template) covering `logIn`, `logOut`, `pairKiosk`.

Size: S, as estimated. Pure refactor + config; gate stayed green.

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

**Partially done** (commit `69ee3fe`, 2026-08-06). Remaining tail:

- ~~**Delete is currently unguarded**~~ **Fixed.** `deleteReport` now
  asks `"delete-defect-report"` before removing, wired into
  `DefectReportManagementView`.
- **Status transitions** (`updateStatus`): `changeStatus` exists in
  the core and is used by `DefectReportManagementView`, but only
  enforces the `edit-defect-report` permission — *which* transitions
  are legal, and what closing a report requires, is still not
  encoded anywhere. `FullDisplay.vue`'s own `updateStatus` (still
  fused, still directly mutating and emitting) doesn't go through it
  at all.
- `DefectReportView.vue` (the standalone side-by-side route, distinct
  from the management view) was **not touched** by the partial
  migration — `saveComment`/`onSaveRequested` still call bridges
  directly.
- The comment-delete intent fused in `CommentBlock`'s `ConfirmedButton`
  (the one carrying the mislabelled `data-intent="delete-booking"`)
  is still unmigrated.
- Attachment upload/download stays adapter-side except the decision
  parts (permission, overwrite/limit rules if any) — unchanged from
  the original plan.

Remaining size: S–M. Touches `DefectReportView`, `FullDisplay`,
`CommentBlock`.

## WP3 — import/export core — REMOVED, feature deleted

~~A genuine multi-step sequence with observable intermediate state:
drop file → accept/reject type → build preview → user reviews →
commit → report.~~ Moot: the entire import/export (xcom) feature —
view, bridge, table components, route, permission — was deleted in
commit `db5404b` (2026-08-03). Nothing left to split. Kept here,
struck, so this WP number isn't silently reused for something
unrelated.

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
pattern warns against. Instead, one small core function replaces the
copy-pasted fused flows:

- `core/resources.ts`: `deleteEntity(label, {store, dialogue,
  permissions})` asking a parameterised `"delete-entity"` question.
- Consumers: the six `ConfirmedButton`-based `*Table.vue` components
  (course, customer, instructor, kiosk, policy, simulator),
  `KioskManagementView`, `PolicyEditorView`'s load-template button
  (see WP4 — same underlying `ConfirmedButton`, different question),
  `NavBar`'s logout confirm (which instead extends the session core:
  `logOut(gateway, dialogue)` asking `"confirm-logout"`), and
  `CommentBlock`'s mislabelled delete-comment button (see WP2). Also
  add `UserTable.vue`'s separate hand-rolled delete dialog, found
  during the 2026-08-06 reconciliation — it doesn't use
  `ConfirmedButton` at all but is the same copy-pasted pattern.
- End state: **`ConfirmedButton.vue` has no consumers and is
  deleted**, together with its stray `data-intent` attributes. Its
  dialog look already lives on in `ConfirmDialog.vue`.

Size: M (mechanical, wide).

## Sequencing and increment rules

Original order: **0 → 1 → WP1 → WP2 → WP3 → WP4 → WP5.** Revised
2026-08-06 now that WP3 is moot and WP2 is partly done ahead of
schedule: **0 → 1 → WP1 → WP2 tail → WP4 → WP5.** Value order, and
each step leaves the app bootable and the gate green (`task check`:
vitest, vue-tsc, lint, backend tests untouched).

- One work package per branch/PR off `develop`, following the repo's
  atomic-commit and Conventional-Commits rules.
- A WP that changes observable behaviour (the WP2 delete guard, the
  WP1 sign-off bypass) must say so in its PR description and gets a
  decision from the maintainer before merge.
- No new dependencies; no new state stores. Ports stay narrow — if an
  adapter needs the port to grow a delivery-specific parameter, the
  boundary is misplaced; move it instead.
- Update this doc's status as packages land (`docs/vue3-migration.md`,
  referenced by the original plan, does not exist).

## Rough sizing

| Step | Size | Risk | Status |
| --- | --- | --- | --- |
| 0 enforcement + core hygiene | S | none (mechanical) | done |
| 1 vocabulary rules | — | folded into each WP | ongoing |
| WP1 techlog | L | sign-off bypass decision | in progress |
| WP2 defect reports | M–L | delete becomes guarded | partial |
| ~~WP3 import/export~~ | ~~M~~ | ~~low~~ | removed (feature deleted) |
| WP4 policy editor | S–M | low | not started |
| WP5 shared delete + cleanup | M | wide but mechanical | not started |
