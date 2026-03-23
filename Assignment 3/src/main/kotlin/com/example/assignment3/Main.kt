package com.example.assignment3

import java.util.Locale

interface AgeAware {
    val age: Int

    fun lifeStage(): String = if (age >= 18) "adult" else "minor"
}

open class CommunityMember(open val name: String)

data class Person(
    override val name: String,
    override val age: Int,
    val city: String = "Unknown",
) : CommunityMember(name), AgeAware

sealed class AgeReport {
    data class MatchedGroup(
        val initials: Set<Char>,
        val people: List<Person>,
        val averageAge: Double,
        val cityCounts: Map<String, Int>,
    ) : AgeReport()

    data class NoMatches(val initials: Set<Char>) : AgeReport()
}

fun people(vararg members: Person): List<Person> = members.toList()

infix fun String.startsWithAny(initials: Set<Char>): Boolean {
    val first = firstOrNull()?.uppercaseChar() ?: return false
    val normalizedInitials = initials.map { it.uppercaseChar() }.toSet()
    return first in normalizedInitials
}

fun filterPeopleByInitials(
    people: List<Person>,
    initials: Set<Char> = setOf('A', 'B'),
): List<Person> = people.filter { person ->
    person.name startsWithAny initials
}

fun extractAges(people: List<Person>): List<Int> = people.map(Person::age)

fun calculateAverageAge(ages: List<Int>): Double? =
    ages.takeIf { it.isNotEmpty() }?.fold(0) { total, age -> total + age }?.let { total ->
        total / ages.size.toDouble()
    }

fun List<Person>.averageAgeOrNull(): Double? = calculateAverageAge(extractAges(this))

fun formatAverageAge(averageAge: Double): String =
    String.format(Locale.US, "%.1f", averageAge)

fun summarizeByCity(
    people: List<Person>,
    selector: (Person) -> Boolean = { true },
): Map<String, Int> = people
    .filter(selector)
    .fold(emptyMap()) { counts, person ->
        counts + (person.city to ((counts[person.city] ?: 0) + 1))
    }

fun analyzePeople(
    people: List<Person>,
    initials: Set<Char> = setOf('A', 'B'),
    selector: (Person) -> Boolean = { true },
): AgeReport {
    val matchingPeople = filterPeopleByInitials(people, initials).filter(selector)
    val averageAge = matchingPeople.averageAgeOrNull() ?: return AgeReport.NoMatches(initials)

    return AgeReport.MatchedGroup(
        initials = initials,
        people = matchingPeople,
        averageAge = averageAge,
        cityCounts = summarizeByCity(matchingPeople),
    )
}

fun AgeReport.describe(): String = when (this) {
    is AgeReport.MatchedGroup -> {
        val initialsLabel = initials.map { it.uppercaseChar() }.sorted().joinToString(", ")
        val matchingNames = people.joinToString { "${it.name} (${it.lifeStage()})" }
        val cities = cityCounts.entries.joinToString { (city, count) -> "$city=$count" }
        "Average age for initials $initialsLabel: ${formatAverageAge(averageAge)} | " +
            "People: $matchingNames | Cities: $cities"
    }
    is AgeReport.NoMatches -> {
        val initialsLabel = initials.map { it.uppercaseChar() }.sorted().joinToString(", ")
        "No people matched the initials $initialsLabel."
    }
}

fun buildAverageAgeMessage(
    people: List<Person>,
    initials: Set<Char> = setOf('A', 'B'),
    selector: (Person) -> Boolean = { true },
): String = analyzePeople(
    people = people,
    initials = initials,
    selector = selector,
).describe()

fun main() {
    val roster = people(
        Person("Alice", 25, "Lagos"),
        Person("Bob", 30, "Abuja"),
        Person("Charlie", 35, "Lagos"),
        Person("Anna", 22, "Ibadan"),
        Person("Ben", 28, "Abuja"),
        Person("Aisha", 17, "Lagos"),
    )

    val message = buildAverageAgeMessage(
        people = roster,
        initials = setOf('A', 'B'),
        selector = { person -> person.age >= 18 },
    )

    println(message)
}
