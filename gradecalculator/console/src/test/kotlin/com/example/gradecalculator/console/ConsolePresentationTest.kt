package com.example.gradecalculator.console

import kotlin.io.path.Path
import kotlin.test.Test
import kotlin.test.assertTrue

class ConsolePresentationTest {
    @Test
    fun `formats single grade result with the expected sections`() {
        val text = ConsoleExperience.gradeResult(
            GradeRunResult(
                inputPath = Path("students.xlsx"),
                outputPath = Path("students_graded.xlsx"),
                sheetName = "Class A",
                processedRows = 24,
                maxTotalUsed = 300.0,
                skippedEmptyRows = 1,
                skippedNoScoreRows = 2,
                negativeMarksCorrected = 0,
                percentagesClampedAbove100 = 0,
                gradeDistribution = linkedMapOf("A" to 6, "B+" to 8, "C" to 10),
            ),
        )

        assertTrue(text.contains("GRADING COMPLETE"))
        assertTrue(text.contains("Processed rows"))
        assertTrue(text.contains("Grade distribution"))
        assertTrue(text.contains("A"))
    }

    @Test
    fun `formats batch summary with failure details`() {
        val text = ConsoleExperience.batchSummary(
            BatchGradeSummary(
                inputDirectory = Path("raw"),
                outputDirectory = Path("graded"),
                scannedFiles = 3,
                succeeded = 2,
                failed = 1,
                failures = listOf(BatchFailureDetail("bad.xlsx", "Could not detect a header row.")),
            ),
        )

        assertTrue(text.contains("BATCH GRADING COMPLETE"))
        assertTrue(text.contains("bad.xlsx"))
        assertTrue(text.contains("Could not detect a header row."))
    }
}
