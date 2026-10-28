#!/usr/bin/env bash
# Builds PPSSPP.rpx from the aliaspider/ppsspp "wiiu" branch and packages it.
# Works inside the Docker image or natively (Linux/WSL) with devkitPPC installed.
#
# Optional environment variables:
#   BRANCH   git branch to build            (default: wiiu)
#   REPO     git repository                 (default: aliaspider/ppsspp)
#   JOBS     parallel make jobs             (default: all cores)
#   LTO      1 = link-time optimisation     (default: 0, experimental on old GCC)
#   OUT      output folder                  (default: ./out)
#   OLD_EXTRAS  path to your extracted original archive, to copy the forwarder
#               and WUP installer into the package (optional)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRANCH="${BRANCH:-wiiu}"
REPO="${REPO:-https://github.com/aliaspider/ppsspp.git}"
JOBS="${JOBS:-$(nproc)}"
LTO="${LTO:-0}"
OUT="${OUT:-$HERE/out}"
WORK="${WORK:-$HERE/work}"
SRC="$WORK/ppsspp"

export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export DEVKITPPC="${DEVKITPPC:-$DEVKITPRO/devkitPPC}"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -x "$DEVKITPPC/bin/powerpc-eabi-gcc" ] || die "devkitPPC not found at $DEVKITPPC (set DEVKITPRO / DEVKITPPC)"
for t in git cmake make gcc zip; do command -v "$t" >/dev/null || die "missing host tool: $t"; done
echo "==> Compiler: $("$DEVKITPPC/bin/powerpc-eabi-gcc" --version | head -1)"

mkdir -p "$WORK" "$OUT"

# ---- 1. Source -------------------------------------------------------------
if [ ! -d "$SRC/.git" ]; then
  echo "==> Cloning $REPO ($BRANCH)"
  git clone --branch "$BRANCH" "$REPO" "$SRC"
else
  echo "==> Updating existing checkout"
  git -C "$SRC" fetch origin "$BRANCH"
  git -C "$SRC" checkout -q "$BRANCH"
  git -C "$SRC" reset -q --hard "origin/$BRANCH"
fi
cd "$SRC"
echo "==> Building commit: $(git log -1 --format='%h %ad %s' --date=short)"

# ---- 2. Submodules (skip the big test-suite and Windows-only ones) ----------
for sm in ext/wiiu ffmpeg ext/glslang ext/SPIRV-Cross ext/rapidjson ext/miniupnp \
          ext/armips ext/discord-rpc assets/lang ext/native/tools/prebuilt; do
  git submodule update --init --recursive -- "$sm" \
    || echo "WARN: submodule $sm could not be fetched (may be unused)"
done

# The branch README asks for the latest ppsspp-ffmpeg (it carries the Wii U libs).
echo "==> Updating ffmpeg submodule to ppsspp-ffmpeg master"
git -C ffmpeg fetch -q origin master
git -C ffmpeg checkout -q FETCH_HEAD

# ---- 3. Host tool: rpltool (ELF -> RPX) ------------------------------------
echo "==> Building rpltool with the host compiler"
# FLAGS is overridden to drop the Makefile's -Werror, which breaks on modern host GCC
make -C ext/wiiu/rpltool -j"$JOBS" CC=gcc CXX=g++ FLAGS="-ffunction-sections -fdata-sections"
[ -x ext/wiiu/rpltool/rpltool ] || die "rpltool did not build"

# ---- 4. PPSSPP for Wii U ----------------------------------------------------
EXTRA="-fomit-frame-pointer"
LINK=""
if [ "$LTO" = "1" ]; then EXTRA="$EXTRA -flto"; LINK="-flto"; fi

echo "==> Configuring (Release = -O3, LTO=$LTO)"
cmake -S . -B build-wiiu \
  -DWIIU=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="$EXTRA" \
  -DCMAKE_CXX_FLAGS="$EXTRA" \
  -DCMAKE_EXE_LINKER_FLAGS="$LINK"

echo "==> Compiling with $JOBS jobs (this takes a while)"
cmake --build build-wiiu -j"$JOBS"

RPX="$(find build-wiiu -maxdepth 2 -name 'PPSSPP.rpx' | head -1)"
[ -n "$RPX" ] || die "PPSSPP.rpx was not produced - see the compiler output above"
echo "==> Built: $RPX ($(du -h "$RPX" | cut -f1))"

# ---- 5. Package -------------------------------------------------------------
bash "$HERE/package.sh" "$SRC" "$SRC/$RPX" "$OUT" ${OLD_EXTRAS:+"$OLD_EXTRAS"}
