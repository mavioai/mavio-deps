#!/bin/sh
# Builds libmpv for Android as mpv-android does, with its build scripts and
# its JNI layer, at the versions pinned below, into out/mpv: jniLibs/<abi>/
# (libmpv, FFmpeg, libc++ and libplayer, the JNI layer) and kotlin/,
# mpv-android's Kotlin API to the JNI layer (is.xyz.mpv.MPVLib). FFmpeg and
# mpv are built as GPL-3.0, as Mavio is licensed. The sources it builds from
# go into work/mpv/sources. Intermediate builds are kept in work/mpv; a run
# with the same pins does nothing. Installs the Android NDK with sdkmanager
# (ANDROID_HOME) when it is missing. Needs meson and ninja (mise.toml),
# autotools, pkg-config and gperf, and on macOS GNU sed, coreutils and bash 4
# or later; nasm is built when missing.
# Usage: scripts/build-mpv.sh [--version | --sources]
# --sources only fetches the sources into work/mpv/sources.
set -eu
cd "$(dirname "$0")/.."
root=$(pwd)
. scripts/lib.sh

mpv_android=c2e02fe111541e4063ab8f868bf629649ed937a3
# mpv's commit, and its last release before it.
mpv=88eb9f2e73945d8bc9c133a2f67babaa9af34680
mpv_release=0.41.0
ffmpeg=n9.0.2
libass=0.17.5
libplacebo=v7.360.1
dav1d=1.5.4
nasm=3.02
fontconfig=2.18.3
ndk_version=30.0.16248370

# The release version: mpv's last release and its commit,
# <release>.g<7 hex digits>.
if [ "${1:-}" = --version ]; then
	echo "$mpv_release.g$(echo "$mpv" | cut -c1-7)"
	exit 0
fi

work=$root/work/mpv
out=$root/out/mpv
sources=$work/sources

# The libraries are built once for each version of this script.
stamp=$(cat scripts/build-mpv.sh scripts/lib.sh | cksum)
if [ "${1:-}" != --sources ] && [ "$(cat "$work/stamp" 2>/dev/null)" = "$stamp" ] &&
	[ -d "$out" ] && [ -d "$sources" ]; then
	echo "$out"
	exit 0
fi

mkdir -p "$work/bin"
export PATH="$work/bin:$PATH"
# mpv-android downloads with wget; curl stands in for it.
# shellcheck disable=SC2016
printf '#!/bin/sh\nexec curl -fsSL "$1"\n' >"$work/bin/wget"
chmod +x "$work/bin/wget"

fetch "$work/mpv-android" https://github.com/mpv-android/mpv-android "$mpv_android"
scripts=$work/mpv-android/buildscripts
deps=$scripts/deps
mkdir -p "$deps" "$scripts/sdk"
fetch "$deps/mpv" https://github.com/mpv-player/mpv "$mpv"
fetch "$deps/ffmpeg" https://github.com/FFmpeg/FFmpeg "refs/tags/$ffmpeg"
fetch "$deps/libass" https://github.com/libass/libass "refs/tags/$libass"
fetch "$deps/libplacebo" https://github.com/haasn/libplacebo "refs/tags/$libplacebo" --recursive
fetch "$deps/dav1d" https://github.com/videolan/dav1d "refs/tags/$dav1d"
# Its archives sit behind a browser check; git is not.
fetch "$deps/fontconfig" https://gitlab.freedesktop.org/fontconfig/fontconfig "refs/tags/$fontconfig"
# The rest of the sources, at the versions mpv-android pins. Those that come
# as archives are built in their trees, so they are downloaded afresh.
for d in "$deps"/*/; do
	[ -e "$d/.git" ] || rm -rf "$d"
done
(cd "$scripts" && ./include/download-deps.sh)

# The sources, before the build: mpv-android, with its build scripts, and
# every dependency it builds.
rm -rf "$sources"
snapshot "$work/mpv-android" "$sources/mpv-android"
for d in "$deps"/*/; do
	d=${d%/}
	snapshot "$d" "$sources/mpv-android/buildscripts/deps/${d##*/}"
