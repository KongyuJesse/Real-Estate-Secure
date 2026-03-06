package com.example.gradecalculator.console

import org.apache.poi.ss.usermodel.WorkbookFactory
import java.nio.file.Files
import java.nio.file.Path

fun listSheetNames(inputPath: Path): List<String> {
    require(Files.exists(inputPath)) { "Input path not found: $inputPath" }
    require(Files.isRegularFile(inputPath)) { "Input path is not a file: $inputPath" }

    Files.newInputStream(inputPath).use { input ->
        WorkbookFactory.create(input).use { workbook ->
            return (0 until workbook.numberOfSheets).map { workbook.getSheetName(it) }
        }
    }
}

