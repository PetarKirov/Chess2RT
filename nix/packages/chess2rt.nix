# Nix derivation for Chess2RT.
{ lib, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      fs = lib.fileset;
      root = ../..;
      fromRoot = lib.path.append root;

      isDubManifest =
        file:
        builtins.elem file.name [
          "dub.sdl"
          "dub.selections.json"
        ];

      src = fs.toSource {
        inherit root;
        fileset = fs.unions [
          (fs.fileFilter isDubManifest root)
          (fs.fileFilter (file: file.hasExt "d") (fromRoot "source"))
        ];
      };
    in
    {
      packages.chess2rt = pkgs.buildDubPackage (finalAttrs: {
        pname = "chess2rt";
        version = "0.1.0";

        inherit src;

        dubLock = ./dub.lock.json;

        buildInputs = [
          pkgs.SDL2
        ];

        nativeBuildInputs = [
          pkgs.pkg-config
          pkgs.makeWrapper
        ];

        installPhase = ''
          runHook preInstall
          install -Dm755 bin/Linux64/${finalAttrs.pname} -t $out/bin
          runHook postInstall
        '';

        postInstall = ''
          wrapProgram $out/bin/${finalAttrs.pname} \
            --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.SDL2 ]}
        '';

        meta.mainProgram = finalAttrs.pname;
      });

      packages.default = config.packages.chess2rt;
    };
}
