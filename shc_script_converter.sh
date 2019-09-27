#!/bin/bash

## Script to convert the base lab scripts to binaries

SHC_STATUS=$(which shc > /dev/null; echo $?)
if [ $SHC_STATUS -ne 0 ]
then
    echo -e "\nError: missing shc binary...\n"
    exit 4
fi

L200LABS_SCRIPTS="$(ls ./l200labs_scripts/)"
if [ -z "$L200LABS_SCRIPTS" ]
then
    echo -e "Error: missing l200labs scripts...\n"
    exit 5
fi

function convert_to_binary() {
    SCRIPT_NAME="$1"
    BINARY_NAME="$(echo "$SCRIPT_NAME" | sed 's/.sh//')"
    shc -f ./l200labs_scripts/${SCRIPT_NAME} -r -o ./l200labs_binaries/${BINARY_NAME}
    rm -f ./l200labs_scripts/${SCRIPT_NAME}.x.c > /dev/null 2>&1
}

for FILE in $(echo "$L200LABS_SCRIPTS")
do
    convert_to_binary $FILE
done

exit 0
