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
test without mounting a huge view. This project already has a concrete
version of that split: `docs/behavioural-split-plan.md`, with two
shipped reference implementations (`src/core/session/`,
`src/core/booking/`), a survey grading which large views still fuse
logic with presentation, and a deliberate list of views that should
stay fused (thin CRUD, read-only — don't split those speculatively).
When an edit lands inside one of the flagged views, prefer extracting
the touched piece into its `src/core/<domain>/` the way the plan's
step 0/WP1 describe, rather than adding another fused handler. The
plan's behavior-changing extractions (WP1's sign-off-bypass question,
WP2's newly-guarded delete) are a maintainer decision, not something
to fold into an unrelated patch.

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
