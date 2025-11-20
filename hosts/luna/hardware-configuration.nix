{
  lib,
  modulesPath,
  config,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "sr_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/21f99bfd-3c4a-4bf9-ac2c-c3969910e463";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A8F0-4010";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };
  fileSystems."/mnt/usbhdd1" = {
    device = "/dev/disk/by-uuid/89c7b709-8627-4a88-b6f6-46a33e98a880";
    fsType = "ext4";
  };

  swapDevices = [];

  networking = {
    interfaces = {
      eno1.ipv4.addresses = [
        {
          address = "192.168.0.99";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      interface = "eno1";
      address = "192.168.0.1";
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
