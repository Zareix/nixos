# Hermes Agent en VM Ubuntu sur jupiter

Remplace le conteneur Docker `jupiter/hermes-agent` (repo `Zareix/docker`) par une VM
Incus **Ubuntu 24.04** pilotée depuis ce flake.

- **Déclaratif (ce repo)** : daemon incus, pool de stockage, bridge, réservation DHCP,
  cloud-init, script de provisioning, unités systemd de création/provisioning,
  secrets sops.
- **Non déclaratif (assumé)** : l'intérieur de la VM (apt, `hermes update`, npm, pip).
  C'est le prix de la flexibilité ; la compensation est le snapshot incus avant
  chaque changement.

## Ce que le module crée

| Ressource | Valeur par défaut |
|---|---|
| Instance | `hermes` (VM, pas conteneur) |
| Image | `images:ubuntu/24.04` (incus-agent déjà présent → `incus exec` fonctionne) |
| CPU / RAM | 4 vCPU / 6 GiB |
| Pool | `hermes`, driver `dir`, source `/data/apps/incus` |
| Réseau | bridge `incusbr0`, `10.42.0.0/24`, IP réservée `10.42.0.10` |
| Disque données | volume bloc `hermes-data` (120 GiB) → `/opt/data` dans la VM |

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
# hermes-vm-env: |
#   OPENCODE_GO_API_KEY=...
#   HERMES_DASHBOARD_BASIC_AUTH_USERNAME=...
#   ...
```

Puis dans `hosts/jupiter/default.nix` :

```nix
envFile = config.sops.secrets."hermes-vm-env".path;
```

(Laisser `envFile = null` tant que la clé n'existe pas : sinon l'activation
`sops-install-secrets` échoue et casse le rebuild.)

### 2. Activer et construire

```sh
git pull && nh os switch .
systemctl status hermes-vm hermes-vm-provision     # ~5-10 min au premier boot
incus list                                          # hermes RUNNING, IP 10.42.0.10
incus exec hermes -- journalctl -u hermes-gateway -f
```

### 3. Migrer l'état du conteneur

```sh
sudo bash hosts/jupiter/hermes-vm/migrate.sh
```

Le conteneur est **arrêté, pas supprimé** : `docker start hermes-agent` suffit à
revenir en arrière.

### 4. Mnemosyne (étape manuelle, une fois)

Le quirk n'est pas lié à Docker : le provider doit vivre dans un side-venv,
parce que Hermes bascule `sys.path` sur son environnement managé au démarrage.
Après la migration, dans la VM :

```sh
incus exec hermes -- su - hermes
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

incus exec hermes -- systemctl restart hermes-gateway
incus exec hermes -- su - hermes -c 'HERMES_HOME=/opt/data hermes memory status'
# attendu : Plugin: installed ✓ / Status: available ✓
```

Si l'ancien `plugins/mnemosyne` est un lien symbolique vers un site-packages
disparu, le supprimer avant l'étape `--mode wrapper`.

### 5. Accès réseau

- Dashboard en tailnet-only sous `zrx.sh` (convention maison) : installer tailscale
  dans la VM, `tailscale up`, puis router Traefik vers `10.42.0.10:9119`.
- Traefik ne peut plus lire les labels Docker : la route devient statique
  (fichier de provider) — c'est la seule régression fonctionnelle du passage en VM.

## Ce que la VM règle

- Chromium avec sandbox réel (les user namespaces fonctionnent dans la VM) :
  plus de `--no-sandbox`, plus de `DONGHOST_NO_SANDBOX`.
- `hermes update` fonctionnel (contrairement à l'install Docker).
- Plus de DirtyFile : ni `gh`, ni `pnpm`, ni binaire donsetch root-owned à installer
  au build — `apt` + `npm -g` fonctionnent.
- Plus de mapping UID 1000 ni de hook s6.
- Isolation réelle : root dans la VM, aucun accès à jupiter.

## Rollback

| Incident | Action |
|---|---|
| La VM ne démarre plus | `incus snapshot restore hermes <snap>` (snapshot avant chaque changement) |
| Hermes cassé après migration | `docker start hermes-agent` (état intact) |
| Provisioning à rejouer | `systemctl restart hermes-vm-provision` |
| Module à retirer | `enable = false` + `nh os switch .` (l'instance et son volume survivent) |

## Points non vérifiés

- `/dev/kvm` sur jupiter (à contrôler avant tout).
- `incus config device set|override eth0 ipv4.address` : la commande qui marche
  dépend de la version d'incus ; le module essaie les deux et avertit.
- SQLite doit rester sur le volume bloc (pas de virtiofs) — c'est le cas ici.
