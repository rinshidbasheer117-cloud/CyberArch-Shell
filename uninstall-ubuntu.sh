#!/usr/bin/env bash
set -euo pipefail
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/cyberarch"
if [ "$(id -u)" = 0 ]; then
    if [ -n "${SUDO_USER:-}" ]; then exec runuser -u "$SUDO_USER" -- env -u SUDO_USER bash "$(dirname "${BASH_SOURCE[0]}")/uninstall-ubuntu.sh" "$@"; fi
    echo 'Run this as your user, not from a root shell.' >&2; exit 1
fi
MANIFEST="$STATE/manifest"
[ -f "$MANIFEST" ] || { echo 'No CyberArch Ubuntu install manifest found; nothing removed.'; exit 0; }
[ -t 0 ] || { echo 'Interactive confirmation is required; rerun in a terminal.' >&2; exit 1; }
printf 'Remove the CyberArch session, theme link, and dedicated Nix profile? The Nix daemon/store stay installed. [y/N] '; read -r answer
case "$answer" in y|Y|yes|YES) ;; *) echo 'Cancelled.'; exit 0;; esac
theme=''; profile=''; launcher=''; session=''; session_digest=''; source=''; ags_link=''; astal_link=''; gnim_link=''; profile_target=''; launcher_digest=''; config_digest=''
while IFS='=' read -r key path; do
  case "$key" in
    theme|profile|launcher|session|session_digest|source|ags_link|astal_link|gnim_link|profile_target|launcher_digest|config_digest) printf -v "$key" '%s' "$path" ;;
  esac
done < "$MANIFEST"
expected_source=''
if [ "$theme" = "$HOME/.config/hypr/themes/cyberpunk" ] && [ -L "$theme" ]; then
  theme_target="$(readlink -f "$theme" 2>/dev/null || true)"
  if [ "$theme_target" = "$source" ]; then expected_source="$theme_target"; rm -f -- "$theme"
  else echo "Kept changed theme link: $theme"; fi
fi
if [ "$profile" = "$STATE/nix-profile" ] && [ -L "$profile" ] && [ "$(readlink "$profile")" = "$profile_target" ]; then rm -f -- "$profile"
elif [ "$profile" = "$STATE/nix-profile" ] && { [ -e "$profile" ] || [ -L "$profile" ]; }; then echo "Kept changed Nix profile link: $profile"; fi
if [ "$launcher" = "$HOME/.local/bin/cyberarch-session" ] && [ -f "$launcher" ]; then
  [ "$(sha256sum "$launcher" | awk '{print $1}')" = "$launcher_digest" ] && rm -f -- "$launcher" || echo "Kept modified launcher: $launcher"
fi
if [ "$session" = /usr/local/share/wayland-sessions/cyberarch.desktop ] && [ -f "$session" ]; then
  actual_digest="$(sha256sum "$session" | awk '{print $1}')"
  if [ "$actual_digest" = "$session_digest" ]; then sudo rm -f -- "$session"
  else echo "Kept modified session entry: $session"; fi
fi
if [ -n "$source" ] && [ "$source" = "$expected_source" ]; then
  [ ! -L "$source/node_modules/ags" ] || [ "$(readlink "$source/node_modules/ags")" != "$STATE/nix-profile/share/ags/js" ] || ln -sfn -- "$ags_link" "$source/node_modules/ags"
  [ ! -L "$source/node_modules/astal" ] || [ "$(readlink "$source/node_modules/astal")" != "$STATE/nix-profile/share/astal/gjs" ] || ln -sfn -- "$astal_link" "$source/node_modules/astal"
  [ ! -L "$source/node_modules/gnim" ] || [ "$(readlink "$source/node_modules/gnim")" != "$STATE/nix-profile/share/ags/js/node_modules/gnim" ] || ln -sfn -- "$gnim_link" "$source/node_modules/gnim"
fi
if [ -f "$STATE/hyprland.lua" ] && [ "$(sha256sum "$STATE/hyprland.lua" | awk '{print $1}')" = "$config_digest" ]; then rm -f -- "$STATE/hyprland.lua"
else echo "Kept modified session config: $STATE/hyprland.lua"; fi
rm -f -- "$MANIFEST"
rmdir "$STATE" 2>/dev/null || true
echo 'CyberArch Ubuntu files removed. The shared Nix store and daemon were preserved.'
