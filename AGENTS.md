# AGENTS.md

Instructions for AI agents working in this repository.

## What this repository is

`flightlogs-mono` is an umbrella project that combines two existing,
legacy repositories as git submodules so that agents can reason about
both halves of the application at once:

- `backend/` — [bristow-flightlogs-backend]
  (FastAPI + PostgreSQL, checked out on `develop`)
- `frontend/` — [bristow-flight-logs-frontend]
  (Vue 3 SPA, checked out on `develop`)

[bristow-flightlogs-backend]: https://github.com/exhuma/bristow-flightlogs-backend
[bristow-flight-logs-frontend]: https://github.com/exhuma/bristow-flight-logs-frontend

The application manages flight-simulator training: booking simulator
sessions for customers, per-session technical logs ("techlogs"), defect
reports with comments and history, plus customers, instructors, courses,
crew, kiosks, users, roles and validation policies.

## Working with the submodules

- Each submodule is a full git repository with its own history, branches
  and remotes. Run `git submodule update --init` after cloning.
- Committing inside a submodule does **not** update this repo; the
  umbrella repo only records a commit pointer per submodule. Never
  commit a submodule pointer bump unless you intend to pin the umbrella
  to that exact commit.
- The backend integration branch is `develop` (its `master` lags).
- `frontend/AGENTS.md` does not exist on disk. Treat **this** file as
  authoritative for cross-cutting guidance for both submodules.

## Finishing a task: commit and push

When a task is done (changes verified — tests/typecheck/lint green,
and a UI change checked in a live browser per the top-level agent
instructions), commit and push all the way up, without waiting to be
asked each time:

1. In each submodule you touched, commit on its `develop` branch and
   `git push origin develop`.
2. Back in the umbrella repo, `git add <submodule>` to bump its
   pointer to the commit just pushed, commit on `master` (the
   umbrella repo only has `master` — there is no umbrella `develop`),
   and `git push origin master`.

This is what lets the user `git pull` the umbrella repo and get a
working tree that already points at the pushed submodule commits, no
extra steps. See "Working with the submodules" above for when a
pointer bump is warranted versus accidental; a task that changed
submodule code always warrants one. Skip a submodule step only if
that submodule had no changes this task.

## Dev environment: the root Taskfile

