{ lib
, buildPythonPackage
, fetchPypi
, setuptools
, wheel
}:

buildPythonPackage rec {
  pname = "uv";
  version = "0.1.39";

  src = fetchPypi {
    inherit pname version;
    hash = lib.fakeSha256;
  };

  doCheck = false;

  pyproject = true;
  build-system = [
    setuptools
    wheel
  ];
}