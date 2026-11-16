{globals, ...}:
# cloud-init de mercure. Généré par Nix pour que le nom d'utilisateur vienne de
# `globals.username` (vars.nix) au lieu d'être recopié ici.
''
  #cloud-config
  # Invité Debian (trixie) pour mercure — image cloud, sans GUI.
  # Volontairement minimal : le reste (paquets utiles, Hermes, service) se fait à
  # la main, voir hosts/jupiter/mercure/README.md §2.

  timezone: Europe/Paris
  package_update: true
  package_upgrade: false

  packages:
    - qemu-guest-agent
    - ca-certificates
    - curl
    - git
    - jq

  runcmd:
    - systemctl enable --now qemu-guest-agent
    # L'image fournit `debian` en uid/gid 1000 : on le renomme au nom de
    # vars.nix, uid et gid conservés (c'est ce qui possède /opt/data).
    - |
      set -eu
      if ! id ${globals.username} >/dev/null 2>&1 && id debian >/dev/null 2>&1; then
        usermod -l ${globals.username} -d /home/${globals.username} -m debian
        groupmod -n ${globals.username} debian
        printf '%s ALL=(ALL) NOPASSWD:ALL\n' ${globals.username} > /etc/sudoers.d/90-cloud-init-users
        chmod 0440 /etc/sudoers.d/90-cloud-init-users
      fi
''
