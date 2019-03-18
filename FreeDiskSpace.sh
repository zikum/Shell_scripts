#!/bin/bash
# Check for free space in all logging FS.
# When free space drops below set threshold it deletes all defined files in given paths
# v1.0 - Final basic version

# Set treshold in %
TRESHOLD=40
# Dir with log files
DIRLOG=/application/
#Files to delete
FILES=*.gz


# Watch all logging FS for threshold. If its okay, then just do nothing and exit... Else, parse them and CLEAN them!
FILESYSTEMS=$(df -P 2> /dev/null |grep log |awk '0+$5 >= '$TRESHOLD' {print}' |awk '{ print $6 }')

if [ "$FILESYSTEMS" = "" ]; then
    echo "No FS met treshold - All okay exiting...";

exit 1;

else

# Save results, add app log dir and file extension
FSOVERTRESHOLD=$FILESYSTEMS

FILESTODELETE=$(while read -r line; do
	    		echo "$line$DIRLOG"
		done <<< "$FSOVERTRESHOLD")


# CLEAN files!
	while read -r file; do
			echo deleting files: $FILES from: "$file"
			find "$file" -name $FILES -type f -delete
		done <<< "$FILESTODELETE"

fi