The canonical entry points live in the root `Taskfile.yaml`
(https://taskfile.dev). This host is **shared** — default ports may be
occupied by other developers' processes — so every port and container
name is configurable via a gitignored root `.env` (see `.env.sample`
for all knobs and their defaults). Serve/database tasks fail early with
a clear message when their port is taken; override the named variable
in `.env` instead of killing other processes.

- `task setup` — init submodules, `uv sync`, `npm clean-install`,
  create `backend/dev-auth.json` from its `.dist` template.
- `task db:up` / `task db:down` — disposable PostgreSQL 16 containers
  for dev and tests.
- `task db:seed` — wipe and repopulate the dev database with
  bookings/techlogs/defect reports covering normal cases plus fixed
  calendar edge cases (DST transitions, a year boundary).
- `task dev` — run backend (uvicorn, auto-reload) and frontend (vite)
  together; `task dev:backend` / `task dev:frontend` individually.
- `task test`, `task test:backend`, `task test:frontend`,
  `task typecheck:frontend`, `task lint:frontend`, `task check`.
- `task image:build` — build the release image locally (no push).
  Reads the product version from the root `VERSION` file.

The Taskfile wires the two halves together in dev by starting the
backend with `dev-auth.json` authentication (HTTP Basic with fake users
such as `admin` or `booking`; any password), so no Keycloak/Entra IdP
is needed. The SPA addresses the backend at `/api`, which in dev is
Vite's `server.proxy` forwarding to `BACKEND_PORT` — in production one
process serves both, so there is nothing to configure either way.

The frontend only *offers* that dev sign-in (the nav-drawer "Login"
dialog) when the Taskfile's `DEV_AUTH` var is true, which it derives
as `empty(FLIGHTLOGS_OIDC_AUTHORITY)` unless overridden — so if the
root `.env` also sets `FLIGHTLOGS_OIDC_AUTHORITY` (e.g. left over from
testing the real IdP flow), plain `task dev` shows OIDC login instead
and fails with connection-refused when no Keycloak is running. Run
`DEV_AUTH=true task dev` to force dev-auth on alongside that OIDC
config.

Per-submodule tasks live in `backend/Taskfile.yml` and
`frontend/Taskfile.yml`, included into the root Taskfile as
`backend:*`/`frontend:*` (`task backend:run`, `task backend:doc`,
`task backend:generate-alembic`, `task backend:seed`, `task
frontend:run-dev-container`); each also works standalone by running
plain `task <name>` from inside that submodule. `uv run pytest` and
`npm run dev | test:unit | type-check | lint` still work directly
too.

## CI

There **is** umbrella-level CI now, reversing an earlier decision
recorded in this file's history: the concern was that it "would need
cross-repo tokens for two private submodules and would pin submodule
SHAs that lag `develop`." Both are true, but for a *release build* a
pinned pair of submodule SHAs is the entire point, not a drawback — the
umbrella is the only repo that knows which pair shipped together, so it
is the only repo that can build the one image correctly. Do not
re-derive the old "no umbrella CI" conclusion from that same reasoning;
it applied to quality gates, not to owning the release.

Each submodule keeps its own `ci.yml`: quality gates only (lint,
type-check, tests), `contents: read` throughout, no image build and no
release pipeline. Neither submodule publishes a container image or
tags its own release any more — see each repo's own CI for exactly
what it still checks.

The umbrella has two workflows:

- `ci.yml` — checks out both submodules (a `SUBMODULE_TOKEN` secret
  authenticates the checkout, since `.gitmodules` uses SSH URLs) and
  runs `task image:build`: the image still builds. This is what
  replaced each submodule's old PR-time "does the Dockerfile still
  build" job, since the Dockerfile lives here now.
- `release.yml` — on a `release-*` tag, builds and pushes **two**
  images (the application, and `flightlogs-ops`, the maintenance-tools
  image — see "Deployment and maintenance operations" below), builds
  and zips the Sphinx manual, generates an SBOM, and creates the GitHub
  release with notes extracted from this repo's own `CHANGELOG.rst`.
  `contents: write` is elevated on the release job alone.

**CI runs the Taskfile's commands, not its own variants**, where a
Taskfile command exists for the job — `task image:build` for the image,
`task check` inside each submodule for its own quality gates. When you
change one, change it in both places or they drift.

Some jobs are deliberately advisory (`continue-on-error: true`) because
their baselines are not yet clean: repo-wide mypy, `alembic check`
drift, `sphinx -W`, bandit, pip-audit, npm audit and Trivy. Each carries
a comment saying so. Promote one to blocking by deleting that line once
its baseline is triaged — do not silence the finding instead.

There is no CodeQL: both submodule repositories are private with code
scanning disabled, so it requires paid GitHub Code Security and would
fail with a 403 rather than report anything.

## Deployment and maintenance operations

Deployment is a normal `docker compose` install against the released
`flightlogs` image -- see the backend manual's "Installation" page for
the operator-facing walkthrough. There is no Ansible any more (removed
when direct SSH access to the deployment host was withdrawn); do not
recreate it.

Recurring maintenance -- database backup, an anonymised dump for use
outside production -- is documented on the manual's "Maintenance
Operations" page as small, dependency-free scripts under
`backend/docs/source/maintenance/data/`. The `flightlogs-ops` image
(built from `ops/Dockerfile`, published alongside the application image)
wraps the two that only need Docker (`backup.bash`,
`anonymise-dump.bash`) behind `task`, purely for convenience: it is not
the only way to run them, and dropping it would not lose any
capability. `upload-to-az.bash` is deliberately excluded -- it needs
the Azure CLI, a dependency neither of the other two shares, and adding
it would mean every user of the image carries that weight. Keep this
image narrow: a script gaining logic that only exists inside the
wrapper, rather than in the script itself, or a new script pulled in
purely because it is convenient rather than because it shares the same
dependencies, both defeat the reason this is a separate, minimal image.

## Backend summary

- FastAPI app factory `create_app()` in
  `backend/src/flightlogs/main.py`; SQLAlchemy 2 + psycopg 3;
  PostgreSQL 16; Alembic migrations; Python 3.12; **uv is the only
  package manager** (`uv run …`, `uv sync`).
- Configuration comes from `pydantic-settings` with the `FLIGHTLOGS_`
  env prefix (`settings.py`). The app itself doesn't read `.env`
  files; the root Taskfile's `dotenv: [".env"]` (and, standalone,
  your shell) is what populates these vars.
