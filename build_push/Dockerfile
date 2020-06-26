FROM openfaas/faas-cli:0.11.3

ARG DOCKER_USERNAME
ARG DOCKER_PASSWORD
ARG DOCKER_REGISTRY_URL=""
ARG DOCKER_USERNAME_2=""
ARG DOCKER_PASSWORD_2=""
ARG DOCKER_REGISTRY_URL_2=""
ARG CUSTOM_TEMPLATE_URL=""
ARG BUILD_ARG_1_NAME
ARG BUILD_ARG_1
ARG TAG_OVERRIDE
ARG LATEST_TAG
ARG HOTFIX_TAG


ENV DOCKER_USERNAME=${DOCKER_USERNAME}
ENV DOCKER_PASSWORD=${DOCKER_PASSWORD}
ENV DOCKER_REGISTRY=${DOCKER_REGISTRY_URL}
ENV DOCKER_USERNAME=${DOCKER_USERNAME_2}
ENV DOCKER_PASSWORD=${DOCKER_PASSWORD_2}
ENV DOCKER_REGISTRY=${DOCKER_REGISTRY_URL_2}
ENV CUSTOM_TEMPLATE_URL=${CUSTOM_TEMPLATE_URL}
ENV BUILD_ARG_1=${BUILD_ARG_1}
ENV BUILD_ARG_1_NAME=${BUILD_ARG_1_NAME}
ENV TAG_OVERRIDE=${TAG_OVERRIDE}
ENV LATEST_TAG=${LATEST_TAG}
ENV HOTFIX_TAG=${HOTFIX_TAG}


RUN apk add docker
RUN apk add bash
RUN apk add curl
RUN apk update

RUN wget $(wget -q -O - https://api.github.com/repos/mikefarah/yq/releases/latest | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4) -O /usr/bin/yq
RUN chmod +x /usr/bin/yq


# Copies your code file from your action repository to the filesystem path `/` of the container
COPY build_push.sh /build_push.sh

RUN chmod +x /build_push.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/build_push.sh"]
