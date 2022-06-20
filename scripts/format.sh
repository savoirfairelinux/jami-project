#!/usr/bin/env bash

set -e

command_exists ()
{
    type "$1" &> /dev/null ;
}

CFVERSION="9"
CLANGFORMAT=""
if command_exists clang-format-${CFVERSION}; then
    CLANGFORMAT=clang-format-${CFVERSION}
else
    if command_exists clang-format; then
        CLANGFORMAT=clang-format
    fi
fi

if ! command -v $CLANGFORMAT &> /dev/null; then
    echo "Required version of clang-format not found"
    exit 1
fi

format_file()
{
    if [ -f "${1}" ]; then
        $CLANGFORMAT -i -style=file "${1}" || true
    fi
}

format_files()
{
    for file in $1; do
        echo -ne "Formatting: ${file}\\033[0K\\r"
        format_file "${file}"
    done
}

exit_if_no_files()
{
    echo No files to format
    exit 0
}

install_hook()
{
    hooks_path=$1
    if [ ! -d "$hooks_path" ]; then
        echo "$hooks_path" path does not exist
        exit 1
    fi
    echo Installing pre-commit hook in "$hooks_path"
    echo "$(realpath $0)" > "$hooks_path"/pre-commit
    chmod +x "$hooks_path"/pre-commit
}

display_help()
{
    echo "Usage: $0 [OPTION...] -- Clang format source files with a .clang-format file" >&2
    echo
    echo "   --all             format all files instead of only committed ones"
    echo "   --install <path>  install a pre-commit hook to run this script"
    echo
}

if [ "$1" == "--help" ]; then
    display_help
    exit 0
fi

case "${1}" in
  --all )
    files=$(find src -regex '.*\.\(cpp\|hpp\|cc\|cxx\|h\)$') || true
    echo Formatting all source files...
    format_files "$files"
    ;;
  --install )
    install_hook "${2}"
    ;;
  * )
    files=$(git diff-index --cached --name-only HEAD | grep -iE '\.(cpp|cxx|cc|h|hpp)$') || exit_if_no_files
    echo Formatting committed source files...
    format_files "$files"
    ;;
esac
