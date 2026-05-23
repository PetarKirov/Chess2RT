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

      chess2rt-data = builtins.path {
        name = "chess2rt-data";
        path = fromRoot "data";
      };
    in
    {
      packages = {
        inherit chess2rt-data;

        chess2rt = pkgs.buildDubPackage (finalAttrs: {
          pname = "chess2rt";
          version = "0.1.0";

          src = fs.toSource {
            inherit root;
            fileset = fs.unions [
              (fs.fileFilter isDubManifest root)
              (fs.fileFilter (file: file.hasExt "d") (fromRoot "source"))
            ];
          };

          dubLock = ./dub.lock.json;

          installPhase = ''
            runHook preInstall
            install -Dm755 bin/Linux64/${finalAttrs.pname} -t $out/bin
            runHook postInstall
          '';

          meta.mainProgram = finalAttrs.pname;
        });

        default =
          pkgs.runCommand "chess2rt"
            {
              nativeBuildInputs = [ pkgs.makeWrapper ];
              meta.mainProgram = "chess2rt";
            }
            ''
              mkdir -p $out/bin
              makeWrapper \
                ${lib.getExe config.packages.chess2rt} \
                $out/bin/chess2rt \
                --set CHESS2RT_DATA_DIR ${chess2rt-data} \
                --prefix LD_LIBRARY_PATH : \
                ${lib.makeLibraryPath [ pkgs.SDL2 ]}
            '';
      };
    };
}
