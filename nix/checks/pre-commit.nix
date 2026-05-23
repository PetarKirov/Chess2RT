{ lib, ... }:
let
  generatedJsonFiles = [
    # Nix Flake lock file
    "flake.lock"

    # DUB lock and selections (dub.selections.json is managed by dub itself;
    # dub.lock.json is emitted by `nix run nixpkgs#dub-to-nix`).
    "nix/packages/dub.lock.json"
    "dub.selections.json"
  ];
in
{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.pre-commit =
        let
          inherit (config.pre-commit.settings)
            enabledPackages
            package
            configFile
            ;
        in
        pkgs.mkShell {
          packages = enabledPackages ++ [ package ];
          shellHook = ''
            ln -fvs ${configFile} .pre-commit-config.yaml
            echo "Running Pre-commit checks"
            echo "========================="
          '';
        };

      # impl:
      # https://github.com/cachix/git-hooks.nix/blob/master/flake-module.nix
      pre-commit = {
        # Disable `checks` flake output
        check.enable = false;

        # Enable commonly used formatters
        settings = {
          # Use Rust-based alternative to pre-commit:
          # * https://github.com/j178/prek
          # * https://prek.j178.dev/
          package = pkgs.prek;

          excludes = [ "^.*\.age$" ];

          hooks = {
            editorconfig-checker = {
              enable = true;
              excludes = [
                "^dub\\.selections\\.json$"
                "^dub\\.sdl$"
                "^source/.*$"
                "^data/.*$"
                "^perf-results\\.md$"
                "^README\\.md$"
                "^\\.envrc$"
              ];
            };

            # *.nix formatting
            nixfmt.enable = true;

            # *.{js,jsx,ts,tsx,css,html,md,json} formatting
            prettier = {
              enable = true;
              args = [
                "--check"
                "--list-different=false"
                "--log-level=warn"
                "--ignore-unknown"
                "--write"
              ];
              excludes = map lib.escapeRegex generatedJsonFiles;
            };
          };

          # Prek built-in hooks:
          # https://prek.j178.dev/builtin/#supported-hooks_1
          rawConfig.repos = [
            {
              repo = "builtin";
              hooks = [
                { id = "trailing-whitespace"; }
                { id = "check-added-large-files"; }
                { id = "check-case-conflict"; }
                { id = "check-illegal-windows-names"; }
                { id = "file-contents-sorter"; }
                { id = "fix-byte-order-marker"; }
                { id = "check-json"; }
                { id = "check-json5"; }
                { id = "check-toml"; }
                { id = "check-vcs-permalinks"; }
                { id = "check-yaml"; }
                { id = "check-xml"; }
                {
                  id = "mixed-line-ending";
                  args = [ "--fix=lf" ];
                }
                { id = "check-symlinks"; }
                { id = "destroyed-symlinks"; }
                { id = "check-merge-conflict"; }
                { id = "detect-private-key"; }
                { id = "no-commit-to-branch"; }
                { id = "check-shebang-scripts-are-executable"; }
                { id = "check-executables-have-shebangs"; }
              ];
            }
          ];
        };
      };
    };
}
