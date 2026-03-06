package com.example.assignment2

fun buildWordLengthMap(words: List<String>): Map<String, Int> =
    words.associateWith { it.length }

fun filterWordsLongerThan(
    wordLengths: Map<String, Int>,
    minimumLengthExclusive: Int = 4,
): Map<String, Int> = wordLengths.filter { (_, length) ->
    length > minimumLengthExclusive
}

fun formatWordLengthEntry(word: String, length: Int): String =
    "$word has length $length"

fun printWordLengthEntries(entries: Map<String, Int>) {
    entries.forEach { (word, length) ->
        println(formatWordLengthEntry(word, length))
    }
}

fun main() {
    val words = listOf("apple", "cat", "banana", "dog", "elephant")
    val wordLengths = buildWordLengthMap(words)
    val longWords = filterWordsLongerThan(wordLengths)

    printWordLengthEntries(longWords)
}

