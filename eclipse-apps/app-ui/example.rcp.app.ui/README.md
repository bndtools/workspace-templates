# Eclipse 4 Application

This example is an Eclipse 4 product with an application model, handlers, and
CSS styling.

## Requirements

- Java 21 or newer.
- Add the `Eclipse RCP E4 Application` template fragment to a bnd workspace. It
  requires the Eclipse Platform fragment, which supplies the shared repository
  configuration.
- Supported launch targets: Linux GTK x86-64, Windows x86-64, and macOS Cocoa
  x86-64 or aarch64.

## Run in Eclipse

1. Build the workspace and wait for the project to compile.
2. Open the `app.ui_*.bndrun` file matching your operating system and
   architecture. The `app.ui_shared.bndrun` file is included by the launch
   configurations and is not a standalone launch target.
3. Click **Resolve**, save the file, then select
   **Run As > Bnd OSGi Run Launcher**.

On macOS, the supplied launch configuration enables `-XstartOnFirstThread`.

## Run from the bnd CLI

Install the [bnd CLI](https://bnd.bndtools.org/chapters/120-install.html), then
run these commands from the workspace root. Set `RUN_FILE` to the launch file
for your host; example below uses Windows x86-64. bnd 7.4 cannot build this
project because its build path contains an Eclipse feature; use a newer bnd CLI
that supports Eclipse features on the build path.

```bash
cd example.rcp.app.ui
bnd build
RUN_FILE=app.ui_win32.win32.x86-64.bndrun
bnd resolve resolve -W "$RUN_FILE"
bnd run "$RUN_FILE"
```
