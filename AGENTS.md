# AGENTS.md

## Purpose

`bndtools/workspace-templates` holds **bnd workspace template fragments**. When bndtools (or `bnd add fragment`) creates a workspace, the user picks fragments; each fragment is a folder whose content is copied into the new workspace. [index.bnd](index.bnd) is the master index bndtools reads by default. Docs: https://bnd.bndtools.org/chapters/620-template-fragments.html

There is no product code here. Content is bnd config (`cnf/ext/*.bnd`, `*.bndrun`, `bnd.bnd`), small example projects, and a bash/perl testbed that validates every fragment.

## Layout

| Path | Fragment / role |
| --- | --- |
| `index.bnd` | Master index: `name`, `description`, `require`, `archived` per fragment. Also references external fragments (mnlipp, eclipse-tycho). |
| `gradle/`, `maven/` | Build layout fragments (`tool.bnd` handled by bnd). |
| `osgi/` | OSGi R8 + Felix (`cnf/ext/defaults.bnd`, `build.mvn`, `runtime.mvn`, `java.bnd`). |
| `osgi-testing/` | JUnit 5 + OSGi testing. Requires `osgi`. |
| `demo-webapp/` | Web app example. Requires `osgi`, `osgi-testing`. |
| `cheatsheet/` | bnd macro/instruction reference project. |
| `eclipse/eclipse_<pv>_platform`, `eclipse/eclipse_<pv>_simrel_<YYYY-MM>` | One Eclipse repository per fragment (P2 + indexed OSGi variants). See [eclipse/README.md](eclipse/README.md). |
| `eclipse-apps/{headless,ui,app-ui,tray-app}` | Eclipse RCP examples; require the latest platform fragment. See [eclipse-apps/README.md](eclipse-apps/README.md). |
| `eclipse-apps/{swtbot-tests,tray-app-swtbot-tests}` | SWTBot tests; require the latest platform, `swtbot-repo` and their app fragment (`app-ui` / `tray-app`). The tray tests use native Linux (X11/AT-SPI) and Windows drivers; macOS is not implemented and fails explicitly. The Windows driver also fails explicitly, as a known/accepted limitation, on GitHub Actions hosted `windows-latest` runners (the tray icon never gets a valid bounding rectangle there); see the fragment README. |
| `eclipse-apps/swtbot-repo` | Shared SWTBot p2 repository config (`cnf/ext`, no project); required by every SWTBot test fragment. |
| `testbed/` | Test harness. See [testbed/README.md](testbed/README.md). |
| `.github/workflows/` | `testbed.yml` (reusable), `poll-bnd-master.yml`, `bnd-master.yml`. |

## Rules

- A fragment is only discoverable if listed in `index.bnd`. New/removed/renamed fragment = update `index.bnd`.
- `require="..."` must list every fragment a fragment depends on, using full `bndtools/workspace-templates/<path>` ids.
- Do not duplicate config across fragments; rely on `require` (e.g. app fragments get repos from the Eclipse platform fragment, not their own `cnf/ext`).
- Fragments are templates copied into user workspaces: keep them minimal, no generated output, no `bin/`, `target/`, `generated/`, `.settings`, `cnf/cache` (see `.gitignore`).
- Eclipse apps need Java 21+; UI bndruns exist per platform (linux.gtk.x86-64, win32.x86-64, macosx.cocoa x86-64/aarch64).
- Licensing: existing examples are Apache-2.0; the tray app and its tests (adapted from Gaia) are EPL-2.0 with their own `LICENSE`. Keep each example's license consistent with its source.
- Never commit `testbed/work/` or `testbed/.cache/` (gitignored).

## Adding an Eclipse release

Use the `add-eclipse-release` skill for timestamps and process, but follow **this repo's current conventions** (the skill text may lag):