- Three model layers, deliberately separate: `model/` (Pydantic API
  schemas), `persistence/model/` (SQLAlchemy ORM), converted by
  `bridge/api2db.py` and `bridge/db2api.py`. A new field usually
  touches all three **plus** an Alembic revision (`task
  backend:generate-alembic LABEL="..."`).
- Most resources are exposed via the generic CRUD router factory in
  `routers/persistent_entity.py`.
- Auth: OIDC/Entra JWT bearer tokens in production, `dev-auth.json`
  HTTP Basic in development, PIN-paired kiosk tokens. Authorization is
  **permission-based, never role-based in code**
  (`current_user.require_permission(...)`).
- Mutable resources use optimistic locking: clients must send back the
  `version` they read.
- Tests: `uv run pytest`; they need a live PostgreSQL. The pytest-env
  DSN pins hostname `test-db` (devcontainer network); the root
  Taskfile overrides it to reach the `task db:up` container.
- Style: black + isort + ruff via pre-commit, RST/Sphinx docstrings,
  cspell. Docs are Sphinx (`task backend:doc`), served at `/api/manual`
  in the image.
- ruff is configured in `pyproject.toml` at 80 columns. Pre-existing
  over-long files are grandfathered in `per-file-ignores` behind a
  `ruff-exemption:` marker — retire a file's entry when you next touch
  it rather than sweeping the repo.
- mypy is lenient globally (baseline ~62 errors, so the CI job is
  advisory) with a strict opt-in allowlist under
  `[[tool.mypy.overrides]]`. That allowlist is green and blocks. Add a
  module to it when you next work on it.
- Releases, versioning and the changelog are **not** owned here any
  more -- see "CI" above. `pyproject.toml`'s own `version` is frozen at
  a placeholder; `Settings.app_version`
  (`FLIGHTLOGS_APP_VERSION`, set by the umbrella's image build) is what
  `FastAPI(version=)` and the Sphinx manual's `release` actually report
  at runtime, falling back to the frozen placeholder for a standalone
  checkout.

## Frontend summary

- **Current state: Vue 3.5 + Vuetify 3.13** with vue-router 4, Vite,
  TypeScript, Vitest 2 with `@vue/test-utils` v2. npm is the only
  package manager.
- UI route: **Vuetify** (Material Design). Recorded here so agents do
  not re-ask; the calendar is **vue-cal v5** (MIT, no paid tier) —
  Vuetify 3's labs `VCalendar` was ruled out as unusable (broken
  slots/click events, no imperative API). It is wrapped in the
  project-owned `src/components/booking/BookingCalendar.vue`, the only
  file that imports the library directly, alongside a `useCalendar()`
  composable owning view/range/navigation state — keep it that way so
  the library stays swappable.
- 98 of 103 SFCs use `<script setup lang="ts">` with typed
  `defineProps`/`defineEmits`. Keep that style; do not add Options API
  components.
- No Pinia/Vuex. Shared state lives in components, `localStorage`
  helpers (`src/core/userSettings.ts`), and a handful of module-level
  singleton composables (`src/composables/useCalendar.ts`,
  `src/composables/useBookingData.ts`).
- Backend access is hand-written `fetch` bridges in `src/bridge/`
  (composed by `AllBridges` in `src/bridge/index.ts`); remote DTOs in
  `src/remoteModel/`, domain classes in `src/model/`. There is no
  OpenAPI codegen — bridges mirror the backend `model/` schemas by
  hand, so API changes need matching edits on both sides.
- The SPA addresses the backend at `/api` on its own origin
  (`API_BASE_URL` in `src/core/config.ts`) and fetches
  `/api/config.json` for OIDC and banner settings. The base is absolute
  (`window.location.origin + "/api"`), not the bare path, because a
  dozen call sites build requests with ``new URL(`${remoteUrl}/…`)``
  and the one-argument `URL` constructor throws without a scheme.
