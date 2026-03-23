package com.example.gradecalculator.console

import java.nio.file.Path
import kotlin.math.max
import kotlin.math.roundToInt

data class BatchFailureDetail(
    val fileName: String,
    val message: String,
)

data class BatchGradeSummary(
    val inputDirectory: Path,
    val outputDirectory: Path,
    val scannedFiles: Int,
    val succeeded: Int,
    val failed: Int,
    val failures: List<BatchFailureDetail>,
)

object ConsoleExperience {
    private const val width = 78

    fun helpScreen(usage: String): String = buildString {
        appendLine(rule('='))
        appendLine(center("GRADE CALCULATOR STUDIO"))
        appendLine(center("Professional Excel grading from the CLI or desktop UI"))
        appendLine(rule('='))
        appendLine()
        appendLine(usage)
    }.trimEnd()

    fun conceptsScreen(showcase: String): String = buildString {
        appendLine(rule('='))
        appendLine(center("KOTLIN FEATURE SHOWCASE"))
        appendLine(center("Assignment coverage built into the grade calculator project"))
        appendLine(rule('='))
        appendLine()
        appendLine(showcase)
    }.trimEnd()

    fun interactiveWelcome(): String = buildString {
        appendLine(rule('='))
        appendLine(center("GRADE CALCULATOR STUDIO"))
        appendLine(center("Interactive wizard for workbook generation and grading"))
        appendLine(rule('='))
        appendLine()
        appendLine("Use the menu below to generate sample spreadsheets, grade workbooks,")
        appendLine("process entire folders, open the desktop UI, or review the Kotlin showcase.")
    }.trimEnd()

    fun interactiveMenu(): String = """
        1. Generate a sample workbook
        2. Grade one workbook
        3. Grade an entire folder
        4. Launch desktop UI
        5. Show Kotlin concepts showcase
        6. Show CLI help
        7. Exit
    """.trimIndent()

    fun batchStart(fileCount: Int, inputDirectory: Path, outputDirectory: Path): String = buildString {
        appendLine(rule('-'))
        appendLine("BATCH GRADING STARTED")
        appendLine(rule('-'))
        appendLine(keyValue("Input folder", inputDirectory))
        appendLine(keyValue("Output folder", outputDirectory))
        appendLine(keyValue("Excel files discovered", fileCount))
    }.trimEnd()

    fun batchProgress(success: Boolean, inputFile: Path, detail: String): String {
        val status = if (success) "[OK]" else "[FAILED]"
        return "$status ${inputFile.fileName} - $detail"
    }

    fun gradeResult(result: GradeRunResult): String = buildString {
        appendLine(rule('='))
        appendLine(center("GRADING COMPLETE"))
        appendLine(rule('='))
        appendLine(keyValue("Input", result.inputPath))
        appendLine(keyValue("Output", result.outputPath))
        appendLine(keyValue("Sheet", result.sheetName))
        appendLine(keyValue("Processed rows", result.processedRows))
        appendLine(keyValue("Skipped empty rows", result.skippedEmptyRows))
        appendLine(keyValue("Skipped rows without scores", result.skippedNoScoreRows))
        appendLine(keyValue("Negative marks corrected", result.negativeMarksCorrected))
        appendLine(keyValue("Percentages clamped", result.percentagesClampedAbove100))
        appendLine(keyValue("Maximum total used", formatDouble(result.maxTotalUsed)))
        appendLine()
        appendLine("Grade distribution")
        appendLine(rule('-'))
        append(distribution(result.gradeDistribution))
    }.trimEnd()

    fun generateResult(result: GenerateRunResult): String = buildString {
        appendLine(rule('='))
        appendLine(center("WORKBOOK GENERATED"))
        appendLine(rule('='))
        appendLine(keyValue("Output", result.outputPath))
        appendLine(keyValue("Sheet", result.sheetName))
        appendLine(keyValue("Student rows", result.students))
        appendLine(keyValue("Subjects", result.subjects.joinToString(", ")))
    }.trimEnd()

    fun batchSummary(summary: BatchGradeSummary): String = buildString {
        appendLine(rule('='))
        appendLine(center("BATCH GRADING COMPLETE"))
        appendLine(rule('='))
        appendLine(keyValue("Input folder", summary.inputDirectory))
        appendLine(keyValue("Output folder", summary.outputDirectory))
        appendLine(keyValue("Files scanned", summary.scannedFiles))
        appendLine(keyValue("Succeeded", summary.succeeded))
        appendLine(keyValue("Failed", summary.failed))
        if (summary.failures.isNotEmpty()) {
            appendLine()
            appendLine("Failure details")
            appendLine(rule('-'))
            summary.failures.forEach { failure ->
                appendLine("- ${failure.fileName}: ${failure.message}")
            }
        }
    }.trimEnd()

    fun error(message: String): String = buildString {
        appendLine(rule('!'))
        appendLine(center("REQUEST COULD NOT BE COMPLETED"))
        appendLine(rule('!'))
        appendLine(message)
        appendLine()
        appendLine("Tip: run the 'help' command to review the supported workflows and flags.")
    }.trimEnd()

    private fun distribution(distribution: Map<String, Int>): String {
        if (distribution.isEmpty()) return "(no grades assigned)"
        val maxCount = max(distribution.values.maxOrNull() ?: 0, 1)
        return distribution.entries.joinToString(separator = "\n") { (grade, count) ->
            val barLength = max((count * 24.0 / maxCount).roundToInt(), if (count > 0) 1 else 0)
            val bar = "#".repeat(barLength).padEnd(24, '.')
            "${grade.padEnd(2)} | $bar $count"
        }
    }

    private fun keyValue(label: String, value: Any): String =
        label.padEnd(28, ' ') + ": $value"

