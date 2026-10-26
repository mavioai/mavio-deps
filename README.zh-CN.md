# mavio-deps

> [English](README.md) | 简体中文

[Mavio](https://github.com/mavioai/mavio) 客户端所链接的原生第三方库：从源码构建，作为带版本、带校验和的 GitHub Release 资产发布。Mavio 仓库下载、校验并解压它们，而不再自行编译：仅 libmpv 一项就要构建约一小时。

## 库

| 库 | 脚本 | Runner | 发布版本 | 二进制资产 | 解压到（Mavio） |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Apple 版 libass | `scripts/build-libass.sh` | `macos-latest` | libass 的版本 | `<tag>.xcframework.zip` → `Libass.xcframework/` | `libs/apple/build/` |
| Android 版 libmpv | `scripts/build-mpv.sh` | `ubuntu-latest` | mpv 的版本 | `<tag>.tar.gz` → `mpv/` | `libs/android/player/build/` |
| macOS 版 libmpv | `scripts/build-mpv-macos.sh` | `macos-latest` | mpv 的版本 | `<tag>.tar.gz` → `mpv-macos/` | `apps/desktop/build/` |
| Media3 的 FFmpeg 解码扩展 | `scripts/build-media3-ffmpeg.sh` | `ubuntu-latest` | Media3 的版本 | `<tag>.tar.gz` → `ffmpeg/` | `libs/android/player/build/` |

- **libass**：每个平台一个静态库（iOS、iOS 模拟器、tvOS、tvOS 模拟器，以及 arm64 + x86_64 通用的 macOS），链接了 FreeType、FriBidi 与 HarfBuzz，以 Core Text 作为字体提供者，打包为 `Libass.xcframework`，其模块 `Libass` 导出 `ass.h`。Mavio 的 Apple 播放器用它渲染 ASS 字幕。
- **libmpv**：用 mpv-android 的构建脚本与 JNI 层构建：`mpv/jniLibs/<abi>/` 含 `arm64-v8a`、`armeabi-v7a`、`x86_64` 的 libmpv、FFmpeg、libc++ 与 `libplayer.so`（JNI 层），`mpv/kotlin/is/xyz/mpv/MPVLib.kt` 是 mpv-android 调用它的 Kotlin API。FFmpeg 与 mpv 以 GPL-3.0 构建。
- **macOS 版 libmpv**：供 Mavio 桌面应用在运行时加载。`mpv-macos/lib/` 含 `libmpv.2.dylib`（arm64 + x86_64 通用，静态链接了 FFmpeg、libass、libplacebo 及其依赖）与 `libMoltenVK.dylib`（它直接链接的 Vulkan 驱动，不经 Vulkan loader，也不需要 ICD 文件）；`mpv-macos/include/mpv/` 是客户端 API 的头文件。两者的 install name 均为 `@rpath/<name>`，应用把它们放进 `Contents/Frameworks` 并把该目录加入运行路径即可；除系统库外它们不链接任何库。需要 macOS 13 或更高版本。mpv 以 `vo=gpu-next`、`gpu-context=macvk` 渲染（经 MoltenVK 的 Vulkan，经 EDR 输出 HDR），以 VideoToolbox 解码；Mavio 的补丁 `patches/mpv-macos/wid.patch` 让它嵌入以 `--wid` 传入的宿主 `NSView`（以 int64 表示的 `NSView *`）：在宿主布局的一个子视图中绘制，而不自建窗口；`patches/mpv-macos/coreaudio-channel-map.patch` 让 coreaudio 输出在 macOS 拒绝 mpv 作为声道映射传入的声道布局时仍能启动，否则 mpv 会退回到预先排入两秒音频的 avfoundation 输出。FFmpeg 与 mpv 以 GPL-3.0 构建。
- **Media3 的 FFmpeg 解码扩展**（官方没有发布制品）：`ffmpeg/jniLibs/<abi>/libffmpegJNI.so` 是其 JNI 层，链接了只含音频解码器的 LGPL FFmpeg；`ffmpeg/java/` 是其音频渲染器。它与 Media3 版本绑定，该版本必须与 Mavio 的 `libs/android/gradle/libs.versions.toml` 一致。

每个脚本在开头的变量中固定所有版本，并在 `out/` 下写出 Mavio 仓库所使用的目录（见上表）；构建所用的源码放入 `work/<library>/sources/`。构建时对某个库的源码打的补丁放在 `patches/<library>/`。

## 标签规则

发布的标签为 `<library>-<version>-<revision>`：

- `<library>` 为 `libass`、`mpv`、`mpv-macos` 或 `media3-ffmpeg`。
- `<version>` 是脚本为该库固定的版本，由 `scripts/build-<library>.sh --version` 打印，不含连字符。libass 与 Media3 使用各自的发布版本；mpv 固定在某个提交上，使用其最近的发布版本加提交的前七位十六进制数字：`<release>.g<commit>`。
- `<revision>` 对每个版本从 1 开始；同一版本的后续发布若改动了其他任何内容（其他固定版本、构建选项、脚本），则递增。修订号 0 标记拉取请求与手动运行的测试构建，永不打标签。

例如 `libass-0.17.5-1`、`mpv-0.41.0.g88eb9f2-1`、`mpv-macos-0.41.0.g88eb9f2-1`、`media3-ffmpeg-1.11.1-1`。

## 资产与清单

每个发布 `<tag>` 有四个资产，地址为 `https://github.com/mavioai/mavio-deps/releases/download/<tag>/<asset>`：

| 资产 | 内容 |
| :--- | :--- |
| `<tag>.xcframework.zip`（libass）或 `<tag>.tar.gz`（其他库） | 二进制：一个顶层目录，`Libass.xcframework`、`mpv`、`mpv-macos` 或 `ffmpeg`。 |
| `<tag>-sources.tar.gz` | `<tag>-sources/`：`sources/` 下是二进制中每个组件的确切源码及 `sources/COMPONENTS`，另有本仓库的脚本、补丁、`mise.toml`、README 与许可证。 |
| `manifest.json` | 下述机器可读的描述。 |
| `SHA256SUMS` | 其余三个资产的 SHA-256 摘要，`sha256sum` 格式。 |

发布说明重复列出这些摘要，并列出各组件及其许可证。`manifest.json`：

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
    "sha256": "<64 位十六进制>",
    "size": 12345678,
    "extract_to": "libs/apple/build",
    "path": "libs/apple/build/Libass.xcframework"
  },
  "sources": {
    "name": "libass-0.17.5-1-sources.tar.gz",
    "url": "https://github.com/mavioai/mavio-deps/releases/download/libass-0.17.5-1/libass-0.17.5-1-sources.tar.gz",
    "sha256": "<64 位十六进制>",
    "size": 12345678
  },
  "components": [
    {"name": "libass", "version": "0.17.5", "license": "ISC", "upstream": "https://github.com/libass/libass"}
  ]
}
```

`binary.extract_to` 是二进制归档解压到的目录（相对 Mavio 仓库根目录）；`binary.path` 是解压后得到的目录。Mavio 仓库固定一个标签及二进制的 `sha256`，下载 `binary.url`，校验摘要后解压。

## 在 Mavio 中使用

**libass**：SwiftPM 自行下载并校验归档；其校验和由 `swift package compute-checksum` 计算，即归档的 SHA-256：

```swift
.binaryTarget(
    name: "Libass",
    url: "https://github.com/mavioai/mavio-deps/releases/download/libass-0.17.5-1/libass-0.17.5-1.xcframework.zip",
    checksum: "<binary.sha256>"
),
```

**libmpv 与 FFmpeg 扩展**：把 `<tag>.tar.gz` 解压到 `libs/android/player/build/`，得到 `libs/android/player/build/mpv` 与 `libs/android/player/build/ffmpeg`。播放器的 Gradle 构建已把 `build/mpv/kotlin`、`build/ffmpeg/java` 及两个 `jniLibs` 目录加为源码目录。

**macOS 版 libmpv**：把 `<tag>.tar.gz` 解压到 `apps/desktop/build/`，得到 `apps/desktop/build/mpv-macos`。应用包把两个 dylib 放在 `Contents/Frameworks`，可执行文件的运行路径为 `@executable_path/../Frameworks`，并用 purego 加载 `libmpv.2.dylib`；mpv 需要应用的 `NSApplication` 及其主运行循环，在其上布局自己的视图。

## 发布

1. 修改脚本开头的固定版本并测试：拉取请求会构建其改动了脚本或补丁的库（改动 `scripts/lib.sh`、`scripts/package.sh`、`mise.toml` 或 `.github/` 时构建所有库），并把打包结果上传为 workflow 制品；手动运行 Release workflow 则构建所指定的库。
2. 合并后，在 `main` 的提交上打标签 `<library>-<version>-<revision>`（版本即 `sh scripts/build-<library>.sh --version` 的输出），并推送标签：

   ```bash
   git tag libass-0.17.5-1
   git push origin libass-0.17.5-1
   ```

3. Release workflow 在对应 runner 上构建该库，检查标签与脚本固定的版本一致，打包并创建 GitHub Release，资产齐全，摘要写入发布说明。它需要 `contents: write`，workflow 已声明；仓库的 Actions 设置须允许。
4. 在 Mavio 仓库中更新标签与摘要。

## 本地构建

工具版本固定在 `mise.toml` 中（meson、ninja、CMake、供 sdkmanager 使用的 Java、ShellCheck）：

```bash
mise install
mise exec -- sh scripts/build-libass.sh          # 需 macOS 与 Xcode；约 4 分钟
mise exec -- sh scripts/build-media3-ffmpeg.sh   # 约 4 分钟
mise exec -- sh scripts/build-mpv.sh             # 约一小时
mise exec -- sh scripts/build-mpv-macos.sh       # 需 macOS 与 Xcode；约 12 分钟
mise exec -- sh scripts/package.sh libass 0      # dist/libass-0.17.5-0/
mise exec -- shellcheck scripts/*.sh
```

- Android 构建在缺少所固定的 NDK 时，用 `ANDROID_HOME`（默认 `~/Library/Android/sdk`）中的 sdkmanager 安装。
- libmpv 还需要 autotools、pkg-config 与 gperf，在 macOS 上还需要 GNU sed、coreutils 与 bash 4 以上（Homebrew）；缺少 nasm 时会自行构建。Linux 上：`sudo apt-get install autoconf automake libtool pkg-config gperf nasm`。
- macOS 版 libmpv 还需要 pkg-config；缺少 nasm 时会自行构建，此时需要 autotools（Homebrew：`brew install pkgconf nasm`）。它只使用自己构建的库，不会用到包管理器安装的库。
- `scripts/build-mpv.sh --sources` 只把 libmpv 的源码获取到 `work/mpv/sources`，不构建。
- 脚本与补丁不变时再次运行什么也不做；`scripts/build-mpv-macos.sh` 会从失败的运行停下处继续。中间构建保存在 `work/`，输出在 `out/`，打包结果在 `dist/`；三者均被 git 忽略。

## 许可证

本仓库的脚本以 [GPL-3.0](LICENSE) 授权，与 Mavio 相同。按 LGPL 与 GPL 的要求，每个发布都在 `<tag>-sources.tar.gz` 中附带其二进制中每个组件的确切源码及构建它们的脚本；各组件自身的许可证文本在其源码中。下列许可证均与 GPL-3.0 兼容。

**Apple 版 libass**

| 组件 | 许可证 |
| :--- | :--- |
| libass | ISC |
| FreeType | FTL 或 GPL-2.0-or-later |
| FriBidi | LGPL-2.1-or-later |
| HarfBuzz | MIT |

**Android 版 libmpv**（整体为 GPL-3.0）

| 组件 | 许可证 |
| :--- | :--- |
| mpv | GPL-2.0-or-later，以 `-Dgpl=true` 构建；与 FFmpeg 结合为 GPL-3.0 |
| FFmpeg | GPL-3.0-or-later（`--enable-gpl --enable-version3`） |
| mpv-android（构建脚本、JNI 层、`MPVLib.kt`） | MIT |
| libass | ISC |
| libplacebo | LGPL-2.1-or-later |
| dav1d | BSD-2-Clause |
| FreeType | FTL 或 GPL-2.0-or-later |
| FriBidi | LGPL-2.1-or-later |
| HarfBuzz | MIT |
| libunibreak | Zlib |
| fontconfig | HPND-sell-variant（MIT 风格） |
| libxml2 | MIT |
| Lua | MIT |
| Mbed TLS | Apache-2.0 或 GPL-2.0-or-later |
| curl | curl（MIT 风格） |
| LLVM libc++（`libc++_shared.so`，来自 Android NDK） | Apache-2.0 with LLVM exception |

**macOS 版 libmpv**（整体为 GPL-3.0）

| 组件 | 许可证 |
| :--- | :--- |
| mpv，含 Mavio 用于将其嵌入宿主视图（`patches/mpv-macos/wid.patch`）与启动其 coreaudio 输出（`patches/mpv-macos/coreaudio-channel-map.patch`）的补丁 | GPL-2.0-or-later，以 `-Dgpl=true` 构建；与 FFmpeg 结合为 GPL-3.0 |
| FFmpeg | GPL-3.0-or-later（`--enable-gpl --enable-version3`） |
| libass | ISC |
| FreeType | FTL 或 GPL-2.0-or-later |
| FriBidi | LGPL-2.1-or-later |
| HarfBuzz | MIT |
| libplacebo | LGPL-2.1-or-later |
| dav1d | BSD-2-Clause |
| Little CMS | MIT |
| glslang | BSD-3-Clause、BSD-2-Clause、MIT、Apache-2.0 及带 Bison 例外的 GPL-3.0-or-later |
| MoltenVK | Apache-2.0 |
| SPIRV-Cross（MoltenVK 内） | Apache-2.0 或 MIT |
| SPIRV-Tools（MoltenVK 内） | Apache-2.0 |
| SPIRV-Headers | MIT |
| Vulkan-Headers | Apache-2.0 或 MIT |
| cereal（MoltenVK 内） | BSD-3-Clause |

**Media3 的 FFmpeg 解码扩展**

| 组件 | 许可证 |
| :--- | :--- |
| Media3 FFmpeg 解码扩展 | Apache-2.0 |
| FFmpeg | LGPL-2.1-or-later |
| LLVM libc++（静态链接，来自 Android NDK） | Apache-2.0 with LLVM exception |
