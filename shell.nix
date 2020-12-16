{ pkgs ? import <nixpkgs> { } }: with pkgs;
mkShell {
  nativeBuildInputs = [
    dmd
    ldc
    dub
  ];

  buildInputs = [
    SDL2
  ];

  shellHook = ''
    export LD_LIBRARY_PATH=${SDL2}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
  '';
}
