{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    devenv.url = "github:cachix/devenv";
    zig.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls";
    zls.inputs.nixpkgs.follows = "nixpkgs";
    zls.inputs.zig-overlay.follows = "zig";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, zig, devenv, zls, ... } @ inputs:
    let
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      zigpkg = zig.packages."x86_64-linux";
      zlspkg = zls.packages."x86_64-linux";
    in
    {
      devShell.x86_64-linux = devenv.lib.mkShell {
        inherit inputs pkgs;

        modules = [
          ({ pkgs, lib, ... }: {

            # This is your devenv configuration
            packages = [
              zlspkg.zls
              zigpkg.master
              pkgs.zls
              pkgs.nodePackages.nodemon
            ];

            enterShell = ''
            '';
          })
        ];
      };
    };
}
