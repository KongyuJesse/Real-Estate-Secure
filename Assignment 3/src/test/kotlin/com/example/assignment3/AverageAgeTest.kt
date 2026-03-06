package com.example.assignment3

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class AverageAgeTest {
    private val people = listOf(
        Person("Alice", 25),
        Person("Bob", 30),
        Person("Charlie", 35),
        Person("Anna", 22),
        Person("Ben", 28),
    )

    @Test
    fun `filters only people whose names start with A or B`() {
        val result = filterPeopleByInitials(people)

        assertEquals(
            listOf(
                Person("Alice", 25),
                Person("Bob", 30),
                Person("Anna", 22),
                Person("Ben", 28),
            ),
            result,
        )
    }

    @Test
    fun `extracts ages from matching people`() {
        val filteredPeople = filterPeopleByInitials(people)

        val result = extractAges(filteredPeople)

        assertEquals(listOf(25, 30, 22, 28), result)
    }

    @Test
    fun `calculates the average age`() {
        val result = calculateAverageAge(listOf(25, 30, 22, 28))

        assertEquals(26.25, result)
    }

    @Test
    fun `formats the average age to one decimal place`() {
        assertEquals("26.3", formatAverageAge(26.25))
    }

    @Test
    fun `returns null when there are no ages to average`() {
        assertNull(calculateAverageAge(emptyList()))
    }

    @Test
    fun `builds the final message`() {
        val result = buildAverageAgeMessage(people)

        assertEquals("Average age for names starting with A or B: 26.3", result)
    }
}

