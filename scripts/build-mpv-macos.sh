#!/bin/sh
# Builds libmpv for macOS into out/mpv-macos, universal for arm64 and x86_64,
# at the versions pinned below: lib/ holds libmpv.2.dylib, with FFmpeg,
# libass, libplacebo and the rest linked in, and libMoltenVK.dylib, the
# Vulkan driver it links directly; include/mpv/ the client API's headers.
# Each dylib's install name is @rpath/<name>. mpv renders with vo=gpu-next
# and gpu-context=macvk (Vulkan through MoltenVK, HDR through EDR), decodes
# with VideoToolbox, and embeds in a host NSView given as --wid with Mavio's
# patches in patches/mpv-macos. FFmpeg and mpv are built as GPL-3.0, as Mavio
# is licensed. Mavio's desktop app loads libmpv at run time. The sources it
# built from go into work/mpv-macos/sources. Intermediate builds are kept in
# work/mpv-macos; a run with the same pins does nothing. Needs macOS with
# Xcode, meson, ninja and CMake (mise.toml) and pkg-config; nasm is built
# when missing, with autotools.
# Usage: scripts/build-mpv-macos.sh [--version]
set -eu
cd "$(dirname "$0")/.."
root=$(pwd)
. scripts/lib.sh

# mpv's commit, and its last release before it, as scripts/build-mpv.sh
# pins them.
mpv=88eb9f2e73945d8bc9c133a2f67babaa9af34680
mpv_release=0.41.0
ffmpeg=n9.0.2
libass=0.17.5
libplacebo=v7.360.1
dav1d=1.5.4
# libass's dependencies, as scripts/build-libass.sh pins them.
freetype=VER-2-14-3
fribidi=v1.0.17
harfbuzz=12.3.2
# libplacebo's color management and shader compiler.
lcms2=2.19.1
glslang=16.6.0
# The Vulkan driver, with the dependencies its ExternalRevisions pin.
moltenvk=v1.4.2
nasm=3.02
archs="arm64 x86_64"
# MoltenVK needs macOS 12 and mpv 10.15; Mavio supports macOS 13.
macos=13.0

# The release version: mpv's last release and its commit,
# <release>.g<7 hex digits>.
if [ "${1:-}" = --version ]; then
	echo "$mpv_release.g$(echo "$mpv" | cut -c1-7)"
	exit 0
fi

work=$root/work/mpv-macos
out=$root/out/mpv-macos
sources=$work/sources
patches=$root/patches/mpv-macos

