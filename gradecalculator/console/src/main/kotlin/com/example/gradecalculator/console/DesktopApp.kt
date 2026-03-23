package com.example.gradecalculator.console

import java.awt.BorderLayout
import java.awt.Color
import java.awt.Dimension
import java.awt.FlowLayout
import java.awt.Font
import java.awt.Graphics
import java.awt.Graphics2D
import java.awt.GraphicsEnvironment
import java.awt.GridBagConstraints
import java.awt.GridBagLayout
import java.awt.Insets
import java.awt.RenderingHints
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.util.concurrent.ExecutionException
import javax.swing.BorderFactory
import javax.swing.Box
import javax.swing.BoxLayout
import javax.swing.JButton
import javax.swing.JCheckBox
import javax.swing.JComboBox
import javax.swing.JComponent
import javax.swing.JEditorPane
import javax.swing.JFileChooser
import javax.swing.JFrame
import javax.swing.JLabel
import javax.swing.JOptionPane
import javax.swing.JPanel
import javax.swing.JProgressBar
import javax.swing.JScrollPane
import javax.swing.JSpinner
import javax.swing.JSplitPane
import javax.swing.JTabbedPane
import javax.swing.JTextArea
import javax.swing.JTextField
import javax.swing.SpinnerNumberModel
import javax.swing.SwingUtilities
import javax.swing.SwingWorker
import javax.swing.UIManager
import javax.swing.filechooser.FileNameExtensionFilter

