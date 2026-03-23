package com.example.assignment2

interface Heading {
    fun heading(): String
}

open class Vocabulary(open val label: String)

data class WordBatch(
    override val label: String,
    val words: List<String>,
) : Vocabulary(label), Heading {
    override fun heading(): String = "Vocabulary set: $label"
}

interface WordRule {
    val label: String
    fun matches(word: String, length: Int): Boolean
}

data class PredicateWordRule(
    override val label: String,
    private val predicate: (String, Int) -> Boolean,
) : WordRule {
    override fun matches(word: String, length: Int): Boolean = predicate(word, length)
}

sealed class WordInsight {
    data class MatchSection(
        val label: String,
        val entries: Map<String, Int>,
        val totalCharacters: Int,
    ) : WordInsight()

    data class EmptySection(val label: String) : WordInsight()
}

fun wordBatch(vararg words: String, label: String = "Vocabulary"): WordBatch =
    WordBatch(label = label, words = words.toList())

fun String.cleanWord(): String = trim().lowercase()

infix fun String.startsWithLetter(letter: Char): Boolean =
    firstOrNull()?.equals(letter, ignoreCase = true) ?: false

fun buildWordLengthMap(
    words: List<String>,
    normalizer: (String) -> String = String::cleanWord,
): Map<String, Int> = words
    .map(normalizer)
    .filter(String::isNotBlank)
    .associateWith(String::length)

fun filterWordsLongerThan(
    wordLengths: Map<String, Int>,
    minimumLengthExclusive: Int = 4,
): Map<String, Int> = wordLengths.filter { (_, length) ->
    length > minimumLengthExclusive
}

fun formatWordLengthEntry(word: String, length: Int): String =
    "$word has length $length"

fun printWordLengthEntries(
    entries: Map<String, Int>,
    formatter: (String, Int) -> String = ::formatWordLengthEntry,
) {
    entries.forEach { (word, length) ->
        println(formatter(word, length))
    }
}

fun Map<String, Int>.totalCharacters(): Int =
    values.fold(0) { total, length -> total + length }

fun analyzeVocabulary(
    batch: WordBatch,
    minimumLengthExclusive: Int = 4,
    normalizer: (String) -> String = String::cleanWord,
    vararg rules: WordRule,
): List<WordInsight> {
    val longWords = filterWordsLongerThan(
        wordLengths = buildWordLengthMap(batch.words, normalizer),
        minimumLengthExclusive = minimumLengthExclusive,
    )

    return rules.map { rule ->
        val matches = longWords.filter { (word, length) ->
            rule.matches(word, length)
        }

        if (matches.isEmpty()) {
            WordInsight.EmptySection(rule.label)
        } else {
            WordInsight.MatchSection(
                label = rule.label,
                entries = matches,
                totalCharacters = matches.totalCharacters(),
            )
        }
    }
}

fun WordInsight.describe(
    formatter: (String, Int) -> String = ::formatWordLengthEntry,
): String = when (this) {
    is WordInsight.MatchSection -> {
        val details = entries.entries
            .map { (word, length) -> formatter(word, length) }
            .joinToString(separator = "; ")
        "$label -> $details | totalCharacters=$totalCharacters"
    }
    is WordInsight.EmptySection -> "$label -> no matching words"
}

fun buildVocabularyReport(
    batch: WordBatch,
    minimumLengthExclusive: Int = 4,
    normalizer: (String) -> String = String::cleanWord,
    vararg rules: WordRule,
): String {
    val longWords = filterWordsLongerThan(
        wordLengths = buildWordLengthMap(batch.words, normalizer),
        minimumLengthExclusive = minimumLengthExclusive,
    )
    val longestWord = longWords.entries.fold("" to 0) { currentLongest, entry ->
        if (entry.value > currentLongest.second) {
            entry.key to entry.value
        } else {
            currentLongest
        }
    }
    val insights = analyzeVocabulary(batch, minimumLengthExclusive, normalizer, *rules)

    val longestLine = if (longestWord.second == 0) {
        "Longest retained word: N/A"
    } else {
        "Longest retained word: ${longestWord.first} (${longestWord.second})"
    }

    return listOf(
        batch.heading(),
        "Retained words: ${longWords.size}",
        longestLine,
        insights.joinToString(separator = "\n") { insight -> insight.describe() },
    ).joinToString("\n")
}

fun main() {
    val batch = wordBatch(
        " Apple ",
        "cat",
        "Banana",
        "dog",
        "elephant",
        "boat",
        label = "Mixed Vocabulary",
    )
    val report = buildVocabularyReport(
        batch,
        4,
        String::cleanWord,
        PredicateWordRule("Words starting with b") { word, _ -> word startsWithLetter 'b' },
        PredicateWordRule("Words with at least 6 letters") { _, length -> length >= 6 },
    )

    println(report)

    val longWords = filterWordsLongerThan(
        wordLengths = buildWordLengthMap(batch.words),
        minimumLengthExclusive = 4,
    )
    printWordLengthEntries(longWords)
}
