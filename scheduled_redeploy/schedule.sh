#!/bin/bash -l

set -eux

echo "--------- Starting function template pull process ---------"
GCR_ID="gcr.io/platform-235214/"
STACK_FILE="stack.yml"

FAAS_GATEWAY="${GATEWAY_URL_PROD}"
FAAS_USER="${GATEWAY_USERNAME_PROD}"
FAAS_PASS="${GATEWAY_PASSWORD_PROD}"

FUNCTION_NAME="$(basename "${SCHEDULED_REDEPLOY_FUNCS}")"

cd "${SCHEDULED_REDEPLOY_FUNCS}" && PACKAGE_VERSION=$(cat package.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
# Write the updated version into stack file image properties tag
cd .. && UPDATED_STACK_FILE=$(yq w "$STACK_FILE" functions."$FUNCTION_NAME".image "$GCR_ID""$FUNCTION_NAME":"$PACKAGE_VERSION")
echo "$UPDATED_STACK_FILE" > $STACK_FILE

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


echo "--------- FaaS Build triggered by schedule ----------------"

reDeployFuncs=($SCHEDULED_REDEPLOY_FUNCS)
for func in "${reDeployFuncs[@]}"
do
  GROUP_PATH="$(dirname $func)"
  FUNCTION_PATH="$(basename $func)"
  cd "$GITHUB_WORKSPACE/$GROUP_PATH"
  cd "$FUNCTION_PATH" && PACKAGE_VERSION=$(cat package.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
  # Write the updated version into stack file image properties tag
  cd .. && UPDATED_STACK_FILE=$(yq w "$STACK_FILE" functions."$FUNCTION_PATH".image "$GCR_ID""$FUNCTION_PATH":"$PACKAGE_VERSION")
  echo "$UPDATED_STACK_FILE" > $STACK_FILE

  if [ -n "${BUILD_ARG_1:-}" ] && [ -n "${BUILD_ARG_1_NAME:-}" ];
  then

      faas-cli build --filter="$FUNCTION_PATH" --build-arg "$BUILD_ARG_1_NAME=$BUILD_ARG_1"
  else
      faas-cli build --filter="$FUNCTION_PATH"
  fi
  faas-cli push --filter="$FUNCTION_PATH"
  faas-cli deploy --gateway="$FAAS_GATEWAY" --filter="$FUNCTION_PATH"
  curl -H "Authorization: token ${AUTH_TOKEN_PROD}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config/dispatches
done



echo "--------- Scheduled function Re-deployed ---------"
