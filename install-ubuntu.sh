#!/usr/bin/env bash
set -euo pipefail

THEME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/cyberarch"
PROFILE="$STATE/nix-profile"
THEME_LINK="$HOME/.config/hypr/themes/cyberpunk"
SESSION_DIR="/usr/local/share/wayland-sessions"
SESSION_FILE="$SESSION_DIR/cyberarch.desktop"
MANIFEST="$STATE/manifest"
DRY_RUN=0
for arg in "$@"; do case "$arg" in --dry-run) DRY_RUN=1;; *) echo "Unknown option: $arg" >&2; exit 2;; esac; done

. /etc/os-release
[ "${ID:-}" = ubuntu ] || { echo 'Ubuntu installer invoked on a non-Ubuntu system.' >&2; exit 1; }
[ "$(uname -m)" = x86_64 ] || { echo 'Only x86_64 is supported.' >&2; exit 1; }
case "${VERSION_ID:-}" in 26.04) ;; *) echo "This path supports Ubuntu 26.04; found ${VERSION_ID:-unknown}." >&2; exit 1;; esac
[ -d "$THEME/nix" ] && [ -f "$THEME/theme.lua" ] || { echo 'Run this from the CyberArch repository checkout.' >&2; exit 1; }
[ ! -e "$THEME_LINK" ] && [ ! -L "$THEME_LINK" ] || { echo "Refusing to replace existing path: $THEME_LINK" >&2; exit 1; }
[ ! -e "$PROFILE" ] && [ ! -L "$PROFILE" ] || { echo "Refusing to replace existing profile: $PROFILE" >&2; exit 1; }
if ! command -v nix >/dev/null 2>&1; then
  if [ "$DRY_RUN" = 1 ]; then
    echo 'Dry run: Nix is missing; the installer would ask before running the official multi-user installer.'
    exit 0
  fi
  [ -t 0 ] || { echo 'Nix is missing. Run this from a terminal to review and confirm the official multi-user installer.' >&2; exit 1; }
  cat <<'NOTICE'
Nix is not installed. Its official multi-user installer adds the Nix store,
systemd services, and a system build user group. GNOME and GDM are not changed.
NOTICE
  printf 'Download and run the official Nix installer now? [y/N] '; read -r answer
  case "$answer" in y|Y|yes|YES) ;; *) echo 'Install Nix from https://nixos.org/download/ and rerun.'; exit 1;; esac
  command -v curl >/dev/null 2>&1 || { echo 'curl is required to download the official installer.' >&2; exit 1; }
  installer="$(mktemp)"
  trap 'rm -f -- "$installer"' EXIT
  curl --fail --location --proto '=https' --tlsv1.2 https://nixos.org/nix/install -o "$installer"
  sh "$installer" --daemon
  rm -f -- "$installer"
  trap - EXIT
  . "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true
  command -v nix >/dev/null 2>&1 || { echo 'Nix installation did not make nix available in this shell; open a new terminal and rerun.' >&2; exit 1; }
fi
printf 'Ubuntu 26.04 x86_64 preflight passed.\n'
printf 'Will install the pinned runtime in: %s\n' "$PROFILE"
printf 'Will add the theme symlink: %s\n' "$THEME_LINK"
printf 'Optional GDM session file: %s\n' "$SESSION_FILE"
[ "$DRY_RUN" = 1 ] && { echo 'Dry run: no files were changed.'; exit 0; }
nix --extra-experimental-features 'nix-command flakes' flake metadata --no-write-lock-file "$THEME/nix" >/dev/null
[ -t 0 ] || { echo 'Interactive confirmation is required; rerun in a terminal.' >&2; exit 1; }
printf 'Install the isolated runtime and user files? [y/N] '; read -r answer
case "$answer" in y|Y|yes|YES) ;; *) echo 'Cancelled.'; exit 0;; esac
mkdir -p "$STATE" "$(dirname "$THEME_LINK")" "$HOME/.local/bin"
created=()
cleanup() {
  if [ "${#created[@]}" -gt 0 ]; then
    for p in "${created[@]}"; do
      if [ "$p" = "$SESSION_FILE" ]; then sudo rm -f -- "$p" 2>/dev/null || true
      else rm -rf -- "$p"; fi
    done
  fi
  [ -z "${session_tmp:-}" ] || rm -f -- "$session_tmp"
}
trap cleanup ERR
nix --extra-experimental-features 'nix-command flakes' profile install --profile "$PROFILE" "$THEME/nix"
created+=("$PROFILE")
ln -s -- "$THEME" "$THEME_LINK"
created+=("$THEME_LINK")
cat > "$STATE/hyprland.lua" <<'LUA'
package.path = os.getenv("HOME") .. "/.config/hypr/themes/cyberpunk/?.lua;" .. (package.path or "")
require("theme")
LUA
created+=("$STATE/hyprland.lua")
cat > "$HOME/.local/bin/cyberarch-session" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${XDG_STATE_HOME:-$HOME/.local/state}/cyberarch"
export CYBERARCH_SESSION_LOCAL=1 CYBERARCH_OS=ubuntu
export PATH="$state/nix-profile/bin:$HOME/.local/bin:$PATH"
export CYBERARCH_AGS_BIN="$state/nix-profile/bin/ags"
export LD_LIBRARY_PATH="$state/nix-profile/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$state/nix-profile/bin/Hyprland" --config "$state/hyprland.lua"
SH
chmod 755 "$HOME/.local/bin/cyberarch-session"
created+=("$HOME/.local/bin/cyberarch-session")

printf 'Add the optional CyberArch entry to GDM? This writes one file under %s. [y/N] ' "$SESSION_DIR"; read -r answer
case "$answer" in
    y|Y|yes|YES)
    [ ! -e "$SESSION_FILE" ] || { echo "Refusing to replace $SESSION_FILE" >&2; exit 1; }
    session_tmp="$(mktemp)"
    printf '[Desktop Entry]\nName=CyberArch (Hyprland)\nComment=CyberArch shell in an isolated Hyprland session\nExec=%s/.local/bin/cyberarch-session\nType=Application\nDesktopNames=Hyprland\n' "$HOME" > "$session_tmp"
    sudo install -d -m 755 "$SESSION_DIR"
    sudo install -m 644 "$session_tmp" "$SESSION_FILE"
    rm -f -- "$session_tmp"
    created+=("$SESSION_FILE")
    session_path="$SESSION_FILE"
    ;;
  *) echo 'Skipped GDM entry; the user files and Nix profile are installed.'; session_path='' ;;
esac
printf '%s\n' "theme=$THEME_LINK" "profile=$PROFILE" "launcher=$HOME/.local/bin/cyberarch-session" "session=$session_path" > "$MANIFEST"
trap - ERR
echo 'Installed. GNOME remains the default session; choose CyberArch (Hyprland) from the GDM session menu.'
