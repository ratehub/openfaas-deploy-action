# GitHub Action to Build, Push, and Deploy OpenFaaS Functions/Microservices

This action is designed to deploy functions or microservices developed with [OpenFaaS](https://www.openfaas.com).


## Requirements
1. Your repository must be organized in one of the following ways: 
   1. A single stack.yml file and dev-deploy/prod-deploy/staging-deploy.yml file in the function path for each function.
   ```
      your-repo/
        ├── function 1/
        │   └── handler.js
        │   └── dev-deploy.yml
        │   └── staging-deploy.yml
        │   └── prod-deploy.yml  
        ├── function 2/
        │   └── handler.js
        │   └── dev-deploy.yml
        │   └── staging-deploy.yml
        │   └── prod-deploy.yml        
        └── stack.yml
   ```
      This method will result in function being built, pushed, and deployed every time something changes in the function path. 
      
   2. Functions grouped into related folders, each with their own stack.yml file and dev-deploy/prod-deploy/staging-deploy.yml files (For repos with a large number of functions)  
   ```
      your-repo/
        ├── group-1/
        │   ├── function 1/
        │   │   └── handler.js
        │   │   └── dev-deploy.yml
        │   │   └── staging-deploy.yml
        │   │   └── prod-deploy.yml  
        │   ├── function 2/
        │   │   └── handler.js
        │   │   └── dev-deploy.yml
        │   │   └── staging-deploy.yml
        │   └── └── prod-deploy.yml        
        └── stack.yml
        └── group-2/
        │   ├── function 1/
        │   │   └── handler.js
        │   │   └── dev-deploy.yml
        │   │   └── staging-deploy.yml
        │   │   └── prod-deploy.yml  
        │   ├── function 2/
        │   │   └── handler.js
        │   │   └── dev-deploy.yml
        │   │   └── staging-deploy.yml
        │   └── └── prod-deploy.yml        
        └── stack.yml
            
   ```
      Function folder names must correspond exactly to the name of a function in the stack.yml in its group folder.
      In addition, this method will only build, push, and deploy based on which files changed in the last commit. So if any files changed in a given function's folder, that function will be deployed. 
      
      
# Usage
## Commit to any branch(dev) other than master
     1. If handler.js file is updated. 
           └── Triggers release.yml workflow, however doesn't create a release(as it is configured only for the master(default-channel) branch).
           └── FaaS build and push completes(overwrites the image in GCR if the tag(same as the version in package.json) already exists(basically image is pushed with the same tag)).
     2. If package.json is updated
          └── build_push.yml action is triggered, builds and pushes the function image with updated tag(version from package.json) 
     3. If the staging-deploy.yml/prod-deploy.yml is updated
          >> deploy.yml workflow is triggered. 
               1. if staging-deploy/prod-deploy.yml is updated with the new image tag.
                   └── The function with updated version is deployed to the STAGING/PROD environment respectively. 
               2. if staging-deploy/prod-deploy.yml is updated with only new env variables(image tag remains same)
                   └── Re-deploys the function with same tag but with updated env variables to DEV environment.
     4. dev-deploy.yml does not contain image properties, provision to update environment variables/secrets/labels/constraints.
     5. Updates to stack.yml does not trigger any actions, although updated configurations will be used the next time deploy action runs.
      
## Commit to master branch
##### If changes are made to one function specifically and are included in the PR, when merged
         1. Triggers release.yml action checks the function updated based on the path of the files changed
               └── if the commits merged includes(fix/feat/perf(BREAKING CHANGE)) prefixes a new release and tag is created
                      └── for "fix" prefix - `p` is updated in M.n.p
                      └── for "feat" prefix - `n` is updated in M.n.p
                      └── for "perf"(included with BREAKING CHANGE) prefix - `M` is updated in M.n.p
         2. Updates to a function when pushed to master
               └── Triggers auto-dev-deploy.yml action which auto-deploys updated function to DEV environment
         3. If package.json is updated
               └── build_push.yml action is triggered, builds and pushes the function image with updated tag.
         4. If the staging-deploy.yml/prod-deploy.yml is updated
              >> deploy.yml workflow is triggered. 
                   1. if staging-deploy/prod-deploy.yml is updated with the new image tag.
                       └── The function with updated version is deployed to the STAGING/PROD environment respectively. 
                   2. if staging-deploy/prod-deploy.yml is updated with only new env variables(image tag remains same)
                       └── Re-deploys the function with same tag but with updated env variables to DEV environment. 
         5. Update to dev-deploy.yml(environment variables/secrets/labels/constraints etc.)
              └── Triggers auto-dev-deploy.yml action, builds, pushes and automatically deploys to the DEV environment
         6. Updates to stack.yml does not trigger any actions, although updated configurations will be used the next time deploy action runs. 
          
## Scheduled Re-deploy function
##### If the cron schedule is triggered for the functions to re-deploy
         1. Triggers schedule.yml action which builds, pushes and deploys the functions(selected re-deploy functions) to PROD
         
## On Pull request to master branch
    1. Triggers status.yml action to run function build for all the updated functions for status check.
    
    