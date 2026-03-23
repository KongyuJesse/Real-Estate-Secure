# Assignment 5: Logger Delegation And Log Analysis

Assignment 5 remains a logging-focused Kotlin console project, but it now has stronger structure, a dedicated `LogSummary` data class, clearer documentation, and fuller tests. It continues to be a good example of Kotlin class delegation while also covering the rest of the required language features.

## What The Program Does

The program creates loggers, routes log calls through a delegated `Application` class, formats log entries, filters error logs, summarizes the log stream, and prints a final report.

The main workflow is:

1. create applications with different logger implementations
2. build immutable `LogEntry` objects
3. format entries with extension and infix functions
4. filter out important error logs
5. summarize all logs with `fold`
6. send the finished report through delegated logging

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
infix fun String.taggedWith(tag: String): String = "[$tag] $this"

fun buildSummary(entries: List<LogEntry>): String = summarizeEntries(entries).format()
```

### Default and named arguments

The project uses defaults in several places:

```kotlin
class Application(
    override val name: String = "App",
    private val logger: Logger,
) : Component(name), Logger by logger

fun LogEntry.format(
    includeSource: Boolean = true,
    prefix: String = "",
): String
```

Named arguments are used when building applications and formatting entries.

### Varargs

Varargs are used for both log entry creation and multi-message logging:

```kotlin
val entries = logEntries(
    LogEntry("ConsoleApp", LogEvent.Info("App started")),
    LogEntry("ConsoleApp", LogEvent.Error("Error occurred")),
)

app.logAll(header, formattedLines, summary)
```

### Infix and extension functions

This assignment includes:

```kotlin
infix fun String.taggedWith(tag: String): String
fun LogEvent.label(): String
fun LogEvent.body(): String
fun LogEntry.format(...): String
fun LogSummary.format(): String
fun List<LogEntry>.formatLines(...): String
```

### Immutable collections

The log pipeline works with immutable `List` values and immutable data objects such as `LogEntry` and `LogSummary`.

### Lambdas and higher-order functions

`formatLines` accepts a transformation lambda:

```kotlin
fun List<LogEntry>.formatLines(
    transform: (LogEntry) -> String,
    separator: String = "\n",
): String
```

The project uses lambdas to define how each log entry should be rendered.

### `map`, `filter`, and `fold`

- `map` is used when formatting lines
- `filter` powers `selectErrors`
- `fold` powers `summarizeEntries`

### Classes, inheritance, interfaces, data classes, and sealed classes

All required structures are present:

- `Component` is an open base class
- `Logger` is an interface
- `LogEntry` and `LogSummary` are data classes
- `LogEvent` is a sealed class
- `Application` inherits from `Component` and delegates `Logger`

## Core Types

### `Application`

This class demonstrates Kotlin delegation:

```kotlin
class Application(
    override val name: String = "App",
    private val logger: Logger,
) : Component(name), Logger by logger
```

It inherits from `Component` and forwards `Logger` behavior to the provided logger instance.

### `LogSummary`

`LogSummary` stores the result of folding over the log entries:

```kotlin
data class LogSummary(
    val infoCount: Int = 0,
    val errorCount: Int = 0,
    val debugCount: Int = 0,
    val totalCharacters: Int = 0,
)
```

## Important Functions

### `summarizeEntries`

This function uses `fold` and `copy` to build a typed summary object:

```kotlin
fun summarizeEntries(entries: List<LogEntry>): LogSummary
```

### `buildSummary`

Converts the typed summary into the final output string.

### `selectErrors`

Filters the log stream to keep only error entries.

## Example Output

```text
App started
File: Error occurred
[SYSTEM] Log Report
>> ConsoleApp: [INFO] App started
>> ConsoleApp: [ERROR] Error occurred
>> FileApp: [DEBUG] Verbose mode enabled
Summary: info=1, error=1, debug=1, chars=45
Errors: [ERROR] Error occurred
```

## Project Structure

```text
Assignment 5/
|-- build.gradle.kts
|-- gradle.properties
|-- gradlew
|-- gradlew.bat
|-- settings.gradle.kts
|-- README.md
|-- src/
|   |-- main/
|   |   `-- kotlin/com/example/assignment5/Main.kt
|   `-- test/
|       `-- kotlin/com/example/assignment5/LoggerDelegationTest.kt
`-- gradle/wrapper/
    |-- gradle-wrapper.jar
    `-- gradle-wrapper.properties
```

## How To Run

From the `Assignment 5` folder:

```powershell
.\gradlew.bat run
```

## How To Test

```powershell
.\gradlew.bat test
```

## Test Coverage

The tests verify:

- delegation from `Application` to `Logger`
- log entry formatting
- error filtering
- typed summary generation
- final summary formatting

## Summary

Assignment 5 now gives you a cleaner and more descriptive logging showcase. It demonstrates Kotlin delegation, data modelling, collection pipelines, and every other requested feature in one cohesive example.
