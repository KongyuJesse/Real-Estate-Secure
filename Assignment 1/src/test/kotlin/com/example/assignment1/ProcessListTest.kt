package com.example.assignment1

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ProcessListTest {
    @Test
    fun `returns only even numbers`() {
        val nums = listOf(1, 2, 3, 4, 5, 6)

        val even = processList(nums) { it isMultipleOf 2 }

        assertEquals(listOf(2, 4, 6), even)
    }

    @Test
    fun `prepareValues applies the transformer and minimum value`() {
        val result = prepareValues(
            values = listOf(1, 2, 3, 4),
            minimumValue = 4,
            transformer = Int::squared,
        )

        assertEquals(listOf(4, 9, 16), result)
    }

    @Test
    fun `analyzeBatch builds grouped insights with fold based totals`() {
        val batch = numberBatch(1, 2, 3, 4, 5, 6, name = "Quiz Scores")

        val result = analyzeBatch(
            batch,
            4,
            { it * 2 },
            PredicateRule("Even numbers") { it isMultipleOf 2 },
            PredicateRule("Above ten") { it > 10 },
        )

        assertEquals(
            listOf(
                BatchInsight.MatchGroup(
                    label = "Even numbers",
                    values = listOf(4, 6, 8, 10, 12),
                    total = 40,
                    average = "8.0",
                ),
                BatchInsight.MatchGroup(
                    label = "Above ten",
                    values = listOf(12),
                    total = 12,
                    average = "12.0",
                ),
            ),
            result,
        )
    }

    @Test
    fun `buildBatchReport includes the no matches section`() {
        val report = buildBatchReport(
            numberBatch(1, 2, 3, name = "Small Batch"),
            5,
            { it },
            PredicateRule("Large values") { it > 10 },
        )

        assertTrue(report.contains("Large values -> no matches"))
    }
}
