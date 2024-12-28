#!/usr/bin/env bats

function gitInit {
	cd "$BATS_TEST_TMPDIR" || false
	git init >/dev/null 2>&1 || true
	git config user.name "Your Name"
	git config user.email "you@example.com"
}

function createGitFile {
	cd "$BATS_TEST_TMPDIR" || false
	mkdir -p "$(dirname "$1")"
	touch "$1"
	git add "$1" >/dev/null 2>&1 
	git commit -m "createGitFile" >/dev/null 2>&1 
}

# $1: From
# $2: To
function createGitSymlink {
	cd "$BATS_TEST_TMPDIR" || false
	mkdir -p "$(dirname "$2")"
	ln -s "$1" "$2"
	git add "$2" >/dev/null 2>&1 
	git commit -m "createGitSymlink" >/dev/null 2>&1 
}

function createNonGitFile {
	cd "$BATS_TEST_TMPDIR" || false
	mkdir -p "$(dirname "$1")"
	touch "$1"
}

function compareWithFindCd {
	cd "$1" || false
	shift

	local argsFind=()
	while [ ! "$1" == '--' ]; do
		argsFind+=("$1")
		shift
	done
	shift
	local argsGitFind=("$@")
	local gitFindRes
	local findRes

	set -o pipefail
	if ! gitFindRes="$("$BATS_TEST_DIRNAME"/git-find "${argsGitFind[@]}" 2>&1 | sort)"; then
		echo "$gitFindRes"
		return 1
	fi
	if ! findRes="$(find "${argsFind[@]}" 2>&1 | sort)"; then
		echo "$findRes"
		return 2
	fi
	set +o pipefail

	diff -C10 /dev/fd/5 /dev/fd/4 4<<<"$findRes" 5<<<"$gitFindRes"
}

function compareWithFind {
	compareWithFindCd "$BATS_TEST_TMPDIR" "$@"
}