    private fun center(text: String): String {
        if (text.length >= width) return text
        val padding = (width - text.length) / 2
        return " ".repeat(padding) + text
    }

    private fun rule(char: Char): String = char.toString().repeat(width)

    private fun formatDouble(value: Double): String = "%.2f".format(value)
}

object DesktopPresentation {
    fun gradePlaceholder(): String = page(
        title = "Grade Workbooks With Confidence",
        subtitle = "Choose an Excel workbook, review the available sheets, and generate a polished graded copy.",
        content = bulletList(
            listOf(
                "Automatically detects header rows and score columns.",
                "Adds or reuses Total, Percentage, and Grade columns.",
                "Highlights grade distribution, corrections, and processed row counts.",
            ),
        ),
    )

    fun generatePlaceholder(): String = page(
        title = "Generate Training And Demo Data",
        subtitle = "Build clean sample workbooks for demos, practice, QA, or classroom walkthroughs.",
        content = bulletList(
            listOf(
                "Create realistic student names and numeric marks.",
                "Control sheet name, subject list, totals, seed, and mark range.",
                "Produce ready-to-grade Excel files in one step.",
            ),
        ),
    )

    fun workbookPreview(inputPath: Path, sheets: List<String>, suggestedOutput: Path): String {
        val sheetItems = if (sheets.isEmpty()) {
            "<li>No readable worksheets were detected yet.</li>"
        } else {
            sheets.joinToString(separator = "") { sheet -> "<li>${escape(sheet)}</li>" }
        }

        return page(
            title = "Workbook Ready",
            subtitle = "The file was inspected successfully. Review the sheet list and suggested output path below.",
            content =
                metricTable(
                    listOf(
                        "Workbook" to escape(inputPath.toString()),
                        "Suggested output" to escape(suggestedOutput.toString()),
                        "Sheets detected" to sheets.size.toString(),
                    ),
                ) +
                    "<h3>Available sheets</h3><ul>$sheetItems</ul>",
        )
    }

    fun gradeResult(result: GradeRunResult): String = page(
        title = "Grading Completed Successfully",
        subtitle = "Your graded workbook is ready, along with a processing summary and grade distribution.",
        content =
            metricTable(
                listOf(
                    "Input" to escape(result.inputPath.toString()),
                    "Output" to escape(result.outputPath.toString()),
                    "Sheet" to escape(result.sheetName),
                    "Processed rows" to result.processedRows.toString(),
                    "Skipped empty rows" to result.skippedEmptyRows.toString(),
                    "Skipped rows without scores" to result.skippedNoScoreRows.toString(),
                    "Negative marks corrected" to result.negativeMarksCorrected.toString(),
                    "Percentages clamped" to result.percentagesClampedAbove100.toString(),
                    "Maximum total used" to "%.2f".format(result.maxTotalUsed),
                ),
            ) +
                "<h3>Grade distribution</h3>${distributionTable(result.gradeDistribution)}",
    )

    fun generateResult(result: GenerateRunResult): String = page(
        title = "Workbook Generated",
        subtitle = "The sample sheet has been created and is ready for grading, demos, or verification.",
        content =
            metricTable(
                listOf(
                    "Output" to escape(result.outputPath.toString()),
                    "Sheet" to escape(result.sheetName),
                    "Student rows" to result.students.toString(),
                    "Subjects" to escape(result.subjects.joinToString(", ")),
                ),
            ),
    )

    fun message(title: String, subtitle: String, points: List<String>): String = page(
        title = title,
        subtitle = subtitle,
        content = bulletList(points),
    )

    fun error(title: String, message: String): String = page(
        title = title,
        subtitle = "The request could not be completed. Review the message below and try again.",
        content = "<p><b>Error:</b> ${escape(message)}</p>",
    )

    private fun page(title: String, subtitle: String, content: String): String = """
        <html>
          <body style="font-family: Segoe UI, Arial, sans-serif; background-color: #F8F4ED; color: #1D2935; margin: 0; padding: 18px;">
            <h1 style="margin: 0 0 10px 0; color: #163452;">${escape(title)}</h1>
            <p style="margin: 0 0 16px 0; color: #54606C;">${escape(subtitle)}</p>
            $content
          </body>
        </html>
    """.trimIndent()

    private fun metricTable(rows: List<Pair<String, String>>): String {
        val renderedRows = rows.joinToString(separator = "") { (label, value) ->
            """
            <tr>
              <td style="padding: 6px 10px 6px 0;"><b>${escape(label)}</b></td>
              <td style="padding: 6px 0;">$value</td>
            </tr>
            """.trimIndent()
        }
        return "<table cellpadding='0' cellspacing='0'>$renderedRows</table>"
    }

    private fun bulletList(points: List<String>): String {
        val items = points.joinToString(separator = "") { point ->
            "<li>${escape(point)}</li>"
        }
        return "<ul>$items</ul>"
    }

    private fun distributionTable(distribution: Map<String, Int>): String {
        if (distribution.isEmpty()) {
            return "<p>No grades were assigned.</p>"
        }
        val rows = distribution.entries.joinToString(separator = "") { (grade, count) ->
            """
            <tr>
              <td style="padding: 6px 16px 6px 0;"><b>${escape(grade)}</b></td>
              <td style="padding: 6px 0;">$count</td>
            </tr>
            """.trimIndent()
        }
        return "<table cellpadding='0' cellspacing='0'>$rows</table>"
    }

    private fun escape(value: String): String = buildString(value.length) {
        value.forEach { character ->
            append(
                when (character) {
                    '&' -> "&amp;"
                    '<' -> "&lt;"
                    '>' -> "&gt;"
                    '"' -> "&quot;"
                    '\'' -> "&#39;"
                    else -> character
                },
            )
        }
    }
}
