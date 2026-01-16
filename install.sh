#!/bin/bash
# WireGuard + wgcg installer (Rocky/RHEL/Fedora-ish)

set -euo pipefail

# -------------------- helpers --------------------
die() { echo "[!] $*" >&2; exit 1; }
info() { echo "[*] $*"; }

# Must be root
[ "$(id -u)" -eq 0 ] || die "Please run as root"

# Resolve WAN interface (default route)
WAN_IF="$(ip -4 route list default 2>/dev/null | awk '{print $5}' | head -n1 || true)"
[ -n "${WAN_IF}" ] || die "Could not detect default WAN interface (no default route?)"

WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/wg0.conf"

# -------------------- existing install path --------------------
if [ -f "$WG_CONF" ]; then
    info "$WG_CONF already exists."
    read -rp "WireGuard appears installed. Only install wgcg? (y/n): " yn
    if [[ $yn =~ ^[Yy]$ ]]; then
        install -m 0755 -o root -g root wgcg.sh /usr/bin/wgcg
        if [ -f "ipspace.txt" ]; then
            install -m 0644 -o root -g root ipspace.txt "${WG_DIR}/ipspace.txt"
        else
            die "ipspace.txt not found."
        fi
        info "wgcg installed successfully."
        exit 0
    else
        die "Exiting..."
    fi
fi

# -------------------- user prompts --------------------
while true; do
    read -rp "Enter WireGuard gateway+mask (e.g. 10.2.0.1/24): " gatewayslashmask
    if [[ $gatewayslashmask =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        break
    else
        echo "Invalid format. Try again."
    fi
done

read -rp "Enter WireGuard listen port [default 51820]: " listenport
listenport=${listenport:-51820}

# Choose firewalld zones (defaults are sane)
read -rp "Firewalld zone for WAN interface (${WAN_IF}) [default public]: " WAN_ZONE
WAN_ZONE=${WAN_ZONE:-public}

read -rp "Firewalld zone for WireGuard interface (wg0) [default trusted]: " WG_ZONE
WG_ZONE=${WG_ZONE:-trusted}

info "Using WAN interface: ${WAN_IF}"
info "Using WAN zone:      ${WAN_ZONE}"
info "Using WG zone:       ${WG_ZONE}"

# -------------------- system prep --------------------
info "Installing packages..."
dnf install -y wireguard-tools firewalld

info "Ensuring firewalld is enabled..."
systemctl enable --now firewalld

# Enable forwarding (idempotent)
info "Enabling IPv4 forwarding..."
cat >/etc/sysctl.d/99-wireguard.conf <<EOF
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null

# Make sure module loads at boot
info "Persisting wireguard module load..."
echo wireguard > /etc/modules-load.d/wireguard.conf
modprobe wireguard || true

# SELinux: leave enforcing on; wg doesn't require disabling SELinux.
# If you truly need permissive later, do it explicitly outside the installer.
info "SELinux left unchanged."

# -------------------- keys + dirs --------------------
info "Creating WireGuard directories..."
install -d -m 0700 -o root -g root "$WG_DIR"
install -d -m 0700 -o root -g root "$WG_DIR/clients"

info "Generating keys..."
umask 077
wg genkey | tee "$WG_DIR/server.key" | wg pubkey > "$WG_DIR/server.pub"
chmod 0400 "$WG_DIR/server.key"
privatekey="$(cat "$WG_DIR/server.key")"

# -------------------- wg0.conf (NO firewall PostUp) --------------------
info "Writing ${WG_CONF}..."
cat > "$WG_CONF" <<EOF
[Interface]
Address = ${gatewayslashmask}
ListenPort = ${listenport}
PrivateKey = ${privatekey}
EOF
chmod 0600 "$WG_CONF"

# -------------------- firewalld (permanent) --------------------
info "Configuring firewalld permanently..."

# Open port on WAN zone
firewall-cmd --permanent --zone="$WAN_ZONE" --add-port="${listenport}/udp"

# Put wg0 into WG_ZONE (zone is applied when interface appears)
firewall-cmd --permanent --zone="$WG_ZONE" --add-interface=wg0

# Enable masquerade on WAN zone (NAT out to internet)
firewall-cmd --permanent --zone="$WAN_ZONE" --add-masquerade

# Allow forwarding from wg zone (trusted -> public NAT)
# This is the simplest broadly-compatible option.
firewall-cmd --permanent --zone="$WG_ZONE" --add-forward

firewall-cmd --reload

# -------------------- wgcg install --------------------
info "Installing wgcg..."
install -m 0755 -o root -g root wgcg.sh /usr/bin/wgcg

if [ -f "ipspace.txt" ]; then
    install -m 0644 -o root -g root ipspace.txt "${WG_DIR}/ipspace.txt"
else
    echo "[!] ipspace.txt not found. Please add manually to ${WG_DIR}/ipspace.txt"
fi

# -------------------- enable wg-quick --------------------
info "Enabling wg-quick@wg0..."
systemctl enable --now wg-quick@wg0

info "Done."
echo
echo "Installation complete."
echo "- WireGuard: ${WG_CONF}"
echo "- wgcg:       /usr/bin/wgcg"
echo "- ipspace:    ${WG_DIR}/ipspace.txt"
echo "- Service:    systemctl status wg-quick@wg0"
