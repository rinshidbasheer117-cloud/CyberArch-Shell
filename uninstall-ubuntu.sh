#!/usr/bin/env bash
set -euo pipefail
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/cyberarch"
MANIFEST="$STATE/manifest"
[ -f "$MANIFEST" ] || { echo 'No CyberArch Ubuntu install manifest found; nothing removed.'; exit 0; }
[ -t 0 ] || { echo 'Interactive confirmation is required; rerun in a terminal.' >&2; exit 1; }
printf 'Remove the CyberArch session, theme link, and dedicated Nix profile? The Nix daemon/store stay installed. [y/N] '; read -r answer
case "$answer" in y|Y|yes|YES) ;; *) echo 'Cancelled.'; exit 0;; esac
while IFS='=' read -r key path; do
  case "$key" in
    theme|profile|launcher) case "$path" in "$HOME/.config/hypr/themes/cyberpunk"|"$STATE/nix-profile"|"$HOME/.local/bin/cyberarch-session") rm -rf -- "$path";; esac ;;
    session) [ "$path" = /usr/local/share/wayland-sessions/cyberarch.desktop ] && sudo rm -f -- "$path" ;;
  esac
done < "$MANIFEST"
rm -f -- "$STATE/hyprland.lua" "$MANIFEST"
rmdir "$STATE" 2>/dev/null || true
echo 'CyberArch Ubuntu files removed. The shared Nix store and daemon were preserved.'
