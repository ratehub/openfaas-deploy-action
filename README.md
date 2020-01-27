# GitHub Action to Build, Push, and Deploy OpenFaaS Functions/Microservices

This action is designed to deploy functions or microservices developed with [OpenFaaS](https://www.openfaas.com).


## Requirements
1. Your repository must be organized in one of the following ways: 
   1. A single stack.yml file in the root (For a single microservice or a small number of functions)  
   ```
      your-repo/
        ├── function 1/
        │   └── handler.js
        ├── function-2/
        │   └── handler.js
        ├── env-prod.yml
        ├── env-staging.yml
        └── stack.yml
   ```
      This method will result in every function being rebuilt, pushed, and deployed every time something changes in the repository. The names of the function folders don't matter as long as the handler paths are properly configured in stack.yml.
      
   2. Functions grouped into related folders, each with their own stack.yml file (For repos with a large number of functions)  
   ```
      your-repo/
        ├── group-1/
        │   ├── function-1/
        │   │   └── handler.js
        │   ├── function-2/
        │   │   └── handler.js
        │   ├── env-prod.yml
        │   ├── env-staging.yml
        │   └── stack.yml
        └── group-2/
            ├── function-1/
            │   └── handler.js
            ├── env-prod.yml
            ├── env-staging.yml
            └── stack.yml
   ```
      Group and function folders can be named whatever you like, but function folder names must correspond exactly to the name of a function in the stack.yml in its group folder.
      
2. Your GitHub repo must have access to the required secrets specified in the "Secrets" section below


## Secrets
All secrets are required unless otherwise specified.
- **CustomTemplateURL** (Optional): The URL of a repository of custom OpenFaaS templates. If you require basic-auth, include it in the URL string.
- **DockerUsername**: Username of an account with access to the docker registry where your function images are stored.
- **DockerPassword**: Password of an account with access to the docker registry where your function images are stored.
- **DockerRegistryURL** (Optional): The URL of the docker registry where your function images are stored. Leave this blank if you wish to authenticate with Docker Hub.
- **DockerUsername2** (Optional): Username of a second docker account, if needed.
- **DockerPassword2** (Optional): Password of a second docker account, if needed.
- **DockerRegistryURL2** (Optional): URL of a second docker registry, if needed. Leave this blank if you wish to authenticate with Docker Hub.
- **GatewayUserDev**: The basic-auth username of your development OpenFaaS environment.
- **GatewayPassDev**: The basic-auth password of your development OpenFaaS environment.
- **GatewayURLDev**: The URL of your development OpenFaaS environment.
- **GatewayUserStaging**: The basic-auth username of your staging OpenFaaS environment.
- **GatewayPassStaging**: The basic-auth password of your staging OpenFaaS environment.
- **GatewayURLStaging**: The URL of your staging OpenFaaS environment.
- **GatewayUserProd**: The basic-auth username of your production OpenFaaS environment.
- **GatewayPassProd**: The basic-auth password of your development OpenFaaS environment.
- **GatewayURLProd**: The URL of your production OpenFaaS environment.


## Installation
Using this action is simple. Create a workflow file including the action, like the following, and put it in a folder at ".github/workflows" in the root of the repo:

```
name: OpenFaaS CICD
on:
  push:
    branches:
    - master
    - staging-deploy
    - dev-deploy

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v1
    - name: Build, push, and deploy functions to OpenFaaS
      uses: ratehub/openfaas-deploy-action@master
      env: # Or as an environment variable
        GATEWAY_URL_DEV: ${{ secrets.GatewayURLDev }}
        GATEWAY_URL_STAGING: ${{ secrets.GatewayURLStaging }}
        GATEWAY_URL_PROD: ${{ secrets.GatewayURLProd }}
        GATEWAY_USERNAME_DEV: ${{ secrets.GatewayUserDev }}
        GATEWAY_PASSWORD_DEV: ${{ secrets.GatewayPassDev }}
        GATEWAY_USERNAME_STAGING: ${{ secrets.GatewayUserStaging }}
        GATEWAY_PASSWORD_STAGING: ${{ secrets.GatewayPassStaging }}
        GATEWAY_USERNAME_PROD: ${{ secrets.GatewayUserProd }}
        GATEWAY_PASSWORD_PROD: ${{ secrets.GatewayPassProd }}
        DOCKER_USERNAME: ${{ secrets.DockerUsername }}
        DOCKER_PASSWORD: ${{ secrets.DockerPassword }}
        DOCKER_REGISTRY_URL: ${{ secrets.DockerRegistryURL }}
        DOCKER_USERNAME_2: ${{ secrets.DockerUsername2 }}
        DOCKER_PASSWORD_2: ${{ secrets.DockerPassword2 }}
        DOCKER_REGISTRY_URL_2: ${{ secrets.DockerRegistryURL2 }}
        CUSTOM_TEMPLATE_URL: ${{ secrets.CustomTemplateURL }}
```


## Usage
