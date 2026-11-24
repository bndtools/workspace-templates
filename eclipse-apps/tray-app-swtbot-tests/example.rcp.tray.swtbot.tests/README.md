# Tray SWTBot tests

This optional fragment requires `tray-app` and the Eclipse Platform fragment.
It requires the shared `eclipse-apps/swtbot-repo` fragment for the SWTBot 4.3.0
repository configuration and index. SWTBot is an Eclipse project; see
https://www.eclipse.org/swtbot/ and its EPL-2.0 license.

The test waits for the application's SWT tray item, checks its tooltip, and
starts a second Java process against the actual application class to verify
that the per-user lock rejects a concurrent instance. The second process
invokes the class directly, not through a second Equinox launcher.
After Exit, the test verifies the lock is free, restarts the class in another
process, kills it, and verifies that the OS releases the lock after a crash.

On Linux, the native driver uses X11 input and AT-SPI accessibility, not
synthetic SWT events. It checks the complete left and right menus, including
the separator; opens Hello World from both menus, About and Preferences;
checks each dialog's title, message and OK button; and selects Exit. It
requires exactly one SWT icon embedded in a `trayer` panel. Dialogs are native
GTK message boxes, not SWT shells discoverable by SWTBot.

## Linux prerequisites

- Java 21+, a working X11 display with `GDK_BACKEND=x11`, and a `trayer`
  process on that same display.
- `xdotool`, `xwininfo`, Python 3, `python3-pyatspi`, AT-SPI, and a D-Bus
  session accessible to both the app and test. On Ubuntu these are provided
  by `xdotool`, `x11-utils`, `python3-pyatspi`, `at-spi2-core` and `dbus-x11`.
- A fresh tray: another SWT icon or another trayer panel causes an explicit
  failure. A headless X server without a tray host is insufficient.

Build both projects, then resolve the `swtbot_*.bndrun` matching the host.
The test must run inside the application framework with the Eclipse
application on the main thread and the bnd tester on a separate thread. A
plain `bnd runtests` invocation may not supply this launch harness. When using
Xvfb, start the harness and tray within the same `dbus-run-session` and X
display. The repository testbed supplies its own harness and tray wrapper.

## Windows prerequisites

- Java 21+, Windows PowerShell 5.1 and .NET Framework UI Automation assemblies
  (`UIAutomationClient`, `UIAutomationTypes`, `WindowsBase`).
- An unlocked interactive desktop with Explorer's notification area running.
  Session 0, services and secure/locked desktops are unsupported. The app,
  Explorer and test must use compatible integrity levels; do not elevate only
  one process. Do not interact with the mouse during the test.
- The tray icon must be accessible through UI Automation as `Tray App`.
  The driver opens hidden icons using Explorer's `SystemTray.OverflowButton`
  or `NotificationChevron` automation ID (with English `Show hidden icons`
  as a fallback). An unsupported Explorer layout fails explicitly.

The PowerShell driver locates the actual Explorer icon, injects mouse input
with `SendInput`, inspects the application's Win32 popup menus, and checks
native message-box title, text and OK button before clicking. It verifies
both menus including the separator, all four menu/dialog paths, Windows
double-click Hello World, and Exit.
It uses the application PID supplied by the SWTBot test, not a window with
an arbitrary matching title. Failure output includes application/tray window
handles, classes and titles. The extracted script is kept under
`generated/native/windows_tray.ps1` for reproduction; set
`NATIVE_TRAY_APP_PID` to the running application's PID before invoking it.

## Current limitations

macOS native automation is not implemented; its test **fails**, rather than
skipping. Linux double-click is not asserted. Lock release after a crash or a normal
exit is checked through the application lock file. The test shuts down its
application through Exit and must not share it with other test cases.

Linux's complete Equinox/SWTBot lifecycle test has been exercised against a
real Xvfb/trayer setup. Windows validation reached the real Hello World menu
and message box, but subsequent runs lost desktop cursor access
(`GetCursorPos` returned Win32 error 5). Full Windows lifecycle and
double-click coverage remain unverified; this prerequisite fails explicitly.
