# Assignment 3: Average Age Console Project

This project is a Kotlin console application that works with a list of people, keeps only names that begin with `A` or `B`, calculates their average age, and prints the result rounded to one decimal place.

## Project Goal

The program processes a list of `Person` objects in four steps:

1. filter people whose names begin with `A` or `B`
2. extract their ages
3. calculate the average age
4. format the result to one decimal place and print it

Sample data used in `main`:

```kotlin
val people = listOf(
    Person("Alice", 25),
    Person("Bob", 30),
    Person("Charlie", 35),
    Person("Anna", 22),
    Person("Ben", 28),
)
```

Matching people:

- Alice
- Bob
- Anna
- Ben

Average calculation:

- total age = `25 + 30 + 22 + 28 = 105`
- number of matching people = `4`
- average age = `105 / 4 = 26.25`
- rounded to one decimal place = `26.3`

Console output:

```text
Average age for names starting with A or B: 26.3
```

## What This Project Contains

- a standalone Kotlin/JVM console project
- a `Person` data class
- filtering logic for names starting with selected initials
- age extraction logic
- average-age calculation logic
- one-decimal-place formatting
- unit tests for the main behavior
- a Gradle wrapper so the project can run without a global Gradle installation

## Project Structure

```text
Assignment 3/
|-- build.gradle.kts
|-- gradle.properties
|-- gradlew
|-- gradlew.bat
|-- settings.gradle.kts
|-- README.md
|-- src/
|   |-- main/
|   |   `-- kotlin/com/example/assignment3/Main.kt
|   `-- test/
|       `-- kotlin/com/example/assignment3/AverageAgeTest.kt
`-- gradle/wrapper/
    |-- gradle-wrapper.jar
    `-- gradle-wrapper.properties
```

## How the Program Works

The program is broken into small functions:

- `filterPeopleByInitials(people, initials)`: keeps only people whose names start with one of the chosen letters
- `extractAges(people)`: converts a list of people into a list of ages
- `calculateAverageAge(ages)`: computes the average age and returns `null` if the list is empty
- `formatAverageAge(averageAge)`: rounds and formats the result to one decimal place
- `buildAverageAgeMessage(people, initials)`: produces the final printable message

Main flow:

```kotlin
fun main() {
    val people = listOf(
        Person("Alice", 25),
        Person("Bob", 30),
        Person("Charlie", 35),
        Person("Anna", 22),
        Person("Ben", 28),
    )

    println(buildAverageAgeMessage(people))
}
```

## Source Code Summary

Data model:

```kotlin
data class Person(val name: String, val age: Int)
```

Filtering logic:

```kotlin
fun filterPeopleByInitials(
    people: List<Person>,
    initials: Set<Char> = setOf('A', 'B'),
): List<Person>
```

Average calculation:

```kotlin
fun calculateAverageAge(ages: List<Int>): Double? =
    ages.takeIf { it.isNotEmpty() }?.average()
```

Formatting:

```kotlin
fun formatAverageAge(averageAge: Double): String =
    String.format(Locale.US, "%.1f", averageAge)
```

## User Guide

### Prerequisites

- Java JDK 24 installed
- Windows PowerShell if you want to use `gradlew.bat`

This project uses:

- Gradle `8.14.4`
- Kotlin Gradle plugin `2.2.21`

### Run the program

From the `Assignment 3` folder:

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

1. Open the `Assignment 3` folder as a project.
2. Let Gradle sync finish.
3. Run `Main.kt` to see the console output.
4. Run `AverageAgeTest.kt` to execute the tests.

## Example Processing Walkthrough

Starting list:

```kotlin
listOf(
    Person("Alice", 25),
    Person("Bob", 30),
    Person("Charlie", 35),
    Person("Anna", 22),
    Person("Ben", 28),
)
```

After filtering by initials `A` and `B`:

```kotlin
listOf(
    Person("Alice", 25),
    Person("Bob", 30),
    Person("Anna", 22),
    Person("Ben", 28),
)
```

Extracted ages:

```kotlin
listOf(25, 30, 22, 28)
```

Computed average:

```kotlin
26.25
```

Formatted value:

```text
26.3
```

## How to Change the Data

You can edit the list in `main`:

```kotlin
val people = listOf(
    Person("Ada", 20),
    Person("Brian", 27),
    Person("Clara", 31),
)
```

You can also change the initials:

```kotlin
val message = buildAverageAgeMessage(people, setOf('C', 'D'))
```

## Test Coverage

The tests verify:

- filtering names that start with `A` or `B`
- extracting ages from the filtered list
- calculating the average age
- formatting to one decimal place
- handling empty input for averaging
- building the final output message

## Summary

This project demonstrates list filtering, mapping, average calculation, and numeric formatting in a small Kotlin console application.

## Collaboration

For changes in this folder, use a short-lived branch from `main`, for example `docs/assignment-3-readme-update` or `feat/assignment-3-improvement`.

Before opening a pull request:

- keep the change scoped to `Assignment 3/` whenever possible
- run `.\gradlew.bat test`
- open the pull request into `main`
