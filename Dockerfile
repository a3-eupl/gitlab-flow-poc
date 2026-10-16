FROM alpine:3.24.2

ARG AMS AMS_NAME AMS_REVISION AMS_BUILD

ENV AMS=${AMS} \
    AHS_NAME=${AMS_NAME} \
    AHS_REVISION=${AMS_REVISION} \
    AHS_BUILD=${AMS_BUILD} \
    TZ=Europe/Bratislava \
    PS1="\[\e[1;35m\]\u\[\e[1;34m\]@\[\e[1;32m\]\${AHS_NAME}\[\e[1;34m\]:\[\e[1;33m\]\${AHS_REVISION}\[\e[1;34m\]:\[\e[1;36m\]\w \[\e[1;35m\]\\$\[\e[0m\] " \
    SHELL=/bin/bash \
    TERM=xterm \
    DOCKER_BUILDKIT=1\
    AIR_VERSION="/cache-volume/air/.version"\
    CI_HOME="/cache-volume/air/ci"\
    ROLLOUT_HOME="/cache-volume/air/rollout"\
    AUTH_HTPASSWD="/cache-volume/.auth.htpasswd"\
    BIN_HOME="/cache-volume/bin"\
    KUBECONFIG_HOME="/cache-volume/kube/config"\
    ENV_HOME="/cache-volume/kube/env"\
    MVN_HOME="/cache-volume/lib/mvn"\
    TRIVY_CACHE_DIR="/cache-volume/lib/trivy"\
    GIT_DEPTH=1

WORKDIR /opt

COPY .opt/ .

RUN sh entry/pip3/entry-run.bin.sh

LABEL org.opencontainers.image.title="hub-gitlab-flow"
LABEL org.opencontainers.image.description="This Docker image simplifies and streamlines the process of building, packaging, and deploying applications stored in a GitLab repository. It supports AMS attributes setup, artifact building, Docker image packaging, image validation, and deployment to Kubernetes-based application servers. It is designed to enhance the software development lifecycle by improving automation and consistency across projects."
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/a3services/hub-gitlab-flow"
LABEL org.opencontainers.image.source="https://github.com/eupl-a3-services/gitlab-flow-poc"
LABEL org.opencontainers.image.documentation="https://github.com/eupl-a3-services/gitlab-flow-poc"
LABEL org.opencontainers.image.licenses="EUPL-1.2"
LABEL org.opencontainers.image.vendor="WILLING + HEAR s.r.o."
LABEL org.opencontainers.image.authors="info@chzb.sk"
LABEL org.opencontainers.image.ref.name="hub-gitlab-flow:latest"
LABEL org.opencontainers.image.revision="git-commit-sha"
LABEL org.opencontainers.image.created="2025-03-30T12:00:00Z"
