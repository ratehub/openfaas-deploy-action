#!/bin/bash -l

set -eu

#  $1 deployment-env
#  $2 stack-file
#  $3 openfaas-username
#  $4 openfaas-password
#  $5 openfaas-gateway
#  $6 api-gateway-auth-token
#  $7 tag-override
#  $8 openfaas-template-url
#  $9 image-registry
# $10 deploy-function
# $11 group-path

ls -la

echo $4 | faas-cli login --username=$3 --password-stdin --gateway=$5

cd ${11}
cd ${10}

# if [ ! -d "template" ]; then
#     cp -R "$GITHUB_WORKSPACE/template" template
# fi

faas-cli template pull
# openfaas custom template pull
if [ -n "$8" ]; then
    faas-cli template pull $8
fi

echo "pwd"
pwd
ls -la

echo "Starting to deploy ${10} function"

if [ ! -f "./$1-deploy.yml" ]; then
    echo "Function specific deploy config not found!"
    touch "./$1-deploy.yml"
fi

# create `updated-stack.yml` file
# Args:
# deployment evironment
# function specific deploy settings
# stack file path
# gcr hostname and project id
# tag override (optional)
node /action-helper-workspace/create-stack.js $1 "./$1-deploy.yml" "$GITHUB_WORKSPACE/$2" $9 $7
cat updated-stack.yml

if [[ ${10} != "." ]]; then
    faas-cli deploy -f updated-stack.yml --gateway=$5 --filter=${10}
else
    faas-cli deploy -f updated-stack.yml --gateway=$5
fi

if [[ $1 == "prod"  ]]; then
    API_GATEWAY_CONFIG_URL="https://api.github.com/repos/ratehub/gateway-config/dispatches"
else
    API_GATEWAY_CONFIG_URL="https://api.github.com/repos/ratehub/gateway-config-$1/dispatches"
fi

# Query gateway action so that functions are added to gateway
if [ -n "$6" ]; then
    curl -H "Authorization: token $6" -d '{"event_type":"repository_dispatch"}' $API_GATEWAY_CONFIG_URL
fi
