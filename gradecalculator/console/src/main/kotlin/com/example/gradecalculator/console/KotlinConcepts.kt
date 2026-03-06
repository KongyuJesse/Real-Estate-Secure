package com.example.gradecalculator.console

import kotlin.math.pow
import kotlin.math.roundToInt

typealias ScoreTransformer = (Double) -> Double
typealias ScorePredicate = (Double) -> Boolean

interface Describable {
    fun describe(): String
}

open class PersonRecord(
    open val id: String,
    open val name: String,
) : Describable {
    override fun describe(): String = "$id - $name"
}

data class StudentRecord(
    override val id: String,
    override val name: String,
    val scores: List<Double>,
    val labels: Set<String> = emptySet(),
) : PersonRecord(id, name) {
    override fun describe(): String = "Student ${super.describe()} (${scores.size} score(s))"
}

data class StudentSummary(
    val total: Double,
    val percentage: Double,
    val grade: String,
    val normalizedScores: List<Double>,
)

sealed class EvaluationOutcome {
    data class Processed(val summary: StudentSummary) : EvaluationOutcome()
    data class Skipped(val reason: String) : EvaluationOutcome()
}

data class KotlinSyntaxComparison(
    val concept: String,
    val classicSyntax: String,
    val idiomaticSyntax: String,
    val note: String,
)

data class KotlinFeatureReport(
    val student: StudentRecord,
    val outcome: EvaluationOutcome,
    val immutableList: List<String>,
    val immutableSet: Set<String>,
    val immutableMap: Map<String, Int>,
    val syntaxComparisons: List<KotlinSyntaxComparison>,
)

fun sumScores(vararg scores: Double): Double = scores.fold(0.0) { acc, value -> acc + value }

fun computePercentage(total: Double, maxTotal: Double = 100.0): Double = (total percentOf maxTotal).coerceIn(0.0, 100.0)

infix fun Double.percentOf(maxTotal: Double): Double {
    if (maxTotal <= 0.0) return 0.0
    return (this / maxTotal) * 100.0
}

fun Double.roundTo(decimals: Int = 2): Double {
    val scale = 10.0.pow(decimals.toDouble())
    return kotlin.math.round(this * scale) / scale
}

fun List<Double>.normalizeScores(min: Double = 0.0, max: Double = 100.0): List<Double> = map { it.coerceIn(min, max) }

fun List<Double>.averageByFold(): Double {
    if (isEmpty()) return 0.0
    return fold(0.0) { acc, score -> acc + score } / size
}

fun processScores(
    scores: List<Double>,
    transform: ScoreTransformer = { it },
    predicate: ScorePredicate = { true },
): List<Double> {
    return scores.map(transform).filter(predicate)
}

fun distributionByFold(values: List<String>): Map<String, Int> {
    return values.fold(linkedMapOf()) { acc, value ->
        acc[value] = (acc[value] ?: 0) + 1
        acc
    }
}

object KotlinSyntaxCatalog {
    val comparisons: List<KotlinSyntaxComparison> = listOf(
        KotlinSyntaxComparison(
            concept = "Function Body Style",
            classicSyntax = "fun gradeFor(p: Double): String { return if (p >= 60) \"Pass\" else \"Fail\" }",
            idiomaticSyntax = "fun gradeFor(p: Double): String = if (p >= 60) \"Pass\" else \"Fail\"",
            note = "Expression bodies make short functions concise.",
        ),
        KotlinSyntaxComparison(
            concept = "Mutable vs Immutable Collections",
            classicSyntax = "val scores = mutableListOf(80.0, 70.0); scores.add(90.0)",
            idiomaticSyntax = "val scores: List<Double> = listOf(80.0, 70.0, 90.0)",
            note = "Prefer immutable collections and create new values when transforming.",
        ),
        KotlinSyntaxComparison(
            concept = "Loop vs map/filter/fold",
            classicSyntax = "var total = 0.0; for (s in scores) if (s >= 0) total += s",
            idiomaticSyntax = "scores.filter { it >= 0 }.fold(0.0) { acc, s -> acc + s }",
            note = "Higher-order functions keep collection processing declarative.",
        ),
        KotlinSyntaxComparison(
            concept = "Class Hierarchy",
            classicSyntax = "open class Person(...); class Student(...): Person(...)",
            idiomaticSyntax = "data class Student(...): Person(...)",
            note = "Data classes reduce boilerplate while keeping inheritance support.",
        ),
        KotlinSyntaxComparison(
            concept = "Branching with Sealed Types",
            classicSyntax = "if (ok) printSuccess() else printFailure()",
            idiomaticSyntax = "when (outcome) { is Processed -> ...; is Skipped -> ... }",
            note = "Sealed classes + when create exhaustive and safer flow handling.",
        ),
    )

