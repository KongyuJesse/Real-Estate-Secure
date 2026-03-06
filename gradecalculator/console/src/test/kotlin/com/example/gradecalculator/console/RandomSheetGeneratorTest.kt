package com.example.gradecalculator.console

import org.apache.poi.ss.usermodel.WorkbookFactory
import kotlin.io.path.createTempDirectory
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class RandomSheetGeneratorTest {
    @Test
    fun `generates workbook with requested student count`() {
        val tempDir = createTempDirectory("gradecalc-generate")
        val outputPath = tempDir.resolve("random")

        val command = GenerateCommand(
            outputPath = outputPath,
            outputDirectory = null,
            chooseFolderInteractive = false,
            students = 12,
            subjects = listOf("Math", "English", "Physics"),
            sheetName = "Students",
            includeTotalColumn = true,
            seed = 42L,
            minMark = 40.0,
            maxMark = 100.0,
            overwrite = true,
        )

        val result = RandomSheetGenerator().generate(command)
        assertTrue(result.outputPath.toString().endsWith(".xlsx"))

        WorkbookFactory.create(result.outputPath.toFile()).use { workbook ->
            val sheet = workbook.getSheet("Students")
            assertEquals(13, sheet.physicalNumberOfRows)
            val header = sheet.getRow(0)
            assertEquals("Student ID", header.getCell(0).stringCellValue)
            assertEquals("Student Name", header.getCell(1).stringCellValue)
            assertEquals("Total", header.getCell(5).stringCellValue)
        }
    }
}
