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
| `run` | `bnd run` / `bnd runtests` | only bndruns matching the host platform (`*_linux.gtk.x86-64.bndrun` etc.) or platform neutral ones; `-XstartOnFirstThread` only on macOS; SWTBot uses a dedicated resolved OSGi launch harness (with headless AWT on macOS) and must produce JUnit XML with at least one test and no failures (0 tests = `FAIL`); other `-tester`/`Test-Cases` bndruns use `runtests`; apps run until `--run-timeout` and pass when the log has no error markers; when the bndrun sets `org.osgi.service.http.port` the port must answer HTTP; Linux without `DISPLAY` uses `xvfb-run` |

## Usage

Prerequisites: bash 4+, Java 21 (`JAVA_HOME`), perl, curl, git, `jar` from the
JDK. The bnd CLI still reads the public master index, so GitHub must be
reachable. The testbed disables the JVM XML general and total entity size limits
for bnd so large repository index entries can be parsed.

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

In CI, `TESTBED_BND_CHANNELS` in `.github/workflows/testbed.yml` controls the
bnd matrix. It accepts a space- or comma-separated list of `release`,
`snapshot`, and `rc`; `rc` expands to every release candidate newer than the
latest release (newest RC per version). It defaults to `snapshot` so release
and RC builds can be temporarily disabled without changing the matrix logic.
Results are visible in GitHub without downloading artifacts:

- **Job summary**: each matrix job writes its `REPORT.md` summary table, plus
  a collapsed *Issues* section with FAIL/WARN details and log tails.
- **Annotations**: `lib/annotate.pl` turns every FAIL/WARN row of
  `results.tsv` into an `::error`/`::warning` annotation on the run.
- **SWTBot check**: `lib/junit.pl` turns the SWTBot JUnit XML
  (`logs/junit-*/TEST-*.xml`) into a job-summary table, `::error` annotations
  on the failing test source line, and a check run `SWTBot / <os> / bnd <bnd>`
  created through the REST API. Fork PRs only get the summary and annotations
  because their token cannot create checks.
- **Combined report**: the `summary` job shows a one-page overview with each
  job's bnd CLI version, Java version, test counts, and aggregated fragment
  outcomes.
- **PR comment**: for same-repository PRs, `lib/pr-comment.sh` posts the
  overview as a single comment and updates it on each run. Set
  `TESTBED_PR_COMMENT` to anything other than `true` to disable it.

The bndtools organization only allows actions owned by bndtools or GitHub, so
these surfaces are implemented with in-repository scripts and `gh api`
instead of marketplace actions.

### Independent CI for bnd master

[Poll bnd master](../.github/workflows/poll-bnd-master.yml) runs every
15 minutes and can also be started manually. It reads the public master
commit SHA from `bndtools/bnd` and compares it with the most recently
dispatched [bnd master fragment testbed](../.github/workflows/bnd-master.yml).
An unchanged SHA does not start another build, including when its previous
run failed or is still running. Failed runs can be rerun in Actions.

For a new SHA, the poller dispatches the source testbed **in this repository**
using its own `GITHUB_TOKEN` with `actions: write`. No cross-repository
credential, webhook, workflow, check, status, or comment is added to bnd.
Only public source reads go to bnd; failures cannot affect its CI or merges.
GitHub schedules and runner availability can delay execution. Multiple
master updates between polls are coalesced to the latest revision, and
GitHub concurrency keeps at most one running and one pending source run.

The source workflow checks out the immutable bnd SHA, builds
`:biz.aQute.bnd:build` with the Gradle wrapper (skipping unit and OSGi tests
covered by bnd's CI), and uploads
`biz.aQute.bnd/generated/biz.aQute.bnd.jar` as a same-run artifact.
It calls the local reusable `testbed.yml` at the same workspace-templates
revision, with archived fragments enabled. For a manual source run, supply
the full bnd master commit SHA as `bnd_sha`.

The reusable workflow requires `bnd_artifact` (the artifact name) and accepts
`templates_ref` (default `master`) and `include_archived` (default `false`).
It checks out **workspace-templates**, not the caller's source tree, downloads
the CLI artifact on each OS, and tests that exact JAR instead of a published
snapshot. A missing JAR fails the job rather than falling back to a snapshot.
Reports, checks, and artifacts belong only to workspace-templates.
Source runs do not post PR comments. Native workspace-templates runs retain
their configured bnd channels, PR comments, and separate concurrency group.
The root [README](../README.md) links both workflow status badges.

Both new workflows must be merged to the default branch before polling and
manual dispatch are available. No change in bnd is needed.

Artifacts are still uploaded for full logs: the whole work directory (minus
repository caches) as `testbed-<os>-<bnd>`, and `testbed-all` with one
`REPORT.md` per matrix entry plus the combined `REPORT.md` and `OVERVIEW.md`.
