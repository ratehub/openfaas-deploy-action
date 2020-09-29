#!/bin/bash -l

set -eu

#  $1 stack-file
#  $2 force-deploy-functions

# List for files updated
git diff HEAD HEAD~1 --name-only > differences.txt

echo "differences.txt file:"
cat differences.txt
echo ""

# Read and list all handlers from stack.yml to handlers.txt
# Args:
# file path to store results
# stack file path
node /action-helper-workspace/list-handler-paths.js handlers.txt $1

echo "handlers.txt file:"
cat handlers.txt
echo ""
echo ""

# List for functions to deploy
touch functions-to-deploy.txt

if [ -n "$2" ];
then
    forceDeployFuncs=""
    if [[ $2 == "*" ]];
    then
        echo "force deploy all"
        echo ""
        allFunctions=$(cat handlers.txt)
        IFS=', ' read -r -a forceDeployFuncs <<< "$allFunctions"
    else
        echo "force deploy $2"
        echo ""
        forceDeployFuncs=($2)
    fi

    for func in "${forceDeployFuncs[@]}"
    do
        echo "force deploy $func"
        echo ""
        echo $func >> functions-to-deploy.txt
    done
else
    while IFS= read -r line; do
        # Ignore changes if the folder is prefixed with a "." or "_"
        if [[ ! "$line" =~ ^[\._] ]];
        then
            # Changes to global settings
            if [[ "$line" == "stack.yml" || "$line" =~ "global-*" ]];
            then
                echo "DEPLOY_EVERYTHING" >> functions-to-deploy.txt
                break
            # Changes are in root and not already added to deploy list
            elif [[ ! "$line" =~ "/" && $(grep -F -L "." functions-to-deploy.txt) ]];
            then
                echo "." >> functions-to-deploy.txt
            else
                SUB_DIR="$(echo "$line" | awk -F"/" '{print $1}')"
                # Changes are in `sub-dir` and not already added to deploy list
                if [[ $(grep -F -w "./$SUB_DIR" handlers.txt) && $(grep -F -L "$SUB_DIR" functions-to-deploy.txt) ]];
                then
                    echo "./$SUB_DIR" >> functions-to-deploy.txt
                # Changes in some sub dir which is not a separate function
                elif [[ $(grep -F -L "./$SUB_DIR" handlers.txt) && $(grep -F -L "." functions-to-deploy.txt) ]];
                then
                    echo "." >> functions-to-deploy.txt
                fi
            fi
        fi
    done < differences.txt
fi

echo "functions-to-deploy.txt file:"
cat functions-to-deploy.txt
echo ""

if [[ $(grep -F -w "DEPLOY_EVERYTHING" functions-to-deploy.txt) ]];
then
    echo "DEPLOY_EVERYTHING in functions-to-deploy.txt"
    rm functions-to-deploy.txt
    touch functions-to-deploy.txt 
    allFunctions=$(cat handlers.txt)
    forceDeployFuncs=""
    IFS=', ' read -r -a forceDeployFuncs <<< "$allFunctions"
    for func in "${forceDeployFuncs[@]}"
    do
        echo $func >> functions-to-deploy.txt
    done
fi

echo "AFTER functions-to-deploy.txt file:"
cat functions-to-deploy.txt
echo ""
echo ""


FUNCTIONS_TO_DEPLOY=""
while IFS= read -r line; do
    if [[ $line == "." ]];
    then
        FUNCTIONS_TO_DEPLOY="$FUNCTIONS_TO_DEPLOY \"$line\","
    else
        functionName=$(echo $line | sed "s/.\//""/g")
        echo "updated function name: $functionName"
        FUNCTIONS_TO_DEPLOY="$FUNCTIONS_TO_DEPLOY \"$functionName\","
    fi
done < functions-to-deploy.txt

FUNCTIONS_TO_DEPLOY=${FUNCTIONS_TO_DEPLOY::-1}
FUNCTIONS_TO_DEPLOY="[$FUNCTIONS_TO_DEPLOY]"

echo "FUNCTIONS_TO_DEPLOY:"
echo $FUNCTIONS_TO_DEPLOY

echo ::set-output name=functions-to-deploy::$FUNCTIONS_TO_DEPLOY