object DesktopApp {
    fun launch() {
        require(!GraphicsEnvironment.isHeadless()) {
            "Desktop UI is not available in a headless environment. Use CLI mode instead."
        }
        SwingUtilities.invokeLater {
            UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName())
            createAndShowWindow()
        }
    }

    private fun createAndShowWindow() {
        val frame = JFrame("Grade Calculator Studio")
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.minimumSize = Dimension(1240, 800)

        val root = JPanel(BorderLayout()).apply {
            background = StudioTheme.canvas
        }
        root.add(createHeroPanel(), BorderLayout.NORTH)
        root.add(createTabs(), BorderLayout.CENTER)
        root.add(createFooter(), BorderLayout.SOUTH)

        frame.contentPane = root
        frame.pack()
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
    }

    private fun createHeroPanel(): JComponent {
        val hero = GradientPanel().apply {
            layout = BorderLayout()
            border = BorderFactory.createEmptyBorder(28, 32, 24, 32)
            preferredSize = Dimension(1200, 170)
        }

        val copy = JPanel().apply {
            isOpaque = false
            layout = BoxLayout(this, BoxLayout.Y_AXIS)
        }
        copy.add(JLabel("Grade Calculator Studio").apply {
            foreground = Color.WHITE
            font = Font("Segoe UI", Font.BOLD, 30)
            alignmentX = JComponent.LEFT_ALIGNMENT
        })
        copy.add(Box.createVerticalStrut(8))
        copy.add(JLabel("Beautiful desktop workflows for grading Excel sheets and generating realistic sample data.").apply {
            foreground = StudioTheme.soft
            font = Font("Segoe UI", Font.PLAIN, 16)
            alignmentX = JComponent.LEFT_ALIGNMENT
        })
        copy.add(Box.createVerticalStrut(18))
        copy.add(JPanel(FlowLayout(FlowLayout.LEFT, 10, 0)).apply {
            isOpaque = false
            add(createChip("Workbook grading"))
            add(createChip("Sample data"))
            add(createChip("Professional summaries"))
            add(createChip("CLI + desktop"))
        })
        hero.add(copy, BorderLayout.CENTER)
        return hero
    }

    private fun createTabs(): JComponent = JTabbedPane().apply {
        border = BorderFactory.createEmptyBorder(18, 22, 18, 22)
        background = StudioTheme.canvas
        font = Font("Segoe UI", Font.BOLD, 14)
        addTab("Workbook Generator", createGeneratePanel())
        addTab("Workbook Grader", createGradePanel())
    }

    private fun createFooter(): JComponent = JPanel(BorderLayout()).apply {
        background = StudioTheme.canvas
        border = BorderFactory.createCompoundBorder(
            BorderFactory.createMatteBorder(1, 0, 0, 0, StudioTheme.border),
            BorderFactory.createEmptyBorder(12, 24, 14, 24),
        )
        add(JLabel("Use the CLI for fast recursive folder grading, and use the desktop studio when you want a guided workflow.").apply {
            foreground = StudioTheme.muted
            font = Font("Segoe UI", Font.PLAIN, 13)
        }, BorderLayout.WEST)
    }

    private fun createGeneratePanel(): JComponent {
        val outputField = field("random_students.xlsx", 32)
        val sheetNameField = field("Students", 18)
        val studentsSpinner = spinner(SpinnerNumberModel(30, 1, 10000, 1))
        val minSpinner = spinner(SpinnerNumberModel(35.0, 0.0, 1000.0, 1.0))
        val maxSpinner = spinner(SpinnerNumberModel(100.0, 1.0, 1000.0, 1.0))
        val seedField = field("", 10)
        val subjectsArea = area("Math, English, Physics, Chemistry, Biology", 4, 28)
        val includeTotal = check("Include a Total column", true)
        val overwrite = check("Overwrite output if it already exists", false)
        val resultPane = resultPane(DesktopPresentation.generatePlaceholder())
        val progress = progressBar()
        val status = statusLabel("Ready to generate", StudioTheme.success)

        val form = card("Workbook Generator", "Create polished practice sheets for demos, testing, and onboarding.", status)
        val grid = JPanel(GridBagLayout()).apply { isOpaque = false }
        row(grid, 0, "Output workbook", outputField, button("Browse") { chooseFileInto(outputField, true) })
        row(grid, 1, "Worksheet name", sheetNameField)
        row(grid, 2, "Student rows", studentsSpinner)
        row(grid, 3, "Minimum mark", minSpinner)
        row(grid, 4, "Maximum mark", maxSpinner)
        row(grid, 5, "Random seed", seedField)
        row(grid, 6, "Subjects", JScrollPane(subjectsArea).apply { preferredSize = Dimension(320, 92) }, tall = true)
        row(grid, 7, "Options", JPanel().apply {
            isOpaque = false
            layout = BoxLayout(this, BoxLayout.Y_AXIS)
            add(includeTotal)
            add(Box.createVerticalStrut(6))
            add(overwrite)
        }, tall = true)
        val generateButton = button("Generate Workbook", primary = true) {
            runTask(progress, generateButton = this as JButton, work = {
                val outputPath = Paths.get(outputField.text.trim().ifBlank { "random_students.xlsx" })
                val minMark = (minSpinner.value as Number).toDouble()
                val maxMark = (maxSpinner.value as Number).toDouble()
                require(maxMark > minMark) { "Maximum mark must be greater than minimum mark." }
                RandomSheetGenerator().generate(
                    GenerateCommand(
                        outputPath = outputPath,
                        outputDirectory = null,
                        chooseFolderInteractive = false,
                        students = (studentsSpinner.value as Number).toInt(),
                        subjects = subjectsArea.text.split(",").map { it.trim() }.filter { it.isNotEmpty() }
                            .ifEmpty { listOf("Math", "English", "Physics", "Chemistry", "Biology") },
                        sheetName = sheetNameField.text.trim().ifBlank { "Students" },
                        includeTotalColumn = includeTotal.isSelected,
                        seed = seedField.text.trim().takeIf { it.isNotBlank() }?.toLongOrNull(),
                        minMark = minMark,
                        maxMark = maxMark,
                        overwrite = if (overwrite.isSelected) true else confirmOverwrite(form, outputPath),
                    ),
                )
            }, onSuccess = { result ->
                status.text = "Workbook generated"
                status.background = StudioTheme.success
                resultPane.text = DesktopPresentation.generateResult(result as GenerateRunResult)
                resultPane.caretPosition = 0
            }, onError = { error ->
                status.text = "Generation failed"
                status.background = StudioTheme.warning
                resultPane.text = DesktopPresentation.error("Generation failed", error.message ?: "Unknown error.")
                resultPane.caretPosition = 0
                JOptionPane.showMessageDialog(form, error.message, "Generation Error", JOptionPane.ERROR_MESSAGE)
            })
        }
        row(grid, 8, "Action", generateButton)
        row(grid, 9, "Progress", progress)
        form.add(grid, BorderLayout.CENTER)

        val summary = card("Run Summary", "Generation details, saved path, and subject setup appear here.").apply {
            add(JScrollPane(resultPane), BorderLayout.CENTER)
        }
        return split(form, summary)
    }

    private fun createGradePanel(): JComponent {
        val inputField = field("", 32)
        val outputField = field("", 32)
        val sheetBox = JComboBox<String>().apply {
            font = Font("Segoe UI", Font.PLAIN, 14)
            addItem("Auto-detect sheet")
        }
        val headerRowField = field("", 8)
        val maxTotalField = field("", 8)
        val totalHintField = field("", 18)
        val percentageField = field("Percentage", 18)
        val gradeField = field("Grade", 18)
        val overwrite = check("Overwrite output if it already exists", false)
        val resultPane = resultPane(DesktopPresentation.gradePlaceholder())
        val progress = progressBar()
        val status = statusLabel("Ready to grade", StudioTheme.success)

        val form = card("Workbook Grader", "Inspect workbook structure, tune grading options, and produce a polished output file.", status)
        val grid = JPanel(GridBagLayout()).apply { isOpaque = false }
        row(grid, 0, "Input workbook", inputField, button("Browse") {
            chooseFileInto(inputField, false)
            setSuggestedOutput(inputField, outputField)
            inspectWorkbook(inputField, outputField, sheetBox, resultPane, status)
        })
        row(grid, 1, "Output workbook", outputField, button("Browse") { chooseFileInto(outputField, true) })
        row(grid, 2, "Worksheet", sheetBox)
        row(grid, 3, "Header row", headerRowField)
        row(grid, 4, "Maximum total", maxTotalField)
        row(grid, 5, "Total column hint", totalHintField)
        row(grid, 6, "Percentage column", percentageField)
        row(grid, 7, "Grade column", gradeField)
        row(grid, 8, "Options", overwrite)
        val actions = JPanel(FlowLayout(FlowLayout.LEFT, 10, 0)).apply {
            isOpaque = false
            add(button("Analyze Workbook") { inspectWorkbook(inputField, outputField, sheetBox, resultPane, status) })
            add(button("Use Suggested Output") { setSuggestedOutput(inputField, outputField) })
            add(button("Grade Workbook", primary = true) {
                runTask(progress, generateButton = this as JButton, work = {
                    val inputPath = Paths.get(inputField.text.trim())
                    require(Files.isRegularFile(inputPath)) { "Choose a readable Excel workbook." }
                    val outputPath = Paths.get(outputField.text.trim().ifBlank { suggestedOutput(inputPath).toString() })
                    ExcelGrader().grade(
                        GradeCommand(
                            inputPath = inputPath,
                            outputPath = outputPath,
                            outputDirectory = null,
                            chooseFolderInteractive = false,
                            recursive = false,
                            sheetSelector = sheetBox.selectedItem?.toString()?.takeUnless { it == "Auto-detect sheet" },
                            headerRowNumber = headerRowField.text.trim().takeIf { it.isNotBlank() }?.toInt(),
                            maxTotal = maxTotalField.text.trim().takeIf { it.isNotBlank() }?.toDouble(),
                            totalColumnHint = totalHintField.text.trim().takeIf { it.isNotBlank() },
                            percentageColumnName = percentageField.text.trim().ifBlank { "Percentage" },
                            gradeColumnName = gradeField.text.trim().ifBlank { "Grade" },
                            overwrite = if (overwrite.isSelected) true else confirmOverwrite(form, outputPath),
                        ),
                    )
                }, onSuccess = { result ->
                    status.text = "Workbook graded"
                    status.background = StudioTheme.success
                    resultPane.text = DesktopPresentation.gradeResult(result as GradeRunResult)
                    resultPane.caretPosition = 0
                }, onError = { error ->
                    status.text = "Grading failed"
                    status.background = StudioTheme.warning
                    resultPane.text = DesktopPresentation.error("Grading failed", error.message ?: "Unknown error.")
                    resultPane.caretPosition = 0
                    JOptionPane.showMessageDialog(form, error.message, "Grading Error", JOptionPane.ERROR_MESSAGE)
                })
            })
        }
        row(grid, 9, "Actions", actions, tall = true)
        row(grid, 10, "Progress", progress)
        form.add(grid, BorderLayout.CENTER)

        val summary = card("Run Summary", "Workbook analysis, output paths, diagnostics, and grade distribution appear here.").apply {
            add(JScrollPane(resultPane), BorderLayout.CENTER)
        }
        return split(form, summary)
    }

    private fun inspectWorkbook(
        inputField: JTextField,
        outputField: JTextField,
        sheetBox: JComboBox<String>,
        resultPane: JEditorPane,
        status: JLabel,
    ) {
        try {
            val inputPath = Paths.get(inputField.text.trim())
            require(Files.isRegularFile(inputPath)) { "Choose a readable Excel workbook." }
            val sheets = listSheetNames(inputPath)
            sheetBox.removeAllItems()
            sheetBox.addItem("Auto-detect sheet")
            sheets.forEach { sheetBox.addItem(it) }
            outputField.text = outputField.text.ifBlank { suggestedOutput(inputPath).toString() }
            resultPane.text = DesktopPresentation.workbookPreview(inputPath, sheets, suggestedOutput(inputPath))
            resultPane.caretPosition = 0
            status.text = "Workbook analyzed"
            status.background = StudioTheme.info
        } catch (error: Throwable) {
            status.text = "Analysis failed"
            status.background = StudioTheme.warning
            resultPane.text = DesktopPresentation.error("Workbook analysis failed", error.message ?: "Unknown error.")
            resultPane.caretPosition = 0
        }
    }

    private fun setSuggestedOutput(inputField: JTextField, outputField: JTextField) {
        runCatching {
            val input = Paths.get(inputField.text.trim())
            outputField.text = suggestedOutput(input).toString()
        }
    }

    private fun suggestedOutput(inputPath: Path): Path = inputPath.resolveSibling(derivedGradedFileName(inputPath))

    private fun runTask(
        progress: JProgressBar,
        generateButton: JButton,
        work: () -> Any,
        onSuccess: (Any) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        generateButton.isEnabled = false
        progress.isVisible = true
        progress.isIndeterminate = true
        object : SwingWorker<Any, Unit>() {
            override fun doInBackground(): Any = work()
            override fun done() {
                generateButton.isEnabled = true
                progress.isIndeterminate = false
                progress.isVisible = false
                try {
                    onSuccess(get())
                } catch (error: Throwable) {
                    onError((error as? ExecutionException)?.cause ?: error)
                }
            }
        }.execute()
    }

    private fun confirmOverwrite(panel: JComponent, outputPath: Path): Boolean {
        if (!Files.exists(outputPath)) return false
        val choice = JOptionPane.showConfirmDialog(
            panel,
            "File already exists:\n$outputPath\n\nReplace it?",
            "Overwrite File",
            JOptionPane.YES_NO_OPTION,
        )
        require(choice == JOptionPane.YES_OPTION) { "Choose a different file name." }
        return true
    }

    private fun split(left: JComponent, right: JComponent): JComponent = JSplitPane(JSplitPane.HORIZONTAL_SPLIT, left, right).apply {
        border = BorderFactory.createEmptyBorder()
        resizeWeight = 0.46
        dividerSize = 16
        background = StudioTheme.canvas
    }

    private fun card(title: String, subtitle: String, badge: JComponent? = null): SurfacePanel {
        val card = SurfacePanel().apply {
            layout = BorderLayout(0, 18)
            border = BorderFactory.createEmptyBorder(24, 24, 24, 24)
        }
        val header = JPanel(BorderLayout()).apply { isOpaque = false }
        val text = JPanel().apply {
            isOpaque = false
            layout = BoxLayout(this, BoxLayout.Y_AXIS)
            add(JLabel(title).apply { foreground = StudioTheme.primary; font = Font("Segoe UI", Font.BOLD, 20) })
            add(Box.createVerticalStrut(6))
            add(JLabel(subtitle).apply { foreground = StudioTheme.muted; font = Font("Segoe UI", Font.PLAIN, 14) })
        }
        header.add(text, BorderLayout.CENTER)
        if (badge != null) header.add(badge, BorderLayout.EAST)
        card.add(header, BorderLayout.NORTH)
        return card
    }

    private fun row(panel: JPanel, row: Int, label: String, component: JComponent, action: JComponent? = null, tall: Boolean = false) {
        panel.add(JLabel(label).apply { foreground = StudioTheme.ink; font = Font("Segoe UI", Font.PLAIN, 14) }, GridBagConstraints().apply {
            gridx = 0; gridy = row; insets = Insets(6, 0, 10, 14); anchor = GridBagConstraints.NORTHWEST
        })
        panel.add(component, GridBagConstraints().apply {
            gridx = 1; gridy = row; weightx = 1.0; fill = if (tall) GridBagConstraints.BOTH else GridBagConstraints.HORIZONTAL
            insets = Insets(4, 0, 10, 10); anchor = GridBagConstraints.NORTHWEST
        })
        if (action != null) panel.add(action, GridBagConstraints().apply {
            gridx = 2; gridy = row; insets = Insets(4, 0, 10, 0); anchor = GridBagConstraints.NORTHWEST
        })
    }

    private fun field(value: String, columns: Int): JTextField = JTextField(value, columns).apply {
        font = Font("Segoe UI", Font.PLAIN, 14)
    }

    private fun area(value: String, rows: Int, columns: Int): JTextArea = JTextArea(value, rows, columns).apply {
        font = Font("Segoe UI", Font.PLAIN, 14)
        lineWrap = true
        wrapStyleWord = true
    }

    private fun spinner(model: SpinnerNumberModel): JSpinner = JSpinner(model).apply {
        font = Font("Segoe UI", Font.PLAIN, 14)
    }

    private fun check(label: String, selected: Boolean): JCheckBox = JCheckBox(label, selected).apply {
        isOpaque = false
        font = Font("Segoe UI", Font.PLAIN, 14)
        foreground = StudioTheme.ink
    }

    private fun button(label: String, primary: Boolean = false, onClick: JButton.() -> Unit): JButton = JButton(label).apply {
        font = Font("Segoe UI", Font.BOLD, 13)
        isFocusPainted = false
        background = if (primary) StudioTheme.primary else Color.WHITE
        foreground = if (primary) Color.WHITE else StudioTheme.primary
        addActionListener { onClick() }
    }

    private fun progressBar(): JProgressBar = JProgressBar().apply {
        isVisible = false
        background = StudioTheme.canvas
        foreground = StudioTheme.accent
    }

    private fun resultPane(initial: String): JEditorPane = JEditorPane("text/html", initial).apply {
        isEditable = false
        background = StudioTheme.canvas
        border = BorderFactory.createEmptyBorder(12, 12, 12, 12)
    }

    private fun statusLabel(text: String, color: Color): JLabel = JLabel(text).apply {
        isOpaque = true
        background = color
        foreground = Color.WHITE
        font = Font("Segoe UI", Font.BOLD, 12)
        border = BorderFactory.createEmptyBorder(6, 12, 6, 12)
    }

    private fun createChip(text: String): JLabel = JLabel(text).apply {
        isOpaque = true
        background = StudioTheme.chip
        foreground = StudioTheme.primary
        font = Font("Segoe UI", Font.BOLD, 12)
        border = BorderFactory.createEmptyBorder(6, 12, 6, 12)
    }

    private fun chooseFileInto(target: JTextField, saveDialog: Boolean) {
        val chooser = JFileChooser().apply {
            fileFilter = FileNameExtensionFilter("Excel files (*.xlsx, *.xls)", "xlsx", "xls")
            selectedFile = target.text.trim().takeIf { it.isNotEmpty() }?.let { Paths.get(it).toFile() }
        }
        val status = if (saveDialog) chooser.showSaveDialog(null) else chooser.showOpenDialog(null)
        if (status == JFileChooser.APPROVE_OPTION) target.text = chooser.selectedFile.toPath().toString()
    }
}

