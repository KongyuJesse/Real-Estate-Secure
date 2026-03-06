package com.example.gradecalculator.console

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class KotlinConceptsTest {
    @Test
    fun `supports vararg and expression-body functions`() {
        assertEquals(60.0, sumScores(10.0, 20.0, 30.0))
    }

    @Test
    fun `supports infix and extension helpers`() {
        val percentage = 75.0 percentOf 100.0
        assertEquals(75.0, percentage)
        assertEquals(listOf(0.0, 50.0, 100.0), listOf(-4.0, 50.0, 120.0).normalizeScores())
    }

    @Test
    fun `supports higher-order processing and fold distribution`() {
        val values = processScores(
            scores = listOf(10.0, 45.0, 90.0),
            transform = { it * 1.1 },
            predicate = { it >= 40.0 },
        )
        assertEquals(listOf(49.5, 99.0), values.map { it.roundTo(1) })

        val distribution = distributionByFold(listOf("A", "B", "A", "C", "B"))
        assertEquals(2, distribution["A"])
        assertEquals(2, distribution["B"])
        assertEquals(1, distribution["C"])
    }

    @Test
    fun `builds feature showcase with immutable collections and oop model`() {
        val report = KotlinFeatureShowcase.buildReport(
            studentName = "Test User",
            maxTotal = 300.0,
            100.0,
            90.0,
            80.0,
        )

        assertTrue(report.student is PersonRecord)
        assertTrue(report.outcome is EvaluationOutcome.Processed)
        assertEquals(3, report.immutableList.size)
        assertTrue(report.immutableSet.contains("kotlin"))
        assertEquals(3, report.immutableMap.size)
        assertTrue(report.syntaxComparisons.isNotEmpty())
    }
}
