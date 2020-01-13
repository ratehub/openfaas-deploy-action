#!/bin/bash -l

echo "Starting function deployment process"

FAAS_GATEWAY="${GATEWAY_URL_STAGING}"
FAAS_USER="${GATEWAY_USERNAME_STAGING}"
FAAS_PASS="${GATEWAY_PASSWORD_STAGING}"
BRANCH_NAME="`echo \"$GITHUB_REF\" | cut -d \"/\" -f3`"

# Depending on which branch we want to choose a different set of environment variables and credentials
if [ "$BRANCH_NAME" == "master" ];
then
    ENV_FILE="env-prod.yml"
    FAAS_GATEWAY="${GATEWAY_URL_PROD}"
    FAAS_USER="${GATEWAY_USERNAME_PROD}"
    FAAS_PASS="${GATEWAY_PASSWORD_PROD}"
else
    ENV_FILE="env-staging.yml"
fi

docker login -u "${DOCKER_USERNAME}" -p "${DOCKER_PASSWORD}" "${DOCKER_REGISTRY_URL}"

faas-cli template pull

faas-cli template pull "${CUSTOM_TEMPLATE_URL}"

faas-cli login --username="$FAAS_USER" --password="$FAAS_PASS" --gateway="$FAAS_GATEWAY"

# If there's a stack file in the root of the repo, assume we want to deploy everything
if [ -f "$GITHUB_WORKSPACE/stack.yml" ];
then
    cp "$ENV_FILE" env.yml
    faas-cli build
    faas-cli push
    faas-cli deploy --gateway="$FAAS_GATEWAY"
else
    GROUP_PATH=""
    GROUP_PATH2=""
    FUNCTION_PATH2=""

    LAST_PUSH_HASH=`git rev-parse origin/master`

    git diff "$LAST_PUSH_HASH" --name-only > differences.txt

    echo "$LAST_PUSH_HASH"

    cat differences.txt

    while IFS= read -r line; do
        #If changes are in root, we can ignore them
        if [[ "$line" =~ "/" ]];
        then
            GROUP_PATH="`echo \"$line\" | cut -d \"/\" -f1`"
            #Ignore changes in these paths
            if [ "$GROUP_PATH" != ".github" ] && [ "$GROUP_PATH" != "__mocks__" ];
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
                        faas-cli build --filter="$FUNCTION_PATH"
                        faas-cli push --filter="$FUNCTION_PATH"
                        faas-cli deploy --gateway="$FAAS_GATEWAY" --filter="$FUNCTION_PATH"
                        FUNCTION_PATH2="$FUNCTION_PATH"
                    fi
                elif [ "$FUNCTION_PATH" == "stack.yml" ];
                then
                    faas-cli deploy --gateway="$FAAS_GATEWAY"
                fi
            fi
        fi
        # Else: do nothing since the only modifications would be at the root and not in any function folders
    done < differences.txt
fi

echo "Finished function deployment process"
