#!/bin/sh

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Error: Two arguments required. Usage: ./finder.sh <directory-path> <search-string>"
    exit 1
fi

# Assign arguments to variables
filesdir=$1
searchstr=$2

# Check if the directory exists
if [ ! -d "$filesdir" ]; then
    echo "Error: Directory path '$filesdir' does not exist or is not a directory."
    exit 1
fi

# Find the number of files in the directory and subdirectories
num_files=$(find "$filesdir" -type f | wc -l)

# Find the number of matching lines for the search string
num_matches=$(grep -r "$searchstr" "$filesdir" 2>/dev/null | wc -l)

# Print the results
echo "The number of files are $num_files and the number of matching lines are $num_matches"
