#!/bin/bash
# Check for free space in defined FS.
# When free space drops below set threshold it deletes all *.gz files in given paths
# v0.1 - initial draft

# FS to watch
FILESYSTEM=/dev/sda1
# Capacity threshold in %
CAPACITY=95
# Dirs to be cleaned
/srv/log/<env>/mep/*/application/


files:  .gz .json .log


for i in $(find /srv/log -type d -name "fed" 2>/dev/null | awk -F/ '{print $4}'); do echo "${i} environment"; done





