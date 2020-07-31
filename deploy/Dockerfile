FROM openfaas/faas-cli:0.11.3

RUN apk update && \
    apk add docker bash curl

RUN wget $(wget -q -O - https://api.github.com/repos/mikefarah/yq/releases/latest | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4) -O /usr/bin/yq
RUN chmod +x /usr/bin/yq

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY deploy.sh /deploy.sh

RUN chmod +x /deploy.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/deploy.sh"]
