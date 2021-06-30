FROM openfaas/faas-cli:0.11.3

ARG BUILD_ARG_1_NAME
ARG BUILD_ARG_1_VALUE
ARG BUILD_ARG_2_NAME
ARG BUILD_ARG_2_VALUE
ARG BUILD_ARG_3_NAME
ARG BUILD_ARG_3_VALUE
ARG BUILD_ARG_4_NAME
ARG BUILD_ARG_4_VALUE
ARG BUILD_ARG_5_NAME
ARG BUILD_ARG_5_VALUE
ARG BUILD_ARG_6_NAME
ARG BUILD_ARG_6_VALUE

ENV BUILD_ARG_1_NAME=${BUILD_ARG_1_NAME}
ENV BUILD_ARG_1_VALUE=${BUILD_ARG_1_VALUE}
ENV BUILD_ARG_2_NAME=${BUILD_ARG_2_NAME}
ENV BUILD_ARG_2_VALUE=${BUILD_ARG_2_VALUE}
ENV BUILD_ARG_3_NAME=${BUILD_ARG_3_NAME}
ENV BUILD_ARG_3_VALUE=${BUILD_ARG_3_VALUE}
ENV BUILD_ARG_4_NAME=${BUILD_ARG_4_NAME}
ENV BUILD_ARG_4_VALUE=${BUILD_ARG_4_VALUE}
ENV BUILD_ARG_5_NAME=${BUILD_ARG_5_NAME}
ENV BUILD_ARG_5_VALUE=${BUILD_ARG_5_VALUE}
ENV BUILD_ARG_6_NAME=${BUILD_ARG_6_NAME}
ENV BUILD_ARG_6_VALUE=${BUILD_ARG_6_VALUE}

RUN apk add --update docker bash npm curl openssh

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY build_push.sh /build_push.sh

WORKDIR /action-helper-workspace/
COPY update-image.js .
COPY package*.json /action-helper-workspace/
RUN npm install

RUN chmod +x /build_push.sh

# Code file to execute when the docker container starts up
ENTRYPOINT ["/build_push.sh"]