- Tests live in the top-level `frontend/tests/` tree mirroring `src/`.
  The vitest `include` glob also matches `src/**/__tests__/`, so a
  colocated spec is picked up as well.
- `npm run lint` auto-fixes; `npm run lint:check` is the gate CI runs
  and is pinned at `--max-warnings 35`. That number is a ratchet — it
  may only ever go down.

## Backend <-> frontend contract (calendar-relevant)

- One container, one origin. The API lives below `/api`
  (`/api/docs`, `/api/openapi.json`, `/api/manual`, `/api/livez`,
  `/api/readyz`, `/api/healthz`); everything else belongs to the SPA.
  A test in `backend/tests/test_routing.py` asserts no route escapes
  the prefix, because the history-mode fallback's safety depends on it.
  The fallback only answers with `index.html` when the client asks for
  HTML, so a missing sub-resource still 404s.
- The calendar view fetches `GET /api/booking?start=…&end=…&simulator-id=…`
  for the visible range; bookings carry a `time_slot` range, `version`
  (optimistic locking) and either full details or an opaque
  `BookingPublic` ("busy") shape depending on the caller's permissions.
- `Simulator.maintenance_window` is rendered as a hatched overlay on
  the calendar intervals.
- Overlapping bookings are rejected server-side (`OverlapError`), and
  Lua policies may reject writes (`PolicyViolation`).

## Quartermaster

Instruction kits are resolved **per task**, not per project: call
`resolve_kits(task="…")` before editing or planning, and again when the
work changes shape. Hooks in `.claude/settings.json` enforce this. Do
not hard-code kit lists in this file or other docs.

## Incremental code-quality improvement

Both submodules predate agentic coding and carry real legacy debt
(oversized views, oversized modules). Do not run a repo-wide refactor
sweep. Instead, leave whatever you touch a little better than you
found it, scoped strictly to the code the current task already edits:
tighten a name, extract a small pure helper, trim a function or file
that's over the structural limits down toward them, remove dead code
you notice in passing. Do not refactor code the task doesn't otherwise
touch — see the "make minimal, focused changes" rule Quartermaster
loads for this stack.

`module-code-structure-limits`' "adopting on an existing codebase"
guidance is the operating model for legacy-scale files like these:
grandfather violations per file (never by raising a threshold
repo-wide), mark exemptions so they're greppable, and retire a file's
exemption the next time that file is touched for any reason, bringing
just the touched portion under the limit.

For the frontend specifically, `module-interaction-core`'s split
between the *what* (intents, guarded decisions, sequences) and the
*how* (Vue/Vuetify presentation) is worth applying incrementally too —
a small, ported "core" function is something an agent can read and
test without mounting a huge view. The frontend's behavioural split
(tracked to completion in a since-deleted planning doc) landed across
every domain a 2026-08 survey identified: `src/core/session/`,
`src/core/booking/`, `src/core/defectReport/`, `src/core/techlog/`,
`src/core/policy/`, and the shared delete flow in
`src/core/resources.ts` are the reference implementations. Thin CRUD
and read-only views (dashboards, pick-and-navigate lists,
toggle-and-persist settings) were deliberately left fused — extracting
ports for them would be speculative generality. When an edit lands
inside a view that still fuses a guarded, sequenced or state-changing
decision with its presentation, prefer extracting the touched piece
into its own `src/core/<domain>/` the way the shipped examples do,
rather than adding another fused handler. A behavior-changing
extraction (a newly-enforced permission check, a previously-unguarded
action becoming guarded, a fixed bypass) is a maintainer decision, not
something to fold into an unrelated patch — say so explicitly in the
PR/commit.

## Shared conventions

- 80-character line limit everywhere — Python (black/isort), prose
  (hard-wrap markdown/RST), config. Do not raise limits or suppress
  linters to make a check pass.
- Both submodules use pre-commit and cspell (project dictionaries under
  each repo's `cspell/` directory); run them before committing.
- Match ceremony to change size: work packages get a feature branch and
  PR; small self-contained fixes may be committed directly.
- Commit as an identifiable AI author: use
  `--author="$QM_GIT_AUTHOR"` when that variable is set, otherwise use
  the user's identity with a clear agent indicator, keeping the
  standard `Name <email>` format.
