package com.example.gradecalculator.console

import org.apache.poi.ss.usermodel.Cell
import org.apache.poi.ss.usermodel.CellStyle
import org.apache.poi.ss.usermodel.CellType
import org.apache.poi.ss.usermodel.DataFormatter
import org.apache.poi.ss.usermodel.FormulaEvaluator
import org.apache.poi.ss.usermodel.Row
import org.apache.poi.ss.usermodel.Sheet
import org.apache.poi.ss.usermodel.Workbook
import org.apache.poi.ss.usermodel.WorkbookFactory
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardOpenOption
import kotlin.io.path.extension
import kotlin.io.path.nameWithoutExtension

data class GradeRunResult(
    val inputPath: Path,
    val outputPath: Path,
    val sheetName: String,
    val processedRows: Int,
    val maxTotalUsed: Double,
    val skippedEmptyRows: Int,
    val skippedNoScoreRows: Int,
    val negativeMarksCorrected: Int,
    val percentagesClampedAbove100: Int,
    val gradeDistribution: Map<String, Int>,
)

class ExcelGrader(private val gradeScale: GradeScale = GradeScale.defaultUsPlusMinus()) {
    private val formatter = DataFormatter()
    private val metadataKeywords = setOf(
        "name", "student", "id", "registration", "reg", "roll", "matric", "email", "phone", "class", "section",
        "group", "remark", "remarks", "comment", "gender", "age"
    )
    private val totalKeywords = setOf("total", "sum", "overall", "aggregate")
    private val percentageKeywords = setOf("percent", "percentage")
    private val gradeKeywords = setOf("grade")
    private val typicalScoreCeilings = listOf(10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0, 60.0, 70.0, 75.0, 80.0, 90.0, 100.0)

