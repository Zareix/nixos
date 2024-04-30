{ stdenv, fetchurl, lib }:

let
 systemMap = {
    x86_64-linux = "x86_64-unknown-linux-gnu";
    aarch64-linux = "aarch64-unknown-linux-gnu";
 };

 githubRelease = { version, sha256, system ? builtins.currentSystem }:
    let
      systemType = systemMap.${system} or (throw "unsupported system: ${system}");

      url = "https://github.com/astral-sh/uv/releases/download/${version}/uv-${systemType}.tar.gz";
    in
    stdenv.mkDerivation {
      src = fetchurl {
        inherit url sha256;
      };
      sourceRoot = ".";
      installPhase = ''
        mkdir -p $out/bin
        mv uv $out/bin
      '';
    };
in
{
 # Example usage
 uv = githubRelease {
    version = "0.1.39";
    sha256 = "000000000000000000000000000000000000000000000000000";
 };
}
