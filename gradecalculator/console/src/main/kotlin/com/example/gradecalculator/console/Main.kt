package com.example.gradecalculator.console

import java.nio.file.Files
import java.nio.file.InvalidPathException
import java.nio.file.Path
import java.nio.file.Paths
import java.util.Comparator
import java.util.stream.Collectors
import kotlin.io.path.extension
import kotlin.io.path.nameWithoutExtension
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    try {
        when (val command = Cli.parse(args)) {
            HelpCommand -> {
                println(Cli.usage())
                exitProcess(0)
            }
            DesktopUiCommand -> {
                DesktopApp.launch()
            }
            ConceptsCommand -> {
                println(KotlinFeatureShowcase.asConsoleText())
                exitProcess(0)
            }
            InteractiveCommand -> {
                runInteractiveMode()
                exitProcess(0)
            }
            is GenerateCommand -> {
                val resolved = withResolvedGenerateOutputPath(command)
                val result = RandomSheetGenerator().generate(resolved)
                println("Random sheet generated successfully.")
                println("Output: ${result.outputPath}")
                println("Sheet: ${result.sheetName}")
                println("Students: ${result.students}")
                println("Subjects: ${result.subjects.joinToString(", ")}")
            }
            is GradeCommand -> {
                runGradeFlow(command)
            }
        }
    } catch (exception: Throwable) {
        System.err.println("Error: ${exception.message}")
        System.err.println()
        System.err.println(Cli.usage())
        exitProcess(1)
    }
}

private fun runGradeFlow(command: GradeCommand) {
    require(Files.exists(command.inputPath)) { "Input path not found: ${command.inputPath}" }
    val grader = ExcelGrader()
    if (Files.isDirectory(command.inputPath)) {
        runBatchDirectoryGrading(grader, command)
        return
    }

    val resolvedCommand = withResolvedGradeOutputPath(command, command.inputPath)
    val result = grader.grade(resolvedCommand)
    printSingleGradeResult(result)
}

private fun runBatchDirectoryGrading(grader: ExcelGrader, command: GradeCommand) {
    require(command.outputPath == null) {
        "When --input is a folder, use --output-dir (or --choose-folder) instead of --output."
    }
    val outputDirectory = resolveGradeOutputDirectory(command, command.inputPath)
    val files = collectExcelFiles(command.inputPath, command.recursive)
    require(files.isNotEmpty()) {
        "No Excel files (.xlsx or .xls) found in folder: ${command.inputPath}"
    }

    var successCount = 0
    var failedCount = 0
    val failures = mutableListOf<String>()
    println("Found ${files.size} Excel file(s). Starting grading...")
    for (inputFile in files) {
        val outputFile = outputDirectory.resolve(derivedGradedFileName(inputFile))
        val fileCommand = command.copy(
            inputPath = inputFile,
            outputPath = outputFile,
            outputDirectory = null,
            chooseFolderInteractive = false,
        )
        try {
            val result = grader.grade(fileCommand)
            successCount += 1
            println("[OK] ${result.inputPath.fileName} -> ${result.outputPath}")
            println("     Processed rows: ${result.processedRows}, skipped empty: ${result.skippedEmptyRows}, skipped no-scores: ${result.skippedNoScoreRows}")
        } catch (error: Throwable) {
            failedCount += 1
            failures += "${inputFile.fileName}: ${error.message}"
            println("[FAILED] ${inputFile.fileName}: ${error.message}")
        }
    }

    println()
    println("Batch grading completed.")
    println("Input folder: ${command.inputPath}")
    println("Output folder: $outputDirectory")
    println("Succeeded: $successCount")
    println("Failed: $failedCount")
    if (failures.isNotEmpty()) {
        println("Failure details:")
        failures.forEach { println("  - $it") }
    }
}

