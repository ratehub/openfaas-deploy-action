#!/bin/bash -l

set -eu

# $1 stack-file
# $2 force
# $3 used-by

# List for files updated
git diff HEAD HEAD~1 --name-only > differences.txt
cat differences.txt

# Read and list all handlers from stack.yml to all-handlers.txt
# Args: 1. file path to store results 2. stack file path
node /action-helper-workspace/list-handler-paths.js all-handlers.txt $1
ALL_HANDLERS=$(cat all-handlers.txt)

echo "Used by: $3"

echo "All handlers: $ALL_HANDLERS"

# List of handlers to act upon
touch handler-list.txt

if [ -n "$2" ]; then
    handlers=""
    if [[ $2 == "*" ]]; then
        IFS=', ' read -r -a handlers <<< "$ALL_HANDLERS"
    else
        handlers=($2)
    fi

    for handler in "${handlers[@]}"
    do
        echo $handler >> handler-list.txt
    done
else
    while IFS= read -r line; do
        # Ignore changes if the file is prefixed with a "." or "_"
        if [[ ! "$line" =~ ^[\._] && ! ("$3" == "build-push" && "$line" =~ .*-deploy.yml) ]]; then
            if [[ ! "$line" =~ "/" ]]; then
                echo "case 1"
                echo "STACK_HANDLERS" >> handler-list.txt
                break
            else
                SUB_DIR="$(echo "$line" | awk -F"/" '{print $1}')"
                # Changes are in `sub-dir` and not already added to deploy list
                if [[ $(grep -F -w "./$SUB_DIR" all-handlers.txt) && $(grep -F -L "$SUB_DIR" handler-list.txt) ]]; then
                    echo "case 2a"
                    echo "./$SUB_DIR" >> handler-list.txt
                elif [[ $(grep -F -L "./$SUB_DIR" all-handlers.txt) ]]; then
                    echo "case 2b"
                    echo "STACK_HANDLERS" >> handler-list.txt
                    break
                fi
            fi
        fi
    done < differences.txt
fi

cat handler-list.txt

# force all case
if [[ $(grep -F -w "STACK_HANDLERS" handler-list.txt) ]]; then
    rm handler-list.txt
    touch handler-list.txt 
    handlerArray=""
    IFS=', ' read -r -a handlerArray <<< "$ALL_HANDLERS"
    for handler in "${handlerArray[@]}"
    do
        echo $handler >> handler-list.txt
    done
fi

# map each handler to corresponding function name
FUNCTIONS=""
while IFS= read -r line; do
    if [[ $line == "." ]]; then
        FUNCTIONS="$FUNCTIONS \"$line\","
    else
        funcName=$(echo $line | sed "s/.\//""/g")
        FUNCTIONS="$FUNCTIONS \"$funcName\","
    fi
done < handler-list.txt

# Trim ',' from the end
if [ ${#FUNCTIONS} -ge 1 ]; then
FUNCTIONS=${FUNCTIONS::-1}
fi
# Add '[' and ']' at start and end respectively
FUNCTIONS="[$FUNCTIONS]"

if [[ "$FUNCTIONS" == "[]" ]]; then
    FUNCTIONS="[\"nothing\"]"
fi

echo "Output: $FUNCTIONS"
echo ::set-output name=function-list::$FUNCTIONS
