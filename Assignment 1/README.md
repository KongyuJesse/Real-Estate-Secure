# Assignment 1: Number Processing Feature Showcase

This assignment started as a simple `processList` exercise and has been expanded into a richer number-processing console project. It still demonstrates filtering a list with a predicate, but it now also showcases the broader Kotlin language features you were asked to practice.

## What The Program Does

The program creates an immutable batch of numbers, transforms the values, filters them with reusable rules, and produces a readable report.

Sample flow:

1. create a `NumberBatch` with `vararg` inputs
2. square each number with a higher-order transformation
3. keep only values above a minimum threshold
4. evaluate multiple reusable rules
5. build a text report from the results

## Kotlin Features Implemented

- functions and expression bodies
- default and named arguments
- varargs
- infix and extension functions
- immutable collections
- lambdas and higher-order functions
- `map`, `filter`, and `fold`
- classes, inheritance, interfaces, data classes, and sealed classes

## Design Walkthrough

### 1. Functions and expression bodies

Several functions use Kotlin expression bodies for concise logic:

```kotlin
fun processList(numbers: List<Int>, predicate: (Int) -> Boolean): List<Int> =
    numbers.filter(predicate)

fun Int.squared(): Int = this * this
```

### 2. Default and named arguments

The project uses default values so functions stay flexible:

```kotlin
fun numberBatch(vararg values: Int, name: String = "Numbers"): NumberBatch

fun prepareValues(
    values: List<Int>,
    minimumValue: Int = 0,
    transformer: (Int) -> Int = { it },
): List<Int>
```

Named arguments are used in the codebase, for example:

```kotlin
val batch = numberBatch(1, 2, 3, 4, name = "Quarter Scores")
```

### 3. Varargs

`numberBatch` accepts any number of integers:

```kotlin
val batch = numberBatch(1, 2, 3, 4, 5, 6, name = "Quarter Scores")
```

### 4. Infix and extension functions

The assignment includes both:

```kotlin
infix fun Int.isMultipleOf(divisor: Int): Boolean
fun List<Int>.sumWithFold(): Int
fun BatchInsight.describe(): String
```

Example:

```kotlin
4 isMultipleOf 2
```

### 5. Immutable collections

The project relies on Kotlin immutable collection types such as `List` and arrays converted with `toList()`. The data class stores values in immutable lists instead of mutable ones.

### 6. Lambdas and higher-order functions

`processList`, `prepareValues`, and `renderLines` all accept function values:

```kotlin
fun processList(numbers: List<Int>, predicate: (Int) -> Boolean): List<Int>
fun <T> List<T>.renderLines(transform: (T) -> String): String
```

The program passes lambdas and function references like `Int::squared`.

### 7. `map`, `filter`, and `fold`

These collection operators are central to the solution:

- `map` transforms numbers before analysis
- `filter` applies thresholds and reusable rules
- `fold` calculates totals through `sumWithFold`

### 8. Classes, inheritance, interfaces, data classes, and sealed classes

The object model is intentionally varied:

- `NumberCollection` is an open base class
- `Titled` and `NumberRule` are interfaces
- `NumberBatch` and `PredicateRule` are data classes
- `BatchInsight` is a sealed class with typed result variants

## Important Types And Functions

### `NumberBatch`

Represents a named immutable set of numbers.

```kotlin
data class NumberBatch(
    override val name: String,
    val values: List<Int>,
) : NumberCollection(name), Titled
```

### `PredicateRule`

Wraps a label and a predicate lambda into a reusable rule object.

### `BatchInsight`

Represents either:

- a successful rule match with values, total, and average
- a no-match result

### `buildBatchReport`

The high-level orchestration function:

```kotlin
fun buildBatchReport(
    batch: NumberBatch,
    minimumValue: Int = 0,
    transformer: (Int) -> Int = { it },
    vararg rules: NumberRule,
): String
```

It prepares values, analyzes them with reusable rules, and formats the final output.

## Example Output

```text
Number batch: Quarter Scores
Prepared values: 4, 9, 16, 25, 36, 49, 64
Prepared total: 203
Even numbers -> values=4, 16, 36, 64, total=120, average=30.0
Values above 20 -> values=25, 36, 49, 64, total=174, average=43.5
Multiples of three -> values=9, 36, total=45, average=22.5
```

## File Structure

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

## How To Run

From the `Assignment 1` folder:

```powershell
.\gradlew.bat run
```

## How To Test

```powershell
.\gradlew.bat test
```

## Test Coverage

The test suite verifies:

- filtering with the original `processList` idea
- transformation and threshold handling
- rule-based analysis with folded totals
- report output when no values match a rule

## Summary

Assignment 1 is now more than a basic filter function. It is a complete Kotlin feature showcase built around number processing, with a stronger domain model, reusable rules, collection pipelines, and descriptive documentation.