private fun printSingleGradeResult(result: GradeRunResult) {
    println("Grading completed successfully.")
    println("Input: ${result.inputPath}")
    println("Output: ${result.outputPath}")
    println("Sheet: ${result.sheetName}")
    println("Processed rows: ${result.processedRows}")
    println("Skipped empty rows: ${result.skippedEmptyRows}")
    println("Skipped rows without valid scores: ${result.skippedNoScoreRows}")
    println("Negative marks corrected to 0: ${result.negativeMarksCorrected}")
    println("Percentages clamped to 100: ${result.percentagesClampedAbove100}")
    println("Max total used: ${"%.2f".format(result.maxTotalUsed)}")
    println("Grade distribution:")
    if (result.gradeDistribution.isEmpty()) {
        println("  (no grades assigned)")
    } else {
        result.gradeDistribution.forEach { (grade, count) ->
            println("  $grade: $count")
        }
    }
}

private fun withResolvedGradeOutputPath(command: GradeCommand, inputFile: Path): GradeCommand {
    val outputDirectory = resolveGradeOutputDirectory(command, inputFile)
    val outputFileName = command.outputPath?.fileName?.toString() ?: derivedGradedFileName(inputFile)
    return command.copy(
        outputPath = outputDirectory.resolve(outputFileName),
        outputDirectory = null,
        chooseFolderInteractive = false,
    )
}

private fun resolveGradeOutputDirectory(command: GradeCommand, inputPath: Path): Path {
    val fromOutputPath = command.outputPath?.parent
    val defaultDirectory = command.outputDirectory
        ?: fromOutputPath
        ?: if (Files.isDirectory(inputPath)) inputPath else (inputPath.parent ?: Paths.get("."))

    val selected = if (command.chooseFolderInteractive || (command.outputDirectory == null && command.outputPath == null)) {
        promptForDirectory(defaultDirectory, "graded Excel files")
    } else {
        defaultDirectory
    }
    Files.createDirectories(selected)
    return selected
}

private fun withResolvedGenerateOutputPath(command: GenerateCommand): GenerateCommand {
    if (command.outputDirectory == null && !command.chooseFolderInteractive) {
        return command
    }
    val defaultDirectory = command.outputDirectory ?: (command.outputPath.parent ?: Paths.get("."))
    val selected = if (command.chooseFolderInteractive) {
        promptForDirectory(defaultDirectory, "generated Excel files")
    } else {
        defaultDirectory
    }
    Files.createDirectories(selected)
    return command.copy(outputPath = selected.resolve(command.outputPath.fileName.toString()), outputDirectory = null, chooseFolderInteractive = false)
}

private fun promptForDirectory(defaultDirectory: Path, description: String): Path {
    println("Choose output folder for $description.")
    println("Press Enter to use default: $defaultDirectory")
    print("Folder path: ")
    val entered = readConsoleLineOrFail().trim()
    if (entered.isBlank()) return defaultDirectory
    return Paths.get(entered)
}

private fun collectExcelFiles(inputFolder: Path, recursive: Boolean): List<Path> {
    val sequence = if (recursive) Files.walk(inputFolder) else Files.list(inputFolder)
    sequence.use { stream ->
        return stream
            .filter { Files.isRegularFile(it) }
            .filter { path ->
                val ext = path.extension.lowercase()
                ext == "xlsx" || ext == "xls"
            }
            .sorted(Comparator.comparing { it.toString().lowercase() })
            .collect(Collectors.toList())
    }
}

fun derivedGradedFileName(inputFile: Path): String {
    val ext = inputFile.extension.ifBlank { "xlsx" }
    return "${inputFile.nameWithoutExtension}_graded.$ext"
}

private fun runInteractiveMode() {
    println("Grade Calculator Interactive Mode")
    println("Choose an option:")
    while (true) {
        println()
        println("1) Generate a sample Excel sheet")
        println("2) Grade an Excel sheet")
        println("3) Launch desktop UI")
        println("4) Show CLI help")
        println("5) Exit")
        when (promptMenuChoice(1, 5, 1)) {
            1 -> runInteractiveGenerate()
            2 -> runInteractiveSingleFileGrade()
            3 -> DesktopApp.launch()
            4 -> println(Cli.usage())
            5 -> return
        }
    }
}

