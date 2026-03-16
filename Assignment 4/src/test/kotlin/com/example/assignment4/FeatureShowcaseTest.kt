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
    fun `classifyStudent uses the pass threshold`() {
        val student = Student("Ada", scores(80, 70, 90))

        val result = classifyStudent(student, passThreshold = 75.0)

        assertEquals(
            GradeResult.Passed(80.0),
            result,
        )
    }
}
