# Maintenance-operations tooling: the `task` binary plus a Taskfile
# wrapping the plain scripts documented in the backend manual's
# Maintenance Operations page. This is deliberately a separate image
# from the application: it has no runtime need for a task runner, and
# a problem in this one can't touch the running application.
#
# Every target here is a thin wrapper over a standalone script that
# also runs with no `task` involved -- dropping this image entirely
# still leaves fully working operations.
FROM debian:12-slim AS task-download

# Pinned, not "latest": a supply-chain compromise of the download
# should not be able to move this forward silently. Bump deliberately.
ARG TASK_VERSION=3.53.1
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /dl
# The build machine has internet; the host this image is deployed to
# does not need it, since the binary is already inside the image by
# the time it gets there. Verified against the project's own published
# checksums file before anything is extracted -- a corrupted or
# tampered download is rejected here, not silently run later.
RUN curl -sL -o task_checksums.txt \
      "https://github.com/go-task/task/releases/download/v${TASK_VERSION}/task_checksums.txt" \
 && curl -sL -o "task_linux_${TARGETARCH}.tar.gz" \
      "https://github.com/go-task/task/releases/download/v${TASK_VERSION}/task_linux_${TARGETARCH}.tar.gz" \
 && grep "task_linux_${TARGETARCH}.tar.gz" task_checksums.txt | sha256sum -c - \
 && tar -xzf "task_linux_${TARGETARCH}.tar.gz" task

FROM debian:12-slim AS ops
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY --from=task-download /dl/task /usr/local/bin/task
# Just the CLI, not the full docker.io package: that installs a whole
# unused daemon. The scripts below only ever talk to the host's own
# Docker, via its socket mounted in at run time.
COPY --from=docker:27-cli /usr/local/bin/docker /usr/local/bin/docker
COPY ops/Taskfile.yaml /ops/Taskfile.yaml
COPY backend/docs/source/maintenance/data/backup.bash /ops/backup.bash
COPY backend/docs/source/maintenance/data/anonymise-dump.bash /ops/anonymise-dump.bash
COPY backend/docs/source/maintenance/data/anonymise.sql /ops/anonymise.sql
# upload-to-az.bash is deliberately NOT included: it needs the Azure
# CLI, which is a large dependency neither of the other two scripts
# needs. Bundling it here would mean carrying that weight for every
# user of this image, not just Azure Blob ones. Run it directly on a
# host that already has `az` installed instead.
RUN chmod +x /ops/*.bash
WORKDIR /ops
ENTRYPOINT ["task"]
CMD ["--list"]