private fun runInteractiveSingleFileGrade() {
    println()
    println("Grade Excel Sheet")
    val inputFile = promptExistingPath("Enter Excel file path", requireDirectory = false)
    val sheetSelector = promptSheetSelection(inputFile)
    val outputChoice = promptGradedOutputChoice(inputFile)

    val command = GradeCommand(
        inputPath = inputFile,
        outputPath = outputChoice.outputPath,
        outputDirectory = null,
        chooseFolderInteractive = false,
        recursive = false,
        sheetSelector = sheetSelector,
        headerRowNumber = null,
        maxTotal = null,
        totalColumnHint = null,
        percentageColumnName = "Percentage",
        gradeColumnName = "Grade",
        overwrite = outputChoice.overwrite,
    )

    runGradeFlow(command)
}

private fun runInteractiveGenerate() {
    println()
    println("Generate Sample Excel Sheet")
    val outputPathText = promptText("Output file path", "random_students.xlsx")
    val students = promptPositiveInt("Number of students", defaultValue = 30)
    val subjectsRaw = promptText("Subjects (comma-separated)", "Math,English,Physics,Chemistry,Biology")
    val subjects = subjectsRaw.split(",").map { it.trim() }.filter { it.isNotEmpty() }
    val outputPath = Paths.get(outputPathText)
    val overwrite = if (Files.exists(outputPath)) {
        promptYesNo("Output already exists. Replace it? (y/N)", defaultYes = false)
    } else {
        false
    }

    val command = GenerateCommand(
        outputPath = outputPath,
        outputDirectory = null,
        chooseFolderInteractive = false,
        students = students,
        subjects = if (subjects.isEmpty()) listOf("Math", "English", "Physics", "Chemistry", "Biology") else subjects,
        sheetName = "Students",
        includeTotalColumn = true,
        seed = null,
        minMark = 35.0,
        maxMark = 100.0,
        overwrite = overwrite,
    )

    val result = RandomSheetGenerator().generate(command)
    println("Random sheet generated successfully.")
    println("Output: ${result.outputPath}")
    println("Sheet: ${result.sheetName}")
    println("Students: ${result.students}")
    println("Subjects: ${result.subjects.joinToString(", ")}")
}

private fun promptSheetSelection(inputFile: Path): String? {
    val sheetNames = try {
        listSheetNames(inputFile)
    } catch (_: Throwable) {
        emptyList()
    }
    if (sheetNames.size <= 1) return null

    println("Select a sheet to grade:")
    println("0) Auto-detect sheet")
    sheetNames.forEachIndexed { index, sheetName ->
        println("${index + 1}) $sheetName")
    }

    val choice = promptMenuChoice(0, sheetNames.size, 0)
    return if (choice == 0) null else sheetNames[choice - 1]
}

private fun promptGradedOutputChoice(inputFile: Path): InteractiveOutputChoice {
    val defaultOutputPath = inputFile.resolveSibling(derivedGradedFileName(inputFile))
    while (true) {
        val keepDefault = promptYesNo(
            "Keep default graded file name '${defaultOutputPath.fileName}'? (Y/n)",
            defaultYes = true,
        )
        val chosenPath = if (keepDefault) {
            defaultOutputPath
        } else {
            val entered = promptText("New output file name or path", defaultOutputPath.fileName.toString())
            val typedPath = Paths.get(entered)
            if (typedPath.isAbsolute) typedPath else defaultOutputPath.parent.resolve(typedPath)
        }

        if (!Files.exists(chosenPath)) {
            return InteractiveOutputChoice(chosenPath, overwrite = false)
        }

        if (promptYesNo("Output already exists. Replace it? (y/N)", defaultYes = false)) {
            return InteractiveOutputChoice(chosenPath, overwrite = true)
        }

        println("Choose a different output file name.")
    }
}

private fun promptMenuChoice(min: Int, max: Int, defaultValue: Int): Int {
    while (true) {
        print("Select option [$defaultValue]: ")
        val value = readConsoleLineOrFail().trim()
        if (value.isBlank()) return defaultValue
        val parsed = value.toIntOrNull()
        if (parsed != null && parsed in min..max) return parsed
        println("Please enter a number between $min and $max.")
    }
}

