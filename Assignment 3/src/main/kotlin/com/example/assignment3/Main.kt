package com.example.assignment3

import java.util.Locale

data class Person(val name: String, val age: Int)

fun filterPeopleByInitials(
    people: List<Person>,
    initials: Set<Char> = setOf('A', 'B'),
): List<Person> {
    val normalizedInitials = initials.map { it.uppercaseChar() }.toSet()
    return people.filter { person ->
        person.name.firstOrNull()?.uppercaseChar() in normalizedInitials
    }
}

fun extractAges(people: List<Person>): List<Int> = people.map { it.age }

fun calculateAverageAge(ages: List<Int>): Double? =
    ages.takeIf { it.isNotEmpty() }?.average()

fun formatAverageAge(averageAge: Double): String =
    String.format(Locale.US, "%.1f", averageAge)

fun buildAverageAgeMessage(
    people: List<Person>,
    initials: Set<Char> = setOf('A', 'B'),
): String {
    val matchingPeople = filterPeopleByInitials(people, initials)
    val ages = extractAges(matchingPeople)
    val averageAge = calculateAverageAge(ages)

    return if (averageAge == null) {
        "No people matched the selected initials."
    } else {
        "Average age for names starting with A or B: ${formatAverageAge(averageAge)}"
    }
}

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

