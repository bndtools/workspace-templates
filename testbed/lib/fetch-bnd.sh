#!/usr/bin/env bash
# Resolve and download a bnd CLI jar.
#   fetch-bnd.sh release|snapshot|<version>|<path-to-jar> <cache-dir>
# Prints the jar path on stdout.
set -euo pipefail
IFS=$'\n\t'

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$here/common.sh"

spec="${1:-release}"
cache="${2:-$here/../.cache}"

RELEASE_REPO="https://repo.maven.apache.org/maven2/biz/aQute/bnd/biz.aQute.bnd"
SNAPSHOT_REPO="https://bndtools.jfrog.io/bndtools/libs-snapshot/biz/aQute/bnd/biz.aQute.bnd"

fetch() { # url out
  local url="$1" out="$2" tmp
  tmp="$(mktemp "$out.XXXXXX")"
  # shellcheck disable=SC2086
  curl -sSfL ${TESTBED_CURL_OPTS:-} --retry 3 -o "$tmp" "$url" || { rm -f "$tmp"; die "download failed: $url"; }
  mv -f "$tmp" "$out"
}

xml_tag() { # tag  (reads stdin, prints first match)
  perl -0777 -ne "print \$1 if /<$1>\\s*([^<\\s]+)\\s*<\\/$1>/" </dev/stdin
}

mkdir -p "$cache"

if [[ -f "$spec" ]]; then
  printf '%s\n' "$(cd "$(dirname "$spec")" && pwd)/$(basename "$spec")"
  exit 0
fi

case "$spec" in
  release)
    meta="$(mktemp)"; fetch "$RELEASE_REPO/maven-metadata.xml" "$meta"
    version="$(xml_tag release <"$meta")"; rm -f "$meta"
    [[ -n "$version" ]] || die "no <release> in release metadata"
    url="$RELEASE_REPO/$version/biz.aQute.bnd-$version.jar"
    ;;
  snapshot)
    meta="$(mktemp)"; fetch "$SNAPSHOT_REPO/maven-metadata.xml" "$meta"
    version="$(xml_tag latest <"$meta")"; rm -f "$meta"
    [[ "$version" == *-SNAPSHOT ]] || die "latest snapshot version not a SNAPSHOT: '$version'"
    meta="$(mktemp)"; fetch "$SNAPSHOT_REPO/$version/maven-metadata.xml" "$meta"
    ts="$(xml_tag timestamp <"$meta")"; bn="$(xml_tag buildNumber <"$meta")"; rm -f "$meta"
    [[ -n "$ts" && -n "$bn" ]] || die "no snapshot timestamp/buildNumber for $version"
    unique="${version%-SNAPSHOT}-$ts-$bn"
    url="$SNAPSHOT_REPO/$version/biz.aQute.bnd-$unique.jar"
    version="$unique"
    ;;
  *-SNAPSHOT)
    version="$spec"
    url="$SNAPSHOT_REPO/$version/biz.aQute.bnd-$version.jar"
    ;;
  *)
    version="$spec"
    url="$RELEASE_REPO/$version/biz.aQute.bnd-$version.jar"
    ;;
esac

jar="$cache/biz.aQute.bnd-$version.jar"
if [[ ! -s "$jar" ]]; then
  err "downloading bnd $version"
  fetch "$url" "$jar"
fi
printf '%s\n' "$jar"
