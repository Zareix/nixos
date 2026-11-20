# mercure — VM Debian pour Hermes Agent sur jupiter

Remplace le conteneur Docker `jupiter/hermes-agent` (repo `Zareix/docker`) par
**mercure**, une VM Incus **Debian 13 (trixie)** pilotée depuis ce flake.

- **Déclaratif (ce repo)** : `modules/zrx/incus.nix` (`zrx.incus`) — daemon incus,
  pool, bridge, profils, cloud-init, création et réconciliation des instances.
- **Manuel (assumé)** : tout l'intérieur de la VM — paquets, Hermes, unités
  systemd. Aucun script de provisioning : les étapes sont en §2 à §4.

## Données : locales à la VM

`~/.hermes` (le défaut de Hermes, aucun `HERMES_HOME`) est un simple répertoire
du **disque système de la VM** (pool `/data/apps/incus`), pas un partage de
l'hôte :

- SQLite (`state.db`) vit sur un ext4 local : WAL et verrous POSIX normaux,
  aucun des problèmes d'un partage virtiofs/9p ;
- le pool incus est exclu de restic : la sauvegarde, c'est Hermes —
  `hermes backup` produit un zip de `$HERMES_HOME` (§7), à sortir de la VM pour
  la rétention hors site ;
- la copie initiale depuis le conteneur est **minimale** (§3) : pas de `state.db`,
  pas de `home/`, pas de caches — on repart d'une base saine.

## Module générique

`modules/zrx/incus.nix` ne connaît pas Hermes : il expose `zrx.incus` (pool,
réseau) et `zrx.incus.vms.<nom>` (image, cpu/mem, disque racine, cloud-init).
Tout ce qui est spécifique à mercure tient dans l'entrée du host.

```nix
zrx.incus = {
  enable = true;
  storageSource = "/data/apps/incus";
  network = "10.42.0.1/24";
  vms.mercure = {
    image = "images:debian/13/cloud";
    cpu = 4; memory = "6GiB"; rootSize = "60GiB";
    userData = pkgs.writeText "mercure-user-data.yaml" (import ./mercure/user-data.nix {inherit globals;});
  };
};
```

Une deuxième VM = une entrée de plus sous `vms`, une unité `incus-vm-<nom>`
générée automatiquement. Limites à connaître :

- `cpu`, `memory` sont **réconciliés à chaque rebuild** ;
- `rootSize` ne s'applique **qu'à la création** (redimensionner est une opération
  incus manuelle) ;
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

