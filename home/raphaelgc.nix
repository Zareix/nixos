{ globals, ... }:
{
  home = {
    username = globals.username;
    homeDirectory = "/home/${globals.username}";
  };
}
