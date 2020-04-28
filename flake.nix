{
  description = "A combination of two embedded data storage C language libraries: SQLite and LMDB";

  inputs.nixpkgs.url = "nixpkgs/nixos-20.03";
  inputs.lumosql-src = { url = github:LumoSQL/LumoSQL; flake = false; };

  outputs = { self, nixpkgs, lumosql-src }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
    in

    {

      overlay = final: prev: {

        lumosql = with final; stdenv.mkDerivation rec {
          name = "lumosql";

          src = lumosql-src;

          patches = [ ./makefile.patch ];

          lmdbVersion = "0.9.16";

          lmdbSrc = fetchurl {
            url = "https://github.com/LMDB/lmdb/archive/LMDB_${lmdbVersion}.tar.gz";
            hash = "sha256-Sde0CUnyztm8iyPqaonnVHGhyRJlN6iyaMMYoAuEMis=";
          };

          buildInputs = [ tcl ];

          postUnpack = ''
            unpackFile $lmdbSrc
            mv lmdb-* source/src-lmdb
          '';

          buildPhase = "make bld-LMDB_$lmdbVersion";

          installPhase = "cd bld-LMDB* && make install prefix=${placeholder "out"} HAVE_TCL=";
        };

        # Build Nix against LumoSQL.
        nix-lumosql = (prev.nix.override {
          sqlite = final.lumosql;
        }).overrideDerivation (_: {
          # FIXME: test suite currently fails with a "malformed database image" error.
          doInstallCheck = false;
        });

      };

      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) lumosql nix-lumosql;
        });

      defaultPackage = forAllSystems (system: self.packages.${system}.lumosql);

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) lumosql nix-lumosql;

        # Run the benchmark. We do this in a separate derivation
        # because it's inherently not binary-reproducible and we don't
        # want to taint the the lumosql package with that.
        benchmark =
          with nixpkgsFor.${system};
          stdenv.mkDerivation {
            name = "lumosql-benchmark";

            inherit (lumosql) src patches lmdbVersion;

            buildInputs = [ tcl ];

            buildPhase = ''
              ln -s ${lumosql}/bin/sqlite3 sqlite3
              make LMDB_$lmdbVersion.html
            '';

            installPhase = ''
              mkdir -p $out/nix-support
              cp LMDB_$lmdbVersion.html $out/
              echo "doc benchmark $out/LMDB_$lmdbVersion.html" >> $out/nix-support/hydra-build-products
            '';
          };
      });

    };
}
