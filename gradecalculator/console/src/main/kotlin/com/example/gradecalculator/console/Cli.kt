package com.example.gradecalculator.console

import java.nio.file.Path
import kotlin.io.path.Path

sealed interface Command

data object HelpCommand : Command
data object InteractiveCommand : Command
data object DesktopUiCommand : Command
data object ConceptsCommand : Command

data class GradeCommand(
    val inputPath: Path,
    val outputPath: Path?,
    val outputDirectory: Path?,
    val chooseFolderInteractive: Boolean,
    val recursive: Boolean,
    val sheetSelector: String?,
    val headerRowNumber: Int?,
    val maxTotal: Double?,
    val totalColumnHint: String?,
    val percentageColumnName: String,
    val gradeColumnName: String,
    val overwrite: Boolean,
) : Command

data class GenerateCommand(
    val outputPath: Path,
    val outputDirectory: Path?,
    val chooseFolderInteractive: Boolean,
    val students: Int,
    val subjects: List<String>,
    val sheetName: String,
    val includeTotalColumn: Boolean,
    val seed: Long?,
    val minMark: Double,
    val maxMark: Double,
    val overwrite: Boolean,
) : Command

object Cli {
    fun parse(args: Array<String>): Command {
        if (args.isEmpty()) return InteractiveCommand
        val command = args.first().lowercase()
        val options = parseOptions(args.drop(1))
        return when (command) {
            "help", "--help", "-h" -> HelpCommand
            "interactive", "wizard" -> InteractiveCommand
            "ui", "desktop", "--ui" -> DesktopUiCommand
            "concepts", "syntax", "comparison" -> ConceptsCommand
            "grade" -> parseGradeCommand(options)
            "generate" -> parseGenerateCommand(options)
            else -> throw IllegalArgumentException("Unknown command '$command'. Use 'help' to view usage.")
        }
    }

    fun usage(): String = """
        Grade Calculator Console (Kotlin)

        Commands:
          interactive / wizard  Launch interactive option picker (recommended).
          ui / desktop          Launch desktop application mode (Swing UI).
          concepts / syntax     Show Kotlin feature showcase and Kotlin syntax/concept comparison.
          grade     Read an Excel sheet, compute totals/percentages, and write letter grades.
          generate  Generate a random student marks Excel sheet.

        Grade command:
          grade --input <path> [--output <path>] [--output-dir <folder>] [--choose-folder]
                [--recursive] [--sheet <sheetNameOrIndex>]
                [--header-row <1-based-number>] [--max-total <number>]
                [--total-column <columnName>] [--percentage-column <columnName>]
                [--grade-column <columnName>] [--overwrite]

        Generate command:
          generate [--output <path>] [--output-dir <folder>] [--choose-folder]
                   [--students <number>] [--subjects <comma-separated>]
                   [--sheet-name <name>] [--include-total <true|false>]
                   [--seed <number>] [--min-mark <number>] [--max-mark <number>] [--overwrite]

        Examples:
          interactive
          wizard
          ui
          concepts
          grade --input "C:\data\students.xlsx"
          grade --input "C:\data\raw-marks" --output-dir "C:\data\graded" --recursive
          grade --input "C:\data\students.xlsx" --sheet "Class A" --output "C:\data\students_graded.xlsx"
          generate --output "C:\data\random_students.xlsx" --students 120 --subjects "Math,English,Physics"
    """.trimIndent()

    private fun parseGradeCommand(options: Map<String, String>): GradeCommand {
        val inputRaw = options["input"] ?: throw IllegalArgumentException("Missing required option --input for grade command.")
        val inputPath = Path(inputRaw)
        val outputPath = options["output"]?.let { Path(it) }
        val outputDirectory = options["output-dir"]?.let { Path(it) }
        if (outputPath != null && outputDirectory != null) {
            throw IllegalArgumentException("Use either --output or --output-dir, not both.")
        }
        val headerRowNumber = options["header-row"]?.toIntOrNull()?.also {
            require(it > 0) { "--header-row must be >= 1." }
        }
        val maxTotal = options["max-total"]?.toDoubleOrNull()?.also {
            require(it > 0) { "--max-total must be greater than 0." }
        }
        return GradeCommand(
            inputPath = inputPath,
            outputPath = outputPath,
            outputDirectory = outputDirectory,
            chooseFolderInteractive = options["choose-folder"].toBooleanWithDefaultFalse(),
            recursive = options["recursive"].toBooleanWithDefaultFalse(),
            sheetSelector = options["sheet"],
            headerRowNumber = headerRowNumber,
            maxTotal = maxTotal,
            totalColumnHint = options["total-column"],
            percentageColumnName = options["percentage-column"]?.ifBlank { "Percentage" } ?: "Percentage",
            gradeColumnName = options["grade-column"]?.ifBlank { "Grade" } ?: "Grade",
            overwrite = options["overwrite"].toBooleanWithDefaultFalse(),
        )
    }

    private fun parseGenerateCommand(options: Map<String, String>): GenerateCommand {
        if (options["output"] != null && options["output-dir"] != null) {
            throw IllegalArgumentException("Use either --output or --output-dir, not both.")
        }
        val students = options["students"]?.toIntOrNull() ?: 30
        require(students > 0) { "--students must be greater than 0." }

        val subjects = options["subjects"]
            ?.split(",")
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?.takeIf { it.isNotEmpty() }
            ?: listOf("Math", "English", "Physics", "Chemistry", "Biology")

        val minMark = options["min-mark"]?.toDoubleOrNull() ?: 35.0
        val maxMark = options["max-mark"]?.toDoubleOrNull() ?: 100.0
        require(minMark >= 0.0) { "--min-mark must be >= 0." }
        require(maxMark > minMark) { "--max-mark must be greater than --min-mark." }

        return GenerateCommand(
            outputPath = Path(options["output"] ?: "random_students.xlsx"),
            outputDirectory = options["output-dir"]?.let { Path(it) },
            chooseFolderInteractive = options["choose-folder"].toBooleanWithDefaultFalse(),
            students = students,
            subjects = subjects,
            sheetName = options["sheet-name"]?.ifBlank { "Students" } ?: "Students",
            includeTotalColumn = options["include-total"].toBooleanWithDefaultTrue(),
            seed = options["seed"]?.toLongOrNull(),
            minMark = minMark,
            maxMark = maxMark,
            overwrite = options["overwrite"].toBooleanWithDefaultFalse(),
        )
    }

    private fun parseOptions(rawOptions: List<String>): Map<String, String> {
        if (rawOptions.isEmpty()) return emptyMap()
        val parsed = linkedMapOf<String, String>()
        var index = 0
        while (index < rawOptions.size) {
            val token = rawOptions[index]
            require(token.startsWith("--")) {
                "Unexpected token '$token'. Options must start with '--'."
            }
            val key = token.removePrefix("--")
            require(key.isNotBlank()) { "Invalid empty option name." }
            val value = if (index + 1 < rawOptions.size && !rawOptions[index + 1].startsWith("--")) {
                rawOptions[index + 1].also { index += 1 }
            } else {
                "true"
            }
            parsed[key] = value
            index += 1
        }
        return parsed
    }

    private fun String?.toBooleanWithDefaultFalse(): Boolean {
        if (this == null) return false
        return when (lowercase()) {
            "true", "1", "yes", "y" -> true
            "false", "0", "no", "n" -> false
            else -> false
        }
    }

    private fun String?.toBooleanWithDefaultTrue(): Boolean {
        if (this == null) return true
        return when (lowercase()) {
            "true", "1", "yes", "y" -> true
            "false", "0", "no", "n" -> false
            else -> true
        }
    }
}
