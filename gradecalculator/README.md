# Grade Calculator (Kotlin)

Kotlin/Gradle project for grading Excel score sheets from the command line or a desktop Swing UI.

## Project Layout

The `gradecalculator` folder contains three main parts:

- `console/`: the real application. It contains the CLI, Swing desktop UI, Excel grading logic, random workbook generator, and tests.
- `app/`: an Android app scaffold with manifest/resources only. There is no activity or mobile grading screen yet.
- Gradle files at the root: shared build configuration for the `:console` and `:app` modules.

Useful paths after analyzing the folder:

- `console/src/main/kotlin/.../Main.kt`: entry point and interactive flows.
- `console/src/main/kotlin/.../ExcelGrader.kt`: workbook grading rules.
- `console/src/main/kotlin/.../RandomSheetGenerator.kt`: sample workbook generator.
- `console/src/main/kotlin/.../DesktopApp.kt`: Swing desktop UI.
- `console/src/main/kotlin/.../KotlinConcepts.kt`: Kotlin concepts showcase used by the assignment.
- `console/src/test/kotlin/...`: tests covering CLI parsing, grading, generation, grade scale, and Kotlin concepts.
- `console/random_students.xlsx`: sample workbook already present in the repository.
- `console/build/`, `console/bin/`, `.gradle/`, `.kotlin/`: generated build artifacts and caches.

## Run Modes

1. CLI mode: `interactive`, `grade`, `generate`, `concepts`
2. Desktop UI mode: `ui` or `desktop`

## Prerequisites

- JDK 17 or later
- Windows PowerShell for the `gradlew.bat` examples below

## Quick Start

Run the interactive CLI wizard:

```powershell
.\gradlew.bat :console:run
```

or:

```powershell
.\gradlew.bat :console:run --args="interactive"
```

Run the desktop UI:

```powershell
.\gradlew.bat :console:run --args="ui"
```

Show command help:

```powershell
.\gradlew.bat :console:run --args="help"
```

## Common Commands

Grade one workbook:

```powershell
.\gradlew.bat :console:run --args="grade --input C:\data\students.xlsx --output C:\data\students_graded.xlsx"
```

Grade all workbooks in a folder:

```powershell
.\gradlew.bat :console:run --args="grade --input C:\data\raw-marks --output-dir C:\data\graded --recursive"
```

Generate a random workbook:

```powershell
.\gradlew.bat :console:run --args="generate --output C:\data\random_students.xlsx --students 50 --subjects Math,English,Physics,Chemistry,Biology"
```

Show the Kotlin concepts showcase:

```powershell
.\gradlew.bat :console:run --args="concepts"
```

## Manual Guide

### 1. Prepare the Excel file

The grader works with `.xlsx` and `.xls` files.

For best results, your sheet should have:

- one header row with text labels
- one row per student below the header
- metadata columns such as `Student ID` or `Student Name`
- subject columns that contain numeric scores

Recommended header style:

| Student ID | Student Name | Math | English | Physics |
|---|---|---|---|---|
| STU-0001 | Ada Lovelace | 95 | 88 | 91 |
| STU-0002 | Grace Hopper | 70 | 60 | 65 |

How the grader interprets the sheet:

- It auto-detects a header row if you do not provide `--header-row`.
- It ignores metadata-style columns such as name, ID, registration, class, section, gender, remarks, and similar labels.
- It treats remaining columns with numeric data as mark columns.
- If a `Total`-style column already exists, it can use it.
- It writes `Total`, `Percentage`, and `Grade` columns if they are missing.

### 2. Grade one workbook from the CLI

Use this when you already know the input and output file paths:

```powershell
.\gradlew.bat :console:run --args="grade --input C:\data\students.xlsx --output C:\data\students_graded.xlsx"
```

Useful options:

- `--sheet "Class A"`: use a specific sheet by name
- `--sheet 1`: use a specific sheet by index; naming the sheet is safer when possible
- `--header-row 1`: header row number is 1-based
- `--max-total 300`: manually set the full score when auto-inference is not correct
- `--total-column "Overall Score"`: help the grader recognize an existing total column
- `--percentage-column "Percentage"`: name for the written percentage column
- `--grade-column "Grade"`: name for the written grade column
- `--overwrite`: replace an existing output file

