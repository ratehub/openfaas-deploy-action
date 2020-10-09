#!/bin/bash -l

set -eu

# $1 stack-file
# $2 force
# $3 used-by

ls -la

echo "Stack file: $1"

# List for files updated
git diff HEAD HEAD~1 --name-only > differences.txt
cat differences.txt

GROUP_PATH="."
if [[ "$1" =~ "/" ]]; then
    echo "stack file contains group path"
    GROUP_PATH="$(echo "$1" | awk -F"/" '{print $1}')"
    sed -i '/\<$GROUP_PATH\>/!d' differences.txt
fi

echo "differences file after filter:"
cat differences.txt

# Read and list all handlers from stack.yml to all-handlers.txt
# Args: 1. file path to store results 2. stack file path
node /action-helper-workspace/list-handler-paths.js all-handlers.txt $1
ALL_HANDLERS=$(cat all-handlers.txt)

echo "Used by: $3"

echo "All handlers in the given stack: $ALL_HANDLERS"

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
                echo "case 1 - changes at root of repo"
                echo "STACK_HANDLERS" >> handler-list.txt
                break
            else
                SUB_DIR_1="$(echo "$line" | awk -F"/" '{print $1}')"
                SUB_DIR_2="$(echo "$line" | awk -F"/" '{print $2}')"
                echo "first sub-dir 1: $SUB_DIR_1"
                echo "first sub-dir 2: $SUB_DIR_2"

                FUNCTION_PATH=""
                if [[ $(grep -F -w "./$SUB_DIR_2" all-handlers.txt) ]]; then
                    FUNCTION_PATH=$SUB_DIR_2
                else
                    FUNCTION_PATH=$SUB_DIR_1
                fi
                echo "Function path: $FUNCTION_PATH"

                # Changes are in `sub-dir` and not already added to deploy list
                if [[ $(grep -F -w "./$FUNCTION_PATH" all-handlers.txt) && $(grep -F -L "$FUNCTION_PATH" handler-list.txt) ]]; then
                    echo "case 2a - changes to directory or file specific to a faas-function"
                    echo "./$FUNCTION_PATH" >> handler-list.txt
                elif [[ $(grep -F -L "./$FUNCTION_PATH" all-handlers.txt) ]]; then
                    echo "case 2b - changes to directory or file common to all stack functions"
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
echo ::set-output name=group::$GROUP_PATH
