# Assignment 2: Word Length Console Project

This project is a Kotlin console application that builds a map from words to their lengths, keeps only the longer entries, and prints the result in a readable format.

## Project Goal

The program starts with a list of words, creates a `Map<String, Int>`, removes entries whose length is `4` or less, and prints the remaining entries line by line.

Sample input used in `main`:

```kotlin
val words = listOf("apple", "cat", "banana", "dog", "elephant")
```

Console output:

```text
apple has length 5
banana has length 6
elephant has length 8
```

## What This Project Contains

- a standalone Kotlin/JVM console project
- a word-to-length map builder
- a filter for entries longer than 4 characters
- a printer for the final output
- unit tests for the core behavior
- a Gradle wrapper so the project can run without a global Gradle installation

## Project Structure

```text
Assignment 2/
|-- build.gradle.kts
|-- gradle.properties
|-- gradlew
|-- gradlew.bat
|-- settings.gradle.kts
|-- README.md
|-- src/
|   |-- main/
|   |   `-- kotlin/com/example/assignment2/Main.kt
|   `-- test/
|       `-- kotlin/com/example/assignment2/WordLengthTest.kt
`-- gradle/wrapper/
    |-- gradle-wrapper.jar
    `-- gradle-wrapper.properties
```

## How the Program Works

The application is split into small functions:

- `buildWordLengthMap(words)`: creates a map where each word points to its character count
- `filterWordsLongerThan(wordLengths)`: keeps only entries whose length is greater than `4`
- `formatWordLengthEntry(word, length)`: creates the printed line
- `printWordLengthEntries(entries)`: prints each remaining entry

The implementation uses Kotlin collection features directly:

- `associateWith` to create the map
- `filter` to remove shorter entries
- `forEach` to print each remaining entry

## Source Code Summary

Main flow:

```kotlin
fun main() {
    val words = listOf("apple", "cat", "banana", "dog", "elephant")
    val wordLengths = buildWordLengthMap(words)
    val longWords = filterWordsLongerThan(wordLengths)

    printWordLengthEntries(longWords)
}
```

Core mapping function:

```kotlin
fun buildWordLengthMap(words: List<String>): Map<String, Int> =
    words.associateWith { it.length }
```

Filter function:

```kotlin
fun filterWordsLongerThan(
    wordLengths: Map<String, Int>,
    minimumLengthExclusive: Int = 4,
): Map<String, Int> = wordLengths.filter { (_, length) ->
    length > minimumLengthExclusive
}
```

## User Guide

### Prerequisites

- Java JDK 24 installed
- Windows PowerShell if you want to use `gradlew.bat`

This project uses:

- Gradle `8.14.4`
- Kotlin Gradle plugin `2.2.21`

### Run the program

From the `Assignment 2` folder:

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

1. Open the `Assignment 2` folder as a project.
2. Let Gradle sync finish.
3. Run `Main.kt` to see the console output.
4. Run `WordLengthTest.kt` to execute the tests.

## Example Behavior

Input list:

```kotlin
listOf("apple", "cat", "banana", "dog", "elephant")
```

Intermediate map:

```kotlin
{
    "apple"=5,
    "cat"=3,
    "banana"=6,
    "dog"=3,
    "elephant"=8
}
```

Filtered result:

```kotlin
{
    "apple"=5,
    "banana"=6,
    "elephant"=8
}
```

Printed lines:

```text
apple has length 5
banana has length 6
elephant has length 8
```

## How to Change the Input

You can edit the `words` list in `main`:

```kotlin
val words = listOf("table", "pen", "notebook", "cup")
```

You can also change the filter threshold by passing a different value:

```kotlin
val longWords = filterWordsLongerThan(wordLengths, minimumLengthExclusive = 6)
```

That would keep only words with length greater than `6`.

## Test Coverage

The tests verify:

- map creation from a list of strings
- filtering entries longer than four characters
- output line formatting
- empty-list behavior

## Summary

This project provides a small Kotlin console program that demonstrates map creation, filtering, and formatted output using standard Kotlin collection operations.

## Collaboration

For changes in this folder, use a short-lived branch from `main`, for example `docs/assignment-2-readme-update` or `feat/assignment-2-improvement`.

Before opening a pull request:

- keep the change scoped to `Assignment 2/` whenever possible
- run `.\gradlew.bat test`
- open the pull request into `main`
