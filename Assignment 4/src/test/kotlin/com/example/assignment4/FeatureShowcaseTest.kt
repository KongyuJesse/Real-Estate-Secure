package com.example.assignment4

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class FeatureShowcaseTest {
    @Test
    fun `maxOf returns the maximum int`() {
        assertEquals(9, maxOf(listOf(3, 7, 2, 9)))
    }

    @Test
    fun `maxOf returns the maximum string`() {
        assertEquals("kiwi", maxOf(listOf("apple", "banana", "kiwi")))
    }

    @Test
    fun `maxOf returns null for empty list`() {
        assertNull(maxOf(emptyList<Int>()))
    }

    @Test
    fun `averageOrNull returns null for empty scores`() {
        assertNull(emptyList<Int>().averageOrNull())
    }

    @Test
    fun `selectStudents filters by initials and custom selector`() {
        val result = selectStudents(
            students(
                Student("Alice", scores(85, 90)),
                Student("Bob", scores(70, 65)),
                Student("Charlie", scores(50, 45)),
                Student("Ben", scores()),
            ),
            initials = setOf('A', 'B'),
            selector = { student -> student.scores.isNotEmpty() },
        )

        assertEquals(
            listOf(
                Student("Alice", scores(85, 90)),
                Student("Bob", scores(70, 65)),
            ),
            result,
        )
    }

    @Test
    fun `classifyStudent uses the pass threshold`() {
        val student = Student("Ada", scores(80, 70, 90))

        val result = classifyStudent(student, passThreshold = 75.0)

        assertEquals(
            GradeResult.Passed(80.0),
            result,
        )
    }

    @Test
    fun `buildStudentReport includes formatted student results and the top average`() {
        val result = buildStudentReport(
            students = students(
                Student("Alice", scores(85, 90, 88)),
                Student("Bob", scores(70, 65, 72)),
                Student("Ben", scores()),
            ),
            initials = setOf('A', 'B'),
            passThreshold = 75.0,
        )

        assertEquals(
            "Alice: passed with 87.7\n" +
                "Bob: failed with 69.0\n" +
                "Ben: no scores\n" +
                "Top average: 87.7",
            result,
        )
    }
}
