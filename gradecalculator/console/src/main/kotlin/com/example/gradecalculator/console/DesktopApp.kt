package com.example.gradecalculator.console

import java.awt.Dimension
import java.awt.GraphicsEnvironment
import java.awt.GridBagConstraints
import java.awt.GridBagLayout
import java.awt.Insets
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import javax.swing.BorderFactory
import javax.swing.JButton
import javax.swing.JComboBox
import javax.swing.JFileChooser
import javax.swing.JFrame
import javax.swing.JLabel
import javax.swing.JOptionPane
import javax.swing.JPanel
import javax.swing.JScrollPane
import javax.swing.JTabbedPane
import javax.swing.JTextArea
import javax.swing.JTextField
import javax.swing.SwingUtilities
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
        val frame = JFrame("Grade Calculator")
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.minimumSize = Dimension(960, 640)

        val tabs = JTabbedPane().apply {
            addTab("Generate Sheet", createGeneratePanel())
            addTab("Grade Sheet", createGradePanel())
        }

        frame.contentPane.add(tabs)
        frame.pack()
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
    }

    private fun createGradePanel(): JPanel {
        val panel = JPanel(GridBagLayout())
        panel.border = BorderFactory.createEmptyBorder(12, 12, 12, 12)
        val gbc = baseConstraints()

        val inputField = JTextField(45)
        val sheetBox = JComboBox<String>().apply {
            addItem("Auto-detect sheet")
        }
        val resultArea = JTextArea(14, 88).apply {
            isEditable = false
            lineWrap = true
            wrapStyleWord = true
        }

        addRow(panel, gbc, 0, "Excel file to grade:", inputField, JButton("Browse").apply {
            addActionListener {
                chooseFileInto(inputField, saveDialog = false)
                refreshSheetChoices(sheetBox, inputField.text.trim())
            }
        })
        addComboRow(panel, gbc, 1, "Sheet:", sheetBox)

        val runButton = JButton("Grade File")
        gbc.gridx = 1
        gbc.gridy = 2
        gbc.gridwidth = 2
        gbc.fill = GridBagConstraints.NONE
        gbc.anchor = GridBagConstraints.WEST
        panel.add(runButton, gbc)

        gbc.gridy = 3
        gbc.fill = GridBagConstraints.BOTH
        gbc.weightx = 1.0
        gbc.weighty = 1.0
        panel.add(JScrollPane(resultArea), gbc)

        runButton.addActionListener {
            runButton.isEnabled = false
            Thread {
                try {
                    val inputText = inputField.text.trim()
                    require(inputText.isNotEmpty()) { "Choose an Excel file to grade." }
                    refreshSheetChoices(sheetBox, inputText)

                    val inputPath = Paths.get(inputText)
                    val outputSelection = chooseGradeOutput(panel, inputPath)
                        ?: throw IllegalStateException("Grading cancelled.")

                    val selectedSheet = sheetBox.selectedItem?.toString()?.takeUnless { it == "Auto-detect sheet" }
                    val result = ExcelGrader().grade(
                        GradeCommand(
                            inputPath = inputPath,
                            outputPath = outputSelection.outputPath,
                            outputDirectory = null,
                            chooseFolderInteractive = false,
                            recursive = false,
                            sheetSelector = selectedSheet,
                            headerRowNumber = null,
                            maxTotal = null,
                            totalColumnHint = null,
                            percentageColumnName = "Percentage",
                            gradeColumnName = "Grade",
                            overwrite = outputSelection.overwrite,
                        ),
                    )

                    val text = buildString {
                        appendLine("Grading completed.")
                        appendLine("Input: ${result.inputPath}")
                        appendLine("Output: ${result.outputPath}")
                        appendLine("Sheet used: ${result.sheetName}")
                        appendLine("Rows processed: ${result.processedRows}")
                        appendLine("Grade distribution:")
                        result.gradeDistribution.forEach { (grade, count) ->
                            appendLine("  $grade -> $count")
                        }
                    }
                    SwingUtilities.invokeLater { resultArea.text = text }
                } catch (error: Throwable) {
                    SwingUtilities.invokeLater {
                        resultArea.text = "Error: ${error.message}"
                        JOptionPane.showMessageDialog(panel, error.message, "Grading Error", JOptionPane.ERROR_MESSAGE)
                    }
                } finally {
                    SwingUtilities.invokeLater { runButton.isEnabled = true }
                }
            }.apply {
                isDaemon = true
                start()
            }
        }

        return panel
    }

    private fun createGeneratePanel(): JPanel {
        val panel = JPanel(GridBagLayout())
        panel.border = BorderFactory.createEmptyBorder(12, 12, 12, 12)
        val gbc = baseConstraints()

        val outputField = JTextField("random_students.xlsx", 45)
        val studentsField = JTextField("30", 8)
        val subjectsField = JTextField("Math,English,Physics,Chemistry,Biology", 45)
        val resultArea = JTextArea(14, 88).apply {
            isEditable = false
            lineWrap = true
            wrapStyleWord = true
        }

        addRow(panel, gbc, 0, "Output Excel file:", outputField, JButton("Browse").apply {
            addActionListener { chooseFileInto(outputField, saveDialog = true) }
        })
        addRow(panel, gbc, 1, "Number of students:", studentsField)
        addRow(panel, gbc, 2, "Subjects:", subjectsField)

        val runButton = JButton("Generate Sheet")
        gbc.gridx = 1
        gbc.gridy = 3
        gbc.gridwidth = 2
        gbc.fill = GridBagConstraints.NONE
        gbc.anchor = GridBagConstraints.WEST
        panel.add(runButton, gbc)

        gbc.gridy = 4
        gbc.fill = GridBagConstraints.BOTH
        gbc.weightx = 1.0
        gbc.weighty = 1.0
        panel.add(JScrollPane(resultArea), gbc)

        runButton.addActionListener {
            runButton.isEnabled = false
            Thread {
                try {
                    val outputPath = Paths.get(outputField.text.trim().ifBlank { "random_students.xlsx" })
                    val subjects = subjectsField.text
                        .split(",")
                        .map { it.trim() }
                        .filter { it.isNotEmpty() }
                        .ifEmpty { listOf("Math", "English", "Physics", "Chemistry", "Biology") }

                    val result = RandomSheetGenerator().generate(
                        GenerateCommand(
                            outputPath = outputPath,
                            outputDirectory = null,
                            chooseFolderInteractive = false,
                            students = studentsField.text.trim().toIntOrNull() ?: 30,
                            subjects = subjects,
                            sheetName = "Students",
                            includeTotalColumn = true,
                            seed = null,
                            minMark = 35.0,
                            maxMark = 100.0,
                            overwrite = confirmOverwriteIfNeeded(panel, outputPath),
                        ),
                    )

                    val text = buildString {
                        appendLine("Sheet generated successfully.")
                        appendLine("Output: ${result.outputPath}")
                        appendLine("Sheet: ${result.sheetName}")
                        appendLine("Students: ${result.students}")
                        appendLine("Subjects: ${result.subjects.joinToString(", ")}")
                    }
                    SwingUtilities.invokeLater { resultArea.text = text }
                } catch (error: Throwable) {
                    SwingUtilities.invokeLater {
                        resultArea.text = "Error: ${error.message}"
                        JOptionPane.showMessageDialog(panel, error.message, "Generation Error", JOptionPane.ERROR_MESSAGE)
                    }
                } finally {
                    SwingUtilities.invokeLater { runButton.isEnabled = true }
                }
            }.apply {
                isDaemon = true
                start()
            }
        }

        return panel
    }

    private fun refreshSheetChoices(sheetBox: JComboBox<String>, inputPathText: String) {
        sheetBox.removeAllItems()
        sheetBox.addItem("Auto-detect sheet")
        if (inputPathText.isBlank()) return

        try {
            listSheetNames(Paths.get(inputPathText)).forEach { sheetBox.addItem(it) }
        } catch (_: Throwable) {
            // Keep the combo usable even when the selected file is not a readable workbook yet.
        }
    }

    private fun chooseGradeOutput(panel: JPanel, inputPath: Path): OutputSelection? {
        val defaultPath = inputPath.resolveSibling(derivedGradedFileName(inputPath))
        val options = arrayOf("Keep Default Name", "Change Name", "Cancel")
        val choice = JOptionPane.showOptionDialog(
            panel,
            "Graded file name:\n$defaultPath\n\nKeep this name or choose a new one?",
            "Output File Name",
            JOptionPane.DEFAULT_OPTION,
            JOptionPane.QUESTION_MESSAGE,
            null,
            options,
            options[0],
        )

        val outputPath = when (choice) {
            0 -> defaultPath
            1 -> choosePath(defaultPath, saveDialog = true) ?: return null
            else -> return null
        }

        return OutputSelection(
            outputPath = outputPath,
            overwrite = confirmOverwriteIfNeeded(panel, outputPath),
        )
    }

    private fun confirmOverwriteIfNeeded(panel: JPanel, outputPath: Path): Boolean {
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

    private fun baseConstraints(): GridBagConstraints = GridBagConstraints().apply {
        insets = Insets(4, 4, 4, 4)
        anchor = GridBagConstraints.WEST
        fill = GridBagConstraints.HORIZONTAL
        weightx = 0.0
        weighty = 0.0
    }

    private fun addRow(
        panel: JPanel,
        base: GridBagConstraints,
        row: Int,
        label: String,
        field: JTextField,
        actionButton: JButton? = null,
    ) {
        val labelConstraints = base.clone() as GridBagConstraints
        labelConstraints.gridx = 0
        labelConstraints.gridy = row
        panel.add(JLabel(label), labelConstraints)

        val fieldConstraints = base.clone() as GridBagConstraints
        fieldConstraints.gridx = 1
        fieldConstraints.gridy = row
        fieldConstraints.weightx = 1.0
        panel.add(field, fieldConstraints)

        if (actionButton != null) {
            val buttonConstraints = base.clone() as GridBagConstraints
            buttonConstraints.gridx = 2
            buttonConstraints.gridy = row
            panel.add(actionButton, buttonConstraints)
        }
    }

    private fun addComboRow(
        panel: JPanel,
        base: GridBagConstraints,
        row: Int,
        label: String,
        comboBox: JComboBox<String>,
    ) {
        val labelConstraints = base.clone() as GridBagConstraints
        labelConstraints.gridx = 0
        labelConstraints.gridy = row
        panel.add(JLabel(label), labelConstraints)

        val comboConstraints = base.clone() as GridBagConstraints
        comboConstraints.gridx = 1
        comboConstraints.gridy = row
        comboConstraints.gridwidth = 2
        comboConstraints.weightx = 1.0
        panel.add(comboBox, comboConstraints)
    }

    private fun chooseFileInto(target: JTextField, saveDialog: Boolean) {
        val selected = choosePath(
            initialPath = target.text.trim().takeIf { it.isNotEmpty() }?.let { Paths.get(it) },
            saveDialog = saveDialog,
        )
        if (selected != null) {
            target.text = selected.toString()
        }
    }

    private fun choosePath(initialPath: Path? = null, saveDialog: Boolean): Path? {
        val chooser = JFileChooser().apply {
            fileFilter = FileNameExtensionFilter("Excel files (*.xlsx, *.xls)", "xlsx", "xls")
            selectedFile = initialPath?.toFile()
        }
        val status = if (saveDialog) chooser.showSaveDialog(null) else chooser.showOpenDialog(null)
        return if (status == JFileChooser.APPROVE_OPTION) chooser.selectedFile.toPath() else null
    }
}

private data class OutputSelection(
    val outputPath: Path,
    val overwrite: Boolean,
)
