# AGENTS.md

Instructions for AI agents working in this repository.

## What this repository is

`flightlogs-mono` is an umbrella project that combines two existing,
legacy repositories as git submodules so that agents can reason about
both halves of the application at once:

- `backend/` — [bristow-flightlogs-backend]
  (FastAPI + PostgreSQL, checked out on `develop`)
- `frontend/` — [bristow-flight-logs-frontend]
  (Vue SPA, currently checked out on
  `copilot/prepare-for-upgrade-to-vue3`)

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
- `frontend/AGENTS.md` is known-stale: it is truncated and only contains
  an outdated kit list. Treat **this** file as authoritative for
  cross-cutting guidance until it is repaired.

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

The Taskfile wires the two halves together in dev: it generates the
gitignored `frontend/public/config/remote.json` pointing at the local
backend, and starts the backend with `dev-auth.json` authentication
(HTTP Basic with fake users such as `admin` or `booking`; any
password), so no Keycloak/Entra IdP is needed.

Per-submodule tasks live in `backend/Taskfile.yml` and
`frontend/Taskfile.yml`, included into the root Taskfile as
`backend:*`/`frontend:*` (`task backend:run`, `task backend:doc`,
`task backend:generate-alembic`, `task backend:seed`, `task
frontend:run-dev-container`); each also works standalone by running
plain `task <name>` from inside that submodule. `uv run pytest` and
`npm run dev | test:unit | type-check | lint` still work directly
too.

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
  cspell. Docs are Sphinx (`task backend:doc`), served at `/manual` in
  the image.
- Releases: CalVer (`YYYY.MM.DD` in `pyproject.toml`), newest-first
  `CHANGELOG.rst`, tags `release-*`.

## Frontend summary

- **Current state: Vue 2.7 + Vuetify 2.6** with vue-router 3, Vite 3
  (`@vitejs/plugin-vue2`), TypeScript, Vitest 2 with
  `@vue/test-utils` v1. npm is the only package manager.
- UI route: **Vuetify** (Material Design). Recorded here so agents do
  not re-ask; the calendar is Vuetify's built-in `<v-calendar>` — no
  third-party calendar library is installed.
- 94 of 98 SFCs already use `<script setup lang="ts">` with typed
  `defineProps`/`defineEmits`. Keep that style; do not add Options API
  components.
- No Pinia/Vuex. Shared state lives in components and `localStorage`
  helpers (`src/core/userSettings.ts`).
- Backend access is hand-written `fetch` bridges in `src/bridge/`
  (composed by `AllBridges` in `src/bridge/index.ts`); remote DTOs in
  `src/remoteModel/`, domain classes in `src/model/`. There is no
  OpenAPI codegen — bridges mirror the backend `model/` schemas by
  hand, so API changes need matching edits on both sides.
- Runtime config is two-layered: the SPA fetches its own
  `/config/remote.json` (gitignored, generated in dev) to learn the
  backend `remoteURL`, then fetches `<remoteURL>/config.json` for OIDC
  and banner settings.
- Tests live in the top-level `frontend/tests/` tree mirroring `src/`.
  Lint runs via pre-commit, not CI; CI runs unit tests and
  `vue-tsc` type-checking.

## Backend <-> frontend contract (calendar-relevant)

- The calendar view fetches `GET /booking?start=…&end=…&simulator-id=…`
  for the visible range; bookings carry a `time_slot` range, `version`
  (optimistic locking) and either full details or an opaque
  `BookingPublic` ("busy") shape depending on the caller's permissions.
- `Simulator.maintenance_window` is rendered as a hatched overlay on
  the calendar intervals.
- Overlapping bookings are rejected server-side (`OverlapError`), and
  Lua policies may reject writes (`PolicyViolation`).

## Vue 3 migration: status and goal

The next big goal is finishing the migration to Vue 3 + Vuetify 3 with
**close visual parity to the current Vue 2 calendar**. Ground truth:

- Mainline (`develop`, `master`, and the checked-out branch) is still
  Vue 2.7. The checked-out branch only contains composition-API prep.
- `origin/vuejs3` is the only real Vue 3 attempt — a WIP from July 2024
  that is ~2 years behind `develop`. **Do not merge it as-is**; treat
  it as reference material.
- `origin/vue-3` is misleadingly named: it points at a Vue 2 commit.

The calendar will be rebuilt on **vue-cal v5** (Vuetify 3's labs
VCalendar is not usable; the component must be entirely free — decided
2026-08-01). The detailed parity checklist, the Vue-2-only chokepoint
files, the milestone plan, and the branches worth harvesting are in
`docs/vue3-migration.md`. Read it before starting any migration work;
`docs/vue3-handover-prompt.md` holds the session kick-off prompt.

## Quartermaster

Instruction kits are resolved **per task**, not per project: call
`resolve_kits(task="…")` before editing or planning, and again when the
work changes shape. Hooks in `.claude/settings.json` enforce this. Do
not hard-code kit lists in this file or other docs.

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
