# Grade Calculator Studio

Grade Calculator Studio is a Kotlin-based Excel grading toolkit with two polished ways to work:

- a professional CLI for automation, guided terminal workflows, and batch processing
- a redesigned desktop UI for users who want a cleaner visual workspace

The project grades student score sheets, generates realistic sample workbooks, and includes a built-in Kotlin concepts showcase for the assignment requirements.

## What Was Improved In This Version

This iteration focused on turning the project from a functional prototype into a more polished tool.

### UI improvements

- redesigned the desktop window as a more intentional studio-style interface
- added a branded hero section and stronger visual hierarchy
- upgraded the grading and generation screens into cleaner card-based workspaces
- replaced plain text result areas with richer HTML summaries
- expanded form controls so users can set output paths, worksheet names, grading hints, mark limits, and overwrite behavior from the UI
- improved workbook inspection so the UI can preview sheet names and suggest output files before grading

### CLI improvements

- rewrote the help output so it reads like a professional command guide
- improved success and error messages with clearer formatting and summaries
- made batch grading output easier to scan
- upgraded the interactive wizard so it now supports:
  - generating workbooks with more options
  - grading a single workbook
  - grading an entire folder
  - launching the desktop UI
  - viewing the Kotlin concepts showcase
- removed an awkward prompt in normal file-grading mode by defaulting single-file output to a sibling `*_graded` workbook

### Engineering and maintenance improvements

- introduced shared presentation helpers so CLI and desktop output feel consistent
- added tests for the new command aliases and text presentation layer
- updated the Gradle wrapper to `8.14.4` for better compatibility with Java `24`
- configured Kotlin compilation to use in-process execution for a smoother sandboxed build experience

## Product Overview

The studio supports three primary workflows:

1. grade a workbook and write `Total`, `Percentage`, and `Grade` columns
2. grade a whole folder of Excel files into a clean output directory
3. generate realistic sample spreadsheets for practice, demos, and QA

## Core Features

- reads `.xlsx` and `.xls`
- auto-detects likely header rows
- detects numeric score columns automatically
- reuses an existing total column when one is present
- writes missing `Total`, `Percentage`, and `Grade` columns
- clamps percentages above `100`
- corrects negative marks to `0`
- skips empty rows and rows without usable numeric data
- supports sheet selection by name or index
- supports recursive folder grading
- prevents accidental overwrite unless explicitly allowed
- generates sample student workbooks with customizable subjects and score ranges

## Project Structure

```text
gradecalculator/
|-- app/
|   `-- Android app scaffold for future mobile expansion
|-- console/
|   |-- src/main/kotlin/com/example/gradecalculator/console/
|   |   |-- Main.kt
|   |   |-- Cli.kt
|   |   |-- DesktopApp.kt
|   |   |-- Presentation.kt
|   |   |-- ExcelGrader.kt
|   |   |-- RandomSheetGenerator.kt
|   |   |-- GradeScale.kt
|   |   |-- WorkbookSheets.kt
|   |   `-- KotlinConcepts.kt
|   `-- src/test/kotlin/com/example/gradecalculator/console/
|-- gradle/
|-- build.gradle.kts
|-- gradle.properties
|-- settings.gradle.kts
`-- README.md
```

## Module Responsibilities

### `console/`

This is the real working application module.

It contains:

- the CLI parser and interactive wizard
- the desktop Swing UI
- the Excel grading engine
- the random workbook generator
- the Kotlin concepts showcase
- the automated test suite

### `app/`

This is currently an Android scaffold module.

It still exists for future mobile expansion, but the production-grade UI in this repository today is the desktop UI inside `console/`.

## Desktop UI

The desktop interface is launched through the `console` module.

### Generator screen

The workbook generator screen lets you configure:

- output workbook path
- worksheet name
- number of student rows
- minimum and maximum marks
- optional seed value
- subject list
- whether a total column should be included
- overwrite behavior

After generation, the summary panel shows:

- the output path
- the sheet name
- the number of generated students
- the selected subjects

### Grader screen

The workbook grader screen lets you configure:

- input workbook path
- output workbook path
- worksheet selection
- optional header row override
- optional maximum total override
- total column hint
- percentage column name
- grade column name
- overwrite behavior

It also supports workbook inspection before grading so the user can:

- preview sheet names
- confirm the suggested output path
- review the workbook at a glance before running the grader

After grading, the summary panel shows:

- input and output workbook paths
- the sheet used
- processed row counts
- skipped-row diagnostics
- correction counts
- the maximum total used
- the final grade distribution

## CLI

The CLI is intended for power users, automation, and batch processing.

### Commands

- `interactive` or `wizard`
- `ui`, `desktop`, or `studio`
- `concepts`, `syntax`, or `kotlin`
- `grade`
- `generate`

### Interactive mode

Run the wizard:

```powershell
.\gradlew.bat :console:run
```

or:

```powershell
.\gradlew.bat :console:run --args="interactive"
```

The interactive menu now supports:

1. generating a sample workbook
2. grading one workbook
3. grading an entire folder
4. launching the desktop UI
5. viewing the Kotlin concepts showcase
6. showing CLI help
7. exiting

### Desktop UI command

```powershell
.\gradlew.bat :console:run --args="ui"
```

### Help command

```powershell
.\gradlew.bat :console:run --args="help"
```

### Grade one workbook

```powershell
.\gradlew.bat :console:run --args="grade --input C:\data\students.xlsx --output C:\data\students_graded.xlsx"
```

