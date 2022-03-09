let
  pkgs = import (builtins.fetchGit rec {
    name = "dapptools-${rev}";
    url = https://github.com/dapphub/dapptools;
    rev = "42a807306188cd20b1fe925ffe469979e2802b82";
  }) {};

in
  pkgs.mkShell {
    src = null;
    name = "dapptools-template";
    buildInputs = with pkgs; [
      pkgs.dapp
      pkgs.seth
      pkgs.go-ethereum-unlimited
      pkgs.hevm
    ];
  }
