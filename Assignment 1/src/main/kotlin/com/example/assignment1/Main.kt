package com.example.assignment1

import java.util.Locale

interface Titled {
    fun title(): String
}

open class NumberCollection(open val name: String)

data class NumberBatch(
    override val name: String,
    val values: List<Int>,
) : NumberCollection(name), Titled {
    override fun title(): String = "Number batch: $name"
}

interface NumberRule {
    val label: String
    fun matches(value: Int): Boolean
}

data class PredicateRule(
    override val label: String,
    private val predicate: (Int) -> Boolean,
) : NumberRule {
    override fun matches(value: Int): Boolean = predicate(value)
}

sealed class BatchInsight {
    data class MatchGroup(
        val label: String,
        val values: List<Int>,
        val total: Int,
        val average: String,
    ) : BatchInsight()

    data class NoMatch(val label: String) : BatchInsight()
}

fun processList(numbers: List<Int>, predicate: (Int) -> Boolean): List<Int> =
    numbers.filter(predicate)

fun numberBatch(vararg values: Int, name: String = "Numbers"): NumberBatch =
    NumberBatch(name = name, values = values.toList())

infix fun Int.isMultipleOf(divisor: Int): Boolean =
    divisor != 0 && this % divisor == 0

fun Int.squared(): Int = this * this

fun List<Int>.sumWithFold(): Int =
    fold(0) { total, value -> total + value }

fun List<Int>.averageText(): String =
    if (isEmpty()) {
        "n/a"
    } else {
        String.format(Locale.US, "%.1f", sumWithFold().toDouble() / size)
    }

fun prepareValues(
    values: List<Int>,
    minimumValue: Int = 0,
    transformer: (Int) -> Int = { it },
): List<Int> = values
    .map(transformer)
    .filter { it >= minimumValue }

fun analyzeBatch(
    batch: NumberBatch,
    minimumValue: Int = 0,
    transformer: (Int) -> Int = { it },
    vararg rules: NumberRule,
): List<BatchInsight> {
    val preparedValues = prepareValues(
        values = batch.values,
        minimumValue = minimumValue,
        transformer = transformer,
    )

    return rules.map { rule ->
        val matches = processList(preparedValues) { value -> rule.matches(value) }

        if (matches.isEmpty()) {
            BatchInsight.NoMatch(rule.label)
        } else {
            BatchInsight.MatchGroup(
                label = rule.label,
                values = matches,
                total = matches.sumWithFold(),
                average = matches.averageText(),
            )
        }
    }
}

fun BatchInsight.describe(): String = when (this) {
    is BatchInsight.MatchGroup ->
        "$label -> values=${values.joinToString()}, total=$total, average=$average"
    is BatchInsight.NoMatch -> "$label -> no matches"
}

fun <T> List<T>.renderLines(
    transform: (T) -> String,
    separator: String = "\n",
): String = map(transform).joinToString(separator)

fun buildBatchReport(
    batch: NumberBatch,
    minimumValue: Int = 0,
    transformer: (Int) -> Int = { it },
    vararg rules: NumberRule,
): String {
    val preparedValues = prepareValues(
        values = batch.values,
        minimumValue = minimumValue,
        transformer = transformer,
    )
    val insights = analyzeBatch(batch, minimumValue, transformer, *rules)

    return listOf(
        batch.title(),
        "Prepared values: ${preparedValues.joinToString()}",
        "Prepared total: ${preparedValues.sumWithFold()}",
        insights.renderLines(transform = { insight -> insight.describe() }),
    ).joinToString("\n")
}

fun main() {
    val batch = numberBatch(1, 2, 3, 4, 5, 6, 7, 8, name = "Quarter Scores")
    val rules = arrayOf(
        PredicateRule("Even numbers") { it isMultipleOf 2 },
        PredicateRule("Values above 20") { it > 20 },
        PredicateRule("Multiples of three") { it isMultipleOf 3 },
    )

    val report = buildBatchReport(batch, 4, Int::squared, *rules)

    println(report)
}