private fun promptExistingPath(prompt: String, requireDirectory: Boolean): Path {
    while (true) {
        print("$prompt: ")
        val input = readConsoleLineOrFail().trim()
        if (input.isBlank()) {
            println("This value is required.")
            continue
        }
        val path = try {
            Paths.get(input)
        } catch (_: InvalidPathException) {
            println("Invalid path. Please try again.")
            continue
        }
        if (!Files.exists(path)) {
            println("Path does not exist: $path")
            continue
        }
        if (requireDirectory && !Files.isDirectory(path)) {
            println("Expected a folder path.")
            continue
        }
        if (!requireDirectory && !Files.isRegularFile(path)) {
            println("Expected a file path.")
            continue
        }
        return path
    }
}

private fun promptDirectoryPath(prompt: String, defaultPath: Path): Path {
    while (true) {
        print("$prompt: ")
        val input = readConsoleLineOrFail().trim()
        val chosen = if (input.isBlank()) {
            defaultPath
        } else {
            try {
                Paths.get(input)
            } catch (_: InvalidPathException) {
                println("Invalid path. Please try again.")
                continue
            }
        }
        return chosen
    }
}

private fun promptText(prompt: String, defaultValue: String): String {
    print("$prompt [$defaultValue]: ")
    val input = readConsoleLineOrFail().trim()
    return if (input.isBlank()) defaultValue else input
}

private fun promptOptionalText(prompt: String): String? {
    print("$prompt: ")
    val input = readConsoleLineOrFail().trim()
    return input.ifBlank { null }
}

private fun promptYesNo(prompt: String, defaultYes: Boolean): Boolean {
    while (true) {
        print("$prompt ")
        val input = readConsoleLineOrFail().trim().lowercase()
        if (input.isBlank()) return defaultYes
        when (input) {
            "y", "yes", "true", "1" -> return true
            "n", "no", "false", "0" -> return false
            else -> println("Please enter y or n.")
        }
    }
}

private fun promptOptionalPositiveInt(prompt: String): Int? {
    while (true) {
        print("$prompt: ")
        val input = readConsoleLineOrFail().trim()
        if (input.isBlank()) return null
        val parsed = input.toIntOrNull()
        if (parsed != null && parsed > 0) return parsed
        println("Enter a whole number greater than 0, or press Enter to skip.")
    }
}

private fun promptOptionalLong(prompt: String): Long? {
    while (true) {
        print("$prompt: ")
        val input = readConsoleLineOrFail().trim()
        if (input.isBlank()) return null
        val parsed = input.toLongOrNull()
        if (parsed != null) return parsed
        println("Enter a valid whole number, or press Enter to skip.")
    }
}

private fun promptOptionalPositiveDouble(prompt: String): Double? {
    while (true) {
        print("$prompt: ")
        val input = readConsoleLineOrFail().trim()
        if (input.isBlank()) return null
        val parsed = input.toDoubleOrNull()
        if (parsed != null && parsed > 0.0) return parsed
        println("Enter a number greater than 0, or press Enter to skip.")
    }
}

private fun promptPositiveInt(prompt: String, defaultValue: Int): Int {
    while (true) {
        print("$prompt [$defaultValue]: ")
        val input = readConsoleLineOrFail().trim()
        if (input.isBlank()) return defaultValue
        val parsed = input.toIntOrNull()
        if (parsed != null && parsed > 0) return parsed
        println("Enter a whole number greater than 0.")
    }
}

private fun promptPositiveDouble(prompt: String, defaultValue: Double, strictlyGreaterThan: Double? = null): Double {
    while (true) {
        print("$prompt [$defaultValue]: ")
        val input = readConsoleLineOrFail().trim()
        val value = if (input.isBlank()) defaultValue else input.toDoubleOrNull()
        if (value == null) {
            println("Enter a valid number.")
            continue
        }
        if (value <= 0.0) {
            println("Enter a number greater than 0.")
            continue
        }
        if (strictlyGreaterThan != null && value <= strictlyGreaterThan) {
            println("Value must be greater than $strictlyGreaterThan.")
            continue
        }
        return value
    }
}

private fun readConsoleLineOrFail(): String {
    return readlnOrNull()
        ?: throw IllegalStateException(
            "No interactive input stream is available. " +
                "Run this from a normal terminal, or use non-interactive CLI flags like " +
                "`grade --input ... --output ...` or `generate --output ...`."
        )
}

private data class InteractiveOutputChoice(
    val outputPath: Path,
    val overwrite: Boolean,
)
