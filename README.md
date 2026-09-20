# Half-Life: Decay on Linux

Gets the Half-Life: Decay PC port running on Linux and the Steam Deck: an installer that
does the fiddly parts, and prebuilt libraries if you want them.

**The source and all the portability work are [FWGS](https://github.com/FWGS/hlsdk-portable)'.**
This repository compiles their `decay-pc` branch and wraps the result in an installer.
It is not official, and not affiliated with FWGS, Valve, Gearbox, or the Decay PC port team.

## The problem

Decay was a PlayStation 2 exclusive. The 2008 PC port ships exactly one piece of
executable code — `decay.dll`, for Windows. Everything else is platform-independent data
the Linux engine reads happily.

So on Linux the mod appears in the menu, plays its music, and **no map ever starts**.
There is no error: the engine looks for a game library, finds only a Windows DLL it
cannot load, and silently does nothing.

Supplying a Linux library is necessary but not sufficient. You also need the right
architecture, a low enough glibc, one missing line in `liblist.gam`, and — on a Deck —
a launcher that gets the Steam identity right. Miss any of them and it still silently
does nothing. That is what the installer is for.

## Install

Download the latest release, then:

```
tar xzf decay-linux.tar.gz
cd decay-linux
./install.sh
```

It finds Half-Life across every Steam library (microSD included, and Flatpak or Snap
installs), installs the libraries, adds the missing `gamedll_linux` line to
`liblist.gam` preserving its CRLF endings, writes a launcher, and verifies every
dependency resolves. It backs up whatever it replaces and is safe to run twice.

Two things must already be in place, neither of them here:

| Needed first | From |
|---|---|
| Half-Life, installed | Steam (the normal Linux build) |
| The Decay PC port — the ~150 MB `decay/` folder | ModDB |

The mod folder is **deliberately excluded**: it contains Valve and Gearbox assets. Get it
from ModDB, the sanctioned source for the same files.

## See also: binaries for every other Half-Life mod

If you want a different mod, or a platform this repo does not build,
**[nekonomicon/hlsdk-mega-build](https://github.com/nekonomicon/hlsdk-mega-build)** is
the place to go. It builds every FWGS branch continuously — Decay and Echoes included,
along with They Hunger, Poke646, Azure Sheep, Residual Point and dozens more — across 13
platforms: linux i386/amd64/arm64/armhf/riscv64, Android, macOS arm64, win32, Nintendo
Switch and PS Vita. Hundreds of assets per build.

Its `decay-linux-i386.zip` is equivalent to what this repo builds: same ELF class, same
GoldSrc exports, a glibc ceiling comfortably below what a Steam Deck provides. It
extracts straight into your Half-Life folder in the right layout.

What it does not do is the rest of the job — the `gamedll_linux` line, the launcher, the
Steam Deck identity handling below. Use their binaries with this installer if you prefer;
the steps are the same.

## Running it on a Steam Deck

If you add Decay as a **non-Steam shortcut**, the launcher must export `SteamAppId=70`.
Steam otherwise hands the game the shortcut's own app id, Half-Life's Steam auth rejects
the mismatch, and the game exits after about a second with
`[S_API FAIL] SteamAPI_Init() failed`.

Do **not** also set `SteamGameId`. gamescope tracks the launched game by that id and will
not display a window that disagrees, logging `xwm: appid clash` and leaving Game Mode
spinning on "launching executable" forever while the game runs fine behind it. Set one,
not both. The installer's launcher already does this.

On an ordinary desktop you need none of that: Steam builds its own Decay entry from
`liblist.gam`, and launching it from the library works.

## Verifying what you downloaded

You should not run a stranger's shared library. Every release here is built by a public
GitHub Actions run from public source, and the artifacts carry a signed provenance
attestation:

```
gh attestation verify decay.so --repo ranting-soberly/half-life-decay-linux-installer
```

That checks these exact bytes came from this repository's workflow, from the upstream
commit named in the release. `SHA256SUMS` is published alongside, and the workflow file
is [right here](.github/workflows/build.yml) — read it before you trust it.

## Building it yourself

```
git clone --depth 1 -b decay-pc https://github.com/FWGS/hlsdk-portable
cd hlsdk-portable && git submodule update --init --depth 1   # freevgui, else cmake fails
cmake -S . -B build -D64BIT=OFF -DGOLDSOURCE_SUPPORT=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
```

Three things that are easy to get wrong:

**Build 32-bit, not 64-bit.** `engine_amd64.so` exists in a Half-Life install, but
`hl.sh` hardcodes `GAMEEXE=hl_linux`, and Valve's own `hl.so` and `opfor.so` are 32-bit.

**Mind the glibc ceiling.** Building on a modern distro yields `acosf@GLIBC_2.43` and
similar, which a Steam Deck (glibc 2.41) cannot resolve — perfectly valid libraries that
will never load. Build in an older container; this repo uses `i386/debian:bookworm`
(glibc 2.36) and CI fails the build if the requirement creeps above that.

**Do not ship the built `vgui.so`.** Valve supply that at the Half-Life root.

## Reporting problems

Issues here are for **packaging and installation** — the installer, the launcher, the
libraries not loading. Bugs in the game code itself belong with
[FWGS](https://github.com/FWGS/hlsdk-portable/issues), who maintain the source, and
problems with the mod's maps or assets belong with the Decay PC port team on ModDB.

## Licence

Built from the Half-Life 1 SDK. Valve's licence permits redistribution **free of charge
only**, and requires `LICENSE` to travel with the binaries. It is in every release. Keep
it there if you pass this on.
