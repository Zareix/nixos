#!/usr/bin/env bash
# Migration : /data/apps/hermes-agent (état du conteneur Docker) -> volume de la VM.
# À lancer SUR JUPITER, en root. Le conteneur est arrêté, pas supprimé : rollback immédiat.
set -euo pipefail

SRC=${SRC:-/data/apps/hermes-agent}
INSTANCE=${INSTANCE:-hermes}
CONTAINER=${CONTAINER:-hermes-agent}

# Répertoires propres au conteneur : chemins absolus vers /opt/hermes, réinstallés par provision.sh
EXCLUDES=(
  --exclude=./venvs
  --exclude=./installs
  --exclude=./.venv
  --exclude=./.npm-global
  --exclude=./home/.npm
  --exclude=./webui/cache
)

[ -d "$SRC" ] || { echo "ERREUR : $SRC introuvable" >&2; exit 1; }
incus info "$INSTANCE" >/dev/null 2>&1 || { echo "ERREUR : instance $INSTANCE absente" >&2; exit 1; }
incus exec "$INSTANCE" -- mountpoint -q /opt/data \
  || { echo "ERREUR : /opt/data n'est pas monté dans $INSTANCE (provision.sh pas passé ?)" >&2; exit 1; }

echo "source      : $SRC ($(du -sh "$SRC" | cut -f1))"
echo "destination : $INSTANCE:/opt/data"
echo
read -r -p "Arrêter $CONTAINER et écraser /opt/data dans la VM ? [oui/NON] " ok
[ "$ok" = "oui" ] || { echo "annulé"; exit 1; }

if docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "==> arrêt du conteneur $CONTAINER (conservé pour rollback)"
  docker stop "$CONTAINER"
fi

echo "==> copie (uid/gid numériques préservés : 1000 = hermes des deux côtés)"
tar -C "$SRC" --numeric-owner -cf - "${EXCLUDES[@]}" . \
  | incus exec "$INSTANCE" -- tar -C /opt/data --numeric-owner -xf -

echo "==> permissions"
incus exec "$INSTANCE" -- chown -R 1000:1000 /opt/data
incus exec "$INSTANCE" -- chmod 0750 /opt/data

echo "==> redémarrage du gateway dans la VM"
incus exec "$INSTANCE" -- systemctl restart hermes-gateway.service
sleep 5
incus exec "$INSTANCE" -- systemctl --no-pager --lines=20 status hermes-gateway.service || true

cat <<'EOF'

Migration terminée. Vérifications à faire (dans la VM) :

  incus exec hermes -- su - hermes -c 'HERMES_HOME=/opt/data hermes doctor'
  incus exec hermes -- su - hermes -c 'HERMES_HOME=/opt/data hermes sessions list | head'
  incus exec hermes -- su - hermes -c 'HERMES_HOME=/opt/data hermes memory status'

Rollback (tant que le conteneur existe) :

  docker start hermes-agent

Ne supprimer le conteneur qu'après quelques jours d'usage :
  docker rm hermes-agent && img=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep hermes-agent | head -1) && echo "$img"
EOF
