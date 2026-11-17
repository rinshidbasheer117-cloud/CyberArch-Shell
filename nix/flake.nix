{
  description = "Isolated CyberArch Hyprland and AGS runtime for Ubuntu";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/e03f211152d22378ff43ee309ee83b906fe62705";
    ags.url = "github:Aylur/ags/bbee2f18939f1ec7ff720e717cf305e73635628f";
    ags.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ags }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system}.default = pkgs.symlinkJoin {
        name = "cyberarch-runtime";
        paths = [
          pkgs.hyprland
          ags.packages.${system}.agsFull
          pkgs.xwayland
          pkgs.dbus
          pkgs.wayland
          pkgs.xdg-utils
          pkgs.libnotify
          pkgs.playerctl
          pkgs.networkmanager
          pkgs.pavucontrol
          pkgs.wireplumber
          pkgs.brightnessctl
          pkgs.procps
          pkgs.gawk
          pkgs.gnugrep
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnused
          pkgs.bash
        ];
      };
    };
}
