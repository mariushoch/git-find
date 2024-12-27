# git-find

Script that wraps [`find`](https://www.gnu.org/software/findutils/) to limit it to files indexed in git.

This is to `find` what [`git grep`](https://git-scm.com/docs/git-grep) is to `grep`.

[![asciicast](https://asciinema.org/a/FmbgaA1RV3lqD1G3vmqHxex8e.svg)](https://asciinema.org/a/FmbgaA1RV3lqD1G3vmqHxex8e)

## Usage

```
Usage: git-find [-H] [-L] [-P] [-D debugopts] [-Olevel] [starting-point...] [expression]

Search for files in the current git repository.

find expressions are fully supported, except for "-maxdepth" and "-mindepth".
For further details, see "man 1 find".
```

## Requirements
This script requires `git`, `bash`, `find` and `coreutils`.

## Known limitations
1. The `-maxdepth` and `-mindepth` find expressions aren't supported.
1. Directories will not be included in the results, as git doesn't index directories.
