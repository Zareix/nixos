# mercure — VM Debian pour Hermes Agent sur jupiter

Remplace le conteneur Docker `jupiter/hermes-agent` (repo `Zareix/docker`) par
**mercure**, une VM Incus **Debian 13 (trixie)** pilotée depuis ce flake.

- **Déclaratif (ce repo)** : daemon incus, pool de stockage, bridge, réservation DHCP,
  cloud-init, script de provisioning, unités systemd de création/provisioning,
  secrets sops.
- **Non déclaratif (assumé)** : l'intérieur de la VM (apt, `hermes update`, npm, pip).
  C'est le prix de la flexibilité ; la compensation est le snapshot incus avant
  chaque changement.

## Pas de GUI

L'image cloud Debian est **headless** : aucun serveur graphique, aucun X/Wayland,
aucun environnement de bureau n'est installé, ni par l'image ni par
`provision.sh`. Il n'y a donc pas d'écran dans la VM, seulement :

- `incus exec mercure -- …` (agent invité) ;
- la console série via l'UI web d'Incus ;
- les ports HTTP servis par Hermes (dashboard `9119`, API `8642`), qui sont des
  pages web, pas une session graphique.

Chromium y tourne uniquement en mode headless (bladebro / donsetch). Conséquence :
`hermes desktop` (Electron) ne peut pas être lancé **dans** la VM — l'app desktop
se connecte à distance au backend (`backend.mode`), elle reste sur ton poste.

Debian plutôt qu'Ubuntu : `chromium` y est un vrai `.deb` (sur Ubuntu 24.04 c'est
un snap), `gh` est packagé (2.46), node 20 est suffisant pour les MCP, et il n'y a
aucun snapd dans l'image.

## Ce que le module crée

| Ressource | Valeur par défaut |
|---|---|
| Instance | `mercure` (VM, pas conteneur) |
| Image | `images:debian/13` (incus-agent déjà présent → `incus exec` fonctionne) |
| CPU / RAM | 4 vCPU / 6 GiB |
| Pool | `mercure`, driver `dir`, source `/data/apps/incus` |
| Réseau | bridge `incusbr0`, `10.42.0.0/24`, IP réservée `10.42.0.10` |
| Disque données | volume bloc `mercure-data` (120 GiB) → `/opt/data` dans la VM |

`/opt/data` **garde le même chemin** que dans le conteneur : `config.yaml`, la base
Mnemosyne, `state.db`, les skills et les chemins absolus continuent de fonctionner
sans réécriture.

## Ordre des opérations

### 0. Prérequis sur jupiter

```sh
ls -l /dev/kvm                      # sans KVM, --vm tombe en émulation : stop
df -h /data/apps                    # ~150 G libres (sys + volume)
```

### 1. Secret sops (une fois)

Le fichier `.env` de Hermes va dans `secrets/common.yaml` sous une clé unique,
décryptée sur l'hôte puis poussée dans la VM (jamais dans la config incus).

```sh
sops secrets/common.yaml        # ajouter une clé :
# mercure-env: |
#   OPENCODE_GO_API_KEY=...
#   HERMES_DASHBOARD_BASIC_AUTH_USERNAME=...
#   ...
```

Puis dans `hosts/jupiter/default.nix` :

```nix
envFile = config.sops.secrets."mercure-env".path;
```

(Laisser `envFile = null` tant que la clé n'existe pas : sinon l'activation
`sops-install-secrets` échoue et casse le rebuild.)

### 2. Activer et construire

```sh
git pull && nh os switch .
systemctl status mercure mercure-provision     # ~5-10 min au premier boot
incus list                                          # mercure RUNNING, IP 10.42.0.10
incus exec mercure -- journalctl -u mercure-gateway -f
```

### 3. Migrer l'état du conteneur (manuel, volontairement hors du repo)

Aucun script n'est fourni pour cette étape : elle se lance à la main, une fois,
depuis jupiter. Le conteneur est **arrêté, jamais supprimé** — `docker start
hermes-agent` suffit à revenir en arrière.

```sh
SRC=/data/apps/hermes-agent
INSTANCE=mercure

# a. le conteneur doit être arrêté pour un état cohérent (state.db / SQLite)
docker stop hermes-agent

# b. copie avec uid/gid numériques préservés (1000 = mercure des deux côtés) ;
#    on exclut ce qui embarque des chemins d'interpréteur du conteneur
tar -C "$SRC" --numeric-owner -cf - \
    --exclude=./venvs --exclude=./installs --exclude=./.venv \
    --exclude=./.npm-global --exclude=./home/.npm --exclude=./webui/cache . \
  | incus exec "$INSTANCE" -- tar -C /opt/data --numeric-owner -xf -

# c. permissions + redémarrage
incus exec "$INSTANCE" -- chown -R 1000:1000 /opt/data
incus exec "$INSTANCE" -- chmod 0750 /opt/data
incus exec "$INSTANCE" -- systemctl restart mercure-gateway

# d. vérifications
incus exec "$INSTANCE" -- su - mercure -c 'HERMES_HOME=/opt/data hermes doctor'
incus exec "$INSTANCE" -- su - mercure -c 'HERMES_HOME=/opt/data hermes memory status'
```

