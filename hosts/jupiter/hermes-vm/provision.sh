#!/usr/bin/env bash
# Provisionne l'invité Ubuntu pour Hermes Agent.
# Exécuté en root DANS la VM, poussé et lancé par systemd.services.hermes-vm-provision.
# Idempotent : relançable à tout moment (aucune donnée n'est écrasée).
set -euo pipefail

HERMES_USER=hermes
HERMES_UID=1000
DATA_MOUNT=/opt/data
DATA_LABEL=hermes-data
ENV_SRC=/root/hermes.env
ENV_DST=/etc/hermes/hermes.env

log() { printf '\n==> %s\n' "$*"; }

log "paquets système"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  ca-certificates curl git gh jq unzip xz-utils rsync \
  fonts-liberation ffmpeg \
  nodejs npm \
  build-essential python3 python3-venv python3-pip \
  tzdata sudo >/dev/null

# Ubuntu 24.04 ne distribue chromium que via snap : best-effort, bladebro
# embarque de toute façon son propre Chromium.
log "chromium (snap)"
if command -v snap >/dev/null 2>&1; then
  snap list chromium >/dev/null 2>&1 || snap install chromium || true
else
  echo "snapd absent : installer google-chrome-stable si un Chromium système est requis" >&2
fi

# Outils MCP : mêmes chemins absolus que dans le conteneur, donc la config
# existante (~/.hermes/config.yaml) reste valide. npm -g en root -> /usr/local.
log "donsetch + bladebro (npm -g)"
npm install -g --silent "donsetch@5.2.1" "bladebro@4.6.8" \
  || echo "ATTENTION : échec npm -g (vérifier la version de node, >= 20 si besoin)" >&2

log "disque de données -> $DATA_MOUNT"
if ! mountpoint -q "$DATA_MOUNT"; then
  root_disk="$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" | head -1)"
  data_dev=""
  for d in $(lsblk -dpno NAME,TYPE | awk '$2 == "disk" { print $1 }'); do
    [ "/dev/$root_disk" = "$d" ] && continue
    data_dev="$d"
    break
  done
  [ -n "$data_dev" ] || { echo "ERREUR : aucun disque de données trouvé" >&2; exit 1; }

  if ! blkid "$data_dev" >/dev/null 2>&1; then
    echo "formatage de $data_dev (vierge, label $DATA_LABEL)"
    mkfs.ext4 -q -L "$DATA_LABEL" "$data_dev"
  fi

  install -d -m 0750 "$DATA_MOUNT"
  mount "$data_dev" "$DATA_MOUNT"
fi
grep -q "LABEL=$DATA_LABEL" /etc/fstab \
  || echo "LABEL=$DATA_LABEL $DATA_MOUNT ext4 defaults,nofail 0 2" >>/etc/fstab

log "utilisateur $HERMES_USER (uid $HERMES_UID)"
# L'image Ubuntu fournit `ubuntu` en uid 1000 : on le renomme plutôt que d'en
# créer un second, pour que les fichiers migrés (uid 1000) restent accessibles.
if ! id "$HERMES_USER" >/dev/null 2>&1; then
  if id ubuntu >/dev/null 2>&1; then
    usermod -l "$HERMES_USER" -d "/home/$HERMES_USER" -m ubuntu
    groupmod -n "$HERMES_USER" ubuntu
  else
    useradd -m -U -u "$HERMES_UID" -s /bin/bash "$HERMES_USER"
  fi
fi
usermod -s /bin/bash -aG sudo "$HERMES_USER" 2>/dev/null || true
install -d -m 0755 /etc/sudoers.d
echo "$HERMES_USER ALL=(ALL) NOPASSWD:ALL" >"/etc/sudoers.d/90-$HERMES_USER"
chmod 0440 "/etc/sudoers.d/90-$HERMES_USER"
chown "$HERMES_USER:$HERMES_USER" "$DATA_MOUNT"
chmod 0750 "$DATA_MOUNT"

log "secrets (/etc/hermes/hermes.env)"
install -d -m 0755 /etc/hermes
if [ -f "$ENV_SRC" ]; then
  install -m 0600 -o root -g root "$ENV_SRC" "$ENV_DST"
  rm -f "$ENV_SRC"
elif [ ! -f "$ENV_DST" ]; then
  echo "ATTENTION : pas de $ENV_DST — le gateway démarrera sans clés API." >&2
fi

log "installation de Hermes (utilisateur $HERMES_USER)"
# install.sh restaure/installe sous $HOME de l'utilisateur ; HERMES_HOME reste /opt/data
su -s /bin/bash "$HERMES_USER" -c 'command -v hermes >/dev/null 2>&1 || curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash'

HERMES_BIN="$(su -s /bin/bash "$HERMES_USER" -c 'command -v hermes' || true)"
[ -n "$HERMES_BIN" ] || { echo "ERREUR : hermes introuvable après install.sh" >&2; exit 1; }
echo "hermes -> $HERMES_BIN ($("$HERMES_BIN" --version 2>/dev/null | head -1))"

log "service systemd hermes-gateway"
cat >/etc/systemd/system/hermes-gateway.service <<EOF
[Unit]
Description=Hermes Agent gateway
After=network-online.target
Wants=network-online.target
RequiresMountsFor=$DATA_MOUNT

[Service]
Type=simple
User=$HERMES_USER
Group=$HERMES_USER
Environment=HERMES_HOME=$DATA_MOUNT
Environment=HOME=/home/$HERMES_USER
Environment=TZ=Europe/Paris
EnvironmentFile=-$ENV_DST
WorkingDirectory=$DATA_MOUNT
ExecStart=$HERMES_BIN gateway run --replace
Restart=always
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now hermes-gateway.service

# linger : les cron jobs Hermes tournent en `systemd-run --user --scope`
loginctl enable-linger "$HERMES_USER"

log "état"
systemctl is-active hermes-gateway.service || true
su -s /bin/bash "$HERMES_USER" -c 'HERMES_HOME=/opt/data '"$HERMES_BIN"' doctor 2>&1 | tail -20' || true

log "terminé — puis : incus exec <instance> -- journalctl -u hermes-gateway -f"
