#!/bin/bash -l

set -eux

echo "--------- Starting function template pull process ---------"
STACK_FILE="stack.yml"
# Default GCR url/project ID
GCR_ID="gcr.io/platform-235214/"


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


echo "--------- Function template pull process is done ---------"

echo "***********************************************************"

echo "--------- Starting function build and push process ---------"

if [ -f "$GITHUB_WORKSPACE/$STACK_FILE" ];
then
    #if the TAG_OVERRIDE flag is set to latest, update image properties in stack file
    if [ -z "${TAG_OVERRIDE:-}" ];
    then
        #If build action is triggered after the release, get the updated version from package file and set it as the image tag in stack file
        PACKAGE_VERSION="$(cat package.json | sed 's/.*"version": "\(.*\)".*/\1/;t;d')"
        FUNCTION_PATH="$(cat package.json | grep name | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')"
        UPDATED_STACK_FILE="$(yq w "$STACK_FILE" functions."$FUNCTION_PATH".image "$GCR_ID""$FUNCTION_PATH":"$PACKAGE_VERSION")"
        echo "$UPDATED_STACK_FILE" > $STACK_FILE
    else
        FUNCTION_PATH="$(cat package.json | grep name | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')"
        UPDATED_STACK_FILE="$(yq w "$STACK_FILE" functions."$FUNCTION_PATH".image "$GCR_ID""$FUNCTION_PATH":"$TAG_OVERRIDE")"
        echo "$UPDATED_STACK_FILE" > $STACK_FILE
    fi
    if [ -n "${BUILD_ARG_1:-}" ] && [ -n "${BUILD_ARG_1_NAME:-}" ];
    then
        faas-cli build --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
    else
        faas-cli build
    fi
    if [ "$GITHUB_EVENT_NAME" == "push" ];
    then
        faas-cli push --filter="$FUNCTION_PATH"
    fi
else
    GROUP_PATH=""
    GROUP_PATH2=""
    FUNCTION_PATH2=""

    if [ -z "${LATEST_TAG:-}" ] && [ -z "${HOTFIX_TAG:-}" ];
    then
        git diff HEAD HEAD~1 --name-only > differences.txt
    else
        git fetch all
        git diff HOTFIX_TAG LATEST_TAG --stat > differences.txt
    fi

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
                fi

                FUNCTION_PATH="$(echo "$line" | awk -F"/" '{print $2}')"

                if [ -d "$FUNCTION_PATH" ];
                then
                    #If we already handled this function based on a prior file, we can ignore it this time around
                    if [ "$FUNCTION_PATH" != "$FUNCTION_PATH2" ];
                    then
                        #if the TAG_OVERRIDE flag is set to latest, update image properties in stack file
                        if [ -z "${TAG_OVERRIDE:-}" ];
                        then
                            # Get the updated version from the package.json file
                            cd "$FUNCTION_PATH" && PACKAGE_VERSION=$(cat package.json | sed 's/.*"version": "\(.*\)".*/\1/;t;d')
                            # Write the updated version into stack file image properties tag
                            cd .. && UPDATED_STACK_FILE=$(yq w "$STACK_FILE" functions."$FUNCTION_PATH".image "$GCR_ID""$FUNCTION_PATH":"$PACKAGE_VERSION")
                            echo "$UPDATED_STACK_FILE" > $STACK_FILE
                        else
                            UPDATED_STACK_FILE=$(yq w "$STACK_FILE" functions."$FUNCTION_PATH".image "$GCR_ID""$FUNCTION_PATH":"$TAG_OVERRIDE")
                            echo "$UPDATED_STACK_FILE" > $STACK_FILE
                        fi
                        if [ -n "${BUILD_ARG_1:-}" ] && [ -n "${BUILD_ARG_1_NAME:-}" ];
                        then
                            faas-cli build --filter="$FUNCTION_PATH" --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
                        else
                            faas-cli build --filter="$FUNCTION_PATH"
                        fi
                        if [ "$GITHUB_EVENT_NAME" == "push" ];
                        then
                            faas-cli push --filter="$FUNCTION_PATH"
                        fi
                        FUNCTION_PATH2="$FUNCTION_PATH"
                    fi
                fi
            fi
        fi
    done < differences.txt

fi

echo "--------- Function build and Push process is done ---------"
