FROM openfaas/faas-cli:0.11.3

RUN apk add --update docker bash npm

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY functions_to_deploy.sh /functions_to_deploy.sh

WORKDIR /action-helper-workspace/
COPY list-handler-paths.js .
COPY package*.json /action-helper-workspace/
RUN npm install

RUN chmod +x /functions_to_deploy.sh

# Code file to execute when the docker container starts up
ENTRYPOINT ["/functions_to_deploy.sh"]
