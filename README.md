# Half-Life: Decay — Linux game libraries

Prebuilt Linux libraries for the Half-Life: Decay PC port, so you don't have to compile
them yourself, plus an installer.

**The source and all the portability work are [FWGS](https://github.com/FWGS/hlsdk-portable)'.**
This repository only compiles their `decay-pc` branch and publishes the result. It is not
official, and it is not affiliated with FWGS, Valve, Gearbox, or the Decay PC port team.

## Why this exists

Decay was a PlayStation 2 exclusive. The 2008 PC port ships exactly one piece of
executable code — `decay.dll`, for Windows. Everything else in the mod is
platform-independent data the Linux engine reads happily.

So on Linux the mod appears in the menu, plays its music, and **no map ever starts**.
There is no error message: the engine looks for a game library, finds only a Windows
DLL it cannot load, and silently does nothing.

FWGS made the code buildable for Linux years ago. Nobody had published a build.

## Install

Download the latest release, then:

```
tar xzf decay-linux.tar.gz
cd decay-linux
./install.sh
```

The installer finds Half-Life across all your Steam libraries (microSD included),
installs the two libraries, adds the missing `gamedll_linux` line to `liblist.gam`,
writes a launcher, and verifies every dependency resolves. It backs up whatever it
replaces and is safe to run twice.

You need two things first, neither of which is here:

| Needed first | From |
|---|---|
| Half-Life, installed | Steam (the normal Linux build) |
| The Decay PC port — the ~150 MB `decay/` folder | ModDB |

The mod folder is **deliberately excluded**: it contains Valve and Gearbox assets. Get it
from ModDB, which is the sanctioned source for the same files.

## Verifying what you downloaded

You should not run a stranger's shared library, and you don't have to take anyone's word
here. Every release is built by a public GitHub Actions run from public source, and the
artifacts carry a signed provenance attestation:

```
gh attestation verify decay.so --repo OWNER/REPO
```

That checks these exact bytes came from this repository's workflow, from the upstream
commit named in the release. `SHA256SUMS` is published alongside. The workflow file is
[right here](.github/workflows/build.yml) — read it before you trust it.

## Notes for anyone building it themselves

Three things that are easy to get wrong:

**Build 32-bit, not 64-bit.** `engine_amd64.so` exists in a Half-Life install, but
`hl.sh` hardcodes `GAMEEXE=hl_linux`, and Valve's own `hl.so` and `opfor.so` are 32-bit.

**Mind the glibc ceiling.** Building on a modern distro yields `acosf@GLIBC_2.43` and
similar, which a Steam Deck (glibc 2.41) cannot resolve — perfectly valid libraries that
will never load. Build in an older container; this repo uses `i386/debian:bookworm`
(glibc 2.36) and CI fails the build if the requirement creeps above that.

**Initialise the submodule.** `freevgui` is a submodule and cmake fails outright without it.

## Running it on a Steam Deck

If you add Decay as a **non-Steam shortcut**, the launcher must export `SteamAppId=70`.
Steam otherwise hands the game the shortcut's own app id, Half-Life's Steam auth rejects
the mismatch, and the game exits after about a second with
`[S_API FAIL] SteamAPI_Init() failed`.

Do **not** also set `SteamGameId`. gamescope tracks the launched game by that id and will
not display a window that disagrees, logging `xwm: appid clash` and leaving Game Mode
spinning on "launching executable" forever while the game runs fine behind it. Set one,
not both. The installer's launcher already does this.

## Licence

Built from the Half-Life 1 SDK. Valve's licence permits redistribution **free of charge
only**, and requires `LICENSE` to travel with the binaries. It is in every release. Keep
it there if you pass this on.
