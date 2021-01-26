FROM openfaas/faas-cli:0.12.13-root

RUN apk add --update docker bash npm

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY helper.sh /helper.sh

WORKDIR /action-helper-workspace/
COPY list-handler-paths.js .
COPY package*.json /action-helper-workspace/
RUN npm install

RUN chmod +x /helper.sh

# Code file to execute when the docker container starts up
ENTRYPOINT ["/helper.sh"]
