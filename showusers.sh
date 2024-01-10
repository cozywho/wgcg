#!/bin/bash

# Directory containing Wireguard client config files
WG_DIR="/etc/wireguard/clients"

# Run wg command and save output
WG_OUTPUT=$(wg)

# Get all unique peer keys from the output
PEER_KEYS=$(echo "$WG_OUTPUT" | grep -oP 'peer: \K.*' | sort -u)

# For each unique peer key, find the file it's located in
for PEER_KEY in $PEER_KEYS
do
    # Find the file that contains the peer key
    FILE_NAME=$(grep -l $PEER_KEY $WG_DIR/*)
    
    # If the file was found, replace the key with the filename in the output
    if [ -n "$FILE_NAME" ]
    then
        WG_OUTPUT=$(echo "$WG_OUTPUT" | sed "s/$PEER_KEY/$(basename $FILE_NAME)/g")
    fi
done

# Print the modified output
echo "$WG_OUTPUT"
