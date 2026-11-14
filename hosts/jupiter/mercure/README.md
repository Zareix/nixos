# mercure — VM Debian pour Hermes Agent sur jupiter

Remplace le conteneur Docker `jupiter/hermes-agent` (repo `Zareix/docker`) par
**mercure**, une VM Incus **Debian 13 (trixie)** pilotée depuis ce flake.

- **Déclaratif (ce repo)** : le module générique `modules/zrx/incus.nix`
  (`zrx.incus`) — daemon incus, pools, bridges, profils, réservation DHCP, UI web,
  cloud-init, création et réconciliation des instances.
- **Manuel (assumé)** : tout l'intérieur de la VM — paquets, Hermes, unité
  systemd, montage de `/opt/data`, Mnemosyne. Aucun script de provisioning n'est
  fourni : les étapes minimales sont en §2, à lancer une fois.

## Module générique

`modules/zrx/incus.nix` ne connaît pas Hermes : il expose `zrx.incus` (pools,
réseaux, UI) et `zrx.incus.vms.<nom>` (image, cpu/mem, disque racine, volumes
bloc, IP réservée, cloud-init). Tout ce qui est spécifique à mercure tient dans
l'appel du host `hosts/jupiter/default.nix`, plus le `user-data.yaml` d'ici.

```nix
zrx.incus = {
  enable = true;
  storagePools.default.source = "/data/apps/incus";
  networks.incusbr0.cidr = "10.42.0.0/24";
  vms.mercure = {
    image = "images:debian/13";
    cpu = 4; memory = "6GiB"; rootSize = "60GiB";
    pool = "default"; network = "incusbr0"; ip = "10.42.0.10";
    userData = ./mercure/user-data.yaml;
    dataVolumes = [{name = "mercure-data"; size = "120GiB";}];
  };
};
```

Une deuxième VM = une entrée de plus sous `vms`, une unité `incus-vm-<nom>`
générée automatiquement. Limites à connaître :

- `cpu`, `memory`, `autostart` sont **réconciliés à chaque rebuild** ;
- `rootSize` et la taille des `dataVolumes` ne s'appliquent **qu'à la création**
  (redimensionner est une opération incus manuelle) ;
- le preseed n'est appliqué **qu'à l'initialisation d'incus** : ajouter un pool ou
  un réseau plus tard ne crée rien, il faut `incus storage create` /
  `incus network create` à la main.

## Pas de GUI

L'image cloud Debian est **headless** : aucun serveur graphique, aucun X/Wayland,
aucun environnement de bureau n'est installé. Il n'y a donc pas d'écran dans la VM,
seulement :

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
| Pool | `default`, driver `dir`, source `/data/apps/incus` |
| Réseau | bridge `incusbr0`, `10.42.0.0/24`, IP réservée `10.42.0.10` |
| Disque données | volume bloc `mercure-data` (120 GiB), **non formaté** → `/opt/data` |

`/opt/data` **garde le même chemin** que dans le conteneur : `config.yaml`, la base
Mnemosyne, `state.db`, les skills et les chemins absolus continuent de fonctionner
sans réécriture.

## Ordre des opérations

### 0. Prérequis sur jupiter

```sh
ls -l /dev/kvm                      # sans KVM, --vm tombe en émulation : stop
df -h /data/apps                    # ~150 G libres (sys + volume)
```

### 1. Activer et construire

```sh
git pull && nh os switch .
systemctl status incus-vm-mercure    # création/réconciliation de l'instance au boot
incus list                          # mercure RUNNING, IP 10.42.0.10
```

### 2. Installer Hermes à la main (une fois, le strict nécessaire)

```sh
# a. entrer dans la VM (root via l'agent invité)
incus exec mercure -- bash

# b. paquets utiles (dont chromium, qui est un vrai .deb sur Debian)
apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates curl git gh jq chromium ffmpeg \
  nodejs npm python3 python3-venv

# c. outils MCP : npm -g en root => /usr/local/lib/node_modules, soit exactement
#    les chemins absolus que contient déjà config.yaml
npm install -g donsetch@5.2.1 bladebro@4.6.8

# d. disque de données (le volume est créé par le module, pas formaté)
mkfs.ext4 -L mercure-data /dev/vdb
mkdir -p /opt/data && mount /dev/vdb /opt/data
echo 'LABEL=mercure-data /opt/data ext4 defaults,nofail 0 2' >> /etc/fstab
chown 1000:1000 /opt/data          # uid 1000 = debian dans l'invité

exit
```

Puis l'installation officielle, en tant que `debian` (uid 1000, déjà présent dans
l'image cloud) — c'est le chemin **Tier 1** :

```sh
incus exec mercure -- su - debian -c \
  'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash'
```

Pour que le gateway tourne en service, une unité suffit (adapter le chemin si
`hermes` n'est pas dans `~/.local/bin`) :

```sh
incus exec mercure -- bash -s <<'EOF'
cat >/etc/systemd/system/mercure-gateway.service <<'UNIT'
[Unit]
Description=Hermes Agent gateway
After=network-online.target
Wants=network-online.target
RequiresMountsFor=/opt/data

[Service]
Type=simple
User=debian
Group=debian
Environment=HERMES_HOME=/opt/data
Environment=HOME=/home/debian
Environment=TZ=Europe/Paris
WorkingDirectory=/opt/data
ExecStart=/home/debian/.local/bin/hermes gateway run --replace
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now mercure-gateway
loginctl enable-linger debian
EOF
```

`loginctl enable-linger` n'est pas cosmétique : les cron jobs Hermes tournent en
`systemd-run --user --scope`, qui exige un gestionnaire de session pour l'uid.

Le `.env` vit dans `HERMES_HOME`, donc `/opt/data/.env` — il arrive avec la
migration (§3). Pour une VM neuve, le copier à la main :

```sh
incus file push /chemin/vers/.env mercure/opt/data/.env --mode 0600
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

# b. copie avec uid/gid numériques préservés (1000 = debian dans l'invité) ;
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
incus exec "$INSTANCE" -- su - debian -c 'HERMES_HOME=/opt/data hermes doctor'
incus exec "$INSTANCE" -- su - debian -c 'HERMES_HOME=/opt/data hermes memory status'
```

Rollback tant que le conteneur existe : `docker start hermes-agent`. Ne le
supprimer qu'après quelques jours d'usage réel.

### 4. Mnemosyne (étape manuelle, une fois)

Le quirk n'est pas lié à Docker : le provider doit vivre dans un side-venv,
parce que Hermes bascule `sys.path` sur son environnement managé au démarrage.
Après la migration, dans la VM :

```sh
incus exec mercure -- su - debian
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
incus exec mercure -- su - debian -c 'HERMES_HOME=/opt/data hermes memory status'
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
| Module à retirer | `enable = false` + `nh os switch .` (l'instance et son volume survivent) |

## Points non vérifiés

- `/dev/kvm` sur jupiter (à contrôler avant tout).
- `incus config device set|override eth0 ipv4.address` : la commande qui marche
  dépend de la version d'incus ; le module essaie les deux et avertit.
- SQLite doit rester sur le volume bloc (pas de virtiofs) — c'est le cas ici.
- Le chemin de `hermes` après `install.sh` (`~/.local/bin/hermes`) : à confirmer
  au premier passage, l'unité systemd le suppose.
