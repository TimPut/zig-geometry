{
  description = "Mach is a game engine & graphics toolkit for the future.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = { self, zig, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      lib = pkgs.lib;
    in {
      devShell.x86_64-linux = pkgs.mkShell {
        packages = [
          zig.packages.x86_64-linux.master
          pkgs.xorg.libX11
          pkgs.libGL
          pkgs.libsoundio
          pkgs.alsa-lib
        ];
        LD_LIBRARY_PATH = "${lib.makeLibraryPath [ pkgs.libGL pkgs.vulkan-loader ]}";
      };
    };
}
