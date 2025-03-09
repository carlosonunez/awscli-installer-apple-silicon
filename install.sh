#!/usr/bin/env bash
set -euo pipefail
FORCE="${FORCE:-}"
usage() {
  cat <<-EOF
$(basename "$0") [-v|--version]
Installs the AWS CLI on Apple Silicon from source. No package managers required!

ARGUMENTS

    -v, --version         Installs a specific version of the AWS CLI (see NOTES)

ENVIRONMENT VARIABLES

    FORCE                 Installs the AWS CLI even if an installlation was already found (see NOTES).

NOTES

  - Multiple versions of the AWS CLI are not supported by this script. Some things might not work
    if you override an existing version of the AWS CLI with an older version using the 'FORCE'
    environment variable.
  - Earlier versions of AWS CLI v2 might fail to install with this script. Create a new GitHub Issue
    is this is affecting you, and I'll do my best to help.
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
  echo -en "${color_code}[${2^^}]:${reset} ${*:3}\n"
}

_install_dir() {
  echo "$HOME/.local/aws-$1"
}

_enter_install_dir() {
  pushd &>/dev/null "$(_install_dir "$1")"
}

_leave_install_dir() {
  test "$PWD" == "$(_install_dir "$1")" && popd &>/dev/null
  true
}

_aws_cli_install_directory() {
  pip show awscli |
    grep -E '^Location' |
    cut -f2 -d ':' |
    sed -E 's;lib.*;bin; ; s/^[ \t]+//'
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
  test -z "$version" && return 0
  grep -Eiq "^$1" <<< "$2"
}

make_install_dir() {
  test -d "$(_install_dir "$1")" || mkdir -p "$(_install_dir "$1")"
}

download_release_at_version() {
  test -f "$(_install_dir "$1")/awscli.tar.gz" && return 0
  curl -sSLo "$(_install_dir "$1")/awscli.tar.gz" "https://github.com/aws/aws-cli/archive/refs/tags/$1.tar.gz"
}

extract_release() {
  _enter_install_dir "$1"
  # shellcheck disable=SC2154
  trap 'rc=$?; _leave_install_dir $1; return $rc' INT HUP
  tar -xzf "awscli.tar.gz"
  _leave_install_dir "$1"
}

install_awscli() {
  _enter_install_dir "$1"
  # shellcheck disable=SC2154
  trap 'rc=$?; _leave_install_dir $1; return $rc' INT HUP
  cd "aws-cli-$1"
  pip3 install -r requirements.txt
  pip3 install -e .
  _leave_install_dir "$1"
}

ensure_python3_installed() {
  which python3 &>/dev/null
}

installed_awscli_matches_system_awscli() {
  test "$(which aws)" == "$(_aws_cli_install_directory)/aws"
}

asdf_installed() {
  &>/dev/null which asdf
}

awscli_bin_dir_not_in_path() {
  grep -q "$(_aws_cli_install_directory)" <<< "$PATH"
}

uninstall_pip_installed_awscli() {
  test -z "$(_aws_cli_install_directory)" && return 0

  pip uninstall --yes awscli
}

find_existing_awscli_installation() {
  if test -n "$(_aws_cli_install_directory)"
  then
    want="$(_aws_cli_install_directory)/aws"
    test -f "$want" || return 1
    echo "$want"
    return 0
  fi
  2>/dev/null which aws && return 0
}

if help_requested "$@"
then
  usage
  exit 0
fi

# This is unlikely, as macOS ships with some version of Python3 installed.
if ! ensure_python3_installed
then
  log_error "You'll need to install Python before running this."
  exit 1
fi

version=$(get_arg_value "(-v|--version)" "$@")

log_info "Fetching AWS CLI versions (this might take a few seconds)"
versions=$(get_awscli_versions)
if ! confirm_version_valid "$version" "$versions"
then
  log_error "AWS CLI version [$version] not found; go here to see available versions: \
https://github.com/aws/aws-cli/tags"
  exit 1
fi

awscli_found=$(find_existing_awscli_installation)
if test -n "$awscli_found"
then
  if test -z "$FORCE"
  then
    log_error "AWS CLI is already installed at $awscli_found (re-run with FORCE=1 to install anyway)"
    exit 1
  fi
  log_warn "AWS CLI installed at $awscli_found; proceeding with installation anyway, as requested"
  uninstall_pip_installed_awscli
fi

test -z "$version" && version=$(tail -1 <<< "$versions")
log_info "Downloading AWS CLI v$version"
make_install_dir "$version"
download_release_at_version "$version"
trap 'rc=$?; clean; exit $rc' INT HUP EXIT
extract_release "$version"

log_info "Installing AWS CLI (this might take a few minutes)"
install_awscli "$version"

if installed_awscli_matches_system_awscli
then
  log_info "AWS CLI installed! Run 'aws' to get started."
  exit 0
elif asdf_installed
then
  log_info "AWS CLI installed; run 'asdf reshim python' to apply changes, then run 'aws' to get started."
  exit 0
elif awscli_bin_dir_not_in_path
then
  message="$(cat <<-EOF
AWS CLI installed successfully!

Run the command below to ensure that your terminal can find the correct version of 'aws'
on startup.

echo 'export PATH="$(_aws_cli_install_directory);\$PATH"' >> \$HOME/.bash_profile

Afterwards, restart your terminal and run 'aws' to get started.
EOF
)"
  echo "$message" |
  while read -r line
  do log_info "$line"
  done
else
  message="$(cat <<-EOF
AWS CLI installed successfully!

Run the command below to ensure that your terminal can find the correct version of 'aws'
on startup.

echo 'alias aws=$(_aws_cli_install_directory)/aws' >> \$HOME/.bash_profile

Afterwards, restart your terminal and run 'aws' to get started.
EOF
)"
  echo "$message" |
  while read -r line
  do log_info "$line"
  done
fi
