{ username, ... }:
{
  home = {
    username = username;
    homeDirectory = "/root";
  };
}
