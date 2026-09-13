#!/usr/bin/env bash
#
# Half-Life: Decay -- Linux support installer for Steam Deck / desktop Linux.
#
# Decay's PC port ships only decay.dll (Windows). Valve never built the mod for
# Linux, so on a Deck the menu loads but no map ever starts. This installs the
# missing native libraries and the one config line that points the engine at them.
#
# It does NOT install the Decay mod itself -- get that from ModDB first.

set -euo pipefail

say()  { printf '  %s\n' "$*"; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/lib/decay.so" ]  || die "lib/decay.so missing -- run this from inside the unpacked folder"
[ -f "$HERE/lib/client.so" ] || die "lib/client.so missing -- run this from inside the unpacked folder"

echo
echo "Half-Life: Decay -- Linux support installer"
echo "==========================================="
echo

# ---- 1. locate Half-Life across every Steam library ------------------------
say "Looking for Half-Life..."
STEAM_ROOT=""
STEAM_KIND=""
for c in "$HOME/.local/share/Steam:native" \
         "$HOME/.steam/steam:native" \
         "$HOME/.steam/root:native" \
         "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam:flatpak" \
         "$HOME/.var/app/com.valvesoftware.Steam/data/Steam:flatpak" \
         "$HOME/snap/steam/common/.local/share/Steam:snap"; do
    d="${c%:*}"; k="${c##*:}"
    [ -d "$d/steamapps" ] && { STEAM_ROOT="$d"; STEAM_KIND="$k"; break; }
done
[ -n "$STEAM_ROOT" ] || die "no Steam installation found under \$HOME
       Looked for native, Flatpak and Snap installs."
say "Steam root: $STEAM_ROOT ($STEAM_KIND)"

if [ "$STEAM_KIND" != "native" ]; then
    echo
    say "NOTE: this is a $STEAM_KIND Steam install."
    say "The libraries will be installed correctly, but the generated launcher runs"
    say "outside the $STEAM_KIND sandbox and may not find Steam's runtime. Launching"
    say "Decay from Steam's own library entry is the reliable route there."
    echo
fi

LIBS=("$STEAM_ROOT/steamapps")
LF="$STEAM_ROOT/steamapps/libraryfolders.vdf"
if [ -f "$LF" ]; then
    while IFS= read -r p; do
        [ -d "$p/steamapps" ] && LIBS+=("$p/steamapps")
    done < <(grep -oP '(?<="path"\s{2})"[^"]*"' "$LF" 2>/dev/null | tr -d '"')
fi

H=""
for l in "${LIBS[@]}"; do
    if [ -f "$l/common/Half-Life/hl.sh" ]; then H="$l/common/Half-Life"; break; fi
done
[ -n "$H" ] || die "Half-Life not found. Install it from Steam first (it must be the Linux build)."
say "Half-Life:  $H"

# ---- 2. the Decay mod itself must already be there -------------------------
[ -d "$H/decay" ] || die "No 'decay' folder in $H
       Install the Decay PC port first, then re-run this.
       It goes in:  $H/decay"
[ -f "$H/decay/liblist.gam" ] || die "$H/decay exists but has no liblist.gam -- incomplete mod install"
say "Decay mod:  found"

# ---- 3. sanity-check we are targeting the right architecture ---------------
if grep -q 'GAMEEXE=hl_linux64' "$H/hl.sh" 2>/dev/null; then
    die "This install uses the 64-bit engine; these libraries are 32-bit."
fi
say "Engine:     32-bit (hl_linux) -- matches these libraries"

# ---- 4. install the libraries ---------------------------------------------
mkdir -p "$H/decay/dlls" "$H/decay/cl_dlls"
for pair in "decay.so:dlls" "client.so:cl_dlls"; do
    f="${pair%%:*}"; d="${pair##*:}"
    if [ -f "$H/decay/$d/$f" ]; then
        cp -a "$H/decay/$d/$f" "$H/decay/$d/$f.bak-$(date +%Y%m%d-%H%M%S)"
        say "backed up existing $d/$f"
    fi
    install -m644 "$HERE/lib/$f" "$H/decay/$d/$f"
    say "installed   decay/$d/$f"
done

# ---- 5. point liblist.gam at the Linux library (CRLF-safe, idempotent) -----
python3 - "$H/decay/liblist.gam" <<'PY'
import shutil, sys
from datetime import datetime
p = sys.argv[1]
raw = open(p, "rb").read()
eol = b"\r\n" if raw.count(b"\r\n") else b"\n"
if b"gamedll_linux" in raw:
    print("  liblist.gam already has gamedll_linux -- unchanged")
    raise SystemExit
out, done = [], False
for ln in raw.split(eol):
    out.append(ln)
    if not done and ln.strip().lower().startswith(b"gamedll "):
        out.append(b'gamedll_linux "dlls/decay.so"'); done = True
if not done:
    raise SystemExit("ERROR: no gamedll line in liblist.gam to anchor on")
shutil.copy2(p, p + ".bak-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
open(p, "wb").write(eol.join(out))
print("  liblist.gam  + gamedll_linux \"dlls/decay.so\"  (%s endings preserved)"
      % ("CRLF" if eol == b"\r\n" else "LF"))
PY

# ---- 6. launcher ------------------------------------------------------------
# GoldSrc will not start outside the Steam Runtime: no distro ships 32-bit SDL2
# in a way the game finds, so bare ./hl.sh dies with "Could not load hw.so".
RT="$STEAM_ROOT/ubuntu12_32/steam-runtime/run.sh"
# Keep an existing launcher where it is: a Steam shortcut may already point at it,
# and moving it would silently orphan that shortcut.
if   [ -f "$HOME/decay.sh" ];            then LAUNCHER="$HOME/decay.sh"
elif [ -f "$HOME/.local/bin/decay.sh" ]; then LAUNCHER="$HOME/.local/bin/decay.sh"
elif [ -d "$HOME/.local/bin" ];          then LAUNCHER="$HOME/.local/bin/decay.sh"
else                                          LAUNCHER="$HOME/decay.sh"
fi
cat > "$LAUNCHER" <<LAUNCH
#!/bin/bash
# Launch Half-Life: Decay. Generated by install.sh on $(date +%Y-%m-%d).
#
# You usually do NOT need this. Steam builds its own Decay entry from liblist.gam,
# and launching from the Steam library works on an ordinary desktop. This script is
# for launching outside Steam, and for adding Decay as a non-Steam shortcut - which
# is how you get it into Steam Deck Game Mode.
#
# SteamAppId=70: when Steam launches a NON-STEAM SHORTCUT it hands the game the
# shortcut's own app id. Half-Life is app 70, so SteamAPI rejects the mismatch and
# the game exits after about a second with "[S_API FAIL] SteamAPI_Init() failed".
# Setting it is harmless when launching any other way.
#
# SteamGameId is deliberately NOT set. gamescope (Steam Deck Game Mode) tracks the
# launched game by that id and will not display a window that disagrees, logging
# "xwm: appid clash" and spinning on "launching executable" forever.
set -u
H="$H"
RT="$RT"
[ -x "\$H/hl.sh" ]               || { echo "Half-Life not found at \$H" >&2; exit 1; }
[ -f "\$H/decay/dlls/decay.so" ] || { echo "decay.so missing - no map will load" >&2; exit 1; }
export SteamAppId=70
cd "\$H" || exit 1
# GoldSrc needs 32-bit SDL2. Steam's runtime always has it; a desktop distro may too.
if [ -x "\$RT" ]; then
    exec "\$RT" ./hl.sh -game decay "\$@"
else
    exec ./hl.sh -game decay "\$@"
fi
LAUNCH
chmod +x "$LAUNCHER"
say "launcher    $LAUNCHER"
[ -x "$RT" ] || say "WARNING: Steam Runtime not at $RT -- start Steam once, then re-run"

# ---- 7. verify --------------------------------------------------------------
echo
say "Verifying..."
MISS=$(LD_LIBRARY_PATH="$H" ldd "$H/decay/dlls/decay.so" 2>&1 | grep -ci "not found" || true)
if [ "$MISS" != "0" ]; then
    LD_LIBRARY_PATH="$H" ldd "$H/decay/dlls/decay.so" 2>&1 | grep -i "not found" | sed 's/^/    /'
    die "$MISS unresolved dependencies -- your glibc may be older than these builds need.
       Rebuild from https://github.com/FWGS/hlsdk-portable (branch decay-pc)."
fi
say "decay.so:   all dependencies resolve"
CMISS=$(LD_LIBRARY_PATH="$H" ldd "$H/decay/cl_dlls/client.so" 2>&1 | grep -ci 'not found' || true)
if [ "$CMISS" = "0" ]; then
    say "client.so:  all dependencies resolve"
else
    say "client.so:  $CMISS unresolved outside Steam - normally fine."
    say "            The client library uses SDL2 and friends, which Steam's runtime"
    say "            supplies at launch. Only a concern if the game fails to start."
fi

IS_DECK=no
if grep -qi 'steamos' /etc/os-release 2>/dev/null || command -v steamos-session-select >/dev/null 2>&1; then
    IS_DECK=yes
fi

cat <<DONE

Done.

  Decay should now appear in your Steam library. Steam builds that entry itself from
  the mod's liblist.gam, so on an ordinary desktop that is all you need - launch it
  from Steam and play.

  Or run it directly:   $LAUNCHER
DONE

if [ "$IS_DECK" = yes ]; then
cat <<DECK

  Steam Deck: to reach it from Game Mode, add the launcher as a non-Steam shortcut.
    Desktop Mode -> Steam -> Games -> Add a Non-Steam Game -> Browse -> $LAUNCHER
  Rename it to "Half-Life: Decay" and set artwork via right-click -> Properties.
  Bind G to a back paddle; swapping between the two scientists is constant.

  Steam's own auto-generated Decay tile will sit alongside yours with the same name.
  The one with artwork is the one you added.
DECK
fi

cat <<PLAY

  Playing: Decay is co-op and has no New Game. Use "Play Decay" and start a server on
  dy_accident1 with 3 player slots. You control one of two scientists and swap with G.
  Later maps unlock as you finish them, and there are no mid-mission saves. All of
  that is original PlayStation 2 behaviour, not a broken install.
PLAY
