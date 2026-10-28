# SWT/JFace Application

This example launches a small SWT/JFace application with a progress dialog.

## Requirements

- Java 21 or newer.
- Add the `Eclipse RCP SWT` template fragment to a bnd workspace. It requires
  the Eclipse Platform fragment, which supplies the shared repository
  configuration.
- Supported launch targets: Linux GTK x86-64, Windows x86-64, and macOS Cocoa
  x86-64 or aarch64.

## Run in Eclipse

1. Build the workspace and wait for the project to compile.
2. Open the `ui_*.bndrun` file matching your operating system and architecture.
   The `ui_shared.bndrun` file is included by the launch configurations and is
   not a standalone launch target.
3. Click **Resolve**, save the file, then select
   **Run As > Bnd OSGi Run Launcher**.

## Run from the bnd CLI

Install the [bnd CLI](https://bnd.bndtools.org/chapters/120-install.html), then
run these commands from the workspace root. Set `RUN_FILE` to the launch file
for your host; example below uses Windows x86-64.

```bash
cd example.rcp.ui
bnd build
RUN_FILE=ui_win32.win32.x86-64.bndrun
bnd resolve resolve -W "$RUN_FILE"
bnd run "$RUN_FILE"
```
