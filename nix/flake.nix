{
  description = "Isolated CyberArch Hyprland and AGS runtime for Ubuntu";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/e03f211152d22378ff43ee309ee83b906fe62705";
    ags.url = "github:Aylur/ags/a6a7a0adb17740f4c34a59902701870d46fbb6a4";
    astal.url = "github:Aylur/astal/127e9cdcbf173846a3c40ddc0abfbb038df48042";
    ags.inputs.nixpkgs.follows = "nixpkgs";
    ags.inputs.astal.follows = "astal";
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
