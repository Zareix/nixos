# nixos

## Deploy script (new host)

### 1. Get new host's age pubkey

Boot the host (live ISO or minimal install). SSH host key is generated at first boot.
Run locally (requires SSH reachable):

```sh
ssh-keyscan <host-ip> 2>/dev/null | grep ed25519 | ssh-to-age
```

### 2. Add host key to `.sops.yaml` (on your machine)

```yaml
- &newhostname age1...  # paste key from step 1
```

Add `*newhostname` to all `key_groups` in creation rules, then re-encrypt:

```sh
sops updatekeys secrets/common.yaml
sops updatekeys secrets/home.yaml
git add .sops.yaml secrets/
git commit -m "feat: add newhostname sops key"
git push
```

### 3. Add host to `flake.nix` and `hosts/`

Add entry to the `hosts` list and create `hosts/newhostname/` directory with config.

### 4. Deploy on the new host

```sh
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf

nix-channel --update
nix-env -f '<nixpkgs>' -iA git

cd /etc
mv nixos nixos.bak
git clone https://github.com/Zareix/nixos
cd nixos
git config --global --add safe.directory /etc/nixos
```

Verify config, copy old `hardware-configuration.nix` from `nixos.bak` if exists, then run:

```sh
nixos-rebuild switch --flake .#newhostname
```

sops-nix decrypts secrets automatically using `/etc/ssh/ssh_host_ed25519_key`. No key import needed.

## Update

On the first machine:

```sh
cd /etc/nixos
git pull
nix flake update
nh os switch . --ask
git add .
git commit -m "chore: update"
git push
```

On other machines:

```sh
cd /etc/nixos
git pull
nh os switch .
```

## Secrets

Edit existing secrets:

```sh
sops secrets/common.yaml   # system secrets
sops secrets/home.yaml     # home secrets
```

Requires `SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt` in environment.
