#!/usr/bin/env bash
# Fragment testbed: installs every bndtools workspace template fragment from the
# working tree into clean bnd workspaces with a real bnd CLI, loads repositories,
# builds projects, resolves bndruns, runs what matches the host platform and
# writes a markdown report.
set -euo pipefail
IFS=$'\n\t'
trap 'printf "testbed: internal error at %s:%s: %s\n" "${BASH_SOURCE[0]##*/}" "$LINENO" "$BASH_COMMAND" >&2' ERR

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
# shellcheck source=lib/common.sh
source "$here/lib/common.sh"

usage() {
  cat <<'EOF'
usage: testbed.sh [options]
  --bnd <release|snapshot|rc|version|jar>
                                        bnd CLI to use (default: release)
  --fragment <slug>                     test only this fragment (repeatable; see --list)
  --individual                          test every fragment in its own workspace
  --all-in-one                          test all non-archived fragments in one workspace
  --include-archived                    include archived fragments in --individual
  --skip-run                            do not launch bndruns
  --run-timeout <seconds>               launch timeout for long running apps (default 90)
  --keep-all                            keep workspaces of passing tests too
  --work-dir <dir>                      output directory (default testbed/work/<os>-<bnd>-<timestamp>)
  --list                                print fragment slugs and exit
  -h, --help
Without --fragment/--individual/--all-in-one both --individual and --all-in-one run.
Environment: JAVA_HOME (java/jar), TESTBED_CURL_OPTS (extra curl options).
EOF
}

BND_SPEC="release"; FRAGMENTS=(); INDIVIDUAL=0; ALL_IN_ONE=0; INCLUDE_ARCHIVED=0
SKIP_RUN=0; RUN_TIMEOUT=90; KEEP_ALL=0; WORK=""; LIST=0
while (( $# )); do
  case "$1" in
    --bnd) BND_SPEC="$2"; shift 2 ;;
    --fragment) FRAGMENTS+=("$2"); shift 2 ;;
    --individual) INDIVIDUAL=1; shift ;;
    --all-in-one) ALL_IN_ONE=1; shift ;;
    --include-archived) INCLUDE_ARCHIVED=1; shift ;;
    --skip-run) SKIP_RUN=1; shift ;;
    --run-timeout) RUN_TIMEOUT="$2"; shift 2 ;;
    --keep-all) KEEP_ALL=1; shift ;;
    --work-dir) WORK="$2"; shift 2 ;;
    --list) LIST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" 2 ;;
  esac
