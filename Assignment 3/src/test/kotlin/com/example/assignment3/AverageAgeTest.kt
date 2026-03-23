package com.example.assignment3

import kotlin.test.Test
import kotlin.test.assertEquals

class AverageAgeTest {
    private val roster = people(
        Person("Alice", 25, "Lagos"),
        Person("Bob", 30, "Abuja"),
        Person("Charlie", 35, "Lagos"),
        Person("Anna", 22, "Ibadan"),
        Person("Ben", 28, "Abuja"),
        Person("Aisha", 17, "Lagos"),
    )

    @Test
    fun `filters only people whose names start with A or B`() {
        val result = filterPeopleByInitials(roster)

        assertEquals(
            listOf(
                Person("Alice", 25, "Lagos"),
                Person("Bob", 30, "Abuja"),
                Person("Anna", 22, "Ibadan"),
                Person("Ben", 28, "Abuja"),
                Person("Aisha", 17, "Lagos"),
            ),
            result,
        )
    }

    @Test
    fun `extracts ages from matching people`() {
        val filteredPeople = filterPeopleByInitials(roster)

        val result = extractAges(filteredPeople)

        assertEquals(listOf(25, 30, 22, 28, 17), result)
    }

    @Test
    fun `calculates the average age`() {
        val result = calculateAverageAge(listOf(25, 30, 22, 28))

        assertEquals(26.25, result)
    }

    @Test
    fun `summarizeByCity counts selected people with fold`() {
        val result = summarizeByCity(roster) { person ->
            person.name startsWithAny setOf('A', 'B') && person.age >= 18
        }

        assertEquals(
            mapOf(
                "Lagos" to 1,
                "Abuja" to 2,
                "Ibadan" to 1,
            ),
            result,
        )
    }

    @Test
    fun `analyzePeople returns a structured report for adult matches`() {
        val result = analyzePeople(
            people = roster,
            initials = setOf('A', 'B'),
            selector = { it.age >= 18 },
        )

        assertEquals(
            AgeReport.MatchedGroup(
                initials = setOf('A', 'B'),
                people = listOf(
                    Person("Alice", 25, "Lagos"),
                    Person("Bob", 30, "Abuja"),
                    Person("Anna", 22, "Ibadan"),
                    Person("Ben", 28, "Abuja"),
                ),
                averageAge = 26.25,
                cityCounts = mapOf(
                    "Lagos" to 1,
                    "Abuja" to 2,
                    "Ibadan" to 1,
                ),
            ),
            result,
        )
    }

    @Test
    fun `buildAverageAgeMessage handles no matches`() {
        val result = buildAverageAgeMessage(roster, initials = setOf('Z'))

        assertEquals("No people matched the initials Z.", result)
    }
}
