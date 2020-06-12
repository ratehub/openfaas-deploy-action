#!/bin/bash -l

set -eux

echo "--------- Starting function deployment process ---------"

# Get the branch name
BRANCH_NAME="$(echo "$GITHUB_REF" | awk -F"/" '{print $3}')"
GCR_ID="gcr.io/platform-235214/"
#Get the deploy files updated
COMMIT_PATH="$(git diff --name-only HEAD~1..HEAD "$GITHUB_SHA")"
#Get the deploy file filename only from the diff
DEPLOY_FILE="$(echo "$COMMIT_PATH" | awk -F"/" '{print $3}')"
#Get the function name only from the diff
FUNCTION="$(echo "$COMMIT_PATH" | awk -F"/" '{print $2}')"


# Add all the files changed in a file
echo "$DEPLOY_FILE" > changed_files.txt
# Add all the functions updated in another file
echo "$FUNCTION" > functions.txt

# For group deploy to the target environment(staging/prod) set the deploy files as a variable
COMMITTED_FILES="$(awk '!unique[$0]++ { count++ } END { print count == 1 ? $1 : "files of multiple environment changed cannot deploy"  }' changed_files.txt)"

# Depending on the deploy file we want to choose a different set of environment variables and credentials

if [ "$COMMITTED_FILES" == 'prod-deploy.yml' ] || [ "$COMMIT_PATH" == 'prod-deploy.yml' ];
then
    FAAS_GATEWAY="${GATEWAY_URL_PROD}"
    FAAS_USER="${GATEWAY_USERNAME_PROD}"
    FAAS_PASS="${GATEWAY_PASSWORD_PROD}"
    
elif [ "$COMMITTED_FILES" == 'staging-deploy.yml' ] ||[ "$COMMIT_PATH" == 'staging-deploy.yml' ];
then
    FAAS_GATEWAY="${GATEWAY_URL_STAGING}"
    FAAS_USER="${GATEWAY_USERNAME_STAGING}"
    FAAS_PASS="${GATEWAY_PASSWORD_STAGING}"
#$COMMIT_PATH is a deploy file updated when the deploy action is triggered by the external FaaS repo
elif [ "$COMMITTED_FILES" == 'dev-deploy.yml' ] || [ "$COMMIT_PATH" == 'dev-deploy.yml' ] || [ -n "${TAG_OVERRIDE:-}" ];
then
    COMMITTED_FILES="dev-deploy.yml"
    COMMIT_PATH='dev-deploy.yml'
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
    if [ -z "${TAG_OVERRIDE:-}" ];
    then
        groupFuncs=($GROUP_FUNCS)
        for func in "${groupFuncs[@]}"
        do
          FUNCTION_NAME="$func"
          IMAGE_TAG="$(yq r "$COMMIT_PATH" functions.$FUNCTION_NAME.image)"
          yq w -i "$COMMIT_PATH" functions."$FUNCTION_NAME".image "$GCR_ID""$IMAGE_TAG"
          yq merge -i "$COMMIT_PATH" stack.yml
          cp -f "$COMMIT_PATH" stack.yml
        done
    else
        groupFuncs=($GROUP_FUNCS)
        for func in "${groupFuncs[@]}"
        do
          #Get the function name from the package file
          FUNCTION_NAME="$func"
          #Add prefix to the deploy file
          IMAGE_TAG="$(yq r "$COMMIT_PATH" functions.$FUNCTION_NAME.image)"
          #Update the image properties in the deploy file
          yq w -i "$COMMIT_PATH" functions."$FUNCTION_NAME".image "$GCR_ID""$FUNCTION_NAME":"${TAG_OVERRIDE}"
          # Merge the deploy file into stack file
          yq merge -i "$COMMIT_PATH" stack.yml
          cp -f "$COMMIT_PATH" stack.yml
       done
    fi
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
            GROUP_PATH="$(echo "$line" | awk -F"/" '{print $1}')"
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

                FUNCTION_PATH="$(echo "$line" | awk -F"/" '{print $2}')"

                if [ -d "$FUNCTION_PATH" ];
                then
                    #If we already handled this function based on a prior file, we can ignore it this time around
                    if [ "$FUNCTION_PATH" != "$FUNCTION_PATH2" ];
                    then
                      if [ -z "${TAG_OVERRIDE:-}" ];
                      then
                          yq p -i "$FUNCTION_PATH/$COMMITTED_FILES" "functions"."$FUNCTION_PATH"
                          # Get the updated image tag if the tag is not latest
                          IMAGE_TAG=$(yq r "$FUNCTION_PATH/$COMMITTED_FILES" functions."$FUNCTION_PATH".image)
                          yq w -i "$FUNCTION_PATH/$COMMITTED_FILES" functions."$FUNCTION_PATH".image "$GCR_ID""$IMAGE_TAG"
                      else
                          #Add prefix to the deploy file
                          yq p -i "$FUNCTION_PATH/$COMMITTED_FILES" "functions"."$FUNCTION_PATH"
                          #Update the image properties in the deploy file
                          yq w -i "$FUNCTION_PATH/$COMMITTED_FILES" functions."$FUNCTION_PATH".image "$GCR_ID""$FUNCTION_PATH":"${TAG_OVERRIDE}"

                      fi
                      yq merge -i "$FUNCTION_PATH/$COMMITTED_FILES" stack.yml
                      cp -f "$FUNCTION_PATH/$COMMITTED_FILES" stack.yml
                      # Deploy all the functions whose deploy files are updated
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
    if [ -n "${AUTH_TOKEN_PROD}:-}" ] && [ "$BRANCH_NAME" == "master" ] && [ "$DEPLOY_FILE" == 'prod-deploy.yml' ];
    then
        curl -H "Authorization: token ${AUTH_TOKEN_PROD}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config/dispatches
    elif [ -n "${AUTH_TOKEN_STAGING}:-}" ] && [ "$DEPLOY_FILE" == 'staging-deploy.yml' ];
    then
       curl -H "Authorization: token ${AUTH_TOKEN_STAGING}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config-staging/dispatches
    fi
    elif [ -n "${AUTH_TOKEN_DEV:-}" ] && [ -n "${TAG_OVERRIDE:-}" ] || [ "$DEPLOY_FILE" == 'dev-deploy.yml' ];
    then
       curl -H "Authorization: token ${AUTH_TOKEN_DEV}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config-dev/dispatches
    fi

fi

echo "---------- Deployment finished-----------"
