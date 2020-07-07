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

function getBuildArgs()
{
    local  buildArgs=""
    # currently we support 6 build arg
    for i in {1..6}
    do
        local key="BUILD_ARG_${i}_NAME"
        local value="BUILD_ARG_${i}_VALUE"
        if [ -n "${!key:-}" ] && [ -n "${!value:-}" ];
        then
            buildArgs="${buildArgs} --build-arg ${!key}=${!value}"
        fi
    done
    echo "$buildArgs"
}

if [ -f "$GITHUB_WORKSPACE/$STACK_FILE" ];
then
    #If build action is triggered after the release, get the updated version from package file and set it as the image tag in stack file
    IMAGE=$(yq r stack.yml functions."*".image | cut -f1 -d ":")
    UPDATED_STACK_FILE="$(yq w "$STACK_FILE" functions.*.image "$GCR_ID""$IMAGE":"${TAG}")"
    echo "$UPDATED_STACK_FILE" > $STACK_FILE

    BUILD_ARGS=$(getBuildArgs)

    if [ -n "${BUILD_ARGS:-}" ];
    then
        faas-cli build $BUILD_ARGS
    else
        faas-cli build
    fi

    if [ "$GITHUB_EVENT_NAME" == "push" ];
    then
        faas-cli push
    fi

else

    FUNCTION="$(echo "${TAG}" | cut -f1 -d"-")"
    for GROUP_PATH in */ ;
    do
      cd "$GROUP_PATH"
      if [ -d "$FUNCTION" ];
      then
          cp "$GITHUB_WORKSPACE/template" -r template
          # Get the updated version from the package.json file
          cd "$FUNCTION" && IMAGE_TAG="$(echo "${TAG}" | sed 's/^[^-]*-//g')"
          # Write the updated version into stack file image properties tag
          cd .. && UPDATED_STACK_FILE=$(yq w "$STACK_FILE" functions."$FUNCTION".image "$GCR_ID""$FUNCTION":"$IMAGE_TAG")
          echo "$UPDATED_STACK_FILE" > $STACK_FILE

          if [ -n "${BUILD_ARG_1:-}" ] && [ -n "${BUILD_ARG_1_NAME:-}" ];
          then
              faas-cli build --filter="$FUNCTION" --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
          else
              faas-cli build --filter="$FUNCTION"
          fi
          if [ "$GITHUB_EVENT_NAME" == "push" ];
          then
              faas-cli push --filter="$FUNCTION"
          fi
      fi
      cd ..
    done
fi

echo "--------- Function build and Push process is done ---------"
