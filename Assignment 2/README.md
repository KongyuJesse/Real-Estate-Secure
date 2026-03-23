# Assignment 2: Vocabulary And Word-Length Analysis

Assignment 2 is now a full Kotlin vocabulary-analysis project rather than a small one-step map exercise. It still builds a map of words to lengths, but it now adds reusable rule objects, report generation, richer tests, and explicit demonstrations of the Kotlin concepts required for the assignment.

## What The Program Does

The program takes an immutable collection of words, normalizes them, keeps only the longer ones, applies reusable analysis rules, and prints a readable report.

The workflow is:

1. create a `WordBatch` with `vararg` input
2. normalize words with an extension function
3. build a word-to-length map
4. filter long words
5. evaluate rule objects against the filtered data
6. generate a detailed report

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
fun String.cleanWord(): String = trim().lowercase()

fun formatWordLengthEntry(word: String, length: Int): String =
    "$word has length $length"
```

### Default and named arguments

Several APIs use defaults:

```kotlin
fun wordBatch(vararg words: String, label: String = "Vocabulary"): WordBatch

fun filterWordsLongerThan(
    wordLengths: Map<String, Int>,
    minimumLengthExclusive: Int = 4,
): Map<String, Int>
```

Named arguments are used in calls such as:

```kotlin
val batch = wordBatch("Apple", "Banana", label = "Mixed Vocabulary")
```

### Varargs

`wordBatch` accepts any number of words:

```kotlin
val batch = wordBatch("Apple", "cat", "Banana", "dog", "elephant")
```

### Infix and extension functions

This assignment uses:

```kotlin
infix fun String.startsWithLetter(letter: Char): Boolean
fun String.cleanWord(): String
fun Map<String, Int>.totalCharacters(): Int
fun WordInsight.describe(...): String
```

Example:

```kotlin
"Banana" startsWithLetter 'b'
```

### Immutable collections

The project uses immutable `List` and `Map` values throughout the analysis pipeline. Even `vararg` input is converted into an immutable `List`.

### Lambdas and higher-order functions

The rule system is built on lambdas:

```kotlin
data class PredicateWordRule(
    override val label: String,
    private val predicate: (String, Int) -> Boolean,
) : WordRule
```

The report functions also accept formatters and normalizers as higher-order parameters.

### `map`, `filter`, and `fold`

- `map` normalizes words
- `filter` keeps long words and rule matches
- `fold` calculates total character counts and finds the longest retained word

### Classes, inheritance, interfaces, data classes, and sealed classes

The project demonstrates all requested structures:

- `Vocabulary` is an open class
- `Heading` and `WordRule` are interfaces
- `WordBatch` and `PredicateWordRule` are data classes
- `WordInsight` is a sealed class

## Core Types

### `WordBatch`

Stores the label and immutable word list:

```kotlin
data class WordBatch(
    override val label: String,
    val words: List<String>,
) : Vocabulary(label), Heading
```

### `PredicateWordRule`

Turns a label and a lambda into a reusable rule object.

### `WordInsight`

Represents the outcome of a rule:

- `MatchSection` when matching words are found
- `EmptySection` when no words match

## Important Functions

### `buildWordLengthMap`

Creates the normalized `Map<String, Int>`:

```kotlin
fun buildWordLengthMap(
    words: List<String>,
    normalizer: (String) -> String = String::cleanWord,
): Map<String, Int>
```

### `filterWordsLongerThan`

Keeps only words whose length is greater than the chosen threshold.

### `buildVocabularyReport`

High-level report generator:

```kotlin
fun buildVocabularyReport(
    batch: WordBatch,
    minimumLengthExclusive: Int = 4,
    normalizer: (String) -> String = String::cleanWord,
    vararg rules: WordRule,
): String
```

## Example Output

```text
Vocabulary set: Mixed Vocabulary
Retained words: 3
Longest retained word: elephant (8)
Words starting with b -> banana has length 6 | totalCharacters=6
Words with at least 6 letters -> banana has length 6; elephant has length 8 | totalCharacters=14
apple has length 5
banana has length 6
elephant has length 8
```

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

## How To Run

From the `Assignment 2` folder:

```powershell
.\gradlew.bat run
```

## How To Test

```powershell
.\gradlew.bat test
```

## Test Coverage

The tests verify:

- normalized word-to-length map creation
- filtering with the default threshold
- the infix extension function
- structured rule analysis
- longest-word reporting

## Summary

Assignment 2 now demonstrates Kotlin collection processing and object modelling in a much more complete way. It preserves the original word-length idea while clearly implementing every required Kotlin concept in one cohesive project.
