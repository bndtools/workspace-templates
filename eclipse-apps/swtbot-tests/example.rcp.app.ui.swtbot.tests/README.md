# SWTBot UI Tests

This project contains SWTBot tests for the Eclipse 4 application in
`example.rcp.app.ui`.

## Requirements

- Java 21 or newer.
- Add both the `Eclipse RCP SWTBot Tests` and `Eclipse RCP E4 Application`
  template fragments to a bnd workspace. The test fragment requires `app-ui`
  and the Eclipse Platform fragment.
- Supported launch targets: Linux GTK x86-64, Windows x86-64, and macOS Cocoa
  x86-64 or aarch64.

## Run in Eclipse

1. Build both `example.rcp.app.ui` and
   `example.rcp.app.ui.swtbot.tests`.
2. Open the `swtbot_*.bndrun` file matching your operating system and
   architecture. `swtbot_shared.bndrun` is an include file, not a standalone
   launch target.
3. Click **Resolve**, save the file, then select
   **Run As > Bnd OSGi Test Launcher (JUnit)**.
4. Check the JUnit view for the test result.

The test launch uses separate runtime storage and keeps the SWT event loop on
the main thread.

## Run from the bnd CLI

Install the [bnd CLI](https://bnd.bndtools.org/chapters/120-install.html), then
run these commands from the workspace root. Set `RUN_FILE` to the test launch
file for your host; example below uses Windows x86-64. Build path includes the
Eclipse feature through `app-ui`, so use a bnd CLI version that supports Eclipse
features on the build path.

```bash
cd example.rcp.app.ui
bnd build
cd ../example.rcp.app.ui.swtbot.tests
bnd build
RUN_FILE=swtbot_win32.win32.x86-64.bndrun
bnd resolve resolve -W "$RUN_FILE"
bnd runtests -r generated/test-reports "$RUN_FILE"
```
