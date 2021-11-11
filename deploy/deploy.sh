#!/bin/bash -l

set -eu

#  $1 deployment-env
#  $2 stack-file
#  $3 openfaas-username
#  $4 openfaas-password
#  $5 openfaas-gateway
#  $6 tag-override
#  $7 image-registry
#  $8 deploy-function
#  $9 group-path
# $10 config-override

echo $4 | faas-cli login --username=$3 --password-stdin --gateway=$5

echo "Starting to deploy $9/$8 function"

cd $9
cd $8

if [ ! -f "$GITHUB_WORKSPACE/$9/global-$1-deploy.yml" ]; then
    touch "$GITHUB_WORKSPACE/$9/global-$1-deploy.yml"
fi

# create `updated-stack.yml` file
# Args:
# global settings
# function specific deploy settings
# stack file path
# gcr hostname and project id
# tag override (optional)
if [[ ${10} == "none"  ]]; then
    node /action-helper-workspace/create-stack.js "$GITHUB_WORKSPACE/$9/global-$1-deploy.yml" "./$1-deploy.yml" "$GITHUB_WORKSPACE/$9/$2" $7 $6
else
    node /action-helper-workspace/create-stack.js "$GITHUB_WORKSPACE/$9/global-$1-deploy.yml" "./${10}" "$GITHUB_WORKSPACE/$9/$2" $7 $6
fi

cat updated-stack.yml

# faas-cli deploy -f updated-stack.yml --gateway=$5
