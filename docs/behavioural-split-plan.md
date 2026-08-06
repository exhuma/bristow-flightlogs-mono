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
  flows. Grade: **high**. **Done** (commits `69ee3fe` and
  2026-08-06's WP2-tail commit): `core/defectReport/` covers
  select/draft/save/`changeStatus`/`deleteReport`/`deleteComment` with
  tests, and both views + `FullDisplay.vue` + `CommentBlock.vue` route
  through it. The watch toggle stays fused deliberately (see WP2
  below) — it was never a guarded decision.
- **Import/export** — ~~`views/xcom/ImportExport.vue` (304)~~
  **removed.** The whole feature (view, bridge, table components,
  route, permission) was deleted in commit `db5404b` (2026-08-03,
  "feat!: remove the import/export (xcom) feature") — the backend
  dropped xcom and the client confirmed the feature was obsolete.
  Nothing is left to split; WP3 below is struck.
- **Policy editor** — `views/policy/PolicyEditorView.vue` (490).
  Template-overwrite guard (via `ConfirmedButton`); save/test/format.
  Grade: **medium**. **Done** — see WP4.
- **Resource CRUD** — the six `resource-management/*Table.vue` this
  survey originally counted (course, customer, instructor, kiosk,
  policy, simulator; `KioskTable.vue`'s confirm pairs with the bridge
  call living in `KioskManagementView.vue`), plus `NavBar.vue`'s
  logout: **7** current `ConfirmedButton` consumers (was 9 before WP2
  migrated `CommentBlock.vue` and WP4 migrated
  `PolicyEditorView.vue`'s load-template guard off it). There is also
  a previously unnoticed fused-delete pattern that never used
  `ConfirmedButton` at all: `UserTable.vue` has its own hand-rolled
  `v-dialog` + `dialogDelete`/`deleteItem` flow — add it to WP5's
  consumer list when that WP is picked up. Grade: **low each, high in
  aggregate**. Untouched (WP5).
- **Small confirmations** — `NavBar.vue` (logout). One guarded
  decision, fused via `ConfirmedButton`. Grade: **low**. Untouched.
  (`CommentBlock.vue`'s delete-comment was the other one in this
  category; WP2 migrated it — see below.)

Evidence that the fused pattern was copy-pasted rather than designed:
both the policy editor's *load template* button and CommentBlock's
*delete comment* button carried `data-intent="delete-booking"` — a
pasted attribute naming an unrelated intent. WP2 and WP4 dropped both
along with the `ConfirmedButton` usage that carried them.

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
- Defect-report watch/unwatch (`DefectReportBridge.setWatch`): a bare
  toggle with no permission classification or confirmation to guard.

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

**Done** (2026-08-06). The largest remaining chokepoint.
`TechLogDetailsView.vue` fused:

- **The quality rule, twice.** "Quality ≤ 3 requires discrepancy
  notes" lived once as a form validator (`maybeRequireNotes`) and
  again as a save guard in `saveTechLog()` — knowledge duplication
  with slightly different thresholds (`> 20 chars` vs `non-empty`).
  **Resolved**: `qualityRule()` in the core is the single source of
  truth, unified on the stricter `> 20 chars` threshold; both the
  validator and the save guard now call it.
- **Three sign-off intents** (discrepancy, instructor, technician).
  `discrepancySignOff()` saved through its own path and **bypassed
  the quality gate** that `saveTechLog()` enforced — a latent bug.
  **Resolved, deliberately (maintainer decision, not silently
  preserved)**: all three now go through one `signOff(kind, context)`
  sequence, gated identically. Verified live: a discrepancy sign-off
  attempt at quality ≤ 3 with empty notes is now blocked with the
  same warning the manual save shows, and a valid sign-off after
  adding notes succeeds.
- A second bug surfaced *by* the fix, and fixed alongside it:
  `signOff()` originally applied the toggle to the local `Techlog`
  object before checking the gate, so a rejected sign-off still left
  the UI showing "Undo Sign-Off" with nothing to revert it. The gate
  check now runs first, before any mutation.
- **The autosave sequence.** Correction to this plan's original
  description: there was no debounce anywhere in this file —
  `scheduleSave()` only flipped a dirty flag ahead of a manual
  save-button click. That flag (`saveNeeded`/`saveInProgress`) stayed
  in the adapter as pure UI feedback state; only the save/sign-off
  *decision* sequences moved into the core.

Deliverables: `core/techlog/ports.ts` (`TechlogStore`, `SaveOutcome`,
`SignOffKind`), `techlog.ts` (`saveTechlog`, `signOff`, `qualityRule`),
`tests/core/techlog/techlog.spec.ts` (14 specs), and the view rewired
as adapter. The view kept its layout; only handlers changed.

Size: L, as estimated. Highest payoff — the sign-off/quality
behaviour is now testable without mounting a 1000-line view.

## WP2 — defect-report core (`src/core/defectReport/`)

**Done.** Landed in two passes: commit `69ee3fe` (2026-08-06)
migrated `DefectReportManagementView.vue`; a same-day follow-up
finished the rest.

- ~~**Delete is currently unguarded**~~ **Fixed.** `deleteReport` now
  asks `"delete-defect-report"` before removing, wired into
  `DefectReportManagementView`.
- **Status transitions** (`updateStatus`/`toggleDeferred`):
  `changeStatus` in the core enforces the `edit-defect-report`
  permission and is now used by every status-changing button in both
  views. *Which* transitions are legal beyond that permission check
  is still not encoded — checked, and there is no backend Lua policy
  for defect reports the way `TechLog.lua` governs techlog fields
  (`backend/.../rules/bundled_scripts/validation/` has no
  `DefectReport.lua`), so there is no concrete rule to mirror
  client-side. This stays permission-only until a specific transition
  rule is actually specified; inventing one would be speculation the
  repo's own conventions warn against.
- `FullDisplay.vue`'s `updateStatus`/`toggleDeferred` no longer build
  a mutated copy and emit a generic `save-requested` themselves —
  they emit a `status-change-requested` event naming the target
  status, and the owning view (`DefectReportView.vue`, the only place
  that renders these buttons live — `DefectReportManagementView`'s
  embedded `FullDisplay` is read-only) calls `changeStatus` from the
  core in response. `FullDisplay.vue` is presentation-only now: it
  computes which status a toggle should move to (matching the
  convention `DefectReportManagementView.vue`'s own `toggleDeferred`
  already used) but the actual decision to persist is the core's.
- `DefectReportView.vue` (the standalone side-by-side route) is fully
  rewired: `onSaveRequested` now calls `saveReport`, a new
  `onStatusChangeRequested` calls `changeStatus`, and comment deletion
  calls the core's new `deleteComment`. It gained its own
  `ConfirmDialog` + `useConfirmDialog` composition root — the first
  one this view has had.
- **`core/defectReport/defectReport.ts` gained `deleteComment`**, a
  new decision: checks the comment's ownership (only its author may
  delete it — previously enforced only by hiding the button, so a
  request built by other means would have gone through), the
  `edit-defect-report` permission, and confirms via a newly added
  `"delete-defect-report-comment"` question (not the borrowed
  `"delete-booking"` `CommentBlock.vue` used to carry).
  `CommentBlock.vue` dropped its `ConfirmedButton` in favour of a
  plain button that emits `delete-requested`; the confirm dialog and
  the core call now live at `DefectReportView.vue`'s composition
  root, matching every other guarded delete in the app.
- **Watch/unwatch was surveyed and deliberately left fused.**
  `DefectReportBridge.setWatch` has no permission classification and
  no confirmation — it is a bare toggle with nothing for a core
  function to guard, decide or sequence. Extracting a pass-through
  wrapper would be exactly the speculative generality the "when not
  to apply this" guidance warns against. Revisit only if watching
  ever grows a real guard.
- Attachment upload/download stays adapter-side except the decision
  parts (permission, overwrite/limit rules if any) — unchanged from
  the original plan; no guard was found to extract there either.

Deliverables added on top of the first pass:
`core/defectReport/ports.ts` (`CommentStore`, `DeleteCommentOutcome`),
`deleteComment` in `defectReport.ts`, 6 new specs in
`tests/core/defectReport/defectReport.spec.ts` (24 total), and
`"delete-defect-report-comment"` in `core/dialogue.ts`'s `QuestionId`.

Size: S–M, as estimated for the remaining tail.

## WP3 — import/export core — REMOVED, feature deleted

~~A genuine multi-step sequence with observable intermediate state:
drop file → accept/reject type → build preview → user reviews →
commit → report.~~ Moot: the entire import/export (xcom) feature —
view, bridge, table components, route, permission — was deleted in
commit `db5404b` (2026-08-03). Nothing left to split. Kept here,
struck, so this WP number isn't silently reused for something
unrelated.

## WP4 — policy editor core (`src/core/policy/`)

**Done.**

- The **load-template guard** ("replace the script, changes lost")
  moved from `ConfirmedButton` markup into a core decision
  (`loadTemplate`) asking a correctly named
  `"overwrite-policy-script"` question, only when the buffer is
  actually dirty — the old `ConfirmedButton` asked unconditionally.
  Verified live: loading the template on a clean buffer skips the
  dialog entirely; dirtying the buffer first makes it appear with the
  same wording the button used to carry.
- `savePolicy` / `runTest` / `autoFormat` all got named outcomes in
  `core/policy/policy.ts`. `runTest` folds a failed request into the
  same `ExecutionResult` shape a script's own errors use, so the
  adapter has one rendering path for both — matching the pre-split
  handler's fallback exactly. The Ctrl-S key handling and the Monaco
  buffer/dirty-flag state stayed in the adapter.
- **`savePolicy` gained a permission check that did not exist
  before.** The route to this view only requires `view-policies` (not
  `edit-policies`), and the pre-split `save()` had no client-side
  gate at all -- anyone who could open the editor could attempt a
  save and get a raw, unclassified backend 403. `savePolicy` now
  checks `edit-policies` before ever calling the store, and the Save
  button in the template is disabled for the same reason. A
  behaviour change worth a maintainer's attention, if a narrower
  read-with-attempt affordance was ever intentional.
- **Fixed a version-staleness bug found while extracting `save`:**
  `PolicyBridge.save()` posted the policy but discarded the response
  body -- unlike every sibling bridge (`techlogs.ts`, `defectReport.ts`,
  `bookings.ts`), it never passed `Policy` as the `post()` helper's
  `localType`. The server-assigned `version` never made it back into
  the editing session, so a *second* save in the same visit would
  submit a stale version. `savePolicy` now syncs `policy.value` from
  the store's response on success, the same way `saveBooking` and
  `saveReport` already do. Verified live: two saves in one session
  now both return `200`, versions incrementing `1 → 2 → 3`; before
  the fix the second would have raced against a version the backend
  had already moved past.
- **Fixed a second, smaller gap alongside `autoFormat`:** the
  original handler had no `.catch()` at all -- a failed format
  request vanished as an unhandled promise rejection. `autoFormat`
  now returns a named `{status: "failed", error}` outcome the adapter
  surfaces through `errorCaught`.

Deliverables: `core/policy/ports.ts` (`PolicyStore`, `SaveOutcome`,
`LoadTemplateOutcome`, `FormatOutcome`), `policy.ts` (`savePolicy`,
`loadTemplate`, `runTest`, `autoFormat`), 12 specs in
`tests/core/policy/policy.spec.ts`, the `"overwrite-policy-script"`
`QuestionId`, and the `PolicyBridge.save()` fix.

Size: S–M, as estimated.

## WP5 — one shared delete flow for resource CRUD

Not a full split per resource — that would be the over-application the
pattern warns against. Instead, one small core function replaces the
copy-pasted fused flows:

- `core/resources.ts`: `deleteEntity(label, {store, dialogue,
  permissions})` asking a parameterised `"delete-entity"` question.
- Consumers: the six `ConfirmedButton`-based `*Table.vue` components
  (course, customer, instructor, kiosk, policy, simulator; `kiosk`'s
  confirm lives in `KioskTable.vue`, but the actual bridge call is a
  separate handler in `KioskManagementView.vue`, so both files need
  touching), and `NavBar`'s logout confirm (which instead extends the
  session core: `logOut(gateway, dialogue)` asking
  `"confirm-logout"`) — **7** `ConfirmedButton` consumers total.
  (`CommentBlock`'s mislabelled delete-comment button and
  `PolicyEditorView`'s load-template button were the same pattern but
  WP2 and WP4 migrated them already, each straight to its own
  `ConfirmDialog` + core decision rather than through this shared
  `deleteEntity` — two fewer consumers for WP5 to touch.) Also add
  `UserTable.vue`'s separate hand-rolled delete dialog, found during
  the 2026-08-06 reconciliation — it doesn't use `ConfirmedButton` at
  all but is the same copy-pasted pattern.
