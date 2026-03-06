package com.example.gradecalculator.console

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class CliTest {
    @Test
    fun `defaults to interactive mode when no args are provided`() {
        assertEquals(InteractiveCommand, Cli.parse(emptyArray()))
    }

    @Test
    fun `parses desktop and concepts commands`() {
        assertEquals(DesktopUiCommand, Cli.parse(arrayOf("ui")))
        assertEquals(ConceptsCommand, Cli.parse(arrayOf("concepts")))
        assertEquals(ConceptsCommand, Cli.parse(arrayOf("syntax")))
    }

    @Test
    fun `parses grade command with named options`() {
        val command = Cli.parse(
            arrayOf(
                "grade",
                "--input",
                "students.xlsx",
                "--output",
                "students_graded.xlsx",
                "--percentage-column",
                "Pct",
                "--grade-column",
                "Letter",
            ),
        )

        val gradeCommand = assertIs<GradeCommand>(command)
        assertEquals("Pct", gradeCommand.percentageColumnName)
        assertEquals("Letter", gradeCommand.gradeColumnName)
    }
}
