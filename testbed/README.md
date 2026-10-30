# Fragment Testbed

Exercises the workspace template fragments of this repository with a real
`bnd` CLI, locally and in GitHub Actions
([testbed.yml](../.github/workflows/testbed.yml)).

For every test a clean, empty directory is used. Workspaces of failed tests are
kept for inspection; passing workspaces are deleted (logs stay). All results are
collected in a navigable `REPORT.md` that links to logs, kept workspace files and
the fragment sources.

## What Is Tested

Fragments come from the working tree (uncommitted changes included). Each
`bndtools/workspace-templates/...` entry of [index.bnd](../index.bnd) is zipped
and offered to bnd through a generated local index (`testbed-index.bnd`,
appended to `cnf/build.bnd`), so the real `bnd add fragment` code path including
`require` resolution and `tool.bnd` handling is used.

Two test kinds:

- **individual** - one workspace per fragment (requirements are installed by bnd)
- **all-in-one** - one workspace with all non-archived fragments

Steps per test (each recorded as `PASS`, `WARN`, `FAIL` or `SKIP`):

| Step | Command | Notes |
| --- | --- | --- |
| `workspace` | `bnd add workspace ws` | fresh workspace |
| `fragment` | `bnd add fragment testbed:<slug> ...` | must report `Added N template fragment(s)` |
| `repos` | `bnd repo repos`, `bnd repo list` | loads all repository indexes |
| `build` | `bnd build` | every project directory containing `bnd.bnd`; `WARN` when bnd reports warnings (e.g. empty bundles, unused `-privatepackage`) |
| `resolve` | `bnd resolve resolve -W <file>.bndrun` | all bndruns except include-only files (referenced by another bndrun in the same directory, e.g. `*_shared.bndrun`); `WARN` if committed `-runbundles` drift |
| `run` | `bnd run` / `bnd runtests` | only bndruns matching the host platform (`*_linux.gtk.x86-64.bndrun` etc.) or platform neutral ones; `-XstartOnFirstThread` only on macOS; `-tester`/`Test-Cases` bndruns use `runtests` and must produce JUnit XML with at least one test and no failures (0 tests = `FAIL`); others run until `--run-timeout` and pass when the log has no error markers; when the bndrun sets `org.osgi.service.http.port` the port must answer HTTP; Linux without `DISPLAY` uses `xvfb-run` |

## Usage

Prerequisites: bash 4+, Java 21 (`JAVA_HOME`), perl, curl, git, `jar` from the
JDK. The bnd CLI still reads the public master index, so GitHub must be
reachable.

```bash
bash testbed/testbed.sh --list                                  # fragment slugs
bash testbed/testbed.sh                                         # release bnd, individual + all-in-one
bash testbed/testbed.sh --bnd snapshot --include-archived
bash testbed/testbed.sh --bnd rc                                # newest release candidate newer than the release
bash testbed/testbed.sh --fragment demo-webapp --fragment eclipse-apps__headless
bash testbed/testbed.sh --bnd 7.4.0 --skip-run --keep-all
bash testbed/testbed.sh --bnd 7.5.0-RC1
bash testbed/testbed.sh --bnd /path/to/biz.aQute.bnd.jar
bash testbed/lib/fetch-bnd.sh --list-rc                         # RC versions newer than the release
```

Options:

| Option | Meaning |
| --- | --- |
| `--bnd release\|snapshot\|rc\|<version>\|<jar>` | bnd CLI; `release` from Maven Central, `snapshot` latest timestamped build and `rc` newest release candidate newer than the release from `bndtools.jfrog.io`; `<version>` like `7.4.0` or `7.5.0-RC1` (default `release`) |
| `--fragment <slug>` | test only this fragment (repeatable) |
| `--individual` / `--all-in-one` | select test kinds (default: both) |
| `--include-archived` | also test archived Eclipse fragments individually |
| `--skip-run` | resolve only |
| `--run-timeout <s>` | launch time for long running apps (default 90) |
| `--keep-all` | keep passing workspaces too |
| `--work-dir <dir>` | output directory (default `testbed/work/<os>-<bnd>-<timestamp>`, must be empty) |

Environment: `JAVA_HOME`; `TESTBED_CURL_OPTS` for extra curl options (for
example `--ssl-no-revoke` behind TLS interception).

Slugs are the fragment path with `/` replaced by `__`, e.g.
`eclipse-apps__app-ui`, `eclipse__eclipse_4.41_platform`.

Exit code is `1` when any step failed.

## Output

```
<work-dir>/
  REPORT.md            navigable report (summary, issues with log tails, all steps)
  results.tsv          every step as TSV
  meta.env             os, java, bnd version, git sha, ...
  testbed-index.bnd    generated local fragment index
  zips/<slug>.zip      fragments as offered to bnd
  <test>/
    status.tsv
    logs/NN-<step>-<subject>.log
    ws/                kept only on failure (or --keep-all)
```

In CI a `plan` job builds the bnd matrix: `release`, `snapshot` and every
release candidate newer than the release (newest RC per version). The report
summary is written to the job summary and the whole work
directory (minus repository caches) is uploaded as artifact
`testbed-<os>-<bnd>`; the `summary` job publishes `testbed-all` with one
`REPORT.md` per matrix entry plus a combined fragment x job result table in
its job summary.
