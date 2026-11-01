#!/bin/sh
#
# Checks a repository's layout against its `.clang-format`; it only reads, and exits non-zero on any finding.
# Run from anywhere inside the repository; the format-check action runs it in the caller's checkout.
#
# 1. clang-format: every C++ file matches `.clang-format`.
# 2. Visual alignment: no code line indented more than 2 past the code line above it (`check-format.awk`).
#    clang-format accepts its own output, and its output aligns in a few shapes it cannot avoid
#    (`<<` under `<<`, a literal under a literal, a ternary hung from a `(`), so this is checked apart.
# 3. Padded trailing comments: no `//` after two or more spaces, in code, doc comments or the Markdown files.
# 4. With FORMAT_TABS=true, no tab in the C++ files.
#
# Use the clang-format the action installs (`pipx install clang-format==23.1.3`); another version may format
# differently. To fix a file: `clang-format -i <file>`.
#
# Environment, each a space-separated list of git pathspecs:
#   FORMAT_FILES     the C++ files (default: *.hpp *.cpp); extensionless headers by name or :(glob)include/<name>/*
#   FORMAT_EXCLUDE   paths to leave out (default: none)
#   FORMAT_MARKDOWN  the Markdown files (default: README*.md)
#   FORMAT_TABS      true adds check 4 (default: false)
#   CLANG_FORMAT     the clang-format to run (default: clang-format)
#
# Example, from a repository's root:
#   FORMAT_FILES='*.hpp *.cpp :(glob)include/<name>/*' path/to/.github/actions/format-check/check-format.sh

set -eu

here=$(cd "$(dirname "$0")" && pwd)
if ! top=$(git rev-parse --show-toplevel); then
    echo "check-format: run it inside a git checkout (in CI, after actions/checkout)" >&2
    exit 1
fi
cd "$top"
CLANG_FORMAT=${CLANG_FORMAT:-clang-format}
FORMAT_FILES=${FORMAT_FILES:-'*.hpp *.cpp'}
FORMAT_EXCLUDE=${FORMAT_EXCLUDE:-}
FORMAT_MARKDOWN=${FORMAT_MARKDOWN:-'README*.md'}
FORMAT_TABS=${FORMAT_TABS:-false}
failed=0

case "$FORMAT_TABS" in
    true | false) ;;
    *)
        echo "check-format: FORMAT_TABS must be true or false, not $FORMAT_TABS" >&2
        exit 1
        ;;
esac

# The lists are pathspecs for git, never globs for the shell.
set -f

excludes() {
    for path in $FORMAT_EXCLUDE; do
        printf ':(exclude)%s\n' "$path"
    done
}

# Listed once; a git error (a malformed pathspec) stops the run here instead of skipping a check.
# shellcheck disable=SC2046
cpp=$(git ls-files -- $FORMAT_FILES $(excludes))
# shellcheck disable=SC2046
markdown=$(git ls-files -- $FORMAT_MARKDOWN $(excludes))

if [ -z "$cpp" ]; then
    echo "check-format: FORMAT_FILES matches no file" >&2
    exit 1
fi

if ! printf '%s\n' "$cpp" | xargs "$CLANG_FORMAT" --dry-run --Werror; then
    failed=1
fi

if ! printf '%s\n' "$cpp" | xargs awk -f "$here/check-format.awk"; then
    failed=1
fi

# A line whose first non-blank characters are `//` is skipped: commented-out code keeps its own indentation.
padded=$(
    printf '%s\n' "$cpp" "$markdown" | grep -v '^$' | xargs grep -nE '[^ ] {2,}//' /dev/null | grep -vE '^[^:]+:[0-9]+: *//' || true
)
if [ -n "$padded" ]; then
    printf '%s\n' "$padded" | sed 's/^\([^:]*:[0-9]*\):.*/\1: a trailing comment after more than one space/'
    failed=1
fi

if [ "$FORMAT_TABS" = true ]; then
    tabs=$(printf '%s\n' "$cpp" | xargs grep -n "$(printf '\t')" /dev/null || true)
    if [ -n "$tabs" ]; then
        printf '%s\n' "$tabs" | sed 's/^\([^:]*:[0-9]*\):.*/\1: a tab/'
        failed=1
    fi
fi

exit "$failed"
