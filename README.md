# nixos

## Usage

### To deploy in a proxmox lxc container

- Create a new privileged container with nesting enabled.
- In proxmox edit file `/etc/pve/lxc/<lxc-id>.conf` and add following lines for Tailscale :

```plain
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

- Optionally, add following lines for GPU passthrough :

```plain
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/dri/renderD128 dev/renderD128 none bind,optional,create=file
```

## Deploy script

```sh
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf

nix-channel --update
nix-env -f '<nixpkgs>' -iA git
nix-env -f '<nixpkgs>' -iA git-crypt

cd /etc
mv nixos nixos.bak
git clone https://github.com/Zareix/nixos
cd nixos

read -r -p "Enter secret-key in base64: " secret_key
echo "$secret_key" | base64 -d >./.secret-key
git-crypt unlock ./.secret-key
git config --global --add safe.directory /etc/nixos
```

Verify config, copy old `hardware-configuration.nix` from `nixos.bak` if exists, then run

```sh
nixos-rebuild switch --flake .
```

## Update

On the first machine :

```sh
cd /etc/nixos
git pull
nix flake update
nh os switch . --ask
git add .
git commit -m "chore: update"
git push
```

On other machines :

```sh
cd /etc/nixos
git pull
nh os switch .
```
