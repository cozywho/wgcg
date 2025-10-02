#!/bin/bash
# WireGuard + wgcg installer

# Must be root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Check for existing wg0.conf
if [ -f "/etc/wireguard/wg0.conf" ]; then
    echo "/etc/wireguard/wg0.conf already exists."
    read -rp "WireGuard appears installed. Only install wgcg? (y/n): " yn
    if [[ $yn =~ ^[Yy]$ ]]; then
        cp wgcg.sh /usr/bin/wgcg
        chmod +x /usr/bin/wgcg
        if [ -f "ipspace.txt" ]; then
            cp ipspace.txt /etc/wireguard/ipspace.txt
        else
            echo "ipspace.txt not found."
            exit 1
        fi
        echo "wgcg installed successfully."
        exit 0
    else
        echo "Exiting..."
        exit 1
    fi
fi

# Ask for WireGuard subnet
while true; do
    read -rp "Enter WireGuard gateway+mask (e.g. 10.2.0.1/24): " gatewayslashmask
    if [[ $gatewayslashmask =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        break
    else
        echo "Invalid format. Try again."
    fi
done

# Ask for listen port
read -rp "Enter WireGuard listen port [default 51820]: " listenport
listenport=${listenport:-51820}

# Prep system
setenforce 0
modprobe wireguard
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Firewall
firewall-cmd --add-port=$listenport/udp --permanent
firewall-cmd --reload

# Persist module
echo wireguard > /etc/modules-load.d/wireguard.conf

# Install tools
dnf install -y wireguard-tools

# Keys
wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
chmod 0400 /etc/wireguard/server.key
mkdir -p /etc/wireguard/clients

privatekey=$(cat /etc/wireguard/server.key)

# Create wg0.conf
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = $gatewayslashmask
ListenPort = $listenport
PrivateKey = $privatekey

PostUp   = firewall-cmd --zone=public --add-masquerade
PostUp   = firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -i wg0 -o ens18 -j ACCEPT
PostUp   = firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -o ens18 -j MASQUERADE

PostDown = firewall-cmd --zone=public --remove-masquerade
PostDown = firewall-cmd --direct --remove-rule ipv4 filter FORWARD 0 -i wg0 -o ens18 -j ACCEPT
PostDown = firewall-cmd --direct --remove-rule ipv4 nat POSTROUTING 0 -o ens18 -j MASQUERADE
EOF

# wgcg install
cp wgcg.sh /usr/bin/wgcg
chmod +x /usr/bin/wgcg

if [ -f "ipspace.txt" ]; then
    cp ipspace.txt /etc/wireguard/ipspace.txt
else
    echo "ipspace.txt not found. Please add manually."
fi

# Enable and start WireGuard
systemctl enable --now wg-quick@wg0

echo "Installation complete."
echo "wgcg installed, WireGuard configured and started."
echo "Modify /etc/wireguard/ipspace.txt as needed."
exit 0
