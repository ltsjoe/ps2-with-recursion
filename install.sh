#!/usr/bin/env bash
# install.sh: install or remove ps2-with-recursion for the current user (no root needed).
#
# Copyright (C) 2026 ltsJoe
# SPDX-License-Identifier: GPL-3.0-or-later
# https://github.com/ltsjoe/ps2-with-recursion

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=ps2-with-recursion
. "$HERE/ps2-with-recursion"          # NAME, VERSION, PS2_APPID, steam_libraries, find_rt, ...

BIN_DIR=${XDG_BIN_HOME:-$HOME/.local/bin}
DATA_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/$NAME
KWIN_RULES=${XDG_CONFIG_HOME:-$HOME/.config}/kwinrulesrc
KWIN_RULE=$NAME-consoles
GAME_FILES=("$NAME.bat" "$NAME.js" "$NAME.log" "$NAME.quit")

usage() {
    cat <<EOF
Usage: ./install.sh [--no-kwin-rule]   install for the current user
       ./install.sh --uninstall        remove everything this installed

Installs:
  $BIN_DIR/$NAME
  $DATA_DIR/  (the Windows-side .bat and .js)
  on KDE Plasma, a KWin window rule that keeps Recursion Tracker's console windows hidden
EOF
}

say()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

# ------------------------------------------------------------------------- KDE rule

kwin_tool() { # $1 = write|read
    local v
    for v in 6 5; do
        if have "k${1}config$v"; then echo "k${1}config$v"; return 0; fi
    done
    return 1
}

kwin_reconfigure() {
    busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 ||
        gdbus call --session --dest org.kde.KWin --object-path /KWin \
            --method org.kde.KWin.reconfigure >/dev/null 2>&1 ||
        true
}

kwin_set_rules_list() { # $1 = comma-separated rule group names
    local w n
    w=$(kwin_tool write)
    n=$(tr ',' '\n' <<<"$1" | grep -c .) || true
    "$w" --file kwinrulesrc --group General --key rules "$1"
    "$w" --file kwinrulesrc --group General --key count "$n"   # Plasma 5 still reads count
}

add_kwin_rule() {
    local w r rules
    w=$(kwin_tool write); r=$(kwin_tool read)
    k() { "$w" --file kwinrulesrc --group "$KWIN_RULE" --key "$1" "$2"; }
    k Description "PlanetSide 2: hide Recursion Tracker's console windows ($NAME)"
    k title '\\(cmd|rtst_run_dx(64|86))\.exe'; k titlematch 3      # regex
    k wmclass "steam_app_$PS2_APPID";          k wmclassmatch 1    # exact
    k minimize true;     k minimizerule 2                          # 2 = force
    k skiptaskbar true;  k skiptaskbarrule 2
    k skippager true;    k skippagerrule 2
    k skipswitcher true; k skipswitcherrule 2
    rules=$("$r" --file kwinrulesrc --group General --key rules 2>/dev/null || true)
    case ",$rules," in
        *",$KWIN_RULE,"*) ;;
        *) kwin_set_rules_list "${rules:+$rules,}$KWIN_RULE" ;;
    esac
    kwin_reconfigure
}

remove_kwin_rule() {
    local r rules tmp
    [ -f "$KWIN_RULES" ] && grep -q "^\[$KWIN_RULE\]" "$KWIN_RULES" || return 0
    if r=$(kwin_tool read); then
        rules=$("$r" --file kwinrulesrc --group General --key rules 2>/dev/null || true)
        rules=$(tr ',' '\n' <<<"$rules" | grep -vx "$KWIN_RULE" | paste -sd, -) || true
        kwin_set_rules_list "$rules"
    fi
    tmp=$(mktemp)
    awk -v g="[$KWIN_RULE]" '/^\[/{skip = ($0 == g)} !skip' "$KWIN_RULES" >"$tmp"
    cat "$tmp" >"$KWIN_RULES"; rm -f "$tmp"
    kwin_reconfigure
    say "Removed the KWin window rule."
}

# ---------------------------------------------------------------------- game folders

ps2_game_dirs() {
    local lib acf dir
    while read -r lib; do
        acf=$lib/steamapps/appmanifest_$PS2_APPID.acf
        [ -f "$acf" ] || continue
        dir=$(sed -n 's/^[[:space:]]*"installdir"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$acf")
        if [ -n "$dir" ] && [ -d "$lib/steamapps/common/$dir" ]; then
            printf '%s\n' "$lib/steamapps/common/$dir"
        fi
    done < <(steam_libraries)
}

ps2_prefixes() {
    local lib
    while read -r lib; do
        if [ -d "$lib/steamapps/compatdata/$PS2_APPID/pfx" ]; then
            printf '%s\n' "$lib/steamapps/compatdata/$PS2_APPID/pfx"
        fi
    done < <(steam_libraries)
}

# --------------------------------------------------------------------------- checks

package_hint() {
    local id='' like=''
    if [ -r /etc/os-release ]; then
        id=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')
        like=$(sed -n 's/^ID_LIKE=//p' /etc/os-release | tr -d '"')
    fi
    if [ -e /run/ostree-booted ]; then
        echo "rpm-ostree install xdotool xwininfo xprop   (then reboot)"; return
    fi
    case " $id $like " in
        *" steamos "*) echo "SteamOS ships them; if they are missing, update SteamOS" ;;
        *" arch "*)    echo "sudo pacman -S --needed xdotool xorg-xwininfo xorg-xprop" ;;
        *" debian "*|*" ubuntu "*) echo "sudo apt install xdotool x11-utils" ;;
        *" fedora "*|*" rhel "*)   echo "sudo dnf install xdotool xwininfo xprop" ;;
        *" suse "*|*" opensuse "*) echo "sudo zypper install xdotool xwininfo xprop" ;;
        *) echo "install xdotool, xwininfo and xprop (often in an x11-utils package)" ;;
    esac
}