    fun grade(command: GradeCommand): GradeRunResult {
        require(Files.exists(command.inputPath)) { "Input file not found: ${command.inputPath}" }
        require(Files.isRegularFile(command.inputPath)) { "Input path is not a file: ${command.inputPath}" }

        val outputPath = resolveOutputPath(command)
        Files.newInputStream(command.inputPath).use { input ->
            WorkbookFactory.create(input).use { workbook ->
                val evaluator = workbook.creationHelper.createFormulaEvaluator()
                val sheet = resolveSheet(workbook, command.sheetSelector)
                val headerRow = resolveHeaderRow(sheet, evaluator, command.headerRowNumber)

                val headers = collectHeaders(headerRow, evaluator)
                if (headers.isEmpty()) {
                    error("No header columns found in sheet '${sheet.sheetName}'.")
                }

                val detectedTotalColumn = resolveColumnIndex(headers, command.totalColumnHint, totalKeywords)
                val existingPercentageColumn = resolveColumnIndex(headers, null, percentageKeywords)
                val existingGradeColumn = resolveColumnIndex(headers, command.gradeColumnName, gradeKeywords)

                val markColumns = detectMarkColumns(
                    sheet = sheet,
                    headers = headers,
                    evaluator = evaluator,
                    ignoredColumns = setOfNotNull(detectedTotalColumn, existingPercentageColumn, existingGradeColumn),
                )

                if (markColumns.isEmpty() && detectedTotalColumn == null) {
                    error("Could not detect any mark columns or total column in sheet '${sheet.sheetName}'.")
                }

                val totalColumnIndex = detectedTotalColumn ?: appendColumn(headerRow, headers, command.totalColumnHint ?: "Total")
                val percentageColumnIndex = existingPercentageColumn ?: appendColumn(headerRow, headers, command.percentageColumnName)
                val gradeColumnIndex = existingGradeColumn ?: appendColumn(headerRow, headers, command.gradeColumnName)

                val maxTotal = resolveMaxTotal(command.maxTotal, sheet, headerRow.rowNum + 1, markColumns, totalColumnIndex, evaluator)

                val numericStyle = createNumericStyle(workbook, "0.00")
                val percentageStyle = createNumericStyle(workbook, "0.00")

                var processedRows = 0
                var skippedEmptyRows = 0
                var skippedNoScoreRows = 0
                var negativeMarksCorrected = 0
                var percentagesClampedAbove100 = 0
                val producedGrades = mutableListOf<String>()
                for (rowIndex in (headerRow.rowNum + 1)..sheet.lastRowNum) {
                    val row = sheet.getRow(rowIndex) ?: continue
                    if (isRowEffectivelyEmpty(row, headers.map { it.index })) {
                        skippedEmptyRows += 1
                        continue
                    }

                    val rawMarks = markColumns.mapNotNull { index ->
                        readNumericCell(row.getCell(index), evaluator)
                    }
                    val marks = processScores(
                        scores = rawMarks,
                        transform = { mark -> mark.coerceAtLeast(0.0) },
                    )
                    negativeMarksCorrected += rawMarks.count { it < 0.0 }
                    val totalFromMarks = marks.takeIf { it.isNotEmpty() }?.let { sumScores(*it.toDoubleArray()) }
                    val totalFromSheetRaw = readNumericCell(row.getCell(totalColumnIndex), evaluator)
                    val totalFromSheet = totalFromSheetRaw?.let { value ->
                        if (value < 0.0) {
                            negativeMarksCorrected += 1
                            0.0
                        } else {
                            value
                        }
                    }
                    if (totalFromMarks == null && totalFromSheet == null) {
                        skippedNoScoreRows += 1
                        continue
                    }
                    val total = totalFromMarks ?: totalFromSheet ?: continue

                    val rawPercentage = total percentOf maxTotal
                    val percentage = computePercentage(total = total, maxTotal = maxTotal)
                    if (rawPercentage > 100.0) {
                        percentagesClampedAbove100 += 1
                    }
                    val grade = gradeScale.gradeFor(percentage)
                    producedGrades += grade

                    writeNumericCell(row, totalColumnIndex, total, numericStyle)
                    writeNumericCell(row, percentageColumnIndex, percentage, percentageStyle)
                    writeTextCell(row, gradeColumnIndex, grade)
                    processedRows += 1
                }

                if (processedRows == 0) {
                    error("No student rows were processed in sheet '${sheet.sheetName}'.")
                }

                autosizeColumns(sheet, setOf(totalColumnIndex, percentageColumnIndex, gradeColumnIndex))
                ensureOutputPath(outputPath, command.overwrite)
                Files.newOutputStream(outputPath, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE).use {
                    workbook.write(it)
                }

                return GradeRunResult(
                    inputPath = command.inputPath,
                    outputPath = outputPath,
                    sheetName = sheet.sheetName,
                    processedRows = processedRows,
                    maxTotalUsed = maxTotal,
                    skippedEmptyRows = skippedEmptyRows,
                    skippedNoScoreRows = skippedNoScoreRows,
                    negativeMarksCorrected = negativeMarksCorrected,
                    percentagesClampedAbove100 = percentagesClampedAbove100,
                    gradeDistribution = orderGradeDistribution(distributionByFold(producedGrades)),
                )
            }
        }
    }

    private fun resolveOutputPath(command: GradeCommand): Path {
        val provided = command.outputPath
        if (provided != null) return provided
        val extension = command.inputPath.extension.ifBlank { "xlsx" }
        val outputName = "${command.inputPath.nameWithoutExtension}_graded.$extension"
        return command.inputPath.resolveSibling(outputName)
    }

    private fun resolveSheet(workbook: Workbook, selector: String?): Sheet {
        if (selector.isNullOrBlank()) {
            return (0 until workbook.numberOfSheets)
                .asSequence()
                .map { workbook.getSheetAt(it) }
                .firstOrNull { sheet ->
                    val header = detectHeaderRow(sheet, workbook.creationHelper.createFormulaEvaluator())
                    header != null && header.rowNum < sheet.lastRowNum
                }
                ?: workbook.getSheetAt(0)
        }

        val index = selector.toIntOrNull()
        if (index != null) {
            val oneBased = index - 1
            if (oneBased in 0 until workbook.numberOfSheets) return workbook.getSheetAt(oneBased)
            if (index in 0 until workbook.numberOfSheets) return workbook.getSheetAt(index)
            error("Sheet index '$selector' is out of range. Workbook has ${workbook.numberOfSheets} sheets.")
        }

        return workbook.getSheet(selector)
            ?: error("Sheet named '$selector' was not found.")
    }

    private fun resolveHeaderRow(sheet: Sheet, evaluator: FormulaEvaluator, explicitHeaderRowNumber: Int?): Row {
        if (explicitHeaderRowNumber != null) {
            val row = sheet.getRow(explicitHeaderRowNumber - 1)
            require(row != null) { "Header row ${explicitHeaderRowNumber} was not found in sheet '${sheet.sheetName}'." }
            return row
        }
        return detectHeaderRow(sheet, evaluator)
            ?: error("Could not detect a header row in sheet '${sheet.sheetName}'. Use --header-row to specify it.")
    }

