# Assignment 4: Generic `maxOf` And Student Report Showcase

Assignment 4 was already the most feature-rich folder, so the work here focused on making the implementation cleaner, improving the tests, and documenting exactly how the project satisfies the Kotlin concepts you listed.

## What The Program Does

This project combines two ideas:

1. a generic `maxOf` function that works on any `Comparable<T>`
2. a student grading report that demonstrates Kotlin object modelling and collection pipelines

The report filters students by initials, classifies each one against a pass threshold, computes the top average, and prints a readable summary.

## Kotlin Features Implemented

- functions and expression bodies
- default and named arguments
- varargs
- infix and extension functions
- immutable collections
- lambdas and higher-order functions
- `map`, `filter`, and `fold`
- classes, inheritance, interfaces, data classes, and sealed classes

## Feature Breakdown

### Functions and expression bodies

Examples:

```kotlin
fun scores(vararg scores: Int): List<Int> = scores.toList()

fun formatAverage(average: Double): String =
    String.format(Locale.US, "%.1f", average)
```

### Default and named arguments

Important examples:

```kotlin
fun classifyStudent(student: Student, passThreshold: Double = 60.0): GradeResult

fun buildStudentReport(
    students: List<Student>,
    initials: Set<Char> = setOf('A', 'B'),
    passThreshold: Double = 60.0,
    selector: (Student) -> Boolean = { true },
): String
```

Named arguments are used in `main` and in the tests.

### Varargs

The project uses `vararg` for both score lists and student lists:

```kotlin
val group = students(
    Student("Alice", scores(85, 90, 88)),
    Student("Bob", scores(70, 65, 72)),
)
```

### Infix and extension functions

This assignment includes:

```kotlin
infix fun String.startsWithAny(initials: Set<Char>): Boolean
fun List<Int>.averageOrNull(): Double?
fun <T> List<T>.formatWith(...): String
```

### Immutable collections

The design uses immutable `List` and `Set` values to represent students, scores, and initials.

### Lambdas and higher-order functions

The `selector` parameter in `selectStudents` and `buildStudentReport` makes the report customizable:

```kotlin
selector: (Student) -> Boolean = { true }
```

`formatWith` is also a higher-order extension that accepts a transformation lambda.

### `map`, `filter`, and `fold`

- `filter` narrows the student list
- `map` transforms students into results and averages
- `fold` powers both `averageOrNull` and the generic `maxOf`

### Classes, inheritance, interfaces, data classes, and sealed classes

The project demonstrates all required structures:

- `Person` is an open base class
- `HasScores` is an interface
- `Student` is a data class extending `Person`
- `GradeResult` is a sealed class

## Core Functions

### Generic `maxOf`

```kotlin
fun <T : Comparable<T>> maxOf(list: List<T>): T? =
    list.fold<T?>(null) { currentMax, item ->
        if (currentMax == null || item > currentMax) item else currentMax
    }
```

This version is generic, safe for empty lists, and clearly demonstrates `fold`.

### `selectStudents`

Filters students by initials and any extra rule provided as a lambda.

### `buildStudentReport`

Produces the final report:

```kotlin
fun buildStudentReport(
    students: List<Student>,
    initials: Set<Char> = setOf('A', 'B'),
    passThreshold: Double = 60.0,
    selector: (Student) -> Boolean = { true },
): String
```

## Example Output

```text
Alice: passed with 87.7
Bob: failed with 69.0
Anita: passed with 93.7
Ben: no scores
Top average: 93.7
9
kiwi
null
```

## Project Structure

```text
Assignment 4/
|-- build.gradle.kts
|-- gradle.properties
|-- gradlew
|-- gradlew.bat
|-- settings.gradle.kts
|-- README.md
|-- src/
|   |-- main/
|   |   `-- kotlin/com/example/assignment4/Main.kt
|   `-- test/
|       `-- kotlin/com/example/assignment4/FeatureShowcaseTest.kt
`-- gradle/wrapper/
    |-- gradle-wrapper.jar
    `-- gradle-wrapper.properties
```

## How To Run

From the `Assignment 4` folder:

```powershell
.\gradlew.bat run
```

## How To Test

```powershell
.\gradlew.bat test
```

## Test Coverage

The test suite verifies:

- generic `maxOf` behavior for numbers, strings, and empty lists
- score averaging
- filtering with initials plus a custom lambda selector
- threshold-based grade classification
- full report formatting

## Summary

Assignment 4 is now a polished Kotlin feature showcase: the generic algorithm is cleaner, the grading workflow is more explicit, and the documentation clearly maps the code back to every requested Kotlin concept.
