#!/bin/bash -l

set -eu

# $1 stack-file
# $2 force
# $3 caller

# List for files updated
git diff HEAD HEAD~1 --name-only > all-differences.txt
echo "all differences:"
cat all-differences.txt

FUNCTION_DETAILS=""
IFS=', ' read -r -a stack_files <<< $1
for stack in "${stack_files[@]}"
do
    echo "Processing: $stack"

    GROUP_PATH="."
    if [[ "$stack" =~ "/" ]]; then
        echo "stack file contains group path"
        GROUP_PATH="$(echo "$stack" | awk -F"/" '{print $1}')"
        sed "/^\<$GROUP_PATH\>\//!d" all-differences.txt > filtered-differences.txt
    else
        cp all-differences.txt filtered-differences.txt
    fi
    echo "group-path: $GROUP_PATH"

    echo "differences file after filter:"
    cat filtered-differences.txt

    # Read and list all handlers from stack.yml to all-handlers.txt
    # Args: 1. file path to store results 2. stack file path
    node /action-helper-workspace/list-handler-paths.js all-handlers.txt $stack
    ALL_HANDLERS=$(cat all-handlers.txt)

    echo "All handlers in the given stack: $ALL_HANDLERS"

    # List of handlers
    if [ -f handler-list.txt ]; then
        rm handler-list.txt
    fi
    touch handler-list.txt

    if [ -n "$2" ]; then
        handlers=""
        if [[ $2 == "*" ]]; then
            echo "Force all case"
            IFS=', ' read -r -a handlers <<< "$ALL_HANDLERS"
        else
            echo "Force $2 case"
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
                    if [[ $GROUP_PATH == $SUB_DIR_1 ]]; then
                        FUNCTION_PATH=$SUB_DIR_2
                    else
                        FUNCTION_PATH=$SUB_DIR_1
                    fi
                    echo "Function path: $FUNCTION_PATH"

                    # Changes are in `sub-dir` and not already added to deploy list
                    if [[ $(grep -F -w "./$FUNCTION_PATH" all-handlers.txt) && $(grep -L -w "^./$FUNCTION_PATH$" handler-list.txt) ]]; then
                        echo "case 2a - changes to directory or file specific to a faas-function"
                        echo "./$FUNCTION_PATH" >> handler-list.txt
                    elif [[ $(grep -F -L "./$FUNCTION_PATH" all-handlers.txt) ]]; then
                        echo "case 2b - changes to directory or file common to all stack functions"
                        echo "STACK_HANDLERS" >> handler-list.txt
                        break
                    else
                        echo "Nothing added for $FUNCTION_PATH"
                    fi
                fi
            fi
        done < filtered-differences.txt

        echo "Handlers added after diff analysis:"
        cat handler-list.txt
    fi


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
    while IFS= read -r line; do
        if [[ $line == "." ]]; then
            FUNCTION_DETAILS="$FUNCTION_DETAILS {\"function-name\": \"$line\", \"function-group\": \"$GROUP_PATH\"},"
        else
            funcName=$(echo $line | sed "s/.\//""/g")
            FUNCTION_DETAILS="$FUNCTION_DETAILS {\"function-name\": \"$funcName\", \"function-group\": \"$GROUP_PATH\"},"
        fi
    done < handler-list.txt

    echo "Addition to output list: $FUNCTION_DETAILS"

done

# Trim ',' from the end
if [ ${#FUNCTION_DETAILS} -ge 1 ]; then
    FUNCTION_DETAILS=${FUNCTION_DETAILS::-1}
    FUNCTION_DETAILS="{\"include\":[$FUNCTION_DETAILS]}"
else
    FUNCTION_DETAILS="{\"include\":[{\"function-name\": \"none\", \"function-group\": \"none\"}]}"
fi

echo "Final output: $FUNCTION_DETAILS"

echo ::set-output name=function-details::$FUNCTION_DETAILS