    private fun detectHeaderRow(sheet: Sheet, evaluator: FormulaEvaluator): Row? {
        for (rowIndex in 0..sheet.lastRowNum) {
            val row = sheet.getRow(rowIndex) ?: continue
            val cells = usedCells(row)
            if (cells.size < 2) continue
            val textLike = cells.count { cell ->
                readNumericCell(cell, evaluator) == null
            }
            if (textLike >= 1) return row
        }
        return null
    }

    private fun collectHeaders(headerRow: Row, evaluator: FormulaEvaluator): MutableList<ColumnHeader> {
        val lastCell = headerRow.lastCellNum.toInt().coerceAtLeast(0)
        val headers = mutableListOf<ColumnHeader>()
        for (columnIndex in 0 until lastCell) {
            val cell = headerRow.getCell(columnIndex)
            val raw = formatter.formatCellValue(cell, evaluator).trim()
            val name = if (raw.isBlank()) "Column_${columnIndex + 1}" else raw
            headers += ColumnHeader(columnIndex, name)
        }
        return headers
    }

    private fun resolveColumnIndex(headers: List<ColumnHeader>, explicitName: String?, keywords: Set<String>): Int? {
        val explicit = explicitName?.trim()?.takeIf { it.isNotEmpty() }
        if (explicit != null) {
            headers.firstOrNull { normalize(it.name) == normalize(explicit) }?.let { return it.index }
        }
        return headers.firstOrNull { header ->
            val normalized = normalize(header.name)
            keywords.any { keyword -> normalized.contains(keyword) }
        }?.index
    }

    private fun detectMarkColumns(
        sheet: Sheet,
        headers: List<ColumnHeader>,
        evaluator: FormulaEvaluator,
        ignoredColumns: Set<Int>,
    ): List<Int> {
        val excluded = headers.filter { header ->
            val normalized = normalize(header.name)
            header.index in ignoredColumns ||
                metadataKeywords.any { normalized.contains(it) } ||
                totalKeywords.any { normalized.contains(it) } ||
                percentageKeywords.any { normalized.contains(it) } ||
                gradeKeywords.any { normalized.contains(it) }
        }.map { it.index }.toSet()

        val numericCandidates = headers.filter { it.index !in excluded }.filter { header ->
            hasNumericDataInColumn(sheet, header.index, evaluator)
        }.map { it.index }

        if (numericCandidates.isNotEmpty()) return numericCandidates
        return headers.filter { it.index !in ignoredColumns && hasNumericDataInColumn(sheet, it.index, evaluator) }.map { it.index }
    }

    private fun appendColumn(headerRow: Row, headers: MutableList<ColumnHeader>, name: String): Int {
        val nextIndex = headers.maxOfOrNull { it.index }?.plus(1) ?: 0
        writeTextCell(headerRow, nextIndex, name)
        headers += ColumnHeader(nextIndex, name)
        return nextIndex
    }

    private fun resolveMaxTotal(
        explicitMaxTotal: Double?,
        sheet: Sheet,
        firstDataRow: Int,
        markColumns: List<Int>,
        totalColumnIndex: Int,
        evaluator: FormulaEvaluator,
    ): Double {
        if (explicitMaxTotal != null) return explicitMaxTotal

        if (markColumns.isNotEmpty()) {
            val inferredPerColumn = markColumns.map { column ->
                val observedMax = maxValueInColumn(sheet, firstDataRow, column, evaluator)
                inferCeiling(observedMax)
            }
            return inferredPerColumn.sum()
        }

        val maxTotalObserved = maxValueInColumn(sheet, firstDataRow, totalColumnIndex, evaluator)
        if (maxTotalObserved <= 100.0) return 100.0
        error(
            "Unable to infer a valid maximum total from sheet '${sheet.sheetName}'. " +
                "Please provide --max-total (for example --max-total 500)."
        )
    }

    private fun inferCeiling(observedMax: Double): Double {
        if (observedMax <= 0.0) return 100.0
        return typicalScoreCeilings.firstOrNull { it > observedMax + 1e-6 } ?: observedMax
    }

