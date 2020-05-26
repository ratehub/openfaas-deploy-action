#!/bin/bash -l

set -eux

echo "Starting function deployment process"

BRANCH_NAME="`echo \"$GITHUB_REF\" | cut -d \"/\" -f3`"
STACK_FILE="${DEPLOY_FILE}"
FUNCTION_NAME="${FUNCTION}"
STACK_DIR="${STACK_PATH}"




# Depending on which branch we want to choose a different set of environment variables and credentials
if [ "$BRANCH_NAME" == "master" ];
then
    cd "$STACK_DIR" && PREFIX_FILE=$(yq p "$FUNCTION_NAME/$STACK_FILE" "functions"."$FUNCTION_NAME")
    echo "$PREFIX_FILE" > "temp.yml"
    UPDATED_STACK_FILE=$(yq merge "temp.yml" stack.yml)
    echo "$UPDATED_STACK_FILE" > stack.yml && cd ..
    FAAS_GATEWAY="${GATEWAY_URL_PROD}"
    FAAS_USER="${GATEWAY_USERNAME_PROD}"
    FAAS_PASS="${GATEWAY_PASSWORD_PROD}"

elif [ "$BRANCH_NAME" == "staging-deploy" ] && [ "$STACK_FILE" == 'staging-deploy.yml' ];
then
    cd "$STACK_DIR" && PREFIX_FILE=$(yq p "$FUNCTION_NAME/$STACK_FILE" "functions"."$FUNCTION_NAME")
    echo "$PREFIX_FILE" > "temp.yml"
    UPDATED_STACK_FILE=$(yq merge "temp.yml" stack.yml)
    echo "$UPDATED_STACK_FILE" > stack.yml && cd ..
    FAAS_GATEWAY="${GATEWAY_URL_STAGING}"
    FAAS_USER="${GATEWAY_USERNAME_STAGING}"
    FAAS_PASS="${GATEWAY_PASSWORD_STAGING}"

elif [ "$BRANCH_NAME" == "dev-deploy" ] && [ "$STACK_FILE" == 'dev-deploy.yml' ];
then
    cd "$STACK_DIR" && PREFIX_FILE=$(yq p "$FUNCTION_NAME/$STACK_FILE" "functions"."$FUNCTION_NAME")
    echo "$PREFIX_FILE" > "temp.yml"
    UPDATED_STACK_FILE=$(yq merge "temp.yml" stack.yml)
    echo "$UPDATED_STACK_FILE" > stack.yml && cd ..
    FAAS_GATEWAY="${GATEWAY_URL_DEV}"
    FAAS_USER="${GATEWAY_USERNAME_DEV}"
    FAAS_PASS="${GATEWAY_PASSWORD_DEV}"

fi

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


# If there's a stack file in the root of the repo, assume we want to deploy everything
if [ -f "$GITHUB_WORKSPACE/stack.yml" ];
then
    cp "$ENV_FILE" env.yml
    if [ "$GITHUB_EVENT_NAME" == "push" ];
    then
        faas-cli deploy --gateway="$FAAS_GATEWAY"
    fi
elif [ "$GITHUB_EVENT_NAME" == "schedule" ];
then
    reDeployFuncs=($SCHEDULED_REDEPLOY_FUNCS)
    for func in "${reDeployFuncs[@]}"
    do
        GROUP_PATH="`echo \"$func\" | cut -d \"/\" -f1`"
        FUNCTION_PATH="`echo \"$func\" | cut -d \"/\" -f2`"

        cd "$GITHUB_WORKSPACE/$GROUP_PATH"
        cp "$ENV_FILE" env.yml

        faas-cli deploy --gateway="$FAAS_GATEWAY" --filter="$FUNCTION_PATH"

        curl -H "Authorization: token ${AUTH_TOKEN_PROD}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config/dispatches
    done
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

                fi

                FUNCTION_PATH="`echo \"$line\" | cut -d \"/\" -f2`"

                if [ -d "$FUNCTION_PATH" ];
                then
                    #If we already handled this function based on a prior file, we can ignore it this time around
                    if [ "$FUNCTION_PATH" != "$FUNCTION_PATH2" ];
                    then

                        if [ "$GITHUB_EVENT_NAME" == "push" ];
                        then
                            faas-cli deploy --gateway="$FAAS_GATEWAY" --filter="$FUNCTION_PATH"
                        fi
                        FUNCTION_PATH2="$FUNCTION_PATH"
                    fi
                #If the stack.yml file has changed or any of the environment files have changed, redeploy all functions in the group
                elif [ "$FUNCTION_PATH" == "env-dev.yml" ] || [ "$FUNCTION_PATH" == "env-staging.yml" ] || [ "$FUNCTION_PATH" == "env-prod.yml" ];
                then
                    if [ "$GITHUB_EVENT_NAME" == "push" ];
                    then
                        faas-cli deploy --gateway="$FAAS_GATEWAY"
                    fi
                fi
            fi
        fi
        # Else: do nothing since the only modifications would be at the root and not in any function folders
    done < differences.txt
fi

if [ "$GITHUB_EVENT_NAME" == "push" ];
then
    # Query gateway action so that functions are added to gateway
    if [ -n "${AUTH_TOKEN_PROD}:-}" ] && [ "$BRANCH_NAME" == "master" ];
    then
        curl -H "Authorization: token ${AUTH_TOKEN_PROD}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config/dispatches
    elif [ -n "${AUTH_TOKEN_STAGING}:-}" ] && [ "$BRANCH_NAME" == "staging-deploy" ];
    then
        curl -H "Authorization: token ${AUTH_TOKEN_STAGING}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config-staging/dispatches
    fi

    echo "Finished function deployment process"
else
    echo "Deployment finished"
fi