| Ressource | Valeur |
|---|---|
| Instance | `mercure` (VM, pas conteneur) |
| Image | `images:debian/13/cloud` (incus-agent + cloud-init → `incus exec` et user-data au premier boot) |
| CPU / RAM | 4 vCPU / 6 GiB |
| Pool | `default`, driver `dir`, source `/data/apps/incus` |
| Réseau | bridge `incusbr0`, `10.42.0.0/24`, IP en DHCP (l'accès passe par le tailnet) |
| Données | `~/.hermes` (défaut Hermes) sur le disque de la VM (copie minimale en §3) |

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

### 2. Installer Hermes (paquets + install.sh)

```sh
incus exec mercure -- bash

# paquets utiles (dont chromium, qui est un vrai .deb sur Debian)
apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates curl git gh jq chromium ffmpeg \
  nodejs npm python3 python3-venv

exit
```

Pas de `npm -g` : les serveurs MCP de `config.yaml` sont lancés par `npx -y`
(§3), node + npm suffisent. `npx` télécharge donsetch/bladebro au premier
démarrage (la VM sort par le NAT d'incus).

Puis l'installation officielle, en tant que `raphaelgc` — l'utilisateur de
`vars.nix`, créé par cloud-init comme utilisateur par défaut de l'image (uid 1000) :

```sh
incus exec mercure -- su - raphaelgc -c \
  'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash'
```

`install.sh` enchaîne sur le wizard `hermes setup` : répondre **ESC** (annuler).
Le vrai `config.yaml` arrive avec la copie (§3) — le wizard en créerait un autre.

### 3. Copier le minimum depuis le conteneur

Le strict nécessaire : réglages, secrets, mémoire, skills, scripts, cron. Pas de
`state.db` (l'historique), ni `home/`, ni caches, ni `installs/`.

```sh
SRC=/data/apps/hermes-agent
DST=/home/raphaelgc/.hermes

docker stop hermes-agent 2>/dev/null || true   # copie cohérente (auth.json)

tar -C "$SRC" -cf - --exclude 'skills/.archive' \
  config.yaml .env auth.json SOUL.md MEMORY.md USER.md \
  profile.yaml secrets.yaml google_token.json google_client_secret.json \
  skills scripts apple-music cron plugins/hermes-push \
  | incus exec mercure -- tar -C "$DST" -xf -

# optionnel : profil Chromium de bladebro (cookies + logins web, 165 Mo)
# tar -C "$SRC" -cf - blade-state | incus exec mercure -- tar -C "$DST" -xf -

incus exec mercure -- chown -R 1000:1000 "$DST"

# les trois fichiers qui citent l'ancien /opt/data
incus exec mercure -- su - raphaelgc -c "
  sed -i 's#/opt/data/.hermes#$DST#g; s#/opt/data#$DST#g' \
    $DST/config.yaml $DST/.env $DST/cron/jobs.json
"
```

`~/.hermes` existe déjà (le code Hermes y est installé en §2). Les seuls chemins
absolus à réécrire sont `DONSETCH_CACHE_DIR` et `BLADE_HOME` dans `config.yaml`,
`APPLE_MUSIC_P8_PATH` dans `.env`, et les scripts cités par `cron/jobs.json` —
d'où le `sed`. Les `skills/` peuvent encore mentionner `/opt/data` dans leur
documentation : à rafraîchir à l'usage, ça ne bloque pas l'exécution.

Retirer aussi le workaround conteneur :

```sh
incus exec mercure -- sed -i '/DONGHOST_NO_SANDBOX/d' "$DST/config.yaml"
```

`config.yaml` contient des credentials en clair (`GITHUB_TOKEN`, clés Karakeep) :
il est en 0600, ne le copie pas hors de la VM.

### 4. Gateway + dashboard

```sh
# root ne résout pas ~/.hermes tout seul : expliciter le défaut de raphaelgc
incus exec mercure -- sudo env HERMES_HOME=/home/raphaelgc/.hermes \
  /home/raphaelgc/.local/bin/hermes gateway install --system \
  --run-as-user raphaelgc --start-now

# linger : requis pour les cron jobs
incus exec mercure -- loginctl enable-linger raphaelgc
```

`--system` installe une unité system-level (démarrage au boot), `--run-as-user`
fixe l'utilisateur et `HERMES_HOME` pointe sur le défaut (`~/.hermes` de
raphaelgc). L'unité s'appelle `hermes-gateway` ou `hermes-gateway-<hash>` :
récupère-la plutôt que de la deviner —

```sh
UNIT=$(incus exec mercure -- systemctl list-unit-files --no-legend 'hermes-gateway*' | awk '{print $1}')
```

`systemctl status|stop 'hermes-gateway*'` marche sur une unité chargée, mais pour
la (re)démarrer après un arrêt, utilise `$UNIT` — un glob ne relance pas une
unité déchargée. Éviter `hermes gateway stop|restart` en root : la commande
vérifie que le home appartient à l'utilisateur appelant et refuse
(`unsafe_control_path`).

Si l'install échoue sur `refusing to update …hermes-agent` ou `no dependency
environment is committed`, une mise à jour a été interrompue : la finir en
`raphaelgc` (`hermes update`, puis `hermes pm repair` si demandé), jamais en root.

Le dashboard web n'est **pas** couvert par le service du gateway : il a sa propre
unité. Écouter sur `0.0.0.0` active l'auth gate, dont les identifiants sont
`HERMES_DASHBOARD_BASIC_AUTH_*` dans `~/.hermes/.env`.

```sh
incus exec mercure -- bash -c 'cat >/etc/systemd/system/hermes-dashboard.service <<"EOF"
[Unit]
Description=Hermes Agent Web Dashboard
After=network-online.target
Wants=network-online.target

[Service]
User=raphaelgc
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
volontairement de démarrer (port déjà servi). Le service tourne en `raphaelgc`,
donc `HOME=~` et le home par défaut ; le process lit lui-même `~/.hermes/.env`,
pas d'`EnvironmentFile`. Si les extras web manquent, `hermes dashboard` affiche
la commande à lancer.

Vérification :

```sh
incus exec mercure -- su - raphaelgc -c 'hermes doctor'
incus exec mercure -- systemctl is-active $UNIT hermes-dashboard
```

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

### 7. Backups (Hermes, hors VM)

Le pool incus n'est pas dans restic. La sauvegarde, c'est Hermes :

```sh
# snapshot complet (config, skills, sessions, state.db) dans la VM
incus exec mercure -- su - raphaelgc -c 'hermes backup -o /home/raphaelgc/hermes.zip'

# le sortir de la VM pour la rétention (restic voit /data)
incus file pull mercure/home/raphaelgc/hermes.zip /data/backups/

# restauration
incus exec mercure -- su - raphaelgc -c 'hermes import /home/raphaelgc/hermes.zip'
```

`--quick` limite le zip aux fichiers critiques (config, state.db, .env, auth,
cron) ; sans option, tout `$HERMES_HOME` sauf le code.

## Ce que la VM règle

- Chromium avec sandbox réel (les user namespaces fonctionnent dans la VM), et un
  paquet `chromium` Debian maintenu : plus de `--no-sandbox`, plus de
  `DONGHOST_NO_SANDBOX`, plus de snap.
- `hermes update` fonctionnel (contrairement à l'install Docker).
- SQLite sur un ext4 local : plus de contraintes de partage (WAL, verrous).
- Plus de mapping UID 1000 ni de hook s6.
- Isolation réelle : root dans la VM, aucun accès à jupiter.

## Rollback

| Incident | Action |
|---|---|
| La VM ne démarre plus | `incus snapshot restore mercure <snap>` |
| Données abîmées | `hermes import <zip>` (backup §7) |
| Hermes cassé | `docker start hermes-agent` (données du conteneur intactes) |
| Module à retirer | `enable = false` + `nh os switch .` (l'instance survit) |

## Points non vérifiés

- `/dev/kvm` sur jupiter (à contrôler avant tout).
- Le chemin de `hermes` après `install.sh` (`~/.local/bin/hermes`) : à confirmer
  au premier passage, l'unité systemd le suppose.
- Les MCP `npx -y` téléchargent donsetch/bladebro au premier démarrage : à
  vérifier dans les logs (`mcp-stderr.log`) si un serveur reste muet.
