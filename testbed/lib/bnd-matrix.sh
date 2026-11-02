#!/usr/bin/env bash
set -euo pipefail
IFS=$' \n\t'

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
channels="${TESTBED_BND_CHANNELS:-snapshot}"
channels="${channels//,/ }"
read -r -a selected <<< "$channels"

versions=()
declare -A seen=()
for channel in "${selected[@]}"; do
  case "$channel" in
    release|snapshot) candidates=("$channel") ;;
    rc)
      rc_list="$(bash "$here/fetch-bnd.sh" --list-rc)"
      candidates=()
      while IFS= read -r version; do
        [[ -n "$version" ]] && candidates+=("$version")
      done <<< "$rc_list"
      ;;
    *) echo "Unsupported TESTBED_BND_CHANNELS entry: $channel" >&2; exit 2 ;;
  esac
  for version in "${candidates[@]}"; do
    if [[ -z "${seen[$version]:-}" ]]; then
      versions+=("$version")
      seen[$version]=1
    fi
  done
done

((${#versions[@]} > 0)) || { echo "TESTBED_BND_CHANNELS selected no bnd versions" >&2; exit 2; }
printf -v list '"%s",' "${versions[@]}"
printf '[%s]\n' "${list%,}"
