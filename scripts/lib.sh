# shellcheck shell=sh
# Functions the build scripts share; they source it from the repository root.

# fetch dir repository revision [--recursive | path]: checks out a revision
# of a repository into dir, with its submodules when --recursive is given,
# or only the path under it. A directory that exists is kept as it is.
fetch() {
	[ -d "$1" ] && return
	git init -q "$1"
	case ${4:-} in
	"" | --recursive) ;;
	*) git -C "$1" sparse-checkout set "$4" ;;
	esac
	git -C "$1" fetch -q --depth 1 "$2" "$3"
	git -C "$1" -c advice.detachedHead=false checkout -q FETCH_HEAD
	if [ "${4:-}" = --recursive ]; then
		git -C "$1" submodule -q update --init --recursive --depth 1
	fi
}

# snapshot dir dest [path...]: copies the sources of dir into dest. Of a git
# work tree, those are the files its commit and its submodules track, under
# the paths when given, which must be unmodified; build outputs inside it are
# left out. Of any other directory, every file.
snapshot() {
	snap_src=$1 snap_dest=$2
	shift 2
	rm -rf "$snap_dest" && mkdir -p "$snap_dest"
	if [ -e "$snap_src/.git" ]; then
		if [ -n "$(git -C "$snap_src" status --porcelain --untracked-files=no -- "$@")" ]; then
			echo "snapshot: $snap_src has modified files" >&2
			return 1
		fi
		git -C "$snap_src" ls-files -z --recurse-submodules -- "$@" |
			(cd "$snap_src" && tar -cf - --no-recursion --null -T -) |
			tar -xf - -C "$snap_dest"
	else
		cp -R "$snap_src/." "$snap_dest/"
	fi
}

# component file name version license upstream: records a component that a
# build links in or ships, one tab-separated line in file.
component() {
	printf '%s\t%s\t%s\t%s\n' "$2" "$3" "$4" "$5" >>"$1"
}

# ndk version: prints the directory of the Android NDK of version, which it
# installs with sdkmanager when it is missing.
ndk() {
	ndk_sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
	if [ ! -d "$ndk_sdk/ndk/$1" ]; then
		yes | "$ndk_sdk/cmdline-tools/latest/bin/sdkmanager" --install "ndk;$1" >/dev/null
	fi
	echo "$ndk_sdk/ndk/$1"
}
