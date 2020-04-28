{
  description = "A combination of two embedded data storage C language libraries: SQLite and LMDB";

  inputs.nixpkgs.url = "nixpkgs/nixos-20.03";
  inputs.lumosql-src = { url = github:LumoSQL/LumoSQL; flake = false; };

  outputs = { self, nixpkgs, lumosql-src }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
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
            pwd
            unpackFile $lmdbSrc
            mv lmdb-* source/src-lmdb
            ls -l source
          '';

          buildPhase = "make bld-LMDB_$lmdbVersion";

          installPhase = "cd bld-LMDB* && make install prefix=${placeholder "out"} HAVE_TCL=";
        };

      };

      defaultPackage = forAllSystems (system: (import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      }).lumosql);

      checks = forAllSystems (system: {
        build = self.defaultPackage.${system};
      });

    };
}