    fun asConsoleTable(): String {
        val header = "Kotlin Syntax and Concept Comparison"
        val divider = "-".repeat(header.length)
        val rows = comparisons.joinToString("\n") { comparison ->
            buildString {
                appendLine("Concept: ${comparison.concept}")
                appendLine("  Classic:   ${comparison.classicSyntax}")
                appendLine("  Idiomatic: ${comparison.idiomaticSyntax}")
                append("  Note:      ${comparison.note}")
            }
        }
        return "$header\n$divider\n$rows"
    }
}

object KotlinFeatureShowcase {
    fun buildReport(
        studentName: String = "Ada Lovelace",
        maxTotal: Double = 300.0,
        vararg rawScores: Double,
    ): KotlinFeatureReport {
        val sourceScores = if (rawScores.isNotEmpty()) rawScores.toList() else listOf(94.0, 88.5, 91.0)
        if (sourceScores.isEmpty()) {
            return KotlinFeatureReport(
                student = StudentRecord(id = "STU-0000", name = studentName, scores = emptyList()),
                outcome = EvaluationOutcome.Skipped(reason = "No scores provided."),
                immutableList = listOf("Math", "English", "Physics"),
                immutableSet = setOf("kotlin", "functions"),
                immutableMap = emptyMap(),
                syntaxComparisons = KotlinSyntaxCatalog.comparisons,
            )
        }

        val normalized = processScores(
            scores = sourceScores.normalizeScores(min = 0.0, max = maxTotal),
            transform = { score -> score.roundTo(decimals = 2) },
            predicate = { value -> value >= 0.0 },
        )

        val total = sumScores(*normalized.toDoubleArray())
        val percentage = computePercentage(total = total, maxTotal = maxTotal)
        val grade = GradeScale.defaultUsPlusMinus().gradeFor(percentage)
        val student = StudentRecord(
            id = "STU-1001",
            name = studentName,
            scores = normalized,
            labels = setOf("cli", "ui", "collections"),
        )
        val summary = StudentSummary(
            total = total.roundTo(),
            percentage = percentage.roundTo(),
            grade = grade,
            normalizedScores = normalized,
        )
        val subjectNames: List<String> = listOf("Math", "English", "Physics")
        val tags: Set<String> = setOf("kotlin", "desktop", "kotlin", "functions")
        val scoreMap: Map<String, Int> = subjectNames.zip(normalized).associate { (subject, score) ->
            subject to score.roundToInt()
        }

        return KotlinFeatureReport(
            student = student,
            outcome = EvaluationOutcome.Processed(summary = summary),
            immutableList = subjectNames,
            immutableSet = tags,
            immutableMap = scoreMap,
            syntaxComparisons = KotlinSyntaxCatalog.comparisons,
        )
    }

    fun asConsoleText(): String {
        val report = buildReport(
            studentName = "Grace Hopper",
            maxTotal = 300.0,
            95.0,
            88.0,
            91.0,
        )

        val overview = buildString {
            appendLine("Kotlin Feature Showcase")
            appendLine("----------------------")
            appendLine("Student: ${report.student.describe()}")
            when (val outcome = report.outcome) {
                is EvaluationOutcome.Processed -> {
                    appendLine("Total: ${outcome.summary.total}")
                    appendLine("Percentage: ${outcome.summary.percentage}")
                    appendLine("Grade: ${outcome.summary.grade}")
                    appendLine("Average (fold): ${outcome.summary.normalizedScores.averageByFold().roundTo()}")
                }
                is EvaluationOutcome.Skipped -> appendLine("Skipped: ${outcome.reason}")
            }
            appendLine("Immutable List: ${report.immutableList}")
            appendLine("Immutable Set: ${report.immutableSet}")
            appendLine("Immutable Map: ${report.immutableMap}")
            appendLine("Grade distribution (map/filter/fold demo):")
            val grades = listOf("A", "B", "A", "C", "A", "B")
            distributionByFold(grades).forEach { (grade, count) ->
                appendLine("  $grade -> $count")
            }
        }

        return "$overview\n\n${KotlinSyntaxCatalog.asConsoleTable()}"
    }
}

