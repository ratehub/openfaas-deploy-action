#!/bin/bash -l

set -eux

echo "##### Starting function template pull process #####"


STACK_FILE="stack.yml"
GCR_URL="gcr.io/platform-235214/"




# cd "$STACK_PATH" && UPDATED_STACK_FILE="$(yq w "$STACK_FILE" functions."$FUNCTION_NAME".image "$GCR_URL""$FUNCTION_NAME":"$NEW_VERSION")"
# echo "$UPDATED_STACK_FILE" > $STACK_FILE && cd ..



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


echo "##### Function template pull process is done #####"

echo "##### Starting function build and push process #####"

if [ -f "$GITHUB_WORKSPACE/$STACK_FILE" ];
then
    if [ -n "${BUILD_ARG_1:-}" ] && [ -n "${BUILD_ARG_1_NAME:-}" ];
    then
        faas-cli build --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
    else
        faas-cli build
    fi
    if [ "$GITHUB_EVENT_NAME" == "push" ];
    then
        faas-cli push
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

        if [ -n "${BUILD_ARG_1:-}" ] && [ -n "${BUILD_ARG_1_NAME:-}" ];
        then
            faas-cli build --filter="$FUNCTION_PATH" --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
        else
            faas-cli build --filter="$FUNCTION_PATH"
        fi
        faas-cli push --filter="$FUNCTION_PATH"
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
                        if [ -n "${BUILD_ARG_1:-}" ] && [ -n "${BUILD_ARG_1_NAME:-}" ];
                        then
                            cd "$FUNCTION_PATH" && PACKAGE_VERSION="$(cat package.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')"
                            cd .. && UPDATED_STACK_FILE="$(yq w "$STACK_FILE" functions."$FUNCTION_PATH".image "$GCR_URL""$FUNCTION_PATH":"$PACKAGE_VERSION")"
                            echo "$UPDATED_STACK_FILE" > $STACK_FILE
                            faas-cli build --filter="$FUNCTION_PATH" --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
                        else
                            cd "$FUNCTION_PATH" && PACKAGE_VERSION="$(cat package.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')"
                            cd .. && UPDATED_STACK_FILE="$(yq w "$STACK_FILE" functions."$FUNCTION_NAME".image "$GCR_URL""$FUNCTION_NAME":"$PACKAGE_VERSION")"
                            echo "$UPDATED_STACK_FILE" > $STACK_FILE
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

echo "##### Function build and Push process is done #####"