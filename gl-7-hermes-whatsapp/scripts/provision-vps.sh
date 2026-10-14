#!/usr/bin/env bash
# Provisiona a VPS (DigitalOcean, Ubuntu 22.04/24.04) para o PoC do Hermes Agent (GL-7).
# Rodar como root:  bash provision-vps.sh
set -euo pipefail

HERMES_USER=hermes
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Rode como root." >&2
  exit 1
fi

echo "==> Pacotes base"
apt-get update -y
apt-get install -y git curl ufw ffmpeg

echo "==> Firewall: apenas SSH de entrada (o bridge Baileys só faz conexões de saída)"
ufw allow OpenSSH
ufw --force enable

echo "==> Swap de 2 GB (se ainda não houver)"
if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> Usuário dedicado: $HERMES_USER"
if ! id "$HERMES_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$HERMES_USER"
fi
# Mantém o serviço systemd --user rodando sem sessão aberta.
loginctl enable-linger "$HERMES_USER"

echo "==> Copiando o kit para /home/$HERMES_USER"
cp -r "$KIT_DIR" "/home/$HERMES_USER/"
chown -R "$HERMES_USER:$HERMES_USER" "/home/$HERMES_USER/$(basename "$KIT_DIR")"

echo "==> Instalando o Hermes Agent (instalador oficial)"
sudo -iu "$HERMES_USER" bash -c \
  'curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash'

cat <<EOF

Pronto. Próximo passo: README, passo 2 (aplicar a trava com 'hermes config set'
e copiar o SOUL.md). Não substitua o config.yaml gerado pelo assistente.
EOF
