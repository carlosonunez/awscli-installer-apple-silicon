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

_log() {
  local colors reset color_code
  colors=$(cat <<-EOF
black='\033[1;30m'
blue='\033[1;34m'
cyan='\033[1;36m'
green='\033[1;32m'
red='\033[1;31m'
white='\033[1;37m'
yellow='\033[1;33m'
EOF
)
  reset='\033[m'
  color_code="$(grep -E "^${1,,}" <<< "$colors" | cut -f2 -d '=' | tr -d "'")"
  test -z "$color_code" && color_code=''
  echo -en "${color_code}[${2^^}]:${reset} ${*:3}"
}

log_info() {
  _log green info "$@"
}

log_warn() {
  _log yellow warn "$@"
}

log_error() {
  _log red error "$@"
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
      log_error "This script only supports v2 of the AWS CLI. (You requested '$val'.)"
      exit 1
    fi
    if ! _ensure_semver "$val"
    then
      log_error "Version '$val' is not valid (should be something like 2.x.x)"
      exit 1
    fi
    echo "$val"
    return 0
  done
}

# get_awscli_versions: Queries for AWS CLI 2.x versions from their official GitHub repo.
get_awscli_versions() {
  local body response status_code
  response=$(curl -sSw '%{http_code}' https://api.github.com/repos/aws/aws-cli/git/refs/tags)
  status_code=$(sed -n '$p' <<< "$response")
  body=$(sed '$d' <<< "$response")
  if test "$status_code" -ne 200
  then
    log_error "Failed to get AWS CLI versions; error code [$status_code]"
    log_error "$(tr -d '\n' <<< "$body")"
    exit 1
  fi
  grep '"refs/tags/2.' <<< "$body" |
    cut -f2 -d ':' |
    awk -F '/' '{print $NF}' |
    tr -dc '0-9.\n'
}

confirm_version_valid() {
  test "${1,,}" == latest && return 0
  grep -Eiq "^$1" <<< "$2"
}

if help_requested "$@"
then
  usage
  exit 0
fi

version=$(get_arg_value "(-v|--version)" "$@")
test -z "$version" && version=latest
versions=$(get_awscli_versions)
if ! confirm_version_valid "$version" "$versions"
then
  log_error "AWS CLI version [$version] not found; go here to see available versions: \
https://github.com/aws/aws-cli/tags"
  exit 1
fi
