# mercure — VM Debian pour Hermes Agent sur jupiter

Remplace le conteneur Docker `jupiter/hermes-agent` (repo `Zareix/docker`) par
**mercure**, une VM Incus **Debian 13 (trixie)** pilotée depuis ce flake.

- **Déclaratif (ce repo)** : le module générique `modules/zrx/incus.nix`
  (`zrx.incus`) — daemon incus, pools, bridges, profils, UI web,
  cloud-init, partages de répertoires hôte, création et réconciliation des instances.
- **Manuel (assumé)** : tout l'intérieur de la VM — paquets, Hermes, unité
  systemd. Aucun script de provisioning n'est fourni : les étapes
  minimales sont en §2, à lancer une fois.

## Données : des fichiers de l'hôte, pas une image disque

`/opt/data` **n'est pas un volume incus** : c'est un partage du répertoire hôte
`/data/apps/mercure`, monté dans la VM par l'agent invité (9p ou virtiofs, incus
choisit). Conséquences voulues :

- les données restent **des fichiers lisibles sur jupiter** → le restic de l'hôte
  les sauvegarde normalement, en incrémental, sans lire d'image de plusieurs
  dizaines de Go ;
- le disque système de la VM vit dans le pool `/data/apps/incus`, **exclu du
  backup** (il est reconstructible depuis ce flake) ;
- un partage n'est **pas** snapshoté avec l'instance : la protection des données,
  c'est restic, pas le snapshot incus.

**Mode journal obligatoire** : `state.db` (SQLite) vit sur ce partage. En mode
**WAL**, SQLite échoue sur virtiofs (`disk I/O error`) et le doctor signale un
risque de corruption. Toutes les bases doivent être en `journal_mode: delete`
(`database.journal_mode` dans `config.yaml`, conversion en §3), sinon le gateway
crashe en boucle au démarrage.

Corollaire : restic lit une base **vivante** (il ne prend pas les verrous SQLite),
donc une restauration peut échouer au `integrity_check`. Si ça arrive, la parade
est un `sqlite3 /opt/data/state.db "VACUUM INTO /data/apps/mercure/db-dump/state.db"`
juste avant le cron, sans rien changer d'autre.

## Module générique

`modules/zrx/incus.nix` ne connaît pas Hermes : il expose `zrx.incus` (pool,
réseau, UI) et `zrx.incus.vms.<nom>` (image, cpu/mem, disque racine, partages,
cloud-init). Tout ce qui est spécifique à mercure tient
dans l'appel du host `hosts/jupiter/default.nix`, plus le `user-data.yaml` d'ici.

```nix
zrx.incus = {
  enable = true;
  storageSource = "/data/apps/incus";
  network = "10.42.0.1/24";
  vms.mercure = {
    image = "images:debian/13/cloud";
    cpu = 4; memory = "6GiB"; rootSize = "60GiB";
    userData = ./mercure/user-data.yaml;
    shares = [{name = "data"; source = "/data/apps/mercure"; path = "/opt/data";}];
  };
};
```

Une deuxième VM = une entrée de plus sous `vms`, une unité `incus-vm-<nom>`
générée automatiquement. Limites à connaître :

- `cpu`, `memory` et la présence des partages sont **réconciliés à chaque
  rebuild** ;
- `rootSize` ne s'applique **qu'à la création** (redimensionner est une opération
  incus manuelle) ;
- le preseed n'est appliqué **qu'à l'initialisation d'incus** : ajouter un pool ou
  un réseau plus tard ne crée rien, il faut `incus storage create` /
  `incus network create` à la main ;
- les `shares` ne sont pas inclus dans les snapshots de l'instance.

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