@test "git-find --help" {
	cd /
	run "$BATS_TEST_DIRNAME"/git-find --help
	[ "$status" -eq 0 ]
	[[ "$output" =~ Usage:\ git-find ]]

	gitInit
	cd "$BATS_TEST_TMPDIR"
	createGitFile foo

	run "$BATS_TEST_DIRNAME"/git-find --help -delete
	[ "$status" -eq 0 ]
	[[ "$output" =~ Usage:\ git-find ]]

	# Make sure foo still exists (=> thus find wasn't run)
	test -f foo
}
@test "git-find: Empty git repo" {
	gitInit
	cd "$BATS_TEST_TMPDIR"
	run "$BATS_TEST_DIRNAME"/git-find .
	# shellcheck disable=SC2103
	cd -
	[ "$status" -eq 0 ]
	[ "$output" == "" ]
}
@test "git-find: Various starting points" {
	gitInit
	createGitFile "foo/bar/afile"
	createGitFile "with-hidden-file/.dotfile"
	createGitFile "file-in-top-dir"
	mkdir "$BATS_TEST_TMPDIR/empty-folder"

	while true; do
		# Director(y|ies) as starting point(s)
		compareWithFind . -type f -not -path '*.git*' -- .
		compareWithFind -name afile -type f -not -path '*.git*' -- -name afile
		compareWithFind empty-folder -type f -not -path '*.git*' -- empty-folder
		compareWithFind . -type f -path '*hidden*' -not -path '*.git*' -- . -path '*hidden*'
		compareWithFind . . . -type f -not -path '*.git*' -- . . .
		compareWithFind -type f -not -path '*.git*' --
		compareWithFind ./ -type f -not -path '*.git*' -- ./
		compareWithFind .// -type f -not -path '*.git*' -- .//
		compareWithFind "$BATS_TEST_TMPDIR" -type f -not -path '*.git*' -- "$BATS_TEST_TMPDIR"
		compareWithFind "$BATS_TEST_TMPDIR"/ -type f -not -path '*.git*' -- "$BATS_TEST_TMPDIR"/
		compareWithFind "$BATS_TEST_TMPDIR"/// -type f -not -path '*.git*' -- "$BATS_TEST_TMPDIR"///
		compareWithFind "$BATS_TEST_TMPDIR"//../"$(basename "$BATS_TEST_TMPDIR")"/ -type f -not -path '*.git*' -- "$BATS_TEST_TMPDIR"//../"$(basename "$BATS_TEST_TMPDIR")"/
		compareWithFind ./foo/.. -type f -not -path '*.git*' -- ./foo/..
		compareWithFind ./foo///.. -type f -not -path '*.git*' -- ./foo///..
		compareWithFind ./foo//bar/.././.. -type f -not -path '*.git*' -- ./foo//bar/.././..
		compareWithFind foo/bar/.././.. -type f -not -path '*.git*' -- foo/bar/.././..
		compareWithFind . foo/// . -type f -not -path '*.git*' -- . foo/// .
		compareWithFind . -type f -not -path '*.git*' -name 'afi*' -- . -name 'afi*'
		compareWithFind . -type f -not -path '*.git*' -- . -name 'afi*' -or -true
		compareWithFind . -type f -not -path '*.git*' -- -or -true
		compareWithFindCd "$BATS_TEST_TMPDIR/foo" .. -type f -not -path '*.git*' -- ..
		compareWithFindCd "$BATS_TEST_TMPDIR/foo" ../with-hidden-file -type f -not -path '*.git*' -- ../with-hidden-file
		compareWithFindCd "$BATS_TEST_TMPDIR/foo/bar" .. -type f -not -path '*.git*' -- ..
		compareWithFindCd "$BATS_TEST_TMPDIR/foo/bar" ../.. -type f -not -path '*.git*' -- ../..
		compareWithFindCd "$BATS_TEST_TMPDIR/foo/bar" ../bar/../.. -type f -not -path '*.git*' -- ../bar/../..
		compareWithFindCd "$BATS_TEST_TMPDIR/with-hidden-file" .. -type f -not -path '*.git*' -- ..
		compareWithFindCd "$BATS_TEST_TMPDIR/empty-folder" . -type f -- .
		compareWithFindCd "$BATS_TEST_TMPDIR/empty-folder" .. -type f -not -path '*.git*' -- ..

		# File(s) as starting point(s)
		compareWithFind with-hidden-file/.dotfile -type f -not -path '*.git*' -- with-hidden-file/.dotfile
		compareWithFind foo/bar/afile -- foo/bar/afile
		compareWithFind foo/bar/afile foo/bar/afile -- foo/bar/afile foo/bar/afile
		compareWithFind foo/bar/afile file-in-top-dir -- foo/bar/afile file-in-top-dir
		compareWithFind foo/bar/../bar/afile -- foo/bar/../bar/afile
		compareWithFindCd "$BATS_TEST_TMPDIR/foo" bar/afile -type f -not -path '*.git*' -- bar/afile

		# File(s) and director(y|ies) as starting points
		compareWithFind foo/bar/afile . -type f -not -path '*.git*' -- foo/bar/afile .
		compareWithFind foo/bar/..//bar/afile . -type f -not -path '*.git*' -- foo/bar/..//bar/afile .

		# Run all of these tests again with a changed file
		[ "$(cat foo/bar/afile)" == "changed" ] && break
		echo changed > "foo/bar/afile"
	done

	createGitFile "file-with"$'\n'"newline"
	createGitFile "Юникод😁"
	compareWithFind . -type f -not -path '*.git*' -- .
}
@test "git-find: Symlinks in git" {
	gitInit
	createGitFile file-in-top-dir
	createGitSymlink file-in-top-dir foo/a-symlink

	compareWithFind . -not -type d -not -path '*.git*' -- .
	compareWithFind foo -not -type d -not -path '*.git*' -- foo
	compareWithFind foo/a-symlink -not -path '*.git*' -- foo/a-symlink

	createGitFile subfolder/file
	createGitSymlink subfolder symlink-to-subfolder

	compareWithFind . -type l -not -path '*.git*' -- . -type l
	compareWithFind symlink-to-subfolder -not -path '*.git*' -- symlink-to-subfolder
	compareWithFind symlink-to-subfolder symlink-to-subfolder -not -path '*.git*' -- symlink-to-subfolder symlink-to-subfolder
	compareWithFind symlink-to-subfolder symlink-to-subfolder/file -not -path '*.git*' -- symlink-to-subfolder symlink-to-subfolder/file

	ln -s subfolder symlink-not-in-git
	compareWithFind -false -- symlink-not-in-git
}
@test "git-find: Starting-point doesn't exist" {
	gitInit

	# Output should exactly match find's
	run find nope
	expectedStatus="$status"
	expectedOutput="$output"

	run "$BATS_TEST_DIRNAME"/git-find nope
	[ "$status" -eq  "$expectedStatus" ]
	[ "$output" == "$expectedOutput" ]

	createGitFile "foo/bar"
	run "$BATS_TEST_DIRNAME"/git-find nope foo
	[ "${lines[0]}" == "find: ‘nope’: No such file or directory" ]
	[ "${lines[1]}" == "foo/bar" ]

	run "$BATS_TEST_DIRNAME"/git-find foo nope
	[ "${lines[0]}" == "foo/bar" ]
	[ "${lines[1]}" == "find: ‘nope’: No such file or directory" ]
}
@test "git-find: Starting-point not git indexed" {
	gitInit
	cd "$BATS_TEST_TMPDIR"
	mkdir not-in-git

	run "$BATS_TEST_DIRNAME"/git-find not-in-git
	[ "$status" -eq 0 ]
	[ "$output" == "" ]

	createGitFile "foo/bar/afile"
	compareWithFind . -type f -not -path '*.git*' -- .
	compareWithFind . -type f -not -path '*.git*' -- . not-in-git
	compareWithFind . -type f -not -path '*.git*' -- . not-in-git/
	compareWithFind . -type f -not -path '*.git*' -- . not-in-git/../not-in-git
	compareWithFind -false -- ./not-in-git
}
@test "git-find: Not a git repo" {
	cd "$BATS_TEST_TMPDIR"

	# Output should exactly match git's
	run git status
	expectedStatus="$status"
	expectedOutput="$output"

	run "$BATS_TEST_DIRNAME"/git-find
	[ "$status" -eq  "$expectedStatus" ]
	[ "$output" == "$expectedOutput" ]
}
@test "git-find: Starting-point outside of git repo" {
	cd "$BATS_TEST_TMPDIR"
	mkdir foo
	cd foo
	git init .

	run "$BATS_TEST_DIRNAME"/git-find ..
	[ "$status" -eq 255 ]
	[ "$output" == "Error: Starting point \"..\" is outside of the current git directory. Giving up." ]

	run "$BATS_TEST_DIRNAME"/git-find . ..
	[ "$status" -eq 255 ]
	[ "$output" == "Error: Starting point \"..\" is outside of the current git directory. Giving up." ]
}
@test "git-find: -mindepth and -maxdepth" {
	function matchMinMaxDepthError {
		[ "$output" == "Error: git-find doesn't support \"-$1depth\"." ]
	}
	gitInit

	run "$BATS_TEST_DIRNAME"/git-find . -type f -mindepth 3
	[ "$status" -eq 1 ]
	matchMinMaxDepthError min

	run "$BATS_TEST_DIRNAME"/git-find . -type f -mindepth 3
	[ "$status" -eq 1 ]
	matchMinMaxDepthError min

	run "$BATS_TEST_DIRNAME"/git-find . -type f -maxdepth 0
	[ "$status" -eq 1 ]
	matchMinMaxDepthError max

	run "$BATS_TEST_DIRNAME"/git-find . -type l -maxdepth 1
	[ "$status" -eq 1 ]
	matchMinMaxDepthError max

	run "$BATS_TEST_DIRNAME"/git-find -maxdepth 1
	[ "$status" -eq 1 ]
	matchMinMaxDepthError max

	run "$BATS_TEST_DIRNAME"/git-find -mindepth 1
	[ "$status" -eq 1 ]
	matchMinMaxDepthError min

	run "$BATS_TEST_DIRNAME"/git-find maxdepth -mindepth 1 -maxdepth 10
	[ "$status" -eq 1 ]
	matchMinMaxDepthError min
}
@test "git-find: git indexed file deleted" {
	gitInit
	createGitFile "foo/afile"
	createGitFile "foo/bfile"
	rm "$BATS_TEST_TMPDIR/foo/bfile"

	compareWithFind . -type f -not -path '*.git*' -- .
}
@test "git-find: find options" {
	gitInit
	createGitFile "foo/afile"
	createGitFile "foo/bfile"
	createGitSymlink foo/afile a-symlink

	# Symlink related options
	compareWithFind -P . -not -type d -not -path '*.git*' -- -P .
	compareWithFind -L . -not -type d -not -path '*.git*' -- -L .
	compareWithFind -L . -not -type d -not -path '*.git*' -ls -- -L . -ls
	compareWithFind -H . -not -type d -not -path '*.git*' -- -H .
	compareWithFind -H a-symlink -not -type d -not -path '*.git*' -ls -- -H a-symlink -ls
	compareWithFind -O3 -H a-symlink -not -type d -not -path '*.git*' -ls -- -O3 -H a-symlink -ls

	# Query optimisation options
	compareWithFind -O0 . -not -type d -not -path '*.git*' -- -O0 .
	compareWithFind -O1 . -not -type d -not -path '*.git*' -- -O1 .
	compareWithFind -O2 . -not -type d -not -path '*.git*' -- -O2 .
	compareWithFind -O3 . -not -type d -not -path '*.git*' -- -O3 .
	compareWithFind -P -O3 . -not -type d -not -path '*.git*' -- -P -O3 .
	compareWithFind -O3 -P . -not -type d -not -path '*.git*' -- -O3 -P .

	# Debug options
	compareWithFind -D rates foo/afile -maxdepth 0 -- -D rates foo/afile
	compareWithFind -D rates foo/afile -maxdepth 0 -exec true \; -- -D rates foo/afile -exec true \;
}
