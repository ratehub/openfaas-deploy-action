#!/bin/bash -l

set -eux

echo "--------- Starting function deployment process ---------"

# Get the branch name
BRANCH_NAME="$(echo "$GITHUB_REF" | awk -F"/" '{print $3}')"
GCR_ID="gcr.io/platform-235214/"
#Get the deploy files updated
COMMIT_PATH="$(git diff --name-only HEAD~1..HEAD "$GITHUB_SHA")"

if [[ $COMMIT_PATH == *"prod-deploy.yml"* ]] && [ -z "${TAG_OVERRIDE:-}" ];
then
   COMMIT_PATH="prod-deploy.yml"
   COMMITTED_FILES="prod-deploy.yml"
elif [[ $COMMIT_PATH == *"staging-deploy.yml"* ]] && [ -z "${TAG_OVERRIDE:-}" ];
then
   COMMIT_PATH="staging-deploy.yml"
   COMMITTED_FILES="staging-deploy.yml"
else
   COMMIT_PATH="dev-deploy.yml"
   COMMITTED_FILES="dev-deploy.yml"
fi


# Depending on the deploy file we want to choose a different set of environment variables and credentials
if [ "$COMMITTED_FILES" == 'prod-deploy.yml' ] || [ "$COMMIT_PATH" == 'prod-deploy.yml' ];
then
    FAAS_GATEWAY="${GATEWAY_URL_PROD}"
    FAAS_USER="${GATEWAY_USERNAME_PROD}"
    FAAS_PASS="${GATEWAY_PASSWORD_PROD}"
    ENV_FILE="env-prod.yml"
    COMMITTED_FILES="prod-deploy.yml"
    
elif [ "$COMMITTED_FILES" == 'staging-deploy.yml' ] ||[ "$COMMIT_PATH" == 'staging-deploy.yml' ];
then
    FAAS_GATEWAY="${GATEWAY_URL_STAGING}"
    FAAS_USER="${GATEWAY_USERNAME_STAGING}"
    FAAS_PASS="${GATEWAY_PASSWORD_STAGING}"
    ENV_FILE="env-staging.yml"
    COMMITTED_FILES="staging-deploy.yml"

#$COMMIT_PATH is a deploy file updated when the deploy action is triggered by the functions from a repo different than faas
elif [ "$COMMITTED_FILES" == 'dev-deploy.yml' ] || [ "$COMMIT_PATH" == 'dev-deploy.yml' ] || [ -n "${TAG_OVERRIDE:-}" ];
then
    COMMITTED_FILES="dev-deploy.yml"
    COMMIT_PATH='dev-deploy.yml'
    FAAS_GATEWAY="${GATEWAY_URL_DEV}"
    FAAS_USER="${GATEWAY_USERNAME_DEV}"
    FAAS_PASS="${GATEWAY_PASSWORD_DEV}"
    ENV_FILE="env-dev.yml"
fi

faas-cli template pull

if [ -n "${CUSTOM_TEMPLATE_URL:-}" ];
then
    faas-cli template pull "${CUSTOM_TEMPLATE_URL}"
fi

faas-cli login --username="$FAAS_USER" --password="$FAAS_PASS" --gateway="$FAAS_GATEWAY"

