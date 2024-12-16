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

- Then open a shell in the container and run following commands :

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

nixos-rebuild switch --flake .
```

### To deploy on Hetzner

- We'll use [nixos-infect](https://github.com/elitak/nixos-infect)
- First boot with server using a default OS like Ubuntu 22.04
- Then add the following to cloud-init

```yaml
#cloud-config

runcmd:
  - curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | PROVIDER=hetznercloud NIX_CHANNEL=nixos-24.05 bash 2>&1 | tee /tmp/infect.log
```

- Wait a few minutes for nixos-infect to finish
- Then ssh to the server and run following commands :

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

nixos-rebuild switch --flake .
```

## Update

On the first machine :

```sh
cd /etc/nixos
sudo git pull
sudo nix flake update
sudo nix-channel --update
sudo nixos-rebuild switch --flake .
sudo git add .
sudo git commit -m "update"
sudo git push
```

On other machines :

```sh
cd /etc/nixos
sudo git pull
sudo nix-channel --update
sudo nixos-rebuild switch --flake .
```
