#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "No arguments provided"
    echo "Usage: wgcg username1 [username2 ... usernameN]"
    exit 1
fi

# Check for ipspace.txt and read values
if [ ! -f "/etc/wireguard/ipspace.txt" ]; then
    echo "/etc/wireguard/ipspace.txt not found"
    exit 1
fi

allowed_ips=$(sed -n '1p' /etc/wireguard/ipspace.txt)
endpoint=$(sed -n '2p' /etc/wireguard/ipspace.txt)

# Find the subnet details from wg0.conf
subnet=$(sed -n '2p' /etc/wireguard/wg0.conf | awk '{print $3}')
subnet_ip=$(echo $subnet | cut -d/ -f1)
subnet_mask=$(echo $subnet | cut -d/ -f2)

# Generate a list of all possible IPs in the subnet
IFS=. read -r i1 i2 i3 i4 <<< "$subnet_ip"
ip_range=($(seq 1 254))

# Loop through each provided username
for username in "$@"; do

    # Check for duplicate username in /etc/wireguard/wg0.conf
    if grep -A 1 "\[Peer\]" /etc/wireguard/wg0.conf | grep -q "#$username"; then
        echo "Duplicate username: $username"
        continue
    fi

    # Find an unused IP in the subnet
    unused_ip=""
    for ip in "${ip_range[@]}"; do
        if ! grep -q "$i1.$i2.$i3.$ip/32" /etc/wireguard/wg0.conf; then
            unused_ip="$i1.$i2.$i3.$ip"
            break
        fi
    done

    if [ -z "$unused_ip" ]; then
        echo "No unused IP found in the subnet for $username"
        continue
    fi

    client_ip=$unused_ip

    # Set umask to ensure the below files are r/w only by current user
    umask 077

    # Generate keys and store them
    wg genkey > /etc/wireguard/clients/$username.key
    wg pubkey < /etc/wireguard/clients/$username.key > /etc/wireguard/clients/$username.pub

    private_key=$(cat /etc/wireguard/clients/$username.key)
    public_key=$(cat /etc/wireguard/clients/$username.pub)

    # Append new peer to wg0.conf
    {
        echo ""
        echo "[Peer]"
        echo "#$username"
        echo "PublicKey = $public_key"
        echo "AllowedIPs = $client_ip/32"
    } >> /etc/wireguard/wg0.conf

    # Create certs folder
    certs_folder="/etc/wireguard/certs"
    [ ! -d "$certs_folder" ] && mkdir "$certs_folder"

    # Generate .conf file
    conf_file="$certs_folder/$username.conf"
    {
        echo "[Interface]"
        echo "PrivateKey = $private_key"
        echo "Address = $client_ip/32"
        echo "ListenPort = 51820"
        echo ""
        echo "[Peer]"
        echo "PublicKey = $(cat /etc/wireguard/server.pub)"
        echo "AllowedIPs = $allowed_ips"
        echo "Endpoint = $endpoint"
        echo "PersistentKeepalive = 21"
    } > "$conf_file"
    echo "--------------------------------------------------"
    echo "$username.conf created in /etc/wireguard/certs folder."
    echo "--------------------------------------------------"
done

# Ask to restart Wireguard service
echo "Would you like to restart the Wireguard service & apply new config?"
echo "Warning: This will cause an outage for current users."
read -rp "(y/n): " restart
if [[ "$restart" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    wg-quick down wg0 > /dev/null 2>&1
    sleep 1
    wg-quick up wg0 > /dev/null 2>&1
fi

exit 0