# If there's a stack file in the root of the repo, assume we want to deploy everything
if [ -f "$GITHUB_WORKSPACE/stack.yml" ];
then
    cp "$ENV_FILE" env.yml
    if [ -z "${TAG_OVERRIDE:-}" ];
    then
        FUNCTION_NAME="$(cat package.json | grep name | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')"
        if [[ "$FUNCTION_NAME" == *"front-end"* ]];
        then
            TEMPLATE=$(yq r stack.yml functions.frontend-export)
            FUNCTIONS=$(yq r $COMMIT_PATH)
            while IFS= read -r line
            do
               echo "$line" >> template.yml
            done < <(printf '%s\n' "$TEMPLATE")
            TEMPLATE_FILE="template.yml"

            while IFS= read -r line
            do
               echo "$line" >> functions.txt
            done < <(printf '%s\n' "$FUNCTIONS")

            tt=$(awk '/frontend-export-*/' functions.txt)
            echo $tt | tr -d ":"| tr "\ " \\n | awk '{print $1}'> new_functions.yml

            FUNCTIONS_FILE="new_functions.yml"
            while IFS= read -r line
            do
              yq p $TEMPLATE_FILE $line >> updated_deploy.yml
            done < $FUNCTIONS_FILE

            yq merge -i updated_deploy.yml $COMMIT_PATH

            while IFS= read -r line
            do
              IMAGE_TAG=$(yq r "$COMMIT_PATH" "$line".image)
              echo $IMAGE_TAG
              yq w -i updated_deploy.yml "$line".image. "$GCR_ID""$IMAGE_TAG"
            done <  new_functions.yml
            yq p -i updated_deploy.yml "functions"
            yq merge -i stack.yml updated_deploy.yml
            yq d -i stack.yml functions.frontend-export
        else
            yq p -i "$COMMIT_PATH" "functions"."$FUNCTION_NAME"
            IMAGE_TAG=$(yq r "$COMMIT_PATH" functions."$FUNCTION_NAME".image)
            yq w -i "$COMMIT_PATH" functions."$FUNCTION_NAME".image "$GCR_ID""$IMAGE_TAG"
        fi
    else
        #Get the function name from the package file
        FUNCTION_NAME="$(cat package.json | grep name | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')"
        if [[ "$FUNCTION_NAME" == *"front-end"* ]];
        then
            TEMPLATE=$(yq r stack.yml functions.frontend-export)
            FUNCTIONS=$(yq r $COMMIT_PATH)
            while IFS= read -r line
            do
               echo "$line" >> template.yml
            done < <(printf '%s\n' "$TEMPLATE")
            TEMPLATE_FILE="template.yml"

            while IFS= read -r line
            do
               echo "$line" >> functions.txt
            done < <(printf '%s\n' "$FUNCTIONS")

            tt=$(awk '/frontend-export-*/' functions.txt)
            echo $tt | tr -d ":"| tr "\ " \\n | awk '{print $1}'> new_functions.yml

            FUNCTIONS_FILE="new_functions.yml"
            while IFS= read -r line
            do
              yq p $TEMPLATE_FILE $line >> updated_deploy.yml
            done < $FUNCTIONS_FILE

            yq merge -i updated_deploy.yml $COMMIT_PATH

            while IFS= read -r line
            do
              IMAGE_TAG=$(yq r stack.yml functions.frontend-export.image)
              yq w -i updated_deploy.yml "$line".image "$IMAGE_TAG"
            done < new_functions.yml
            yq p -i updated_deploy.yml "functions"
            yq merge -i stack.yml updated_deploy.yml
            yq d -i stack.yml functions.frontend-export

        else
            #Add prefix to the deploy file
            yq p -i "$COMMIT_PATH" "functions"."$FUNCTION_NAME"
            #Update the image properties in the deploy file
            yq w -i "$COMMIT_PATH" functions."$FUNCTION_NAME".image "$GCR_ID""$FUNCTION_NAME":"${TAG_OVERRIDE}"
        fi
        yq merge -i "$COMMIT_PATH" stack.yml
        cp -f "$COMMIT_PATH" stack.yml
    fi
    # Merge the deploy file into stack file
    if [ "$GITHUB_EVENT_NAME" == "push" ];
    then
        faas-cli deploy --gateway="$FAAS_GATEWAY"
    fi
