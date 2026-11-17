# CyberArch Shell on Ubuntu with Nix

## Intent

Make the user's CyberArch Shell fork installable as an optional Hyprland session on Ubuntu 26.04 GNOME. The goal is to use the full CyberArch HUD while keeping the existing GNOME desktop, GDM login manager, and Ubuntu package installation usable.

## Goals

- Add an Ubuntu-specific install path that uses Nix for Hyprland and the shell runtime/dependencies instead of Arch's `pacman` and AUR.
- Keep the existing Arch installation path intact.
- Install a selectable Hyprland session alongside GNOME through GDM.
- Back up existing Hyprland configuration before modifying it; avoid overwriting user configuration.
- Provide a corresponding uninstall path that removes only artifacts created by this installer and leaves Nix's shared store, GDM, GNOME, and Ubuntu packages intact.
- Make the installer's operations and any required privileged writes explicit and reversible.
- Keep GTK, icon, cursor, Kitty, and color-scheme changes local to the Hyprland session; do not change GNOME's persistent `gsettings` values or overwrite the user's existing application configuration.

## Non-goals and anti-goals

- Do not port the theme to GNOME Shell; it remains a Hyprland shell.
- Do not replace or disable GDM, install SDDM, alter PAM, change the default session, or configure the theme lock screen.
- Do not change GNOME's persistent appearance preferences or stop/replace applications in the GNOME session as a side effect of starting Hyprland.
- Do not run `apt upgrade`, alter Ubuntu repositories, or remove system packages.
- Do not install optional terminal emulators, login screens, or system theming as a prerequisite for the core HUD session.

## Constraints

- Target this computer's Ubuntu 26.04 x86_64 GNOME/Wayland setup first; detect and clearly reject unsupported distributions or architectures.
- Keep the Hyprland and theme runtime in a dedicated Nix profile, using a pinned Nixpkgs revision so the dependency set is reproducible.
- If Nix is absent, explain that the official multi-user installer creates `/nix`, build users, and a systemd daemon, then require an explicit interactive confirmation before invoking it.
- Create the GDM session entry under `/usr/local/share/wayland-sessions` with only the privileges needed for that file; never change the `display-manager.service` link or enabled state.
- Store theme configuration and state under the user's home directory. Back up files before updating them, and record ownership so uninstall does not remove pre-existing content.
- Do not run Nix, APT, or system services as part of build-time checks.

## Approaches considered

1. **Nix alongside GNOME (selected).** A dedicated Nix profile isolates Hyprland and the theme runtime from Ubuntu's older Hyprland package and APT dependency graph. The installer adds an optional GDM session and leaves the existing display manager and default session unchanged. This is the selected route because the user chose it and requested the current system remain safe.
2. **Ubuntu APT packages.** This would be simpler to maintain, but the available Hyprland package is older than the project's documented target and its package names do not match the Arch installer. It was rejected due to compatibility uncertainty.
3. **Rebuild this as a GNOME Shell theme.** This would avoid adding a compositor but would not run the requested Hyprland HUD and would be a separate product, so it is out of scope.

## Design

- Add an Ubuntu route to `install.sh` that dispatches to a separate Ubuntu/Nix installer while retaining the current Arch route.
- Package the session runtime and required command-line tools in a project Nix flake with a committed lock file. Prefer Nixpkgs packages for Hyprland, AGS/Astal, and supported utilities; follow the APIs used by the current source because the README's AGS v3 label and the installer's AGS v2 checks disagree. Fail during preflight with a clear missing-package report if any required component is unavailable, rather than falling back to APT or an unreviewed third-party installer.
- Generate a per-user Hyprland launch wrapper that supplies the Nix runtime environment and starts the existing CyberArch configuration. The session entry points to that wrapper.
- Add an explicit preflight and dry-run mode. Preflight checks Ubuntu release, architecture, free space, existing Nix, Hyprland configuration collisions, and required packages before writing files.
- Use backups and an install manifest for all managed home-directory files. Create the system session entry in `/usr/local/share/wayland-sessions` only after the user confirms the privileged write. Never switch the active/default display manager or edit PAM/SDDM files.
- In the Ubuntu session, set supported theme environment variables in the Hyprland launcher and skip global `gsettings` and GTK/Kvantum/Kitty configuration writes. Keep the existing Arch behavior unchanged when the session-local mode is not set.
- Disable AUR/package-upgrade actions on Ubuntu so the HUD cannot invoke `pacman`, `yay`, or `paru` from that session.
- Add a separate uninstall path that consults the manifest, restores backed-up user files, removes the session entry and dedicated Nix profile, and does not garbage-collect Nix store paths or uninstall Nix itself.
- Update README installation, supported-platform, rollback, and uninstallation instructions for Ubuntu; clarify that GNOME remains available and the user chooses Hyprland from GDM.

## Review questions for implementation

The builder may select exact package attributes and shell structure after confirming that the pinned Nixpkgs revision includes compatible Hyprland, AGS v2, and Astal packages. If it does not, stop before installation and report the exact missing package/compatibility issue; do not substitute APT or alter the supported scope without approval.
