#!/bin/bash -l

set -eux

echo "Starting function template pull process"

FAAS_GATEWAY="${GATEWAY_URL_DEV}"
FAAS_USER="${GATEWAY_USERNAME_DEV}"
FAAS_PASS="${GATEWAY_PASSWORD_DEV}"
BRANCH_NAME="`echo \"$GITHUB_REF\" | cut -d \"/\" -f3`"
STACK_FILE="stack.yml"
FUNCTION_NAME="${FUNCTION}"
NEW_VERSION="${VERSION}"
echo "$NEW_VERSION"
STACK_PATH="${STACK_DIR}"
GCR_URL="gcr.io/platform-235214/"



cd "$STACK_PATH" && UPDATED_STACK_FILE="$(yq w "$STACK_FILE" functions."$FUNCTION_NAME".image "$GCR_URL""$FUNCTION_NAME":"$NEW_VERSION")"
echo "$UPDATED_STACK_FILE" > $STACK_FILE && cd ..


# Depending on which branch we want to choose a different set of environment variables and credentials
if [ "$BRANCH_NAME" == "master" ]  || [ "$GITHUB_EVENT_NAME" == "schedule" ];
then
    FAAS_GATEWAY="${GATEWAY_URL_PROD}"
    FAAS_USER="${GATEWAY_USERNAME_PROD}"
    FAAS_PASS="${GATEWAY_PASSWORD_PROD}"
elif [ "$BRANCH_NAME" == "staging-deploy" ];
then
    FAAS_GATEWAY="${GATEWAY_URL_STAGING}"
    FAAS_USER="${GATEWAY_USERNAME_STAGING}"
    FAAS_PASS="${GATEWAY_PASSWORD_STAGING}"
fi


docker login -u "${DOCKER_USERNAME}" -p "${DOCKER_PASSWORD}" "${DOCKER_REGISTRY_URL}"

if [ -n "${DOCKER_USERNAME_2:-}" ] && [ -n "${DOCKER_PASSWORD_2:-}" ];
then
    docker login -u "${DOCKER_USERNAME_2}" -p "${DOCKER_PASSWORD_2}" "${DOCKER_REGISTRY_URL_2}"
fi

faas-cli template pull

if [ -n "${CUSTOM_TEMPLATE_URL:-}" ];
then
    faas-cli template pull "${CUSTOM_TEMPLATE_URL}"
fi

faas-cli login --username="$FAAS_USER" --password="$FAAS_PASS" --gateway="$FAAS_GATEWAY"

echo "Function template pull process is done!"


echo "Starting function build process"

if [ -f "$GITHUB_WORKSPACE/$STACK_FILE" ];
then
    cp "$ENV_FILE" env.yml
    if [ -n "${BUILD_ARG_1:-}" ] && [ -n "${BUILD_ARG_1_NAME:-}" ];
    then
        faas-cli build --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
    else
        faas-cli build
    fi
elif [ "$GITHUB_EVENT_NAME" == "schedule" ];
then
    reDeployFuncs=($SCHEDULED_REDEPLOY_FUNCS)
    for func in "${reDeployFuncs[@]}"
    do
        GROUP_PATH="`echo \"$func\" | cut -d \"/\" -f1`"
        FUNCTION_PATH="`echo \"$func\" | cut -d \"/\" -f2`"

        cd "$GITHUB_WORKSPACE/$GROUP_PATH"
        cp "$GITHUB_WORKSPACE/template" -r template
        cp "$ENV_FILE" env.yml

        if [ -n "${BUILD_ARG_1:-}" ] && [ -n "${BUILD_ARG_1_NAME:-}" ];
        then
            faas-cli build --filter="$FUNCTION_PATH" --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
        else
            faas-cli build --filter="$FUNCTION_PATH"
        fi

    done
else
    ls -lah
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
                fi

                FUNCTION_PATH="`echo \"$line\" | cut -d \"/\" -f2`"

                if [ -d "$FUNCTION_PATH" ];
                then
                    #If we already handled this function based on a prior file, we can ignore it this time around
                    if [ "$FUNCTION_PATH" != "$FUNCTION_PATH2" ];
                    then
                        if [ -n "${BUILD_ARG_1:-}" ] && [ -n "${BUILD_ARG_1_NAME:-}" ];
                        then
                            faas-cli build --filter="$FUNCTION_PATH" --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
                        else
                            faas-cli build --filter="$FUNCTION_PATH"
                        fi
                        FUNCTION_PATH2="$FUNCTION_PATH"
                    fi

                  fi
            fi
        fi
    done < differences.txt

fi

echo "Function build process is done!"
