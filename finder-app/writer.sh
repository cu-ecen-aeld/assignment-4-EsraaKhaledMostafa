#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Error: Two arguments required. Usage: ./writer.sh <file-path> <write-string>"
    exit 1
fi

# Assign arguments to variables
writefile=$1
writestr=$2

# Create the directory path if it doesn't exist
mkdir -p "$(dirname "$writefile")"

# Write the string to the file, overwriting if it exists
echo "$writestr" > "$writefile"
if [ $? -ne 0 ]; then
    echo "Error: File could not be created."
    exit 1
fi

