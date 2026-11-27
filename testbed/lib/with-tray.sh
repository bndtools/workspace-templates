#!/usr/bin/env bash
# Run a command with an X11 system tray on the current display.
set -euo pipefail

if [[ -z "${DISPLAY:-}" ]]; then
  echo "with-tray: DISPLAY is not set" >&2
  exit 1
fi
for command in python3 trayer; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "with-tray: missing $command" >&2
    exit 1
  fi
done
if (( $# == 0 )); then
  echo "with-tray: no command supplied" >&2
  exit 1
fi

# GTK must use the same X display as the tray, even in a Wayland session.
export GDK_BACKEND=x11

tray_owner() {
  python3 -c '
import ctypes
import ctypes.util
import sys

lib = ctypes.util.find_library("X11")
if not lib:
    sys.exit("with-tray: libX11 not found")
x = ctypes.CDLL(lib)
x.XOpenDisplay.argtypes = [ctypes.c_char_p]
x.XOpenDisplay.restype = ctypes.c_void_p
x.XDefaultScreen.argtypes = [ctypes.c_void_p]
x.XDefaultScreen.restype = ctypes.c_int
x.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
x.XInternAtom.restype = ctypes.c_ulong
x.XGetSelectionOwner.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x.XGetSelectionOwner.restype = ctypes.c_ulong
x.XCloseDisplay.argtypes = [ctypes.c_void_p]
display = x.XOpenDisplay(None)
if not display:
    sys.exit("with-tray: cannot open DISPLAY")
atom = x.XInternAtom(display, ("_NET_SYSTEM_TRAY_S%d" % x.XDefaultScreen(display)).encode(), 0)
owner = x.XGetSelectionOwner(display, atom)
x.XCloseDisplay(display)
print(owner)
'
}

owner="$(tray_owner)"
if [[ "$owner" != 0 ]]; then
  echo "with-tray: display already has a system tray owner" >&2
  exit 1
fi
trayer --edge top --align right --widthtype request --height 32 \
  --transparent false --SetDockType true --SetPartialStrut true &
tray_pid=$!
cleanup() {
  kill "$tray_pid" 2>/dev/null || true
  wait "$tray_pid" 2>/dev/null || true
}
trap cleanup EXIT

ready=0
for ((i = 0; i < 50; i++)); do
  kill -0 "$tray_pid" 2>/dev/null || break
  owner="$(tray_owner)"
  if [[ "$owner" != 0 ]]; then
    ready=1
    break
  fi
  sleep 0.1
done
if (( ! ready )); then
  echo "with-tray: trayer failed to acquire the X11 system tray selection" >&2
  exit 1
fi

status=0
"$@" || status=$?
owner="$(tray_owner)"
if ! kill -0 "$tray_pid" 2>/dev/null || [[ "$owner" == 0 ]]; then
  echo "with-tray: system tray host stopped during the command" >&2
  exit 1
fi
exit "$status"
