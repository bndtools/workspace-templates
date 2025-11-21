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
