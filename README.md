# PPSSPP for Wii U: build kit

Rebuilds PPSSPP from the `wiiu` branch of `aliaspider/ppsspp` (last commit
Oct 2020; your current `.rpx` is from June 2018) with `-O3`, and packages it
with a speed-oriented `ppsspp.ini`.

## What was and wasn't tested

Tested in my sandbox:
- Scripts pass `bash -n`; `ppsspp.ini` parses; the config key names were
  checked against the branch's `Core/Config.cpp`.
- `rpltool` (the ELF-to-RPX converter) compiles and runs on a modern host GCC
  once `-Werror` is dropped (build.sh does this).
- `package.sh` produces the right SD-card layout.

NOT tested: the actual PowerPC compile, or running the result on a Wii U.
My sandbox can't reach the devkitPro servers and I have no console. Expect to
possibly fix compiler errors on the first run (see Troubleshooting).

## Build (Docker, recommended)

    docker build -t ppsspp-wiiu .
    docker run --rm -v "$PWD/out:/kit/out" ppsspp-wiiu

To also copy the title forwarder and WUP Installer from your original archive,
extract it somewhere and add `-v /path/to/extracted:/old -e OLD_EXTRAS=/old`.

## Build (no Docker)

On Linux/WSL with devkitPPC installed (`DEVKITPRO`/`DEVKITPPC` set) plus
`git cmake make gcc zlib1g-dev zip`:

    ./build.sh

Options: `JOBS=4`, `LTO=1` (experimental), `BRANCH=...`, `OUT=...`.

## Install

Unzip `out/ppsspp-wiiu.zip` onto the root of your SD card. Put games in
`sd:/ppsspp/roms/` (uncompressed ISO is faster than CSO). Launch from the
Homebrew Launcher. This port uses its own HBL-style runtime, not wut, so it is
built for HBL; Aroma is untested.

## Tuning (this is where speed actually comes from)

Edit `sd:/ppsspp/PSP/SYSTEM/ppsspp.ini`:

- `CPUCore`: `1` = the branch's PowerPC JIT, `2` = IR interpreter, `0` = plain
  interpreter. **Correction to what I said earlier:** this branch does include
  a PowerPC JIT backend (about 4,600 lines under `Core/MIPS/PPC`), and your old
  binary contains it. Upstream PPSSPP does not have one, and this one is old
  and likely incomplete, so how well it works per game is unknown. Try 1, then
  2, then 0 per game and keep what runs fastest without crashing.
- `FrameSkip`: `0` none, `1` default here, `2`+ for heavier games.
- `ShowFPSCounter = 1` shows speed so you can compare changes.
- Per-game overrides: PPSSPP also reads `<GAMEID>_ppsspp.ini` in the same
  folder, so you can tune one game without affecting others.

## Troubleshooting

- **Compiler errors in the PowerPC build:** the branch was tested with
  devkitPPC r38 (2020). Pin an older image:
  `docker build --build-arg DEVKITPPC_IMAGE=devkitpro/devkitppc:<tag> -t ppsspp-wiiu .`
  (pick a tag from Docker Hub).
- **ffmpeg link errors:** build.sh updates the `ffmpeg` submodule to
  ppsspp-ffmpeg master as the branch README requires; check that step's output.
- **Black screen or crash on launch:** set `CPUCore = 2` (or `0`) in the ini.
- **LTO build fails:** leave `LTO` at its default `0`.

## Licence

PPSSPP is GPLv2. If you share the built binary, share the source (the commit
hash is printed during the build).
