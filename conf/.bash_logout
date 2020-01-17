#!/usr/bin/env bash

# clean history at exit by removing useless commands

# save current history
history -n

# do not store some simple commands
tempHistory=$(mktemp)
trap "rm -f ${tempHistory}" EXIT
history | sort -k2 -k1nr | uniq -f1 | sort -n | cut -c8- | grep -v -E "^ls|^ll|^pwd |^ |^exit|^mc$|^su$|^df|^clear|^ps|^history|^env|^#|^vi|^exit" > "${tempHistory}"

# clear history
history -c

# load cleaned history temp file
history -r "${tempHistory}"

# write history
history -w
