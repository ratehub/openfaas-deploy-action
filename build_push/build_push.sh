#!/bin/bash -l

set -eu

# $1 stack-file
# $2 docker-username
# $3 docker-password
# $4 tag
# $5 openfaas-template-url
# $6 image-registry
# $7 build-push-function
# $8 group-path

TAG=$4

function getBuildArgs()
{
    local  buildArgs=""
    # currently we support 6 build arg
    for i in {1..6}
    do
        local key="BUILD_ARG_${i}_NAME"
        local value="BUILD_ARG_${i}_VALUE"
        if [ -n "${!key:-}" ] && [ -n "${!value:-}" ]; then
            buildArgs="${buildArgs} --build-arg ${!key}=${!value}"
        fi
    done
    # bake-in DOCKER_TAG build arg
    buildArgs="${buildArgs} --build-arg DOCKER_TAG=${TAG}"

    # bake-in GITHUB_SHA build arg
    buildArgs="${buildArgs} --build-arg GIT_SHA=${GITHUB_SHA}"

    # bake-in GITHUB_REF build arg. Aka refs/heads/main or refs/tags/1.0.0
    buildArgs="${buildArgs} --build-arg GIT_REF=${GITHUB_REF}"
    echo "$buildArgs"
}

# docker login
echo $3 | docker login --username $2 --password-stdin $6

cd $8

# custom and default faas-template pull
faas-cli template pull
if [ -n "$5" ]; then
    faas-cli template pull $5
fi

echo "Starting to build and push $8/$7 function"

# create `updated-stack.yml` file
# Args:
# stack file path
# gcr hostname and project id
# tag
node /action-helper-workspace/update-image.js "$GITHUB_WORKSPACE/$8/$1" $6 $4
cat updated-stack.yml

BUILD_ARGS=$(getBuildArgs)
echo "Build args: $BUILD_ARGS"

if [[ $7 != "." ]]; then
    faas-cli build -f updated-stack.yml $BUILD_ARGS --filter=$7
    faas-cli push -f updated-stack.yml --filter=$7
else
    faas-cli build -f updated-stack.yml $BUILD_ARGS
    faas-cli push -f updated-stack.yml
fi