| Ressource | Valeur |
|---|---|
| Instance | `mercure` (VM, pas conteneur) |
| Image | `images:debian/13/cloud` (incus-agent + cloud-init → `incus exec` et user-data au premier boot) |
| CPU / RAM | 4 vCPU / 6 GiB |
| Pool | `default`, driver `dir`, source `/data/apps/incus` (disque système seulement) |
| Réseau | bridge `incusbr0`, `10.42.0.0/24`, IP en DHCP (l'accès passe par le tailnet) |
| Données | partage hôte `/data/apps/mercure` (uid/gid 1000) → `/opt/data` |

`/opt/data` **garde le même chemin** que dans le conteneur : `config.yaml`, `state.db`, les skills et les chemins absolus continuent de fonctionner
sans réécriture.

## Ordre des opérations

### 0. Prérequis sur jupiter

```sh
ls -l /dev/kvm                      # sans KVM, --vm tombe en émulation : stop
df -h /data/apps                    # ~80 G libres (disque système de la VM)
```

### 1. Activer et construire

```sh
git pull && nh os switch .
systemctl status incus-vm-mercure    # création/réconciliation de l'instance au boot
incus list                          # mercure RUNNING, IP 10.42.0.x (DHCP)
```

Au premier boot, l'agent incus dépose les templates cloud-init puis redémarre la
VM : attendre la fin avant de continuer.

```sh
incus exec mercure -- cloud-init status --wait   # status: done
incus exec mercure -- id raphaelgc               # uid=1000, créé par cloud-init
```

**Vérifier le protocole du partage avant de migrer les données** — c'est incusd qui
choisit, au démarrage, entre virtiofs (« si disponible ») et 9p :

```sh
# vérité terrain, depuis la VM : virtiofs = ok, 9p = SQLite risqué sur /opt/data
incus exec mercure -- findmnt -no FSTYPE /opt/data

# côté hôte, même information dans la ligne de commande de QEMU
ps -eo args= | grep -oE -- '-device vhost-user-fs-pci|-virtfs local' | head -1
#   vhost-user-fs-pci => virtiofs
#   virtfs local     => 9p
```

virtiofs est attendu ici : le module nixpkgs met `virtiofsd` dans le PATH d'incusd,
et la mémoire d'une VM incus est partagée avec l'hôte par défaut (prérequis de
virtiofs). Il n'existe pas d'option de device pour forcer l'un ou l'autre.

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

# d. /opt/data est déjà monté (partage de /data/apps/mercure)
ls -la /opt/data

exit
```

Puis l'installation officielle, en tant que `raphaelgc` — l'utilisateur de
`vars.nix`, créé par cloud-init comme utilisateur par défaut de l'image (uid 1000,
donc propriétaire de `/opt/data`). C'est le chemin **Tier 1** :

```sh
incus exec mercure -- su - raphaelgc -c \
  'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash'
```

`install.sh` enchaîne sur le wizard `hermes setup` : répondre **ESC** (annuler).
Le vrai `config.yaml` arrive avec la migration (§3) — le wizard en créerait un
autre, aussitôt écrasé.

Le service est géré par l'installeur, pas à la main :

```sh
# `sudo` réinitialise l'environnement : passer HERMES_HOME via `sudo env`,
# sinon root travaille dans /root/.hermes.
incus exec mercure -- sudo env HERMES_HOME=/opt/data \
  /home/raphaelgc/.local/bin/hermes gateway install --system \
  --run-as-user raphaelgc --start-now

# linger : requis pour les cron jobs, même avec un service system
incus exec mercure -- loginctl enable-linger raphaelgc
```

`--system` installe une unité system-level (démarrage au boot, sans session
ouverte), `--run-as-user` fixe l'utilisateur d'exécution et `HERMES_HOME` pointe
sur l'état partagé. L'unité s'appelle `hermes-gateway-<hash>` (hash du
`HERMES_HOME` non standard, ici `hermes-gateway-b7dd404e`) : `systemctl
status|stop 'hermes-gateway*'` fonctionne sur une unité chargée, mais pour la
(re)démarrer après un arrêt, utilise le nom complet — un glob ne relance pas une
unité déchargée. Éviter `hermes gateway stop|restart` en root : la commande
vérifie que `/opt/data` appartient à l'utilisateur appelant et refuse
(`unsafe_control_path`). Adapter le chemin du binaire si `install.sh` ne l'a pas
mis dans `~/.local/bin`.

Depuis npm 11.19, le postinstall de `donsetch` est bloqué : `binaries/donsetch`
(le chemin du `config.yaml`) n'existe qu'après un premier lancement du wrapper.
Une fois pour toutes, en root :

```sh
incus exec mercure -- /usr/local/bin/donsetch --version
```

Si l'install échoue sur `refusing to update …hermes-agent` ou `no dependency
environment is committed`, une mise à jour a été interrompue : la finir en
`raphaelgc` avant de relancer (`hermes update`, puis `hermes pm repair` si
demandé). Ne jamais la lancer en root : le checkout appartient à uid 1000.

`loginctl enable-linger` reste nécessaire : les cron jobs Hermes tournent en
`systemd-run --user --scope`, qui exige un gestionnaire de session pour l'uid.

Le `.env` vit dans `HERMES_HOME`, donc `/opt/data/.env` — il arrive avec la
migration (§3). Pour une VM neuve, copier celui du conteneur sur l'hôte
(`raphaelgc` est uid 1000 des deux côtés, donc un simple `install` suffit) :

```sh
install -D -m 0600 /data/apps/hermes-agent/.env /data/apps/mercure/.env
```

Le dashboard web n'est **pas** couvert par le service du gateway : il a sa propre
unité, à installer une fois `/opt/data/.env` en place (migration §3, ou écriture
directe ci-dessus). Écouter sur `0.0.0.0` active l'auth gate, dont les
identifiants sont `HERMES_DASHBOARD_BASIC_AUTH_*`.

```sh
incus exec mercure -- bash -c 'cat >/etc/systemd/system/hermes-dashboard.service <<"EOF"
[Unit]
Description=Hermes Agent Web Dashboard
After=network-online.target
Wants=network-online.target

[Service]
User=raphaelgc
Environment=HERMES_HOME=/opt/data
ExecStart=/home/raphaelgc/.local/bin/hermes dashboard --host 0.0.0.0 --port 9119 --no-open
Restart=always
RestartSec=10
RestartPreventExitStatus=78

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now hermes-dashboard'
```

`RestartPreventExitStatus=78` évite la boucle de redémarrage quand Hermes refuse
volontairement de démarrer (port déjà servi). Le process lit lui-même
`$HERMES_HOME/.env`, donc pas d'`EnvironmentFile`. Si les extras web manquent,
`hermes dashboard` affiche la commande à lancer.

### 3. Migrer l'état du conteneur (manuel, volontairement hors du repo)

Aucun script n'est fourni : à lancer à la main, une fois, depuis jupiter. Comme
`/opt/data` **est** un répertoire de l'hôte, la migration ne traverse plus la VM.
Le conteneur est **arrêté, jamais supprimé**.

```sh
SRC=/data/apps/hermes-agent
DST=/data/apps/mercure
UNIT=hermes-gateway-b7dd404e   # systemctl list-unit-files 'hermes-gateway*'

# a. état cohérent : conteneur et services de la VM arrêtés (state.db)
docker stop hermes-agent 2>/dev/null || true   # déjà supprimé : ignorer
incus exec mercure -- systemctl stop hermes-dashboard $UNIT

# b. copie directe, uid/gid préservés ; on exclut ce qui embarque des chemins
#    d'interpréteur du conteneur
rsync -aH --numeric-ids \
  --exclude 'venvs/' --exclude 'installs/' --exclude '.venv/' \
  --exclude '.npm-global/' --exclude 'home/.npm/' --exclude 'webui/cache/' \
  "$SRC"/ "$DST"/
chown -R 1000:1000 "$DST"

# c. config.yaml : restes du conteneur + mode journal SQLite
$EDITOR "$DST/config.yaml"
#    - retirer DONGHOST_NO_SANDBOX de mcp_servers.donsetch.env
#      (la VM a un vrai sandbox chromium)
#    - BLADE_HOME: /home/hermeswebui/.hermes/blade-state
#         -> /home/raphaelgc/.hermes/blade-state
#    - ajouter à la racine :
#        database:
#          journal_mode: delete

# d. bases SQLite : le WAL ne fonctionne pas sur virtiofs (disk I/O error), et
#    `hermes sessions set-journal-mode` échoue car il ouvre la base sur le
#    partage. On convertit donc hors du partage, via /tmp.
incus exec mercure -- bash -c '
  for db in $(find /opt/data -name "*.db" -not -path "*/cache/*" -not -path "*/backups/*"); do
    cp "$db" /tmp/c.db; cp "$db-wal" /tmp/c.db-wal 2>/dev/null
    python3 -c "import sqlite3; sqlite3.connect(\"/tmp/c.db\").execute(\"pragma journal_mode=delete\")"
    cp /tmp/c.db "$db"; rm -f /tmp/c.db* "$db-wal" "$db-shm"
  done'

# e. redémarrage (nom complet : le glob ne relance pas une unité déchargée)
incus exec mercure -- systemctl start $UNIT hermes-dashboard

# f. vérifications
incus exec mercure -- su - raphaelgc -c 'HERMES_HOME=/opt/data hermes doctor'
incus exec mercure -- journalctl -u $UNIT -n 20 --no-pager
```

Rollback tant que le conteneur existe : `docker start hermes-agent`. Ne le
supprimer qu'après quelques jours d'usage réel.

### 4. Backup (côté jupiter, rien à changer dans la VM)

Dans `Zareix/docker`, `jupiter/backup-jupiter/compose.yaml`, une seule ligne à
ajouter aux `RESTIC_BACKUP_ARGS` :

```
--exclude /data/apps/incus/**
```

Le reste est déjà bon : les sources sont `/data`, donc `/data/apps/mercure` (les
données réelles, quelques Go) est sauvegardé en incrémental, et le pool incus
(disque système de la VM) est ignoré.

### 5. Accès réseau

- Dashboard en tailnet-only sous `zrx.sh` (convention maison) : installer tailscale
  dans la VM, `tailscale up`, puis joindre le dashboard par son IP tailnet
  (`http://<hostname-tailnet>:9119`). L'IP du bridge est dynamique : pas de route
  Traefik statique pour la VM.

### 6. UI web d'Incus

Le module active `virtualisation.incus.ui` (`incus-ui-canonical`) et publie
`core.https_address` sur le port 8443. Le firewall NixOS est désactivé
(`modules/core/network.nix`) : le port écoute sur toutes les interfaces, l'accès
se fait par le tailnet.

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
- Backup inchangé : les données restent des fichiers sur jupiter.

## Rollback

| Incident | Action |
|---|---|
| La VM ne démarre plus | `incus snapshot restore mercure <snap>` (disque système ; `/opt/data` vit sur l'hôte) |
| Données abîmées | restauration restic de `/data/apps/mercure` |
| Hermes cassé après migration | `docker start hermes-agent` (état intact) |
| Module à retirer | `enable = false` + `nh os switch .` (l'instance survit, `/opt/data` aussi) |

## Points non vérifiés

- `/dev/kvm` sur jupiter (à contrôler avant tout).
- Protocole du partage (9p ou virtiofs) : c'est incus qui décide. À vérifier au
  premier boot (`incus info mercure`, puis `mount | grep /opt/data` dans la VM) —
  en 9p, SQLite sur `/opt/data` est franchement risqué.
- Le chemin de `hermes` après `install.sh` (`~/.local/bin/hermes`) : à confirmer
  au premier passage, l'unité systemd le suppose.
