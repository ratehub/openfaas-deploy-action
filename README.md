# GitHub Action to Build, Push, and Deploy OpenFaaS Functions/Microservices

This action is designed to deploy functions or microservices developed with [OpenFaaS](https://www.openfaas.com).


## Requirements
1. Your repository must be organized in one of the following ways: 
   1. A single stack.yml file in the root (For a single microservice or a small number of functions)  
   ```
      your-repo/
        ├── your-first-group/
        │   ├── function-1/
        │   │   └── handler.js
        │   ├── function-2/
        │   │   └── handler.js
        │   └── function-3/
        │       └── handler.js
        └── your-second-group/
            ├── function-1/
            │   └── handler.js
            └── function-2/
                └── handler.js
   ```
   2. Functions grouped into related folders, each with their own stack.yml file (For repos with a large number of functions)  
