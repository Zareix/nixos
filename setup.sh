#!/usr/bin/env nix-shell
#!nix-shell -p git-crypt -i bash
# shellcheck shell=bash

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
nixos-rebuild switch --flake .
