# Assignment 5: Logger Delegation Showcase

This project is a Kotlin console application that implements a simple logging system using class delegation and demonstrates core Kotlin features such as extension functions, sealed classes, and collection operations.

## Project Goal

The project focuses on:

- a `Logger` interface with console and file logger implementations
- a delegated `Application` class that forwards logging calls
- default and named arguments
- varargs
- infix and extension functions
- immutable collections
- lambdas and higher-order functions
- `map`, `filter`, and `fold`
- classes, inheritance, interfaces, data classes, and sealed classes

## What This Project Contains

- a standalone Kotlin/JVM console project
- a `Logger` interface plus `ConsoleLogger` and `FileLogger`
- a delegated `Application` class using `Logger by logger`
- a logging domain model using data classes and a sealed class
- list filtering, mapping, and folding for summaries
- unit tests for delegation and formatting
- a Gradle wrapper so the project can run without a global Gradle installation

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

## Key Classes

Logger interface and delegation:

```kotlin
interface Logger {
    fun log(message: String)
}

class Application(
    override val name: String = "App",
    private val logger: Logger,
) : Component(name), Logger by logger
```

Log event model:

```kotlin
sealed class LogEvent {
    data class Info(val message: String) : LogEvent()
    data class Error(val message: String) : LogEvent()
    data class Debug(val message: String) : LogEvent()
}
```

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

## User Guide

### Prerequisites

- Java JDK 24 installed
- Windows PowerShell if you want to use `gradlew.bat`

This project uses:

- Gradle `8.14.4`
- Kotlin Gradle plugin `2.2.21`

### Run the program

From the `Assignment 5` folder:

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

1. Open the `Assignment 5` folder as a project.
2. Let Gradle sync finish.
3. Run `Main.kt` to see the console output.
4. Run `LoggerDelegationTest.kt` to execute the tests.

## Summary

This assignment shows how to use Kotlin delegation for logging while practicing core language features and collection operations.
