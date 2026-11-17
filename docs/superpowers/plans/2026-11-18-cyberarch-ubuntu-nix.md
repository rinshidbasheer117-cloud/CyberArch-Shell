# CyberArch Shell Ubuntu/Nix Implementation Plan

> **For agentic workers:** Use native GitHub branch editing for implementation and keep the work on a dedicated fork branch. The owner approved the design and selected Nix alongside GNOME.

**Goal:** Add a reversible Ubuntu 26.04 install path that launches CyberArch Shell in an optional Hyprland session while preserving GNOME and GDM.

**Architecture:** Keep the existing Arch installer as-is behind an early OS dispatch. Add a separate Ubuntu installer and Nix flake for a pinned, dedicated runtime profile, plus an optional GDM session wrapper. Gate Ubuntu-specific theme helpers so they do not modify GNOME preferences or invoke Arch package tools.

**Tech Stack:** Bash, Nix flakes/Nixpkgs, Hyprland, AGS/Astal, GDM Wayland session desktop entries.

**Spec:** `docs/superpowers/specs/2026-11-18-cyberarch-ubuntu-nix-design.md`

## Global Constraints

- Target Ubuntu 26.04 x86_64 GNOME first; stop before writes on an unsupported OS or architecture.
- Keep the Hyprland and shell runtime in a dedicated Nix profile pinned by `flake.lock`.
- Ask before installing Nix when absent and before writing the GDM session entry.
- Do not replace/disable GDM, change the default session, install SDDM, alter PAM, or set the theme lock screen.
- Do not run APT upgrades, alter repositories, or remove system packages.
- Do not change persistent GNOME `gsettings`, GTK/Kvantum/Kitty preferences, or stop applications in the GNOME session.
- Disable AUR and package-upgrade controls on Ubuntu; never execute `pacman`, `yay`, or `paru` from the Ubuntu session.
- Restore or remove only paths recorded by the install manifest; never garbage-collect the shared Nix store or remove Nix itself.
- Do not add or run automated tests for this work; review generated changes and exercise only the installer’s read-only preflight/dry-run path if execution is available.

## File Map

- Modify `install.sh` and `uninstall.sh` only to dispatch Ubuntu to dedicated scripts before Arch-only logic.
- Create `install-ubuntu.sh` for preflight, Nix setup, backups, runtime installation, and the optional session entry.
- Create `uninstall-ubuntu.sh` for manifest-based cleanup and restoration.
- Create `nix/flake.nix` and `nix/flake.lock` for the pinned runtime packages.
- Create a user-session launcher in `scripts/` and a GDM Wayland session desktop entry template.
- Modify `theme.lua`, `scripts/apply_theme`, `scripts/shell-theme`, and `scripts/aur` to enforce the Ubuntu session-local behavior without changing default Arch behavior.
- Modify `components/modules/aurbar.ts` only if needed to hide or disable unsupported AUR controls in Ubuntu mode.
- Update `README.md` with Ubuntu requirements, install, session selection, supported omissions, rollback, and uninstall instructions.

## Tasks

### Task 1: Pin and define the isolated Nix runtime

**Files:** Create `nix/flake.nix` and `nix/flake.lock`.

- [ ] Check the chosen Nixpkgs revision for compatible Hyprland, the AGS/Astal API actually used by current source, and required utilities; resolve the README's AGS v3 label versus the installer's AGS v2 checks from the runtime imports and record the package attributes and versions used.
- [ ] Define one `x86_64-linux` runtime output containing those exact packages and the libraries needed by `core.ts` and `scripts/launch-theme`.
- [ ] Keep the flake scoped to `nix/` so the large wallpaper/media tree is not copied into the Nix source input.
- [ ] Lock the Nixpkgs revision and ensure the installer can install the runtime into a dedicated `~/.local/state/cyberarch` profile.
- [ ] If the pinned package set lacks a required runtime or cannot satisfy the project API, stop and report the missing component; do not fall back to APT or an unreviewed third-party source.

### Task 2: Add guarded Ubuntu installer and uninstaller dispatch

**Files:** Modify `install.sh`, `uninstall.sh`; create `install-ubuntu.sh`, `uninstall-ubuntu.sh`.

- [ ] Dispatch Ubuntu to its new script before the `pacman` presence check; leave all existing Arch logic and prompts unchanged.
- [ ] Implement read-only preflight and `--dry-run` reporting for OS/version/architecture, disk space, Nix presence, existing Hyprland files, target path collisions, and required Nix packages.
- [ ] If Nix is missing, present the official multi-user Nix installation impact and stop unless the user explicitly confirms it.
- [ ] Install the pinned runtime to a dedicated profile, then create/backup only the per-user theme and Hyprland files tracked by an install manifest.
- [ ] Require confirmation before creating the GDM session entry at `/usr/local/share/wayland-sessions`; never alter the display-manager symlink or enabled state.
- [ ] Make partial failures stop before replacing existing content and report a recovery action from the manifest/backups.
- [ ] Implement uninstall using the manifest: remove the GDM entry, remove the dedicated profile and files created by this installer, and restore the user's pre-install Hyprland files. Preserve Nix itself, its daemon/store, GNOME/GDM, and unowned files.

### Task 3: Launch the HUD without changing GNOME preferences

**Files:** Create a session launcher and GDM desktop-entry template; modify `theme.lua`, `scripts/apply_theme`, `scripts/shell-theme`, `scripts/aur`, and, if required, `components/modules/aurbar.ts`.

- [ ] Make the GDM entry launch Hyprland with the dedicated Nix runtime and set supported theme variables only in that session.
- [ ] Ensure the AGS/Astal import paths used by `scripts/launch-theme` resolve to Nix store packages through installer-managed links, without overwriting pre-existing links or source files.
- [ ] Add an Ubuntu/session-local mode that skips `gsettings` writes and user-global GTK/Kvantum/Kitty config writes while preserving existing Arch behavior when the mode is absent.
- [ ] Remove Ubuntu-session calls that stop unrelated session services; retain only the CyberArch HUD's own startup/cleanup behavior.
- [ ] Make the AUR update helper and its UI non-actionable on Ubuntu and ensure `upgrade` cannot execute a package-manager command there.
- [ ] Keep custom SDDM lock-screen and PAM setup unreachable from the Ubuntu dispatcher.

### Task 4: Document the Ubuntu flow and recovery

**Files:** Modify `README.md`.

- [ ] Document the supported Ubuntu target, Nix's system changes if newly installed, the explicit prompts, and how to pick CyberArch from GDM while retaining GNOME.
- [ ] List Arch-only features omitted on Ubuntu (AUR notifications/upgrades and SDDM/PAM lock-screen integration).
- [ ] Document dry-run, backups, uninstall, and the fact that uninstall leaves the Nix daemon and shared store in place.
- [ ] Review the final branch diff for any path or command that could alter GNOME/GDM outside the approved scope.

## Review Focus

- **Nixpkgs API/version drift:** resolve package availability against the locked revision before writing the profile; stop if AGS/Astal/Hyprland are incompatible.
- **GDM session discovery:** write only the single optional `.desktop` file under `/usr/local/share/wayland-sessions`; do not change display-manager activation.
- **Existing `~/.config` files and links:** back up or skip conflicts, record ownership, and restore only exact manifest entries.
- **Global appearance state:** all Ubuntu-session helper paths must avoid GNOME `gsettings`, GTK preference files, and Kitty config changes.
- **Arch-only helper actions:** the Ubuntu runtime must not offer or execute pacman/AUR upgrades.
- **Partial install/uninstall:** a failure must leave GNOME/GDM usable and preserve unrelated files and the Nix shared store.
