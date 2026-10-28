#!/usr/bin/env bash
# Shared helpers for the fragment testbed. Source only.

err() { printf '%s: %s\n' "testbed" "$*" >&2; }
die() { err "$*"; exit "${2:-1}"; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command missing: $1" 2; }

is_windows() { [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* || "${OS:-}" == Windows_NT ]]; }
is_macos() { [[ "${OSTYPE:-}" == darwin* ]]; }
is_linux() { [[ "${OSTYPE:-}" == linux* ]]; }

# Platform token as used in *_<os>.<ws>.<arch>.bndrun file names.
host_platform() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) arch="x86-64" ;;
    arm64|aarch64) arch="aarch64" ;;
  esac
  if is_windows; then printf 'win32.win32.%s\n' "$arch"
  elif is_macos; then printf 'macosx.cocoa.%s\n' "$arch"
  else printf 'linux.gtk.%s\n' "$arch"
  fi
}

# Absolute native path (Windows: C:/x/y) for a path.
native_path() {
  local p="$1"
  if is_windows && command -v cygpath >/dev/null 2>&1; then cygpath -m "$p"; else printf '%s\n' "$p"; fi
}

# file: URI for an absolute path.
to_file_uri() {
  local p
  p="$(native_path "$1")"
  if [[ "$p" == /* ]]; then printf 'file://%s\n' "$p"; else printf 'file:///%s\n' "$p"; fi
}

now_s() { date +%s; }

# Kill a process and its children.
kill_tree() {
  local pid="$1"
  if is_windows; then
    local winpid
    winpid="$(cat "/proc/$pid/winpid" 2>/dev/null || true)"
    [[ -n "$winpid" ]] && taskkill //T //F //PID "$winpid" >/dev/null 2>&1 || true
  else
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
    sleep 2
    pkill -KILL -P "$pid" 2>/dev/null || true
    kill -KILL "$pid" 2>/dev/null || true
  fi
}

# run_with_timeout <seconds> <log> <dir> [--probe <cmd...> --] <cmd...>
# Runs cmd in dir with stdout/stderr to log. Exit: cmd's code, 124 on timeout.
# If a probe command is given it is polled every second; RUN_PROBE_OK=1 when it succeeded once.
run_with_timeout() {
  local secs="$1" log="$2" dir="$3"; shift 3
  local probe=()
  if [[ "${1:-}" == "--probe" ]]; then
    shift
    while [[ "$1" != "--" ]]; do probe+=("$1"); shift; done
    shift
  fi
  RUN_PROBE_OK=0
  # open but silent stdin: gogo shell stops the framework on EOF
  ( cd "$dir" && exec "$@" ) >"$log" 2>&1 < <(sleep "$((secs + 10))") &
  local pid=$!
  local start elapsed=0
  start="$(now_s)"
  while kill -0 "$pid" 2>/dev/null; do
    if (( ${#probe[@]} > 0 )) && (( RUN_PROBE_OK == 0 )); then
      if "${probe[@]}" >/dev/null 2>&1; then RUN_PROBE_OK=1; fi
    fi
    elapsed=$(( $(now_s) - start ))
    if (( elapsed >= secs )); then
      kill_tree "$pid"
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
  done
  wait "$pid"
}

# Sorted -runbundles entries of a bndrun (commas inside quotes are not separators).
runbundles_entries() {
  perl -0777 -ne '
    if (/^-runbundles:\s*(.*?)(?=^\S|\z)/ms) {
      my $v = $1; $v =~ s/\\\r?\n//g; $v =~ s/[\s\r]//g;
      print "$_\n" for sort grep { length } split /,(?=(?:[^\x27]*\x27[^\x27]*\x27)*[^\x27]*$)/, $v;
    }' "$1"
}

# Prints -runbundles entries that differ between two bndrun snapshots ("<" before, ">" after).
runbundles_diff() {
  diff <(runbundles_entries "$1") <(runbundles_entries "$2") | grep -E '^[<>]' || true
}

# Error markers in a bnd launch log.
ERROR_MARKER_RE='Exception in thread|BundleException|^! |Could not resolve|Unresolved requirement|\[ERROR\]|Failed to start|java\.lang\.[A-Za-z]*Error'
log_has_errors() { grep -Eq "$ERROR_MARKER_RE" "$1"; }