# The libraries are built once for each version of this script and of the
# patches.
stamp=$(cat scripts/build-mpv-macos.sh scripts/lib.sh "$patches"/*.patch | cksum)
if [ "$(cat "$work/stamp" 2>/dev/null)" = "$stamp" ] && [ -d "$out" ] && [ -d "$sources" ]; then
	echo "$out"
	exit 0
fi
mkdir -p "$work/bin"
export PATH="$work/bin:$PATH"
jobs=$(getconf _NPROCESSORS_ONLN)
sdk=$(xcrun --sdk macosx --show-sdk-path)
cc=$(xcrun --sdk macosx -f clang)
cxx=$(xcrun --sdk macosx -f clang++)

# built step: whether this run of the script has built step, so that a run
# continues where a failed one stopped; record step records that it has.
built() {
	[ "$(cat "$work/$1.stamp" 2>/dev/null)" = "$stamp" ]
}
record() {
	echo "$stamp" >"$work/$1.stamp"
}

# Each source in a directory named by its version.
src_mpv=$work/mpv-$mpv
src_ffmpeg=$work/ffmpeg-$ffmpeg
src_libass=$work/libass-$libass
src_libplacebo=$work/libplacebo-$libplacebo
src_dav1d=$work/dav1d-$dav1d
src_lcms2=$work/lcms2-$lcms2
src_glslang=$work/glslang-$glslang
src_moltenvk=$work/MoltenVK-$moltenvk
fetch "$src_mpv" https://github.com/mpv-player/mpv "$mpv"
fetch "$src_ffmpeg" https://github.com/FFmpeg/FFmpeg "refs/tags/$ffmpeg"
# FFmpeg names its version after the tag it finds.
git -C "$src_ffmpeg" tag -f "$ffmpeg" >/dev/null
fetch "$src_libass" https://github.com/libass/libass "refs/tags/$libass"
fetch "$src_libplacebo" https://github.com/haasn/libplacebo "refs/tags/$libplacebo" --recursive
fetch "$src_dav1d" https://github.com/videolan/dav1d "refs/tags/$dav1d"
fetch "$src_lcms2" https://github.com/mm2/Little-CMS "refs/tags/lcms$lcms2"
fetch "$src_glslang" https://github.com/KhronosGroup/glslang "refs/tags/$glslang"
fetch "$src_moltenvk" https://github.com/KhronosGroup/MoltenVK "refs/tags/$moltenvk"
# libass's dependencies, as meson subprojects.
mkdir -p "$src_libass/subprojects"
# wrap name repository revision dependency
wrap() {
	cat >"$src_libass/subprojects/$1.wrap" <<WRAP
[wrap-git]
directory = $1-$3
url = $2
revision = $3
depth = 1

[provide]
dependency_names = $4
WRAP
}
wrap freetype2 https://gitlab.freedesktop.org/freetype/freetype "$freetype" freetype2
wrap fribidi https://github.com/fribidi/fribidi "$fribidi" fribidi
wrap harfbuzz https://github.com/harfbuzz/harfbuzz "$harfbuzz" harfbuzz
# MoltenVK's dependencies, into its External/, and their builds.
if ! built moltenvk-deps; then
	(cd "$src_moltenvk" && ./fetchDependencies --macos >"$work/moltenvk-deps.log" 2>&1)
	record moltenvk-deps
fi

# The sources, before the build and before mpv's patches, which the sources
# archive holds with the scripts: every component built, with the wraps of
# libass and the subprojects they check out, which meson fetches here.
(cd "$src_libass" && meson subprojects download >/dev/null)
git -C "$src_mpv" checkout -q -- .
rm -rf "$sources"
for s in "$src_mpv" "$src_ffmpeg" "$src_libplacebo" "$src_dav1d" "$src_lcms2" "$src_glslang"; do
	snapshot "$s" "$sources/${s##*/}"
done
snapshot "$src_libass" "$sources/${src_libass##*/}"
for d in "$src_libass"/subprojects/*/; do
	d=${d%/}
	snapshot "$d" "$sources/${src_libass##*/}/subprojects/${d##*/}"
done
cp "$src_libass"/subprojects/*.wrap "$sources/${src_libass##*/}/subprojects/"
snapshot "$src_moltenvk" "$sources/${src_moltenvk##*/}"
for d in "$src_moltenvk"/External/*/ "$src_moltenvk"/External/SPIRV-Tools/external/*/; do
	d=${d%/}
	[ -e "$d/.git" ] || continue
	snapshot "$d" "$sources/${src_moltenvk##*/}/${d#"$src_moltenvk"/}"
