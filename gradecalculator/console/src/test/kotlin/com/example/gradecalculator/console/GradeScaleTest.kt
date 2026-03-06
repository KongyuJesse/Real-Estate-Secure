package com.example.gradecalculator.console

import kotlin.test.Test
import kotlin.test.assertEquals

class GradeScaleTest {
    private val scale = GradeScale.defaultUsPlusMinus()

    @Test
    fun `returns expected letter grade at key boundaries`() {
        assertEquals("A+", scale.gradeFor(100.0))
        assertEquals("A+", scale.gradeFor(97.0))
        assertEquals("A", scale.gradeFor(96.9))
        assertEquals("A-", scale.gradeFor(90.0))
        assertEquals("B+", scale.gradeFor(87.0))
        assertEquals("B", scale.gradeFor(83.0))
        assertEquals("C+", scale.gradeFor(77.0))
        assertEquals("C", scale.gradeFor(73.0))
        assertEquals("D-", scale.gradeFor(60.0))
        assertEquals("F", scale.gradeFor(59.9))
    }
}
