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
   
