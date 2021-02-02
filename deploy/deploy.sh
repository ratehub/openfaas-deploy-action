#!/bin/bash -l

set -eu

#  $1 deployment-env
#  $2 stack-file
#  $3 openfaas-username
#  $4 openfaas-password
#  $5 openfaas-gateway
#  $6 tag-override
#  $7 openfaas-template-url
#  $8 image-registry
#  $9 deploy-function
# $10 group-path
# $11 config-override

echo $4 | faas-cli login --username=$3 --password-stdin --gateway=$5

echo "Starting to deploy ${10}/$9 function"

cd ${10}
cd $9

faas-cli template pull
# openfaas custom template pull
if [ -n "$7" ]; then
    faas-cli template pull $7
fi

if [ ! -f "$GITHUB_WORKSPACE/${10}/global-$1-deploy.yml" ]; then
    echo "No global config file!"
    touch "$GITHUB_WORKSPACE/${10}/global-$1-deploy.yml"
fi

# create `updated-stack.yml` file
# Args:
# global settings
# function specific deploy settings
# stack file path
# gcr hostname and project id
# tag override (optional)
if [[ ${11} == "none"  ]]; then
    node /action-helper-workspace/create-stack.js "$GITHUB_WORKSPACE/${10}/global-$1-deploy.yml" "./$1-deploy.yml" "$GITHUB_WORKSPACE/${10}/$2" $8 $6
else
    node /action-helper-workspace/create-stack.js "$GITHUB_WORKSPACE/${10}/global-$1-deploy.yml" "./${11}" "$GITHUB_WORKSPACE/${10}/$2" $8 $6
fi

cat updated-stack.yml

echo "faas-cli deploy -f updated-stack.yml --gateway=$5"