If `--output` is omitted for a single workbook, the CLI now defaults to a sibling output file named like:

```text
students_graded.xlsx
```

### Grade a folder

```powershell
.\gradlew.bat :console:run --args="grade --input C:\data\raw-marks --output-dir C:\data\graded --recursive"
```

### Generate a sample workbook

```powershell
.\gradlew.bat :console:run --args="generate --output C:\data\random_students.xlsx --students 50 --subjects Math,English,Physics,Chemistry,Biology"
```

### View the Kotlin concepts showcase

```powershell
.\gradlew.bat :console:run --args="concepts"
```

## Grading Rules

The grading engine follows a practical workflow:

1. verify that the input workbook exists
2. select the requested sheet, or auto-detect a usable one
3. locate the header row
4. ignore metadata-style columns such as student name or ID
5. detect numeric score columns
6. reuse an existing total column if one exists, or create one
7. create missing percentage and grade columns when needed
8. infer or accept the maximum total
9. process each row
10. write totals, percentages, and letter grades
11. return a structured summary for the CLI or desktop UI

### Error handling built into grading

- negative scores are corrected to `0`
- percentages above `100` are clamped
- empty rows are skipped
- rows without usable scores are skipped
- output files are protected from accidental overwrite unless approved

## Default Grade Scale

| Percentage | Grade |
|---|---|
| 97-100 | A+ |
| 93-96 | A |
| 90-92 | A- |
| 87-89 | B+ |
| 83-86 | B |
| 80-82 | B- |
| 77-79 | C+ |
| 73-76 | C |
| 70-72 | C- |
| 67-69 | D+ |
| 63-66 | D |
| 60-62 | D- |
| <60 | F |

Customize the scale in:

```text
console/src/main/kotlin/com/example/gradecalculator/console/GradeScale.kt
```

## Sample Workbook Generation

The generator creates realistic practice files with:

- `Student ID`
- `Student Name`
- one numeric column per subject
- an optional `Total` column

You can control:

- student count
- subject names
- sheet name
- score range
- repeatability through a seed
- output file path

## Kotlin Concepts Coverage

The project still includes the assignment-focused Kotlin showcase from `KotlinConcepts.kt`.

It explicitly demonstrates:

- functions and expression bodies
- default and named arguments
- varargs
- infix and extension functions
- immutable collections
- lambdas and higher-order functions
- `map`, `filter`, and `fold`
- classes, inheritance, interfaces, data classes, and sealed classes

## Build And Run

### Prerequisites

- Java JDK `17+`
- Gradle wrapper included in the repository

### Run the CLI wizard

```powershell
.\gradlew.bat :console:run
```

### Run the desktop UI

```powershell
.\gradlew.bat :console:run --args="ui"
```

### Run the console tests

```powershell
.\gradlew.bat :console:test
```

## Verification

The updated console module was verified with:

```powershell
.\gradlew.bat -g "c:\Users\HP GAMING LAPTOP\Desktop\AND Project and Assignment\.gradle-home" --no-daemon :console:test
```

During sandboxed verification, the environment also used:

- `ANDROID_USER_HOME=.android`
- `GRADLE_OPTS=-Duser.home=.test-home`

Those extra environment settings were only needed for the sandboxed build environment, not as part of normal project usage on a standard local machine.

## Tests Included

The `console` module currently covers:

- CLI command parsing
- Excel grading behavior
- random workbook generation
- grade scale boundaries
- Kotlin concepts coverage
- new presentation and reporting helpers

## Important Files

- `console/src/main/kotlin/com/example/gradecalculator/console/Main.kt`
  This is the CLI entry point and the interactive wizard.
- `console/src/main/kotlin/com/example/gradecalculator/console/Cli.kt`
  This parses commands and renders command help.
- `console/src/main/kotlin/com/example/gradecalculator/console/DesktopApp.kt`
  This contains the redesigned desktop UI.
- `console/src/main/kotlin/com/example/gradecalculator/console/Presentation.kt`
  This contains shared CLI and desktop presentation helpers.
- `console/src/main/kotlin/com/example/gradecalculator/console/ExcelGrader.kt`
  This is the core grading engine.
- `console/src/main/kotlin/com/example/gradecalculator/console/RandomSheetGenerator.kt`
  This creates sample workbooks.

## Troubleshooting

- `Output file already exists`
  Use `--overwrite`, approve the overwrite in the UI, or choose a different path.
- `Could not detect a header row`
  Supply a header row explicitly with the CLI or enter one in the desktop UI.
- `Could not detect any mark columns or total column`
  Make sure score columns are numeric and metadata columns are clearly labeled.
- `Unable to infer a valid maximum total`
  Provide `--max-total` or set the maximum total in the desktop grader form.
- `Desktop UI is not available in a headless environment`
  Use CLI mode instead.

## Future Expansion

Good next steps for the project would be:

- adding a mobile UI inside the Android module
- supporting user-defined grade scales from configuration files
- exporting richer grading reports
- adding workbook previews and validation warnings before grading
- introducing UI tests for the desktop workflow

## Summary

Grade Calculator Studio is now a cleaner, more professional project:

- the CLI is clearer and easier to trust
- the desktop UI is much more polished and pleasant to use
- the documentation is explicit enough for both users and maintainers
- the build setup is more compatible with the current Java environment

The result is still the same core product, but it now feels much closer to something you could confidently demo, submit, or extend.