private object StudioTheme {
    val canvas = Color(247, 243, 236)
    val border = Color(215, 206, 191)
    val primary = Color(21, 51, 82)
    val accent = Color(50, 120, 111)
    val ink = Color(32, 40, 51)
    val muted = Color(94, 103, 114)
    val soft = Color(233, 240, 245)
    val chip = Color(239, 229, 214)
    val success = Color(43, 112, 84)
    val warning = Color(168, 95, 45)
    val info = Color(74, 98, 149)
}

private class GradientPanel : JPanel() {
    init { isOpaque = false }
    override fun paintComponent(graphics: Graphics) {
        super.paintComponent(graphics)
        val g2 = graphics.create() as Graphics2D
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
        g2.paint = java.awt.GradientPaint(0f, 0f, StudioTheme.primary, width.toFloat(), height.toFloat(), StudioTheme.accent)
        g2.fillRect(0, 0, width, height)
        g2.dispose()
    }
}

private class SurfacePanel : JPanel() {
    init { isOpaque = false }
    override fun paintComponent(graphics: Graphics) {
        super.paintComponent(graphics)
        val g2 = graphics.create() as Graphics2D
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
        g2.color = Color(255, 252, 247)
        g2.fillRoundRect(0, 0, width - 1, height - 1, 26, 26)
        g2.color = StudioTheme.border
        g2.drawRoundRect(0, 0, width - 1, height - 1, 26, 26)
        g2.dispose()
    }
}
