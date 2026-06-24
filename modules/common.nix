{lib, ...}: {
  imports =
    lib.filesystem.listFilesRecursive ./zrx
    ++ lib.filesystem.listFilesRecursive ./core;
}
