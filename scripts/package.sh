#!/bin/sh
# Packages a library that its build script has built into dist/<tag>/, the
# assets of its release <tag> = <library>-<version>-<revision>:
#   <tag>.xcframework.zip (libass) or <tag>.tar.gz (mpv, mpv-macos,
#     media3-ffmpeg), the binaries;
#   <tag>-sources.tar.gz, the sources of every component in them and the
#     scripts and patches that built them;
#   manifest.json, what the main repository reads: the assets, their URLs
#     and SHA-256 digests, and the components with their licenses;
#   SHA256SUMS, the digests of the other assets;
# and notes.md, the release notes. Prints the tag.
# Usage: scripts/package.sh <library> <revision>
# Markdown quotes code in backticks.
# shellcheck disable=SC2016
set -eu
cd "$(dirname "$0")/.."
root=$(pwd)

lib=${1:?usage: scripts/package.sh <library> <revision>}
revision=${2:?usage: scripts/package.sh <library> <revision>}
repository=https://github.com/mavioai/mavio-deps

# Each library: the directory its build writes into out/, and where the main
# repository extracts the archive, whose one top-level entry it is.
case $lib in
libass) dir=Libass.xcframework into=libs/apple/build ;;
mpv) dir=mpv into=libs/android/player/build ;;
mpv-macos) dir=mpv-macos into=apps/desktop/build ;;
media3-ffmpeg) dir=ffmpeg into=libs/android/player/build ;;
*)
	echo "package: unknown library $lib" >&2
	exit 2
	;;
esac
case $revision in
*[!0-9]* | "")
	echo "package: the revision must be a number" >&2
	exit 2
	;;
esac
version=$(sh "scripts/build-$lib.sh" --version)
tag=$lib-$version-$revision
sources=$root/work/$lib/sources
if [ ! -e "$root/out/$dir" ] || [ ! -f "$sources/COMPONENTS" ]; then
	echo "package: build $lib first: scripts/build-$lib.sh" >&2
	exit 1
fi

dist=$root/dist/$tag
rm -rf "$dist" && mkdir -p "$dist"

sha256() {
	if command -v sha256sum >/dev/null; then
		sha256sum "$1" | cut -d' ' -f1
	else
		shasum -a 256 "$1" | cut -d' ' -f1
	fi
}
size() {
	wc -c <"$1" | tr -d ' '
}

# The binaries.
if [ "$lib" = libass ]; then
	binary=$tag.xcframework.zip
	# The archive SwiftPM's binaryTarget(url:checksum:) takes.
	(cd "$root/out" && ditto -c -k --keepParent "$dir" "$dist/$binary")
else
	binary=$tag.tar.gz
	tar -czf "$dist/$binary" -C "$root/out" "$dir"
fi

# The sources, with this repository's scripts, patches, tools and license.
staging=$root/work/package/$tag-sources
rm -rf "$staging" && mkdir -p "$staging"
cp -R LICENSE README.md README.zh-CN.md mise.toml scripts patches "$staging/"
cp -R "$sources" "$staging/sources"
source=$tag-sources.tar.gz
tar -czf "$dist/$source" -C "$(dirname "$staging")" "$tag-sources"
rm -rf "$staging"

binary_sha=$(sha256 "$dist/$binary")
if [ "$lib" = libass ]; then
	# SwiftPM's checksum is the archive's SHA-256.
	# Run in work/, where SwiftPM leaves its .build directory.
	checksum=$(cd "$root/work" && swift package compute-checksum "$dist/$binary")
	if [ "$checksum" != "$binary_sha" ]; then
		echo "package: swift package compute-checksum = $checksum, want = $binary_sha" >&2
		exit 1
	fi
fi
source_sha=$(sha256 "$dist/$source")
url=$repository/releases/download/$tag

# json string: string as a JSON string.
json() {
	printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}
tab=$(printf '\t')
{
	printf '{\n'
	printf '  "schema": 1,\n'
	printf '  "library": %s,\n' "$(json "$lib")"
	printf '  "version": %s,\n' "$(json "$version")"
	printf '  "revision": %s,\n' "$revision"
	printf '  "tag": %s,\n' "$(json "$tag")"
	printf '  "binary": {\n'
	printf '    "name": %s,\n' "$(json "$binary")"
	printf '    "url": %s,\n' "$(json "$url/$binary")"
	printf '    "sha256": %s,\n' "$(json "$binary_sha")"
	printf '    "size": %s,\n' "$(size "$dist/$binary")"
	printf '    "extract_to": %s,\n' "$(json "$into")"
	printf '    "path": %s\n' "$(json "$into/$dir")"
	printf '  },\n'
	printf '  "sources": {\n'
	printf '    "name": %s,\n' "$(json "$source")"
	printf '    "url": %s,\n' "$(json "$url/$source")"
	printf '    "sha256": %s,\n' "$(json "$source_sha")"
	printf '    "size": %s\n' "$(size "$dist/$source")"
	printf '  },\n'
	printf '  "components": [\n'
	sep=""
	while IFS=$tab read -r name cversion license upstream; do
		printf '%s    {"name": %s, "version": %s, "license": %s, "upstream": %s}' "$sep" \
			"$(json "$name")" "$(json "$cversion")" "$(json "$license")" "$(json "$upstream")"
		sep=",
"
	done <"$sources/COMPONENTS"
	printf '\n  ]\n'
	printf '}\n'
} >"$dist/manifest.json"

(cd "$dist" && for f in "$binary" "$source" manifest.json; do
	printf '%s  %s\n' "$(sha256 "$f")" "$f"
done) >"$dist/SHA256SUMS"

{
	printf '%s %s, revision %s, built by `scripts/build-%s.sh`.\n\n' "$lib" "$version" "$revision" "$lib"
	printf '| Asset | SHA-256 |\n| :--- | :--- |\n'
	while read -r sum file; do
		printf '| `%s` | `%s` |\n' "$file" "$sum"
	done <"$dist/SHA256SUMS"
	printf '\nExtract `%s` into `%s`.\n' "$binary" "$into"
	if [ "$lib" = libass ]; then
		printf '\n```swift\n.binaryTarget(\n    name: "Libass",\n    url: "%s",\n    checksum: "%s"\n),\n```\n' \
			"$url/$binary" "$binary_sha"
	fi
	printf '\n| Component | Version | License |\n| :--- | :--- | :--- |\n'
	while IFS=$tab read -r name cversion license upstream; do
		printf '| [%s](%s) | `%s` | %s |\n' "$name" "$upstream" "$cversion" "$license"
	done <"$sources/COMPONENTS"
	printf '\n`%s` holds the sources of every component and the scripts and patches that built them.\n' "$source"
} >"$dist/notes.md"

echo "$tag"