What happens during grading:

- negative marks are corrected to `0`
- percentages above `100` are clamped to `100`
- empty rows are skipped
- rows with no valid numeric scores are skipped
- the app prints row counts and grade distribution after completion

### 3. Grade a whole folder

If `--input` points to a folder, the app grades every Excel file inside it.

```powershell
.\gradlew.bat :console:run --args="grade --input C:\data\raw-marks --output-dir C:\data\graded --recursive"
```

Important rules:

- use `--output-dir` for folder grading
- do not use `--output` when the input is a folder
- use `--recursive` to include subfolders
- each result file is named `<original_name>_graded.<ext>`

### 4. Use the interactive wizard

Running `:console:run` with no arguments opens the interactive menu:

1. Generate a sample Excel sheet
2. Grade an Excel sheet
3. Launch desktop UI
4. Show CLI help
5. Exit

If you choose `Grade an Excel sheet`, the wizard:

1. asks for the Excel file path
2. lists workbook sheets if more than one exists
3. lets you keep the default output name or type a new one
4. asks whether to overwrite if the target file already exists

If you choose `Generate a sample Excel sheet`, the wizard asks for:

- output file path
- number of students
- comma-separated subject names

### 5. Use the desktop UI

The Swing UI has two tabs:

- `Generate Sheet`
- `Grade Sheet`

`Generate Sheet` tab:

- choose an output file
- enter the number of students
- enter comma-separated subjects
- click `Generate Sheet`

`Grade Sheet` tab:

- choose the Excel file to grade
- select a sheet or leave it on `Auto-detect sheet`
- choose whether to keep the default graded filename
- confirm overwrite if needed
- click `Grade File`

The desktop UI shows a short result summary in the text area after each action.

### 6. Generate sample data

The generator creates a workbook with:

- sheet name `Students` by default
- `Student ID` and `Student Name` columns
- one numeric column per subject
- an optional `Total` column

Example:

```powershell
.\gradlew.bat :console:run --args="generate --output C:\data\random_students.xlsx --students 30 --subjects Math,English,Physics --seed 42"
```

Useful generator options:

- `--students <number>`
- `--subjects <comma-separated list>`
- `--sheet-name <name>`
- `--include-total true|false`
- `--min-mark <number>`
- `--max-mark <number>`
- `--seed <number>`
- `--overwrite`

If you omit the file extension, the generator saves the file as `.xlsx`.

### 7. View the Kotlin assignment coverage

The `concepts` command prints the assignment-oriented Kotlin showcase from `KotlinConcepts.kt`.

It demonstrates:

- functions and expression bodies
- default and named arguments
- varargs
- infix and extension functions
- immutable collections
- lambdas and higher-order functions
- `map`, `filter`, and `fold`
- classes, inheritance, interfaces, data classes, and sealed classes

## Grading Features

- Reads `.xlsx` and `.xls`
- Detects header rows and score columns automatically
- Calculates totals, percentages, and letter grades
- Supports batch folder grading and recursive mode
- Prevents accidental overwrite unless `--overwrite` is used or you confirm it interactively
- Prints grading statistics, including skipped rows and grade distribution

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

Edit [`GradeScale.kt`](console/src/main/kotlin/com/example/gradecalculator/console/GradeScale.kt) to customize the grading bands.

## Troubleshooting

- `Output file already exists`: pass `--overwrite` or choose a different output file.
- `Could not detect a header row`: supply `--header-row <number>`.
- `Could not detect any mark columns or total column`: make sure score columns contain numeric values and metadata columns are clearly labeled.
- `Unable to infer a valid maximum total`: run again with `--max-total <number>`.
- `Desktop UI is not available in a headless environment`: use CLI mode instead of `ui`.
- `No interactive input stream is available`: run from a normal terminal, or use full CLI flags instead of the wizard.

## Tests

Run all console tests:

```powershell
.\gradlew.bat :console:test
```

## Collaboration

For changes in this folder, use a short-lived branch from `main`, for example `docs/gradecalculator-readme-update` or `feat/gradecalculator-improvement`.

Before opening a pull request:

- keep the change scoped to `gradecalculator/` whenever possible
- run `.\gradlew.bat :console:test`
- open the pull request into `main`
