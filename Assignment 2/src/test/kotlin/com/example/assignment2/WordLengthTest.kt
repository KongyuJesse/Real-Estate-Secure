package com.example.assignment2

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class WordLengthTest {
    @Test
    fun `builds a normalized map of words to their lengths`() {
        val words = listOf(" Apple ", "cat", "banana", "", "boat")

        val result = buildWordLengthMap(words)

        assertEquals(
            linkedMapOf(
                "apple" to 5,
                "cat" to 3,
                "banana" to 6,
                "boat" to 4,
            ),
            result,
        )
    }

    @Test
    fun `keeps only entries longer than four characters`() {
        val wordLengths = linkedMapOf(
            "apple" to 5,
            "cat" to 3,
            "banana" to 6,
            "boat" to 4,
            "elephant" to 8,
        )

        val result = filterWordsLongerThan(wordLengths)

        assertEquals(
            linkedMapOf(
                "apple" to 5,
                "banana" to 6,
                "elephant" to 8,
            ),
            result,
        )
    }

    @Test
    fun `startsWithLetter works as an infix extension`() {
        assertTrue("Banana" startsWithLetter 'b')
    }

    @Test
    fun `analyzeVocabulary returns structured sections and totals`() {
        val batch = wordBatch("Apple", "Banana", "dog", "elephant", label = "Animals and fruits")

        val result = analyzeVocabulary(
            batch,
            4,
            String::cleanWord,
            PredicateWordRule("Words starting with b") { word, _ -> word startsWithLetter 'b' },
            PredicateWordRule("Words with at least 8 letters") { _, length -> length >= 8 },
        )

        assertEquals(
            listOf(
                WordInsight.MatchSection(
                    label = "Words starting with b",
                    entries = linkedMapOf("banana" to 6),
                    totalCharacters = 6,
                ),
                WordInsight.MatchSection(
                    label = "Words with at least 8 letters",
                    entries = linkedMapOf("elephant" to 8),
                    totalCharacters = 8,
                ),
            ),
            result,
        )
    }

    @Test
    fun `buildVocabularyReport mentions the longest retained word`() {
        val batch = wordBatch("Apple", "Banana", "dog", "elephant", label = "Mixed Vocabulary")

        val report = buildVocabularyReport(
            batch,
            4,
            String::cleanWord,
            PredicateWordRule("Words starting with e") { word, _ -> word startsWithLetter 'e' },
        )

        assertTrue(report.contains("Longest retained word: elephant (8)"))
    }
}
