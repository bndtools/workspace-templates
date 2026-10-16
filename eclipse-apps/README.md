# Eclipse Application Templates

Select these fragments in the bndtools workspace wizard. Each application requires
the Eclipse Platform 4.41 fragment through `index.bnd`; the platform fragment
provides the `cnf/ext` repository configuration, without duplicating it here.

| Fragment | Project | Example |
| --- | --- | --- |
| `headless` | `example.rcp.headless` | Terminal-only Equinox application |
| `ui` | `example.rcp.ui` | SWT/JFace progress dialog |
| `app-ui` | `example.rcp.app.ui` | Eclipse 4 product with application model, handlers, and CSS |
| `swtbot-tests` | `example.rcp.app.ui.swtbot.tests` | SWTBot tests; also requires `app-ui` |

The examples are adapted from
[example.bnd.rcp](https://github.com/peterkir/example.bnd.rcp).
Use Java 21 or newer. The application fragments provide the published bndtools
application launcher through Maven Central. The test fragment additionally
registers the SWTBot p2 repository.

## Build And Launch

Build the projects in bndtools. Open `headless.bndrun`, or the `.bndrun` matching
your OS and architecture, click **Resolve**, and save before launching with
**Run As > Bnd OSGi Run Launcher**. Shared `.bndrun` files are include files,
not standalone launches. Runtime bundles are intentionally not pinned to the
older Eclipse release used by the original examples.

The UI examples support Linux GTK x86-64, Windows x86-64, and macOS Cocoa
x86-64/aarch64. macOS launches include `-XstartOnFirstThread`.

For SWTBot, build both the application and test project, resolve the matching
`swtbot_*.bndrun`, then use **Run As > Bnd OSGi Test Launcher (JUnit)**.
The test launcher uses separate runtime storage and runs tests on a background
thread so the SWT event loop retains the main thread.
