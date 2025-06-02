{...}: {
  networking = {
    hostName = "rpi";
    interfaces.end0 = {
      ipv4.addresses = [
        {
          address = "192.168.0.99";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      address = "192.168.0.1";
      interface = "end0";
    };
    nameservers = [
      "192.168.0.1"
    ];
  };
}
