{ ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          # git pre-commit Rust alternative
          pkgs.prek
          pkgs.figlet

          # D toolchain
          pkgs.ldc
          pkgs.dub
          pkgs.dtools
          pkgs.pkg-config

          # Libraries
          pkgs.SDL2
        ];

        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.SDL2 ];

        shellHook = ''
          figlet 'Chess2RT'
        ''
        + config.pre-commit.installationScript;
      };
    };
}
