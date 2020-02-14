#!/bin/bash -l
set -eux

echo "Starting function deployment process"

FAAS_GATEWAY="${GATEWAY_URL_DEV}"
FAAS_USER="${GATEWAY_USERNAME_DEV}"
FAAS_PASS="${GATEWAY_PASSWORD_DEV}"
ENV_FILE="env-dev.yml"
BRANCH_NAME="`echo \"$GITHUB_REF\" | cut -d \"/\" -f3`"

# Depending on which branch we want to choose a different set of environment variables and credentials
if [ "$BRANCH_NAME" == "master" ];
then
    ENV_FILE="env-prod.yml"
    FAAS_GATEWAY="${GATEWAY_URL_PROD}"
    FAAS_USER="${GATEWAY_USERNAME_PROD}"
    FAAS_PASS="${GATEWAY_PASSWORD_PROD}"
elif [ "$BRANCH_NAME" == "staging-deploy" ];
then
    ENV_FILE="env-staging.yml"
    FAAS_GATEWAY="${GATEWAY_URL_STAGING}"
    FAAS_USER="${GATEWAY_USERNAME_STAGING}"
    FAAS_PASS="${GATEWAY_PASSWORD_STAGING}"
fi

docker login -u "${DOCKER_USERNAME}" -p "${DOCKER_PASSWORD}" "${DOCKER_REGISTRY_URL}"

echo "DOCKER_USERNAME_2: ${DOCKER_USERNAME_2}"
echo "DOCKER_PASSWORD_2: ${DOCKER_PASSWORD_2}"

if [ -n "${DOCKER_USERNAME_2}" ] && [ -n "${DOCKER_PASSWORD_2}" ];
then
    docker login -u "${DOCKER_USERNAME_2}" -p "${DOCKER_PASSWORD_2}" "${DOCKER_REGISTRY_URL_2}"
fi

faas-cli template pull

if [ -n "${CUSTOM_TEMPLATE_URL}" ];
then
    faas-cli template pull "${CUSTOM_TEMPLATE_URL}"
fi

faas-cli login --username="$FAAS_USER" --password="$FAAS_PASS" --gateway="$FAAS_GATEWAY"

# If there's a stack file in the root of the repo, assume we want to deploy everything
if [ -f "$GITHUB_WORKSPACE/stack.yml" ];
then
    cp "$ENV_FILE" env.yml
    if [ -n "$BUILD_ARG_1" ] && [ -n "$BUILD_ARG_1_NAME" ];
    then
        faas-cli build --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
    else
        faas-cli build
    fi

    faas-cli push
    faas-cli deploy --gateway="$FAAS_GATEWAY"
else
    GROUP_PATH=""
    GROUP_PATH2=""
    FUNCTION_PATH2=""

    git diff HEAD HEAD~1 --name-only > differences.txt

    while IFS= read -r line; do
        #If changes are in root, we can ignore them
        if [[ "$line" =~ "/" ]];
        then
            GROUP_PATH="`echo \"$line\" | cut -d \"/\" -f1`"
            #Ignore changes if the folder is prefixed with a "." or "_"
            if [[ ! "$GROUP_PATH" =~ ^[\._] ]];
            then
                if [ "$GROUP_PATH" != "$GROUP_PATH2" ];
                then
                    GROUP_PATH2="$GROUP_PATH"
                    cd "$GITHUB_WORKSPACE/$GROUP_PATH"
                    cp "$GITHUB_WORKSPACE/template" -r template
                    cp "$ENV_FILE" env.yml
                fi

                FUNCTION_PATH="`echo \"$line\" | cut -d \"/\" -f2`"

                if [ -d "$FUNCTION_PATH" ];
                then
                    #If we already handled this function based on a prior file, we can ignore it this time around
                    if [ "$FUNCTION_PATH" != "$FUNCTION_PATH2" ];
                    then
                        if [ -n "${BUILD_ARG_1}" ] && [ -n "${BUILD_ARG_1_NAME}" ];
                        then
                            faas-cli build --filter="$FUNCTION_PATH" --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
                        else
                            faas-cli build --filter="$FUNCTION_PATH"
                        fi

                        faas-cli push --filter="$FUNCTION_PATH"
                        faas-cli deploy --gateway="$FAAS_GATEWAY" --filter="$FUNCTION_PATH"
                        FUNCTION_PATH2="$FUNCTION_PATH"
                    fi
                #If the stack.yml file has changed or any of the environment files have changed, redeploy all functions in the group
                elif [ "$FUNCTION_PATH" == "stack.yml" ] || [ "$FUNCTION_PATH" == "env-dev.yml" ] || [ "$FUNCTION_PATH" == "env-staging.yml" ] || [ "$FUNCTION_PATH" == "env-prod.yml" ];
                then
                    faas-cli deploy --gateway="$FAAS_GATEWAY"
                fi
            fi
        fi
        # Else: do nothing since the only modifications would be at the root and not in any function folders
    done < differences.txt
fi

echo "Finished function deployment process"
