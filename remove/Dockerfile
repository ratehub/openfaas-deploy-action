FROM openfaas/faas-cli:0.11.3

RUN apk add --update docker bash

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY remove.sh /remove.sh

RUN chmod +x /remove.sh

# Code file to execute when the docker container starts up
ENTRYPOINT ["/remove.sh"]
