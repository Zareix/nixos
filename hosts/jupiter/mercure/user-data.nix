{globals, ...}:
# cloud-init de mercure. Généré par Nix pour que le nom d'utilisateur vienne de
# `globals.username` (vars.nix) au lieu d'être recopié ici.
''
  #cloud-config
  # Invité Debian (trixie) pour mercure — image cloud, sans GUI.
  # Volontairement minimal : le reste (paquets utiles, Hermes, service) se fait à
  # la main, voir hosts/jupiter/mercure/README.md §2.

  # L'image crée l'utilisateur par défaut en uid 1000 (sudo NOPASSWD inclus) :
  # on lui donne directement le nom de vars.nix. Un renommage en runcmd ferait
  # échouer ssh-authkey-fingerprints, qui cherche encore `debian`.
  system_info:
    default_user:
      name: ${globals.username}

  timezone: Europe/Paris
  package_update: true
  package_upgrade: false

  packages:
    - ca-certificates
    - curl
    - git
    - jq
''
