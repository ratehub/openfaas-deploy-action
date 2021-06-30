FROM openfaas/faas-cli:0.11.3

RUN apk add --update docker bash npm curl openssh

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY deploy.sh /deploy.sh

WORKDIR /action-helper-workspace/
COPY create-stack.js .
COPY package*.json /action-helper-workspace/
RUN npm install

RUN chmod +x /deploy.sh

# Code file to execute when the docker container starts up
ENTRYPOINT ["/deploy.sh"]
