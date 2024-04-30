#!/usr/bin/env nix-shell
#!nix-shell -p git-crypt -i bash

set -e

# ensure is root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

cd /etc
rm -rf nixos
git clone https://github.com/Zareix/nixos
cd nixos

# prompt user for secret-key-base64
read -r -p "Enter secret-key-base64: " secret_key
echo "$secret_key" | base64 -d >./.secret-key
git-crypt unlock ./.secret-key

# update nix channel
nix-channel --update

# rebuild nixos
nixos-rebuild switch --flake .