- Dirs: `eclipse/eclipse_<pv>_platform` and `eclipse/eclipse_<pv>_simrel_<YYYY-MM>`, each with `cnf/ext/<dir>.bnd` and a committed `cnf/ext/<dir>_p2.index.xml.gz` file (e.g. `eclipse_4.41_platform_p2.index.xml.gz`) — keep dir, filenames, version properties and repo property names consistent.
- Properties are release-specific: `eclipse.repo.<pv>.p2` / `eclipse.repo.<pv>.osgi` (platform), `indexed.ecl-<pv>` or `indexed.ecl-<YYYY-MM>` selector (default `true`), `-plugin.*` pair selecting exactly one backend. Copy the previous release's `.bnd` and adjust.
- Platform reltag `R-<pv>-<YYYYMMDDHHMM>`; SimRel reltag `<YYYYMMDDHHMM>`. Verify from `compositeContent.jar` on download.eclipse.org.
- Generate the index with `indexed...=false` + `bnd repo refresh`/`repo list`, commit only the `_p2.index.xml.gz` index file (no downloaded bundles), set selector back to `true`. Do not commit `build/cache`.
- In `index.bnd`: add the new entries on top of the Eclipse block, mark the previous release `archived=true`, and update every `require="...eclipse_<pv>_platform"` in the `eclipse-apps` entries (headless, ui, app-ui, tray-app, both SWTBot test fragments) and the platform mention in `eclipse-apps/README.md` to the new platform.

## Validate changes

Testbed installs each non-archived `bndtools/workspace-templates/...` fragment from the working tree into clean workspaces and runs `bnd add workspace`, `add fragment`, `repo`, `build`, `resolve`, `run`/`runtests`.

Prereqs: bash 4+, Java 21 (`JAVA_HOME`), perl, curl, git, JDK `jar`. Windows: run from Git Bash.

```bash
bash testbed/testbed.sh --list
bash testbed/testbed.sh --fragment demo-webapp --fragment eclipse-apps__headless
bash testbed/testbed.sh --bnd snapshot --skip-run          # quick, resolve only
bash testbed/testbed.sh --include-archived                 # also archived Eclipse fragments
```

- Slug = fragment path with `/` → `__` (`eclipse-apps__app-ui`).
- Exit code 1 on any FAIL; WARN is non-fatal (empty bundles, `-runbundles` drift).
- Results in `testbed/work/<os>-<bnd>-<ts>/REPORT.md`; failed workspaces are kept under `ws/`.
- `--bnd release|snapshot|rc|<version>|<jar>`. Behind TLS interception set `TESTBED_CURL_OPTS=--ssl-no-revoke`.
- Docs-only or index-description changes need no testbed run; any change to fragment content does.

Tray tests need a real X11 system-tray host on Linux. CI runs `dbus-run-session -- xvfb-run -a bash testbed/lib/with-tray.sh bash testbed/testbed.sh ...` (installs xvfb, xauth, trayer, dbus-x11, at-spi2-core, python3-pyatspi, xdotool, x11-utils; `NO_AT_BRIDGE=0 GTK_A11Y=always`). `with-tray.sh` refuses to replace an existing tray host and fails if it dies. Locally use the same wrapper with `--fragment eclipse-apps__tray-app --fragment eclipse-apps__tray-app-swtbot-tests` (see [testbed/README.md](testbed/README.md)); plain `xvfb-run` provides no tray.

CI: `testbed.yml` runs on ubuntu/windows/macos for release + snapshot bnd (matrix from `TESTBED_BND_CHANNELS`). `poll-bnd-master.yml` polls `bndtools/bnd` master every 15 min and dispatches `bnd-master.yml` here; nothing in bnd's repo/CI is touched. Org only allows bndtools/GitHub-owned actions: use in-repo scripts (`testbed/lib/*`) and `gh api`, not marketplace actions.

## bnd CLI

`java -jar ~/biz.aQute.bnd.jar <cmd>` (or the `bnd` skill). Useful: `bnd resolve resolve -W -b <file.bndrun>`, `bnd repo list`, `bnd repo refresh`, `bnd build`. When resolving bndruns in a fragment, commit updated `-runbundles` only if intended; the testbed warns on drift.

## Commits

- Never add AI `Co-authored-by` trailers; keep the user's `Signed-off-by`. Commits are GPG-signed.