done
# pin name: a version mpv-android's include/depinfo.sh pins.
pin() {
	sed -n "s/^v_$1=//p" "$scripts/include/depinfo.sh"
}
components=$sources/COMPONENTS
: >"$components"
component "$components" mpv-android "$mpv_android" MIT https://github.com/mpv-android/mpv-android
component "$components" mpv "$mpv" "GPL-2.0-or-later (built with -Dgpl=true, as GPL-3.0 with FFmpeg)" https://github.com/mpv-player/mpv
component "$components" FFmpeg "$ffmpeg" "GPL-3.0-or-later (--enable-gpl --enable-version3)" https://github.com/FFmpeg/FFmpeg
component "$components" libass "$libass" ISC https://github.com/libass/libass
component "$components" libplacebo "$libplacebo" LGPL-2.1-or-later https://github.com/haasn/libplacebo
component "$components" dav1d "$dav1d" BSD-2-Clause https://github.com/videolan/dav1d
component "$components" fontconfig "$fontconfig" HPND-sell-variant https://gitlab.freedesktop.org/fontconfig/fontconfig
component "$components" FreeType "$(pin freetype)" "FTL OR GPL-2.0-or-later" https://gitlab.freedesktop.org/freetype/freetype
component "$components" FriBidi "$(pin fribidi)" LGPL-2.1-or-later https://github.com/fribidi/fribidi
component "$components" HarfBuzz "$(pin harfbuzz)" MIT-Modern-Variant https://github.com/harfbuzz/harfbuzz
component "$components" libunibreak "$(pin unibreak)" Zlib https://github.com/adah1972/libunibreak
component "$components" libxml2 "$(pin libxml2)" MIT https://gitlab.gnome.org/GNOME/libxml2
component "$components" Lua "$(pin lua)" MIT https://www.lua.org
component "$components" "Mbed TLS" "$(pin mbedtls)" "Apache-2.0 OR GPL-2.0-or-later" https://github.com/Mbed-TLS/mbedtls
component "$components" curl "$(pin curl)" curl https://curl.se
component "$components" "LLVM libc++ (libc++_shared.so, from Android NDK $ndk_version)" "$ndk_version" "Apache-2.0 WITH LLVM-exception" https://developer.android.com/ndk
if [ "${1:-}" = --sources ]; then
	echo "$sources"
	exit 0
fi

ndk=$(ndk "$ndk_version")
ln -sfn "$ndk" "$scripts/sdk/android-ndk-r30"
if ! command -v nasm >/dev/null; then
	rm -rf "$work/nasm"
	fetch "$work/nasm" https://github.com/netwide-assembler/nasm "refs/tags/nasm-$nasm"
	(cd "$work/nasm" && ./autogen.sh >/dev/null && ./configure -q &&
		make -s -j"$(getconf _NPROCESSORS_ONLN)" nasm && cp nasm "$work/bin/")
fi

cd "$scripts"
for arch in arm64 armv7l x86_64; do
	# Its build script needs bash 4 or later, which macOS lacks in /bin.
	bash ./buildall.sh --arch "$arch" mpv
done

cd "$work/mpv-android/app/src/main"
PATH="$ndk:$PATH" PREFIX64="$scripts/prefix/arm64" PREFIX32="$scripts/prefix/armv7l" \
	PREFIX_X64="$scripts/prefix/x86_64" ndk-build -s -j"$(getconf _NPROCESSORS_ONLN)"

rm -rf "$out" && mkdir -p "$out/jniLibs" "$out/kotlin/is/xyz/mpv"
cp -R libs/. "$out/jniLibs/"
cp java/is/xyz/mpv/MPVLib.kt "$out/kotlin/is/xyz/mpv/"
echo "$stamp" >"$work/stamp"
echo "$out"
