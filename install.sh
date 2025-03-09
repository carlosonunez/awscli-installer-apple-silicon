#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<-EOF
$(basename "$0") [-v|--version]
Installs the AWS CLI on Apple Silicon from source. No package managers required!

ARGUMENTS

  -v, --version         Installs a specific version of the AWS CLI.
EOF
}

help_requested() {
  grep -Eiq '^(-h|--help)$' <<< "$*"
}

get_arg_value() {
  key="${1,,}"
  shift
  while test "$#" -gt 0
  do
    grep -Eiq "^${key}$" <<< "${1,,}" || { shift; shift; continue; }
    echo "$2"
    return 0
  done
}

if help_requested "$@"
then
  usage
  exit 0
fi

version=$(get_arg_value "(-v|--version)" "$@")
echo "Version: $version"
