#!/bin/bash -l

set -eux

echo "--------- Starting function deployment process ---------"

# Get the branch name, commit touch, deploy file, stack file path, function name
BRANCH_NAME="`echo \"$GITHUB_REF\" | cut -d \"/\" -f3`"
GCR_ID="gcr.io/platform-235214/"
COMMIT_PATH="$(git diff --name-only HEAD~1..HEAD "$GITHUB_SHA")"
DEPLOY_FILE="`echo "$COMMIT_PATH" | awk -F"/" '{print $3}'`"
FUNCTION="`echo "$COMMIT_PATH" | awk -F"/" '{print $2}'`"
#STACK_PATH="`echo "$COMMIT_PATH" | awk -F"/" '{print $1}'`"

echo "$DEPLOY_FILE" > changed_files.txt
echo "$FUNCTION" > functions.txt
COMMITTED_FILES="$(awk '!unique[$0]++ { count++ } END { print count == 1 ? $1 : "files of multiple environment changed cannot deploy"  }' changed_files.txt)"

if [ -z "${TAG_OVERRIDE}" ];
then
   TAG="invalid"
else
   TAG="${TAG_OVERRIDE}"
fi


# Depending on which branch we want to choose a different set of environment variables and credentials
if [ "$BRANCH_NAME" == "master" ];
then
    if [ "$COMMITTED_FILES" == 'prod-deploy.yml' ] || [ "$COMMIT_PATH" == 'prod-deploy.yml' ];
    then
        FAAS_GATEWAY="${GATEWAY_URL_PROD}"
        FAAS_USER="${GATEWAY_USERNAME_PROD}"
        FAAS_PASS="${GATEWAY_PASSWORD_PROD}"
    fi
elif [ "$COMMITTED_FILES" == 'staging-deploy.yml' ] ||[ "$COMMIT_PATH" == 'staging-deploy.yml' ];
then
    FAAS_GATEWAY="${GATEWAY_URL_STAGING}"
    FAAS_USER="${GATEWAY_USERNAME_STAGING}"
    FAAS_PASS="${GATEWAY_PASSWORD_STAGING}"

elif [ "$COMMITTED_FILES" == 'dev-deploy.yml' ] || [ "$TAG" == 'latest' ];
then
    COMMITTED_FILES="dev-deploy.yml"
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

    FUNCTION_NAME="$(cat package.json | grep name | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')"
    yq p -i "$COMMIT_PATH" "functions"."$FUNCTION_NAME"
    IMAGE_TAG=$(yq r "$COMMIT_PATH" functions."$FUNCTION_NAME".image)
    yq w -i "$COMMIT_PATH" functions."$FUNCTION_NAME".image "$GCR_ID""$IMAGE_TAG"
    yq merge -i "$COMMIT_PATH" stack.yml
    cp -f "$COMMIT_PATH" stack.yml
    if [ "$GITHUB_EVENT_NAME" == "push" ];
    then
        faas-cli deploy --gateway="$FAAS_GATEWAY"
    fi
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
                    cp "$GITHUB_WORKSPACE/functions.txt" -r functions.txt

                fi

                FUNCTION_PATH="`echo \"$line\" | cut -d \"/\" -f2`"

                if [ -d "$FUNCTION_PATH" ];
                then
                    #If we already handled this function based on a prior file, we can ignore it this time around
                    if [ "$FUNCTION_PATH" != "$FUNCTION_PATH2" ];
                    then
                      if [ -z "${TAG_OVERRIDE}" ];
                      then
                          yq p -i "$FUNCTION_PATH/$COMMITTED_FILES" "functions"."$FUNCTION_PATH"
                          IMAGE_TAG=$(yq r "$FUNCTION_PATH/$COMMITTED_FILES" functions."$FUNCTION_PATH".image)
                          yq w -i "$FUNCTION_PATH/$COMMITTED_FILES" functions."$FUNCTION_PATH".image "$GCR_ID""$IMAGE_TAG"
                      else
                          yq p -i "$FUNCTION_PATH/$COMMITTED_FILES" "functions"."$FUNCTION_PATH"
                          yq w -i "$FUNCTION_PATH/$COMMITTED_FILES" functions."$FUNCTION_PATH".image "$GCR_ID""$FUNCTION_PATH":"${TAG_OVERRIDE}"
                      fi
                      yq merge -i "$FUNCTION_PATH/$COMMITTED_FILES" stack.yml
                      cp -f "$FUNCTION_PATH/$COMMITTED_FILES" stack.yml

                      while IFS= read -r LINE; do
                          faas-cli deploy --gateway="$FAAS_GATEWAY" --filter="$LINE"
                      done < functions.txt
                      FUNCTION_PATH2="$FUNCTION_PATH"

                    fi

                fi

            fi
        fi

    done < differences.txt
fi

if [ "$GITHUB_EVENT_NAME" == "push" ];
then
    # Query gateway action so that functions are added to gateway
    if [ -n "${AUTH_TOKEN_PROD}:-}" ] && [ "$BRANCH_NAME" == "master" ];
    then
        curl -H "Authorization: token ${AUTH_TOKEN_PROD}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config/dispatches
    elif [ -n "${AUTH_TOKEN_STAGING}:-}" ] && [ "$DEPLOY_FILE" == 'staging-deploy.yml' ];
    then
       curl -H "Authorization: token ${AUTH_TOKEN_STAGING}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config-staging/dispatches
    fi

    echo "---------- Deployment finished-----------"
else
     echo "--------- Deployment finished for dev environment---------"
fi
