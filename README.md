# GitHub Action to Build, Push, and Deploy OpenFaaS Functions/Microservices

This action is designed to deploy functions or microservices developed with [OpenFaaS](https://www.openfaas.com).


## Requirements
1. Your repository must be organized in one of the following ways: 
   1. A single stack.yml file and env-dev/prod/staging.yml file in the root (For a single microservice or a small number of functions)  
   ```
      your-repo/
        ├── function 1/
        │   └── handler.js
        ├── function-2/
        │   └── handler.js
        ├── env-dev.yml
        ├── env-prod.yml
        ├── env-staging.yml
        └── stack.yml
   ```
      This method will result in every function being built, pushed, and deployed every time something changes in the repository. The names of the function folders don't matter as long as the handler paths are properly configured in stack.yml.
      
   2. Functions grouped into related folders, each with their own stack.yml file and env-dev/prod/staging.yml files (For repos with a large number of functions)  
   ```
      your-repo/
        ├── group-1/
        │   ├── function-1/
        │   │   └── handler.js
        │   ├── function-2/
        │   │   └── handler.js
        │   ├── env-dev.yml
        │   ├── env-prod.yml
        │   ├── env-staging.yml
        │   └── stack.yml
        └── group-2/
            ├── function-1/
            │   └── handler.js
            ├── env-dev.yml
            ├── env-prod.yml
            ├── env-staging.yml
            └── stack.yml
   ```
      Group and function folders can be named whatever you like, but function folder names must correspond exactly to the name of a function in the stack.yml in its group folder.
      In addition, this method will only build, push, and deploy based on which files changed in the last commit. So if any files changed in a given function's folder, that function will be deployed. If the stack.yml file, or any of the env.yml files change, all functions in that group will be re-deployed (but won't be rebuilt, and will instead use the existing docker images in your registry).
      
2. Your GitHub repo must have access to the required secrets specified in the "Secrets" section below


## Secrets
All secrets are required unless otherwise specified.
- **CUSTOM_TEMPLATE_URL** (Optional): The URL of a repository of custom OpenFaaS templates. If you require basic-auth, include it in the URL string.
- **DOCKER_USERNAME**: Username of an account with access to the docker registry where your function images are stored.
- **DOCKER_PASSWORD**: Password of an account with access to the docker registry where your function images are stored.
- **DOCKER_REGISTRY_URL** (Optional): The URL of the docker registry where your function images are stored. Leave this blank if you wish to authenticate with Docker Hub.
- **DOCKER_USERNAME_2** (Optional): Username of a second docker account, if needed.
- **DOCKER_PASSWORD_2** (Optional): Password of a second docker account, if needed.
- **DOCKER_REGISTRY_URL_2** (Optional): URL of a second docker registry, if needed. Leave this blank if you wish to authenticate with Docker Hub.
- **GATEWAY_USER_DEV**: The basic-auth username of your development OpenFaaS environment.
- **GATEWAY_PASS_DEV**: The basic-auth password of your development OpenFaaS environment.
- **GATEWAY_URL_DEV**: The URL of your development OpenFaaS environment.
- **GATEWAY_USER_STAGING**: The basic-auth username of your staging OpenFaaS environment.
- **GATEWAY_PASS_STAGING**: The basic-auth password of your staging OpenFaaS environment.
- **GATEWAY_URL_STAGING**: The URL of your staging OpenFaaS environment.
- **GATEWAY_USER_PROD**: The basic-auth username of your production OpenFaaS environment.
- **GATEWAY_PASS_PROD**: The basic-auth password of your development OpenFaaS environment.
- **GATEWAY_URL_PROD**: The URL of your production OpenFaaS environment.
- **BUILD_ARG_1**: The value of a build argument to pass into your function templates' dockerfiles through the faas-cli's `build-arg` option (Note that you will also need to include the environment variable BUILD_ARG_1_NAME in the workflow file to specify the name of the argument)


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
    - uses: actions/checkout@v1 # This is a dependency of the action
    - name: Build, push, and deploy functions to OpenFaaS
      uses: ratehub/openfaas-deploy-action@master
      env:
        GATEWAY_URL_DEV: ${{ secrets.GATEWAY_URL_DEV }}
        GATEWAY_URL_STAGING: ${{ secrets.GATEWAY_URL_STAGING }}
        GATEWAY_URL_PROD: ${{ secrets.GATEWAY_URL_PROD }}
        GATEWAY_USERNAME_DEV: ${{ secrets.GATEWAY_USERNAME_DEV }}
        GATEWAY_PASSWORD_DEV: ${{ secrets.GATEWAY_PASSWORD_DEV }}
        GATEWAY_USERNAME_STAGING: ${{ secrets.GATEWAY_USERNAME_STAGING }}
        GATEWAY_PASSWORD_STAGING: ${{ secrets.GATEWAY_PASSWORD_STAGING }}
        GATEWAY_USERNAME_PROD: ${{ secrets.GATEWAY_USERNAME_PROD }}
        GATEWAY_PASSWORD_PROD: ${{ secrets.GATEWAY_PASSWORD_PROD }}
        DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
        DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
        DOCKER_REGISTRY_URL: ${{ secrets.DOCKER_REGISTRY_URL }}
        DOCKER_USERNAME_2: ${{ secrets.DOCKER_USERNAME_2 }}
        DOCKER_PASSWORD_2: ${{ secrets.DOCKER_PASSWORD_2 }}
        DOCKER_REGISTRY_URL_2: ${{ secrets.DOCKER_REGISTRY_URL_2 }}
        CUSTOM_TEMPLATE_URL: ${{ secrets.CUSTOM_TEMPLATE_URL }}
        BUILD_ARG_1_NAME: EXAMPLE_ARG_NAME
        BUILD_ARG_1: ${{ secrets.BUILD_ARG_1 }}
```
- This file will need to be in every branch you want to run the action on.
- You can add additional branches if you so desire, but keep in mind that branches named anything other than `master` or `staging-deploy` will use the OpenFaaS deployment specified in the secrets marked as DEV.

## Usage
- To trigger the action, simply push to one of the branches listed in the workflow file.
- If you used folder structure #2, as described in the "Requirements" section above, the action will only look at the changes since the last commit to decide what files have changed and need re-deploying. So if you push multiple commits at once, the action will ignore all but the last commit. For this reason, squashing commits is recommended.
- If you add branches other than `master` and `staging-deploy` to the workflow file, the action will deploy changes on the additional branches to the environment based on the environment variables marked DEV.
