{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "virtio_pci" "sr_mod" "virtio_blk"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/f222513b-ded1-49fa-b591-20ce86a2fe7f";
    fsType = "ext4";
  };
  fileSystems."/mnt/mass" = {
    device = "/dev/disk/by-uuid/e59ec576-6efd-4f7f-bd91-b39b6b16ee46";
    fsType = "ext4";
    options = ["nofail" "defaults"];
  };

  swapDevices = [];

  networking = {
    interfaces = {
      eth0.ipv4.addresses = [
        {
          address = "192.168.31.205";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      interface = "eth0";
      address = "192.168.31.1";
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
