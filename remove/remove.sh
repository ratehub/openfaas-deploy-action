#!/bin/bash -l

set -eu

#  $1 openfaas-username
#  $2 openfaas-password
#  $3 openfaas-gateway
#  $4 function-name

echo $2 | faas-cli login --username=$1 --password-stdin --gateway=$3

echo "Removing $4"

faas-cli remove $4 --gateway=$3
