# Eclipse Repository Fragments

This folder contains bnd workspace template fragments for Eclipse Platform and Eclipse Simultaneous Release (SimRel) repositories.

## Naming Convention

Each fragment provides one repository:

- `eclipse_<platform-version>_platform` provides the Eclipse Platform update site. For example, `eclipse_4.41_platform`.
- `eclipse_<platform-version>_simrel_<YYYY-MM>` provides the SimRel repository for that platform generation. For example, `eclipse_4.41_simrel_2026-09`.

The fragment's `cnf/ext` file records the platform version and release timestamp. Platform timestamps use the `R-<version>-<YYYYMMDDHHMM>` form; SimRel timestamps use `<YYYYMMDDHHMM>`. Repository properties are release-specific, such as `eclipse.repo.4.41.p2` for Platform and `eclipse.repo.2026-09.p2` for SimRel. Keep the fragment directory, configuration filename, version properties, repository property names, and generated index filename consistent when adding a release.

## Including Multiple Versions

Platform and SimRel fragments have version-specific repository property names, so multiple versions can be included in the same bnd workspace. Select each desired fragment when creating or configuring the workspace. For example, a workspace can include Platform 4.40 and 4.41, and either or both matching SimRel repositories.

Each fragment exposes a P2 and an OSGi repository definition. All fragments use the shared `indexed` property: `false` selects P2 by default and `true` selects OSGi. Use the same setting in every included Eclipse fragment. Set it to `true` only after generating and committing the P2 indexes for all included repositories.

## Generate and Store the P2 Index

P2 repositories create their local index when accessed. To prepare a workspace for the faster OSGi repository:

1. Include the desired Eclipse fragments and leave `indexed = false` while generating indexes.
2. From the bnd workspace root, run `bnd repo refresh`. This refreshes the active P2 repositories and generates each index at the path configured by its `location` property. In the current fragments, the `.gz` index is under `cnf/ext`, beside the repository configuration.
3. Check that each generated `eclipse_<version>_platform_p2.index.xml.gz` or `eclipse_<version>_simrel_<YYYY-MM>_p2.index.xml.gz` exists and is non-empty.
4. Add and commit these `.gz` index files to source control alongside the corresponding fragment configuration. They are required by the OSGi repository on other workstations and CI; do not rely on a local cache or regenerate them during every setup.
5. Set `indexed = true` in all included Eclipse configurations. Each OSGi repository then reads its committed index instead of building it from the remote P2 site, reducing workspace setup time.

The repository cache under `build/cache` is local generated data and should not be committed. Regenerate and commit an index when updating its Eclipse release or repository contents.
