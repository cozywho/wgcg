#!/bin/bash

echo "------------------------"
echo "Wireguard Cert Generator"
echo "------------------------"
sleep 2
# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "Please run as root..."
   exit 1
fi

# Store values from ipspace.txt.file
while true; do
  ipspace_file="ipspace.txt"
  if [ -f "$ipspace_file" ]; then
    readarray -t lines < "$ipspace_file"
    allowed_ips="${lines[0]}"
    endpoint="${lines[1]}"
    break
  else
    echo "---------------------------"
    echo "ipspace.txt file not found!"
    echo "---------------------------"
    read -p "Try again? (y/n): " retry
    if [[ "$retry" =~ ^([nN][oO]|[nN])$ ]]; then
      exit 1
    fi
  fi
done

while true; do
  echo "Please enter desired username:"
  read username
  sleep 2
  # Check for any non-alphanumeric characters
  if [[ "$username" =~ [^a-zA-Z0-9] ]]; then
    echo "Username should be alphanumeric (no special characters or spaces), please try again..."
    continue
  fi
  # Check for duplicate username
  if grep -q "$username" /etc/wireguard/wg0.conf; then
    echo "Duplicate username, please try again..."
    sleep 2
  else
    break
  fi
done

while true; do
  # Print server user pool & request input
  server_user_pool=$(sed -n '2p' /etc/wireguard/wg0.conf | cut -c11- | cut -d '/' -f1)
  echo "-------------------------------"
  echo "This server's IP address is $server_user_pool"
  echo "Please enter desired client IP:"
  echo "-------------------------------"
  read client_ip
  sleep 2
  
  # Validate IP address
  if [[ $client_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    IFS='.' read -ra ADDR <<< "$client_ip"
    IFS='.' read -ra SRVR <<< "$server_user_pool"
    
    # Compare the first 3 octets of client & server IP
    if [[ ${ADDR[0]} -eq ${SRVR[0]} && ${ADDR[1]} -eq ${SRVR[1]} && ${ADDR[2]} -eq ${SRVR[2]} ]]; then
      # Check if the last octet is less than or equal to 253
      if [[ ${ADDR[3]} -gt 253 ]]; then
        echo "The last octet of the IP address should be 253 or less, please try again..."
      else
        # Check for duplicate client IP
        if grep -q "$client_ip" /etc/wireguard/wg0.conf; then
          echo "Duplicate client IP, please try again..."
        else
          break
        fi
      fi
    else
      echo "The IP address is not in the server's subnet, please try again..."
    fi
  else
    echo "Invalid IP address, please try again..."
  fi
done

# Set umask to ensure the below files are r/w only by current user
umask 077

# Generate client private key and store it
wg genkey > /etc/wireguard/clients/$username.key

# Generate client public key and store it
wg pubkey < /etc/wireguard/clients/$username.key > /etc/wireguard/clients/$username.pub

# Store the values of .key and .pub files
private_key=$(cat /etc/wireguard/clients/$username.key)
public_key=$(cat /etc/wireguard/clients/$username.pub)

# Append new information to wg0.conf
echo "" >> /etc/wireguard/wg0.conf
echo "[Peer]" >> /etc/wireguard/wg0.conf
echo "#$username" >> /etc/wireguard/wg0.conf
echo "PublicKey = $public_key" >> /etc/wireguard/wg0.conf
echo "AllowedIPs = $client_ip/32" >> /etc/wireguard/wg0.conf

# Create /etc/wireguard/certs folder if it doesn't exist
certs_folder="/etc/wireguard/certs"
if [ ! -d "$certs_folder" ]; then
  mkdir "$certs_folder"
fi

# Generate .conf file
conf_file="$certs_folder/$username.conf"
echo "[Interface]" > "$conf_file"
echo "PrivateKey = $private_key" >> "$conf_file"
echo "Address = $client_ip/32" >> "$conf_file"
echo "ListenPort = 51820" >> "$conf_file"
echo "" >> "$conf_file"
echo "[Peer]" >> "$conf_file"
echo "PublicKey = $(cat /etc/wireguard/server.pub)" >> "$conf_file"
echo "AllowedIPs = $allowed_ips" >> "$conf_file"
echo "Endpoint = $endpoint" >> "$conf_file"
echo "PersistentKeepalive = 21" >> "$conf_file"

# After generating the .conf file, change its ownership to all users
#chown :users "$conf_file"
#chmod 664 "$conf_file"  # Gives read/write permission to owner and group, and read permission to others

# Ask the user if they want to restart the Wireguard service
echo "-------------------------------"
echo "Would you like to restart the Wireguard service & push the new configuration?"
echo "WARNING: This will cause an outage for current connected users."
read -p "(y/n): " restart
if [[ "$restart" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  wg-quick down wg0 > /dev/null 2>&1
  sleep 5
  wg-quick up wg0 > /dev/null 2>&1
fi


# Notify the user of the new .conf file's location
echo "--------------------------------------"
echo "$username.conf created in /etc/wireguard/certs folder."
echo "--------------------------------------"
exit 0
