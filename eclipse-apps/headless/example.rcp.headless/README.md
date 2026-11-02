# Headless Equinox Application

This example shows a terminal-only Equinox application. Its application entry
point is `example.rcp.headless.application`.

## Requirements

- Java 21 or newer.
- Add the `Eclipse RCP Headless` template fragment to a bnd workspace. It
  requires the Eclipse Platform fragment, which supplies the shared repository
  configuration.

## Run in Eclipse

1. Build the workspace and wait for the project to compile.
2. Open `headless.bndrun`, click **Resolve**, and save the file.
3. Select **Run As > Bnd OSGi Run Launcher**.

The run configuration starts `example.rcp.headless.application` and writes its
output to the console.

## Run from the bnd CLI

Install the [bnd CLI](https://bnd.bndtools.org/chapters/120-install.html), then
run these commands from the workspace root:

```bash
cd example.rcp.headless
bnd build
bnd resolve resolve -W headless.bndrun
bnd run headless.bndrun
```
