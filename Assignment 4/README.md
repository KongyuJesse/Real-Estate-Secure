# Assignment 4: Kotlin Feature Showcase

This project is a Kotlin console application that implements a generic `maxOf` function and demonstrates core Kotlin features such as generics, extension functions, sealed classes, and collection operations.

## Project Goal

The project focuses on:

- a generic `maxOf` function that works with any `Comparable<T>`
- default and named arguments
- varargs
- infix and extension functions
- immutable collections
- lambdas and higher-order functions
- `map`, `filter`, and `fold`
- classes, inheritance, interfaces, data classes, and sealed classes

## What This Project Contains

- a standalone Kotlin/JVM console project
- a generic `maxOf` implementation
- a small student grading domain that uses classes, interfaces, and a sealed class
- list filtering, mapping, and folding for calculations
- unit tests for the generic function and key behaviors
- a Gradle wrapper so the project can run without a global Gradle installation

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

## Key Functions

Generic `maxOf`:

```kotlin
fun <T : Comparable<T>> maxOf(list: List<T>): T? =
    list.fold<T?>(null) { currentMax, item ->
        if (currentMax == null || item > currentMax) item else currentMax
    }
```

Extension and infix function:

```kotlin
infix fun String.startsWithAny(initials: Set<Char>): Boolean
```

Sealed class for grading:

```kotlin
sealed class GradeResult {
    data class Passed(val average: Double) : GradeResult()
    data class Failed(val average: Double) : GradeResult()
    object NoScores : GradeResult()
}
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

## User Guide

### Prerequisites

- Java JDK 24 installed
- Windows PowerShell if you want to use `gradlew.bat`

This project uses:

- Gradle `8.14.4`
- Kotlin Gradle plugin `2.2.21`

### Run the program

From the `Assignment 4` folder:

```powershell
.\gradlew.bat run
```

On Git Bash or another Unix-like shell:

```bash
./gradlew run
```

### Run the tests

```powershell
.\gradlew.bat test
```

### Open in IntelliJ IDEA or Android Studio

1. Open the `Assignment 4` folder as a project.
2. Let Gradle sync finish.
3. Run `Main.kt` to see the console output.
4. Run `FeatureShowcaseTest.kt` to execute the tests.

## Summary

This assignment demonstrates how to build a Kotlin console app that mixes generic programming with Kotlin language features and collection operations.