done
for p in "$patches"/*.patch; do
	[ -e "$p" ] || continue
	git -C "$src_mpv" apply "$p"
done
# rev name: the commit MoltenVK's ExternalRevisions pin for name.
rev() {
	cat "$src_moltenvk/ExternalRevisions/$1_repo_revision"
}
components=$sources/COMPONENTS
: >"$components"
component "$components" mpv "$mpv" "GPL-2.0-or-later (built with -Dgpl=true, as GPL-3.0 with FFmpeg)" https://github.com/mpv-player/mpv
component "$components" FFmpeg "$ffmpeg" "GPL-3.0-or-later (--enable-gpl --enable-version3)" https://github.com/FFmpeg/FFmpeg
component "$components" libass "$libass" ISC https://github.com/libass/libass
component "$components" FreeType "$freetype" "FTL OR GPL-2.0-or-later" https://gitlab.freedesktop.org/freetype/freetype
component "$components" FriBidi "$fribidi" LGPL-2.1-or-later https://github.com/fribidi/fribidi
component "$components" HarfBuzz "$harfbuzz" MIT-Modern-Variant https://github.com/harfbuzz/harfbuzz
component "$components" libplacebo "$libplacebo" LGPL-2.1-or-later https://github.com/haasn/libplacebo
component "$components" dav1d "$dav1d" BSD-2-Clause https://github.com/videolan/dav1d
component "$components" "Little CMS" "$lcms2" MIT https://github.com/mm2/Little-CMS
component "$components" glslang "$glslang" "BSD-3-Clause AND BSD-2-Clause AND MIT AND Apache-2.0 AND GPL-3.0-or-later WITH Bison-exception-2.2" https://github.com/KhronosGroup/glslang
component "$components" MoltenVK "$moltenvk" Apache-2.0 https://github.com/KhronosGroup/MoltenVK
component "$components" SPIRV-Cross "$(rev SPIRV-Cross)" "Apache-2.0 OR MIT" https://github.com/KhronosGroup/SPIRV-Cross
component "$components" SPIRV-Tools "$(rev SPIRV-Tools)" Apache-2.0 https://github.com/KhronosGroup/SPIRV-Tools
component "$components" SPIRV-Headers "$(rev SPIRV-Headers)" MIT https://github.com/KhronosGroup/SPIRV-Headers
component "$components" Vulkan-Headers "$(rev Vulkan-Headers)" "Apache-2.0 OR MIT" https://github.com/KhronosGroup/Vulkan-Headers
component "$components" cereal "$(rev cereal)" BSD-3-Clause https://github.com/USCiLab/cereal

if ! command -v nasm >/dev/null; then
	if ! built nasm; then
		rm -rf "$work/nasm"
		fetch "$work/nasm" https://github.com/netwide-assembler/nasm "refs/tags/nasm-$nasm"
		(cd "$work/nasm" && ./autogen.sh >/dev/null && ./configure -q &&
			make -s -j"$jobs" nasm && cp nasm "$work/bin/")
		record nasm
	fi
fi

# MoltenVK, universal, as a dylib whose install name is
# @rpath/libMoltenVK.dylib. libmpv links it directly, without the Vulkan
# loader, so it needs no ICD file. It logs warnings and errors, not its
# information, unless the environment's MVK_CONFIG_LOG_LEVEL says otherwise.
moltenvk_pkg=$src_moltenvk/Package/Release/MoltenVK
if ! built moltenvk; then
	# shellcheck disable=SC2016
	(cd "$src_moltenvk" && xcodebuild build -quiet -project MoltenVKPackaging.xcodeproj \
		-scheme "MoltenVK Package (macOS only)" -destination generic/platform=macOS \
		-derivedDataPath "$work/build-moltenvk" MACOSX_DEPLOYMENT_TARGET="$macos" \
		GCC_PREPROCESSOR_DEFINITIONS='$(inherited) MVK_CONFIG_LOG_LEVEL=2' \
		>"$work/moltenvk.log" 2>&1)
	record moltenvk
fi
# The dylib alone in a directory, for the linker; and a vulkan.pc for it.
mkdir -p "$work/moltenvk/lib/pkgconfig"
cp "$moltenvk_pkg/dynamic/dylib/macOS/libMoltenVK.dylib" "$work/moltenvk/lib/"
vk_version=1.4.$(sed -n 's/^#define VK_HEADER_VERSION \([0-9]*\)$/\1/p' "$moltenvk_pkg/include/vulkan/vulkan_core.h")
cat >"$work/moltenvk/lib/pkgconfig/vulkan.pc" <<PC
Name: Vulkan (MoltenVK)
Description: Vulkan through MoltenVK $moltenvk
Version: $vk_version
Cflags: -I$moltenvk_pkg/include
Libs: -L$work/moltenvk/lib -lMoltenVK
PC

# build arch: builds every library for arch into $work/prefix-<arch>, and
# libmpv last.
build() {
	arch=$1
	prefix=$work/prefix-$arch
	b=$work/build-$arch
	mkdir -p "$prefix/lib/pkgconfig" "$b"
	cp "$work/moltenvk/lib/pkgconfig/vulkan.pc" "$prefix/lib/pkgconfig/"
	cpu=$arch
	[ "$arch" = arm64 ] && cpu=aarch64
	flags="-arch $arch -isysroot $sdk -mmacosx-version-min=$macos"
	mflags="'-arch', '$arch', '-isysroot', '$sdk', '-mmacosx-version-min=$macos'"
	# Only the libraries built here are found, none of the system's or a
	# package manager's, with what linking them statically needs.
	export PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig"
	cross=$work/$arch.cross
	cat >"$cross" <<CROSS
[binaries]
c = '$cc'
cpp = '$cxx'
objc = '$cc'
ar = '$(xcrun --sdk macosx -f ar)'
strip = '$(xcrun --sdk macosx -f strip)'
nasm = '$(command -v nasm || echo "$work/bin/nasm")'
pkg-config = ['pkg-config', '--static']

[properties]
pkg_config_libdir = '$prefix/lib/pkgconfig'

[built-in options]
c_args = [$mflags, '-I$prefix/include']
cpp_args = [$mflags, '-I$prefix/include']
objc_args = [$mflags, '-I$prefix/include']
c_link_args = [$mflags, '-L$prefix/lib']
cpp_link_args = [$mflags, '-L$prefix/lib']
objc_link_args = [$mflags, '-L$prefix/lib']

[host_machine]
system = 'darwin'
subsystem = 'macos'
cpu_family = '$cpu'
cpu = '$cpu'
endian = 'little'
CROSS
	# meson_build name source options...: a library into prefix, static
	# unless the options say otherwise.
	meson_build() {
		name=$1 msrc=$2
		shift 2
		built "$arch-$name" && return
		rm -rf "${b:?}/$name"
		meson setup "$b/$name" "$msrc" --cross-file "$cross" --prefix "$prefix" --libdir lib \
			--buildtype=release "$@" >"$b/$name.log"
		ninja -C "$b/$name" install >>"$b/$name.log"
		record "$arch-$name"
	}

	meson_build dav1d "$src_dav1d" -Ddefault_library=static -Denable_tools=false -Denable_examples=false -Denable_tests=false \
		-Denable_docs=false

	if ! built "$arch-ffmpeg"; then
		rm -rf "$b/ffmpeg" && mkdir -p "$b/ffmpeg"
		# Only the system's frameworks and libraries it is told of: videotoolbox,
		# audiotoolbox, Secure Transport for https, zlib, bzip2 and iconv.
		(cd "$b/ffmpeg" && "$src_ffmpeg/configure" --prefix="$prefix" \
			--enable-cross-compile --target-os=darwin --arch="$arch" \
			--cc="$cc" --cxx="$cxx" --extra-cflags="$flags" --extra-ldflags="$flags" \
			--pkg-config=pkg-config --pkg-config-flags=--static --x86asmexe=nasm \
			--enable-static --disable-shared --enable-pic --enable-gpl --enable-version3 \
			--disable-programs --disable-doc --disable-debug --disable-avdevice \
			--disable-autodetect --enable-videotoolbox --enable-audiotoolbox \
			--enable-securetransport --enable-zlib --enable-bzlib --enable-iconv \
			--enable-libdav1d >"$b/ffmpeg.log" &&
			make -j"$jobs" install >>"$b/ffmpeg.log")
		record "$arch-ffmpeg"
	fi

	# Core Text is libass's font provider; the x86_64 assembly is left out,
	# as in scripts/build-libass.sh.
	meson_build libass "$src_libass" -Ddefault_library=static --wrap-mode=default \
		--force-fallback-for=freetype2,fribidi,harfbuzz \
		-Dfontconfig=disabled -Dcoretext=enabled -Ddirectwrite=disabled -Dlibunibreak=disabled \
		-Dasm=disabled -Dtest=disabled -Dcompare=disabled -Dprofile=disabled -Dfuzz=disabled -Dcheckasm=disabled \
		-Dfreetype2:zlib=disabled -Dfreetype2:bzip2=disabled -Dfreetype2:png=disabled \
		-Dfreetype2:brotli=disabled -Dfreetype2:harfbuzz=disabled \
		-Dharfbuzz:coretext=disabled -Dharfbuzz:icu=disabled -Dharfbuzz:utilities=disabled \
		-Dharfbuzz:tests=disabled -Dharfbuzz:docs=disabled -Dfribidi:docs=false -Dfribidi:tests=false \
		-Dfribidi:bin=false

	meson_build lcms2 "$src_lcms2" -Ddefault_library=static -Dtests=disabled -Djpeg=disabled -Dtiff=disabled -Dutils=false

	# Without spirv-opt, which libplacebo does not use.
	if ! built "$arch-glslang"; then
		rm -rf "$b/glslang"
		cmake -S "$src_glslang" -B "$b/glslang" -G Ninja -DCMAKE_BUILD_TYPE=Release \
			-DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib \
			-DCMAKE_OSX_ARCHITECTURES="$arch" -DCMAKE_OSX_DEPLOYMENT_TARGET="$macos" \
			-DCMAKE_OSX_SYSROOT="$sdk" -DCMAKE_C_COMPILER="$cc" -DCMAKE_CXX_COMPILER="$cxx" \
			-DBUILD_SHARED_LIBS=OFF -DBUILD_EXTERNAL=OFF -DENABLE_OPT=OFF -DENABLE_HLSL=OFF \
			-DENABLE_GLSLANG_BINARIES=OFF -DGLSLANG_TESTS=OFF -DGLSLANG_ENABLE_INSTALL=ON \
			>"$b/glslang.log"
		ninja -C "$b/glslang" install >>"$b/glslang.log"
		record "$arch-glslang"
	fi

	# Vulkan, linking MoltenVK, with glslang and Little CMS. It finds the
	# static glslang libraries in the directory vulkan-sdk names, but for
	# libglslang itself, which libmpv's link adds.
	meson_build libplacebo "$src_libplacebo" -Ddefault_library=static -Dprefer_static=true \
		-Dvulkan-sdk="$prefix" --auto-features=disabled \
		-Dvulkan=enabled -Dvk-proc-addr=enabled -Dglslang=enabled -Dlcms=enabled -Ddovi=enabled \
		-Ddemos=false -Dtests=false

	# libmpv alone, with only the features named: no window system but
	# Cocoa, and no OpenGL; the Swift code built for the deployment target.
	# Its C++ dependencies need libc++; libplacebo, glslang. mpv lets symbols
	# be looked up at run time; none may be.
	meson_build mpv "$src_mpv" --auto-features=disabled -Ddefault_library=shared \
		-Dc_link_args="[$mflags, '-L$prefix/lib', '-lglslang', '-lglslang-default-resource-limits', '-lc++', '-Wl,-undefined,error']" \
		-Dobjc_link_args="[$mflags, '-L$prefix/lib', '-lglslang', '-lglslang-default-resource-limits', '-lc++', '-Wl,-undefined,error']" \
		-Dgpl=true -Dlibmpv=true -Dcplayer=false -Dlua=disabled -Dgl=disabled \
		-Diconv=enabled -Dzlib=enabled -Dlcms2=enabled -Dvector=enabled \
		-Dcoreaudio=enabled -Davfoundation=enabled -Dcocoa=enabled -Dswift-build=enabled \
		-Dswift-flags="-target $arch-apple-macos$macos" -Dvulkan=enabled -Dvideotoolbox-pl=enabled \
		-Dmacos-10-15-4-features=enabled -Dmacos-11-features=enabled \
		-Dmacos-11-3-features=enabled -Dmacos-12-features=enabled
}
for arch in $archs; do
	build "$arch"
done

rm -rf "$out" && mkdir -p "$out/lib" "$out/include"
dylibs=""
for arch in $archs; do
	dylibs="$dylibs $work/prefix-$arch/lib/libmpv.2.dylib"
done
# shellcheck disable=SC2086
lipo -create $dylibs -output "$out/lib/libmpv.2.dylib"
# meson installs it under the name of its path. Its run paths name the
# Swift toolchain's directories, no place to look up libraries in an app,
# which gives its own; the Swift runtime is the system's, linked by its path.
# Changing them needs signing it anew.
install_name_tool -id @rpath/libmpv.2.dylib "$out/lib/libmpv.2.dylib" 2>/dev/null
for r in $(otool -l "$out/lib/libmpv.2.dylib" | awk '$1 == "path" { print $2 }' | sort -u); do
	install_name_tool -delete_rpath "$r" "$out/lib/libmpv.2.dylib" 2>/dev/null
done
codesign -f -s - "$out/lib/libmpv.2.dylib" 2>/dev/null
cp "$work/moltenvk/lib/libMoltenVK.dylib" "$out/lib/"
cp -R "$work/prefix-arm64/include/mpv" "$out/include/"
echo "$stamp" >"$work/stamp"
echo "$out"
