# BND Cheatsheet

This template fragment provides a comprehensive reference for bnd macros and instructions through a well-documented `bnd.bnd` file.

## Purpose

The `bnd.bnd` file in this template serves as a **cheatsheet** and **reference guide** for bnd macros. It contains examples of:

- String operations (case conversion, trimming, substring, replace, etc.)
- List operations (join, filter, sort, unique, etc.)
- Numeric operations (sum, average, min, max, comparisons, etc.)
- Conditional logic (if, is, def, etc.)
- File and path operations (cat, base64, digest, basename, etc.)
- Environment and system information (env, timestamps, versions, etc.)
- Advanced operations (foreach, map, format, etc.)

## What's Included

- **bnd.bnd** - Comprehensive examples of all major bnd macros with descriptions
- **example.txt** - Sample file for testing file-based macros (cat, base64, digest)
- **README.md** - This file

## How to Use

1. **As a template** - Include this fragment when creating a new bnd workspace to have the cheatsheet available
2. **As a reference** - Open `bnd.bnd` in any editor to see macro syntax and examples
3. **For experimentation** - Modify the examples to test different macro behaviors
4. **For learning** - Read through the examples to understand macro capabilities

## Macro Categories

The bnd.bnd file organizes macros into logical categories:

- **String Operations** - Text manipulation and searching
- **List Operations** - Working with comma-separated lists
- **Numeric Operations** - Mathematical calculations and comparisons  
- **Conditional & Logic** - Decision making and boolean operations
- **File & Path Operations** - File system interactions
- **Environment & System** - System information and timestamps
- **Version & Build Info** - Build metadata and versioning
- **Advanced Operations** - Iteration, transformation, and formatting

## Notes

- Most examples are self-contained and ready to use
- File-based macro examples reference `example.txt`
- Some macros that depend on runtime context are commented out
- All examples follow the syntax: `example.<name>: ${macro;args}`

## Documentation

For complete macro documentation, see:
- [Macro Reference](https://bnd.bndtools.org/chapters/855-macros-ref.html)
- [Macro Index](https://bnd.bndtools.org/chapters/850-macros.html)
- [Test Cases](https://github.com/bndtools/bnd/blob/master/biz.aQute.bndlib.tests/test/test/MacroTestsForDocsExamples.java)

## Based On

This cheatsheet is based on the macro documentation improvements from:
- [PR #6948 - Document macro java methods](https://github.com/bndtools/bnd/pull/6948)
- Documentation files in `docs/_macros/` directory of the bnd repository

## bnd CLI Cheatsheet

The following section showcases some use bnd cli commands.


### Compare / diff the MANIFEST of two .jar files

This is useful e.g. if you want to see if an update of your / a library added certain OSGi headers. For example it is important to know that there are new mandatory `Import-Package` headers which would affect consumers. 
See https://bnd.bndtools.org/commands/diff.html

```
bnd diff -m path/to/assertj-core-4.0.0-SNAPSHOT.jar path/to/assertj-core-3.27.6.jar
```

Example output:

```
CHANGED    MANIFEST   <manifest>
 ADDED      HEADER     Bundle-Version:4.0.0
 CHANGED    HEADER     Export-Package
  CHANGED    CLAUSE     org.assertj.core.annotation
   REMOVED    PARAMETER  version:3.27.6
   ADDED      PARAMETER  version:4.0.0
```

The `-m` option refers to "MANIFEST". Without the `-m` option you get much more output also to changes in .class files.

### Show Manifest of a .jar file

This then shows the Manifest in a nicely formatted way, which is much more readable then the plain MANIFEST.MF which has special formatting limits (e.g. max line lenth 72 bytes which is hard to read for long lines).
See https://bnd.bndtools.org/commands/print.html

```
bnd print -m  path/to/assertj-core-4.0.0-SNAPSHOT.jar
```


