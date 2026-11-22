cat <<'EOF' > /root/harden.sh
#!/usr/bin/env bash
set -euo pipefail

# 1. Lock down SSH to key-only (highest priority drop-in)
mkdir -p /etc/ssh/sshd_config.d
cat <<'SSHEOF' > /etc/ssh/sshd_config.d/00-hardening.conf
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
MaxAuthTries 3
SSHEOF
sshd -t && systemctl reload ssh

# 2. Add 2 GB swap if not already present
if ! swapon --show | grep -q '/swapfile'; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 3. Install & configure Fail2Ban + Unattended Security Upgrades
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y fail2ban unattended-upgrades apt-listchanges

cat <<'APTEOF' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
APTEOF

cat <<'UNATTEOF' > /etc/apt/apt.conf.d/51unattended-upgrades-local
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
UNATTEOF

systemctl enable --now fail2ban
systemctl enable --now unattended-upgrades
EOF

chmod +x /root/harden.sh && /root/harden.sh
