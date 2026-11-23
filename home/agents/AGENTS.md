# Environnement de l'hôte

Cette machine tourne sous **NixOS** (configuration déclarative avec flakes et Home Manager).

- **Configuration système** : définie dans le flake `/etc/nixos` et appliquée via `nh os switch /etc/nixos` (ou `nixos-rebuild switch --flake /etc/nixos`).
- **Paquets et services** : tout est déclaratif ; éviter les modifications impératives dans `/etc` ou les installations système directes. Pour un outil ponctuel, utiliser `nix shell nixpkgs#<pkg>` ou `nix run nixpkgs#<pkg>`.
- **Home Manager** : gère les dotfiles et la config utilisateur (`~/.config`, `zsh`, etc.) via des liens symboliques en lecture seule vers `/nix/store`.
- **Secrets** : gérés par `sops-nix` (chiffrés dans le dépôt, déchiffrés automatiquement sur l'hôte).
- **Binaires externes** : `nix-ld` est activé pour exécuter des binaires dynamiques standards si besoin.
- **Services courants** : Docker (utilisateur dans le groupe `docker`), Tailscale, `direnv`, `tmux`, `git`/`gh`.
- **Stacks Docker** :
  - `/data/stacks` : définitions des stacks Docker Compose (fichiers `compose.yaml`, configuration de déploiement, etc.).
  - `/data/apps` : données persistantes et volumes des applications (configs applicatives, bases de données, fichiers générés).