check_dependencies() {
    local missing=() t
    for t in xdotool xwininfo pgrep; do have "$t" || missing+=("$t"); done
    if [ ${#missing[@]} -gt 0 ]; then
        warn "missing: ${missing[*]}. Without them Recursion Tracker still starts with the game,"
        warn "but its console windows stay visible and it is force-closed instead of quit."
        warn "To install them: $(package_hint)"
    fi
    if ! have busctl && ! have gdbus; then
        warn "neither busctl (systemd) nor gdbus (glib2) found: on KDE Plasma, Recursion Tracker"
        warn "can't be quit through its tray icon and will be force-closed instead."
    fi
    if ! have xprop && [[ ${XDG_CURRENT_DESKTOP:-} != *KDE* ]]; then
        warn "xprop not found: Recursion Tracker can't be quit through a classic system tray"
        warn "(Xfce, MATE, ...) and will be force-closed instead. To install it: $(package_hint)"
    fi
}

check_steam() {
    local dirs pfxs pfx rt
    if [ -z "$(steam_libraries)" ]; then
        if have flatpak && flatpak info com.valvesoftware.Steam >/dev/null 2>&1; then
            warn "only Flatpak Steam was found. That isn't supported: Flatpak Steam runs launch"
            warn "options inside its sandbox, where this tool can't reach. Use your distribution's"
            warn "native Steam package instead."
        else
            warn "no Steam library found under ~/.steam or ~/.local/share/Steam."
        fi
        return
    fi
    dirs=$(ps2_game_dirs)
    if [ -z "$dirs" ]; then
        warn "PlanetSide 2 (Steam app $PS2_APPID) doesn't seem to be installed yet."
        return
    fi
    say "PlanetSide 2:       $dirs"
    pfxs=$(ps2_prefixes)
    if [ -z "$pfxs" ]; then
        warn "PlanetSide 2 has no Proton prefix yet. Run it once with Proton, then install"
        warn "Recursion Tracker into it (see README.md)."
        return
    fi
    while read -r pfx; do
        if rt=$(find_rt "$pfx"); then
            say "Recursion Tracker:  $rt"
        else
            warn "Recursion Tracker is not installed in PlanetSide 2's prefix ($pfx)."
            warn "Install it there first, see 'Install Recursion Tracker' in README.md."
        fi
    done <<<"$pfxs"
}

# -------------------------------------------------------------------------- actions

install_all() {
    local kwin=$1
    say "Installing $NAME $VERSION"
    install -Dm755 "$HERE/$NAME" "$BIN_DIR/$NAME"
    install -Dm644 "$HERE/windows/$NAME.bat" "$DATA_DIR/$NAME.bat"
    install -Dm644 "$HERE/windows/$NAME.js" "$DATA_DIR/$NAME.js"
    say "Installed:          $BIN_DIR/$NAME"
    say "                    $DATA_DIR/"
    if [ "$kwin" = 1 ] && kwin_tool write >/dev/null && [[ ${XDG_CURRENT_DESKTOP:-} == *KDE* ]]; then
        add_kwin_rule
        say "KWin window rule:   $KWIN_RULE (keeps the console windows hidden)"
    fi
    check_dependencies
    check_steam

    local launch="$BIN_DIR/$NAME %command%"
    # shellcheck disable=SC2088 # a literal ~ for Steam's launch options, not expanded here
    [ "$BIN_DIR" = "$HOME/.local/bin" ] && launch="~/.local/bin/$NAME %command%"
    cat <<EOF

Next steps:
  1. In Steam, open PlanetSide 2 > Properties > General > Launch Options and enter:

       $launch

     If you already use a wrapper (gamemoderun, mangohud, ...), keep it in front:
       gamemoderun $launch

  2. Optional: with the game closed, check that Recursion Tracker can be quit cleanly on
     this desktop:   $BIN_DIR/$NAME --test

  3. Play. Logs: journalctl -t $NAME, and $NAME.log in the PlanetSide 2 folder.
EOF
}

uninstall_all() {
    local dir f
    rm -f "$BIN_DIR/$NAME"
    rm -rf "$DATA_DIR"
    say "Removed $BIN_DIR/$NAME and $DATA_DIR/"
    while read -r dir; do
        [ -n "$dir" ] || continue
        for f in "${GAME_FILES[@]}"; do rm -f "$dir/$f"; done
        say "Removed $NAME files from $dir"
    done < <(ps2_game_dirs)
    remove_kwin_rule
    say "Last step: in Steam, remove '$NAME' from PlanetSide 2's launch options."
}

kwin=1
action=install
for arg in "$@"; do
    case $arg in
        --uninstall)    action=uninstall ;;
        --no-kwin-rule) kwin=0 ;;
        -h|--help)      usage; exit 0 ;;
        *)              usage >&2; exit 1 ;;
    esac
done
case $action in
    install)   install_all "$kwin" ;;
    uninstall) uninstall_all ;;
esac