Rollback tant que le conteneur existe : `docker start hermes-agent`. Ne le
supprimer qu'après quelques jours d'usage réel.

### 4. Mnemosyne (étape manuelle, une fois)

Le quirk n'est pas lié à Docker : le provider doit vivre dans un side-venv,
parce que Hermes bascule `sys.path` sur son environnement managé au démarrage.
Après la migration, dans la VM :

```sh
incus exec mercure -- su - mercure
export PATH="$HOME/.local/bin:$PATH"

# l'interpréteur réellement utilisé par le gateway
HERMES_PYTHON=$(ps -eo args= | grep -o '/[^ ]*/venv/bin/python' | head -1)
uv venv --seed --python "$HERMES_PYTHON" /opt/data/venvs/mnemosyne
uv pip install --python /opt/data/venvs/mnemosyne/bin/python \
  "mnemosyne-memory[embeddings]" mnemosyne-hermes
HERMES_HOME=/opt/data MNEMOSYNE_DATA_DIR=/opt/data \
  /opt/data/venvs/mnemosyne/bin/mnemosyne-hermes install --mode wrapper \
  --python /opt/data/venvs/mnemosyne/bin/python
hermes config set memory.provider mnemosyne
exit

incus exec mercure -- systemctl restart mercure-gateway
incus exec mercure -- su - mercure -c 'HERMES_HOME=/opt/data hermes memory status'
# attendu : Plugin: installed ✓ / Status: available ✓
```

Si l'ancien `plugins/mnemosyne` est un lien symbolique vers un site-packages
disparu, le supprimer avant l'étape `--mode wrapper`.

### 5. Accès réseau

- Dashboard en tailnet-only sous `zrx.sh` (convention maison) : installer tailscale
  dans la VM, `tailscale up`, puis router Traefik vers `10.42.0.10:9119`.
- Traefik ne peut plus lire les labels Docker : la route devient statique
  (fichier de provider) — c'est la seule régression fonctionnelle du passage en VM.

### 6. UI web d'Incus

Le module active `virtualisation.incus.ui` (`incus-ui-canonical`) et publie
`core.https_address` sur le port 8443, **ouvert uniquement sur `tailscale0`**
(`ui.tailnetOnly = true`, désactivable).

```sh
# une fois, pour autoriser un navigateur
ssh jupiter incus config trust add admin
#   -> coller le token affiché dans l'UI

# puis : https://jupiter.<tailnet>.ts.net:8443/ui/
```

C'est une UI **d'hyperviseur** (liste des instances, console série, snapshots,
volumes, profils) servie par jupiter — pas une session graphique dans la VM.

Certificat auto-signé par défaut (avertissement navigateur) ; pour un vrai
certificat, `virtualisation.incus.useACMEHost` existe (Let's Encrypt via
`security.acme.certs`, non configuré ici).

## Ce que la VM règle

- Chromium avec sandbox réel (les user namespaces fonctionnent dans la VM), et un
  paquet `chromium` Debian maintenu : plus de `--no-sandbox`, plus de
  `DONGHOST_NO_SANDBOX`, plus de snap.
- `hermes update` fonctionnel (contrairement à l'install Docker).
- Ni `gh`, ni `pnpm`, ni binaire donsetch root-owned à installer au build :
  `apt` + `npm -g` fonctionnent.
- Plus de mapping UID 1000 ni de hook s6.
- Isolation réelle : root dans la VM, aucun accès à jupiter.

## Rollback

| Incident | Action |
|---|---|
| La VM ne démarre plus | `incus snapshot restore mercure <snap>` (snapshot avant chaque changement) |
| Hermes cassé après migration | `docker start hermes-agent` (état intact) |
| Provisioning à rejouer | `systemctl restart mercure-provision` |
| Module à retirer | `enable = false` + `nh os switch .` (l'instance et son volume survivent) |

## Points non vérifiés

- `/dev/kvm` sur jupiter (à contrôler avant tout).
- `incus config device set|override eth0 ipv4.address` : la commande qui marche
  dépend de la version d'incus ; le module essaie les deux et avertit.
- SQLite doit rester sur le volume bloc (pas de virtiofs) — c'est le cas ici.
