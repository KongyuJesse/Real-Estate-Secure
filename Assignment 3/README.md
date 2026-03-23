# Assignment 3: People And Average-Age Analysis

Assignment 3 has been expanded into a more complete people-analysis console project. It still calculates average age, but it now does so through a richer object model and a collection pipeline that explicitly demonstrates the Kotlin concepts requested for the assignment.

## What The Program Does

The program stores an immutable list of people, filters names by initials, optionally applies an additional selector, calculates the average age, groups matches by city, and prints a descriptive summary.

The main scenario in this assignment is:

1. create a roster with `vararg` input
2. keep only names beginning with chosen initials
3. apply an extra lambda filter such as `age >= 18`
4. extract ages and calculate the average
5. summarize the selected people by city
6. return a structured sealed result and convert it to a readable message

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
fun people(vararg members: Person): List<Person> = members.toList()

fun formatAverageAge(averageAge: Double): String =
    String.format(Locale.US, "%.1f", averageAge)
```

### Default and named arguments

The APIs are flexible because they provide default values:

```kotlin
fun filterPeopleByInitials(
    people: List<Person>,
    initials: Set<Char> = setOf('A', 'B'),
): List<Person>

fun buildAverageAgeMessage(
    people: List<Person>,
    initials: Set<Char> = setOf('A', 'B'),
    selector: (Person) -> Boolean = { true },
): String
```

Named arguments are used in the implementation and tests:

```kotlin
val message = buildAverageAgeMessage(
    people = roster,
    initials = setOf('A', 'B'),
    selector = { person -> person.age >= 18 },
)
```

### Varargs

The roster is built with:

```kotlin
val roster = people(
    Person("Alice", 25, "Lagos"),
    Person("Bob", 30, "Abuja"),
)
```

### Infix and extension functions

This assignment includes:

```kotlin
infix fun String.startsWithAny(initials: Set<Char>): Boolean
fun List<Person>.averageAgeOrNull(): Double?
fun AgeReport.describe(): String
```

Example:

```kotlin
"Alice" startsWithAny setOf('A', 'B')
```

### Immutable collections

The roster, filtered lists, and city summaries are all handled as immutable `List`, `Set`, and `Map` values.

### Lambdas and higher-order functions

The `selector` parameter allows callers to add custom filtering behavior:

```kotlin
selector: (Person) -> Boolean = { true }
```

This makes the project more reusable than a hard-coded age calculator.

### `map`, `filter`, and `fold`

- `filter` narrows the roster by initials and custom selection rules
- `map` extracts ages from people
- `fold` calculates totals and builds city-count maps

### Classes, inheritance, interfaces, data classes, and sealed classes

All requested type categories are present:

- `CommunityMember` is an open base class
- `AgeAware` is an interface
- `Person` is a data class
- `AgeReport` is a sealed class

## Important Types

### `Person`

Stores the person’s name, age, and city:

```kotlin
data class Person(
    override val name: String,
    override val age: Int,
    val city: String = "Unknown",
) : CommunityMember(name), AgeAware
```

### `AgeReport`

Represents either:

- a successful `MatchedGroup`
- a `NoMatches` result

This is useful because the program returns a structured result before converting it to a string.

## Important Functions

### `summarizeByCity`

Builds a city-count map using `fold`:

```kotlin
fun summarizeByCity(
    people: List<Person>,
    selector: (Person) -> Boolean = { true },
): Map<String, Int>
```

### `analyzePeople`

Returns an `AgeReport` object with the filtered people, average age, and city counts.

### `buildAverageAgeMessage`

Creates the final console message from the structured report.

## Example Output

```text
Average age for initials A, B: 26.3 | People: Alice (adult), Bob (adult), Anna (adult), Ben (adult) | Cities: Lagos=1, Abuja=2, Ibadan=1
```

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

## How To Run

From the `Assignment 3` folder:

```powershell
.\gradlew.bat run
```

## How To Test

```powershell
.\gradlew.bat test
```

## Test Coverage

The test suite checks:

- filtering by initials
- age extraction
- average calculation
- fold-based city summaries
- sealed-report generation
- no-match handling

## Summary

Assignment 3 is now a fuller Kotlin feature showcase built around a people domain. It keeps the original age-calculation goal, but upgrades it with better structure, richer outputs, and explicit use of every required Kotlin concept.
