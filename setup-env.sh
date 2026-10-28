#!/usr/bin/env bash
# setup-env.sh - installs the tools needed for the DVWA-on-AWS project.
# Target: Ubuntu / Debian / Kali / WSL2 Ubuntu. Run as a normal user with sudo.
# Usage: bash setup-env.sh
set -uo pipefail

ok()   { printf '\033[32m[OK]\033[0m   %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }
info() { printf '\033[36m[..]\033[0m   %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

if ! have apt-get; then
  warn "apt-get not found. This script targets Debian/Ubuntu/Kali/WSL. Install the tools manually (see README.md)."
  exit 1
fi

info "Updating apt and installing base packages"
sudo apt-get update -y
sudo apt-get install -y curl wget unzip git jq gnupg lsb-release ca-certificates \
  software-properties-common mariadb-client tcpdump sqlmap

# --- AWS CLI v2 ---
if have aws; then ok "aws cli: $(aws --version 2>&1)"; else
  info "Installing AWS CLI v2"
  tmp="$(mktemp -d)"
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "$tmp/awscliv2.zip"
  unzip -q "$tmp/awscliv2.zip" -d "$tmp" && sudo "$tmp/aws/install"
  rm -rf "$tmp"
  have aws && ok "aws cli installed" || warn "aws cli install failed"
fi

# --- Terraform (HashiCorp apt repo) ---
if have terraform; then ok "terraform: $(terraform version | head -1)"; else
  info "Installing Terraform"
  wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt-get update -y && sudo apt-get install -y terraform
  have terraform && ok "terraform installed" || warn "terraform install failed"
fi

# --- Docker ---
if have docker; then ok "docker: $(docker --version)"; else
  info "Installing Docker"
  sudo apt-get install -y docker.io
  sudo usermod -aG docker "$USER" || true
  warn "Log out and back in (or run 'newgrp docker') so docker works without sudo."
fi

# --- Trivy ---
if have trivy; then ok "trivy: $(trivy --version | head -1)"; else
  info "Installing Trivy"
  wget -qO- https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor --yes -o /usr/share/keyrings/trivy.gpg
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
  sudo apt-get update -y && sudo apt-get install -y trivy
  have trivy && ok "trivy installed" || warn "trivy install failed"
fi

# --- Wireshark / tshark ---
if have tshark; then ok "tshark present"; else
  info "Installing Wireshark (tshark)"
  echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wireshark tshark
  sudo usermod -aG wireshark "$USER" || true
fi

# --- OWASP ZAP (Docker image, avoids a Java install) ---
if have docker; then
  info "Pulling OWASP ZAP image (used later for authenticated scans)"
  docker pull ghcr.io/zaproxy/zaproxy:stable >/dev/null 2>&1 \
    && ok "ZAP image pulled" || warn "ZAP image pull failed (retry after docker group refresh)"
fi

echo
info "Tool summary"
for t in aws terraform docker trivy sqlmap tshark mysql curl jq git; do
  if have "$t"; then ok "$t"; else warn "$t missing"; fi
done

echo
echo "Next: configure Learner Lab credentials, then run: bash lab-preflight.sh"
