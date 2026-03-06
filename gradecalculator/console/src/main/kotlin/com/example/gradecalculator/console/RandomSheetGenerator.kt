package com.example.gradecalculator.console

import org.apache.poi.hssf.usermodel.HSSFWorkbook
import org.apache.poi.ss.usermodel.Workbook
import org.apache.poi.xssf.usermodel.XSSFWorkbook
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardOpenOption
import kotlin.io.path.extension
import kotlin.math.round
import kotlin.random.Random

data class GenerateRunResult(
    val outputPath: Path,
    val sheetName: String,
    val students: Int,
    val subjects: List<String>,
)

class RandomSheetGenerator {
    private val firstNames = listOf(
        "Ava", "Liam", "Noah", "Emma", "Olivia", "Sophia", "Mason", "Isabella", "Lucas", "Amelia",
        "James", "Mia", "Benjamin", "Harper", "Elijah", "Evelyn", "Henry", "Abigail", "Alexander", "Ella"
    )
    private val lastNames = listOf(
        "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Wilson", "Taylor", "Anderson",
        "Thomas", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White", "Harris", "Clark"
    )

    fun generate(command: GenerateCommand): GenerateRunResult {
        require(command.subjects.isNotEmpty()) { "At least one subject is required." }

        val outputPath = ensureExtension(command.outputPath)
        ensureOutputPath(outputPath, command.overwrite)

        val random = command.seed?.let { Random(it) } ?: Random.Default
        createWorkbook(outputPath.extension).use { workbook ->
            val sheet = workbook.createSheet(command.sheetName)
            val headerRow = sheet.createRow(0)

            val headers = mutableListOf("Student ID", "Student Name")
            headers += command.subjects
            if (command.includeTotalColumn) {
                headers += "Total"
            }
            headers.forEachIndexed { index, value ->
                headerRow.createCell(index).setCellValue(value)
            }

            repeat(command.students) { index ->
                val row = sheet.createRow(index + 1)
                row.createCell(0).setCellValue("STU-${(index + 1).toString().padStart(4, '0')}")
                row.createCell(1).setCellValue(randomStudentName(random))

                var total = 0.0
                command.subjects.forEachIndexed { subjectOffset, _ ->
                    val mark = randomMark(command.minMark, command.maxMark, random)
                    total += mark
                    row.createCell(subjectOffset + 2).setCellValue(mark)
                }

                if (command.includeTotalColumn) {
                    row.createCell(command.subjects.size + 2).setCellValue(total)
                }
            }

            headers.indices.forEach { sheet.autoSizeColumn(it) }
            outputPath.parent?.let { Files.createDirectories(it) }
            Files.newOutputStream(outputPath, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE).use {
                workbook.write(it)
            }
        }

        return GenerateRunResult(
            outputPath = outputPath,
            sheetName = command.sheetName,
            students = command.students,
            subjects = command.subjects,
        )
    }

    private fun createWorkbook(extension: String): Workbook {
        return when (extension.lowercase()) {
            "xls" -> HSSFWorkbook()
            "xlsx" -> XSSFWorkbook()
            else -> XSSFWorkbook()
        }
    }

    private fun ensureExtension(path: Path): Path {
        val ext = path.extension.lowercase()
        return if (ext == "xlsx" || ext == "xls") path else path.resolveSibling("${path.fileName}.xlsx")
    }

    private fun ensureOutputPath(outputPath: Path, overwrite: Boolean) {
        if (Files.exists(outputPath) && !overwrite) {
            error("Output file already exists: $outputPath. Use --overwrite to replace it.")
        }
    }

    private fun randomStudentName(random: Random): String {
        val first = firstNames[random.nextInt(firstNames.size)]
        val last = lastNames[random.nextInt(lastNames.size)]
        return "$first $last"
    }

    private fun randomMark(min: Double, max: Double, random: Random): Double {
        val value = random.nextDouble(min, max)
        return round(value * 10.0) / 10.0
    }
}
