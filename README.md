# nixos

## Usage

### To deploy in a proxmox lxc container

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
mv -r nixos nixos.bak
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

git config --global --add safe.directory /etc/nixos
' >/tmp/setup.sh
chmod +x /tmp/setup.sh
nix-channel --update
/tmp/setup.sh <name>
```

### To deploy on Hetzner

- First boot with server using a default OS like Ubuntu 22.04
- Then run nixos-infect script :

  ```sh
  curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-24.05 bash -x
  ```

- Then run following commands :

  ```sh
  echo '#! /usr/bin/env nix-shell
  #! nix-shell -i bash -p git git-crypt

  set -e

  if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
  fi

  cd /etc
  mv nixos nixos.bak
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

  git config --global --add safe.directory /etc/nixos
  ' >/tmp/setup.sh
  chmod +x /tmp/setup.sh
  nix-channel --update
  /tmp/setup.sh <name>
  ```

## Update

```sh
cd /etc/nixos
sudo nix flake update
sudo nix-channel --update
sudo nixos-rebuild switch --flake .#lxc
```
