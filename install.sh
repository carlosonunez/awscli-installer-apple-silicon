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
  _ensure_semver() {
    grep -Eiq '^2\.[0-9]{1,}\.[0-9]{1,}$' <<< "$1"
  }
  _requested_version_greater_than_v2() {
    grep -Eiq '^2' <<< "$1"
  }
  key="${1,,}"
  shift
  while test "$#" -gt 0
  do
    grep -Eiq "^${key}$" <<< "${1,,}" || { shift; shift; continue; }
    val="${2%.}"
    if ! _requested_version_greater_than_v2 "$val"
    then
      >&2 echo "ERROR: This script only supports v2 of the AWS CLI. (You requested '$val'.)"
      exit 1
    fi
    if ! _ensure_semver "$val"
    then
      >&2 echo "ERROR: Version '$val' is not valid (should be something like 2.x.x)"
      exit 1
    fi
    echo "$val"
    return 0
  done
}

if help_requested "$@"
then
  usage
  exit 0
fi

version=$(get_arg_value "(-v|--version)" "$@")
