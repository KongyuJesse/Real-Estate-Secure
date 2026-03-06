package com.example.gradecalculator.console

import org.apache.poi.ss.usermodel.WorkbookFactory
import org.apache.poi.xssf.usermodel.XSSFWorkbook
import java.nio.file.Files
import kotlin.io.path.createTempDirectory
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

class ExcelGraderTest {
    @Test
    fun `grades workbook and appends grade columns`() {
        val tempDir = createTempDirectory("gradecalc-test")
        val inputPath = tempDir.resolve("students.xlsx")
        val outputPath = tempDir.resolve("students_graded.xlsx")

        XSSFWorkbook().use { workbook ->
            val sheet = workbook.createSheet("Class A")
            val header = sheet.createRow(0)
            header.createCell(0).setCellValue("Student ID")
            header.createCell(1).setCellValue("Student Name")
            header.createCell(2).setCellValue("Math")
            header.createCell(3).setCellValue("English")

            val alice = sheet.createRow(1)
            alice.createCell(0).setCellValue("STU-0001")
            alice.createCell(1).setCellValue("Alice Johnson")
            alice.createCell(2).setCellValue(95.0)
            alice.createCell(3).setCellValue(90.0)

            val bob = sheet.createRow(2)
            bob.createCell(0).setCellValue("STU-0002")
            bob.createCell(1).setCellValue("Bob Williams")
            bob.createCell(2).setCellValue(70.0)
            bob.createCell(3).setCellValue(60.0)

            Files.newOutputStream(inputPath).use { workbook.write(it) }
        }

        val command = GradeCommand(
            inputPath = inputPath,
            outputPath = outputPath,
            outputDirectory = null,
            chooseFolderInteractive = false,
            recursive = false,
            sheetSelector = "Class A",
            headerRowNumber = 1,
            maxTotal = null,
            totalColumnHint = null,
            percentageColumnName = "Percentage",
            gradeColumnName = "Grade",
            overwrite = true,
        )

        val result = ExcelGrader().grade(command)
        assertEquals(2, result.processedRows)
        assertEquals(200.0, result.maxTotalUsed)
        assertEquals(0, result.skippedEmptyRows)
        assertEquals(0, result.skippedNoScoreRows)
        assertEquals(0, result.negativeMarksCorrected)
        assertEquals(0, result.percentagesClampedAbove100)
        assertEquals(1, result.gradeDistribution["A-"])
        assertEquals(1, result.gradeDistribution["D"])

        WorkbookFactory.create(outputPath.toFile()).use { workbook ->
            val sheet = workbook.getSheet("Class A")
            assertNotNull(sheet)

            val header = sheet.getRow(0)
            assertEquals("Total", header.getCell(4).stringCellValue)
            assertEquals("Percentage", header.getCell(5).stringCellValue)
            assertEquals("Grade", header.getCell(6).stringCellValue)

            val firstStudent = sheet.getRow(1)
            assertEquals(185.0, firstStudent.getCell(4).numericCellValue)
            assertEquals("A-", firstStudent.getCell(6).stringCellValue)

            val secondStudent = sheet.getRow(2)
            assertEquals(130.0, secondStudent.getCell(4).numericCellValue)
            assertEquals("D", secondStudent.getCell(6).stringCellValue)
        }
    }

    @Test
    fun `corrects negative marks and clamps percentage above 100`() {
        val tempDir = createTempDirectory("gradecalc-test-edge")
        val inputPath = tempDir.resolve("students_edge.xlsx")
        val outputPath = tempDir.resolve("students_edge_graded.xlsx")

        XSSFWorkbook().use { workbook ->
            val sheet = workbook.createSheet("Sheet1")
            val header = sheet.createRow(0)
            header.createCell(0).setCellValue("Student")
            header.createCell(1).setCellValue("Math")
            header.createCell(2).setCellValue("English")

            val first = sheet.createRow(1)
            first.createCell(0).setCellValue("Low")
            first.createCell(1).setCellValue(-15.0)
            first.createCell(2).setCellValue(40.0)

            val second = sheet.createRow(2)
            second.createCell(0).setCellValue("High")
            second.createCell(1).setCellValue(120.0)
            second.createCell(2).setCellValue(120.0)

            Files.newOutputStream(inputPath).use { workbook.write(it) }
        }

        val command = GradeCommand(
            inputPath = inputPath,
            outputPath = outputPath,
            outputDirectory = null,
            chooseFolderInteractive = false,
            recursive = false,
            sheetSelector = "Sheet1",
            headerRowNumber = 1,
            maxTotal = 200.0,
            totalColumnHint = null,
            percentageColumnName = "Percentage",
            gradeColumnName = "Grade",
            overwrite = true,
        )

        val result = ExcelGrader().grade(command)
        assertEquals(2, result.processedRows)
        assertEquals(1, result.negativeMarksCorrected)
        assertEquals(1, result.percentagesClampedAbove100)
        assertEquals(1, result.gradeDistribution["F"])
        assertEquals(1, result.gradeDistribution["A+"])
    }
}
