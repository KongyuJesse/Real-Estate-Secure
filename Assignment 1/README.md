# Assignment 1: `processList` Kotlin Console Project

This project is a Kotlin console application built around a reusable `processList` function.

## Core Function

```kotlin
fun processList(
    numbers: List<Int>,
    predicate: (Int) -> Boolean
): List<Int>
```

Example usage:

```kotlin
val nums = listOf(1, 2, 3, 4, 5, 6)
val even = processList(nums) { it % 2 == 0 }
println(even) // [2, 4, 6]
```

## What This Project Contains

- a standalone Kotlin/JVM console project
- a `processList` implementation
- a `main` function with sample outputs
- unit tests for common cases
- a Gradle wrapper so the project can run without installing Gradle globally

## Project Structure

```text
Assignment 1/
|-- build.gradle.kts
|-- gradle.properties
|-- gradlew
|-- gradlew.bat
|-- settings.gradle.kts
|-- README.md
|-- src/
|   |-- main/
|   |   `-- kotlin/com/example/assignment1/Main.kt
|   `-- test/
|       `-- kotlin/com/example/assignment1/ProcessListTest.kt
`-- gradle/wrapper/
    |-- gradle-wrapper.jar
    `-- gradle-wrapper.properties
```

## How the Program Works

`processList` accepts two inputs:

1. `numbers`: a list of integers
2. `predicate`: a lambda that returns `true` for values that should be kept

The function loops through the input list, checks every number with the lambda, and adds only the matching numbers to a new list.

Example:

- input list: `[1, 2, 3, 4, 5, 6]`
- predicate: `{ it % 2 == 0 }`
- output: `[2, 4, 6]`

## Source Code

Main implementation:

```kotlin
fun processList(
    numbers: List<Int>,
    predicate: (Int) -> Boolean,
): List<Int> {
    val filteredNumbers = mutableListOf<Int>()

    for (number in numbers) {
        if (predicate(number)) {
            filteredNumbers += number
        }
    }

    return filteredNumbers
}
```

## Console Output Example

When you run the program, the sample `main` function prints:

```text
Input numbers: [1, 2, 3, 4, 5, 6]
Even numbers: [2, 4, 6]
Numbers greater than 3: [4, 5, 6]
Odd numbers: [1, 3, 5]
```

## User Guide

### Prerequisites

- Java JDK 24 installed
- Windows PowerShell if you want to use `gradlew.bat`

This project is configured with:

- Gradle `8.14.4`
- Kotlin Gradle plugin `2.2.21`

That combination matches official compatibility guidance for Kotlin `2.2.21` with Gradle `8.14`, and Gradle `8.14.4` supports running on Java `24`.

Sources:

- https://kotlinlang.org/docs/gradle-configure-project.html
- https://docs.gradle.org/8.14.4/release-notes.html

### Run the program

From the `Assignment 1` folder:

```powershell
.\gradlew.bat run
```

On Git Bash or other Unix-like shells:

```bash
./gradlew run
```

### Run the tests

```powershell
.\gradlew.bat test
```

### Open in IntelliJ IDEA or Android Studio

1. Open the `Assignment 1` folder as a project.
2. Let Gradle sync the project.
3. Run `Main.kt` to see the console output.
4. Run `ProcessListTest.kt` to execute the unit tests.

## How to Change the Predicate

You can reuse `processList` with any condition you want.

Keep only even numbers:

```kotlin
val even = processList(nums) { it % 2 == 0 }
```

Keep only odd numbers:

```kotlin
val odd = processList(nums) { it % 2 != 0 }
```

Keep numbers greater than 3:

```kotlin
val greaterThanThree = processList(nums) { it > 3 }
```

Keep numbers less than or equal to 4:

```kotlin
val small = processList(nums) { it <= 4 }
```

## Test Coverage

The tests currently verify:

- filtering even numbers
- filtering numbers greater than 3
- behavior with an empty input list
- behavior when no numbers match

## Summary

This project satisfies the assignment by:

- creating a Kotlin console project
- implementing `processList(numbers, predicate)`
- demonstrating the function in `main`
- including tests
- documenting the full project and usage in this README
