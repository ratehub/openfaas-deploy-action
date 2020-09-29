#!/bin/bash -l

set -eu

# $1 stack-file
# $2 docker-username
# $3 docker-password
# $4 docker-registry-url
# $5 tag
# $6 openfaas-template-url
# $7 image-registry
# $8 build-push-function

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
    # bake-in DOCKER_TAG build arg
    buildArgs="${buildArgs} --build-arg DOCKER_TAG=$5"
    echo "$buildArgs"
}

faas-cli template pull

# openfaas custom template pull
if [ -n "$8" ];
then
    faas-cli template pull $8
fi

# docker login
echo $3 | docker login --username $2 --password-stdin $4

cd "$GITHUB_WORKSPACE/$8"

if [ ! -d "template" ];
then
    cp -R "$GITHUB_WORKSPACE/template" template
fi

echo "Starting to build and push $8 function"

# create `updated-stack.yml` file
# Args:
# stack file path
# gcr hostname and project id
# tag
node /action-helper-workspace/update-image.js $1 $5 $7

echo "updated-stack.yml file:"
cat updated-stack.yml
echo ""

echo "BUILD_ARGS:"
BUILD_ARGS=$(getBuildArgs)
echo ""

if [[ ${10} != "." ]];
then
    faas-cli build $BUILD_ARGS --filter=$8
else
    faas-cli build $BUILD_ARGS --filter=$8
fi

faas-cli push
