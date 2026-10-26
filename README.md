# mavio-deps

> English | [简体中文](README.zh-CN.md)

The native third-party libraries that the [Mavio](https://github.com/mavioai/mavio) clients link, built from source and published as versioned, checksummed GitHub Release assets. The Mavio repository downloads, verifies and extracts them instead of compiling them: libmpv alone takes about an hour to build.

## Libraries

| Library | Script | Runner | Release version | Binary asset | Extracted into (Mavio) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| libass for Apple | `scripts/build-libass.sh` | `macos-latest` | libass's | `<tag>.xcframework.zip` → `Libass.xcframework/` | `libs/apple/build/` |
| libmpv for Android | `scripts/build-mpv.sh` | `ubuntu-latest` | mpv's | `<tag>.tar.gz` → `mpv/` | `libs/android/player/build/` |
| libmpv for macOS | `scripts/build-mpv-macos.sh` | `macos-latest` | mpv's | `<tag>.tar.gz` → `mpv-macos/` | `apps/desktop/build/` |
| Media3's FFmpeg decoder extension | `scripts/build-media3-ffmpeg.sh` | `ubuntu-latest` | Media3's | `<tag>.tar.gz` → `ffmpeg/` | `libs/android/player/build/` |

- **libass** is a static library per platform (iOS, the iOS simulator, tvOS, the tvOS simulator, and macOS universal for arm64 and x86_64) with FreeType, FriBidi and HarfBuzz linked in and Core Text as its font provider, in `Libass.xcframework`, whose module `Libass` exports `ass.h`. Mavio's Apple player renders ASS subtitles with it.
- **libmpv** is built with mpv-android's build scripts and JNI layer: `mpv/jniLibs/<abi>/` holds libmpv, FFmpeg, libc++ and `libplayer.so` (the JNI layer) for `arm64-v8a`, `armeabi-v7a` and `x86_64`, and `mpv/kotlin/is/xyz/mpv/MPVLib.kt` is mpv-android's Kotlin API to it. FFmpeg and mpv are built as GPL-3.0.
- **libmpv for macOS**, for Mavio's desktop app, which loads it at run time: `mpv-macos/lib/` holds `libmpv.2.dylib`, universal for arm64 and x86_64 with FFmpeg, libass, libplacebo and their dependencies linked in, and `libMoltenVK.dylib`, the Vulkan driver it links directly, without the Vulkan loader or an ICD file; `mpv-macos/include/mpv/` holds the client API's headers. Both install names are `@rpath/<name>`, so that the app ships them in its `Contents/Frameworks` with that directory in its run path; they link nothing but the system's libraries. It needs macOS 13 or later. mpv renders with `vo=gpu-next` and `gpu-context=macvk`, Vulkan through MoltenVK with HDR through EDR, and decodes with VideoToolbox; Mavio's patch `patches/mpv-macos/wid.patch` embeds it in a host `NSView` given as `--wid` (an `NSView *` as an int64), in a view of its own the host lays out, instead of a window of its own; `patches/mpv-macos/coreaudio-channel-map.patch` gives the coreaudio output its channel map as macOS takes it, an entry for each of the device's channels naming the stream's channel it plays, from the device's labelled channels or its stereo pair; macOS refuses the channel layout mpv gives instead, and mpv falls back to the avfoundation output, which queues two seconds of audio. FFmpeg and mpv are built as GPL-3.0.
- **Media3's FFmpeg decoder extension**, which has no published artifact: `ffmpeg/jniLibs/<abi>/libffmpegJNI.so` is its JNI layer linked with an LGPL FFmpeg holding only audio decoders, and `ffmpeg/java/` its audio renderer. It is tied to the Media3 version, which must be the one Mavio's `libs/android/gradle/libs.versions.toml` names.

Each script pins every version in variables at its top and writes into `out/` the directory the Mavio repository consumes, as the table shows; the sources it built from go into `work/<library>/sources/`. Patches a build applies to a library's sources are in `patches/<library>/`.

## Tag scheme

A release is tagged `<library>-<version>-<revision>`:

- `<library>` is `libass`, `mpv`, `mpv-macos` or `media3-ffmpeg`.
- `<version>` is the version the script pins for the library, which `scripts/build-<library>.sh --version` prints; it has no hyphens. libass and Media3 use their release versions; mpv, pinned at a commit, uses its last release and the commit's first seven hex digits, `<release>.g<commit>`.
- `<revision>` starts at 1 for each version and increases with every release of the same version that changes anything else: another pin, a build option, the scripts. Revision 0 marks the test builds of pull requests and manual runs and is never tagged.

For example `libass-0.17.5-1`, `mpv-0.41.0.g88eb9f2-1`, `mpv-macos-0.41.0.g88eb9f2-1` and `media3-ffmpeg-1.11.1-1`.

## Assets and manifest

Each release `<tag>` holds four assets, at `https://github.com/mavioai/mavio-deps/releases/download/<tag>/<asset>`:

| Asset | Contents |
| :--- | :--- |
| `<tag>.xcframework.zip` (libass) or `<tag>.tar.gz` (the others) | The binaries: one top-level directory, `Libass.xcframework`, `mpv`, `mpv-macos` or `ffmpeg`. |
| `<tag>-sources.tar.gz` | `<tag>-sources/`: the exact sources of every component in the binaries under `sources/`, with `sources/COMPONENTS`, and this repository's scripts, patches, `mise.toml`, README and license. |
| `manifest.json` | The machine-readable description below. |
| `SHA256SUMS` | The SHA-256 digests of the other three, in `sha256sum` format. |

The release notes repeat the digests and list the components with their licenses. `manifest.json`:

```json
{
  "schema": 1,
  "library": "libass",
  "version": "0.17.5",
  "revision": 1,
  "tag": "libass-0.17.5-1",
  "binary": {
    "name": "libass-0.17.5-1.xcframework.zip",
    "url": "https://github.com/mavioai/mavio-deps/releases/download/libass-0.17.5-1/libass-0.17.5-1.xcframework.zip",
    "sha256": "<64 hex digits>",
    "size": 12345678,
    "extract_to": "libs/apple/build",
    "path": "libs/apple/build/Libass.xcframework"
  },
  "sources": {
    "name": "libass-0.17.5-1-sources.tar.gz",
    "url": "https://github.com/mavioai/mavio-deps/releases/download/libass-0.17.5-1/libass-0.17.5-1-sources.tar.gz",
    "sha256": "<64 hex digits>",
    "size": 12345678
  },
  "components": [
    {"name": "libass", "version": "0.17.5", "license": "ISC", "upstream": "https://github.com/libass/libass"}
  ]
}
```

`binary.extract_to` is the directory, relative to the Mavio repository's root, into which the binary archive is extracted; `binary.path` is the directory that results. The Mavio repository pins a tag and the binary's `sha256`, downloads `binary.url`, checks the digest and extracts the archive.

## Using the libraries in Mavio

**libass.** SwiftPM downloads and verifies the archive itself; its checksum, which `swift package compute-checksum` computes, is the archive's SHA-256:

```swift
.binaryTarget(
    name: "Libass",
    url: "https://github.com/mavioai/mavio-deps/releases/download/libass-0.17.5-1/libass-0.17.5-1.xcframework.zip",
    checksum: "<binary.sha256>"
),
```

**libmpv and the FFmpeg extension.** Extract `<tag>.tar.gz` into `libs/android/player/build/`, which gives `libs/android/player/build/mpv` and `libs/android/player/build/ffmpeg`. The player's Gradle build already adds `build/mpv/kotlin`, `build/ffmpeg/java` and the two `jniLibs` directories as source directories.

**libmpv for macOS.** Extract `<tag>.tar.gz` into `apps/desktop/build/`, which gives `apps/desktop/build/mpv-macos`. The app bundle carries the two dylibs in `Contents/Frameworks`, its executable has the run path `@executable_path/../Frameworks`, and it loads `libmpv.2.dylib` with purego; mpv needs the app's `NSApplication` and its main run loop, on which it lays out its view.

## Cutting a release

1. Change the pins at the top of the script and test it: a pull request builds the libraries whose scripts or patches it changes (every library when it changes `scripts/lib.sh`, `scripts/package.sh`, `mise.toml` or `.github/`) and uploads their packages as workflow artifacts; a manual run of the Release workflow builds the library it names.
2. Merge, then tag the commit on `main` with `<library>-<version>-<revision>`, the version being what `sh scripts/build-<library>.sh --version` prints, and push the tag:

   ```bash
   git tag libass-0.17.5-1
   git push origin libass-0.17.5-1
   ```

3. The Release workflow builds the library on its runner, checks that the tag names the version the script pins, packages it and creates the GitHub Release with the assets and the digests in its notes. It needs `contents: write`, which the workflow requests; the repository's Actions settings must allow it.
4. Update the tag and the digest in the Mavio repository.

## Building locally

The tools are pinned in `mise.toml` (meson, ninja, CMake, Java for sdkmanager, ShellCheck):

```bash
mise install
mise exec -- sh scripts/build-libass.sh          # macOS with Xcode; about 4 minutes
mise exec -- sh scripts/build-media3-ffmpeg.sh   # about 4 minutes
mise exec -- sh scripts/build-mpv.sh             # about an hour
mise exec -- sh scripts/build-mpv-macos.sh       # macOS with Xcode; about 12 minutes
mise exec -- sh scripts/package.sh libass 0      # dist/libass-0.17.5-0/
mise exec -- shellcheck scripts/*.sh
```

- The Android builds install the NDK they pin with sdkmanager from `ANDROID_HOME` (by default `~/Library/Android/sdk`) when it is missing.
- libmpv also needs autotools, pkg-config and gperf, and on macOS GNU sed, coreutils and bash 4 or later (Homebrew); nasm is built when missing. On Linux: `sudo apt-get install autoconf automake libtool pkg-config gperf nasm`.
- libmpv for macOS also needs pkg-config, and autotools when it builds nasm, which it does when nasm is missing (Homebrew: `brew install pkgconf nasm`). It finds only the libraries it builds, none that a package manager installed.
- `scripts/build-mpv.sh --sources` fetches libmpv's sources into `work/mpv/sources` without building.
- A second run with the same scripts and patches does nothing; `scripts/build-mpv-macos.sh` continues a failed run where it stopped. Intermediate builds are kept in `work/`, outputs in `out/`, packages in `dist/`; git ignores all three.

## Licenses

This repository's scripts are licensed under the [GPL-3.0](LICENSE), as Mavio is. Each release ships the exact sources of every component in its binaries and the scripts that built them in `<tag>-sources.tar.gz`, as the LGPL and the GPL require; each component's own license text is in its sources. Every license below is compatible with the GPL-3.0.

**libass for Apple**

| Component | License |
| :--- | :--- |
| libass | ISC |
| FreeType | FTL or GPL-2.0-or-later |
| FriBidi | LGPL-2.1-or-later |
| HarfBuzz | MIT |

**libmpv for Android** (GPL-3.0 as a whole)

| Component | License |
| :--- | :--- |
| mpv | GPL-2.0-or-later, built with `-Dgpl=true`; GPL-3.0 with FFmpeg |
| FFmpeg | GPL-3.0-or-later (`--enable-gpl --enable-version3`) |
| mpv-android (build scripts, JNI layer, `MPVLib.kt`) | MIT |
| libass | ISC |
| libplacebo | LGPL-2.1-or-later |
| dav1d | BSD-2-Clause |
| FreeType | FTL or GPL-2.0-or-later |
| FriBidi | LGPL-2.1-or-later |
| HarfBuzz | MIT |
| libunibreak | Zlib |
| fontconfig | HPND-sell-variant (MIT-style) |
| libxml2 | MIT |
| Lua | MIT |
| Mbed TLS | Apache-2.0 or GPL-2.0-or-later |
| curl | curl (MIT-style) |
| LLVM libc++ (`libc++_shared.so`, from the Android NDK) | Apache-2.0 with LLVM exception |

**libmpv for macOS** (GPL-3.0 as a whole)

| Component | License |
| :--- | :--- |
| mpv, with Mavio's patches to embed it in a host view (`patches/mpv-macos/wid.patch`) and to give its coreaudio output a channel map macOS takes (`patches/mpv-macos/coreaudio-channel-map.patch`) | GPL-2.0-or-later, built with `-Dgpl=true`; GPL-3.0 with FFmpeg |
| FFmpeg | GPL-3.0-or-later (`--enable-gpl --enable-version3`) |
| libass | ISC |
| FreeType | FTL or GPL-2.0-or-later |
| FriBidi | LGPL-2.1-or-later |
| HarfBuzz | MIT |
| libplacebo | LGPL-2.1-or-later |
| dav1d | BSD-2-Clause |
| Little CMS | MIT |
| glslang | BSD-3-Clause, BSD-2-Clause, MIT, Apache-2.0 and GPL-3.0-or-later with the Bison exception |
| MoltenVK | Apache-2.0 |
| SPIRV-Cross (in MoltenVK) | Apache-2.0 or MIT |
| SPIRV-Tools (in MoltenVK) | Apache-2.0 |
| SPIRV-Headers | MIT |
| Vulkan-Headers | Apache-2.0 or MIT |
| cereal (in MoltenVK) | BSD-3-Clause |

**Media3's FFmpeg decoder extension**

| Component | License |
| :--- | :--- |
| Media3 FFmpeg decoder extension | Apache-2.0 |
| FFmpeg | LGPL-2.1-or-later |
| LLVM libc++ (linked statically, from the Android NDK) | Apache-2.0 with LLVM exception |
