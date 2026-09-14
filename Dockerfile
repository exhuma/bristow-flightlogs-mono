# cspell: ignore libxmlsec
#
# The product version, supplied by the release workflow. Declared here,
# before any FROM, so it is visible as a default to every stage that
# redeclares it -- ARGs do not otherwise cross stage boundaries.
ARG APP_VERSION=0.0.0

# -----------------------------------------------------------------------------
# Web application (frontend/)
# -----------------------------------------------------------------------------

# Node minor is pinned and kept in step with frontend/.nvmrc. Vite 7
# requires >= 20.19, so a bare "node:20" tag can silently drop below
# the floor.
FROM node:20.19 AS web-deps
WORKDIR /usr/local/src/flightlogs-frontend
# Manifests only, so the install layer is reused for as long as the
# dependencies are unchanged. Copying the sources first invalidates it
# on every source edit, making each build a cold install of monaco,
# vuetify and echarts.
COPY frontend/package.json frontend/package-lock.json ./
RUN npm clean-install

FROM web-deps AS web-build
WORKDIR /usr/local/src/flightlogs-frontend
COPY frontend/ .
ARG APP_VERSION
ARG VITE_BUILD_REF
ARG VITE_BUILD_DATE
ARG NODE_OPTIONS
ENV VITE_APP_VERSION=${APP_VERSION}
RUN npm run build-only-prod

# -----------------------------------------------------------------------------
# API (backend/)
# -----------------------------------------------------------------------------

FROM python:3.12-slim AS api-build
RUN apt-get update && apt-get install -y \
    libxmlsec1-openssl \
    python3-dev \
    libxml2-dev \
    libxmlsec1-dev \
    build-essential \
    pipx \
    pkg-config

COPY backend/ /usr/src/flightlogs
# Overwrites the placeholder backend/CHANGELOG.rst: this repo is the
# one that knows which pair of submodule commits shipped together, so
# it is the one that owns the changelog.
COPY CHANGELOG.rst /usr/src/flightlogs/CHANGELOG.rst
WORKDIR /usr/src/flightlogs

RUN pipx install uv
ENV PATH=/root/.local/bin:$PATH
ENV UV_PROJECT_ENVIRONMENT=/opt/build-env
RUN uv sync --locked
ARG APP_VERSION
ENV FLIGHTLOGS_APP_VERSION=${APP_VERSION}
RUN uv run sphinx-build docs/source docs/build

ENV UV_PROJECT_ENVIRONMENT=/opt/flightlogs
RUN uv sync --no-group dev --locked
RUN uv add --frozen pip
RUN uv export > /requirements.txt
RUN uv run pip install --no-deps /usr/src/flightlogs

# -----------------------------------------------------------------------------
# Reproduction artifacts, extracted with `--target export --output
# type=local`. Doing it this way means the release job does not have
# to create and remove a throwaway container just to copy files out.
# -----------------------------------------------------------------------------

FROM scratch AS export
COPY --from=api-build /requirements.txt /
COPY --from=web-build \
     /usr/local/src/flightlogs-frontend/package-lock.json /

# -----------------------------------------------------------------------------
# The single served image
# -----------------------------------------------------------------------------

FROM python:3.12-slim AS prod
RUN apt-get update && apt-get install -y \
    libxmlsec1-openssl
# Absolute because WORKDIR is "/" in this stage, so a relative default
# would resolve against the filesystem root.
ENV FLIGHTLOGS_MANUAL_ROOT=/opt/flightlogs/manual
ENV FLIGHTLOGS_STATIC_ROOT=/opt/flightlogs/static
ARG APP_VERSION
ENV FLIGHTLOGS_APP_VERSION=${APP_VERSION}
COPY --from=api-build /usr/src/flightlogs/alembic /opt/flightlogs/alembic
COPY --from=api-build /usr/src/flightlogs/alembic.ini /opt/flightlogs
COPY --from=api-build /usr/src/flightlogs/docker-resources/main.bash \
     /opt/flightlogs/bin/flightlogs-main.bash
COPY --from=api-build /usr/src/flightlogs/docker-resources/healthcheck.py \
     /opt/flightlogs/bin/healthcheck.py
COPY --from=api-build /usr/src/flightlogs/docker-resources/logging.yaml \
     /opt/flightlogs/etc/logging.yaml
RUN chmod +x /opt/flightlogs/bin/flightlogs-main.bash
COPY --from=api-build /opt/flightlogs /opt/flightlogs
COPY --from=api-build /requirements.txt /opt/flightlogs/requirements.txt
COPY --from=api-build /usr/src/flightlogs/docs/build /opt/flightlogs/manual
COPY --from=web-build \
     /usr/local/src/flightlogs-frontend/dist/ /opt/flightlogs/static
# A web build that silently produced no bundle would otherwise yield an
# image that looks fine and serves the API only -- _mount_web_application
# degrades gracefully on a missing index.html precisely so a broken
# deploy doesn't crash, which also means it won't announce itself here.
RUN test -f /opt/flightlogs/static/index.html
RUN  mkdir /opt/flightlogs/logs
WORKDIR /
EXPOSE 8000
# Plain HTTP, redirected to HTTPS. Unprivileged so the image does not
# need root to bind it; publish it as 80:8080.
EXPOSE 8080
# The start period covers waiting for the database plus the migration
# retry loop, both of which run before the server binds its port.
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD ["python", "/opt/flightlogs/bin/healthcheck.py"]
ENTRYPOINT ["/opt/flightlogs/bin/flightlogs-main.bash"]