- End state: **`ConfirmedButton.vue` has no consumers and is
  deleted**, together with its stray `data-intent` attributes. Its
  dialog look already lives on in `ConfirmDialog.vue`.

Size: M (mechanical, wide).

## Sequencing and increment rules

Original order: **0 → 1 → WP1 → WP2 → WP3 → WP4 → WP5.** Revised
2026-08-06: WP3 is moot (feature deleted), and 0/1/WP1/WP2/WP4 have
all landed: **0 → 1 → WP1 → WP2 → WP4 → WP5.** Next up, and last:
WP5 (shared delete flow). Value order, and each step leaves the app
bootable and the gate green (`task check`: vitest, vue-tsc, lint,
backend tests untouched).

- One work package per branch/PR off `develop`, following the repo's
  atomic-commit and Conventional-Commits rules.
- A WP that changes observable behaviour (the WP2 delete guard, the
  WP1 sign-off bypass, WP4's new save permission check and version
  sync-back) must say so in its PR description and gets a decision
  from the maintainer before merge.
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
| WP1 techlog | L | sign-off bypass decision | done |
| WP2 defect reports | M–L | delete becomes guarded | done |
| ~~WP3 import/export~~ | ~~M~~ | ~~low~~ | removed (feature deleted) |
| WP4 policy editor | S–M | low | done |
| WP5 shared delete + cleanup | M | wide but mechanical | not started |