else

      GROUP_PATH=""
      GROUP_PATH2=""
      FUNCTION_PATH2=""

      git diff HEAD HEAD~1 --name-only > differences.txt

      while IFS= read -r line; do
          #If changes are in root, we can ignore them
          if [[ "$line" =~ "/" ]];
          then
              GROUP_PATH="$(echo "$line" | awk -F"/" '{print $1}')"
              #Ignore changes if the folder is prefixed with a "." or "_"
              if [[ ! "$GROUP_PATH" =~ ^[\._] ]];
              then
                  if [ "$GROUP_PATH" != "$GROUP_PATH2" ];
                  then
                      GROUP_PATH2="$GROUP_PATH"
                      cd "$GITHUB_WORKSPACE/$GROUP_PATH"
                      cp "$GITHUB_WORKSPACE/template" -r template
                      cp "$ENV_FILE" env.yml
                  fi

                  FUNCTION_PATH="$(echo "$line" | awk -F"/" '{print $2}')"
                  if [ -d "$FUNCTION_PATH" ];
                  then
                      #If we already handled this function based on a prior file, we can ignore it this time around
                      if [ "$FUNCTION_PATH" != "$FUNCTION_PATH2" ];
                      then
                          if [ -z "${TAG_OVERRIDE:-}" ] && [ "$COMMITTED_FILES" != "dev-deploy.yml" ];
                          then
                              yq p -i "$FUNCTION_PATH/$COMMITTED_FILES" "functions"."$FUNCTION_PATH"
                              # Get the updated image tag if the tag is not latest
                              IMAGE_TAG=$(yq r "$FUNCTION_PATH/$COMMITTED_FILES" functions."$FUNCTION_PATH".image)
                              yq w -i "$FUNCTION_PATH/$COMMITTED_FILES" functions."$FUNCTION_PATH".image "$GCR_ID""$IMAGE_TAG"
                              

                          else
                              #Add prefix to the deploy file
                              yq p -i "$FUNCTION_PATH/$COMMITTED_FILES" "functions"."$FUNCTION_PATH"
                              #Update the image properties in the deploy file
                              yq w -i "$FUNCTION_PATH/$COMMITTED_FILES" functions."$FUNCTION_PATH".image "$GCR_ID""$FUNCTION_PATH":"${TAG_OVERRIDE}"
                              CONSTRAINTS=$(yq r "$FUNCTION_PATH/$COMMITTED_FILES" constraints)
                              if [ -z "$CONSTRAINTS" ];
                              then
                                yq w -i "$FUNCTION_PATH/$COMMITTED_FILES" "functions."$FUNCTION_PATH".constraints.[+]" "doks.digitalocean.com/node-pool=platform"
                              else
                                echo "### Constraints Already specified ###"
                              fi
                              cat "$FUNCTION_PATH/$COMMITTED_FILES"

                          fi
                          yq merge -i "$FUNCTION_PATH/$COMMITTED_FILES" stack.yml
                          cp -f "$FUNCTION_PATH/$COMMITTED_FILES" stack.yml
                          # Deploy all the functions whose deploy files are updated
                          if [ "$GITHUB_EVENT_NAME" == "push" ];
                          then
                              faas-cli deploy --gateway="$FAAS_GATEWAY" --filter="$FUNCTION_PATH"
                          fi
                          FUNCTION_PATH2="$FUNCTION_PATH"
                      fi
                  fi
              fi
          fi
      done < differences.txt
fi

if [ "$GITHUB_EVENT_NAME" == "push" ];
then
    # Query gateway action so that functions are added to gateway
    if [ -n "${API_GATEWAY_AUTH_TOKEN_PROD:-}" ] && [ "$BRANCH_NAME" == "master" ] && [ "$COMMITTED_FILES" == 'prod-deploy.yml' ];
    then
        curl -H "Authorization: token ${API_GATEWAY_AUTH_TOKEN_PROD}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config/dispatches
    elif [ -n "${API_GATEWAY_AUTH_TOKEN_STAGING:-}" ] && [ "$COMMITTED_FILES" == 'staging-deploy.yml' ];
    then
       curl -H "Authorization: token ${API_GATEWAY_AUTH_TOKEN_STAGING}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config-staging/dispatches
    elif [ -n "${API_GATEWAY_AUTH_TOKEN_DEV:-}" ] && [ -n "${TAG_OVERRIDE:-}" ] || [ "$COMMITTED_FILES" == 'dev-deploy.yml' ];
    then
       curl -H "Authorization: token ${API_GATEWAY_AUTH_TOKEN_DEV}" -d '{"event_type":"repository_dispatch"}' https://api.github.com/repos/ratehub/gateway-config-dev/dispatches
    fi

fi

echo "---------- Deployment finished-----------"