    private fun maxValueInColumn(sheet: Sheet, firstDataRow: Int, columnIndex: Int, evaluator: FormulaEvaluator): Double {
        var max = 0.0
        for (rowIndex in firstDataRow..sheet.lastRowNum) {
            val row = sheet.getRow(rowIndex) ?: continue
            val value = readNumericCell(row.getCell(columnIndex), evaluator) ?: continue
            if (value > max) max = value
        }
        return max
    }

    private fun hasNumericDataInColumn(sheet: Sheet, columnIndex: Int, evaluator: FormulaEvaluator): Boolean {
        for (rowIndex in 0..sheet.lastRowNum) {
            val row = sheet.getRow(rowIndex) ?: continue
            if (readNumericCell(row.getCell(columnIndex), evaluator) != null) return true
        }
        return false
    }

    private fun isRowEffectivelyEmpty(row: Row, columnIndexes: List<Int>): Boolean {
        return columnIndexes.all { index ->
            val value = formatter.formatCellValue(row.getCell(index)).trim()
            value.isEmpty()
        }
    }

    private fun readNumericCell(cell: Cell?, evaluator: FormulaEvaluator): Double? {
        if (cell == null) return null
        return when (cell.cellType) {
            CellType.NUMERIC -> cell.numericCellValue
            CellType.STRING -> parseNumber(cell.stringCellValue)
            CellType.BOOLEAN -> if (cell.booleanCellValue) 1.0 else 0.0
            CellType.FORMULA -> {
                val evaluated = evaluator.evaluate(cell) ?: return null
                when (evaluated.cellType) {
                    CellType.NUMERIC -> evaluated.numberValue
                    CellType.STRING -> parseNumber(evaluated.stringValue)
                    CellType.BOOLEAN -> if (evaluated.booleanValue) 1.0 else 0.0
                    else -> null
                }
            }
            else -> null
        }
    }

    private fun parseNumber(value: String?): Double? {
        if (value == null) return null
        val trimmed = value.trim()
        if (trimmed.isEmpty()) return null
        val withoutPercent = trimmed.removeSuffix("%")
        val normalized = withoutPercent.replace(",", "")
        return normalized.toDoubleOrNull()
    }

    private fun writeNumericCell(row: Row, columnIndex: Int, value: Double, style: CellStyle) {
        val cell = row.getCell(columnIndex) ?: row.createCell(columnIndex)
        cell.setCellValue(value)
        cell.cellStyle = style
    }

    private fun writeTextCell(row: Row, columnIndex: Int, value: String) {
        val cell = row.getCell(columnIndex) ?: row.createCell(columnIndex)
        cell.setCellValue(value)
    }

    private fun createNumericStyle(workbook: Workbook, format: String): CellStyle {
        val dataFormat = workbook.creationHelper.createDataFormat().getFormat(format)
        return workbook.createCellStyle().apply { this.dataFormat = dataFormat }
    }

    private fun autosizeColumns(sheet: Sheet, columns: Set<Int>) {
        columns.forEach { index ->
            sheet.autoSizeColumn(index)
        }
    }

    private fun ensureOutputPath(outputPath: Path, overwrite: Boolean) {
        outputPath.parent?.let { Files.createDirectories(it) }
        if (Files.exists(outputPath) && !overwrite) {
            error("Output file already exists: $outputPath. Use --overwrite to replace it.")
        }
    }

    private fun usedCells(row: Row): List<Cell> {
        val last = row.lastCellNum.toInt().coerceAtLeast(0)
        return (0 until last).mapNotNull { row.getCell(it) }.filter { cell ->
            formatter.formatCellValue(cell).trim().isNotEmpty()
        }
    }

    private fun normalize(value: String): String {
        return value.lowercase().replace("[^a-z0-9]".toRegex(), "")
    }

    private fun orderGradeDistribution(input: Map<String, Int>): Map<String, Int> {
        if (input.isEmpty()) return emptyMap()
        val order = listOf("A+", "A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D+", "D", "D-", "F")
        val sorted = linkedMapOf<String, Int>()
        order.forEach { grade ->
            input[grade]?.let { sorted[grade] = it }
        }
        input.keys.filter { it !in order }.sorted().forEach { grade ->
            sorted[grade] = input.getValue(grade)
        }
        return sorted
    }
}

private data class ColumnHeader(
    val index: Int,
    val name: String,
)
