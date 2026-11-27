# SWT Tray Application

This example adapts Gaia's SWT tray application into a minimal Equinox
application. It requires Java 21 and the Eclipse Platform fragment.

Build the workspace, resolve the `tray_*.bndrun` matching your platform, and
launch it with **Run As > Bnd OSGi Run Launcher**. The shared bndrun is an
include file, not a launch target. Linux GTK x86-64/aarch64, Windows x86-64,
and macOS Cocoa x86-64/aarch64 launch files are provided.

Select the tray icon for the main menu, or open its context menu. The example
offers Hello World, About, Preferences, and Exit actions. Preferences is a
placeholder. A double-click opens Hello World where the desktop delivers that
event; tray gestures and menu behavior vary by desktop. The application exits
with an error if SWT reports that the system tray is unavailable. On GTK it
also checks that a tray host embeds the icon, using an internal SWT GTK API
because SWT can otherwise report a tray when no host is running.

Only one instance per operating-system user may run at a time. A second launch
reports an error. The lock is released on exit, including abrupt termination.
The lock file in the user's home directory is intentionally retained.

The source is licensed under EPL-2.0; see this project's `LICENSE`.
