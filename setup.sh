#!/usr/bin/env nix-shell
#!nix-shell -p git -p git-crypt -i bash
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

secret_key=''
if [ -n "$1" ]; then
  secret_key="$1"
else
  read -r -p "Enter secret-key in base64: " secret_key
fi

echo "$secret_key" | base64 -d >./.secret-key
git-crypt unlock ./.secret-key

nix-channel --update
nixos-rebuild switch --flake ".#${2:-nixos}"