done
if (( ${#FRAGMENTS[@]} == 0 && INDIVIDUAL == 0 && ALL_IN_ONE == 0 )); then INDIVIDUAL=1; ALL_IN_ONE=1; fi

# ---------------------------------------------------------------- preflight
(( BASH_VERSINFO[0] >= 4 )) || die "bash 4+ required (found $BASH_VERSION)" 2
for c in perl curl git diff; do require_cmd "$c"; done
JAVA_BIN="${JAVA_HOME:+$JAVA_HOME/bin/}"
JAVA="${JAVA_BIN}java"; JAR="${JAVA_BIN}jar"
command -v "$JAVA" >/dev/null 2>&1 || die "java not found (JAVA_HOME=${JAVA_HOME:-unset})" 2
command -v "$JAR" >/dev/null 2>&1 || die "jar not found (JAVA_HOME=${JAVA_HOME:-unset})" 2
JAVA_VERSION="$("$JAVA" -version 2>&1 | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
JAVA_MAJOR="${JAVA_VERSION%%.*}"
(( JAVA_MAJOR >= 17 )) || die "java 17+ required, found $JAVA_VERSION" 2
(( JAVA_MAJOR >= 21 )) || err "warning: java $JAVA_VERSION < 21, Eclipse application fragments will not build"

INDEX_TSV="$(perl "$here/lib/index.pl" tsv "$repo/index.bnd")"
if (( LIST )); then printf '%s\n' "$INDEX_TSV" | cut -f1,4 | sed 's/\t1$/ (archived)/; s/\t0$//'; exit 0; fi

slug_field() { printf '%s\n' "$INDEX_TSV" | awk -F'\t' -v s="$1" -v f="$2" '$1==s {print $f}'; }
all_slugs() { printf '%s\n' "$INDEX_TSV" | awk -F'\t' -v a="$1" '(a=="1" || $4=="0") {print $1}'; }
for f in "${FRAGMENTS[@]:-}"; do
  [[ -z "$f" ]] && continue
  [[ -n "$(slug_field "$f" 2)" ]] || die "unknown fragment slug: $f (see --list)" 2
done

BND_JAR="$("$here/lib/fetch-bnd.sh" "$BND_SPEC" "$here/.cache")"
bnd() { "$JAVA" -jar "$BND_JAR" "$@"; }
BND_VERSION="$(bnd version 2>/dev/null | tail -1 | tr -d '\r')"
[[ -n "$BND_VERSION" ]] || die "bnd version failed for $BND_JAR"

HOST="$(host_platform)"
STAMP="$(date +%Y%m%d-%H%M%S)"
[[ -n "$WORK" ]] || WORK="$here/work/${HOST%%.*}-${BND_SPEC//[^A-Za-z0-9.-]/_}-$STAMP"
mkdir -p "$WORK"; WORK="$(cd "$WORK" && pwd)"
[[ -z "$(ls -A "$WORK")" ]] || die "work dir not empty: $WORK"
ZIPS="$WORK/zips"; mkdir -p "$ZIPS"

GIT_SHA="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo unknown)"
git -C "$repo" diff --quiet HEAD -- . ':!testbed' 2>/dev/null || GIT_SHA="$GIT_SHA-dirty"
cat >"$WORK/meta.env" <<EOF
os=$(uname -s)
arch=$(uname -m)
host_platform=$HOST
java=$JAVA_VERSION
bnd_spec=$BND_SPEC
bnd_version=$BND_VERSION
bnd_jar=$(basename "$BND_JAR")
git_sha=$GIT_SHA
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
run_timeout=$RUN_TIMEOUT
skip_run=$SKIP_RUN
EOF
err "bnd $BND_VERSION, java $JAVA_VERSION, host $HOST, work $WORK"

# ---------------------------------------------------------------- zip fragments
zip_fragment() { # slug path
  local slug="$1" path="$2" parent name files=()
  parent="$(dirname "$path")"; name="$(basename "$path")"
  [[ "$parent" == "." ]] && parent=""
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    files+=("${f#"$parent"/}")
  done < <(git -C "$repo" ls-files -co --exclude-standard -- "$path")
  (( ${#files[@]} > 0 )) || die "no files for fragment $slug ($path)"
  ( cd "$repo/${parent:-.}" && "$JAR" --create --no-manifest --file "$ZIPS/$slug.zip" "${files[@]}" )
}
while IFS=$'\t' read -r slug path _; do zip_fragment "$slug" "$path"; done <<<"$INDEX_TSV"
perl "$here/lib/index.pl" local "$repo/index.bnd" "$(to_file_uri "$ZIPS")" >"$WORK/testbed-index.bnd"

# ---------------------------------------------------------------- test steps
TEST=""; TEST_DIR=""; WS=""; LOGS=""; STEP_NO=0; TEST_FAILED=0

record() { # step subject status exit log detail
  local detail; detail="$(printf '%s' "$6" | tr '\t\r\n' '   ')"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$TEST" "$1" "$2" "$3" "$4" "${5#"$WORK"/}" "$detail" >>"$TEST_DIR/status.tsv"
  [[ "$3" == FAIL ]] && TEST_FAILED=1
  err "  [$3] $1 $2${6:+ - $6}"
}
next_log() { STEP_NO=$((STEP_NO + 1)); LOG="$(printf '%s/%02d-%s.log' "$LOGS" "$STEP_NO" "$1")"; }
sanitize() { printf '%s' "$1" | tr '/ ' '__'; }

# run_step <step> <subject> <log> <dir> <cmd...>  -> PASS/FAIL from exit code
run_step() {
  local step="$1" subject="$2" log="$3" dir="$4"; shift 4
  local rc=0
  ( cd "$dir" && "$@" ) >"$log" 2>&1 || rc=$?
  if (( rc == 0 )); then record "$step" "$subject" PASS 0 "$log" ""
  else record "$step" "$subject" FAIL "$rc" "$log" "$(grep -m1 -E '^(! |\[ERROR\]|Error|Exception)' "$log" || tail -1 "$log")"
  fi
  return 0
}

begin_test() {
  TEST="$1"; TEST_DIR="$WORK/$TEST"; WS="$TEST_DIR/ws"; LOGS="$TEST_DIR/logs"; STEP_NO=0; TEST_FAILED=0
  mkdir -p "$TEST_DIR" "$LOGS"
  : >"$TEST_DIR/status.tsv"
  err "== $TEST"
}

step_workspace() {
  local log; next_log workspace; log="$LOG"
  run_step workspace - "$log" "$TEST_DIR" bnd add workspace ws
  [[ -f "$WS/cnf/build.bnd" ]] || { record workspace cnf/build.bnd FAIL 1 "$log" "cnf/build.bnd not created"; return; }
  { printf '\n# testbed: local fragment index\n'; cat "$WORK/testbed-index.bnd"; } >>"$WS/cnf/build.bnd"
}

step_fragments() { # slugs...
  local log names=() s subject; next_log fragment; log="$LOG"
  for s in "$@"; do names+=("testbed:$s"); done
  subject="$(IFS=,; printf '%s' "$*")"
  local rc=0
  ( cd "$WS" && printf 'yes\n' | bnd add fragment "${names[@]}" ) >"$log" 2>&1 || rc=$?
  if (( rc != 0 )); then record fragment "$subject" FAIL "$rc" "$log" "$(grep -m1 -E '^(! |Exception|Error)' "$log" || tail -1 "$log")"
  elif ! grep -qE 'Added [0-9]+ template fragment' "$log"; then record fragment "$subject" FAIL 1 "$log" "bnd did not report 'Added ... template fragment(s)'"
  elif grep -qiE 'conflict' "$log"; then record fragment "$subject" FAIL 1 "$log" "$(grep -m1 -iE 'conflict' "$log")"
  else record fragment "$subject" PASS 0 "$log" "$(grep -oE 'Added [0-9]+ template fragment\(s\)' "$log" | head -1)"
  fi
}

step_repos() {
  local log; next_log repos; log="$LOG"
  run_step repos repos "$log" "$WS" bnd repo repos
  next_log repo-list; log="$LOG"
  run_step repos list "$log" "$WS" bnd repo list
}

projects() { # dirs with bnd.bnd directly under ws, excluding cnf
  find "$WS" -mindepth 2 -maxdepth 2 -name bnd.bnd -not -path "*/cnf/*" -exec dirname {} \; | sort
}

step_build() {
  local p name log rc w
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    name="$(basename "$p")"; next_log "build-$name"; log="$LOG"; rc=0
    ( cd "$p" && bnd build ) >"$log" 2>&1 || rc=$?
    if (( rc != 0 )); then
      record build "$name" FAIL "$rc" "$log" "$(grep -m1 -E '^000: ' "$log" | cut -c1-200 || tail -1 "$log")"
    elif grep -qE '^Warnings$' "$log"; then
      w="$(sed -n '/^Warnings$/,$p' "$log" | grep -m1 -E '^[0-9]{3}: ' | cut -c1-200)"
      record build "$name" WARN 0 "$log" "bnd warnings: $w"
    else
      record build "$name" PASS 0 "$log" ""
    fi
  done < <(projects)
}

# Include-only bndruns: referenced by another bndrun in the same directory.
is_include_file() { # file
  local f="$1" d b o; d="$(dirname "$f")"; b="$(basename "$f")"
  for o in "$d"/*.bndrun; do
    [[ "$o" == "$f" ]] && continue
    grep -qF -- "$b" "$o" 2>/dev/null && return 0
  done
  return 1
}

# Text of a bndrun plus every bndrun it references (transitively).
effective_text() { # file
  local -a queue=("$1"); local -A seen=(); local f d ref
  while (( ${#queue[@]} )); do
    f="${queue[0]}"; queue=("${queue[@]:1}")
    [[ -n "${seen[$f]:-}" || ! -f "$f" ]] && continue
    seen[$f]=1; d="$(dirname "$f")"
    cat "$f"; printf '\n'
    while IFS= read -r ref; do
      ref="${ref//\$\{workspace\}/$WS}"; ref="${ref//\$\{.\}/$d}"
      [[ "$ref" == /* || "$ref" == [A-Za-z]:* ]] || ref="$d/$ref"
      queue+=("$ref")
    done < <(grep -oE '[A-Za-z0-9_${}./-]+\.bndrun' "$f" | grep -v "^$(basename "$f")\$" || true)
  done
}

bndruns() { # runnable bndruns under ws projects
  local f
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    is_include_file "$f" || printf '%s\n' "$f"
  done < <(find "$WS" -mindepth 2 -maxdepth 2 -name '*.bndrun' -not -path "*/cnf/*" | sort)
}

step_resolve() {
  local f rel log before rc
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    rel="${f#"$WS"/}"; next_log "resolve-$(sanitize "$rel")"; log="$LOG"
    before="$(mktemp)"; cp "$f" "$before"
    rc=0
    ( cd "$(dirname "$f")" && bnd resolve resolve -W "$(basename "$f")" ) >"$log" 2>&1 || rc=$?
    if (( rc != 0 )) || grep -qE 'Unable to resolve|Resolution failed|^! ' "$log"; then
      record resolve "$rel" FAIL "${rc:-1}" "$log" "$(grep -m1 -E 'Unable to resolve|Resolution failed|^! |missing requirement' "$log" || tail -1 "$log")"
    elif grep -q '^-runbundles' "$before" && [[ -n "$(runbundles_diff "$before" "$f")" ]]; then
      runbundles_diff "$before" "$f" >"${log%.log}.runbundles.diff"
      { printf '\n--- -runbundles drift (< committed, > resolved) ---\n'; cat "${log%.log}.runbundles.diff"; } >>"$log"
      record resolve "$rel" WARN 0 "$log" "committed -runbundles differ from fresh resolution: $(tr '\n' ' ' <"${log%.log}.runbundles.diff" | cut -c1-200)"
    else
      record resolve "$rel" PASS 0 "$log" ""
    fi
    rm -f "$before"
  done < <(bndruns)
}

step_run() {
  local f rel log text platform port probe=() rc dir wrapper=() junit counts
  if is_linux && [[ -z "${DISPLAY:-}" ]] && command -v xvfb-run >/dev/null 2>&1; then wrapper=(xvfb-run -a); fi
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    rel="${f#"$WS"/}"; dir="$(dirname "$f")"; platform=""
    next_log "run-$(sanitize "$rel")"; log="$LOG"
    if [[ "$(basename "$f")" =~ _((linux\.gtk|win32\.win32|macosx\.cocoa)\.(x86-64|aarch64))\.bndrun$ ]]; then
      platform="${BASH_REMATCH[1]}"
      [[ "$platform" == "$HOST" ]] || { record run "$rel" SKIP 0 - "platform $platform != $HOST"; continue; }
    fi
    text="$(effective_text "$f")"
    if grep -q -- '-XstartOnFirstThread' <<<"$text" && ! is_macos; then
      record run "$rel" SKIP 0 - "-XstartOnFirstThread needs macOS"; continue
    fi
    if awk -F'\t' -v r="$rel" '$2=="resolve" && $3==r && $4=="FAIL" {found=1} END {exit !found}' "$TEST_DIR/status.tsv"; then
      record run "$rel" SKIP 0 - "resolve failed"; continue
    fi
    if grep -qE '^(-tester|Test-Cases)' <<<"$text"; then
      rc=0; junit="$LOGS/junit-$(sanitize "$rel")"
      ( cd "$WS" && ${wrapper[@]+"${wrapper[@]}"} "$JAVA" -jar "$BND_JAR" runtests -r "$junit" "$rel" ) >"$log" 2>&1 || rc=$?
      # keep the JUnit XML next to the logs (the workspace may be removed)
      find "$dir/generated/test-reports" -name 'TEST-*.xml' -exec cp {} "$junit"/ \; 2>/dev/null || true
      counts="$(perl -e 'my ($t,$f,$e)=(0,0,0); for my $x (glob("$ARGV[0]/TEST-*.xml")) { open my $h, "<", $x or next; local $/; my $s=<$h>; while ($s =~ /<testsuite\b([^>]*)>/g) { my $a=$1; $t+=$1 if $a=~/\btests="(\d+)"/; $f+=$1 if $a=~/\bfailures="(\d+)"/; $e+=$1 if $a=~/\berrors="(\d+)"/ } } printf "%d tests, %d failures, %d errors", $t, $f, $e' "$junit")"
      if (( rc != 0 )); then record run "$rel" FAIL "$rc" "$log" "runtests exit $rc ($counts): $(grep -m1 -E 'FAIL|^! |Exception' "$log" || tail -1 "$log")"
      elif [[ "$counts" == "0 tests"* ]]; then record run "$rel" FAIL 1 "$log" "runtests reported no test results ($counts)"
      elif [[ "$counts" != *" 0 failures, 0 errors" ]]; then record run "$rel" FAIL 1 "$log" "runtests: $counts"
      else record run "$rel" PASS 0 "$log" "runtests: $counts"
      fi
      continue
    fi
    probe=()
    port="$(grep -oE 'org\.osgi\.service\.http\.port=[0-9]+' <<<"$text" | head -1 | cut -d= -f2 || true)"
    [[ -n "$port" ]] && probe=(--probe curl -s -o /dev/null "http://127.0.0.1:$port/" --)
    rc=0
    run_with_timeout "$RUN_TIMEOUT" "$log" "$dir" ${probe[@]+"${probe[@]}"} ${wrapper[@]+"${wrapper[@]}"} "$JAVA" -jar "$BND_JAR" run "$(basename "$f")" || rc=$?
    if (( rc == 124 )); then
      if log_has_errors "$log"; then record run "$rel" FAIL 124 "$log" "errors in launch log: $(grep -m1 -E "$ERROR_MARKER_RE" "$log")"
      elif [[ -n "$port" && "$RUN_PROBE_OK" != 1 ]]; then record run "$rel" FAIL 124 "$log" "no HTTP answer on port $port within ${RUN_TIMEOUT}s"
      else record run "$rel" PASS 124 "$log" "still running after ${RUN_TIMEOUT}s${port:+, HTTP :$port answered}"
      fi
    elif (( rc == 0 )); then
      if log_has_errors "$log"; then record run "$rel" WARN 0 "$log" "exit 0 but errors in log: $(grep -m1 -E "$ERROR_MARKER_RE" "$log")"
      else record run "$rel" PASS 0 "$log" "exited by itself"
      fi
    else
      record run "$rel" FAIL "$rc" "$log" "$(grep -m1 -E "$ERROR_MARKER_RE" "$log" || tail -1 "$log")"
    fi
  done < <(bndruns)
}

end_test() {
  if (( TEST_FAILED == 0 && KEEP_ALL == 0 )); then rm -rf "$WS"; printf 'workspace removed (all steps passed)\n' >"$TEST_DIR/CLEANED"; fi
}

run_test() { # name slugs...
  local name="$1"; shift
  begin_test "$name"
  step_workspace
  if (( TEST_FAILED == 0 )); then step_fragments "$@"; fi
  if (( TEST_FAILED == 0 )); then
    step_repos
    step_build
    step_resolve
    (( SKIP_RUN )) || step_run
  fi
  end_test
}

# ---------------------------------------------------------------- main
if (( ${#FRAGMENTS[@]} > 0 )); then
  for s in "${FRAGMENTS[@]}"; do run_test "$s" "$s"; done
fi
if (( INDIVIDUAL )); then
  while IFS= read -r s; do [[ -n "$s" ]] && run_test "$s" "$s"; done < <(all_slugs "$INCLUDE_ARCHIVED")
fi
if (( ALL_IN_ONE )); then
  mapfile -t all < <(all_slugs 0)
  run_test all-in-one "${all[@]}"
fi

printf 'finished=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$WORK/meta.env"
perl "$here/lib/report.pl" "$WORK" "$repo"
err "report: $WORK/REPORT.md"
if cat "$WORK"/*/status.tsv 2>/dev/null | awk -F'\t' '$4=="FAIL" {f=1} END {exit !f}'; then exit 1; fi
