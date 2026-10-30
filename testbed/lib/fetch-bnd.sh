#!/usr/bin/env bash
# Resolve and download a bnd CLI jar.
#   fetch-bnd.sh release|snapshot|rc|<version>|<path-to-jar> <cache-dir>
# Prints the jar path on stdout.
#   fetch-bnd.sh --list-rc
# Prints release candidate versions newer than the latest release (newest RC
# per base version, ascending), one per line.
set -euo pipefail
IFS=$'\n\t'

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$here/common.sh"

spec="${1:-release}"
cache="${2:-$here/../.cache}"

RELEASE_REPO="https://repo.maven.apache.org/maven2/biz/aQute/bnd/biz.aQute.bnd"
SNAPSHOT_REPO="https://bndtools.jfrog.io/bndtools/libs-snapshot/biz/aQute/bnd/biz.aQute.bnd"
RC_REPO="https://bndtools.jfrog.io/bndtools/libs-release/biz/aQute/bnd/biz.aQute.bnd"

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

latest_release() {
  local meta version
  meta="$(mktemp)"; fetch "$RELEASE_REPO/maven-metadata.xml" "$meta"
  version="$(xml_tag release <"$meta")"; rm -f "$meta"
  [[ -n "$version" ]] || die "no <release> in release metadata"
  printf '%s\n' "$version"
}

rc_versions() { # newest RC per base version newer than the latest release, ascending
  local release meta
  release="$(latest_release)"
  meta="$(mktemp)"; fetch "$RC_REPO/maven-metadata.xml" "$meta"
  RELEASE="$release" perl -0777 -ne '
    my @r = split /\./, $ENV{RELEASE};
    my %best;
    while (/<version>\s*(\d+)\.(\d+)\.(\d+)-RC(\d+)\s*<\/version>/g) {
      my ($maj, $min, $mic, $n) = ($1, $2, $3, $4);
      next unless ($maj <=> $r[0] || $min <=> $r[1] || $mic <=> $r[2]) > 0;
      my $base = "$maj.$min.$mic";
      $best{$base} = $n if !defined $best{$base} || $n > $best{$base};
    }
    for my $base (sort { my @x = split /\./, $a; my @y = split /\./, $b;
                         $x[0] <=> $y[0] || $x[1] <=> $y[1] || $x[2] <=> $y[2] } keys %best) {
      print "$base-RC$best{$base}\n";
    }' <"$meta"
  rm -f "$meta"
}

if [[ "$spec" == "--list-rc" ]]; then
  rc_versions
  exit 0
fi

mkdir -p "$cache"

if [[ -f "$spec" ]]; then
  printf '%s\n' "$(cd "$(dirname "$spec")" && pwd)/$(basename "$spec")"
  exit 0
fi

case "$spec" in
  release)
    version="$(latest_release)"
    url="$RELEASE_REPO/$version/biz.aQute.bnd-$version.jar"
    ;;
  rc)
    version="$(rc_versions | tail -n 1)"
    [[ -n "$version" ]] || die "no release candidate newer than the latest release"
    url="$RC_REPO/$version/biz.aQute.bnd-$version.jar"
    ;;
  *-RC[0-9]*)
    version="$spec"
    url="$RC_REPO/$version/biz.aQute.bnd-$version.jar"
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
