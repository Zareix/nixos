# nixos

## Usage

```sh
echo '{ pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  environment.systemPackages = [
    pkgs.vim
  ];
}' >/etc/nixos/configuration.nix
nix-channel --update
nixos-rebuild switch

echo '#! /usr/bin/env nix-shell
#! nix-shell -i bash -p git git-crypt

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

cd /etc
rm -rf nixos
git clone https://github.com/Zareix/nixos
cd nixos

read -r -p "Enter secret-key in base64: " secret_key
echo "$secret_key" | base64 -d >./.secret-key
git-crypt unlock ./.secret-key

nix-channel --update
if [ -z "$1" ]; then
  nixos-rebuild switch --flake .
else
  nixos-rebuild switch --flake ".#${1}"
fi
' >/tmp/setup.sh
chmod +x /tmp/setup.sh
nix-channel --update
/tmp/setup.sh lxc
```
